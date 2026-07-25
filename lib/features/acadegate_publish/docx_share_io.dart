import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareDocxBytesPlatform({
  required Uint8List bytes,
  required String name,
}) async {
  // Windows share sheet often fails ("Try that again") — use Save dialog instead.
  if (defaultTargetPlatform == TargetPlatform.windows) {
    var savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Word document',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['docx'],
    );
    if (savePath == null || savePath.isEmpty) return;
    if (!savePath.toLowerCase().endsWith('.docx')) {
      savePath = '$savePath.docx';
    }
    await File(savePath).writeAsBytes(bytes);
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ),
      ],
      subject: name,
    ),
  );
}
