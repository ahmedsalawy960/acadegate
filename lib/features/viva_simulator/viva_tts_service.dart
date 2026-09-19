import '../../core/locale/locale_service.dart';
import '../../core/voice/voice_tts_service.dart';
import 'viva_committee.dart';

class VivaTtsService {
  VivaTtsService._();

  static final VivaTtsService instance = VivaTtsService._();

  final VoiceTtsService _tts = VoiceTtsService.instance;
  bool _enabled = false;

  bool get isEnabled => _enabled;
  bool get isSpeaking => _tts.isSpeaking;

  Future<void> init() => _tts.init();

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) stop();
  }

  Future<void> speakCommitteeQuestion({
    required VivaCommitteeMember member,
    required String question,
  }) async {
    if (!_enabled) return;
    final prefix = LocaleService.instance.isEnglish
        ? '${member.displayName} asks: '
        : 'يسأل ${member.displayName}: ';
    await _tts.speak('$prefix$question');
  }

  Future<void> stop() => _tts.stop();

  Future<void> dispose() async {
    await stop();
  }
}
