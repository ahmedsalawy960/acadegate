import 'dart:convert';

import 'package:http/http.dart' as http;

/// تصنيف Scimago الرسمي (Q1–Q4) من بيانات SJR العامة.
class ScimagoJournalInfo {
  final String title;
  final String quartile;
  final double? sjr;
  final String publisher;
  final String country;
  final String categories;
  final String issn;
  final int rank;

  const ScimagoJournalInfo({
    required this.title,
    required this.quartile,
    this.sjr,
    this.publisher = '',
    this.country = '',
    this.categories = '',
    this.issn = '',
    this.rank = 0,
  });

  String get browseUrl => ScimagoQuartileService.journalBrowseUrl(title);

  String get submitSearchUrl =>
      ScimagoQuartileService.journalSubmitSearchUrl(title);
}

class ScimagoQuartileService {
  ScimagoQuartileService._();

  static final ScimagoQuartileService instance = ScimagoQuartileService._();

  static const _csvUrl =
      'https://raw.githubusercontent.com/alpha912/PaperImpact/main/data/scimagojr%202023.csv';

  final _byIssn = <String, ScimagoJournalInfo>{};
  final _byTitle = <String, ScimagoJournalInfo>{};
  final List<ScimagoJournalInfo> _catalog = [];
  bool _loaded = false;
  Future<void>? _loading;

  List<ScimagoJournalInfo> get catalog => List.unmodifiable(_catalog);

  int get catalogCount => _catalog.length;

  static String journalBrowseUrl(String title) =>
      journalMetricsUrl(title);

  /// Scimago — تصنيف ومقاييس فقط، لا ينفّذ البحث تلقائياً من الرابط.
  static String journalMetricsUrl(String title) {
    return 'https://www.scimagojr.com/journalsearch.php?q=${Uri.encodeQueryComponent(title)}';
  }

  static String journalSubmitSearchUrl(String title) {
    final parts = ['"$title"', 'submit manuscript', 'online submission'];
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(parts.join(' '))}';
  }

  List<ScimagoJournalInfo> searchCatalog({
    String query = '',
    String? quartile,
    int limit = 250,
  }) {
    final normalized = _normalizeTitle(query);
    Iterable<ScimagoJournalInfo> results = _catalog;

    if (quartile != null && quartile.isNotEmpty) {
      final q = quartile.toUpperCase();
      results = results.where((j) => j.quartile == q);
    }

    if (normalized.isNotEmpty) {
      results = results.where((journal) {
        final haystack = _normalizeTitle(
          '${journal.title} ${journal.publisher} ${journal.categories} ${journal.country}',
        );
        return haystack.contains(normalized) ||
            normalized
                .split(' ')
                .where((token) => token.length >= 2)
                .every((token) => haystack.contains(token));
      });
    }

    return results.take(limit).toList();
  }

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
      final rankIdx = _indexOf(header, 'Rank');
      final titleIdx = _indexOf(header, 'Title');
      final issnIdx = _indexOf(header, 'Issn');
      final quartileIdx = _indexOf(header, 'SJR Best Quartile');
      final sjrIdx = _indexOf(header, 'SJR');
      final publisherIdx = _indexOf(header, 'Publisher');
      final countryIdx = _indexOf(header, 'Country');
      final categoriesIdx = _indexOf(header, 'Categories');
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
        final rank = rankIdx >= 0 && rankIdx < cols.length
            ? int.tryParse(cols[rankIdx].trim()) ?? 0
            : 0;
        final info = ScimagoJournalInfo(
          title: journalTitle,
          quartile: quartile,
          sjr: sjr,
          publisher: _col(cols, publisherIdx),
          country: _col(cols, countryIdx),
          categories: _col(cols, categoriesIdx),
          issn: issnIdx >= 0 && issnIdx < cols.length
              ? cols[issnIdx].trim()
              : '',
          rank: rank,
        );

        _catalog.add(info);
        _byTitle[_normalizeTitle(journalTitle)] = info;

        if (issnIdx >= 0 && issnIdx < cols.length) {
          for (final issn in _splitIssns(cols[issnIdx])) {
            _byIssn[issn] = info;
          }
        }
      }

      _catalog.sort((a, b) {
        if (a.rank > 0 && b.rank > 0) return a.rank.compareTo(b.rank);
        return a.title.compareTo(b.title);
      });

      _loaded = true;
    } catch (_) {
      if (_catalog.isEmpty) {
        _loaded = true;
      }
    }
  }

  static String _col(List<String> cols, int index) {
    if (index < 0 || index >= cols.length) return '';
    return cols[index].trim();
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
