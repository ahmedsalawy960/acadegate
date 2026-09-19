import '../academic/faculty_categories.dart';
import 'import_models.dart';
import 'openalex_author_quality.dart';
import 'openalex_client.dart';
import 'openalex_faculty_mapper.dart';
import 'openalex_search_aliases.dart';
import 'supervisor_import_service.dart';

class SupervisorBulkSeedProgress {
  final String stage;
  final int universitiesDone;
  final int universitiesTotal;
  final int imported;
  final int skipped;
  final Map<String, int> byFaculty;

  const SupervisorBulkSeedProgress({
    required this.stage,
    required this.universitiesDone,
    required this.universitiesTotal,
    required this.imported,
    required this.skipped,
    required this.byFaculty,
  });
}

class SupervisorBulkSeedResult {
  final int imported;
  final int skipped;
  final Map<String, int> byFaculty;
  final List<String> errors;
  final List<String> universityNotes;

  const SupervisorBulkSeedResult({
    required this.imported,
    required this.skipped,
    required this.byFaculty,
    required this.errors,
    required this.universityNotes,
  });
}

/// تعبئة جماعية لملفات المشرفين من OpenAlex لكل كليات AcadeGate.
///
/// يعمل من حساب مدير داخل التطبيق. لا يخترع أسماء — يعتمد OpenAlex فقط.
class SupervisorBulkSeedService {
  SupervisorBulkSeedService._();

  static final SupervisorBulkSeedService instance = SupervisorBulkSeedService._();

  /// عدد الجامعات ذات الأولوية (القاهرة، عين شمس، …).
  static const defaultUniversityLimit = 8;

  /// هدف أدنى لكل كلية عبر كل الجامعات.
  static const perFacultyTarget = 28;

  /// سقف لكل كلية داخل جامعة واحدة (تنويع المصادر).
  static const perUniversityFacultyCap = 10;

  /// استبعاد الباحثين الضعاف جداً.
  static const minQualityScore = 45;

  Future<SupervisorBulkSeedResult> fillAllFaculties({
    bool autoApprove = true,
    int universityLimit = defaultUniversityLimit,
    void Function(SupervisorBulkSeedProgress progress)? onProgress,
  }) async {
    final universities =
        OpenAlexSearchAliases.prioritySeedUniversities(limit: universityLimit);
    final facultyIds = facultyCategoryIds()
        .where((id) => id != 'ProfessionalStudies')
        .toList();

    final selectedById = <String, OpenAlexAuthor>{};
    final facultyCounts = {for (final id in facultyIds) id: 0};
    final notes = <String>[];
    final errors = <String>[];
    var skipped = 0;

    onProgress?.call(
      SupervisorBulkSeedProgress(
        stage: 'starting',
        universitiesDone: 0,
        universitiesTotal: universities.length,
        imported: 0,
        skipped: 0,
        byFaculty: Map.of(facultyCounts),
      ),
    );

    for (var u = 0; u < universities.length; u++) {
      final seed = universities[u];
      onProgress?.call(
        SupervisorBulkSeedProgress(
          stage: seed.english,
          universitiesDone: u,
          universitiesTotal: universities.length,
          imported: selectedById.length,
          skipped: skipped,
          byFaculty: Map.of(facultyCounts),
        ),
      );

      try {
        final institution = await _resolveInstitution(seed);
        if (institution == null) {
          notes.add('${seed.english}: institution not found');
          continue;
        }

        final authors = await OpenAlexClient.instance.fetchAuthorsForInstitution(
          institutionId: institution.id,
          maxPages: 4,
        );

        final perFacultyThisUni = {for (final id in facultyIds) id: 0};

        // أعلى جودة أولاً داخل كل كلية.
        final ranked = List<OpenAlexAuthor>.from(authors)
          ..sort((a, b) {
            final qa = OpenAlexAuthorQuality.evaluate(a).score;
            final qb = OpenAlexAuthorQuality.evaluate(b).score;
            if (qa != qb) return qb.compareTo(qa);
            return b.citedByCount.compareTo(a.citedByCount);
          });

        for (final author in ranked) {
          if (selectedById.containsKey(author.id)) {
            skipped++;
            continue;
          }
          final quality = OpenAlexAuthorQuality.evaluate(author);
          if (quality.score < minQualityScore) {
            skipped++;
            continue;
          }

          final category = OpenAlexFacultyMapper.categoryIdFor(author);
          if (!facultyCounts.containsKey(category)) {
            skipped++;
            continue;
          }
          if (facultyCounts[category]! >= perFacultyTarget) continue;
          if (perFacultyThisUni[category]! >= perUniversityFacultyCap) continue;

          selectedById[author.id] = OpenAlexAuthor(
            id: author.id,
            name: author.name,
            orcid: author.orcid,
            institutionName: author.institutionName.trim().isNotEmpty
                ? author.institutionName
                : institution.name,
            institutionNames: author.institutionNames.isNotEmpty
                ? author.institutionNames
                : [institution.name],
            speciality: author.speciality,
            tags: author.tags,
            worksCount: author.worksCount,
            citedByCount: author.citedByCount,
            hIndex: author.hIndex,
            i10Index: author.i10Index,
            lastPublicationYear: author.lastPublicationYear,
            scholarUrl: author.scholarUrl,
          );
          facultyCounts[category] = facultyCounts[category]! + 1;
          perFacultyThisUni[category] = perFacultyThisUni[category]! + 1;
        }

        notes.add(
          '${institution.name}: kept ${perFacultyThisUni.values.fold<int>(0, (a, b) => a + b)} '
          'of ${authors.length} authors',
        );
      } catch (e) {
        errors.add('${seed.english}: $e');
      }

      // توقف مبكراً إن امتلأت كل الكليات.
      if (facultyCounts.values.every((c) => c >= perFacultyTarget)) break;
    }

    onProgress?.call(
      SupervisorBulkSeedProgress(
        stage: 'importing',
        universitiesDone: universities.length,
        universitiesTotal: universities.length,
        imported: selectedById.length,
        skipped: skipped,
        byFaculty: Map.of(facultyCounts),
      ),
    );

    if (selectedById.isEmpty) {
      return SupervisorBulkSeedResult(
        imported: 0,
        skipped: skipped,
        byFaculty: facultyCounts,
        errors: errors.isEmpty
            ? ['No authors selected — check OpenAlex connectivity.']
            : errors,
        universityNotes: notes,
      );
    }

    final result = await SupervisorImportService.instance.importOpenAlexAuthors(
      authors: selectedById.values.toList(),
      autoApprove: autoApprove,
    );

    return SupervisorBulkSeedResult(
      imported: result.imported,
      skipped: skipped + result.skipped,
      byFaculty: facultyCounts,
      errors: [...errors, ...result.errors],
      universityNotes: notes,
    );
  }

  Future<OpenAlexInstitution?> _resolveInstitution(SeedUniversity seed) async {
    final results =
        await OpenAlexClient.instance.searchInstitutions(seed.english);
    if (results.isEmpty) return null;
    if (seed.openAlexId != null) {
      final id = seed.openAlexId!;
      for (final item in results) {
        final raw = item.id.replaceAll('https://openalex.org/', '');
        if (raw == id || item.id.contains(id) || id.contains(raw)) {
          return item;
        }
      }
    }
    return results.first;
  }
}
