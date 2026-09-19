import '../academic/academic_models.dart';
import '../academic_integrity/semantic_scholar_client.dart';
import '../../core/locale/app_translate.dart';
import 'import_models.dart';
import 'official_university_directories.dart';
import 'openalex_client.dart';
import 'openalex_search_aliases.dart';
import 'orcid_client.dart';
import 'wikidata_academics_client.dart';

class SupervisorSourceHit {
  final String name;
  final String institution;
  final String speciality;
  final List<String> tags;
  final String? orcid;
  final String? openAlexId;
  final String? semanticScholarId;
  final List<String> sources;
  final String officialPageUrl;
  final int worksCount;
  final int citedByCount;
  final int hIndex;

  const SupervisorSourceHit({
    required this.name,
    required this.institution,
    this.speciality = '',
    this.tags = const [],
    this.orcid,
    this.openAlexId,
    this.semanticScholarId,
    this.sources = const [],
    this.officialPageUrl = '',
    this.worksCount = 0,
    this.citedByCount = 0,
    this.hIndex = 0,
  });

  String get sourceLabel => sources.join(' · ');

  AcademicSupervisor toAcademicSupervisor() {
    return AcademicSupervisor(
      name: name,
      university: institution,
      speciality: speciality.isNotEmpty
          ? speciality
          : (tags.isNotEmpty ? tags.first : appTr('بحث أكاديمي', 'Academic research')),
      bio: appTr(
        'ملف من ${sourceLabel.isEmpty ? 'مصادر أكاديمية' : sourceLabel}'
        '${orcid != null ? ' — ORCID $orcid' : ''}.',
        'Record from ${sourceLabel.isEmpty ? 'academic sources' : sourceLabel}'
        '${orcid != null ? ' — ORCID $orcid' : ''}.',
      ),
      faculty: '',
      category: '',
      tags: tags,
      orcid: orcid ?? '',
      openAlexId: openAlexId ?? '',
      scholarUrl: officialPageUrl,
      worksCount: worksCount,
      citedByCount: citedByCount,
      hIndex: hIndex,
      importSource: sources.map((s) => s.toLowerCase().replaceAll(' ', '_')).join('+'),
      isAvailable: false,
    );
  }

  SupervisorSourceHit merge(SupervisorSourceHit other) {
    return SupervisorSourceHit(
      name: name.length >= other.name.length ? name : other.name,
      institution: institution.isNotEmpty ? institution : other.institution,
      speciality: speciality.isNotEmpty ? speciality : other.speciality,
      tags: {...tags, ...other.tags}.toList(),
      orcid: orcid ?? other.orcid,
      openAlexId: openAlexId ?? other.openAlexId,
      semanticScholarId: semanticScholarId ?? other.semanticScholarId,
      sources: {...sources, ...other.sources}.toList(),
      officialPageUrl:
          officialPageUrl.isNotEmpty ? officialPageUrl : other.officialPageUrl,
      worksCount: worksCount >= other.worksCount ? worksCount : other.worksCount,
      citedByCount:
          citedByCount >= other.citedByCount ? citedByCount : other.citedByCount,
      hIndex: hIndex >= other.hIndex ? hIndex : other.hIndex,
    );
  }

  static String dedupeKey(SupervisorSourceHit hit) {
    if (hit.orcid != null && hit.orcid!.isNotEmpty) {
      return 'orcid:${hit.orcid!.toLowerCase()}';
    }
    if (hit.openAlexId != null && hit.openAlexId!.isNotEmpty) {
      return 'openalex:${hit.openAlexId}';
    }
    return 'name:${hit.name.toLowerCase().trim()}|${hit.institution.toLowerCase().trim()}';
  }
}

class MultiSourceSupervisorService {
  MultiSourceSupervisorService._();

  static final MultiSourceSupervisorService instance =
      MultiSourceSupervisorService._();

  Future<List<SupervisorSourceHit>> search({
    String topic = '',
    String university = '',
    String personName = '',
    int limit = 24,
  }) async {
    final englishUni = OpenAlexSearchAliases.suggestedInstitutionEnglish(university) ??
        (university.trim().length >= 3 &&
                !OpenAlexSearchAliases.containsArabic(university)
            ? university.trim()
            : '');
    final directory = OfficialUniversityDirectories.match(
      university.isNotEmpty ? university : englishUni,
    );
    final affiliation = englishUni.isNotEmpty
        ? englishUni
        : (directory?.english ?? university.trim());
    final keyword = topic.trim();

    final collected = <SupervisorSourceHit>[];

    Future<void> addOpenAlex() async {
      try {
        if (personName.trim().length >= 2) {
          final authors = await OpenAlexClient.instance.searchAuthors(
            query: personName.trim(),
            perPage: 15,
          );
          collected.addAll(authors.map((a) => _fromOpenAlex(a, directory)));
        } else if (affiliation.length >= 3) {
          final institutions =
              await OpenAlexClient.instance.searchInstitutions(affiliation);
          if (institutions.isEmpty) return;
          final authors = await OpenAlexClient.instance.searchAuthors(
            query: keyword.length >= 3 ? keyword : affiliation,
            institutionId: institutions.first.id,
            perPage: 15,
          );
          collected.addAll(authors.map((a) => _fromOpenAlex(a, directory)));
        }
      } catch (_) {}
    }

    Future<void> addOrcid() async {
      try {
        final rows = await OrcidClient.instance.search(
          name: personName.trim().isEmpty ? null : personName.trim(),
          affiliation: affiliation.length >= 3 ? affiliation : null,
          keyword: keyword.length >= 3 ? keyword : null,
          rows: 15,
        );
        collected.addAll(rows.map((p) => _fromOrcid(p, directory, keyword)));
      } catch (_) {}
    }

    Future<void> addWikidata() async {
      try {
        if (affiliation.length < 4) return;
        final rows = await WikidataAcademicsClient.instance.searchEmployedAt(
          universityEnglish: affiliation,
          topic: keyword.length >= 4 ? keyword : null,
          limit: 15,
        );
        collected.addAll(rows.map((p) => _fromWikidata(p, directory, keyword)));
      } catch (_) {}
    }

    Future<void> addSemanticScholar() async {
      try {
        final query = [
          if (personName.trim().length >= 3) personName.trim(),
          if (keyword.length >= 3) keyword,
          if (affiliation.length >= 3) affiliation,
        ].join(' ');
        if (query.trim().length < 3) return;
        final authors = await SemanticScholarClient.instance.searchAuthors(
          query,
          limit: 10,
        );
        collected.addAll(authors.map((a) => _fromSemantic(a, directory, keyword)));
      } catch (_) {}
    }

    await Future.wait([
      addOpenAlex(),
      addOrcid(),
      addWikidata(),
      addSemanticScholar(),
    ]);

    return mergeHits(collected).take(limit).toList();
  }

  static List<SupervisorSourceHit> mergeHits(List<SupervisorSourceHit> hits) {
    final merged = <String, SupervisorSourceHit>{};
    for (final hit in hits) {
      if (hit.name.trim().length < 3) continue;
      final key = SupervisorSourceHit.dedupeKey(hit);
      final existing = merged[key];
      merged[key] = existing == null ? hit : existing.merge(hit);
    }
    final list = merged.values.toList()
      ..sort((a, b) {
        final src = b.sources.length.compareTo(a.sources.length);
        if (src != 0) return src;
        return b.citedByCount.compareTo(a.citedByCount);
      });
    return list;
  }

  SupervisorSourceHit _fromOpenAlex(
    OpenAlexAuthor author,
    OfficialUniversityDirectory? directory,
  ) {
    return SupervisorSourceHit(
      name: author.name,
      institution: author.institutionName.trim().isNotEmpty
          ? author.institutionName
          : (directory?.english ?? ''),
      speciality: author.speciality,
      tags: author.tags,
      orcid: author.orcid,
      openAlexId: author.id,
      sources: const ['OpenAlex'],
      officialPageUrl: directory?.displayUrl ?? '',
      worksCount: author.worksCount,
      citedByCount: author.citedByCount,
      hIndex: author.hIndex,
    );
  }

  SupervisorSourceHit _fromOrcid(
    OrcidProfile profile,
    OfficialUniversityDirectory? directory,
    String topic,
  ) {
    return SupervisorSourceHit(
      name: profile.name,
      institution: profile.institutions.isNotEmpty
          ? profile.institutions.first
          : (directory?.english ?? ''),
      speciality: profile.speciality,
      tags: [
        ...profile.keywords,
        if (topic.length >= 3) topic,
      ],
      orcid: profile.orcid,
      sources: const ['ORCID'],
      officialPageUrl: profile.officialUrl.isNotEmpty
          ? profile.officialUrl
          : (directory?.displayUrl ?? ''),
    );
  }

  SupervisorSourceHit _fromWikidata(
    WikidataAcademic person,
    OfficialUniversityDirectory? directory,
    String topic,
  ) {
    return SupervisorSourceHit(
      name: person.name,
      institution: person.institution.isNotEmpty
          ? person.institution
          : (directory?.english ?? ''),
      tags: [
        if (topic.length >= 3) topic,
        'university staff',
      ],
      orcid: person.orcid,
      sources: [
        'Wikidata',
        if (directory != null) 'Official university site',
      ],
      officialPageUrl: person.officialUrl.isNotEmpty
          ? person.officialUrl
          : (directory?.displayUrl ?? person.wikidataUrl),
    );
  }

  SupervisorSourceHit _fromSemantic(
    SemanticScholarAuthor author,
    OfficialUniversityDirectory? directory,
    String topic,
  ) {
    return SupervisorSourceHit(
      name: author.name,
      institution: author.affiliations.isNotEmpty
          ? author.affiliations.first
          : (directory?.english ?? ''),
      tags: [
        if (topic.length >= 3) topic,
        ...author.affiliations.take(2),
      ],
      orcid: author.orcid,
      semanticScholarId: author.authorId,
      sources: const ['Semantic Scholar'],
      officialPageUrl:
          author.url.isNotEmpty ? author.url : (directory?.displayUrl ?? ''),
      worksCount: author.paperCount,
      citedByCount: author.citationCount,
      hIndex: author.hIndex,
    );
  }
}
