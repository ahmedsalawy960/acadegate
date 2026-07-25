import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/locale/locale_service.dart';
import '../ai_advisor/advisor_attachment.dart';
import '../ai_advisor/gemini_advisor_client.dart';

typedef VivaSttTextCallback = void Function(String text, bool isFinal);

enum VivaSttLanguage { auto, arabic, english }

/// Speech-to-text for oral viva answers.
/// Windows local SAPI is English-only — Arabic uses Gemini when configured.
class VivaSttService {
  VivaSttService._();

  static final VivaSttService instance = VivaSttService._();

  final SpeechToText _speech = SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();

  bool _initialized = false;
  bool _localAvailable = false;
  bool _cloudAvailable = false;
  bool _listening = false;
  bool _transcribing = false;
  bool _usingCloud = false;
  String _prefixBeforeListen = '';
  String? _recordingPath;
  VivaSttTextCallback? _onText;

  VivaSttLanguage language = VivaSttLanguage.auto;

  bool get isAvailable => _localAvailable || _cloudAvailable;
  bool get isListening => _listening;
  bool get isTranscribing => _transcribing;
  bool get usesCloud => _usingCloud;

  void Function()? onStateChanged;

  void _notify() => onStateChanged?.call();

  Future<bool> init() async {
    if (_initialized) {
      // Refresh cloud availability after sign-in / key changes.
      _cloudAvailable = GeminiAdvisorClient.isAvailable;
      if (_cloudAvailable) {
        try {
          final mic = await _recorder.hasPermission();
          if (!mic) _cloudAvailable = false;
        } catch (_) {
          _cloudAvailable = false;
        }
      }
      return isAvailable;
    }

    _localAvailable = await _speech.initialize(
      onStatus: (status) {
        if (_usingCloud) return;
        final listening = status == 'listening';
        if (_listening != listening) {
          _listening = listening;
          _notify();
        }
        if (status == 'done' || status == 'notListening') {
          if (_listening) {
            _listening = false;
            _notify();
          }
        }
      },
      onError: (_) {
        if (_usingCloud) return;
        _listening = false;
        _notify();
      },
    );

    _cloudAvailable = GeminiAdvisorClient.isAvailable;
    if (_cloudAvailable) {
      try {
        final mic = await _recorder.hasPermission();
        if (!mic) _cloudAvailable = false;
      } catch (_) {
        _cloudAvailable = false;
      }
    }

    _initialized = true;
    return isAvailable;
  }

  VivaSttLanguage get _effectiveLanguage {
    return switch (language) {
      VivaSttLanguage.arabic => VivaSttLanguage.arabic,
      VivaSttLanguage.english => VivaSttLanguage.english,
      VivaSttLanguage.auto =>
        LocaleService.instance.isEnglish
            ? VivaSttLanguage.english
            : VivaSttLanguage.arabic,
    };
  }

  bool _windowsEnglishOnlyLocal() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<bool> _hasLocalLocale(VivaSttLanguage lang) async {
    if (!_localAvailable) return false;
    final locales = await _speech.locales();
    final code = lang == VivaSttLanguage.english ? 'en' : 'ar';
    return locales.any((l) => l.localeId.toLowerCase().startsWith(code));
  }

  Future<bool> _shouldUseCloud(VivaSttLanguage effective) async {
    if (!_cloudAvailable) return false;

    if (_windowsEnglishOnlyLocal()) {
      if (language == VivaSttLanguage.auto) return true;
      return effective != VivaSttLanguage.english;
    }

    if (effective == VivaSttLanguage.arabic) {
      return !await _hasLocalLocale(VivaSttLanguage.arabic);
    }
    return false;
  }

  Future<String?> _resolveLocalLocale(VivaSttLanguage effective) async {
    final locales = await _speech.locales();
    if (locales.isEmpty) return null;

    final preferred = effective == VivaSttLanguage.english ? 'en-US' : 'ar-SA';
    final lang = preferred.split('-').first;

    for (final locale in locales) {
      if (locale.localeId == preferred) return locale.localeId;
    }
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(lang)) {
        return locale.localeId;
      }
    }
    return null;
  }

  String _transcriptionPrompt(VivaSttLanguage effective) {
    return switch (effective) {
      VivaSttLanguage.arabic =>
        'You transcribe oral answers in academic viva exams. '
            'The student speaks Arabic. Write the transcript in Arabic script only. '
            'Return ONLY the spoken words — no commentary, labels, or translation.',
      VivaSttLanguage.english =>
        'You transcribe oral answers in academic viva exams. '
            'The student speaks English. Return ONLY the spoken words in English — '
            'no commentary or labels.',
      VivaSttLanguage.auto =>
        'You transcribe oral answers in academic viva exams. '
            'The student may speak Arabic, English, or mix both. '
            'Write exactly what was spoken in the same language(s). '
            'Return ONLY the transcript — no commentary or translation.',
    };
  }

  Future<bool> startListening({
    required String existingText,
    required VivaSttTextCallback onText,
  }) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return false;
    }
    if (_listening || _transcribing) return true;

    _onText = onText;
    _prefixBeforeListen = existingText.trimRight();
    if (_prefixBeforeListen.isNotEmpty) {
      _prefixBeforeListen = '$_prefixBeforeListen ';
    }

    final effective = _effectiveLanguage;
    if (await _shouldUseCloud(effective)) {
      return _startCloudListening();
    }
    return _startLocalListening(effective);
  }

  Future<bool> _startCloudListening() async {
    if (!_cloudAvailable) return false;

    final granted = await _recorder.hasPermission();
    if (!granted) return false;

    _recordingPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}viva_stt_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );
    } catch (_) {
      _recordingPath = null;
      return false;
    }

    _usingCloud = true;
    _listening = true;
    _notify();
    return true;
  }

  Future<bool> _startLocalListening(VivaSttLanguage effective) async {
    if (!_localAvailable) return false;

    final localeId = await _resolveLocalLocale(effective);
    if (localeId == null) {
      if (_cloudAvailable) return _startCloudListening();
      return false;
    }

    _usingCloud = false;
    await _speech.listen(
      onResult: (result) {
        final combined =
            '$_prefixBeforeListen${result.recognizedWords}'.trim();
        _onText?.call(combined, result.finalResult);
        if (result.finalResult) {
          _prefixBeforeListen = combined.isEmpty ? '' : '$combined ';
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        localeId: localeId,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 6),
        listenFor: const Duration(minutes: 3),
      ),
    );

    _listening = true;
    _notify();
    return true;
  }

  Future<void> stopListening() async {
    if (_usingCloud) {
      await _stopCloudListening();
      return;
    }
    if (!_listening) return;
    await _speech.stop();
    _listening = false;
    _notify();
  }

  Future<void> _stopCloudListening() async {
    if (!_listening) return;

    _listening = false;
    _transcribing = true;
    _notify();

    String? path = _recordingPath;
    _recordingPath = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    if (path == null || !File(path).existsSync()) {
      _transcribing = false;
      _usingCloud = false;
      _notify();
      return;
    }

    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length > 44) {
        final effective = language == VivaSttLanguage.auto
            ? VivaSttLanguage.auto
            : _effectiveLanguage;
        final text = await _transcribeWithGemini(bytes, effective);
        if (text != null && text.isNotEmpty) {
          final combined =
              '$_prefixBeforeListen$text'.trim();
          _prefixBeforeListen = combined.isEmpty ? '' : '$combined ';
          _onText?.call(combined, true);
        }
      }
    } finally {
      try {
        await File(path).delete();
      } catch (_) {}
      _transcribing = false;
      _usingCloud = false;
      _notify();
    }
  }

  Future<String?> _transcribeWithGemini(
    List<int> audioBytes,
    VivaSttLanguage effective,
  ) async {
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: _transcriptionPrompt(effective),
      userMessage: 'Transcribe the attached audio of the student answer.',
      attachments: [
        GeminiInlinePart(
          mimeType: 'audio/wav',
          base64Data: base64Encode(audioBytes),
          fileName: 'viva_answer.wav',
        ),
      ],
      maxOutputTokens: 2048,
    );
    return result.text?.trim();
  }

  Future<void> cancel() async {
    if (_usingCloud) {
      _listening = false;
      _transcribing = false;
      try {
        await _recorder.stop();
      } catch (_) {}
      final path = _recordingPath;
      _recordingPath = null;
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      _usingCloud = false;
      _notify();
      return;
    }
    if (!_initialized) return;
    await _speech.cancel();
    _listening = false;
    _notify();
  }

  Future<void> dispose() async {
    await cancel();
  }
}
