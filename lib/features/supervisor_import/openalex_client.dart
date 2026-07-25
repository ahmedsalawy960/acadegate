import 'dart:convert';

import '../academic_integrity/citation_http.dart';
import 'import_models.dart';
import 'openalex_search_aliases.dart';

class OpenAlexClient {
  OpenAlexClient._();

  static final OpenAlexClient instance = OpenAlexClient._();

  static const _base = 'https://api.openalex.org';
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.app)',
  };

  Future<List<OpenAlexInstitution>> searchInstitutions(String query) async {
    if (query.trim().length < 2) return [];

    final queries = OpenAlexSearchAliases.institutionQueries(query);
    final merged = <String, OpenAlexInstitution>{};
    final preferEgypt = OpenAlexSearchAliases.containsArabic(query);

    for (final searchTerm in queries) {
      final results = await _fetchInstitutions(
        searchTerm,
        countryCode: preferEgypt ? 'EG' : null,
      );
      for (final institution in results) {
        merged[institution.id] = institution;
      }
      if (merged.isNotEmpty && searchTerm != query.trim()) {
        break;
      }
    }

    if (merged.isEmpty && preferEgypt) {
      for (final searchTerm in queries) {
        final results = await _fetchInstitutions(searchTerm);
        for (final institution in results) {
          merged[institution.id] = institution;
        }
        if (merged.isNotEmpty) break;
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.worksCount.compareTo(a.worksCount));
    return list;
  }

  Future<List<OpenAlexInstitution>> _fetchInstitutions(
    String search, {
    String? countryCode,
  }) async {
    final params = <String, String>{
      'search': search,
      'per-page': '25',
    };
    if (countryCode != null && countryCode.isNotEmpty) {
      params['filter'] = 'country_code:$countryCode';
    }

    final uri = Uri.parse('$_base/institutions').replace(queryParameters: params);
    final data = await _getJson(uri);
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((item) => OpenAlexInstitution.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<OpenAlexAuthor>> fetchAuthorsForInstitution({
    required String institutionId,
    int maxPages = 5,
  }) async {
    final authors = <OpenAlexAuthor>[];
    var page = 1;
    final institutionFilter = _institutionFilterValue(institutionId);

    while (page <= maxPages) {
      final uri = Uri.parse('$_base/authors').replace(
        queryParameters: {
          'filter': 'last_known_institutions.id:$institutionFilter',
          'sort': 'cited_by_count:desc',
          'per-page': '200',
          'page': '$page',
        },
      );

      final data = await _getJson(uri);
      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) break;

      authors.addAll(
        results.map(
          (item) => OpenAlexAuthor.fromMap(item as Map<String, dynamic>),
        ),
      );

      final meta = data['meta'] as Map<String, dynamic>?;
      final totalCount = (meta?['count'] as num?)?.toInt() ?? 0;
      final perPage = (meta?['per_page'] as num?)?.toInt() ?? 200;
      final lastPage = (totalCount / perPage).ceil();
      if (page >= lastPage) break;
      page++;
    }

    return enrichAuthors(authors);
  }

  /// بحث عن باحث/دكتور بالاسم — اختياري ضمن جامعة محددة.
  Future<List<OpenAlexAuthor>> searchAuthors({
    required String query,
    String? institutionId,
    int perPage = 25,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final orcidMatch = RegExp(
      r'^(\d{4}-\d{4}-\d{4}-\d{3}[\dXx])$',
    ).firstMatch(trimmed.replaceAll('https://orcid.org/', ''));

    if (orcidMatch != null) {
      final results = await _searchAuthorsOnce(
        query: trimmed,
        institutionId: institutionId,
        perPage: perPage,
        orcid: orcidMatch.group(1),
      );
      return enrichAuthors(results, limit: results.length);
    }

    final queries = OpenAlexSearchAliases.authorQueries(trimmed);
    final merged = <String, OpenAlexAuthor>{};

    for (final searchTerm in queries) {
      final results = await _searchAuthorsOnce(
        query: searchTerm,
        institutionId: institutionId,
        perPage: perPage,
      );
      for (final author in results) {
        merged[author.id] = author;
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
    return enrichAuthors(list);
  }

  Future<List<OpenAlexAuthor>> _searchAuthorsOnce({
    required String query,
    String? institutionId,
    int perPage = 25,
    String? orcid,
  }) async {
    final params = <String, String>{
      'per-page': '$perPage',
      'sort': 'cited_by_count:desc',
    };

    if (orcid != null && orcid.isNotEmpty) {
      params['filter'] = 'orcid:$orcid';
    } else {
      params['search'] = query.trim();
      if (institutionId != null && institutionId.isNotEmpty) {
        params['filter'] =
            'last_known_institutions.id:${_institutionFilterValue(institutionId)}';
      }
    }

    final uri = Uri.parse('$_base/authors').replace(queryParameters: params);
    final data = await _getJson(uri);
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((item) => OpenAlexAuthor.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// يجلب ملفاً كاملاً لكل باحث (h-index، المفاهيم، الجهات).
  Future<List<OpenAlexAuthor>> enrichAuthors(
    List<OpenAlexAuthor> authors, {
    int limit = 40,
  }) async {
    if (authors.isEmpty) return authors;

    final enrichedById = <String, OpenAlexAuthor>{};
    final targets = authors.take(limit).toList();

    for (final author in targets) {
      try {
        enrichedById[author.id] = await enrichAuthor(author);
      } catch (_) {
        enrichedById[author.id] = author;
      }
    }

    return authors
        .map((author) => enrichedById[author.id] ?? author)
        .toList();
  }

  Future<OpenAlexAuthor> enrichAuthor(OpenAlexAuthor author) async {
    final raw = await fetchAuthorRaw(openAlexId: author.id);
    if (raw == null) return author;
    return OpenAlexAuthor.fromMap(raw);
  }

  Future<Map<String, dynamic>?> fetchAuthorRaw({
    String? openAlexId,
    String? orcid,
  }) async {
    if (openAlexId != null && openAlexId.isNotEmpty) {
      final id = openAlexId.startsWith('A') ? openAlexId : 'A$openAlexId';
      final uri = Uri.parse('$_base/authors/$id');
      try {
        return await _getJson(uri);
      } catch (_) {
        return null;
      }
    }

    if (orcid != null && orcid.isNotEmpty) {
      final authors = await searchAuthors(query: orcid, perPage: 1);
      if (authors.isEmpty) return null;
      final uri = Uri.parse('$_base/authors/${authors.first.id}');
      try {
        return await _getJson(uri);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchAuthorWorks({
    required String openAlexId,
    int perPage = 80,
  }) async {
    final id = openAlexId.startsWith('A') ? openAlexId : 'A$openAlexId';
    final uri = Uri.parse('$_base/works').replace(
      queryParameters: {
        'filter': 'authorships.author.id:$id',
        'per-page': '$perPage',
        'sort': 'publication_year:desc',
      },
    );

    try {
      final data = await _getJson(uri);
      final results = data['results'] as List<dynamic>? ?? [];
      return results.cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await CitationHttp.get(uri, headers: _headers).timeout(
      const Duration(seconds: 45),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAlex: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _institutionFilterValue(String institutionId) {
    final trimmed = institutionId.trim();
    if (trimmed.startsWith('https://openalex.org/')) return trimmed;
    if (trimmed.startsWith('http://openalex.org/')) return trimmed;
    return 'https://openalex.org/$trimmed';
  }
}
