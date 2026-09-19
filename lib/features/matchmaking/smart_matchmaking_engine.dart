import '../academic/academic_degrees.dart';
import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../lab_import/nbsle_university_cities.dart';
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
  static const _shortScience = {
    'gc', 'ms', 'nmr', 'pcr', 'hplc', 'oil', 'dna', 'rna', 'uv', 'ir',
    'icp', 'xrd', 'sem', 'tem', 'ftir',
  };

  static bool _isMeaningfulToken(String t) {
    if (_shortScience.contains(t)) return true;
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(t)) return t.length >= 3;
    return t.length >= 4;
  }

  static List<String> meaningfulTokens(Iterable<String> raw) {
    return raw
        .map((t) => t.trim().toLowerCase())
        .where(_isMeaningfulToken)
        .toSet()
        .toList();
  }

  static int topicHitCount(String text, Iterable<String> tokens) {
    final hay = text.toLowerCase();
    var n = 0;
    for (final token in meaningfulTokens(tokens)) {
      if (hay.contains(token)) n++;
    }
    return n;
  }

  static List<MatchResult<AcademicSupervisor>> matchSupervisors(
    AcademicProfile profile,
    List<AcademicSupervisor> supervisors, {
    int limit = 5,
    bool softFallback = true,
    List<String> requireTokens = const [],
    bool restrictFaculty = true,
  }) {
    if (supervisors.isEmpty) return [];

    final facultyId = profile.resolvedFacultyCategory;
    var pool = _supervisorPool(
      supervisors,
      facultyId,
      profile,
      restrictFaculty: restrictFaculty,
    );

    final results = pool
        .map((supervisor) => _scoreSupervisor(
              profile,
              supervisor,
              facultyId: facultyId,
              requireTokens: requireTokens,
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matched = results
        .where((result) => result.score > 0)
        .take(limit)
        .toList();
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
    AcademicProfile profile, {
    bool restrictFaculty = true,
  }) {
    var pool = supervisors;

    final realSupervisors = supervisors.where((item) => !item.isDemo).toList();
    if (realSupervisors.isNotEmpty) {
      pool = realSupervisors;
    }

    if (restrictFaculty && facultyId != null) {
      final inFaculty =
          pool.where((item) => _supervisorMatchesFaculty(item, facultyId)).toList();
      if (inFaculty.isNotEmpty) {
        pool = inFaculty;
      } else {
        // لا تُرجع مشرفين من كليات أخرى عند التقييد الصارم.
        pool = const [];
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
    List<String> requireTokens = const [],
    bool restrictFaculty = true,
  }) {
    if (ideas.isEmpty) return [];

    final facultyId = profile.resolvedFacultyCategory;
    var pool = ideas;
    if (restrictFaculty && facultyId != null && facultyId.isNotEmpty) {
      final inFaculty =
          ideas.where((idea) => idea.category == facultyId).toList();
      pool = inFaculty; // صارم: لا أفكار من كليات أخرى
    }

    if (pool.isEmpty) {
      if (!softFallback) return [];
      pool = ideas;
    }

    final results = pool
        .map(
          (idea) => _scoreResearchIdea(
            profile,
            idea,
            requireTokens: requireTokens,
          ),
        )
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
    List<String> requireTokens = const [],
    bool restrictFaculty = true,
    bool cityFirst = false,
    int localLimit = 8,
    int otherLimit = 6,
  }) {
    if (labs.isEmpty) return [];

    final facultyId = profile.resolvedFacultyCategory;
    var pool = labs;
    if (restrictFaculty && facultyId != null) {
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
      } else {
        pool = const [];
      }
    }

    final results = pool
        .map(
          (lab) => _scoreLab(
            profile,
            lab,
            facultyId: facultyId,
            requireTokens: requireTokens,
          ),
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final scored = results.where((result) => result.score > 0).toList();
    final matched = cityFirst
        ? rankLabsCityFirst(
            scored,
            profile.city,
            localLimit: localLimit,
            otherLimit: otherLimit,
          )
        : scored.take(limit).toList();
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

  static List<MatchResult<AcademicLab>> rankLabsCityFirst(
    List<MatchResult<AcademicLab>> matches,
    String researcherCity, {
    int localLimit = 8,
    int otherLimit = 6,
  }) {
    if (matches.isEmpty) return const [];
    if (researcherCity.trim().isEmpty) {
      return matches.take(localLimit + otherLimit).toList();
    }
    final local = <MatchResult<AcademicLab>>[];
    final other = <MatchResult<AcademicLab>>[];
    for (final match in matches) {
      if (NbsleUniversityCities.isSameCity(match.item.city, researcherCity) ||
          NbsleUniversityCities.isSameCity(match.item.location, researcherCity)) {
        local.add(match);
      } else {
        other.add(match);
      }
    }
    return [...local.take(localLimit), ...other.take(otherLimit)];
  }

  static MatchResult<AcademicSupervisor> _scoreSupervisor(
    AcademicProfile profile,
    AcademicSupervisor supervisor, {
    String? facultyId,
    List<String> requireTokens = const [],
  }) {
    final topicText = [
      supervisor.speciality,
      supervisor.bio,
      ...supervisor.tags,
    ].join(' ');
    final fieldTokens =
        requireTokens.isNotEmpty ? requireTokens : profile.topicKeywords;
    final topicHits = topicHitCount(topicText, fieldTokens);
    if (fieldTokens.isNotEmpty && topicHits == 0) {
      return MatchResult(item: supervisor, score: 0, reasons: const []);
    }

    var score = 0;
    final reasons = <String>[];

    if (topicHits > 0) {
      score += (topicHits * 16).clamp(0, 64);
      reasons.add(
        appTr(
          'تطابق في مجال البحث والتخصص',
          'Match in research field and specialization',
        ),
      );
    }

    if (facultyId != null && _supervisorMatchesFaculty(supervisor, facultyId)) {
      score += 10;
      reasons.add(
        appTr('نفس كليتك الأكاديمية', 'Same academic faculty as you'),
      );
    }

    if (_containsEither(profile.specialization, supervisor.speciality)) {
      score += 18;
      reasons.add(
        appTr(
          'تخصصك قريب من تخصص المشرف',
          'Your field aligns with the supervisor\'s',
        ),
      );
    }

    if (_containsEither(profile.university, supervisor.university)) {
      score += 6;
      reasons.add(
        appTr('نفس الجامعة أو جهة قريبة', 'Same or nearby university'),
      );
    }

    if (supervisor.methodologies.contains(profile.methodology)) {
      score += 6;
      reasons.add(
        appTr('المنهجية البحثية متوافقة', 'Compatible research methodology'),
      );
    }

    if (_containsEither(profile.researchInterest, supervisor.bio)) {
      score += 12;
      reasons.add(
        appTr(
          'اهتمامك البحثي يتوافق مع خبرة المشرف',
          'Your research interest matches the supervisor\'s expertise',
        ),
      );
    }

    if (supervisor.isAvailable) {
      score += 3;
    }

    if (supervisor.worksCount >= 15) {
      score += 4;
      reasons.add(
        appTr(
          'إنتاج علمي مسجّل على الملف (${supervisor.worksCount} عملاً)',
          'Recorded scientific output on file (${supervisor.worksCount} works)',
        ),
      );
    }
    if (supervisor.hIndex >= 5) {
      score += 3;
      reasons.add(
        appTr(
          'H-index ${supervisor.hIndex} من بيانات المشرف',
          'H-index ${supervisor.hIndex} from supervisor data',
        ),
      );
    }

    return MatchResult(
      item: supervisor,
      score: score.clamp(0, 100),
      reasons: reasons.toSet().take(4).toList(),
    );
  }

  static MatchResult<AcademicResearchIdea> _scoreResearchIdea(
    AcademicProfile profile,
    AcademicResearchIdea idea, {
    List<String> requireTokens = const [],
  }) {
    final ideaText = [idea.title, idea.details, ...idea.tags].join(' ');
    final fieldTokens =
        requireTokens.isNotEmpty ? requireTokens : profile.topicKeywords;
    final topicHits = topicHitCount(ideaText, fieldTokens);
    if (fieldTokens.isNotEmpty && topicHits == 0) {
      return MatchResult(item: idea, score: 0, reasons: const []);
    }

    var score = 0;
    final reasons = <String>[];

    if (topicHits > 0) {
      score += (topicHits * 18).clamp(0, 72);
      reasons.add(
        appTr(
          'الفكرة قريبة من اهتمامك البحثي',
          'Idea aligns with your research interest',
        ),
      );
    }

    final facultyId = profile.resolvedFacultyCategory;
    if (facultyId != null &&
        idea.category.isNotEmpty &&
        idea.category == facultyId) {
      score += 8;
      reasons.add(
        appTr('نفس كليتك الأكاديمية', 'Same academic faculty as you'),
      );
    }

    final level = idea.degreeLevel.toLowerCase().trim();
    if (level.isNotEmpty) {
      final doctoral = isDoctoralDegree(profile.degree);
      final masters = isMastersLevelDegree(profile.degree);
      if (level == 'both') {
        score += 6;
      } else if (level == 'phd' && doctoral) {
        score += 10;
        reasons.add(
          appTr('مناسبة لمستوى الدكتوراه', 'Fits doctoral level'),
        );
      } else if (level == 'masters' && masters) {
        score += 10;
        reasons.add(
          appTr('مناسبة لمستوى الماجستير', 'Fits master\'s level'),
        );
      } else if ((level == 'phd' && masters) || (level == 'masters' && doctoral)) {
        score -= 8;
      }
    }

    if (_containsEither(profile.researchInterest, idea.title)) {
      score += 16;
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

    final feasibility = idea.feasibilityScore;
    if (feasibility != null && feasibility >= 0.7) {
      score += 4;
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
    List<String> requireTokens = const [],
  }) {
    final equipmentNames = [
      ...lab.equipmentList.map((e) => e.name),
      ...lab.equipmentNameHints,
    ].join(' ');
    final serviceNames = lab.sampleServices.map((s) => s.name).join(' ');
    final topicText = [
      lab.name,
      lab.equipment,
      equipmentNames,
      serviceNames,
      lab.description,
      ...lab.tags,
    ].join(' ');
    final fieldTokens =
        requireTokens.isNotEmpty ? requireTokens : profile.topicKeywords;
    final topicHits = topicHitCount(topicText, fieldTokens);
    if (fieldTokens.isNotEmpty && topicHits == 0) {
      return MatchResult(item: lab, score: 0, reasons: const []);
    }

    var score = 0;
    final reasons = <String>[];

    if (topicHits > 0) {
      score += (topicHits * 18).clamp(0, 72);
      reasons.add(
        appTr('المختبر يخدم مجال دراستك', 'Lab serves your field of study'),
      );
    }

    if (facultyId != null &&
        (lab.facultyId == facultyId ||
            lab.category == facultyId ||
            resolveFacultyId(lab.facultyNameAr) == facultyId)) {
      score += 10;
      reasons.add(
        appTr('نفس كليتك الأكاديمية', 'Same academic faculty as you'),
      );
    }

    if (_containsEither(profile.university, lab.university) ||
        _containsEither(profile.university, lab.location)) {
      score += 6;
      reasons.add(
        appTr('المختبر قريب من جامعتك', 'Lab is near your university'),
      );
    }

    if (NbsleUniversityCities.isSameCity(profile.city, lab.city) ||
        NbsleUniversityCities.isSameCity(profile.city, lab.location)) {
      score += 8;
      reasons.add(appTr('نفس مدينتك', 'Same city as you'));
    }

    if (_containsEither(profile.researchInterest, lab.equipment) ||
        _containsEither(profile.researchInterest, equipmentNames) ||
        _containsEither(profile.specialization, serviceNames)) {
      score += 16;
      reasons.add(
        appTr('معدات/خدمات مناسبة لبحثك', 'Equipment/services suit your research'),
      );
    }

    if (topicHits > 0 && lab.acceptsExternalSamples) {
      score += 4;
      reasons.add(
        appTr('يقبل عينات خارجية', 'Accepts external samples'),
      );
    }

    if (topicHits > 0 && lab.offersSampleAnalysis) {
      score += 5;
      reasons.add(
        appTr('يوفر تحليل عينات', 'Offers sample analysis'),
      );
    }

    if (topicHits > 0 && lab.ratingAvg >= 4) {
      score += 3;
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
