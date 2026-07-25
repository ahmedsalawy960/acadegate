import 'dart:convert';

import 'citation_http.dart';

class OpenAlexWork {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? url;

  const OpenAlexWork({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.url,
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

  Future<List<OpenAlexWork>> searchTitle(String query, {int perPage = 5}) async {
    if (query.trim().length < 3) return const [];

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'search': query.trim(),
        'per-page': '$perPage',
        'sort': 'cited_by_count:desc',
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
    );
  }
}
