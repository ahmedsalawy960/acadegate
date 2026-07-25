import 'dart:typed_data';

Future<void> shareDocxBytesPlatform({
  required Uint8List bytes,
  required String name,
}) {
  throw UnsupportedError('DOCX share not available on this platform');
}
