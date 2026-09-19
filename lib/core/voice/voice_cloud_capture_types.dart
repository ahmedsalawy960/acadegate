abstract class VoiceCloudCapture {
  Future<bool> hasMic();
  Future<bool> startWav();
  Future<List<int>?> stopWav();
  Future<void> cancel();
}
