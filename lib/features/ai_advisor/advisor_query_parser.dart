/// يفهم سؤال الطالب بصيغته الطبيعية — بدون اشتراط قوالب جاهزة.
class ParsedAcademicQuery {
  final AcademicQueryGoal goal;
  final String subject;
  final String rawMessage;

  const ParsedAcademicQuery({
    required this.goal,
    required this.subject,
    required this.rawMessage,
  });

  bool get hasClearSubject => subject.trim().length >= 3;
}

enum AcademicQueryGoal {
  researchIdea,
  thesisTitles,
  researchQuestion,
  summarize,
  supervisor,
  thesisWriting,
  literatureReview,
  citations,
  editing,
  dataAnalysis,
  presentation,
  simulation,
  general,
}

class AcademicQueryParser {
  AcademicQueryParser._();

  static ParsedAcademicQuery parse(String message) {
    final raw = message.trim();
    final lower = raw.toLowerCase();
    final subject = _extractSubject(raw);
    final goal = _detectGoal(lower, subject);

    return ParsedAcademicQuery(
      goal: goal,
      subject: subject,
      rawMessage: raw,
    );
  }

  static AcademicQueryGoal _detectGoal(String lower, String subject) {
    if (_any(lower, [
      'مشرف',
      'الأنسب',
      'الانسب',
      'يشرف علي',
      'أشرفني',
    ])) {
      return AcademicQueryGoal.supervisor;
    }

    if (_any(lower, [
      'فكرة بحث',
      'فكرة بحثية',
      'افكار بحث',
      'أفكار بحث',
      'اقترح فكرة',
      'اعطني فكرة',
      'عايز فكرة',
      'فكرة مناسبة',
      'هل الفكرة',
      'رأيك في فكرة',
      'رايك في فكرة',
      'تقييم فكرة',
      'طور فكرة',
      'تطوير فكرة',
      'موضوع بحث',
      'موضوع رسالة',
    ]) ||
        (_any(lower, ['فكرة', 'موضوع']) &&
            _any(lower, ['بحث', 'رسالة', 'ماجستير', 'دكتوراه']))) {
      return AcademicQueryGoal.researchIdea;
    }

    if (_any(lower, ['سؤال بحثي', 'صيغ سؤال', 'صياغة سؤال']) ||
        (_any(lower, ['حوّل', 'حول']) && _any(lower, ['فكرة', 'سؤال']))) {
      return AcademicQueryGoal.researchQuestion;
    }

    if (_any(lower, ['عناوين', 'عنوان رسالة', 'مواضيع رسالة']) ||
        (_any(lower, ['اقترح', 'اعطني', 'عايز']) &&
            _any(lower, ['عناوين', 'عنوان', 'موضوع']))) {
      return AcademicQueryGoal.thesisTitles;
    }

    if (_any(lower, ['لخّص', 'لخص', 'ملخص', 'تلخيص', 'abstract'])) {
      return AcademicQueryGoal.summarize;
    }

    if (_any(lower, [
      'اكتب مقدمة',
      'اكتب فصل',
      'اكتب خاتمة',
      'صياغة فصل',
      'نص رسالة',
    ])) {
      return AcademicQueryGoal.thesisWriting;
    }

    if (_any(lower, [
      'مراجعة أدبية',
      'مراجعة ادبية',
      'إطار نظري',
      'اطار نظري',
      'تحليل ورقة',
      'فجوة بحثية',
      'دراسات سابقة',
    ])) {
      return AcademicQueryGoal.literatureReview;
    }

    if (_any(lower, ['مرجع', 'مراجع', 'توثيق', 'apa', 'ieee', 'chicago'])) {
      return AcademicQueryGoal.citations;
    }

    if (_any(lower, ['تحرير', 'تدقيق', 'تصحيح لغوي', 'إعادة صياغة'])) {
      return AcademicQueryGoal.editing;
    }

    if (_any(lower, [
      'spss',
      'python',
      'تحليل بيانات',
      'إحصاء',
      'احصاء',
      'انحدار',
      'كود',
    ])) {
      return AcademicQueryGoal.dataAnalysis;
    }

    if (_any(lower, [
      'عرض تقديمي',
      'باوربوينت',
      'powerpoint',
      'شرائح',
      'دفاع الرسالة',
    ]) &&
        !_any(lower, ['مناقشة علمية', 'ندوة'])) {
      return AcademicQueryGoal.presentation;
    }

    if (_any(lower, ['محاكاة', 'نتائج افتراضية', 'سيناريو نتائج'])) {
      return AcademicQueryGoal.simulation;
    }

    if (_any(lower, ['بحث', 'رسالة', 'ماجستير', 'دكتوراه', 'أكاديمي', 'اكاديمي']) &&
        subject.length >= 3) {
      return AcademicQueryGoal.researchIdea;
    }

    return AcademicQueryGoal.general;
  }

  static String _extractSubject(String message) {
    final capturePatterns = [
      RegExp(
        r'(?:فكرة(?:\s+بحث(?:ية)?)?|موضوع(?:\s+(?:بحث|رسالة))?)\s*(?:عن|في|حول)\s+(.+)',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'(?:رأيك|رايك|رأي)\s+(?:في|عن)\s+(?:فكرة(?:\s+بحث(?:ية)?)?\s*)?(?:عن|في|حول)?\s*(.+)',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'(?:اقترح|اعطني|عايز|محتاج|أريد|اريد)\s+(?:لي\s+)?(?:فكرة|موضوع|عناوين?)\s*(?:بحث(?:ية)?|رسالة)?\s*(?:عن|في|حول)?\s*(.+)',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(r'(?:عن|في|حول)\s+(.+)', caseSensitive: false, dotAll: true),
      RegExp(r'(?:بحث|رسالة)\s+(?:عن|في)\s+(.+)', caseSensitive: false),
    ];

    for (final pattern in capturePatterns) {
      final match = pattern.firstMatch(message);
      if (match == null) continue;
      final cleaned = _cleanSubject(match.group(1) ?? '');
      if (cleaned.length >= 3) return cleaned;
    }

    return _cleanSubject(message);
  }

  static String _cleanSubject(String value) {
    var text = value.trim();

    final patterns = [
      RegExp(r'[؟?!.…]+$'),
      RegExp(
        r'\s*(?:هل|هل هي|هل هو|مناسبة|جيدة|كويسة|تمام|ممكن|ولا إيه|ولا ايه).*$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:السلام عليكم|مرحبا|أريد|اريد|عايز|محتاج|ممكن|لو سمحت|ساعدني|يا مساعد|مساعد)\s*',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:عندي|لدي|عندى)\s*(?:فكرة(?:\s+بحث(?:ية)?)?)?\s*',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:ما رأيك|ما رايك|رأيك|رايك)\s+(?:في|عن)\s*',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:فكرة(?:\s+بحث(?:ية)?)?|موضوع(?:\s+بحث)?)\s*(?:عن|في|حول)?\s*',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      text = text.replaceAll(pattern, '').trim();
    }

    if (text.length > 180) {
      text = text.substring(0, 180).trim();
    }

    return text;
  }

  static bool _any(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }
}
