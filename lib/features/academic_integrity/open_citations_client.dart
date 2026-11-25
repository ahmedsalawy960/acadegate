import 'dart:convert';

import 'package:http/http.dart' as http;

import 'citation_http.dart';

/// Citation-count lookups from the OpenCitations COCI index
/// (opencitations.net). Free, no key, DOI-based. Used to fill citation
/// counts that pricier/rate-limited indexes did not return.
class OpenCitationsClient {
  OpenCitationsClient._();

  static final OpenCitationsClient instance = OpenCitationsClient._();

  static const _base = 'https://opencitations.net/index/coci/api/v1';

  /// Citation count for [doi] in the COCI index, or null when the DOI is
  /// not indexed or the service cannot answer. Never throws.
  Future<int?> citationCount(String doi) async {
    final normalized = doi.trim().replaceAll(
          RegExp(r'^https?://(dx\.)?doi\.org/', caseSensitive: false),
          '',
        );
    if (normalized.length < 6 || !normalized.contains('/')) return null;

    final uri =
        Uri.parse('$_base/citation-count/${Uri.encodeComponent(normalized)}');
    http.Response res;
    try {
      res = await CitationHttp.get(uri);
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! List || decoded.isEmpty) return null;
      final first = decoded.first;
      if (first is! Map) return null;
      final count = first['count'];
      if (count is int) return count < 0 ? null : count;
      final parsed = int.tryParse(count?.toString() ?? '');
      if (parsed == null || parsed < 0) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }
}
