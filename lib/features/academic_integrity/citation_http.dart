import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// طلبات Crossref/OpenAlex/Semantic Scholar — عبر Cloud Function على الويب لتجاوز CORS.
class CitationHttp {
  CitationHttp._();

  static const _proxyUrl =
      'https://us-central1-acadegate-new.cloudfunctions.net/citationLookupHttp';

  static const _allowedHosts = {
    'api.crossref.org',
    'api.openalex.org',
    'api.semanticscholar.org',
    'www.ebi.ac.uk',
    'serpapi.com',
    'pub.orcid.org',
    'query.wikidata.org',
  };

  /// ORCID and Wikidata publish CORS headers; call them directly on Chrome.
  static const _directOnWeb = {
    'pub.orcid.org',
    'query.wikidata.org',
  };

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    if (kIsWeb) {
      if (_directOnWeb.contains(uri.host)) {
        return http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 25));
      }
      if (!_allowedHosts.contains(uri.host)) {
        throw Exception('Citation proxy: host not allowed');
      }
      final proxy = Uri.parse(_proxyUrl).replace(
        queryParameters: {'url': uri.toString()},
      );
      return http.get(proxy).timeout(const Duration(seconds: 30));
    }

    return http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));
  }
}
