import 'dart:convert';

import 'citation_http.dart';

class CrossrefUpdateNotice {
  final String type;
  final String? label;
  final String? noticeDoi;
  final String? targetDoi;
  final int? year;

  const CrossrefUpdateNotice({
    required this.type,
    this.label,
    this.noticeDoi,
    this.targetDoi,
    this.year,
  });
}

class CrossrefWork {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? url;
  final bool retractedByRelation;
  final List<CrossrefUpdateNotice> updateTo;
  final String abstractText;

  const CrossrefWork({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.url,
    this.retractedByRelation = false,
    this.updateTo = const [],
    this.abstractText = '',
  });
}

class CrossrefClient {
  CrossrefClient._();

  static final CrossrefClient instance = CrossrefClient._();

  static const _base = 'https://api.crossref.org/works';
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.app)',
  };

  Future<CrossrefWork?> lookupDoi(String doi) async {
    final normalized = doi.trim().replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    final uri = Uri.parse('$_base/${Uri.encodeComponent(normalized)}');
    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Crossref: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    if (message == null) return null;
    return _fromMessage(message);
  }

  Future<List<CrossrefWork>> searchBibliographic(
    String query, {
    int rows = 5,
    int? fromYear,
    bool journalArticlesOnly = false,
  }) async {
    if (query.trim().length < 3) return const [];

    final filters = <String>[
      'has-doi:true',
      if (fromYear != null) 'from-pub-date:$fromYear-01-01',
      if (journalArticlesOnly) 'type:journal-article',
    ];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'query': query.trim(),
        'rows': '${rows.clamp(1, 50)}',
        if (filters.isNotEmpty) 'filter': filters.join(','),
      },
    );

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 25),
        );

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    final items = message?['items'] as List<dynamic>? ?? [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(_fromMessage)
        .where((w) => w.title.isNotEmpty)
        .toList();
  }

  Future<List<CrossrefWork>> searchByAuthor(String author, {int rows = 8}) async {
    if (author.trim().length < 2) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'query.author': author.trim(),
        'rows': '$rows',
      },
    );

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 25),
        );

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    final items = message?['items'] as List<dynamic>? ?? [];

    return items
        .whereType<Map<String, dynamic>>()
        .map(_fromMessage)
        .where((w) => w.title.isNotEmpty)
        .toList();
  }

  CrossrefWork _fromMessage(Map<String, dynamic> message) {
    final titles = message['title'] as List<dynamic>?;
    final title = titles?.isNotEmpty == true ? titles!.first.toString() : '';

    final authorsList = message['author'] as List<dynamic>? ?? [];
    final authors = authorsList
        .map((a) {
          final map = a as Map<String, dynamic>;
          final family = map['family']?.toString() ?? '';
          final given = map['given']?.toString() ?? '';
          return '$given $family'.trim();
        })
        .where((s) => s.isNotEmpty)
        .take(4)
        .join('; ');

    final issued = message['issued'] as Map<String, dynamic>?;
    final dateParts = issued?['date-parts'] as List<dynamic>?;
    int? year;
    if (dateParts != null && dateParts.isNotEmpty) {
      final first = dateParts.first as List<dynamic>?;
      if (first != null && first.isNotEmpty) {
        year = int.tryParse(first.first.toString());
      }
    }

    final doi = message['DOI']?.toString();
    final url = doi != null ? 'https://doi.org/$doi' : null;

    return CrossrefWork(
      title: title,
      doi: doi,
      year: year,
      authors: authors.isEmpty ? null : authors,
      url: url,
      retractedByRelation: _hasRetractedBy(message),
      updateTo: _parseUpdateTo(message, noticeDoi: doi),
      abstractText: _abstractFromMessage(message),
    );
  }

  static String _abstractFromMessage(Map<String, dynamic> message) {
    final raw = message['abstract']?.toString() ?? '';
    if (raw.trim().isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Notices that update [doi] (retraction, correction, expression of concern).
  Future<List<CrossrefUpdateNotice>> updatesFor(String doi) async {
    final normalized = doi
        .trim()
        .replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    if (normalized.length < 6) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'filter': 'updates:$normalized',
        'rows': '20',
      },
    );

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
      const Duration(seconds: 25),
    );
    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    final items = message?['items'] as List<dynamic>? ?? [];
    final out = <CrossrefUpdateNotice>[];
    for (final item in items.whereType<Map<String, dynamic>>()) {
      final noticeDoi = item['DOI']?.toString();
      final parsed = _parseUpdateTo(item, noticeDoi: noticeDoi);
      if (parsed.isNotEmpty) {
        out.addAll(parsed);
        continue;
      }
      final titles = item['title'] as List<dynamic>?;
      final title = titles?.isNotEmpty == true ? titles!.first.toString() : '';
      if (title.trim().isEmpty) continue;
      out.add(
        CrossrefUpdateNotice(
          type: title,
          label: title,
          noticeDoi: noticeDoi,
          targetDoi: normalized,
        ),
      );
    }
    return out;
  }

  static bool _hasRetractedBy(Map<String, dynamic> message) {
    final relation = message['relation'];
    if (relation is! Map) return false;
    for (final key in ['is-retracted-by', 'is-withdrawn-by']) {
      final value = relation[key];
      if (value is List && value.isNotEmpty) return true;
    }
    return false;
  }

  static List<CrossrefUpdateNotice> _parseUpdateTo(
    Map<String, dynamic> message, {
    String? noticeDoi,
  }) {
    final raw = message['update-to'];
    if (raw is! List) return const [];
    final issued = message['issued'] as Map<String, dynamic>?;
    final dateParts = issued?['date-parts'] as List<dynamic>?;
    int? year;
    if (dateParts != null && dateParts.isNotEmpty) {
      final first = dateParts.first as List<dynamic>?;
      if (first != null && first.isNotEmpty) {
        year = int.tryParse(first.first.toString());
      }
    }
    return raw.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return CrossrefUpdateNotice(
        type: map['type']?.toString() ?? '',
        label: map['label']?.toString(),
        noticeDoi: noticeDoi ?? map['DOI']?.toString(),
        targetDoi: map['DOI']?.toString(),
        year: year,
      );
    }).toList();
  }
}
