import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../features/ai_advisor/advisor_attachment.dart';
import '../../features/ai_advisor/gemini_advisor_client.dart';
import '../locale/locale_service.dart';
import 'voice_cloud_capture.dart';

typedef VoiceSttTextCallback = void Function(String text, bool isFinal);

enum VoiceSttLanguage { auto, arabic, english }

/// Mic dictation for the researcher advisor (and viva). Chrome uses the
/// browser speech API; Windows Arabic uses Gemini when cloud AI is on.
class VoiceSttService {
  VoiceSttService._();

  static final VoiceSttService instance = VoiceSttService._();

  final SpeechToText _speech = SpeechToText();
  final VoiceCloudCapture? _cloudMic = voiceCloudCapture();

  bool _initialized = false;
  bool _localAvailable = false;
  bool _cloudAvailable = false;
  bool _listening = false;
  bool _transcribing = false;
  bool _usingCloud = false;
  String _prefixBeforeListen = '';
  VoiceSttTextCallback? _onText;

  VoiceSttLanguage language = VoiceSttLanguage.auto;

  bool get isAvailable => _localAvailable || _cloudAvailable;
  bool get isListening => _listening;
  bool get isTranscribing => _transcribing;
  bool get usesCloud => _usingCloud;

  void Function()? onStateChanged;
  final List<void Function()> _listeners = [];

  void addListener(void Function() cb) => _listeners.add(cb);

  void removeListener(void Function() cb) => _listeners.remove(cb);

  void _notify() {
    onStateChanged?.call();
    for (final cb in List.of(_listeners)) {
      cb();
    }
  }

  Future<bool> init() async {
    if (_initialized) {
      await _refreshCloud();
      return isAvailable;
    }

    try {
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
    } catch (_) {
      _localAvailable = false;
    }

    await _refreshCloud();
    _initialized = true;
    return isAvailable;
  }

  Future<void> _refreshCloud() async {
    if (kIsWeb || _cloudMic == null) {
      _cloudAvailable = false;
      return;
    }
    _cloudAvailable = GeminiAdvisorClient.isAvailable;
    if (!_cloudAvailable) return;
    _cloudAvailable = await _cloudMic.hasMic();
  }

  VoiceSttLanguage get _effectiveLanguage {
    return switch (language) {
      VoiceSttLanguage.arabic => VoiceSttLanguage.arabic,
      VoiceSttLanguage.english => VoiceSttLanguage.english,
      VoiceSttLanguage.auto => LocaleService.instance.isEnglish
          ? VoiceSttLanguage.english
          : VoiceSttLanguage.arabic,
    };
  }

  bool _windowsEnglishOnlyLocal() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<bool> _hasLocalLocale(VoiceSttLanguage lang) async {
    if (!_localAvailable) return false;
    try {
      final locales = await _speech.locales();
      final code = lang == VoiceSttLanguage.english ? 'en' : 'ar';
      return locales.any((l) => l.localeId.toLowerCase().startsWith(code));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _shouldUseCloud(VoiceSttLanguage effective) async {
    if (kIsWeb || !_cloudAvailable) return false;

    if (_windowsEnglishOnlyLocal()) {
      if (language == VoiceSttLanguage.auto) return true;
      return effective != VoiceSttLanguage.english;
    }

    if (effective == VoiceSttLanguage.arabic) {
      return !await _hasLocalLocale(VoiceSttLanguage.arabic);
    }
    return false;
  }

  Future<String?> _resolveLocalLocale(VoiceSttLanguage effective) async {
    final locales = await _speech.locales();
    if (locales.isEmpty) return null;

    final preferred = effective == VoiceSttLanguage.english ? 'en-US' : 'ar-SA';
    final lang = preferred.split('-').first;

    for (final locale in locales) {
      if (locale.localeId == preferred) return locale.localeId;
    }
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(lang)) {
        return locale.localeId;
      }
    }
    return locales.first.localeId;
  }

  String _transcriptionPrompt(VoiceSttLanguage effective) {
    return switch (effective) {
      VoiceSttLanguage.arabic =>
        'You transcribe a graduate researcher speaking to an academic assistant. '
            'The student speaks Arabic. Write the transcript in Arabic script only. '
            'Return ONLY the spoken words — no commentary, labels, or translation.',
      VoiceSttLanguage.english =>
        'You transcribe a graduate researcher speaking to an academic assistant. '
            'The student speaks English. Return ONLY the spoken words in English — '
            'no commentary or labels.',
      VoiceSttLanguage.auto =>
        'You transcribe a graduate researcher speaking to an academic assistant. '
            'The student may speak Arabic, English, or mix both. '
            'Write exactly what was spoken in the same language(s). '
            'Return ONLY the transcript — no commentary or translation.',
    };
  }

  Future<bool> startListening({
    required String existingText,
    required VoiceSttTextCallback onText,
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
    final mic = _cloudMic;
    if (mic == null || !_cloudAvailable) return false;
    final started = await mic.startWav();
    if (!started) return false;
    _usingCloud = true;
    _listening = true;
    _notify();
    return true;
  }

  Future<bool> _startLocalListening(VoiceSttLanguage effective) async {
    if (!_localAvailable) {
      if (_cloudAvailable) return _startCloudListening();
      return false;
    }

    final localeId = await _resolveLocalLocale(effective);
    if (localeId == null) {
      if (_cloudAvailable) return _startCloudListening();
      return false;
    }

    _usingCloud = false;
    await _speech.listen(
      onResult: (result) {
        final combined = '$_prefixBeforeListen${result.recognizedWords}'.trim();
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

    try {
      final bytes = await _cloudMic?.stopWav();
      if (bytes != null && bytes.isNotEmpty) {
        final effective = language == VoiceSttLanguage.auto
            ? VoiceSttLanguage.auto
            : _effectiveLanguage;
        final text = await _transcribeWithGemini(bytes, effective);
        if (text != null && text.isNotEmpty) {
          final combined = '$_prefixBeforeListen$text'.trim();
          _prefixBeforeListen = combined.isEmpty ? '' : '$combined ';
          _onText?.call(combined, true);
        }
      }
    } finally {
      _transcribing = false;
      _usingCloud = false;
      _notify();
    }
  }

  Future<String?> _transcribeWithGemini(
    List<int> audioBytes,
    VoiceSttLanguage effective,
  ) async {
    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: _transcriptionPrompt(effective),
      userMessage: 'Transcribe the attached audio of the researcher speaking.',
      attachments: [
        GeminiInlinePart(
          mimeType: 'audio/wav',
          base64Data: base64Encode(audioBytes),
          fileName: 'advisor_voice.wav',
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
      await _cloudMic?.cancel();
      _usingCloud = false;
      _notify();
      return;
    }
    if (!_initialized) return;
    try {
      await _speech.cancel();
    } catch (_) {}
    _listening = false;
    _notify();
  }

  Future<void> dispose() async {
    await cancel();
  }
}
