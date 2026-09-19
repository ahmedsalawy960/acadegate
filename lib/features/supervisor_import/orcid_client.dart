import 'dart:convert';

import '../academic_integrity/citation_http.dart';

class OrcidProfile {
  final String orcid;
  final String name;
  final List<String> institutions;
  final List<String> keywords;
  final String officialUrl;

  const OrcidProfile({
    required this.orcid,
    required this.name,
    this.institutions = const [],
    this.keywords = const [],
    this.officialUrl = '',
  });

  String get speciality => keywords.isNotEmpty ? keywords.first : '';
}

class OrcidClient {
  OrcidClient._();

  static final OrcidClient instance = OrcidClient._();

  static const _base = 'https://pub.orcid.org/v3.0';
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'AcadeGate/1.0 (mailto:support@acadegate.app)',
  };

  static final orcidPattern = RegExp(r'\d{4}-\d{4}-\d{4}-\d{3}[\dXx]');

  static String? normalizeOrcid(String raw) {
    final match = orcidPattern.firstMatch(
      raw.replaceAll('https://orcid.org/', '').trim(),
    );
    return match?.group(0);
  }

  Future<List<OrcidProfile>> search({
    String? name,
    String? affiliation,
    String? keyword,
    int rows = 20,
  }) async {
    final parts = <String>[];
    final orcid = name == null ? null : normalizeOrcid(name);
    if (orcid != null) {
      final one = await fetchRecord(orcid);
      return one == null ? const [] : [one];
    }
    if (name != null && name.trim().length >= 3) {
      parts.add('given-and-family-names:"${_escape(name.trim())}"');
    }
    if (affiliation != null && affiliation.trim().length >= 3) {
      parts.add('affiliation-org-name:"${_escape(affiliation.trim())}"');
    }
    if (keyword != null && keyword.trim().length >= 3) {
      parts.add('keyword:"${_escape(keyword.trim())}"');
    }
    if (parts.isEmpty) return const [];

    final uri = Uri.parse('$_base/expanded-search/').replace(
      queryParameters: {
        'q': parts.join(' AND '),
        'rows': '$rows',
      },
    );
    final response = await CitationHttp.get(uri, headers: _headers);
    if (response.statusCode != 200) return const [];
    final data = jsonDecode(response.body);
    if (data is! Map) return const [];
    return parseExpandedSearch(Map<String, dynamic>.from(data));
  }

  Future<OrcidProfile?> fetchRecord(String orcid) async {
    final id = normalizeOrcid(orcid);
    if (id == null) return null;
    final uri = Uri.parse('$_base/$id');
    final response = await CitationHttp.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is! Map) return null;
    return parseRecord(Map<String, dynamic>.from(data), fallbackOrcid: id);
  }

  static List<OrcidProfile> parseExpandedSearch(Map<String, dynamic> data) {
    final rows = data['expanded-result'] as List<dynamic>? ?? [];
    return rows
        .whereType<Map>()
        .map((raw) => parseExpandedRow(Map<String, dynamic>.from(raw)))
        .where((p) => p.name.trim().length >= 3 && p.orcid.isNotEmpty)
        .toList();
  }

  static OrcidProfile parseExpandedRow(Map<String, dynamic> row) {
    final orcid = normalizeOrcid(row['orcid-id']?.toString() ?? '') ?? '';
    final credit = row['credit-name']?.toString().trim() ?? '';
    final given = row['given-names']?.toString().trim() ?? '';
    final family = row['family-names']?.toString().trim() ?? '';
    final name = credit.isNotEmpty ? credit : '$given $family'.trim();
    final institutions = (row['institution-name'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return OrcidProfile(
      orcid: orcid,
      name: name,
      institutions: institutions,
      officialUrl: orcid.isEmpty ? '' : 'https://orcid.org/$orcid',
    );
  }

  static OrcidProfile parseRecord(
    Map<String, dynamic> data, {
    String fallbackOrcid = '',
  }) {
    final person = data['person'] as Map<String, dynamic>? ?? {};
    final nameMap = person['name'] as Map<String, dynamic>? ?? {};
    final credit = _stringValue(nameMap['credit-name']);
    final given = _stringValue(nameMap['given-names']);
    final family = _stringValue(nameMap['family-names']);
    final name = credit.isNotEmpty ? credit : '$given $family'.trim();
    final idNode = data['orcid-identifier'];
    final idPath = idNode is Map ? idNode['path']?.toString() ?? '' : '';
    final orcid = normalizeOrcid(idPath.isNotEmpty ? idPath : fallbackOrcid) ??
        fallbackOrcid;

    final keywords = <String>[];
    final kwGroup = person['keywords'] as Map<String, dynamic>?;
    for (final item in kwGroup?['keyword'] as List<dynamic>? ?? []) {
      if (item is! Map) continue;
      final value = _stringValue(item['content']);
      if (value.isNotEmpty) keywords.add(value);
    }

    final institutions = <String>[];
    final activities = data['activities-summary'] as Map<String, dynamic>? ?? {};
    final employments = activities['employments'] as Map<String, dynamic>?;
    for (final group in employments?['affiliation-group'] as List<dynamic>? ?? []) {
      if (group is! Map) continue;
      for (final summary in group['summaries'] as List<dynamic>? ?? []) {
        if (summary is! Map) continue;
        final emp = summary['employment-summary'] as Map<String, dynamic>? ?? {};
        final org = emp['organization'] as Map<String, dynamic>?;
        final orgName = org?['name']?.toString().trim() ?? '';
        if (orgName.isNotEmpty) institutions.add(orgName);
      }
    }

    return OrcidProfile(
      orcid: orcid,
      name: name,
      institutions: institutions.toSet().toList(),
      keywords: keywords,
      officialUrl: orcid.isEmpty ? '' : 'https://orcid.org/$orcid',
    );
  }

  static String _stringValue(dynamic raw) {
    if (raw is String) return raw.trim();
    if (raw is Map) return raw['value']?.toString().trim() ?? '';
    return '';
  }

  static String _escape(String value) {
    return value.replaceAll('"', '');
  }
}
