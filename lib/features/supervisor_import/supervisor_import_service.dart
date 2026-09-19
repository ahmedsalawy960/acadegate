import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../academic/faculty_categories.dart';
import '../../core/locale/l10n_lookup.dart';
import '../moderation/approval_status.dart';
import 'import_models.dart';
import 'multi_source_supervisor_service.dart';
import 'openalex_faculty_mapper.dart';
import 'openalex_search_aliases.dart';

class SupervisorImportService {
  SupervisorImportService._();

  static final SupervisorImportService instance = SupervisorImportService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static List<String> get supervisorCategories => facultyCategoryIds();

  Future<SupervisorImportResult> importCsvRows({
    required List<CsvSupervisorRow> rows,
    bool autoApprove = false,
  }) {
    return _importMaps(
      rows.map(_mapFromCsv).toList(),
      autoApprove: autoApprove,
    );
  }

  Future<SupervisorImportResult> importOpenAlexAuthors({
    required List<OpenAlexAuthor> authors,
    String? institutionName,
    bool autoApprove = false,
  }) {
    final maps = authors
        .map(
          (author) => _mapFromOpenAlex(
            author,
            institutionName: institutionName,
          ),
        )
        .toList();
    return _importMaps(maps, autoApprove: autoApprove);
  }

  Future<SupervisorImportResult> importSourceHits({
    required List<SupervisorSourceHit> hits,
    bool autoApprove = false,
  }) {
    return _importMaps(
      hits.map(_mapFromSourceHit).toList(),
      autoApprove: autoApprove,
    );
  }

  Map<String, dynamic> _mapFromSourceHit(SupervisorSourceHit hit) {
    return {
      'name': hit.name,
      'university': hit.institution,
      'speciality': hit.speciality.isNotEmpty
          ? hit.speciality
          : (hit.tags.isNotEmpty ? hit.tags.first : 'Academic research'),
      'bio': hit.toAcademicSupervisor().bio,
      'faculty': '',
      'category': '',
      'tags': hit.tags,
      'methodologies': L10nLookup.defaultMethodologies,
      'isAvailable': false,
      if (hit.orcid != null) 'orcid': hit.orcid,
      if (hit.openAlexId != null) 'openAlexId': hit.openAlexId,
      if (hit.officialPageUrl.isNotEmpty) 'scholarUrl': hit.officialPageUrl,
      'worksCount': hit.worksCount,
      'citedByCount': hit.citedByCount,
      'hIndex': hit.hIndex,
      'importSource': hit.sources.isEmpty
          ? 'multi'
          : hit.sources.map((s) => s.toLowerCase().replaceAll(' ', '_')).join('+'),
      'verificationStatus': 'imported_unverified',
    };
  }

  Map<String, dynamic> _mapFromCsv(CsvSupervisorRow row) {
    return {
      'name': row.name,
      'university': row.university,
      'speciality': row.speciality,
      'bio': row.bio.isEmpty
          ? L10nLookup.supervisorBioDefault(
              row.speciality.isEmpty ? row.faculty : row.speciality,
            )
          : row.bio,
      'faculty': row.faculty.isNotEmpty
          ? row.faculty
          : facultyTitleForCategory(row.category),
      'category': row.category,
      'tags': row.tags,
      'methodologies': row.methodologies,
      'isAvailable': row.isAvailable,
      if (row.orcid != null) 'orcid': row.orcid,
      if (row.scholarUrl != null) 'scholarUrl': row.scholarUrl,
      if (row.researchGateUrl != null) 'researchGateUrl': row.researchGateUrl,
      'importSource': 'csv',
    };
  }

  Map<String, dynamic> _mapFromOpenAlex(
    OpenAlexAuthor author, {
    String? institutionName,
  }) {
    final inferred = OpenAlexFacultyMapper.resolve(author);
    final faculty = inferred.facultyTitle;
    final category = inferred.categoryId;

    final scholarUrl = author.orcid != null
        ? 'https://scholar.google.com/scholar?q=${Uri.encodeComponent(author.name)}'
        : null;

    final institution = author.institutionName.trim().isNotEmpty
        ? author.institutionName.trim()
        : (institutionName?.trim() ?? '');

    final universityLabel = OpenAlexSearchAliases.formatUniversityWithFaculty(
      faculty: faculty,
      institution: institution,
    );

    return {
      'name': author.name,
      'university': universityLabel,
      'speciality': author.speciality,
      'bio': author.bio,
      'faculty': faculty,
      'category': category,
      'tags': author.tags,
      'methodologies': L10nLookup.defaultMethodologies,
      'isAvailable': false,
      'orcid': ?author.orcid,
      'scholarUrl': ?scholarUrl,
      'openAlexId': author.id,
      'worksCount': author.worksCount,
      'citedByCount': author.citedByCount,
      'hIndex': author.hIndex,
      'importSource': 'openalex',
      'verificationStatus': 'imported_unverified',
    };
  }

  Future<SupervisorImportResult> _importMaps(
    List<Map<String, dynamic>> items, {
    required bool autoApprove,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(L10nLookup.loginRequiredMessage);
    }

    final existingKeys = await _loadExistingKeys();
    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    final pending = <Map<String, dynamic>>[];

    for (final item in items) {
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        skipped++;
        continue;
      }

      final dedupeKey = _dedupeKey(item);
      if (existingKeys.contains(dedupeKey)) {
        skipped++;
        continue;
      }

      pending.add(item);
      existingKeys.add(dedupeKey);
    }

    for (var i = 0; i < pending.length; i += 400) {
      final chunk = pending.skip(i).take(400).toList();
      final batch = _db.batch();

      for (final item in chunk) {
        final doc = _db.collection('supervisors').doc();
        batch.set(doc, {
          ...item,
          'importedBy': user.uid,
          'ownerId': '',
          'approvalStatus':
              autoApprove ? ApprovalStatus.approved : ApprovalStatus.pending,
          'verificationStatus': item['verificationStatus'] ??
              (autoApprove ? 'verified' : 'pending_review'),
          'createdAt': FieldValue.serverTimestamp(),
          'importedAt': FieldValue.serverTimestamp(),
        });
      }

      try {
        await batch.commit();
        imported += chunk.length;
      } catch (error) {
        errors.add(error.toString());
      }
    }

    return SupervisorImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
    );
  }

  String _dedupeKey(Map<String, dynamic> item) {
    final openAlexId = item['openAlexId']?.toString();
    if (openAlexId != null && openAlexId.isNotEmpty) {
      return 'openalex:$openAlexId';
    }
    final orcid = item['orcid']?.toString();
    if (orcid != null && orcid.isNotEmpty) {
      return 'orcid:$orcid';
    }
    final name = item['name']?.toString().toLowerCase().trim() ?? '';
    final university = item['university']?.toString().toLowerCase().trim() ?? '';
    return 'name:$name|$university';
  }

  Future<Set<String>> _loadExistingKeys() async {
    final snapshot = await _db.collection('supervisors').get();
    final keys = <String>{};

    for (final doc in snapshot.docs) {
      keys.add(_dedupeKey(doc.data()));
    }

    return keys;
  }
}
