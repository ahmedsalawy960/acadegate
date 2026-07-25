import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../profile/academic_profile.dart';
import '../../core/locale/app_translate.dart';

class MatchResult<T> {
  final T item;
  final int score;
  final List<String> reasons;

  const MatchResult({
    required this.item,
    required this.score,
    required this.reasons,
  });
}

class SmartMatchmakingEngine {
  static List<MatchResult<AcademicSupervisor>> matchSupervisors(
    AcademicProfile profile,
    List<AcademicSupervisor> supervisors, {
    int limit = 5,
  }) {
    if (supervisors.isEmpty) return [];

    final facultyId = profile.resolvedFacultyCategory;
    var pool = _supervisorPool(supervisors, facultyId, profile);

    final results = pool
        .map((supervisor) => _scoreSupervisor(
              profile,
              supervisor,
              facultyId: facultyId,
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return results.where((result) => result.score > 0).take(limit).toList();
  }

  static List<AcademicSupervisor> _supervisorPool(
    List<AcademicSupervisor> supervisors,
    String? facultyId,
    AcademicProfile profile,
  ) {
    var pool = supervisors;

    final realSupervisors = supervisors.where((item) => !item.isDemo).toList();
    if (realSupervisors.isNotEmpty) {
      pool = realSupervisors;
    }

    if (facultyId != null) {
      final inFaculty =
          pool.where((item) => _supervisorMatchesFaculty(item, facultyId)).toList();
      if (inFaculty.isNotEmpty) {
        pool = inFaculty;
      }
    }

    return pool;
  }

  static bool _supervisorMatchesFaculty(
    AcademicSupervisor supervisor,
    String facultyId,
  ) {
    if (supervisor.category == facultyId) return true;

    final facultyTitle = facultyTitleForCategory(facultyId).toLowerCase();
    final shortTitle = facultyTitle.replaceAll('كلية ', '').trim();
    final supervisorFaculty = supervisor.faculty.toLowerCase();

    if (supervisorFaculty.contains(facultyTitle) ||
        (shortTitle.isNotEmpty && supervisorFaculty.contains(shortTitle))) {
      return true;
    }

    return resolveFacultyId(supervisor.faculty) == facultyId;
  }

  static List<MatchResult<AcademicResearchIdea>> matchResearchIdeas(
    AcademicProfile profile,
    List<AcademicResearchIdea> ideas, {
    int limit = 3,
  }) {
    if (ideas.isEmpty) return [];

    final results = ideas
        .map((idea) => _scoreResearchIdea(profile, idea))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return results.where((result) => result.score > 0).take(limit).toList();
  }

  static List<MatchResult<AcademicLab>> matchLabs(
    AcademicProfile profile,
    List<AcademicLab> labs, {
    int limit = 3,
  }) {
    if (labs.isEmpty) return [];

    final facultyId = profile.resolvedFacultyCategory;
    var pool = labs;
    if (facultyId != null) {
      final inFaculty = labs
          .where(
            (lab) =>
                lab.facultyId == facultyId ||
                lab.category == facultyId ||
                resolveFacultyId(lab.facultyNameAr) == facultyId,
          )
          .toList();
      if (inFaculty.isNotEmpty) {
        pool = inFaculty;
      }
    }

    final results = pool
        .map((lab) => _scoreLab(profile, lab))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return results.where((result) => result.score > 0).take(limit).toList();
  }

  static MatchResult<AcademicSupervisor> _scoreSupervisor(
    AcademicProfile profile,
    AcademicSupervisor supervisor, {
    String? facultyId,
  }) {
    var score = 0;
    final reasons = <String>[];

    if (facultyId != null && _supervisorMatchesFaculty(supervisor, facultyId)) {
      score += 30;
      reasons.add(
        appTr('نفس كليتك الأكاديمية', 'Same academic faculty as you'),
      );
    }

    final profileKeywords = profile.keywords;
    final supervisorText = [
      supervisor.speciality,
      supervisor.bio,
      supervisor.faculty,
      supervisor.university,
      supervisor.category,
      ...supervisor.tags,
    ].join(' ').toLowerCase();

    var tagMatches = 0;
    for (final keyword in profileKeywords) {
      if (supervisorText.contains(keyword)) tagMatches++;
    }

    if (tagMatches > 0) {
      score += (tagMatches * 12).clamp(0, 48);
      reasons.add(
        appTr(
          'تطابق في مجال البحث والتخصص',
          'Match in research field and specialization',
        ),
      );
    }

    if (_containsEither(profile.specialization, supervisor.speciality)) {
      score += 20;
      reasons.add(
        appTr(
          'تخصصك قريب من تخصص المشرف',
          'Your field aligns with the supervisor\'s',
        ),
      );
    }

    if (_containsEither(profile.university, supervisor.university)) {
      score += 12;
      reasons.add(
        appTr('نفس الجامعة أو جهة قريبة', 'Same or nearby university'),
      );
    }

    if (supervisor.methodologies.contains(profile.methodology)) {
      score += 10;
      reasons.add(
        appTr('المنهجية البحثية متوافقة', 'Compatible research methodology'),
      );
    }

    if (_containsEither(profile.researchInterest, supervisor.bio)) {
      score += 15;
      reasons.add(
        appTr(
          'اهتمامك البحثي يتوافق مع خبرة المشرف',
          'Your research interest matches the supervisor\'s expertise',
        ),
      );
    }

    if (supervisor.isAvailable) {
      score += 5;
    }

    return MatchResult(
      item: supervisor,
      score: score.clamp(0, 100),
      reasons: reasons.toSet().take(3).toList(),
    );
  }

  static MatchResult<AcademicResearchIdea> _scoreResearchIdea(
    AcademicProfile profile,
    AcademicResearchIdea idea,
  ) {
    var score = 0;
    final reasons = <String>[];

    final ideaText = [
      idea.title,
      idea.provider,
      idea.details,
      ...idea.tags,
    ].join(' ').toLowerCase();

    var matches = 0;
    for (final keyword in profile.keywords) {
      if (ideaText.contains(keyword)) matches++;
    }

    if (matches > 0) {
      score += (matches * 15).clamp(0, 60);
      reasons.add(
        appTr(
          'الفكرة قريبة من اهتمامك البحثي',
          'Idea aligns with your research interest',
        ),
      );
    }

    if (_containsEither(profile.researchInterest, idea.title)) {
      score += 20;
      reasons.add(
        appTr(
          'عنوان الفكرة يشبه موضوع بحثك',
          'Idea title resembles your research topic',
        ),
      );
    }

    if (_containsEither(profile.specialization, idea.details)) {
      score += 10;
      reasons.add(
        appTr('تفاصيل الفكرة تخدم تخصصك', 'Idea details support your specialization'),
      );
    }

    return MatchResult(
      item: idea,
      score: score.clamp(0, 100),
      reasons: reasons.toSet().take(3).toList(),
    );
  }

  static MatchResult<AcademicLab> _scoreLab(
    AcademicProfile profile,
    AcademicLab lab,
  ) {
    var score = 0;
    final reasons = <String>[];

    final labText = [
      lab.name,
      lab.location,
      lab.equipment,
      ...lab.tags,
    ].join(' ').toLowerCase();

    var matches = 0;
    for (final keyword in profile.keywords) {
      if (labText.contains(keyword)) matches++;
    }

    if (matches > 0) {
      score += (matches * 14).clamp(0, 56);
      reasons.add(
        appTr('المختبر يخدم مجال دراستك', 'Lab serves your field of study'),
      );
    }

    if (_containsEither(profile.university, lab.location)) {
      score += 15;
      reasons.add(
        appTr('المختبر قريب من جامعتك', 'Lab is near your university'),
      );
    }

    if (_containsEither(profile.researchInterest, lab.equipment)) {
      score += 12;
      reasons.add(
        appTr('معدات المختبر مناسبة لبحثك', 'Lab equipment suits your research'),
      );
    }

    return MatchResult(
      item: lab,
      score: score.clamp(0, 100),
      reasons: reasons.toSet().take(3).toList(),
    );
  }

  static bool _containsEither(String a, String b) {
    final left = a.trim().toLowerCase();
    final right = b.trim().toLowerCase();
    if (left.isEmpty || right.isEmpty) return false;

    final leftParts = left.split(RegExp(r'[\s,،]+'));
    return leftParts.any(
      (part) => part.length >= 3 && right.contains(part),
    );
  }
}
