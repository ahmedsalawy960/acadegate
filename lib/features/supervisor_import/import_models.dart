import '../../core/locale/l10n_lookup.dart';

class OpenAlexInstitution {
  final String id;
  final String name;
  final String? country;
  final String? type;
  final int worksCount;

  const OpenAlexInstitution({
    required this.id,
    required this.name,
    this.country,
    this.type,
    this.worksCount = 0,
  });

  factory OpenAlexInstitution.fromMap(Map<String, dynamic> map) {
    final rawId = map['id']?.toString() ?? '';
    return OpenAlexInstitution(
      id: rawId.replaceFirst('https://openalex.org/', ''),
      name: map['display_name']?.toString() ?? L10nLookup.institution,
      country: (map['country_code'] ?? map['geo']?['country_code'])?.toString(),
      type: map['type']?.toString(),
      worksCount: (map['works_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class OpenAlexAuthor {
  final String id;
  final String name;
  final String? orcid;
  final String institutionName;
  final List<String> institutionNames;
  final String speciality;
  final List<String> tags;
  final int worksCount;
  final int citedByCount;
  final int hIndex;
  final int i10Index;
  final int? lastPublicationYear;
  final String? scholarUrl;

  const OpenAlexAuthor({
    required this.id,
    required this.name,
    this.orcid,
    required this.institutionName,
    this.institutionNames = const [],
    required this.speciality,
    this.tags = const [],
    this.worksCount = 0,
    this.citedByCount = 0,
    this.hIndex = 0,
    this.i10Index = 0,
    this.lastPublicationYear,
    this.scholarUrl,
  });

  String get bio => L10nLookup.researcherBioDetailed(
        institution: institutionName,
        works: worksCount,
        citations: citedByCount,
        hIndex: hIndex,
        speciality: speciality,
      );

  factory OpenAlexAuthor.fromMap(Map<String, dynamic> map) {
    final rawId = map['id']?.toString() ?? '';
    final institutions = map['last_known_institutions'] as List<dynamic>? ?? [];
    final institutionNames = institutions
        .map((item) => item['display_name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    final institutionName =
        institutionNames.isNotEmpty ? institutionNames.first : '';

    final concepts = (map['x_concepts'] as List<dynamic>?) ??
        (map['concepts'] as List<dynamic>?) ??
        [];
    final topConcepts = concepts
        .map((concept) {
          if (concept is Map<String, dynamic>) {
            return concept['display_name']?.toString() ?? '';
          }
          return concept.toString();
        })
        .where((name) => name.isNotEmpty)
        .take(8)
        .toList();

    final stats = map['summary_stats'] as Map<String, dynamic>?;
    final countsByYear = map['counts_by_year'] as List<dynamic>? ?? [];
    int? lastYear;
    for (final entry in countsByYear) {
      if (entry is! Map) continue;
      final year = (entry['year'] as num?)?.toInt();
      final count = (entry['works_count'] as num?)?.toInt() ?? 0;
      if (year != null && count > 0) {
        if (lastYear == null || year > lastYear) lastYear = year;
      }
    }

    final orcidRaw = map['orcid']?.toString();
    final orcid = orcidRaw?.replaceFirst('https://orcid.org/', '');

    return OpenAlexAuthor(
      id: rawId.replaceFirst('https://openalex.org/', ''),
      name: map['display_name']?.toString() ?? L10nLookup.researcher,
      orcid: orcid?.isNotEmpty == true ? orcid : null,
      institutionName: institutionName,
      institutionNames: institutionNames,
      speciality:
          topConcepts.isNotEmpty ? topConcepts.first : L10nLookup.academicResearch,
      tags: topConcepts,
      worksCount: (map['works_count'] as num?)?.toInt() ?? 0,
      citedByCount: (map['cited_by_count'] as num?)?.toInt() ?? 0,
      hIndex: (stats?['h_index'] as num?)?.toInt() ?? 0,
      i10Index: (stats?['i10_index'] as num?)?.toInt() ?? 0,
      lastPublicationYear: lastYear,
    );
  }
}

class CsvSupervisorRow {
  final String name;
  final String university;
  final String speciality;
  final String bio;
  final String faculty;
  final String category;
  final List<String> tags;
  final List<String> methodologies;
  final bool isAvailable;
  final String? orcid;
  final String? scholarUrl;
  final String? researchGateUrl;

  CsvSupervisorRow({
    required this.name,
    required this.university,
    required this.speciality,
    required this.bio,
    required this.faculty,
    required this.category,
    this.tags = const [],
    List<String>? methodologies,
    this.isAvailable = true,
    this.orcid,
    this.scholarUrl,
    this.researchGateUrl,
  }) : methodologies = methodologies ?? L10nLookup.defaultMethodologies;
}

class SupervisorImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const SupervisorImportResult({
    required this.imported,
    required this.skipped,
    this.errors = const [],
  });
}
