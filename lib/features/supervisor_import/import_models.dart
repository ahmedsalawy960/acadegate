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
      name: map['display_name']?.toString() ?? 'مؤسسة',
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
  final String speciality;
  final List<String> tags;
  final int worksCount;
  final int citedByCount;
  final String? scholarUrl;

  const OpenAlexAuthor({
    required this.id,
    required this.name,
    this.orcid,
    required this.institutionName,
    required this.speciality,
    this.tags = const [],
    this.worksCount = 0,
    this.citedByCount = 0,
    this.scholarUrl,
  });

  String get bio =>
      'باحث في $institutionName. $worksCount منشور، $citedByCount استشهاد.';

  factory OpenAlexAuthor.fromMap(Map<String, dynamic> map) {
    final rawId = map['id']?.toString() ?? '';
    final institutions = map['last_known_institutions'] as List<dynamic>? ?? [];
    final institutionName = institutions.isNotEmpty
        ? institutions.first['display_name']?.toString() ?? ''
        : '';

    final concepts = map['x_concepts'] as List<dynamic>? ?? [];
    final topConcepts = concepts
        .take(5)
        .map((c) => c['display_name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final orcidRaw = map['orcid']?.toString();
    final orcid = orcidRaw?.replaceFirst('https://orcid.org/', '');

    return OpenAlexAuthor(
      id: rawId.replaceFirst('https://openalex.org/', ''),
      name: map['display_name']?.toString() ?? 'باحث',
      orcid: orcid?.isNotEmpty == true ? orcid : null,
      institutionName: institutionName,
      speciality: topConcepts.isNotEmpty ? topConcepts.first : 'بحث أكاديمي',
      tags: topConcepts,
      worksCount: (map['works_count'] as num?)?.toInt() ?? 0,
      citedByCount: (map['cited_by_count'] as num?)?.toInt() ?? 0,
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

  const CsvSupervisorRow({
    required this.name,
    required this.university,
    required this.speciality,
    required this.bio,
    required this.faculty,
    required this.category,
    this.tags = const [],
    this.methodologies = const ['كمي', 'نوعي', 'مختلط'],
    this.isAvailable = true,
    this.orcid,
    this.scholarUrl,
    this.researchGateUrl,
  });
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
