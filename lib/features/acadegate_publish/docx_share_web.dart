// Web-only implementation — dart:html is expected here.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> shareDocxBytesPlatform({
  required Uint8List bytes,
  required String name,
}) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', name)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
