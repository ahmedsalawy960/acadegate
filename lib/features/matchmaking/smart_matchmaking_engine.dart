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
    bool softFallback = true,
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

    final matched =
        results.where((result) => result.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;
    if (!softFallback) return [];
    return results.take(limit).map((result) {
      if (result.score > 0) return result;
      return MatchResult(
        item: result.item,
        score: 20,
        reasons: [
          appTr(
            'مشرف مقترح يمكن أن يفيد مسارك',
            'Suggested supervisor who may help your path',
          ),
        ],
      );
    }).toList();
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
    bool softFallback = true,
  }) {
    if (ideas.isEmpty) return [];

    final results = ideas
        .map((idea) => _scoreResearchIdea(profile, idea))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matched =
        results.where((result) => result.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;
    if (!softFallback) return [];
    return results.take(limit).map((result) {
      if (result.score > 0) return result;
      return MatchResult(
        item: result.item,
        score: 18,
        reasons: [
          appTr(
            'فكرة مقترحة قد تلهم موضوعك',
            'Suggested idea that may inspire your topic',
          ),
        ],
      );
    }).toList();
  }

  static List<MatchResult<AcademicLab>> matchLabs(
    AcademicProfile profile,
    List<AcademicLab> labs, {
    int limit = 3,
    bool softFallback = true,
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
        .map((lab) => _scoreLab(profile, lab, facultyId: facultyId))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matched =
        results.where((result) => result.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;
    if (!softFallback) return [];

    // Always offer useful labs for the faculty/topic rather than an empty step.
    return results.take(limit).map((result) {
      if (result.score > 0) return result;
      return MatchResult(
        item: result.item,
        score: 22,
        reasons: [
          appTr(
            'مختبر مقترح يمكن أن يفيد بحثك',
            'Suggested lab that may help your research',
          ),
        ],
      );
    }).toList();
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
    AcademicLab lab, {
    String? facultyId,
  }) {
    var score = 0;
    final reasons = <String>[];

    final equipmentNames = lab.equipmentList.map((e) => e.name).join(' ');
    final serviceNames = lab.sampleServices.map((s) => s.name).join(' ');
    final labText = [
      lab.name,
      lab.location,
      lab.city,
      lab.university,
      lab.equipment,
      equipmentNames,
      serviceNames,
      lab.description,
      lab.facultyNameAr,
      lab.facultyId,
      lab.category,
      lab.labType,
      ...lab.tags,
    ].join(' ').toLowerCase();

    if (facultyId != null &&
        (lab.facultyId == facultyId ||
            lab.category == facultyId ||
            resolveFacultyId(lab.facultyNameAr) == facultyId)) {
      score += 32;
      reasons.add(
        appTr('نفس كليتك الأكاديمية', 'Same academic faculty as you'),
      );
    }

    var matches = 0;
    for (final keyword in profile.keywords) {
      if (keyword.length >= 3 && labText.contains(keyword)) matches++;
    }

    if (matches > 0) {
      score += (matches * 14).clamp(0, 56);
      reasons.add(
        appTr('المختبر يخدم مجال دراستك', 'Lab serves your field of study'),
      );
    }

    if (_containsEither(profile.university, lab.university) ||
        _containsEither(profile.university, lab.location)) {
      score += 15;
      reasons.add(
        appTr('المختبر قريب من جامعتك', 'Lab is near your university'),
      );
    }

    if (_containsEither(profile.city, lab.city)) {
      score += 10;
      reasons.add(appTr('نفس مدينتك', 'Same city as you'));
    }

    if (_containsEither(profile.researchInterest, lab.equipment) ||
        _containsEither(profile.researchInterest, equipmentNames) ||
        _containsEither(profile.specialization, serviceNames)) {
      score += 14;
      reasons.add(
        appTr('معدات/خدمات مناسبة لبحثك', 'Equipment/services suit your research'),
      );
    }

    if (lab.acceptsExternalSamples) {
      score += 6;
      reasons.add(
        appTr('يقبل عينات خارجية', 'Accepts external samples'),
      );
    }

    if (lab.offersSampleAnalysis) {
      score += 8;
      reasons.add(
        appTr('يوفر تحليل عينات', 'Offers sample analysis'),
      );
    }

    if (lab.ratingAvg >= 4) {
      score += 4;
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
