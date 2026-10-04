/// يختار صورة من مجموعة محلية حسب رقم الأسبوع (تتغيّر كل أسبوع).
class WeeklyImageRotator {
  WeeklyImageRotator._();

  /// أسبوع السنة (1–53) — ثابت طوال الأسبوع الحالي.
  static int weekOfYear([DateTime? now]) {
    final date = now ?? DateTime.now();
    final start = DateTime(date.year);
    final dayOfYear = date.difference(start).inDays;
    return (dayOfYear ~/ 7) + 1;
  }

  /// يختار مساراً من [variants] حسب الأسبوع.
  static String pick(List<String> variants, {DateTime? now}) {
    if (variants.isEmpty) return '';
    if (variants.length == 1) return variants.first;
    final index = (weekOfYear(now) - 1) % variants.length;
    return variants[index];
  }
}

/// كتالوج الصور الأصلية الأسبوعية (مولَّدة للتطبيق — ليست Unsplash).
class AcadeGateWeeklyImages {
  AcadeGateWeeklyImages._();

  static const _feat = 'assets/images/weekly/features';
  static const _svc = 'assets/images/weekly/services';

  // ─── أبرز المزايا (كاروسيل علوي) ───────────────────────
  static String feature(String id) => WeeklyImageRotator.pick(_featureVariants[id] ?? const []);

  static const Map<String, List<String>> _featureVariants = {
    'feat_path': ['$_feat/feat_path_w1.png', '$_feat/feat_path_w2.png'],
    'feat_match': ['$_feat/feat_match_w1.png', '$_feat/feat_match_w2.png'],
    'feat_supervisors': [
      '$_feat/feat_supervisors_w1.png',
      '$_feat/feat_supervisors_w2.png',
    ],
    'feat_labs': ['$_feat/feat_labs_w1.png', '$_feat/feat_labs_w2.png'],
    'feat_humanities': [
      '$_feat/feat_writing_w1.png',
      '$_feat/feat_thesis_w1.png',
    ],
    'feat_ai': ['$_feat/feat_ai_w1.png', '$_feat/feat_ai_w2.png'],
    'feat_escrow': ['$_feat/feat_escrow_w1.png', '$_feat/feat_escrow_w2.png'],
    'feat_writing': ['$_feat/feat_writing_w1.png', '$_feat/feat_writing_w2.png'],
    'feat_thesis': ['$_feat/feat_thesis_w1.png', '$_feat/feat_thesis_w2.png'],
    'feat_ideas': ['$_feat/feat_ideas_w1.png', '$_feat/feat_ideas_w2.png'],
    'feat_community': [
      '$_feat/feat_community_w1.png',
      '$_feat/feat_community_w2.png',
    ],
    'feat_integrity': [
      '$_feat/feat_integrity_w1.png',
      '$_feat/feat_integrity_w2.png',
    ],
  };

  // ─── بطاقات الأقسام ────────────────────────────────────
  static String service(String id) =>
      WeeklyImageRotator.pick(_serviceVariants[id] ?? const []);

  static const Map<String, List<String>> _serviceVariants = {
    'supervisors': [
      '$_svc/svc_supervisors_w1.png',
      '$_svc/svc_supervisors_w2.png',
    ],
    'matchmaking': [
      '$_svc/svc_matchmaking_w1.png',
      '$_svc/svc_matchmaking_w2.png',
    ],
    'ideas': ['$_svc/svc_ideas_w1.png', '$_svc/svc_ideas_w2.png'],
    'research_path': [
      '$_svc/svc_research_path_w1.png',
      '$_svc/svc_research_path_w2.png',
    ],
    'labs': ['$_svc/svc_labs_w1.png', '$_svc/svc_labs_w2.png'],
    'humanities': [
      '$_svc/svc_writing_w1.png',
      '$_svc/svc_thesis_w1.png',
    ],
    'store': ['$_svc/svc_store_w1.png', '$_svc/svc_store_w2.png'],
    'community': ['$_svc/svc_community_w1.png', '$_svc/svc_community_w2.png'],
    'ai': ['$_svc/svc_ai_w1.png', '$_svc/svc_ai_w2.png'],
    'writing': ['$_svc/svc_writing_w1.png', '$_svc/svc_writing_w2.png'],
    'thesis_studio': [
      '$_svc/svc_thesis_w1.png',
      '$_svc/svc_thesis_w2.png',
    ],
    'integrity': ['$_svc/svc_integrity_w1.png', '$_svc/svc_integrity_w2.png'],
    'publish': ['$_svc/svc_publish_w1.png', '$_svc/svc_publish_w2.png'],
    'fund': ['$_svc/svc_fund_w1.png', '$_svc/svc_fund_w2.png'],
    'news': ['$_svc/svc_news_w1.png', '$_svc/svc_news_w2.png'],
  };
}
