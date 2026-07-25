import '../matchmaking/smart_matchmaking_engine.dart';
import '../profile/academic_profile.dart';
import 'writing_categories.dart';
import 'writing_models.dart';

/// Match researchers to human writing experts by specialty, language, tools.
class WriterMatchEngine {
  WriterMatchEngine._();

  static List<MatchResult<WritingExpert>> matchWriters(
    AcademicProfile profile,
    List<WritingExpert> experts, {
    String? preferredCategoryTitle,
    int limit = 8,
  }) {
    if (experts.isEmpty) return const [];

    var pool = experts;
    if (preferredCategoryTitle != null &&
        preferredCategoryTitle.trim().isNotEmpty) {
      final filtered = experts
          .where((e) => e.category == preferredCategoryTitle)
          .toList();
      if (filtered.isNotEmpty) pool = filtered;
    }

    final results = pool
        .map((expert) => _score(profile, expert))
        .where((r) => r.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return results.take(limit).toList();
  }

  static MatchResult<WritingExpert> _score(
    AcademicProfile profile,
    WritingExpert expert,
  ) {
    var score = 10;
    final reasons = <String>[];
    final keywords = profile.keywords;
    final hay = [
      expert.speciality,
      expert.bio,
      expert.category,
      ...expert.tags,
      ...expert.tools,
      ...expert.languages,
    ].join(' ').toLowerCase();

    var keywordHits = 0;
    for (final kw in keywords) {
      if (kw.length < 3) continue;
      if (hay.contains(kw)) keywordHits++;
    }
    if (keywordHits > 0) {
      score += keywordHits * 8;
      reasons.add('تخصص متوافق');
    }

    final lang = profile.preferredLanguage.toLowerCase();
    if (lang.isNotEmpty) {
      final langHit = expert.languages.any(
        (l) =>
            l.toLowerCase().contains(lang) ||
            lang.contains(l.toLowerCase()) ||
            (lang.contains('arab') && l.contains('عرب')) ||
            (lang.contains('eng') &&
                (l.toLowerCase().contains('eng') || l.contains('إنجل'))),
      );
      if (langHit) {
        score += 15;
        reasons.add('لغة متوافقة');
      }
    }

    if (profile.methodology.trim().isNotEmpty) {
      final method = profile.methodology.toLowerCase();
      if (hay.contains(method) ||
          (method.contains('quant') && hay.contains('spss')) ||
          (method.contains('كم') &&
              (hay.contains('spss') || hay.contains('إحص'))) ||
          (method.contains('كيف') && hay.contains('كيف'))) {
        score += 12;
        reasons.add('منهجية قريبة');
      }
    }

    if (expert.tools.isNotEmpty && profile.skills.isNotEmpty) {
      final skillHits = expert.tools.where((t) {
        final tl = t.toLowerCase();
        return profile.skills.any((s) => s.toLowerCase().contains(tl) ||
            tl.contains(s.toLowerCase()));
      }).length;
      if (skillHits > 0) {
        score += skillHits * 6;
        reasons.add('أدوات مشتركة');
      }
    }

    if (expert.completedOrders > 0) {
      score += (expert.completedOrders.clamp(0, 20));
      reasons.add('${expert.completedOrders} طلب مكتمل');
    }
    if (expert.rating >= 4.0) {
      score += 8;
      reasons.add('تقييم ${expert.rating}');
    }
    if (expert.portfolioSamples.isNotEmpty) {
      score += 5;
      reasons.add('معرض أعمال');
    }

    final cat = writingCategoryByTitle(expert.category);
    if (cat != null) {
      reasons.insert(0, cat.localizedTitle);
    }

    return MatchResult(item: expert, score: score, reasons: reasons);
  }
}
