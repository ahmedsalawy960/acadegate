import 'dart:typed_data';

import 'docx_share_platform.dart'
    if (dart.library.html) 'docx_share_web.dart'
    if (dart.library.io) 'docx_share_io.dart';

Future<void> shareDocxBytes({
  required Uint8List bytes,
  required String name,
}) =>
    shareDocxBytesPlatform(bytes: bytes, name: name);
