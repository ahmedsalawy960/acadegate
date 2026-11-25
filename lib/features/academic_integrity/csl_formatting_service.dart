import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/callable_http_client.dart';
import '../../core/locale/locale_service.dart';
import '../ai_advisor/grounded_work.dart';

/// Formats references with journal citation styles (CSL) through the
/// formatCitations Cloud Function (citeproc engine, bundled styles).
class CslFormattingService {
  CslFormattingService._();

  static final CslFormattingService instance = CslFormattingService._();

  /// Styles bundled in functions/csl_styles (keep in sync with the
  /// function's SUPPORTED_STYLES). Labels are style names, fine to show.
  static const supportedStyles = <String, String>{
    'apa': 'APA 7',
    'elsevier-vancouver': 'Vancouver',
    'ieee': 'IEEE',
    'nature': 'Nature',
    'chicago-author-date': 'Chicago (author-date)',
    'chicago-notes-bibliography': 'Chicago (notes)',
    'elsevier-harvard': 'Elsevier Harvard',
    'harvard-cite-them-right': 'Harvard (Cite Them Right)',
    'modern-language-association': 'MLA 9',
    'american-medical-association': 'AMA 11',
    'american-sociological-association': 'ASA 7',
    'springer-basic-author-date': 'Springer (author-date)',
  };

  /// Injectable for tests.
  static Future<List<String>> Function({
    required String style,
    required List<Map<String, dynamic>> items,
    String? locale,
  })? debugFormat;

  /// Bibliography lines for [works] in [style] (a key of
  /// [supportedStyles]). Locale follows the app language.
  Future<List<String>> formatBibliography({
    required String style,
    required List<GroundedWork> works,
    String? locale,
  }) async {
    final items = works.map(toCslJson).toList();
    final effectiveLocale =
        locale ?? (LocaleService.instance.isEnglish ? 'en' : 'ar');

    final debug = debugFormat;
    if (debug != null) {
      return debug(style: style, items: items, locale: effectiveLocale);
    }

    final payload = <String, dynamic>{
      'style': style,
      'items': items,
      'locale': effectiveLocale,
    };
    Map<String, dynamic> data;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      data = await CallableHttpClient.call(
        name: 'formatCitations',
        data: payload,
        callableProtocol: true,
        timeout: const Duration(seconds: 60),
      );
    } else {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'formatCitations',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final response = await callable.call<Map<String, dynamic>>(payload);
      data = Map<String, dynamic>.from(response.data);
    }

    final entries = data['entries'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map>()
        .map((e) => e['text']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// GroundedWork → CSL-JSON. Author strings arrive in mixed shapes
  /// ("Family, Given" or "Given Family", separated by ';', ' and ', '؛'):
  /// a comma splits family/given, otherwise the name passes as a literal
  /// so citeproc prints it unchanged instead of guessing.
  static Map<String, dynamic> toCslJson(GroundedWork work) {
    final json = <String, dynamic>{
      'id': work.hasDoi ? work.doi.trim().toLowerCase() : work.mergeKey,
      'type': 'article-journal',
      'title': work.title,
    };
    if (work.hasDoi) json['DOI'] = work.doi.trim();
    final year = work.year;
    if (year != null) {
      json['issued'] = {
        'date-parts': [
          [year],
        ],
      };
    }
    final authors = <Map<String, dynamic>>[];
    for (final raw in work.authors.split(RegExp(r';| and |؛'))) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final comma = name.indexOf(',');
      if (comma > 0) {
        authors.add({
          'family': name.substring(0, comma).trim(),
          'given': name.substring(comma + 1).trim(),
        });
      } else {
        authors.add({'literal': name});
      }
    }
    if (authors.isNotEmpty) json['author'] = authors;
    final journal = work.journal?.trim() ?? '';
    if (journal.isNotEmpty) json['container-title'] = journal;
    final url = work.primaryUrl;
    if (url.isNotEmpty) json['URL'] = url;
    return json;
  }
}
