import 'package:flutter_tts/flutter_tts.dart';

import '../locale/locale_service.dart';
import 'readable_text.dart';

/// Shared TTS for the advisor and the viva simulator.
class VoiceTtsService {
  VoiceTtsService._();

  static final VoiceTtsService instance = VoiceTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;
  Map<String, String>? _arabicVoice;
  Map<String, String>? _englishVoice;

  bool get isSpeaking => _speaking;

  void Function()? onStateChanged;

  void _notify() => onStateChanged?.call();

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
    _tts.setStartHandler(() {
      _speaking = true;
      _notify();
    });
    _tts.setCompletionHandler(() {
      _speaking = false;
      _notify();
    });
    _tts.setCancelHandler(() {
      _speaking = false;
      _notify();
    });
    _tts.setErrorHandler((_) {
      _speaking = false;
      _notify();
    });
    _initialized = true;
    await _resolveVoices();
    await _applyLocale();
  }

  Future<void> _resolveVoices() async {
    List<Map<String, String>> voices = const [];
    for (var attempt = 0; attempt < 5 && voices.isEmpty; attempt++) {
      try {
        final raw = await _tts.getVoices;
        if (raw is List) {
          voices = raw
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry('$k', '$v')))
              .toList();
        }
      } catch (_) {}
      if (voices.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    Map<String, String>? pick(bool arabic) {
      for (final voice in voices) {
        final locale = (voice['locale'] ?? voice['lang'] ?? '').toLowerCase();
        if (arabic ? locale.startsWith('ar') : locale.startsWith('en')) {
          return {
            'name': voice['name'] ?? '',
            'locale': voice['locale'] ?? voice['lang'] ?? (arabic ? 'ar-SA' : 'en-US'),
          };
        }
      }
      return null;
    }

    _arabicVoice = pick(true);
    _englishVoice = pick(false);
  }

  Future<void> _applyVoice({required bool arabic}) async {
    final voice = arabic ? _arabicVoice : _englishVoice;
    final fallbackLang = arabic ? 'ar-SA' : 'en-US';
    if (voice != null && voice['name']!.isNotEmpty) {
      try {
        await _tts.setVoice(voice);
        return;
      } catch (_) {}
    }
    for (final code in arabic
        ? const ['ar-SA', 'ar-EG', 'ar', 'ar-XA']
        : const ['en-US', 'en-GB', 'en']) {
      try {
        await _tts.setLanguage(code);
        return;
      } catch (_) {}
    }
    try {
      await _tts.setLanguage(fallbackLang);
    } catch (_) {}
  }

  Future<void> _applyLocale() async {
    await _applyVoice(arabic: !LocaleService.instance.isEnglish);
  }

  static String plainForSpeech(String raw) => ReadableText.forSpeech(
        raw,
        arabic: !LocaleService.instance.isEnglish,
      );

  Future<void> speak(String text) async {
    final arabicUi = !LocaleService.instance.isEnglish;
    final spoken = ReadableText.forSpeech(text, arabic: arabicUi);
    if (spoken.isEmpty) return;
    await init();
    await stop();
    _speaking = true;
    _notify();
    try {
      final wantArabic = arabicUi && ReadableText.hasArabic(spoken);
      await _applyVoice(arabic: wantArabic);
      await _tts.speak(spoken);
    } catch (_) {
      _speaking = false;
      _notify();
    }
  }

  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
    _notify();
  }
}
