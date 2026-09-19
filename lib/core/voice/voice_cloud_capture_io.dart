import 'dart:io';

import 'package:record/record.dart';

import 'voice_cloud_capture_types.dart';

VoiceCloudCapture? createVoiceCloudCapture() => _IoVoiceCloudCapture();

class _IoVoiceCloudCapture implements VoiceCloudCapture {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  @override
  Future<bool> hasMic() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> startWav() async {
    final granted = await hasMic();
    if (!granted) return false;
    _path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}advisor_stt_${DateTime.now().millisecondsSinceEpoch}.wav';
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _path!,
      );
      return true;
    } catch (_) {
      _path = null;
      return false;
    }
  }

  @override
  Future<List<int>?> stopWav() async {
    final path = _path;
    _path = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (path == null || !File(path).existsSync()) return null;
    try {
      final bytes = await File(path).readAsBytes();
      return bytes.length > 44 ? bytes : null;
    } finally {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    final path = _path;
    _path = null;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}
