import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _cacheFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/scimagojr_2023.csv');
}

Future<String?> readScimagoCatalogCache() async {
  try {
    final file = await _cacheFile();
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    if (text.length < 1000 || !text.startsWith('Rank;')) return null;
    return text;
  } catch (_) {
    return null;
  }
}

Future<void> writeScimagoCatalogCache(String body) async {
  if (body.length < 1000 || !body.startsWith('Rank;')) return;
  try {
    final file = await _cacheFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(body, flush: true);
  } catch (_) {}
}
