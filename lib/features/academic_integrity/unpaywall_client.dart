import 'dart:convert';

import 'citation_http.dart';

/// Best open-access location for a DOI, from the free Unpaywall index.
class OaLocation {
  final bool isOa;
  final String pdfUrl;
  final String landingUrl;

  const OaLocation({
    this.isOa = false,
    this.pdfUrl = '',
    this.landingUrl = '',
  });

  String get bestUrl => pdfUrl.isNotEmpty ? pdfUrl : landingUrl;
}

/// Unpaywall (free, email-identified). Finds legal open-access copies.
class UnpaywallClient {
  UnpaywallClient._();

  static final UnpaywallClient instance = UnpaywallClient._();

  static const _base = 'https://api.unpaywall.org/v2';

  Future<OaLocation> bestLocationForDoi(String doi) async {
    final normalized = doi
        .trim()
        .replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/'), '');
    if (normalized.length < 6) return const OaLocation();
    final uri = Uri.parse('$_base/${Uri.encodeComponent(normalized)}').replace(
      queryParameters: const {'email': 'support@acadegate.app'},
    );
    try {
      final response = await CitationHttp.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const OaLocation();
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return locationFromMap(data);
    } catch (_) {
      return const OaLocation();
    }
  }

  static OaLocation locationFromMap(Map<String, dynamic> map) {
    final isOa = map['is_oa'] == true;
    final best = map['best_oa_location'];
    if (!isOa || best is! Map) return const OaLocation();
    final b = Map<String, dynamic>.from(best);
    return OaLocation(
      isOa: true,
      pdfUrl: (b['url_for_pdf'] ?? '').toString().trim(),
      landingUrl: (b['url'] ?? '').toString().trim(),
    );
  }
}
