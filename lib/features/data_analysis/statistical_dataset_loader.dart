import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import 'statistical_dataset.dart';
import 'statistical_table_file_parser.dart';

class StatisticalDatasetLoader {
  StatisticalDatasetLoader._();

  static final StatisticalDatasetLoader instance = StatisticalDatasetLoader._();

  static const allowedExtensions = [
    'csv',
    'txt',
    'tsv',
    'xlsx',
    'docx',
  ];

  /// مثال متعدد الأعمدة (ليس عمودين فقط) — للتجربة بدون رفع ملف.
  static const sampleCsvContent = '''id,group,score,pretest,gender
1,A,72,65,F
2,A,68,62,F
3,A,75,70,M
4,A,70,66,M
5,A,73,68,F
6,B,81,74,M
7,B,79,72,F
8,B,85,78,M
9,B,82,76,F
10,B,80,75,M
11,C,90,82,F
12,C,88,80,M
13,C,92,85,F
14,C,87,79,M
15,C,91,84,F
''';

  StatisticalDataset loadSample() {
    return parse(
      content: sampleCsvContent,
      fileName: 'sample_multicolumn.csv',
    );
  }

  Future<StatisticalDataset> pickAndLoad() async {
    final readFromPath = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
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
          'تعذر قراءة الملف — جرّب CSV/Excel أصغر أو «مثال CSV»',
          'Could not read file — try a smaller CSV/Excel or use «Sample CSV»',
        ),
      );
    }

    return loadBytes(
      bytes: Uint8List.fromList(bytes),
      fileName: file.name,
    );
  }

  StatisticalDataset loadBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.docx')) {
      return StatisticalTableFileParser.parseBytes(
        bytes: bytes,
        fileName: fileName,
      );
    }

    if (lower.endsWith('.xls')) {
      throw FormatException(
        appTr(
          'صيغة .xls القديمة غير مدعومة — احفظ الملف كـ .xlsx أو CSV من Excel',
          'Legacy .xls is not supported — save as .xlsx or CSV from Excel',
        ),
      );
    }

    final content = _decode(bytes);
    return parse(content: content, fileName: fileName);
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

    return StatisticalDataset.sanitized(
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
