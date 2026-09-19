import 'dart:typed_data';

import 'thesis_studio_file_share_stub.dart'
    if (dart.library.html) 'thesis_studio_file_share_web.dart'
    if (dart.library.io) 'thesis_studio_file_share_io.dart';

Future<void> shareThesisFile({
  required Uint8List bytes,
  required String name,
}) =>
    shareThesisFilePlatform(bytes: bytes, name: name);
