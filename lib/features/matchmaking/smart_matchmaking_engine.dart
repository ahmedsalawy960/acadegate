import '../academic/academic_models.dart';
import '../profile/academic_profile.dart';

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

    final results = supervisors
        .map((supervisor) => _scoreSupervisor(profile, supervisor))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matched = results.where((result) => result.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;

    return results.take(limit).map((result) {
      return MatchResult(
        item: result.item,
        score: result.score > 0 ? result.score : 25,
        reasons: result.reasons.isEmpty
            ? ['اقتراح عام — عدّل ملفك لمطابقة أدق']
            : result.reasons,
      );
    }).toList();
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

    final matched = results.where((result) => result.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;

    return results.take(limit).map((result) {
      return MatchResult(
        item: result.item,
        score: result.score > 0 ? result.score : 25,
        reasons: result.reasons.isEmpty
            ? ['فكرة مقترحة لك']
            : result.reasons,
      );
    }).toList();
  }

  static List<MatchResult<AcademicLab>> matchLabs(
    AcademicProfile profile,
    List<AcademicLab> labs, {
    int limit = 3,
  }) {
    if (labs.isEmpty) return [];

    final results = labs
        .map((lab) => _scoreLab(profile, lab))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final matched = results.where((result) => result.score > 0).take(limit).toList();
    if (matched.isNotEmpty) return matched;

    return results.take(limit).map((result) {
      return MatchResult(
        item: result.item,
        score: result.score > 0 ? result.score : 25,
        reasons: result.reasons.isEmpty
            ? ['مختبر متاح للاستكشاف']
            : result.reasons,
      );
    }).toList();
  }

  static MatchResult<AcademicSupervisor> _scoreSupervisor(
    AcademicProfile profile,
    AcademicSupervisor supervisor,
  ) {
    var score = 0;
    final reasons = <String>[];

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
      reasons.add('تطابق في مجال البحث والتخصص');
    }

    if (_containsEither(profile.specialization, supervisor.speciality)) {
      score += 20;
      reasons.add('تخصصك قريب من تخصص المشرف');
    }

    if (_containsEither(profile.university, supervisor.university)) {
      score += 12;
      reasons.add('نفس الجامعة أو جهة قريبة');
    }

    if (supervisor.methodologies.contains(profile.methodology)) {
      score += 10;
      reasons.add('المنهجية البحثية متوافقة');
    }

    if (_containsEither(profile.researchInterest, supervisor.bio)) {
      score += 15;
      reasons.add('اهتمامك البحثي يتوافق مع خبرة المشرف');
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
      reasons.add('الفكرة قريبة من اهتمامك البحثي');
    }

    if (_containsEither(profile.researchInterest, idea.title)) {
      score += 20;
      reasons.add('عنوان الفكرة يشبه موضوع بحثك');
    }

    if (_containsEither(profile.specialization, idea.details)) {
      score += 10;
      reasons.add('تفاصيل الفكرة تخدم تخصصك');
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
      reasons.add('المختبر يخدم مجال دراستك');
    }

    if (_containsEither(profile.university, lab.location)) {
      score += 15;
      reasons.add('المختبر قريب من جامعتك');
    }

    if (_containsEither(profile.researchInterest, lab.equipment)) {
      score += 12;
      reasons.add('معدات المختبر مناسبة لبحثك');
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
