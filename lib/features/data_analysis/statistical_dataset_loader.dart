import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import 'statistical_dataset.dart';

class StatisticalDatasetLoader {
  StatisticalDatasetLoader._();

  static final StatisticalDatasetLoader instance = StatisticalDatasetLoader._();

  /// مثال CSV جاهز للتجربة بدون رفع ملف.
  static const sampleCsvContent = '''group,score
A,72
A,68
A,75
A,70
A,73
B,81
B,79
B,85
B,82
B,80
''';

  StatisticalDataset loadSample() {
    return parse(
      content: sampleCsvContent,
      fileName: 'sample_ttest.csv',
    );
  }

  Future<StatisticalDataset> pickAndLoad() async {
    final readFromPath = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt', 'tsv'],
      withData: !readFromPath,
      allowMultiple: false,
      lockParentWindow: true,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception(appTr('لم يتم اختيار ملف', 'No file selected'));
    }

    final file = result.files.first;
    final bytes = await _readBytes(file);
    if (bytes == null || bytes.isEmpty) {
      throw Exception(
        appTr(
          'تعذر قراءة الملف — جرّب CSV أصغر أو «مثال CSV»',
          'Could not read file — try a smaller CSV or use «Sample CSV»',
        ),
      );
    }

    final content = _decode(bytes);
    return parse(
      content: content,
      fileName: file.name,
    );
  }

  Future<List<int>?> _readBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }

    final path = file.path;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      final ioFile = File(path);
      if (await ioFile.exists()) {
        return ioFile.readAsBytes();
      }
    }

    return null;
  }

  String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  StatisticalDataset parse({
    required String content,
    required String fileName,
  }) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      throw FormatException(
        appTr('الملف فارغ', 'File is empty'),
      );
    }

    final delimiter = _detectDelimiter(lines.first, fileName);
    final headers = _parseLine(lines.first, delimiter);
    if (headers.isEmpty) {
      throw FormatException(
        appTr('لا توجد أعمدة في الملف', 'No columns in file'),
      );
    }

    final rows = <List<String>>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = _parseLine(lines[i], delimiter);
      if (cells.every((c) => c.trim().isEmpty)) continue;
      rows.add(_padRow(cells, headers.length));
    }

    if (rows.isEmpty) {
      throw FormatException(
        appTr('لا توجد صفوف بيانات', 'No data rows found'),
      );
    }

    return StatisticalDataset(
      fileName: fileName,
      headers: headers,
      rows: rows,
    );
  }

  String _detectDelimiter(String headerLine, String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.tsv') || headerLine.contains('\t')) return '\t';
    if (headerLine.contains(';')) return ';';
    return ',';
  }

  List<String> _parseLine(String line, String delimiter) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delimiter && !inQuotes) {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  List<String> _padRow(List<String> cells, int length) {
    if (cells.length >= length) return cells.take(length).toList();
    return [...cells, ...List.filled(length - cells.length, '')];
  }
}
