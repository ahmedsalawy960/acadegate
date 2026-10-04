/// ورشة أخطاء الخطط الشائعة + فحص اتساق منهج–أداة–أسئلة.
library;

import 'research_proposal_models.dart';
import 'research_proposal_templates.dart';

class ProposalWorkshopItem {
  final String id;
  final String clusterAr;
  final String clusterEn;
  final String titleAr;
  final String titleEn;
  final String faultAr;
  final String faultEn;
  final String fixAr;
  final String fixEn;

  const ProposalWorkshopItem({
    required this.id,
    required this.clusterAr,
    required this.clusterEn,
    required this.titleAr,
    required this.titleEn,
    required this.faultAr,
    required this.faultEn,
    required this.fixAr,
    required this.fixEn,
  });
}

const List<ProposalWorkshopItem> proposalWorkshopItems = [
  ProposalWorkshopItem(
    id: 'title_field',
    clusterAr: 'العنوان',
    clusterEn: 'Title',
    titleAr: 'تحديد ميدان المشكلة',
    titleEn: 'Name the problem field',
    faultAr:
        'عنوان عام لا يحدّد الميدان أو المتغير/الظاهرة (خطأ شائع في خطط التربية).',
    faultEn:
        'Vague title that does not specify the field or variable (common Education fault).',
    fixAr: 'أدرج التخصص + الظاهرة + السياق المصري إن لزم، واجعل العنوان موجزاً دقيقاً.',
    fixEn: 'Include discipline + phenomenon + Egypt context if needed; keep it concise.',
  ),
  ProposalWorkshopItem(
    id: 'title_open',
    clusterAr: 'العنوان',
    clusterEn: 'Title',
    titleAr: 'تجنّب العنوان المفتوح',
    titleEn: 'Avoid open-ended titles',
    faultAr: 'عنوان يغطي عدة موضوعات في آن واحد (تحذير أدلة الحقوق).',
    faultEn: 'Title covering several topics at once (Law proposal guides warn against this).',
    fixAr: 'ضيّق النطاق لموضوع واحد قابل للبحث في رسالة واحدة.',
    fixEn: 'Narrow to one researchable topic for a single thesis.',
  ),
  ProposalWorkshopItem(
    id: 'problem_craft',
    clusterAr: 'المشكلة',
    clusterEn: 'Problem',
    titleAr: 'صياغة مشكلة قابلة للبحث',
    titleEn: 'Craft a researchable problem',
    faultAr: 'مشكلة ركيكة أو موضوع عام بلا فجوة واضحة.',
    faultEn: 'Weak problem statement or a general topic without a clear gap.',
    fixAr: 'صغ فجوة معرفية/تطبيقية وسؤالاً محورياً تعود إليه بقية الخطة.',
    fixEn: 'State a knowledge/practice gap and one core question that anchors the plan.',
  ),
  ProposalWorkshopItem(
    id: 'objectives_align',
    clusterAr: 'الأهداف',
    clusterEn: 'Objectives',
    titleAr: 'أهداف متسقة وقابلة للقياس',
    titleEn: 'Aligned, measurable objectives',
    faultAr: 'أهداف فضفاضة أو غير مرتبطة بالأسئلة.',
    faultEn: 'Loose objectives disconnected from the questions.',
    fixAr: 'لكل هدف سؤال مقابل وفعل قابل للقياس (تعرّف/تقيس/تحلل/تقترح).',
    fixEn: 'Map each objective to a question with a measurable verb.',
  ),
  ProposalWorkshopItem(
    id: 'limits_clear',
    clusterAr: 'الحدود',
    clusterEn: 'Limits',
    titleAr: 'حدود موضوعية/مكانية/زمانية',
    titleEn: 'Subject / place / time limits',
    faultAr: 'حدود غائبة أو غير مبررة — خاصة في الآداب والتجارة.',
    faultEn: 'Missing or unjustified limits — especially in Arts and Commerce.',
    fixAr: 'اذكر ما يدخل وما لا يدخل، وبرّر الحدود المكانية/الزمنية إن وُجدت.',
    fixEn: 'State what is in/out of scope; justify geo/temporal limits when used.',
  ),
  ProposalWorkshopItem(
    id: 'prior_critical',
    clusterAr: 'دراسات سابقة',
    clusterEn: 'Prior studies',
    titleAr: 'نقد لا سرد',
    titleEn: 'Critique, not narration',
    faultAr:
        'سرد ملخصات بلا مقارنة أو فجوة — معيار قبول ضعيف في التربية والآداب.',
    faultEn:
        'Narrative summaries with no comparison/gap — weak acceptance criterion.',
    fixAr:
        'صنّف الدراسات، قارن المنهج/العينة/النتائج، وحدد موقع دراستك والاختلاف عنها.',
    fixEn:
        'Cluster studies, compare method/sample/findings, and locate your gap.',
  ),
  ProposalWorkshopItem(
    id: 'method_fit',
    clusterAr: 'اتساق منهج–أداة–أسئلة',
    clusterEn: 'Method–instrument–questions',
    titleAr: 'ملاءمة المنهج للمشكلة',
    titleEn: 'Method fits the problem',
    faultAr: 'منهج مذكور بلا تعليل، أو لا يجيب عن الأسئلة.',
    faultEn: 'Method named without rationale, or unable to answer the questions.',
    fixAr: 'اشرح لماذا هذا المنهج (كمّي/نوعي/مختلط/وثائقي/مقارن) يناسب أسئلتك.',
    fixEn: 'Explain why this method answers your questions.',
  ),
  ProposalWorkshopItem(
    id: 'instrument_map',
    clusterAr: 'اتساق منهج–أداة–أسئلة',
    clusterEn: 'Method–instrument–questions',
    titleAr: 'ربط الأداة بالأسئلة',
    titleEn: 'Map instrument to questions',
    faultAr: 'أداة عامة بلا ربط بسؤال/هدف (خطأ إجراءات شائع).',
    faultEn: 'Generic instrument with no link to a question/objective.',
    fixAr: 'جدول بسيط: سؤال → مؤشر/بُعد → بند أداة أو مصدر بيانات.',
    fixEn: 'Simple matrix: question → indicator → item or data source.',
  ),
  ProposalWorkshopItem(
    id: 'validity_note',
    clusterAr: 'اتساق منهج–أداة–أسئلة',
    clusterEn: 'Method–instrument–questions',
    titleAr: 'صدق وثبات / موثوقية',
    titleEn: 'Validity & reliability',
    faultAr: 'إغفال الصدق/الثبات في خطط التربية والتجارة الميدانية.',
    faultEn: 'Missing validity/reliability in Education/Commerce field plans.',
    fixAr: 'اذكر أسلوب التحقق (محكّمين، ثبات ألفا، تجريب أولّي، تثليث…).',
    fixEn: 'State how you will verify (experts, alpha, pilot, triangulation…).',
  ),
  ProposalWorkshopItem(
    id: 'analysis_fit',
    clusterAr: 'اتساق منهج–أداة–أسئلة',
    clusterEn: 'Method–instrument–questions',
    titleAr: 'تحليل يجيب عن الأسئلة',
    titleEn: 'Analysis that answers questions',
    faultAr: 'أساليب تحليل لا تطابق نوع البيانات أو الفرضيات.',
    faultEn: 'Analysis methods that do not match data type or hypotheses.',
    fixAr: 'اربط كل سؤال بأسلوب تحليل مناسب (إحصاء، ترميز موضوعي، استدلال قانوني…).',
    fixEn: 'Map each question to a fitting analysis (stats, thematic coding, legal reasoning…).',
  ),
  ProposalWorkshopItem(
    id: 'human_review',
    clusterAr: 'قبل القسم',
    clusterEn: 'Before the department',
    titleAr: 'مراجعة بشرية متخصصة',
    titleEn: 'Specialist human review',
    faultAr: 'عرض الخطة على القسم دون مراجعة خبير تربية/قانون/تخصص.',
    faultEn: 'Presenting to the department without a specialist review.',
    fixAr: 'اطلب مراجعة من خبير مقترح (تربية/قانون…) وصحّح قبل السمينار/مجلس القسم.',
    fixEn: 'Request a proposal expert review (Education/Law…) and revise before seminar.',
  ),
];

class ProposalConsistencyEngine {
  ProposalConsistencyEngine._();
  static final ProposalConsistencyEngine instance =
      ProposalConsistencyEngine._();

  ProposalConsistencyReport evaluate(ProposalDraft draft) {
    final issues = <ProposalConsistencyIssue>[];
    final title = draft.section(ProposalSectionKeys.titleAr);
    final problem = draft.section(ProposalSectionKeys.problem);
    final questions = draft.section(ProposalSectionKeys.questions);
    final objectives = draft.section(ProposalSectionKeys.objectives);
    final limits = draft.section(ProposalSectionKeys.limits);
    final prior = draft.section(ProposalSectionKeys.priorStudies);
    final method = draft.section(ProposalSectionKeys.methodology);
    final instruments = draft.section(ProposalSectionKeys.instruments);
    final analysis = draft.section(ProposalSectionKeys.analysis);
    final validity = draft.section(ProposalSectionKeys.validity);

    if (title.length < 18) {
      issues.add(const ProposalConsistencyIssue(
        id: 'title_short',
        titleAr: 'العنوان قصير أو ناقص',
        titleEn: 'Title too short',
        detailAr: 'اكتب عنواناً يحدد الميدان والظاهرة بوضوح.',
        detailEn: 'Write a title that clearly names field and phenomenon.',
        severity: 'high',
      ));
    } else if (_isTooOpen(title)) {
      issues.add(const ProposalConsistencyIssue(
        id: 'title_open',
        titleAr: 'العنوان قد يكون مفتوحاً',
        titleEn: 'Title may be too open',
        detailAr: 'تجنّب صيغاً عامة جداً مثل «دراسة عن…» بلا تخصيص.',
        detailEn: 'Avoid overly generic phrasing without focus.',
        severity: 'medium',
      ));
    }

    if (problem.length < 40) {
      issues.add(const ProposalConsistencyIssue(
        id: 'problem_missing',
        titleAr: 'المشكلة غير مكتملة',
        titleEn: 'Problem incomplete',
        detailAr: 'صغ فجوة واضحة وسؤالاً محورياً.',
        detailEn: 'State a clear gap and core question.',
        severity: 'high',
      ));
    }

    if (questions.length < 20) {
      issues.add(const ProposalConsistencyIssue(
        id: 'questions_missing',
        titleAr: 'أسئلة البحث ناقصة',
        titleEn: 'Questions missing',
        detailAr: 'أضف سؤالاً رئيسياً وأسئلة فرعية.',
        detailEn: 'Add a main question and sub-questions.',
        severity: 'high',
      ));
    }

    if (objectives.length < 20) {
      issues.add(const ProposalConsistencyIssue(
        id: 'objectives_missing',
        titleAr: 'الأهداف ناقصة',
        titleEn: 'Objectives missing',
        detailAr: 'اكتب أهدافاً قابلة للقياس ومتسقة مع الأسئلة.',
        detailEn: 'Write measurable objectives aligned with questions.',
        severity: 'high',
      ));
    } else if (questions.length >= 20 &&
        !_sharesTokens(objectives, questions)) {
      issues.add(const ProposalConsistencyIssue(
        id: 'obj_q_mismatch',
        titleAr: 'ضعف اتساق الأهداف مع الأسئلة',
        titleEn: 'Weak objectives–questions alignment',
        detailAr: 'فضّل أن تتشارك الأهداف والأسئلة نفس المفاهيم الأساسية.',
        detailEn: 'Prefer shared core concepts between objectives and questions.',
        severity: 'medium',
      ));
    }

    if (limits.length < 20) {
      issues.add(const ProposalConsistencyIssue(
        id: 'limits_missing',
        titleAr: 'الحدود غير موضحة',
        titleEn: 'Limits unclear',
        detailAr: 'حدّد موضوعياً / مكانياً / زمانياً وما لن تدّعيه.',
        detailEn: 'State subject/place/time limits and non-claims.',
        severity: 'medium',
      ));
    }

    if (prior.length < 40) {
      issues.add(const ProposalConsistencyIssue(
        id: 'prior_thin',
        titleAr: 'الدراسات السابقة ضعيفة',
        titleEn: 'Prior studies too thin',
        detailAr: 'اكتب نقداً ومقارنة وفجوة — لا سرداً فقط.',
        detailEn: 'Write critique, comparison, and gap — not narration only.',
        severity: 'high',
      ));
    } else if (!_looksCritical(prior)) {
      issues.add(const ProposalConsistencyIssue(
        id: 'prior_narrative',
        titleAr: 'يبدو سردياً أكثر من نقدي',
        titleEn: 'Looks more narrative than critical',
        detailAr:
            'أضف كلمات مثل: اتفاق، اختلاف، فجوة، قصور، بينما، مقارنة، موقع الدراسة.',
        detailEn:
            'Add critical markers: agreement, difference, gap, limitation, comparison.',
        severity: 'medium',
      ));
    }

    if (method.length < 20) {
      issues.add(const ProposalConsistencyIssue(
        id: 'method_missing',
        titleAr: 'المنهج غير مذكور',
        titleEn: 'Method missing',
        detailAr: 'سمِّ المنهج وعلّل مناسبته.',
        detailEn: 'Name the method and justify fit.',
        severity: 'high',
      ));
    }

    if (instruments.length < 15 && method.length >= 20) {
      issues.add(const ProposalConsistencyIssue(
        id: 'instrument_missing',
        titleAr: 'الأداة غير مربوطة',
        titleEn: 'Instrument not specified',
        detailAr: 'اربط أداة/مصدر بيانات بكل سؤال رئيسي.',
        detailEn: 'Link an instrument/data source to each main question.',
        severity: 'high',
      ));
    } else if (instruments.length >= 15 &&
        questions.length >= 20 &&
        !_sharesTokens(instruments, questions)) {
      issues.add(const ProposalConsistencyIssue(
        id: 'inst_q_mismatch',
        titleAr: 'ضعف ربط الأداة بالأسئلة',
        titleEn: 'Weak instrument–questions link',
        detailAr: 'اذكر صراحة أي بند/فئة يخدم أي سؤال.',
        detailEn: 'State explicitly which items serve which questions.',
        severity: 'medium',
      ));
    }

    if (method.length >= 20 &&
        analysis.length < 15 &&
        draft.facultyId != 'Law') {
      issues.add(const ProposalConsistencyIssue(
        id: 'analysis_missing',
        titleAr: 'أساليب التحليل ناقصة',
        titleEn: 'Analysis methods missing',
        detailAr: 'وضّح كيف ستُجاب الأسئلة تحليلياً.',
        detailEn: 'Clarify how questions will be answered analytically.',
        severity: 'medium',
      ));
    }

    if ((draft.facultyId == 'Education' || draft.facultyId == 'Business') &&
        instruments.length >= 15 &&
        validity.length < 12) {
      issues.add(const ProposalConsistencyIssue(
        id: 'validity_missing',
        titleAr: 'الصدق/الثبات غير مذكور',
        titleEn: 'Validity/reliability missing',
        detailAr: 'في الخطط الميدانية اذكر أسلوب التحقق من الأداة.',
        detailEn: 'For field plans, state how the instrument will be validated.',
        severity: 'medium',
      ));
    }

    if (method.length >= 20 &&
        questions.length >= 20 &&
        !_methodMentionsKnownApproach(method) &&
        draft.facultyId == 'Law') {
      // soft hint only when empty of legal method cues
    }

    final deductions = issues.fold<int>(0, (sum, i) {
      return sum +
          (i.severity == 'high'
              ? 14
              : i.severity == 'medium'
                  ? 8
                  : 4);
    });
    final score = (100 - deductions).clamp(0, 100);
    return ProposalConsistencyReport(issues: issues, score: score);
  }

  static bool _isTooOpen(String title) {
    final t = title.trim();
    return t.startsWith('دراسة') ||
        t.startsWith('بحث') ||
        t.toLowerCase().startsWith('a study') ||
        t.length > 140;
  }

  static bool _looksCritical(String prior) {
    const markers = [
      'فجوة',
      'قصور',
      'اختلاف',
      'اتفاق',
      'مقارنة',
      'بينما',
      'غير أن',
      'موقع',
      'gap',
      'unlike',
      'however',
      'limitation',
      'differ',
      'compare',
    ];
    final lower = prior.toLowerCase();
    for (final m in markers) {
      if (prior.contains(m) || lower.contains(m.toLowerCase())) return true;
    }
    return false;
  }

  static bool _sharesTokens(String a, String b) {
    final ta = _tokens(a);
    final tb = _tokens(b);
    if (ta.isEmpty || tb.isEmpty) return true;
    var hits = 0;
    for (final t in ta) {
      if (tb.contains(t)) hits++;
    }
    return hits >= 2 || hits / ta.length >= 0.2;
  }

  static Set<String> _tokens(String text) {
    final out = <String>{};
    for (final p in text
        .toLowerCase()
        .split(RegExp(r'[\s,،.;:!?/\\|()\[\]{}\-]+'))) {
      final t = p.trim();
      if (t.length < 3) continue;
      if (_stop.contains(t)) continue;
      out.add(t);
    }
    return out;
  }

  static bool _methodMentionsKnownApproach(String method) {
    const cues = [
      'وصفي',
      'تجريبي',
      'نوعي',
      'كمّي',
      'كمي',
      'مختلط',
      'وثائقي',
      'مقارن',
      'تحليلي',
      'استقرائي',
      'استنباطي',
      'qualitative',
      'quantitative',
      'mixed',
      'doctrinal',
      'survey',
    ];
    final lower = method.toLowerCase();
    for (final c in cues) {
      if (method.contains(c) || lower.contains(c.toLowerCase())) return true;
    }
    return false;
  }

  static const _stop = {
    'التي',
    'الذي',
    'هذه',
    'هذا',
    'من',
    'على',
    'في',
    'إلى',
    'عن',
    'مع',
    'ما',
    'لا',
    'أن',
    'إن',
    'the',
    'and',
    'for',
    'with',
    'that',
    'this',
    'from',
    'into',
  };
}
