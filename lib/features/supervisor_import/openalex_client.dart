import 'dart:convert';

import 'package:http/http.dart' as http;

import 'import_models.dart';

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

    final uri = Uri.parse('$_base/institutions').replace(
      queryParameters: {
        'search': query.trim(),
        'per-page': '25',
      },
    );

    final response = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode != 200) {
      throw Exception('OpenAlex: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
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

    while (page <= maxPages) {
      final uri = Uri.parse('$_base/authors').replace(
        queryParameters: {
          'filter': 'last_known_institutions.id:$institutionId',
          'sort': 'cited_by_count:desc',
          'per-page': '200',
          'page': '$page',
        },
      );

      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 45),
          );

      if (response.statusCode != 200) {
        throw Exception('OpenAlex authors: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) break;

      authors.addAll(
        results.map(
          (item) => OpenAlexAuthor.fromMap(item as Map<String, dynamic>),
        ),
      );

      final meta = data['meta'] as Map<String, dynamic>?;
      final totalPages = (meta?['count'] as num?)?.toInt() ?? 0;
      final perPage = (meta?['per_page'] as num?)?.toInt() ?? 200;
      final lastPage = (totalPages / perPage).ceil();
      if (page >= lastPage) break;
      page++;
    }

    return authors;
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

    final params = <String, String>{
      'per-page': '$perPage',
      'sort': 'cited_by_count:desc',
    };

    if (orcidMatch != null) {
      params['filter'] = 'orcid:${orcidMatch.group(1)}';
    } else {
      params['search'] = trimmed;
      if (institutionId != null && institutionId.isNotEmpty) {
        params['filter'] = 'last_known_institutions.id:$institutionId';
      }
    }

    final uri = Uri.parse('$_base/authors').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode != 200) {
      throw Exception('OpenAlex authors: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((item) => OpenAlexAuthor.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchAuthorRaw({
    String? openAlexId,
    String? orcid,
  }) async {
    if (openAlexId != null && openAlexId.isNotEmpty) {
      final id = openAlexId.startsWith('A') ? openAlexId : 'A$openAlexId';
      final uri = Uri.parse('$_base/authors/$id');
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 25),
          );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    }

    if (orcid != null && orcid.isNotEmpty) {
      final authors = await searchAuthors(query: orcid, perPage: 1);
      if (authors.isEmpty) return null;
      final uri = Uri.parse('$_base/authors/${authors.first.id}');
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 25),
          );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// منشورات المؤلف مع بيانات المجلة (لتقدير التأثير).
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

    final response = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 35),
        );

    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results.cast<Map<String, dynamic>>();
  }
}
