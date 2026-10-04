/// تطبيع ومقارنة تقريبية لعناوين الرسائل/الأفكار (عربي/إنجليزي).
class TopicSimilarity {
  TopicSimilarity._();

  static final _stop = <String>{
    'في',
    'من',
    'على',
    'إلى',
    'عن',
    'مع',
    'بين',
    'الى',
    'ال',
    'و',
    'أو',
    'the',
    'of',
    'and',
    'in',
    'on',
    'for',
    'to',
    'a',
    'an',
    'with',
    'by',
    'study',
    'دراسة',
    'أثر',
    'دور',
    'تحليل',
    'بحث',
    'رسالة',
    'ماجستير',
    'دكتوراه',
  };

  static String normalize(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '');
    s = s.replaceAll('ة', 'ه');
    s = s.replaceAll('ى', 'ي');
    s = s.replaceAll('أ', 'ا');
    s = s.replaceAll('إ', 'ا');
    s = s.replaceAll('آ', 'ا');
    s = s.replaceAll(RegExp(r'[^\w\u0600-\u06ff\s]+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static Set<String> tokens(String raw) {
    final n = normalize(raw);
    if (n.isEmpty) return {};
    return n
        .split(' ')
        .where((t) => t.length >= 2 && !_stop.contains(t))
        .toSet();
  }

  /// 0..1 — Jaccard على الرموز مع مكافأة الاحتواء الجزئي.
  static double score(String a, String b) {
    final ta = tokens(a);
    final tb = tokens(b);
    if (ta.isEmpty || tb.isEmpty) {
      final na = normalize(a);
      final nb = normalize(b);
      if (na.isEmpty || nb.isEmpty) return 0;
      if (na == nb) return 1;
      if (na.contains(nb) || nb.contains(na)) return 0.72;
      return 0;
    }
    final inter = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    if (union == 0) return 0;
    var j = inter / union;
    final na = normalize(a);
    final nb = normalize(b);
    if (na == nb) return 1;
    if (na.contains(nb) || nb.contains(na)) {
      j = j < 0.65 ? 0.65 : j;
    }
    return j.clamp(0.0, 1.0);
  }

  static String riskLabelAr(double score) {
    if (score >= 0.78) return 'تشابه مرتفع';
    if (score >= 0.55) return 'تشابه متوسط';
    if (score >= 0.35) return 'تشابه منخفض';
    return 'بعيد';
  }

  static String riskLabelEn(double score) {
    if (score >= 0.78) return 'High similarity';
    if (score >= 0.55) return 'Medium similarity';
    if (score >= 0.35) return 'Low similarity';
    return 'Distant';
  }
}
