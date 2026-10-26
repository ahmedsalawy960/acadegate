import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'scimago_catalog_cache.dart';

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
    if (_loaded && _catalog.isNotEmpty) return;
    _loading ??= _load();
    try {
      await _loading;
    } catch (_) {
      _loading = null;
      rethrow;
    }
    if (!_loaded) _loading = null;
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
      final body = await _readCatalogText();
      if (body == null) return;

      final rows = await compute(parseScimagoCsvRows, body);
      if (rows.isEmpty) {
        debugPrint('scimago catalog: parsed zero journals');
        return;
      }

      _catalog.clear();
      _byIssn.clear();
      _byTitle.clear();
      for (final row in rows) {
        final info = ScimagoJournalInfo(
          title: row['title']?.toString() ?? '',
          quartile: row['quartile']?.toString() ?? '',
          sjr: row['sjr'] is num ? (row['sjr'] as num).toDouble() : null,
          publisher: row['publisher']?.toString() ?? '',
          country: row['country']?.toString() ?? '',
          categories: row['categories']?.toString() ?? '',
          issn: row['issn']?.toString() ?? '',
          rank: row['rank'] is int ? row['rank'] as int : 0,
        );
        if (info.title.isEmpty) continue;
        _catalog.add(info);
        _byTitle[_normalizeTitle(info.title)] = info;
        for (final issn in _splitIssns(info.issn)) {
          _byIssn[issn] = info;
        }
      }

      _catalog.sort((a, b) {
        if (a.rank > 0 && b.rank > 0) return a.rank.compareTo(b.rank);
        return a.title.compareTo(b.title);
      });

      _loaded = _catalog.isNotEmpty;
    } catch (e) {
      debugPrint('scimago catalog: $e');
      _loaded = false;
    }
  }

  Future<String?> _readCatalogText() async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(Uri.parse(_csvUrl)).timeout(
              const Duration(seconds: 90),
            );
        if (response.statusCode == 200 && response.bodyBytes.length > 1000) {
          final text = utf8.decode(response.bodyBytes);
          await writeScimagoCatalogCache(text);
          return text;
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }
    final cached = await readScimagoCatalogCache();
    if (cached != null) {
      debugPrint('scimago catalog: using saved file after $lastError');
      return cached;
    }
    debugPrint('scimago catalog: download failed: $lastError');
    return null;
  }

  static List<String> parseHeader(String line) => parseCsvLine(line);

  static String columnValue(List<String> cols, int index) {
    if (index < 0 || index >= cols.length) return '';
    return cols[index].trim();
  }

  static int columnIndex(List<String> header, String name) {
    final target = name.toLowerCase();
    for (var i = 0; i < header.length; i++) {
      if (header[i].trim().toLowerCase() == target) return i;
    }
    return -1;
  }

  static List<String> parseCsvLine(String line) {
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

  static bool isQuartile(String value) {
    return value == 'Q1' || value == 'Q2' || value == 'Q3' || value == 'Q4';
  }

  static double? parseSjr(String raw) {
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

/// Runs off the UI isolate so opening the journal list stays responsive
/// for every manuscript, not one catalog file.
List<Map<String, Object?>> parseScimagoCsvRows(String body) {
  final lines = const LineSplitter().convert(body);
  if (lines.isEmpty) return const [];

  final header = ScimagoQuartileService.parseHeader(lines.first);
  final rankIdx = ScimagoQuartileService.columnIndex(header, 'Rank');
  final titleIdx = ScimagoQuartileService.columnIndex(header, 'Title');
  final issnIdx = ScimagoQuartileService.columnIndex(header, 'Issn');
  final quartileIdx =
      ScimagoQuartileService.columnIndex(header, 'SJR Best Quartile');
  final sjrIdx = ScimagoQuartileService.columnIndex(header, 'SJR');
  final publisherIdx = ScimagoQuartileService.columnIndex(header, 'Publisher');
  final countryIdx = ScimagoQuartileService.columnIndex(header, 'Country');
  final categoriesIdx =
      ScimagoQuartileService.columnIndex(header, 'Categories');
  if (titleIdx < 0 || quartileIdx < 0) return const [];

  final rows = <Map<String, Object?>>[];
  for (var i = 1; i < lines.length; i++) {
    final cols = ScimagoQuartileService.parseCsvLine(lines[i]);
    if (cols.length <= quartileIdx) continue;
    final title = cols[titleIdx].trim();
    final quartile = cols[quartileIdx].trim().toUpperCase();
    if (title.isEmpty || !ScimagoQuartileService.isQuartile(quartile)) continue;
    rows.add({
      'title': title,
      'quartile': quartile,
      'sjr': sjrIdx >= 0 && sjrIdx < cols.length
          ? ScimagoQuartileService.parseSjr(cols[sjrIdx])
          : null,
      'publisher': ScimagoQuartileService.columnValue(cols, publisherIdx),
      'country': ScimagoQuartileService.columnValue(cols, countryIdx),
      'categories': ScimagoQuartileService.columnValue(cols, categoriesIdx),
      'issn': issnIdx >= 0 && issnIdx < cols.length ? cols[issnIdx].trim() : '',
      'rank': rankIdx >= 0 && rankIdx < cols.length
          ? int.tryParse(cols[rankIdx].trim()) ?? 0
          : 0,
    });
  }
  return rows;
}
