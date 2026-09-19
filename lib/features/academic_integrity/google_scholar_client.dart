import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/locale/app_translate.dart';
import 'citation_http.dart';

class GoogleScholarHit {
  final String title;
  final String? doi;
  final int? year;
  final String authors;
  final String journal;
  final String snippet;
  final String url;

  const GoogleScholarHit({
    required this.title,
    this.doi,
    this.year,
    this.authors = '',
    this.journal = '',
    this.snippet = '',
    this.url = '',
  });
}

class ScholarSearchException implements Exception {
  final String message;
  final String? code;

  const ScholarSearchException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Google Scholar via SerpAPI Cloud Function (or optional client key on desktop).
/// Direct Scholar scraping is not supported (no public API / ToS).
class GoogleScholarClient {
  GoogleScholarClient._();

  static final GoogleScholarClient instance = GoogleScholarClient._();

  static const _fnUrl =
      'https://us-central1-acadegate-new.cloudfunctions.net/googleScholarSearchHttp';

  /// Optional local/desktop key — debug only; production uses Cloud Function secret.
  static const _clientKey = String.fromEnvironment('SERPAPI_API_KEY');

  static bool get hasClientKey =>
      kDebugMode &&
      _clientKey.isNotEmpty &&
      !_clientKey.contains('ضع_');

  Future<List<GoogleScholarHit>> search(
    String query, {
    int limit = 20,
    int? fromYear,
  }) async {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.length < 3) return const [];

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return _searchViaFunction(q, limit: limit, fromYear: fromYear);
    }

    final fromFn = await _searchViaFunction(
      q,
      limit: limit,
      fromYear: fromYear,
      requireAuth: false,
    );
    if (fromFn.isNotEmpty) return fromFn.take(limit).toList();

    if (!hasClientKey) return const [];
    return _searchViaSerpApiDirect(q, limit: limit, fromYear: fromYear);
  }

  Future<List<GoogleScholarHit>> _searchViaFunction(
    String q, {
    required int limit,
    int? fromYear,
    bool requireAuth = true,
  }) async {
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      } else if (requireAuth) {
        throw ScholarSearchException(
          appTr(
            'سجّل الدخول لاستخدام بحث Google Scholar.',
            'Sign in to use Google Scholar search.',
          ),
          code: 'unauthenticated',
        );
      }

      final uri = Uri.parse(_fnUrl).replace(
        queryParameters: {
          'q': q,
          'num': '${limit.clamp(1, 60)}',
          if (fromYear != null && fromYear > 1900) 'as_ylo': '$fromYear',
        },
      );
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 401) {
        throw ScholarSearchException(
          _errorFromBody(response.body) ??
              appTr(
                'سجّل الدخول لاستخدام بحث Google Scholar.',
                'Sign in to use Google Scholar search.',
              ),
          code: 'unauthenticated',
        );
      }
      if (response.statusCode == 429) {
        throw ScholarSearchException(
          _errorFromBody(response.body) ??
              appTr(
                'وصلت للحد اليومي لبحث Google Scholar.',
                'Daily Google Scholar search limit reached.',
              ),
          code: 'quota_exceeded',
        );
      }
      if (response.statusCode != 200) return const [];
      return _parsePayload(response.body);
    } on ScholarSearchException {
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  String? _errorFromBody(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['error'] != null) {
        return data['error'].toString().trim();
      }
    } catch (_) {}
    return null;
  }

  /// SerpAPI returns max ~20 per page; paginate to gather more studies.
  Future<List<GoogleScholarHit>> _searchViaSerpApiDirect(
    String q, {
    required int limit,
    int? fromYear,
  }) async {
    final want = limit.clamp(1, 60);
    final out = <GoogleScholarHit>[];
    final seen = <String>{};
    for (var start = 0; start < want; start += 20) {
      final pageSize = (want - start).clamp(1, 20);
      final uri = Uri.parse('https://serpapi.com/search.json').replace(
        queryParameters: {
          'engine': 'google_scholar',
          'q': q,
          'api_key': _clientKey,
          'num': '$pageSize',
          'start': '$start',
          'hl': 'en',
          if (fromYear != null && fromYear > 1900) 'as_ylo': '$fromYear',
        },
      );
      try {
        final response = await CitationHttp.get(
          uri,
          headers: const {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 35));
        if (response.statusCode != 200) break;
        final page = _parsePayload(response.body);
        if (page.isEmpty) break;
        for (final hit in page) {
          final key = (hit.doi?.isNotEmpty == true)
              ? 'doi:${hit.doi}'
              : 't:${hit.title.toLowerCase()}';
          if (seen.add(key)) out.add(hit);
        }
        if (page.length < pageSize) break;
      } catch (_) {
        break;
      }
    }
    return out.take(want).toList();
  }

  List<GoogleScholarHit> _parsePayload(String body) {
    final data = jsonDecode(body);
    if (data is! Map) return const [];
    final rows = data['organic_results'];
    if (rows is! List) return const [];
    final out = <GoogleScholarHit>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final title = (map['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final link = (map['link'] ?? '').toString().trim();
      final snippet = (map['snippet'] ?? '').toString().trim();
      final pub = map['publication_info'];
      final summary = pub is Map
          ? (pub['summary'] ?? '').toString()
          : '';
      final parsed = _parsePublicationSummary(summary);
      final doi = _extractDoi('$link $snippet $summary') ??
          _doiFromResources(map['resources']);
      out.add(
        GoogleScholarHit(
          title: title,
          doi: doi,
          year: parsed.year,
          authors: parsed.authors,
          journal: parsed.journal,
          snippet: snippet,
          url: link,
        ),
      );
    }
    return out;
  }

  String? _doiFromResources(dynamic resources) {
    if (resources is! List) return null;
    for (final r in resources) {
      if (r is! Map) continue;
      final link = (r['link'] ?? '').toString();
      final doi = _extractDoi(link);
      if (doi != null) return doi;
    }
    return null;
  }

  String? _extractDoi(String text) {
    final m = RegExp(
      r'10\.\d{4,9}/[-._;()/:A-Z0-9]+',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    return m.group(0)!.replaceAll(RegExp(r'[.,;)\]]+$'), '').toLowerCase();
  }

  ({String authors, int? year, String journal}) _parsePublicationSummary(
    String summary,
  ) {
    // Typical: "A Author, B Author - Journal Name, 2021 - publisher"
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(summary);
    final year = yearMatch == null ? null : int.tryParse(yearMatch.group(0)!);
    var authors = '';
    var journal = '';
    final dashParts = summary.split(RegExp(r'\s+-\s+'));
    if (dashParts.isNotEmpty) {
      authors = dashParts.first.trim();
    }
    if (dashParts.length >= 2) {
      final mid = dashParts[1].trim();
      journal = mid.replaceAll(RegExp(r',?\s*(19|20)\d{2}\b'), '').trim();
    }
    return (authors: authors, year: year, journal: journal);
  }
}
