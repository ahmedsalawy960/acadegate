import 'package:flutter_tts/flutter_tts.dart';

import '../../core/locale/locale_service.dart';
import 'viva_committee.dart';

class VivaTtsService {
  VivaTtsService._();

  static final VivaTtsService instance = VivaTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = false;
  bool _speaking = false;

  bool get isEnabled => _enabled;
  bool get isSpeaking => _speaking;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _initialized = true;
    await _applyLocale();
  }

  Future<void> _applyLocale() async {
    final code = LocaleService.instance.isEnglish ? 'en-US' : 'ar-SA';
    try {
      await _tts.setLanguage(code);
    } catch (_) {
      await _tts.setLanguage('en-US');
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) stop();
  }

  Future<void> speakCommitteeQuestion({
    required VivaCommitteeMember member,
    required String question,
  }) async {
    if (!_enabled) return;
    await init();
    await _applyLocale();
    await stop();
    _speaking = true;
    final prefix = LocaleService.instance.isEnglish
        ? '${member.displayName} asks: '
        : 'يسأل ${member.displayName}: ';
    await _tts.speak('$prefix$question');
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _tts.stop();
    _speaking = false;
  }

  Future<void> dispose() async {
    await stop();
  }
}
