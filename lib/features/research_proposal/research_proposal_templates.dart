/// كتالوج موحّد لفقرات خطة البحث + اختصارات اختيارية حسب الكلية.
/// الفقرات كلها متاحة؛ الكلية تختار منها ما يلزمها — ليست قوالب ملزمة.
library;

class ProposalFacultyTemplate {
  final String id;
  final String facultyId;
  final String titleAr;
  final String titleEn;
  final String universityHintAr;
  final String universityHintEn;
  final String summaryAr;
  final String summaryEn;
  /// اختصار مقترح من الكتالوج العام (ليس قالباً منفصلاً).
  final List<String> requiredSections;
  final List<String> tipsAr;
  final List<String> tipsEn;
  final List<String> sourceNotesAr;
  final List<String> sourceNotesEn;

  const ProposalFacultyTemplate({
    required this.id,
    required this.facultyId,
    required this.titleAr,
    required this.titleEn,
    required this.universityHintAr,
    required this.universityHintEn,
    required this.summaryAr,
    required this.summaryEn,
    required this.requiredSections,
    required this.tipsAr,
    required this.tipsEn,
    required this.sourceNotesAr,
    required this.sourceNotesEn,
  });
}

/// مفاتيح أقسام المسودة — الكتالوج الكامل.
abstract class ProposalSectionKeys {
  static const titleAr = 'titleAr';
  static const titleEn = 'titleEn';
  static const introduction = 'introduction';
  static const motives = 'motives';
  static const problem = 'problem';
  static const questions = 'questions';
  static const hypotheses = 'hypotheses';
  static const objectives = 'objectives';
  static const significance = 'significance';
  static const limits = 'limits';
  static const terms = 'terms';
  static const framework = 'framework';
  static const priorStudies = 'priorStudies';
  static const methodology = 'methodology';
  static const population = 'population';
  static const instruments = 'instruments';
  static const validity = 'validity';
  static const analysis = 'analysis';
  static const chapterPlan = 'chapterPlan';
  static const expectedResults = 'expectedResults';
  static const ethics = 'ethics';
  static const references = 'references';
  static const timeline = 'timeline';

  static String labelAr(String key) => switch (key) {
        titleAr => 'العنوان (عربي)',
        titleEn => 'العنوان (إنجليزي)',
        introduction => 'مقدمة',
        motives => 'دوافع اختيار الموضوع',
        problem => 'مشكلة البحث',
        questions => 'أسئلة البحث',
        hypotheses => 'الفرضيات (إن وُجدت)',
        objectives => 'الأهداف',
        significance => 'الأهمية',
        limits => 'حدود الدراسة',
        terms => 'المصطلحات',
        framework => 'الإطار النظري',
        priorStudies => 'الدراسات السابقة (نقدية)',
        methodology => 'منهج البحث',
        population => 'المجتمع والعينة',
        instruments => 'الأدوات',
        validity => 'الصدق والثبات',
        analysis => 'أساليب التحليل',
        chapterPlan => 'هيكل الفصول',
        expectedResults => 'النتائج المتوقعة',
        ethics => 'الاعتبارات الأخلاقية',
        references => 'أهم المراجع',
        timeline => 'الجدول الزمني',
        _ => key,
      };

  static String labelEn(String key) => switch (key) {
        titleAr => 'Title (Arabic)',
        titleEn => 'Title (English)',
        introduction => 'Introduction',
        motives => 'Motives for the topic',
        problem => 'Research problem',
        questions => 'Research questions',
        hypotheses => 'Hypotheses (if any)',
        objectives => 'Objectives',
        significance => 'Significance',
        limits => 'Limitations / delimitations',
        terms => 'Key terms',
        framework => 'Theoretical framework',
        priorStudies => 'Prior studies (critical)',
        methodology => 'Methodology',
        population => 'Population & sample',
        instruments => 'Instruments',
        validity => 'Validity & reliability',
        analysis => 'Analysis methods',
        chapterPlan => 'Chapter outline',
        expectedResults => 'Expected results',
        ethics => 'Ethics',
        references => 'Key references',
        timeline => 'Timeline',
        _ => key,
      };

  static String hintAr(String key) => switch (key) {
        titleAr =>
          'واضح · موجز · يحدد الميدان والمتغير/الظاهرة — تجنّب العنوان المفتوح.',
        titleEn =>
          'Precise English scholarly title (often required for ASU registration).',
        problem =>
          'صياغة المشكلة كفجوة قابلة للبحث، لا كموضوع عام. اربطها بسؤال محوري.',
        questions =>
          'أسئلة متسقة مع الأهداف والمنهج — سؤال رئيسي ثم فرعية قابلة للإجابة.',
        objectives =>
          'أفعال قابلة للقياس (تعرّف / تقيس / تحلل / تقترح…) متسقة مع الأسئلة.',
        priorStudies =>
          'نقد ومقارنة وفجوة — ممنوع السرد الملخص فقط. أبرز الاتفاق/الاختلاف وموقع دراستك.',
        methodology =>
          'اذكر المنهج صراحة وعلّل مناسبته للمشكلة والأسئلة.',
        instruments =>
          'اربط كل أداة بسؤال/هدف محدد (استبانة، مقابلة، تحليل مضمون، أسانيد…).',
        limits => 'موضوعي · مكاني · زماني — وما لن تدّعيه الدراسة.',
        chapterPlan => 'تقسيم مبدئي لفصول/مباحث دون إغراق في المطالب.',
        _ => 'اكتب بلغة أكاديمية مختصرة مناسبة لعرض القسم.',
      };
}

/// كل فقرات الخطة المتاحة للاختيار.
const List<String> allProposalSectionKeys = [
  ProposalSectionKeys.titleAr,
  ProposalSectionKeys.titleEn,
  ProposalSectionKeys.introduction,
  ProposalSectionKeys.motives,
  ProposalSectionKeys.problem,
  ProposalSectionKeys.questions,
  ProposalSectionKeys.hypotheses,
  ProposalSectionKeys.objectives,
  ProposalSectionKeys.significance,
  ProposalSectionKeys.limits,
  ProposalSectionKeys.terms,
  ProposalSectionKeys.framework,
  ProposalSectionKeys.priorStudies,
  ProposalSectionKeys.methodology,
  ProposalSectionKeys.population,
  ProposalSectionKeys.instruments,
  ProposalSectionKeys.validity,
  ProposalSectionKeys.analysis,
  ProposalSectionKeys.chapterPlan,
  ProposalSectionKeys.expectedResults,
  ProposalSectionKeys.ethics,
  ProposalSectionKeys.references,
  ProposalSectionKeys.timeline,
];

class ProposalSectionGroup {
  final String id;
  final String titleAr;
  final String titleEn;
  final List<String> keys;

  const ProposalSectionGroup({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.keys,
  });
}

const List<ProposalSectionGroup> proposalSectionGroups = [
  ProposalSectionGroup(
    id: 'identity',
    titleAr: 'الهوية والعنوان',
    titleEn: 'Identity & title',
    keys: [
      ProposalSectionKeys.titleAr,
      ProposalSectionKeys.titleEn,
    ],
  ),
  ProposalSectionGroup(
    id: 'framing',
    titleAr: 'تأطير البحث',
    titleEn: 'Research framing',
    keys: [
      ProposalSectionKeys.introduction,
      ProposalSectionKeys.motives,
      ProposalSectionKeys.problem,
      ProposalSectionKeys.questions,
      ProposalSectionKeys.hypotheses,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.significance,
      ProposalSectionKeys.limits,
      ProposalSectionKeys.terms,
    ],
  ),
  ProposalSectionGroup(
    id: 'literature',
    titleAr: 'الأدبيات والإطار',
    titleEn: 'Literature & framework',
    keys: [
      ProposalSectionKeys.framework,
      ProposalSectionKeys.priorStudies,
    ],
  ),
  ProposalSectionGroup(
    id: 'method',
    titleAr: 'المنهج والإجراءات',
    titleEn: 'Method & procedures',
    keys: [
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.population,
      ProposalSectionKeys.instruments,
      ProposalSectionKeys.validity,
      ProposalSectionKeys.analysis,
    ],
  ),
  ProposalSectionGroup(
    id: 'closing',
    titleAr: 'الهيكل والختام',
    titleEn: 'Structure & closing',
    keys: [
      ProposalSectionKeys.chapterPlan,
      ProposalSectionKeys.expectedResults,
      ProposalSectionKeys.ethics,
      ProposalSectionKeys.references,
      ProposalSectionKeys.timeline,
    ],
  ),
];

/// اختصارات اختيارية: تحدّد فقط أي فقرات من الكتالوج تُفعَّل عادةً.
const List<ProposalFacultyTemplate> proposalFacultyTemplates = [
  ProposalFacultyTemplate(
    id: 'catalog_all',
    facultyId: 'General',
    titleAr: 'كل الفقرات',
    titleEn: 'All sections',
    universityHintAr: 'الكتالوج الكامل — اختر ما يلزمك',
    universityHintEn: 'Full catalog — pick what you need',
    summaryAr:
        'يعرض كل فقرات الخطة الشائعة. فعّل ما يطلبه قسمك وأخفِ الباقي.',
    summaryEn:
        'Shows every common proposal section. Enable what your department needs.',
    requiredSections: allProposalSectionKeys,
    tipsAr: [
      'ابدأ بكل الفقرات ثم عطّل ما لا يطلبه نموذج كليتك.',
      'العنوان العربي/الإنجليزي والمشكلة والمنهج أساسية في أغلب الأقسام.',
    ],
    tipsEn: [
      'Start with all sections, then disable what your form does not require.',
      'Arabic/English titles, problem, and method are core in most departments.',
    ],
    sourceNotesAr: [
      'مجموع عناصر شائعة من خطط الدراسات العليا المصرية (تربية/آداب/حقوق/تجارة…).',
    ],
    sourceNotesEn: [
      'Union of common Egyptian postgraduate proposal elements.',
    ],
  ),
  ProposalFacultyTemplate(
    id: 'edu_ain_shams',
    facultyId: 'Education',
    titleAr: 'اختصار تربية',
    titleEn: 'Education shortcut',
    universityHintAr: 'مقترح شائع لكليات التربية',
    universityHintEn: 'Common Education faculty pick',
    summaryAr:
        'مشكلة وأسئلة/فرضيات، إطار ودراسات نقدية، مجتمع وأداة وصدق/ثبات وتحليل وأخلاقيات.',
    summaryEn:
        'Problem, Qs/hypotheses, framework, critical lit, sample, tool, validity, analysis, ethics.',
    requiredSections: [
      ProposalSectionKeys.titleAr,
      ProposalSectionKeys.titleEn,
      ProposalSectionKeys.introduction,
      ProposalSectionKeys.problem,
      ProposalSectionKeys.questions,
      ProposalSectionKeys.hypotheses,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.significance,
      ProposalSectionKeys.terms,
      ProposalSectionKeys.limits,
      ProposalSectionKeys.framework,
      ProposalSectionKeys.priorStudies,
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.population,
      ProposalSectionKeys.instruments,
      ProposalSectionKeys.validity,
      ProposalSectionKeys.analysis,
      ProposalSectionKeys.expectedResults,
      ProposalSectionKeys.ethics,
      ProposalSectionKeys.references,
    ],
    tipsAr: [
      'الدراسات السابقة تُقيَّم بالتحليل والمقارنة لا بالسرد الوصفي فقط.',
      'اتساق صارم: أسئلة ↔ أهداف ↔ منهج ↔ أداة ↔ تحليل.',
    ],
    tipsEn: [
      'Prior studies must be critical/comparative, not a narrative list.',
      'Strict alignment: questions ↔ objectives ↔ method ↔ instrument ↔ analysis.',
    ],
    sourceNotesAr: [
      'ممارسات كليات التربية المصرية وأدلة إعداد الخطط التربوية.',
    ],
    sourceNotesEn: [
      'Common Egyptian Education faculty proposal practice.',
    ],
  ),
  ProposalFacultyTemplate(
    id: 'arts_asu_damanhour',
    facultyId: 'Arts',
    titleAr: 'اختصار آداب',
    titleEn: 'Arts shortcut',
    universityHintAr: 'مقترح شائع لكليات الآداب',
    universityHintEn: 'Common Arts faculty pick',
    summaryAr:
        'مقدمة تضييق، إشكالية، أهمية، أهداف، حدود، دراسات، منهج، هيكل فصول، مصادر.',
    summaryEn:
        'Funnelled intro, problem, significance, objectives, limits, lit, method, chapters, sources.',
    requiredSections: [
      ProposalSectionKeys.titleAr,
      ProposalSectionKeys.titleEn,
      ProposalSectionKeys.introduction,
      ProposalSectionKeys.problem,
      ProposalSectionKeys.questions,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.significance,
      ProposalSectionKeys.limits,
      ProposalSectionKeys.priorStudies,
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.chapterPlan,
      ProposalSectionKeys.references,
    ],
    tipsAr: [
      'المقدمة تنتقل من العام إلى الأشد تحديداً حتى تُحس بالمشكلة.',
      'الحدود الزمنية/الجغرافية تُبرَّر عند وجودها.',
    ],
    tipsEn: [
      'Introduction moves from general to specific until the problem is felt.',
      'Justify temporal/geographic delimitations when used.',
    ],
    sourceNotesAr: [
      'عناصر شائعة في خطط آداب الماجستير/الدكتوراه.',
    ],
    sourceNotesEn: [
      'Common Arts MA/PhD proposal elements.',
    ],
  ),
  ProposalFacultyTemplate(
    id: 'law_doctrinal',
    facultyId: 'Law',
    titleAr: 'اختصار حقوق',
    titleEn: 'Law shortcut',
    universityHintAr: 'مقترح شائع لكليات الحقوق',
    universityHintEn: 'Common Law faculty pick',
    summaryAr:
        'دوافع، أهداف، أهمية، مشكلة، أسئلة، حدود، دراسات مع بيان الاختلاف، منهج، هيكل، مصادر.',
    summaryEn:
        'Motives, objectives, significance, problem, questions, limits, differentiated lit, method, outline, sources.',
    requiredSections: [
      ProposalSectionKeys.titleAr,
      ProposalSectionKeys.titleEn,
      ProposalSectionKeys.motives,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.significance,
      ProposalSectionKeys.problem,
      ProposalSectionKeys.questions,
      ProposalSectionKeys.limits,
      ProposalSectionKeys.priorStudies,
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.chapterPlan,
      ProposalSectionKeys.references,
    ],
    tipsAr: [
      'العنوان لا يكون مفتوحاً يشمل عدة موضوعات.',
      'المنهج يوضح أدوات جمع/معالجة المعطيات القانونية.',
    ],
    tipsEn: [
      'Avoid open-ended titles covering multiple topics.',
      'Method must name legal tools (statute, case law, doctrine, comparison).',
    ],
    sourceNotesAr: [
      'عناصر شائعة في أدلة صياغة المقترحات القانونية.',
    ],
    sourceNotesEn: [
      'Common elements in legal research-proposal guides.',
    ],
  ),
  ProposalFacultyTemplate(
    id: 'business_asu',
    facultyId: 'Business',
    titleAr: 'اختصار تجارة',
    titleEn: 'Commerce shortcut',
    universityHintAr: 'مقترح شائع لكليات التجارة',
    universityHintEn: 'Common Commerce faculty pick',
    summaryAr:
        'أسئلة/فرضيات، حدود، مصطلحات، أدبيات، مجتمع وأدوات وتحليل إحصائي، جدول زمني.',
    summaryEn:
        'Qs/hypotheses, limits, terms, lit, sample/tools/stats, timeline.',
    requiredSections: [
      ProposalSectionKeys.titleAr,
      ProposalSectionKeys.titleEn,
      ProposalSectionKeys.introduction,
      ProposalSectionKeys.problem,
      ProposalSectionKeys.questions,
      ProposalSectionKeys.hypotheses,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.significance,
      ProposalSectionKeys.limits,
      ProposalSectionKeys.terms,
      ProposalSectionKeys.priorStudies,
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.population,
      ProposalSectionKeys.instruments,
      ProposalSectionKeys.analysis,
      ProposalSectionKeys.timeline,
      ProposalSectionKeys.references,
    ],
    tipsAr: [
      'حدد المنهج وخطوات جمع البيانات بوضوح.',
      'اربط التحليل الإحصائي بأسئلة/فرضيات محددة.',
    ],
    tipsEn: [
      'State method and data-collection steps clearly.',
      'Link proposed statistical analysis to specific questions/hypotheses.',
    ],
    sourceNotesAr: [
      'أدلة كتابة خطة بحث الاقتصاد/التجارة الشائعة.',
    ],
    sourceNotesEn: [
      'Common Commerce/Economics proposal writing guides.',
    ],
  ),
  ProposalFacultyTemplate(
    id: 'media_edu_hybrid',
    facultyId: 'MassCommunication',
    titleAr: 'اختصار إعلام',
    titleEn: 'Media shortcut',
    universityHintAr: 'مقترح شائع لكليات الإعلام',
    universityHintEn: 'Common Media faculty pick',
    summaryAr:
        'مشكلة إعلامية، منهج مسح/تحليل مضمون، أداة، صدق، مجتمع، تحليل.',
    summaryEn:
        'Media problem, survey/content analysis, instrument, validity, sample, analysis.',
    requiredSections: [
      ProposalSectionKeys.titleAr,
      ProposalSectionKeys.titleEn,
      ProposalSectionKeys.problem,
      ProposalSectionKeys.questions,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.significance,
      ProposalSectionKeys.limits,
      ProposalSectionKeys.priorStudies,
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.population,
      ProposalSectionKeys.instruments,
      ProposalSectionKeys.validity,
      ProposalSectionKeys.analysis,
      ProposalSectionKeys.references,
    ],
    tipsAr: [
      'إن استخدمت تحليل المضمون: عرّف وحدة التحليل وفئات الترميز مسبقاً.',
    ],
    tipsEn: [
      'For content analysis: define unit of analysis and coding categories upfront.',
    ],
    sourceNotesAr: [
      'عناصر ميدانية شائعة في خطط الإعلام.',
    ],
    sourceNotesEn: [
      'Common practical Media proposal elements.',
    ],
  ),
  ProposalFacultyTemplate(
    id: 'tourism_applied',
    facultyId: 'Tourism',
    titleAr: 'اختصار سياحة',
    titleEn: 'Tourism shortcut',
    universityHintAr: 'مقترح شائع لكليات السياحة والفنادق',
    universityHintEn: 'Common Tourism & hotels pick',
    summaryAr:
        'مشكلة تطبيقية، أهمية لصنّاع القرار، منهج ميداني، عينة، نتائج متوقعة.',
    summaryEn:
        'Applied problem, decision-maker significance, field method, sample, expected results.',
    requiredSections: [
      ProposalSectionKeys.titleAr,
      ProposalSectionKeys.titleEn,
      ProposalSectionKeys.problem,
      ProposalSectionKeys.questions,
      ProposalSectionKeys.objectives,
      ProposalSectionKeys.significance,
      ProposalSectionKeys.limits,
      ProposalSectionKeys.priorStudies,
      ProposalSectionKeys.methodology,
      ProposalSectionKeys.population,
      ProposalSectionKeys.instruments,
      ProposalSectionKeys.analysis,
      ProposalSectionKeys.expectedResults,
      ProposalSectionKeys.references,
    ],
    tipsAr: [
      'وضّح الإسهام التطبيقي للقطاع السياحي المصري إن أمكن.',
    ],
    tipsEn: [
      'Clarify applied contribution to the Egyptian tourism sector when relevant.',
    ],
    sourceNotesAr: [
      'عناصر تطبيقية شائعة في خطط السياحة والفنادق.',
    ],
    sourceNotesEn: [
      'Common applied Tourism & hotels proposal elements.',
    ],
  ),
];

ProposalFacultyTemplate? proposalTemplateById(String id) {
  for (final t in proposalFacultyTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

ProposalFacultyTemplate? proposalTemplateForFaculty(String facultyId) {
  for (final t in proposalFacultyTemplates) {
    if (t.facultyId == facultyId) return t;
  }
  return proposalFacultyTemplates.first; // catalog_all
}

/// الفقرات النشطة للمسودة: اختيار المستخدم، وإلا اختصار الكلية، وإلا الكل.
List<String> resolveActiveSections({
  required List<String> selectedSections,
  required String templateId,
  required String facultyId,
}) {
  if (selectedSections.isNotEmpty) {
    final known = allProposalSectionKeys.toSet();
    final ordered = <String>[];
    for (final k in allProposalSectionKeys) {
      if (selectedSections.contains(k)) ordered.add(k);
    }
    // keep any unknown custom keys at the end
    for (final k in selectedSections) {
      if (!known.contains(k) && !ordered.contains(k)) ordered.add(k);
    }
    return ordered.isNotEmpty ? ordered : List.of(allProposalSectionKeys);
  }
  final tpl = proposalTemplateById(templateId) ??
      proposalTemplateForFaculty(facultyId) ??
      proposalFacultyTemplates.first;
  return List.of(tpl.requiredSections);
}
