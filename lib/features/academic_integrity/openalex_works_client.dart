import 'dart:convert';

import 'citation_http.dart';

class OpenAlexWork {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? url;
  final bool isRetracted;
  final String? journal;
  final String abstractText;

  const OpenAlexWork({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.url,
    this.isRetracted = false,
    this.journal,
    this.abstractText = '',
  });
}

class OpenAlexWorksClient {
  OpenAlexWorksClient._();

  static final OpenAlexWorksClient instance = OpenAlexWorksClient._();

  static const _base = 'https://api.openalex.org/works';
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.app)',
  };

  Future<OpenAlexWork?> lookupDoi(String doi) async {
    final normalized = doi.trim().replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    final uri = Uri.parse('$_base/https://doi.org/${Uri.encodeComponent(normalized)}');

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromMap(data);
  }

  Future<List<OpenAlexWork>> searchTitle(
    String query, {
    int perPage = 5,
    bool byRelevance = false,
    bool englishOnly = false,
    bool arabicOnly = false,
    int? fromYear,
    bool hasDoi = false,
    bool includeTheses = false,
  }) async {
    if (query.trim().length < 3) return const [];

    final filters = <String>[
      if (hasDoi) 'has_doi:true',
      'is_retracted:false',
      if (englishOnly) 'language:en',
      if (arabicOnly) 'language:ar',
      if (fromYear != null) 'from_publication_year:$fromYear',
      includeTheses
          ? 'type:article|review|dissertation'
          : 'type:article|review',
    ];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'search': query.trim(),
        'per-page': '${perPage.clamp(1, 50)}',
        'sort': byRelevance ? 'relevance_score:desc' : 'cited_by_count:desc',
        'filter': filters.join(','),
      },
    );

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 25),
        );

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map<String, dynamic>>()
        .map(_fromMap)
        .where((w) => w.title.isNotEmpty)
        .toList();
  }

  OpenAlexWork _fromMap(Map<String, dynamic> data) {
    final rawDoi = data['doi']?.toString();
    final doi = rawDoi?.replaceFirst('https://doi.org/', '');

    final authorships = data['authorships'] as List<dynamic>? ?? [];
    final authors = authorships
        .map((a) {
          final map = a as Map<String, dynamic>;
          final author = map['author'] as Map<String, dynamic>?;
          return author?['display_name']?.toString() ?? '';
        })
        .where((s) => s.isNotEmpty)
        .take(4)
        .join('; ');

    return OpenAlexWork(
      title: data['display_name']?.toString() ??
          (data['title']?.toString() ?? ''),
      doi: doi,
      year: (data['publication_year'] as num?)?.toInt(),
      authors: authors.isEmpty ? null : authors,
      url: data['id']?.toString(),
      isRetracted: data['is_retracted'] == true,
      journal: _journal(data),
      abstractText: _abstractFromInverted(data['abstract_inverted_index']),
    );
  }

  static String? _journal(Map<String, dynamic> data) {
    final loc = data['primary_location'] as Map<String, dynamic>?;
    final source = loc?['source'] as Map<String, dynamic>?;
    final name = source?['display_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  static String _abstractFromInverted(dynamic inverted) {
    if (inverted is! Map) return '';
    final positions = <int, String>{};
    inverted.forEach((word, idxs) {
      if (idxs is List) {
        for (final i in idxs) {
          if (i is num) positions[i.toInt()] = word.toString();
        }
      }
    });
    if (positions.isEmpty) return '';
    final max = positions.keys.reduce((a, b) => a > b ? a : b);
    final words = List.generate(max + 1, (i) => positions[i] ?? '');
    return words.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
