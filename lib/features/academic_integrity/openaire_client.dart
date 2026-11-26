import 'dart:convert';

import 'citation_http.dart';

/// One work from the OpenAIRE Graph (aggregates repositories, AGRIS,
/// national agricultural institutes, and Crossref-derived records).
class OpenAireWork {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? journal;
  final String abstractText;
  final String? url;
  final bool isOpenAccess;
  final int? citationCount;

  const OpenAireWork({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.journal,
    this.abstractText = '',
    this.url,
    this.isOpenAccess = false,
    this.citationCount,
  });
}

/// Free search across the OpenAIRE Graph — strong in agricultural grey
/// literature, theses, and non-English (incl. Arabic) records that the
/// DOI-first indexes cover poorly.
class OpenAireClient {
  OpenAireClient._();

  static final OpenAireClient instance = OpenAireClient._();

  static const _base = 'https://api.openaire.eu/search/publications';

  Future<List<OpenAireWork>> search(
    String query, {
    int limit = 10,
    int? fromYear,
  }) async {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.length < 3) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'format': 'json',
        'size': '${limit.clamp(1, 50)}',
        'keywords': q,
        if (fromYear != null) 'fromDateAccepted': '$fromYear-01-01',
      },
    );

    final response = await CitationHttp.get(uri).timeout(
      const Duration(seconds: 25),
    );
    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final responseNode = data['response'] as Map<String, dynamic>?;
    final resultsNode = responseNode?['results'] as Map<String, dynamic>?;
    if (resultsNode == null) return const [];
    final raw = resultsNode['result'];
    final records = raw is List
        ? raw.whereType<Map<String, dynamic>>().toList()
        : (raw is Map<String, dynamic> ? [raw] : <Map<String, dynamic>>[]);

    return records
        .map(_fromRecord)
        .where((w) => w != null && w.title.isNotEmpty)
        .cast<OpenAireWork>()
        .toList();
  }

  OpenAireWork? _fromRecord(Map<String, dynamic> record) {
    final metadata = record['metadata'] as Map<String, dynamic>?;
    final entity = metadata?['oaf:entity'] as Map<String, dynamic>?;
    final result = entity?['oaf:result'] as Map<String, dynamic>?;
    if (result == null) return null;

    final title = _firstValue(result['title']);
    if (title.isEmpty) return null;

    final journal = _firstValue(result['journal']);
    return OpenAireWork(
      title: title,
      doi: _doi(result['pid']),
      year: _year(result['dateofacceptance']),
      authors: _authors(result['creator']),
      journal: journal.isEmpty ? null : journal,
      abstractText: _firstValue(result['description']),
      url: _landingUrl(result['children']),
      isOpenAccess: _isOpenAccess(result['bestaccessright']),
      citationCount: _citationCount(result['measure']),
    );
  }

  /// The XML-to-JSON conversion emits a single object for one element and a
  /// list for several; normalize and read the text payload ("$").
  static String _firstValue(dynamic node) {
    if (node is List) {
      for (final item in node) {
        final v = _firstValue(item);
        if (v.isNotEmpty) return v;
      }
      return '';
    }
    if (node is Map<String, dynamic>) {
      return node[r'$']?.toString().trim() ?? '';
    }
    return node?.toString().trim() ?? '';
  }

  static List<Map<String, dynamic>> _asMapList(dynamic node) {
    if (node is List) return node.whereType<Map<String, dynamic>>().toList();
    if (node is Map<String, dynamic>) return [node];
    return const [];
  }

  static String? _doi(dynamic pidNode) {
    for (final pid in _asMapList(pidNode)) {
      if (pid['@classid']?.toString().toLowerCase() == 'doi') {
        final value = pid[r'$']?.toString().trim();
        if (value != null && value.startsWith('10.')) return value;
      }
    }
    return null;
  }

  static int? _year(dynamic dateNode) {
    final raw = _firstValue(dateNode);
    if (raw.length < 4) return null;
    return int.tryParse(raw.substring(0, 4));
  }

  static String? _authors(dynamic creatorNode) {
    final names = _asMapList(creatorNode)
        .map((c) => c[r'$']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .take(4)
        .toList();
    if (names.isEmpty) return null;
    return names.join('; ');
  }

  static String? _landingUrl(dynamic childrenNode) {
    final children = childrenNode is Map<String, dynamic> ? childrenNode : null;
    if (children == null) return null;
    for (final instance in _asMapList(children['instance'])) {
      final webresource = instance['webresource'];
      for (final wr in _asMapList(webresource)) {
        final url = _firstValue(wr['url']);
        if (url.startsWith('http')) return url;
      }
      final direct = _firstValue(instance['url']);
      if (direct.startsWith('http')) return direct;
    }
    return null;
  }

  static bool _isOpenAccess(dynamic accessNode) {
    if (accessNode is Map<String, dynamic>) {
      return accessNode['@classid']?.toString().toUpperCase() == 'OPEN';
    }
    return false;
  }

  static int? _citationCount(dynamic measureNode) {
    for (final measure in _asMapList(measureNode)) {
      if (measure['@id']?.toString() == 'citationCount') {
        return int.tryParse(measure['@score']?.toString() ?? '');
      }
    }
    return null;
  }
}
