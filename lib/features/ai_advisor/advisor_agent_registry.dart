import 'package:flutter/material.dart';

import 'advisor_agent.dart';
import 'advisor_branding.dart';

class AdvisorAgentRegistry {
  AdvisorAgentRegistry._();

  static final AdvisorAgentRegistry instance = AdvisorAgentRegistry._();

  static const _baseRules = '''
قواعد عامة لجميع الوكلاء:
- افهم سؤال الطالب بصيغته الطبيعية مهما كانت عادية أو مختصرة.
- ممنوع منعاً باتاً أن تطلب منه إعادة الصياغة بقالب أو صيغة معينة.
- أجب مباشرة على ما سُئلت عنه بمحتوى عملي ومفيد.
- أجب بالعربية الأكاديمية الواضحة.
- لا تخترع أسماء مشرفين أو مراجع وهمية بأرقام DOI مزيفة.
- قسّم الإجابة بعناوين فرعية عند تعدد المهام.
''';

  static final List<AdvisorAgent> agents = [
    AdvisorAgent(
      id: AdvisorAgentId.researchIdea,
      nameAr: 'وكيل الأفكار البحثية',
      shortLabel: 'فكرة بحثية',
      description: 'تقييم وتطوير واقتراح أفكار بحثية',
      icon: Icons.lightbulb,
      color: Color(0xFFF57C00),
      keywords: [
        'فكرة بحث',
        'فكرة بحثية',
        'افكار بحث',
        'موضوع بحث',
        'موضوع رسالة',
        'اقترح فكرة',
        'رأيك في فكرة',
        'هل الفكرة',
        'تطوير فكرة',
        'فكرة مناسبة',
        'موضوع مناسب',
      ],
      systemPrompt: '''
أنت وكيل متخصص في تقييم وتطوير الأفكار البحثية للماجستير والدكتوراه.
عند أي سؤال عن فكرة بحثية: قيّمها مباشرة (الأهمية، الأصالة، القابلية للتنفيذ، المنهجية المناسبة).
اقترح 2-3 أسئلة بحثية، متغيرات محتملة، وتحديات متوقعة.
لا تطلب من الطالب صياغة معينة — افهم نصه كما هو.
''',
      samplePrompt:
          'عندي فكرة بحثية عن الذكاء الاصطناعي في التعليم الجامعي، هل هي مناسبة للماجستير؟',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.thesisWriter,
      nameAr: 'وكيل كتابة الرسائل',
      shortLabel: 'كتابة رسالة',
      description: 'صياغة فصول ومحتوى بأسلوب أكاديمي طبيعي',
      icon: Icons.edit_note,
      color: Color(0xFF1565C0),
      keywords: [
        'اكتب فصل',
        'اكتب مقدمة',
        'اكتب خاتمة',
        'صياغة فصل',
        'نص رسالة',
        'أسلوب بشري',
        'صياغة أكاديمية',
        'فقرة',
        'مقدمة الرسالة',
        'خاتمة الرسالة',
      ],
      systemPrompt: '''
أنت وكيل متخصص في كتابة الرسائل العلمية بأسلوب أكاديمي طبيعي وسلس.
ركّز على: البنية الأكاديمية، الربط المنطقي، تجنب الحشو، والصياغة العربية الفصيحة.
قدّم نصوصاً جاهزة للمراجعة مع تمييز الأماكن التي يحتاج فيها الطالب لإضافة بياناته.
''',
      samplePrompt:
          'اكتب مقدمة أكاديمية بأسلوب طبيعي عن أثر التعلم الإلكتروني على تحصيل طلاب الهندسة',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.researchSimulation,
      nameAr: 'وكيل محاكاة النتائج',
      shortLabel: 'محاكاة نتائج',
      description: 'سيناريوهات نتائج افتراضية للتدريب على التحليل',
      icon: Icons.insights,
      color: Color(0xFF6A1B9A),
      keywords: [
        'محاكاة',
        'نتائج افتراضية',
        'سيناريو نتائج',
        'توقع نتائج',
        'فرض نتائج',
        'نتائج تجريبية',
        'محاكاة بحث',
      ],
      systemPrompt: '''
أنت وكيل متخصص في محاكاة النتائج البحثية لأغراض التدريب والتخطيط.
وضّح دائماً أن النتائج افتراضية وليست بيانات حقيقية.
قدّم: الفرضيات، المتغيرات، جداول نتائج نموذجية، وتفسيراً إحصائياً مبسطاً.
''',
      samplePrompt:
          'حاكِ نتائج دراسة كمية عن علاقة التوتر الدراسي بأداء طلاب الطب مع جدول افتراضي',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.literatureReview,
      nameAr: 'وكيل المراجعة الأدبية',
      shortLabel: 'مراجعة أدبية',
      description: 'تحليل أوراق علمية وإطار نظري',
      icon: Icons.menu_book,
      color: Color(0xFF2E7D32),
      keywords: [
        'مراجعة أدبية',
        'مراجعة ادبية',
        'إطار نظري',
        'اطار نظري',
        'تحليل ورقة',
        'تحليل paper',
        'أدبيات',
        'دراسات سابقة',
        'gap',
        'فجوة بحثية',
        'نقد منهجي',
      ],
      systemPrompt: '''
أنت وكيل متخصص في المراجعة الأدبية وتحليل الأوراق العلمية.
قدّم: تلخيصاً منهجياً، نقاط القوة والضعف، الفجوة البحثية، واقتراح إطار نظري.
استخدم تنسيقاً أكاديمياً (مقدمة، محاور، خلاصة).
''',
      samplePrompt:
          'حلّل ورقة علمية عن الذكاء الاصطناعي في التعليم واقترح فجوة بحثية',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.citations,
      nameAr: 'وكيل المراجع والتوثيق',
      shortLabel: 'مراجع وتوثيق',
      description: 'APA، IEEE، Chicago وتنظيم المراجع',
      icon: Icons.format_quote,
      color: Color(0xFF5D4037),
      keywords: [
        'مرجع',
        'مراجع',
        'توثيق',
        'apa',
        'ieee',
        'chicago',
        'harvard',
        'قائمة مصادر',
        'bibliography',
        'اقتباس',
        'تنسيق مراجع',
      ],
      systemPrompt: '''
أنت وكيل متخصص في إدارة المراجع والتوثيق الأكاديمي.
رتّب المراجع حسب النمط المطلوب (APA/IEEE/Chicago/Harvard).
صحّح التوثيق داخل النص وقدّم قائمة مراجع منظمة.
''',
      samplePrompt:
          'رتّب هذه المراجع بأسلوب APA: Smith, J. (2020). AI in Education. Journal of Learning.',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.academicEditing,
      nameAr: 'وكيل التحرير والتدقيق',
      shortLabel: 'تحرير لغوي',
      description: 'صياغة، تدقيق لغوي، وتحسين أسلوب أكاديمي',
      icon: Icons.spellcheck,
      color: Color(0xFFC62828),
      keywords: [
        'تحرير',
        'تدقيق',
        'تدقيق لغوي',
        'تصحيح لغوي',
        'تحسين الصياغة',
        'إعادة صياغة',
        'grammar',
        'لغة عربية',
        'أخطاء لغوية',
      ],
      systemPrompt: '''
أنت وكيل متخصص في التحرير الأكاديمي والتدقيق اللغوي العربي.
أعد الصياغة مع الحفاظ على المعنى العلمي، وأبرز التعديلات المقترحة.
قدّم نسخة محسّنة + قائمة ملاحظات تحريرية.
''',
      samplePrompt:
          'حرّر هذا النص أكاديمياً: الدراسة بتتكلم عن تأثير التكنولوجيا على الطلاب بشكل كبير',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.dataAnalysis,
      nameAr: 'وكيل تحليل البيانات',
      shortLabel: 'بيانات وبرمجة',
      description: 'SPSS، Python، R وتحليل إحصائي',
      icon: Icons.analytics,
      color: Color(0xFF00838F),
      keywords: [
        'spss',
        'python',
        'r studio',
        'تحليل بيانات',
        'إحصاء',
        'احصاء',
        'regression',
        'انحدار',
        't-test',
        'anova',
        'كود',
        'برمجة',
        'pandas',
        'معادلة',
      ],
      systemPrompt: '''
أنت وكيل متخصص في تحليل البيانات والبرمجة للبحث التجريبي.
اقترح: المنهج الإحصائي المناسب، خطوات التحليل، وأمثلة كود (Python/R/SPSS).
وضّح الافتراضات الإحصائية والمتطلبات.
''',
      samplePrompt:
          'اقترح تحليلاً إحصائياً لبيانات استبيان 120 مشاركاً مع كود Python مبسط',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.presentations,
      nameAr: 'وكيل العروض التقديمية',
      shortLabel: 'عروض ومناقشة',
      description: 'هيكل عرض المناقشة والندوات',
      icon: Icons.slideshow,
      color: Color(0xFFEF6C00),
      keywords: [
        'عرض تقديمي',
        'باوربوينت',
        'powerpoint',
        'مناقشة',
        'ندوة',
        'شرائح',
        'slides',
        'عروض',
        'دفاع الرسالة',
      ],
      systemPrompt: '''
أنت وكيل متخصص في إعداد العروض التقديمية للمناقشات والندوات الأكاديمية.
قدّم: هيكل الشرائح، نقاط كل شريحة، وقت مقترح، ونصائح للمناقشة والأسئلة المتوقعة.
''',
      samplePrompt:
          'جهّز هيكل عرض تقديمي لمدة 15 دقيقة عن رسالة في الطاقة المتجددة',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.thesisPlanning,
      nameAr: 'وكيل تخطيط البحث',
      shortLabel: 'تخطيط بحث',
      description: 'عناوين، أسئلة بحثية، وتلخيص',
      icon: Icons.lightbulb_outline,
      color: Color(0xFF4527A0),
      keywords: [
        'عناوين',
        'عنوان',
        'اقترح لي',
        'موضوع رسالة',
        'سؤال بحثي',
        'لخّص',
        'لخص',
        'ملخص',
        'خطة بحث',
        'منهجية',
      ],
      systemPrompt: '''
أنت وكيل متخصص في تخطيط البحث العلمي.
ساعد في: عناوين الرسائل، الأسئلة البحثية، تلخيص الأبحاث، وخطة المنهجية.
''',
      samplePrompt: 'اقترح لي 10 عناوين رسالة في الطاقة الشمسية',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.supervisorMatch,
      nameAr: 'وكيل اختيار المشرف',
      shortLabel: 'مشرف مناسب',
      description: 'مطابقة مع مشرفين التطبيق',
      icon: Icons.person_search,
      color: Color(0xFF1A237E),
      keywords: [
        'مشرف',
        'الأنسب',
        'الانسب',
        'من يشرف',
        'أشرفني',
      ],
      systemPrompt: '',
      samplePrompt: 'ما المشرف الأنسب لفكرتي في تحليل البيانات الزراعية؟',
    ),
    AdvisorAgent(
      id: AdvisorAgentId.general,
      nameAr: 'المنسق الأكاديمي',
      shortLabel: 'عام',
      description: 'توجيه ذكي لأي طلب أكاديمي',
      icon: Icons.hub,
      color: Color(0xFF37474F),
      keywords: [],
      systemPrompt: '''
أنت المنسق الأكاديمي العام في AcadeGate.
افهم أي سؤال أكاديمي بصيغة طبيعية وأجب عليه مباشرة دون طلب إعادة صياغة.
إذا كان السؤال عاماً، قدّم خطة عملية وخطوات واضحة.
''',
      samplePrompt: 'ساعدني في البدء بخطة رسالة ماجستير في الذكاء الاصطناعي',
    ),
  ];

  AdvisorAgent byId(AdvisorAgentId id) {
    return agents.firstWhere((agent) => agent.id == id);
  }

  String orchestratorPrompt({
    required AdvisorRoutePlan plan,
    required String profileSummary,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('أنت ${AdvisorBranding.cloudBadge} — منسق وكلاء أكاديميين متخصصين.');
    buffer.writeln(_baseRules);

    final primary = byId(plan.primary);
    buffer.writeln('\n## الوكيل الرئيسي: ${primary.nameAr}');
    buffer.writeln(primary.systemPrompt);

    for (final id in plan.supporting) {
      final agent = byId(id);
      buffer.writeln('\n## وكيل داعم: ${agent.nameAr}');
      buffer.writeln(agent.systemPrompt);
    }

    if (plan.isMultiAgent) {
      buffer.writeln(
        '\nمهم: الطلب يحتاج أكثر من تخصص. قسّم ردك بعناوين بأسماء الوكلاء.',
      );
    }

    buffer.writeln('\nملف الطالب: $profileSummary');
    return buffer.toString();
  }

  /// مطالبة سحابية مختصرة — تترك Gemini يجيب بعمق مثل التطبيق الرسمي.
  String cloudSystemPrompt({
    required String agentName,
    required String agentFocus,
    required String profileSummary,
    required String extraContext,
    required bool isMultiAgent,
    required List<String> supportingAgents,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'أنت ${AdvisorBranding.cloudBadge} — مساعد أكاديمي خبير في تطبيق ${AdvisorBranding.name} '
      'للدراسات العليا (ماجستير ودكتوراه).',
    );
    buffer.writeln('''
أجب على سؤال الطالب **مباشرة وبشكل وافٍ ومفصّل** كما يفعل Gemini — لا تختصر إلا إذا طلب ذلك.
- افهم السؤال بأي صيغة عربية طبيعية (عامية أو فصحى).
- ممنوع أن تطلب منه إعادة صياغة السؤال أو استخدام قالب معين.
- استخدم عناوين فرعية ونقاط وأمثلة عملية عند الحاجة.
- لا تخترع أسماء مشرفين أو مراجع بأرقام DOI وهمية.
''');

    buffer.writeln('\nالتخصص النشط: $agentName');
    if (agentFocus.trim().isNotEmpty) {
      buffer.writeln(agentFocus.trim());
    }

    if (isMultiAgent && supportingAgents.isNotEmpty) {
      buffer.writeln(
        '\nالطلب يحتاج أيضاً خبرة: ${supportingAgents.join('، ')} — '
        'ادمجها في رد واحد متماسك.',
      );
    }

    if (profileSummary.trim().isNotEmpty) {
      buffer.writeln('\nملف الطالب: $profileSummary');
    }

    if (extraContext.trim().isNotEmpty) {
      buffer.writeln('\nبيانات من التطبيق (استخدمها عند الحاجة):\n$extraContext');
    }

    return buffer.toString();
  }
}
