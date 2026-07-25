import 'dart:convert';

import 'citation_http.dart';

class SemanticScholarPaper {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? url;
  final String? paperId;

  const SemanticScholarPaper({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.url,
    this.paperId,
  });
}

class SemanticScholarClient {
  SemanticScholarClient._();

  static final SemanticScholarClient instance = SemanticScholarClient._();

  static const _base = 'https://api.semanticscholar.org/graph/v1';
  static const _headers = {'Accept': 'application/json'};

  Future<SemanticScholarPaper?> lookupDoi(String doi) async {
    final normalized = doi.trim().replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    final uri = Uri.parse('$_base/paper/DOI:${Uri.encodeComponent(normalized)}').replace(
      queryParameters: const {
        'fields': 'title,year,authors,url,externalIds,paperId',
      },
    );

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromMap(data);
  }

  Future<List<SemanticScholarPaper>> search(String query, {int limit = 5}) async {
    if (query.trim().length < 8) return const [];

    final uri = Uri.parse('$_base/paper/search').replace(
      queryParameters: {
        'query': query.trim(),
        'limit': '$limit',
        'fields': 'title,year,authors,url,externalIds,paperId',
      },
    );

    final response = await CitationHttp.get(uri, headers: _headers).timeout(
          const Duration(seconds: 25),
        );

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['data'] as List<dynamic>? ?? [];

    return results
        .whereType<Map<String, dynamic>>()
        .map(_fromMap)
        .where((p) => p.title.isNotEmpty)
        .toList();
  }

  SemanticScholarPaper _fromMap(Map<String, dynamic> data) {
    final authorsList = data['authors'] as List<dynamic>? ?? [];
    final authors = authorsList
        .map((a) => (a as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .take(4)
        .join('; ');

    final externalIds = data['externalIds'] as Map<String, dynamic>?;
    final doi = externalIds?['DOI']?.toString();
    final paperId = data['paperId']?.toString();
    final url = data['url']?.toString() ??
        (paperId != null ? 'https://www.semanticscholar.org/paper/$paperId' : null);

    return SemanticScholarPaper(
      title: data['title']?.toString() ?? '',
      doi: doi,
      year: (data['year'] as num?)?.toInt(),
      authors: authors.isEmpty ? null : authors,
      url: url,
      paperId: paperId,
    );
  }
}
