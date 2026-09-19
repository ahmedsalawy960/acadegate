import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareThesisFilePlatform({
  required Uint8List bytes,
  required String name,
}) async {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'bin';
  if (defaultTargetPlatform == TargetPlatform.windows) {
    var savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save file',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (savePath == null || savePath.isEmpty) return;
    if (!savePath.toLowerCase().endsWith('.$ext')) {
      savePath = '$savePath.$ext';
    }
    await File(savePath).writeAsBytes(bytes);
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: name,
    ),
  );
}
