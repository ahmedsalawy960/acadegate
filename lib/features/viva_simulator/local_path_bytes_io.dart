import 'dart:io';

Future<List<int>?> readLocalPathBytes(String path) async {
  final file = File(path);
  if (await file.exists()) return file.readAsBytes();
  return null;
}
