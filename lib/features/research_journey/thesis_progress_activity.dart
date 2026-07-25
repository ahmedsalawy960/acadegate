import '../../core/locale/app_translate.dart';

/// نشاطات التطبيق المرتبطة بتقدم الرسالة.
enum ThesisActivityId {
  profileComplete,
  topicIdea,
  supervisorMatch,
  methodologyEthics,
  citationCheck,
  originalityCheck,
  dataCollection,
  chapterWriting,
  publishManuscript,
  vivaPractice,
  defenseDeadline,
}

extension ThesisActivityIdX on ThesisActivityId {
  String get key => name;

  static ThesisActivityId? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final id in ThesisActivityId.values) {
      if (id.name == raw || id.key == raw) return id;
    }
    return null;
  }
}

class ThesisActivityAdvice {
  final String titleAr;
  final String titleEn;
  final String tipAr;
  final String tipEn;

  const ThesisActivityAdvice({
    required this.titleAr,
    required this.titleEn,
    required this.tipAr,
    required this.tipEn,
  });

  String title(bool isEnglish) => isEnglish ? titleEn : titleAr;
  String tip(bool isEnglish) => isEnglish ? tipEn : tipAr;
}

class ThesisActivityCatalog {
  ThesisActivityCatalog._();

  static ThesisActivityAdvice adviceFor(String? activityId, String fallbackTitle) {
    final id = ThesisActivityIdX.parse(activityId);
    if (id != null && _catalog.containsKey(id)) {
      return _catalog[id]!;
    }
    return ThesisActivityAdvice(
      titleAr: fallbackTitle,
      titleEn: fallbackTitle,
      tipAr: appTr(
        'أكمل هذا البند ثم ارجع لتحديث تقدمك.',
        'Complete this item then refresh your progress.',
      ),
      tipEn: appTr(
        'أكمل هذا البند ثم ارجع لتحديث تقدمك.',
        'Complete this item then refresh your progress.',
      ),
    );
  }

  static const _catalog = {
    ThesisActivityId.profileComplete: ThesisActivityAdvice(
      titleAr: 'الملف الأكاديمي',
      titleEn: 'Academic profile',
      tipAr: 'أكمل تخصصك واهتمامك البحثي — يُفعّل المطابقة الذكية والمسار.',
      tipEn: 'Complete your field and research interest — unlocks smart matching.',
    ),
    ThesisActivityId.topicIdea: ThesisActivityAdvice(
      titleAr: 'موضوع/فكرة البحث',
      titleEn: 'Research topic/idea',
      tipAr: 'استخدم مسار البحث الذكي أو سوق الأفكار لاختيار موضوع واضح.',
      tipEn: 'Use the smart research path or ideas marketplace to pick a topic.',
    ),
    ThesisActivityId.supervisorMatch: ThesisActivityAdvice(
      titleAr: 'اختيار المشرف',
      titleEn: 'Choose a supervisor',
      tipAr: 'جرّب المطابقة الذكية — ملفك + نسبة توافق % مع المشرفين.',
      tipEn: 'Try smart matching — your profile + supervisor match %.',
    ),
    ThesisActivityId.methodologyEthics: ThesisActivityAdvice(
      titleAr: 'المنهجية والموافقات',
      titleEn: 'Methodology & ethics',
      tipAr: 'استخدم كاشف المنهجية في AcadeGate Integrity قبل تقديم المقترح.',
      tipEn: 'Use the methodology checker in AcadeGate Integrity before submitting.',
    ),
    ThesisActivityId.citationCheck: ThesisActivityAdvice(
      titleAr: 'فحص المراجع',
      titleEn: 'Reference check',
      tipAr: 'تحقق من DOI والعناوين في فاحص المراجع قبل تسليم أي فصل.',
      tipEn: 'Verify DOIs and titles in the reference checker before submitting chapters.',
    ),
    ThesisActivityId.originalityCheck: ThesisActivityAdvice(
      titleAr: 'فحص التشابه',
      titleEn: 'Similarity check',
      tipAr: 'شغّل فحص التشابه على مسودة الفصل قبل الإرسال للمشرف.',
      tipEn: 'Run a similarity check on chapter drafts before sending to your supervisor.',
    ),
    ThesisActivityId.dataCollection: ThesisActivityAdvice(
      titleAr: 'جمع البيانات',
      titleEn: 'Data collection',
      tipAr: 'احجز مختبراً أو أرسل عينات للتحليل من قسم المختبرات.',
      tipEn: 'Book a lab or send samples for analysis from the labs section.',
    ),
    ThesisActivityId.chapterWriting: ThesisActivityAdvice(
      titleAr: 'كتابة الفصول',
      titleEn: 'Writing chapters',
      tipAr: 'استخدم AcadeGate Publish أو خدمات الكتابة + المساعد الذكي.',
      tipEn: 'Use AcadeGate Publish, writing services, or the AI advisor.',
    ),
    ThesisActivityId.publishManuscript: ThesisActivityAdvice(
      titleAr: 'مسودة للنشر',
      titleEn: 'Publication draft',
      tipAr: 'جهّز مسودة IEEE/APA في AcadeGate Publish واختر مجلة مناسبة.',
      tipEn: 'Prepare an IEEE/APA draft in Publish and pick a suitable journal.',
    ),
    ThesisActivityId.vivaPractice: ThesisActivityAdvice(
      titleAr: 'تدريب المناقشة',
      titleEn: 'Viva practice',
      tipAr: 'جرّب محاكي المناقشة — 3–5 أسئلة قبل اللجنة الحقيقية.',
      tipEn: 'Try the viva simulator — 3–5 questions before the real defense.',
    ),
    ThesisActivityId.defenseDeadline: ThesisActivityAdvice(
      titleAr: 'موعد المناقشة',
      titleEn: 'Defense date',
      tipAr: 'حدّد تاريخ المناقشة في التقويم وشاركه مع مشرفك.',
      tipEn: 'Set your defense date and share it with your supervisor.',
    ),
  };
}

class ThesisNextStep {
  final String itemTitle;
  final String? activityId;
  final ThesisActivityAdvice advice;
  final bool allComplete;

  const ThesisNextStep({
    required this.itemTitle,
    this.activityId,
    required this.advice,
    this.allComplete = false,
  });

  factory ThesisNextStep.allDone() {
    return ThesisNextStep(
      itemTitle: appTr('اكتملت جميع البنود', 'All items complete'),
      advice: ThesisActivityAdvice(
        titleAr: 'مبروك!',
        titleEn: 'Congratulations!',
        tipAr: 'راجع موعد المناقشة واستمر في التحديث مع مشرفك.',
        tipEn: 'Review your defense date and keep coordinating with your supervisor.',
      ),
      allComplete: true,
    );
  }
}
