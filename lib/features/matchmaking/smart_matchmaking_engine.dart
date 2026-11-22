import '../academic/academic_degrees.dart';
import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../lab_import/nbsle_university_cities.dart';
import '../profile/academic_profile.dart';
import '../../core/locale/app_translate.dart';

class MatchResult<T> {
  final T item;
  /// Topic fit, 0–100.
  final int score;
  /// Whether a supervision request can reach this person. Null for ideas and labs.
  final int? reachScore;
  final List<String> reasons;

  const MatchResult({
    required this.item,
    required this.score,
    required this.reasons,
    this.reachScore,
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
    return matchingTokens(text, tokens).length;
  }

  static List<String> matchingTokens(String text, Iterable<String> tokens) {
    final hay = text.toLowerCase();
    return meaningfulTokens(tokens).where((token) => hay.contains(token)).toList();
  }

  static String _wordList(List<String> words) => words.take(4).join(appTr('، ', ', '));

  static List<MatchResult<AcademicSupervisor>> matchSupervisors(
    AcademicProfile profile,
    List<AcademicSupervisor> supervisors, {
    int limit = 5,
    bool softFallback = true,
    List<String> requireTokens = const [],
    bool restrictFaculty = true,
    String thesisText = '',
  }) {
    if (supervisors.isEmpty || (softFallback && supervisors.isEmpty)) return [];

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
              thesisText: thesisText,
            ))
        .toList()
      ..sort((a, b) {
        final byTopic = b.score.compareTo(a.score);
        if (byTopic != 0) return byTopic;
        return (b.reachScore ?? 0).compareTo(a.reachScore ?? 0);
      });

    return results.where((result) => result.score > 0).take(limit).toList();
  }

  static List<AcademicSupervisor> _supervisorPool(
    List<AcademicSupervisor> supervisors,
    String? facultyId,
    AcademicProfile profile, {
    bool restrictFaculty = true,
  }) {
    var pool = supervisors
        .where(
          (item) =>
              !item.isDemo && item.isPubliclyVisible && item.isAvailable,
        )
        .toList();
    if (pool.isEmpty) {
      // لا نرجع بيانات تجريبية إذا وُجد طلب تقييد كلية — أفضل فراغ من ترشيح وهمي.
      if (restrictFaculty && (facultyId ?? '').isNotEmpty) return const [];
      pool = supervisors.where((item) => item.isPubliclyVisible).toList();
    }

    if (restrictFaculty && facultyId != null && facultyId.isNotEmpty) {
      final inFaculty = pool
          .where((item) => _supervisorMatchesFaculty(item, facultyId))
          .toList();
      // صارم: لا مشرفين من كليات أخرى ولا بلا كلية/تصنيف.
      pool = inFaculty;
    }

    return pool;
  }

  /// يشترط انتماءً واضحاً للكلية عبر category أو faculty القابل للحل — لا مطابقة غامضة.
  static bool _supervisorMatchesFaculty(
    AcademicSupervisor supervisor,
    String facultyId,
  ) {
    final category = supervisor.category.trim();
    if (category.isNotEmpty && category == facultyId) return true;

    final resolved = resolveFacultyId(supervisor.faculty);
    if (resolved != null && resolved == facultyId) return true;

    // بعض السجلات القديمة تخزّن عنوان الكلية في category كنص عربي.
    final fromCategoryTitle = resolveFacultyId(category);
    if (fromCategoryTitle != null && fromCategoryTitle == facultyId) {
      return true;
    }

    return false;
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

    return results.where((result) => result.score > 0).take(limit).toList();
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
      } else if (softFallback) {
        pool = const [];
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
    if (cityFirst) {
      return rankLabsCityFirst(
        scored,
        profile.city,
        localLimit: localLimit,
        otherLimit: otherLimit,
      );
    }
    return scored.take(limit).toList();
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
    String thesisText = '',
  }) {
    if (_rejectsStudentDegree(supervisor, profile)) {
      return MatchResult(
        item: supervisor,
        score: 0,
        reachScore: supervisor.hasMessagingAccount ? 100 : 0,
        reasons: const [],
      );
    }

    final profileTokens =
        requireTokens.isNotEmpty ? requireTokens : profile.topicKeywords;
    final thesisTokens = meaningfulTokens(
      thesisText.toLowerCase().split(RegExp(r'[\s,،.؛;:]+')),
    );
    final seekTokens = {...profileTokens, ...thesisTokens}.toList();
    final about = '${supervisor.speciality} ${supervisor.bio}';
    final thesisHits = matchingTokens(about, thesisTokens);
    final profileHits = matchingTokens(about, profileTokens)
        .where((token) => !thesisHits.contains(token))
        .toList();
    final matchedTopics = supervisor.tags
        .where((tag) => matchingTokens(tag, seekTokens).isNotEmpty)
        .take(3)
        .toList();

    if (seekTokens.isNotEmpty &&
        thesisHits.isEmpty &&
        profileHits.isEmpty &&
        matchedTopics.isEmpty) {
      return MatchResult(
        item: supervisor,
        score: 0,
        reachScore: supervisor.hasMessagingAccount ? 100 : 0,
        reasons: const [],
      );
    }

    var score = 0;
    final reasons = <String>[];

    if (thesisHits.isNotEmpty) {
      score += (thesisHits.length * 22).clamp(0, 66);
      reasons.add(
        appTr(
          'من ملف الرسالة: ${_wordList(thesisHits)}',
          'From your thesis file: ${_wordList(thesisHits)}',
        ),
      );
    }
    if (profileHits.isNotEmpty) {
      score += (profileHits.length * 12).clamp(0, 36);
      reasons.add(
        appTr(
          'من ملفك: ${_wordList(profileHits)}',
          'From your profile: ${_wordList(profileHits)}',
        ),
      );
    }
    if (matchedTopics.isNotEmpty) {
      score += (matchedTopics.length * 10).clamp(0, 30);
      reasons.add(
        appTr(
          'موضوعات نشره: ${matchedTopics.join(appTr('، ', ', '))}',
          'Publication topics: ${matchedTopics.join(', ')}',
        ),
      );
    }

    if (facultyId != null && _supervisorMatchesFaculty(supervisor, facultyId)) {
      score += 8;
      reasons.add(
        appTr('نفس كليتك الأكاديمية', 'Same academic faculty as you'),
      );
    }

    if (_containsEither(profile.university, supervisor.university)) {
      score += 4;
      reasons.add(
        appTr('نفس الجامعة أو جهة قريبة', 'Same or nearby university'),
      );
    }

    if (_explicitMethodology(supervisor.methodologies) &&
        supervisor.methodologies.contains(profile.methodology)) {
      score += 6;
      reasons.add(
        appTr('المنهجية البحثية متوافقة', 'Compatible research methodology'),
      );
    }

    return MatchResult(
      item: supervisor,
      score: score.clamp(0, 100),
      reachScore: supervisor.hasMessagingAccount ? 100 : 0,
      reasons: reasons.toSet().take(4).toList(),
    );
  }

  /// The default trio is filled in automatically and is not a real choice.
  static bool _explicitMethodology(List<String> methods) {
    final norm = methods
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    const arabic = {'كمي', 'نوعي', 'مختلط'};
    const english = {'quantitative', 'qualitative', 'mixed'};
    if (norm.length == 3 && norm.containsAll(arabic)) return false;
    if (norm.length == 3 && norm.containsAll(english)) return false;
    return norm.isNotEmpty;
  }

  static bool _rejectsStudentDegree(
    AcademicSupervisor supervisor,
    AcademicProfile profile,
  ) {
    final text =
        '${supervisor.speciality} ${supervisor.bio} ${supervisor.tags.join(' ')}'
            .toLowerCase();
    final phdOnly = text.contains('دكتوراه فقط') || text.contains('phd only');
    final mastersOnly = text.contains('ماجستير فقط') ||
        text.contains('masters only') ||
        text.contains("master's only");
    final masters = isMastersLevelDegree(profile.degree);
    final doctoral = isDoctoralDegree(profile.degree);
    if (phdOnly && masters && !doctoral) return true;
    if (mastersOnly && doctoral && !masters) return true;
    return false;
  }

  static MatchResult<AcademicResearchIdea> _scoreResearchIdea(
    AcademicProfile profile,
    AcademicResearchIdea idea, {
    List<String> requireTokens = const [],
  }) {
    final ideaText = [idea.title, idea.details, ...idea.tags].join(' ');
    final fieldTokens =
        requireTokens.isNotEmpty ? requireTokens : profile.topicKeywords;
    final hits = matchingTokens(ideaText, fieldTokens);
    if (fieldTokens.isNotEmpty && hits.isEmpty) {
      return MatchResult(item: idea, score: 0, reasons: const []);
    }
    if (_ideaRejectsDegree(idea, profile)) {
      return MatchResult(item: idea, score: 0, reasons: const []);
    }

    var score = 0;
    final reasons = <String>[];

    if (hits.isNotEmpty) {
      score += (hits.length * 18).clamp(0, 72);
      reasons.add(
        appTr(
          'كلمات مشتركة: ${_wordList(hits)}',
          'Shared words: ${_wordList(hits)}',
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
    if (level == 'phd' && isDoctoralDegree(profile.degree)) {
      score += 8;
      reasons.add(appTr('مناسبة لمستوى الدكتوراه', 'Fits doctoral level'));
    } else if (level == 'masters' && isMastersLevelDegree(profile.degree)) {
      score += 8;
      reasons.add(appTr('مناسبة لمستوى الماجستير', 'Fits master\'s level'));
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
    final hits = matchingTokens(topicText, fieldTokens);
    if (fieldTokens.isNotEmpty && hits.isEmpty) {
      return MatchResult(item: lab, score: 0, reasons: const []);
    }

    var score = 0;
    final reasons = <String>[];

    if (hits.isNotEmpty) {
      score += (hits.length * 18).clamp(0, 72);
      reasons.add(
        appTr(
          'كلمات مشتركة: ${_wordList(hits)}',
          'Shared words: ${_wordList(hits)}',
        ),
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

    if (hits.isNotEmpty && lab.acceptsExternalSamples) {
      score += 4;
      reasons.add(
        appTr('يقبل عينات خارجية', 'Accepts external samples'),
      );
    }

    if (hits.isNotEmpty && lab.offersSampleAnalysis) {
      score += 5;
      reasons.add(
        appTr('يوفر تحليل عينات', 'Offers sample analysis'),
      );
    }

    if (hits.isNotEmpty && lab.ratingAvg >= 4) {
      score += 3;
    }

    return MatchResult(
      item: lab,
      score: score.clamp(0, 100),
      reasons: reasons.toSet().take(3).toList(),
    );
  }

  static bool _ideaRejectsDegree(
    AcademicResearchIdea idea,
    AcademicProfile profile,
  ) {
    final level = idea.degreeLevel.toLowerCase().trim();
    if (level.isEmpty || level == 'both') return false;
    final masters = isMastersLevelDegree(profile.degree);
    final doctoral = isDoctoralDegree(profile.degree);
    if (level == 'phd' && masters && !doctoral) return true;
    if (level == 'masters' && doctoral && !masters) return true;
    return false;
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
