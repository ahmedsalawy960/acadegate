import 'dart:convert';

import 'package:http/http.dart' as http;

/// تصنيف Scimago الرسمي (Q1–Q4) من بيانات SJR العامة.
class ScimagoJournalInfo {
  final String title;
  final String quartile;
  final double? sjr;

  const ScimagoJournalInfo({
    required this.title,
    required this.quartile,
    this.sjr,
  });
}

class ScimagoQuartileService {
  ScimagoQuartileService._();

  static final ScimagoQuartileService instance = ScimagoQuartileService._();

  static const _csvUrl =
      'https://raw.githubusercontent.com/alpha912/PaperImpact/main/data/scimagojr%202023.csv';

  final _byIssn = <String, ScimagoJournalInfo>{};
  final _byTitle = <String, ScimagoJournalInfo>{};
  bool _loaded = false;
  Future<void>? _loading;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loading ??= _load();
    await _loading;
  }

  ScimagoJournalInfo? lookup({
    List<String> issns = const [],
    String? title,
  }) {
    for (final issn in issns) {
      final normalized = _normalizeIssn(issn);
      if (normalized.isEmpty) continue;
      final hit = _byIssn[normalized];
      if (hit != null) return hit;
    }

    if (title != null && title.trim().isNotEmpty) {
      return _byTitle[_normalizeTitle(title)];
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final response = await http.get(Uri.parse(_csvUrl)).timeout(
            const Duration(minutes: 3),
          );
      if (response.statusCode != 200) return;

      final body = utf8.decode(response.bodyBytes);
      final lines = const LineSplitter().convert(body);
      if (lines.isEmpty) return;

      final header = _parseLine(lines.first);
      final titleIdx = _indexOf(header, 'Title');
      final issnIdx = _indexOf(header, 'Issn');
      final quartileIdx = _indexOf(header, 'SJR Best Quartile');
      final sjrIdx = _indexOf(header, 'SJR');
      if (titleIdx < 0 || quartileIdx < 0) return;

      for (var i = 1; i < lines.length; i++) {
        final cols = _parseLine(lines[i]);
        if (cols.length <= quartileIdx) continue;

        final journalTitle = cols[titleIdx].trim();
        final quartile = cols[quartileIdx].trim().toUpperCase();
        if (journalTitle.isEmpty || !_isQuartile(quartile)) continue;

        final sjr = sjrIdx >= 0 && sjrIdx < cols.length
            ? _parseSjr(cols[sjrIdx])
            : null;
        final info = ScimagoJournalInfo(
          title: journalTitle,
          quartile: quartile,
          sjr: sjr,
        );

        _byTitle[_normalizeTitle(journalTitle)] = info;

        if (issnIdx >= 0 && issnIdx < cols.length) {
          for (final issn in _splitIssns(cols[issnIdx])) {
            _byIssn[issn] = info;
          }
        }
      }

      _loaded = true;
    } catch (_) {
      // يبقى التقدير من OpenAlex كاحتياط.
    }
  }

  static int _indexOf(List<String> header, String name) {
    final target = name.toLowerCase();
    for (var i = 0; i < header.length; i++) {
      if (header[i].trim().toLowerCase() == target) return i;
    }
    return -1;
  }

  static List<String> _parseLine(String line) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ';' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  static bool _isQuartile(String value) {
    return value == 'Q1' || value == 'Q2' || value == 'Q3' || value == 'Q4';
  }

  static double? _parseSjr(String raw) {
    final cleaned = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  static Iterable<String> _splitIssns(String raw) sync* {
    for (final part in raw.split(RegExp(r'[,;]'))) {
      final normalized = _normalizeIssn(part);
      if (normalized.isNotEmpty) yield normalized;
    }
  }

  static String _normalizeIssn(String value) {
    return value.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
  }

  static String _normalizeTitle(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
