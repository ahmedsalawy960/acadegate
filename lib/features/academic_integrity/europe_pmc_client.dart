import 'dart:convert';

import 'citation_http.dart';

class EuropePmcWork {
  final String title;
  final String? doi;
  final int? year;
  final String authors;
  final String journal;
  final String abstractText;
  final String url;

  /// PubMed Central id when the article is in PMC (open-access full text).
  final String pmcid;

  const EuropePmcWork({
    required this.title,
    this.doi,
    this.year,
    this.authors = '',
    this.journal = '',
    this.abstractText = '',
    this.url = '',
    this.pmcid = '',
  });
}

/// Open abstracts + free-text search via Europe PMC.
class EuropePmcClient {
  EuropePmcClient._();

  static final EuropePmcClient instance = EuropePmcClient._();

  static const _base = 'https://www.ebi.ac.uk/europepmc/webservices/rest/search';

  Future<String> abstractForDoi(String doi) async {
    final normalized = doi
        .trim()
        .replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    if (normalized.length < 6) return '';
    final works = await search('DOI:"$normalized"', pageSize: 1);
    if (works.isEmpty) return '';
    return works.first.abstractText;
  }

  Future<List<EuropePmcWork>> search(
    String query, {
    int pageSize = 20,
  }) async {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.length < 3) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'query': q,
        'format': 'json',
        'resultType': 'core',
        'pageSize': '${pageSize.clamp(1, 50)}',
      },
    );
    try {
      final response = await CitationHttp.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultList =
          data['resultList'] as Map<String, dynamic>? ?? const {};
      final results = resultList['result'] as List<dynamic>? ?? const [];
      return [
        for (final raw in results)
          if (raw is Map) _fromMap(Map<String, dynamic>.from(raw)),
      ].where((w) => w.title.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  EuropePmcWork _fromMap(Map<String, dynamic> map) {
    final doi = (map['doi'] ?? '').toString().trim();
    final pmid = (map['pmid'] ?? '').toString().trim();
    final pmcid = (map['pmcid'] ?? '').toString().trim();
    final yearRaw = map['pubYear']?.toString() ?? '';
    final year = int.tryParse(yearRaw);
    String url = '';
    if (doi.isNotEmpty) {
      url = 'https://doi.org/$doi';
    } else if (pmcid.isNotEmpty) {
      url = 'https://europepmc.org/article/PMC/$pmcid';
    } else if (pmid.isNotEmpty) {
      url = 'https://europepmc.org/article/MED/$pmid';
    }
    return EuropePmcWork(
      title: (map['title'] ?? '').toString().trim(),
      doi: doi.isEmpty ? null : doi,
      year: year,
      authors: (map['authorString'] ?? '').toString().trim(),
      journal: (map['journalTitle'] ?? '').toString().trim(),
      abstractText: (map['abstractText'] ?? '').toString().trim(),
      url: url,
      pmcid: pmcid,
    );
  }

  /// Open-access full text (JATS XML flattened to readable sections) for a
  /// DOI, when the article is in PubMed Central. Empty when unavailable.
  Future<String> fullTextForDoi(String doi) async {
    final normalized = doi
        .trim()
        .replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    if (normalized.length < 6) return '';
    final works = await search('DOI:"$normalized" AND OPEN_ACCESS:Y',
        pageSize: 1);
    if (works.isEmpty) return '';
    final pmcid = works.first.pmcid;
    if (pmcid.isEmpty) return '';
    return fullTextForPmcid(pmcid);
  }

  /// Full text by PMC id. Empty when the article has no OA full text here.
  Future<String> fullTextForPmcid(String pmcid) async {
    final id = pmcid.trim().replaceAll(RegExp(r'^PMC', caseSensitive: false), '');
    if (id.isEmpty) return '';
    final uri = Uri.parse(
        'https://www.ebi.ac.uk/europepmc/webservices/rest/PMC$id/fullTextXML');
    try {
      final response = await CitationHttp.get(
        uri,
        headers: const {'Accept': 'application/xml'},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return '';
      return jatsBodyText(response.body);
    } catch (_) {
      return '';
    }
  }

  /// Flatten JATS XML to plain sectioned text (titles + paragraphs only;
  /// tables, figures and reference lists are dropped).
  static String jatsBodyText(String xmlText) {
    final bodyMatch = RegExp(r'<body[ >]', caseSensitive: false).firstMatch(xmlText);
    if (bodyMatch == null) return '';
    // Work on the body slice only, then strip tags section by section.
    final start = bodyMatch.start;
    final end = xmlText.lastIndexOf('</body>');
    var body = end > start ? xmlText.substring(start, end) : xmlText.substring(start);
    // Drop elements whose text is not readable prose.
    for (final tag in const ['table-wrap', 'fig', 'graphic', 'inline-graphic', 'disp-formula', 'ref-list', 'ack', 'app']) {
      body = body.replaceAll(RegExp('<$tag\\b[\\s\\S]*?</$tag>', caseSensitive: false), ' ');
      body = body.replaceAll(RegExp('<$tag\\b[^>]*/>', caseSensitive: false), ' ');
    }
    // Section titles and paragraph ends become line breaks.
    body = body.replaceAll(RegExp('<title[^>]*>', caseSensitive: false), '\n\n');
    body = body.replaceAll(RegExp('</p>', caseSensitive: false), '\n\n');
    body = body.replaceAll(RegExp('<[^>]+>'), '');
    body = _xmlUnescape(body);
    final lines = body
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty);
    return lines.join('\n').trim();
  }

  static String _xmlUnescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#x2013;', '–')
      .replaceAll('&#x2014;', '—')
      .replaceAll('&amp;', '&');
}
