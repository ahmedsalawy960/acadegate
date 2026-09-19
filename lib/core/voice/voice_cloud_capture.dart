import 'voice_cloud_capture_types.dart';
import 'voice_cloud_capture_stub.dart'
    if (dart.library.io) 'voice_cloud_capture_io.dart';

export 'voice_cloud_capture_types.dart';

VoiceCloudCapture? voiceCloudCapture() => createVoiceCloudCapture();
