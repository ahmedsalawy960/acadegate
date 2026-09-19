import '../academic/faculty_categories.dart';
import '../academic/faculty_departments.dart';
import '../profile/academic_profile.dart';

/// Home faculty + department that literature and prose must stay inside.
class ThesisDiscipline {
  final String facultyId;
  final String departmentId;
  final String labelAr;
  final String labelEn;
  final List<String> searchTerms;
  final List<String> alienHints;

  const ThesisDiscipline({
    this.facultyId = '',
    this.departmentId = '',
    this.labelAr = '',
    this.labelEn = '',
    this.searchTerms = const [],
    this.alienHints = const [],
  });

  static const empty = ThesisDiscipline();

  bool get isPresent => facultyId.isNotEmpty || searchTerms.isNotEmpty;

  String get facultyAr => FacultyDepartments.facultyTitleAr(facultyId);

  String get facultyEn => FacultyDepartments.facultyTitleEn(facultyId);

  String departmentTitle(bool arabic) =>
      arabic ? (labelAr.isNotEmpty ? labelAr : labelEn) : (labelEn.isNotEmpty ? labelEn : labelAr);

  String get querySuffix {
    final terms = searchTerms.where((t) => t.trim().length >= 4).take(2);
    return terms.join(' ');
  }

  String promptBlock(bool arabic) {
    if (!isPresent) return '';
    if (arabic) {
      return 'التخصص الأكاديمي الملزم: $facultyAr'
          '${labelAr.isNotEmpty ? ' / $labelAr' : ''}. '
          'اكتب واستشهد فقط بما يقبله هذا القسم. '
          'ممنوع مراجع من كلية أو قسم آخر حتى لو شارك الموضوع العام.';
    }
    return 'Mandatory academic home: $facultyEn'
        '${labelEn.isNotEmpty ? ' / $labelEn' : ''}. '
        'Write and cite only what this department would accept. '
        'Reject sources from another faculty even if they share the broad topic.';
  }

  static ThesisDiscipline resolve({
    String? facultyId,
    String? departmentId,
    AcademicProfile? profile,
  }) {
    var faculty = (facultyId ?? '').trim();
    if (faculty.isEmpty) {
      faculty = profile?.resolvedFacultyCategory ?? '';
    }
    if (faculty.isEmpty) {
      faculty = inferFacultyCategoryFromText(
            '${profile?.specialization ?? ''} ${profile?.researchInterest ?? ''}',
          ) ??
          '';
    }
    if (faculty.isEmpty) return empty;

    final specialization = profile?.specialization.trim() ?? '';
    var dept = departmentId != null && departmentId.isNotEmpty
        ? FacultyDepartments.byId(faculty, departmentId)
        : null;
    dept ??= FacultyDepartments.match(faculty, specialization);
    final aliens = FacultyDepartments.alienHints[faculty] ?? const <String>[];

    if (dept != null) {
      return ThesisDiscipline(
        facultyId: faculty,
        departmentId: dept.id,
        labelAr: dept.titleAr,
        labelEn: dept.titleEn,
        searchTerms: dept.searchTerms,
        alienHints: aliens,
      );
    }

    if (specialization.isEmpty) {
      return ThesisDiscipline(
        facultyId: faculty,
        alienHints: aliens,
      );
    }
    return ThesisDiscipline(
      facultyId: faculty,
      departmentId: 'profile',
      labelAr: specialization,
      labelEn: specialization,
      searchTerms: specialization
          .split(RegExp(r'[\s,/،]+'))
          .where((w) => w.length >= 4)
          .take(6)
          .toList(),
      alienHints: aliens,
    );
  }
}
