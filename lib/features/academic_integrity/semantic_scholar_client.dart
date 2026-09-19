import 'dart:convert';

import 'citation_http.dart';

class SemanticScholarAuthor {
  final String authorId;
  final String name;
  final List<String> affiliations;
  final int paperCount;
  final int citationCount;
  final int hIndex;
  final String? orcid;
  final String url;

  const SemanticScholarAuthor({
    required this.authorId,
    required this.name,
    this.affiliations = const [],
    this.paperCount = 0,
    this.citationCount = 0,
    this.hIndex = 0,
    this.orcid,
    this.url = '',
  });
}

class SemanticScholarPaper {
  final String title;
  final String? doi;
  final int? year;
  final String? authors;
  final String? url;
  final String? paperId;
  final String? venue;
  final String abstractText;

  const SemanticScholarPaper({
    required this.title,
    this.doi,
    this.year,
    this.authors,
    this.url,
    this.paperId,
    this.venue,
    this.abstractText = '',
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
        'fields': 'title,year,authors,url,externalIds,paperId,abstract,venue',
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
    if (query.trim().length < 4) return const [];

    final uri = Uri.parse('$_base/paper/search').replace(
      queryParameters: {
        'query': query.trim(),
        'limit': '$limit',
        'fields': 'title,year,authors,url,externalIds,paperId,abstract,venue',
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

  Future<List<SemanticScholarAuthor>> searchAuthors(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().length < 3) return const [];

    final uri = Uri.parse('$_base/author/search').replace(
      queryParameters: {
        'query': query.trim(),
        'limit': '$limit',
        'fields': 'name,affiliations,paperCount,citationCount,hIndex,externalIds,url',
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
        .map(_authorFromMap)
        .where((a) => a.name.trim().length >= 3)
        .toList();
  }

  SemanticScholarAuthor _authorFromMap(Map<String, dynamic> data) {
    final affiliations = (data['affiliations'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final ids = data['externalIds'] as Map<String, dynamic>?;
    final orcid = ids?['ORCID']?.toString();
    final authorId = data['authorId']?.toString() ?? '';
    return SemanticScholarAuthor(
      authorId: authorId,
      name: data['name']?.toString() ?? '',
      affiliations: affiliations,
      paperCount: (data['paperCount'] as num?)?.toInt() ?? 0,
      citationCount: (data['citationCount'] as num?)?.toInt() ?? 0,
      hIndex: (data['hIndex'] as num?)?.toInt() ?? 0,
      orcid: orcid != null && orcid.isNotEmpty ? orcid : null,
      url: data['url']?.toString() ??
          (authorId.isEmpty
              ? ''
              : 'https://www.semanticscholar.org/author/$authorId'),
    );
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
      venue: data['venue']?.toString(),
      abstractText: data['abstract']?.toString().trim() ?? '',
    );
  }
}
