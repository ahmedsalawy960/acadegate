import 'dart:convert';

import '../academic_integrity/citation_http.dart';

class WikidataAcademic {
  final String name;
  final String institution;
  final String? orcid;
  final String officialUrl;
  final String wikidataUrl;

  const WikidataAcademic({
    required this.name,
    required this.institution,
    this.orcid,
    this.officialUrl = '',
    this.wikidataUrl = '',
  });
}

class WikidataAcademicsClient {
  WikidataAcademicsClient._();

  static final WikidataAcademicsClient instance = WikidataAcademicsClient._();

  static const _endpoint = 'https://query.wikidata.org/sparql';

  Future<List<WikidataAcademic>> searchEmployedAt({
    required String universityEnglish,
    String? topic,
    int limit = 20,
  }) async {
    final uni = universityEnglish.trim();
    if (uni.length < 4) return const [];
    final topicFilter = (topic ?? '').trim();
    final topicClause = topicFilter.length >= 4
        ? '''
      OPTIONAL { ?person rdfs:label ?topicLabel. }
      FILTER(!BOUND(?topicLabel) || CONTAINS(LCASE(?topicLabel), "${_escape(topicFilter.toLowerCase())}"))
      '''
        : '';

    final sparql = '''
SELECT DISTINCT ?person ?personLabel ?orcid ?employerLabel ?website WHERE {
  ?person wdt:P108 ?employer.
  ?employer rdfs:label "$uni"@en.
  OPTIONAL { ?person wdt:P496 ?orcid. }
  OPTIONAL { ?person wdt:P856 ?website. }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en,ar". }
  $topicClause
}
LIMIT $limit
''';

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {'query': sparql, 'format': 'json'},
    );
    final response = await CitationHttp.get(
      uri,
      headers: const {
        'Accept': 'application/sparql-results+json',
        'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.app)',
      },
    );
    if (response.statusCode != 200) return const [];
    final data = jsonDecode(response.body);
    if (data is! Map) return const [];
    return parseSparql(Map<String, dynamic>.from(data));
  }

  static List<WikidataAcademic> parseSparql(Map<String, dynamic> data) {
    final bindings =
        (data['results'] as Map<String, dynamic>?)?['bindings'] as List<dynamic>? ??
            [];
    return bindings
        .whereType<Map>()
        .map((raw) => _fromBinding(Map<String, dynamic>.from(raw)))
        .where((a) => a.name.trim().length >= 3)
        .toList();
  }

  static WikidataAcademic _fromBinding(Map<String, dynamic> binding) {
    String val(String key) {
      final node = binding[key];
      if (node is Map) return node['value']?.toString().trim() ?? '';
      return '';
    }

    final person = val('person');
    final orcid = val('orcid');
    return WikidataAcademic(
      name: val('personLabel'),
      institution: val('employerLabel'),
      orcid: orcid.isEmpty ? null : orcid,
      officialUrl: val('website'),
      wikidataUrl: person,
    );
  }

  static String _escape(String value) {
    return value.replaceAll('\\', '').replaceAll('"', '');
  }
}
