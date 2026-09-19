import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/locale/locale_service.dart';

/// صوت إرشاد لخطوات الدليل التفاعلي.
class AssemblyGuideTts {
  AssemblyGuideTts._();
  static final AssemblyGuideTts instance = AssemblyGuideTts._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;
  Completer<void>? _done;

  bool get isSpeaking => _speaking;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      _speaking = false;
      final d = _done;
      if (d != null && !d.isCompleted) d.complete();
    });
    _tts.setCancelHandler(() {
      _speaking = false;
      final d = _done;
      if (d != null && !d.isCompleted) d.complete();
    });
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

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await init();
    await _applyLocale();
    await stop();
    _speaking = true;
    await _tts.speak(t);
  }

  Future<void> speakAndWait(
    String text, {
    Duration extraHold = const Duration(milliseconds: 700),
  }) async {
    final t = text.trim();
    if (t.isEmpty) {
      await Future<void>.delayed(const Duration(seconds: 4));
      return;
    }
    await init();
    _done = Completer<void>();
    await speak(t);
    final waitMs = (t.length * 90).clamp(5000, 22000);
    try {
      await _done!.future.timeout(Duration(milliseconds: waitMs));
    } on TimeoutException {
      _speaking = false;
    }
    await Future<void>.delayed(extraHold);
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _tts.stop();
    _speaking = false;
  }
}
