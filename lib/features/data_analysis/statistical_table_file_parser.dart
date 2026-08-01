import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/locale/app_translate.dart';
import 'statistical_dataset.dart';

/// Extracts the largest useful table from DOCX / XLSX for statistical import.
class StatisticalTableFileParser {
  StatisticalTableFileParser._();

  static StatisticalDataset parseBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.docx')) {
      return _fromDocx(bytes, fileName);
    }
    if (lower.endsWith('.xlsx')) {
      return _fromXlsx(bytes, fileName);
    }
    throw FormatException(
      appTr(
        'صيغة غير مدعومة — استخدم CSV أو XLSX أو DOCX (جدول بيانات)',
        'Unsupported format — use CSV, XLSX, or DOCX (data table)',
      ),
    );
  }

  static StatisticalDataset _fromDocx(Uint8List bytes, String fileName) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) {
      throw FormatException(
        appTr(
          'ملف Word غير صالح',
          'Invalid Word file',
        ),
      );
    }

    final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
    final tables = doc.findAllElements('tbl').toList();
    if (tables.isEmpty) {
      tables.addAll(doc.findAllElements('w:tbl'));
    }
    if (tables.isEmpty) {
      throw FormatException(
        appTr(
          'لا يوجد جدول بيانات داخل ملف Word — أدرج جدولاً (أعمدة مثل group,score) أو صدّر CSV/Excel',
          'No data table found in the Word file — insert a table (e.g. group,score) or export CSV/Excel',
        ),
      );
    }

    StatisticalDataset? best;
    for (final table in tables) {
      final grid = _docxTableToGrid(table);
      if (grid.length < 2 || grid.first.isEmpty) continue;
      final candidate = _gridToDataset(grid, fileName);
      if (best == null || candidate.rowCount > best.rowCount) {
        best = candidate;
      }
    }

    if (best == null || best.rowCount == 0) {
      throw FormatException(
        appTr(
          'تعذر قراءة جدول Word — تأكد أن الصف الأول عناوين أعمدة',
          'Could not read Word table — first row should be column headers',
        ),
      );
    }
    return best;
  }

  static List<List<String>> _docxTableToGrid(XmlElement table) {
    final rows = <List<String>>[];
    for (final tr in table.children.whereType<XmlElement>()) {
      if (tr.localName != 'tr') continue;
      final cells = <String>[];
      for (final tc in tr.children.whereType<XmlElement>()) {
        if (tc.localName != 'tc') continue;
        final texts = tc
            .findAllElements('t')
            .map((e) => e.innerText)
            .join()
            .trim();
        if (texts.isEmpty) {
          // Also try w:t without namespace strip issues.
          final alt = tc
              .findAllElements('w:t')
              .map((e) => e.innerText)
              .join()
              .trim();
          cells.add(alt);
        } else {
          cells.add(texts);
        }
      }
      if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
    }
    return rows;
  }

  static StatisticalDataset _fromXlsx(Uint8List bytes, String fileName) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final shared = _loadSharedStrings(archive);
    final sheetPath = _firstWorksheetPath(archive);
    final sheetEntry = archive.findFile(sheetPath);
    if (sheetEntry == null) {
      throw FormatException(
        appTr('تعذر فتح ورقة Excel', 'Could not open Excel sheet'),
      );
    }

    final doc = XmlDocument.parse(utf8.decode(sheetEntry.content as List<int>));
    final grid = <List<String>>[];

    for (final row in doc.findAllElements('row')) {
      final cellsByCol = <int, String>{};
      for (final cell in row.findAllElements('c')) {
        final ref = cell.getAttribute('r') ?? '';
        final col = _columnIndexFromRef(ref);
        if (col < 0) continue;
        cellsByCol[col] = _cellValue(cell, shared);
      }
      if (cellsByCol.isEmpty) continue;
      final last = cellsByCol.keys.reduce((a, b) => a > b ? a : b);
      final line = List<String>.generate(
        last + 1,
        (i) => cellsByCol[i] ?? '',
      );
      if (line.any((c) => c.trim().isNotEmpty)) grid.add(line);
    }

    if (grid.length < 2) {
      throw FormatException(
        appTr(
          'ورقة Excel فارغة أو بدون صف عناوين',
          'Excel sheet is empty or missing a header row',
        ),
      );
    }

    // Normalize row widths.
    final width = grid
        .map((r) => r.length)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 64);
    final normalized = grid
        .map((r) => [
              ...r.take(width),
              ...List.filled(width > r.length ? width - r.length : 0, ''),
            ])
        .toList();

    return _gridToDataset(normalized, fileName);
  }

  static List<String> _loadSharedStrings(Archive archive) {
    final entry = archive.findFile('xl/sharedStrings.xml');
    if (entry == null) return const [];
    try {
      final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      final out = <String>[];
      for (final si in doc.findAllElements('si')) {
        final text = si.findAllElements('t').map((e) => e.innerText).join();
        out.add(text.trim());
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static String _firstWorksheetPath(Archive archive) {
    // Prefer workbook order when available.
    final wb = archive.findFile('xl/workbook.xml');
    if (wb != null) {
      try {
        final doc = XmlDocument.parse(utf8.decode(wb.content as List<int>));
        final sheets = doc.findAllElements('sheet').toList();
        if (sheets.isNotEmpty) {
          // Default first sheet is usually worksheets/sheet1.xml
          final rels = archive.findFile('xl/_rels/workbook.xml.rels');
          if (rels != null) {
            final rid = sheets.first.getAttribute('r:id') ??
                sheets.first.getAttribute('id') ??
                '';
            final relDoc =
                XmlDocument.parse(utf8.decode(rels.content as List<int>));
            for (final rel in relDoc.findAllElements('Relationship')) {
              if (rel.getAttribute('Id') == rid) {
                final target = rel.getAttribute('Target') ?? '';
                if (target.isNotEmpty) {
                  final path = target.startsWith('/')
                      ? target.substring(1)
                      : 'xl/${target.replaceFirst(RegExp(r'^/+'), '')}';
                  return path.replaceAll('\\', '/');
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    final sheet = archive.files.firstWhere(
      (f) =>
          f.isFile &&
          f.name.replaceAll('\\', '/').toLowerCase().startsWith(
                'xl/worksheets/sheet',
              ),
      orElse: () => throw FormatException(
        appTr('لا توجد ورقة عمل في Excel', 'No worksheet found in Excel'),
      ),
    );
    return sheet.name.replaceAll('\\', '/');
  }

  static String _cellValue(XmlElement cell, List<String> shared) {
    final type = (cell.getAttribute('t') ?? '').toLowerCase();
    final v = cell.getElement('v')?.innerText.trim() ?? '';
    if (type == 's') {
      final idx = int.tryParse(v);
      if (idx != null && idx >= 0 && idx < shared.length) {
        return shared[idx];
      }
      return v;
    }
    if (type == 'inlineStr') {
      return cell.findAllElements('t').map((e) => e.innerText).join().trim();
    }
    return v;
  }

  static int _columnIndexFromRef(String ref) {
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(ref);
    if (match == null) return -1;
    final letters = match.group(1)!.toUpperCase();
    var col = 0;
    for (final code in letters.codeUnits) {
      col = col * 26 + (code - 64);
    }
    return col - 1;
  }

  static StatisticalDataset _gridToDataset(
    List<List<String>> grid,
    String fileName,
  ) {
    final headers = grid.first.map((h) => h.trim()).toList();
    // Drop empty trailing headers.
    while (headers.isNotEmpty && headers.last.isEmpty) {
      headers.removeLast();
    }
    if (headers.isEmpty || headers.every((h) => h.isEmpty)) {
      throw FormatException(
        appTr(
          'الصف الأول يجب أن يحتوي أسماء الأعمدة',
          'The first row must contain column names',
        ),
      );
    }

    final width = headers.length;
    final rows = <List<String>>[];
    for (var i = 1; i < grid.length; i++) {
      final raw = grid[i];
      final row = List<String>.generate(
        width,
        (j) => j < raw.length ? raw[j].trim() : '',
      );
      if (row.every((c) => c.isEmpty)) continue;
      rows.add(row);
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
}
