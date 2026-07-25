import '../../core/locale/app_translate.dart';
import '../academic/academic_content_service.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../profile/academic_profile_service.dart';
import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';
import 'advisor_intent.dart';
import 'advisor_prompts.dart';
import 'advisor_query_parser.dart';
import 'advisor_router.dart';

class LocalAdvisorEngine {
  LocalAdvisorEngine._();

  static final LocalAdvisorEngine instance = LocalAdvisorEngine._();

  Future<String> respondToAgents({
    required String message,
    required AdvisorRoutePlan plan,
  }) async {
    final sections = <String>[];

    for (final agentId in plan.allAgents) {
      final agent = AdvisorAgentRegistry.instance.byId(agentId);
      final section = await _respondForAgent(agentId, message);
      if (plan.isMultiAgent) {
        sections.add('## ${agent.displayShortLabel}\n$section');
      } else {
        sections.add(section);
      }
    }

    if (plan.isMultiAgent) {
      return appTr(
        'رد مجمّع من ${plan.allAgents.length} وكلاء متخصصين:\n\n'
            '${sections.join('\n\n')}',
        'Combined response from ${plan.allAgents.length} specialist agents:\n\n'
            '${sections.join('\n\n')}',
      );
    }

    return sections.first;
  }

  Future<String> _respondForAgent(AdvisorAgentId id, String message) async {
    return switch (id) {
      AdvisorAgentId.researchIdea => _researchIdea(message),
      AdvisorAgentId.thesisPlanning => _thesisPlanning(message),
      AdvisorAgentId.supervisorMatch => supervisorHint(message),
      AdvisorAgentId.thesisWriter => _thesisWriter(message),
      AdvisorAgentId.researchSimulation => _researchSimulation(message),
      AdvisorAgentId.literatureReview => _literatureReview(message),
      AdvisorAgentId.citations => _citations(message),
      AdvisorAgentId.academicEditing => _academicEditing(message),
      AdvisorAgentId.dataAnalysis => _dataAnalysis(message),
      AdvisorAgentId.presentations => _presentations(message),
      AdvisorAgentId.general => _generalHelp(message),
    };
  }

  Future<String> _thesisPlanning(String message) async {
    final parsed = AcademicQueryParser.parse(message);
    return switch (parsed.goal) {
      AcademicQueryGoal.researchQuestion => _toResearchQuestion(message, parsed),
      AcademicQueryGoal.summarize => _summarizeText(message),
      AcademicQueryGoal.thesisTitles => _suggestTitles(message, parsed),
      AcademicQueryGoal.researchIdea => _researchIdea(message),
      _ => _researchIdea(message),
    };
  }

  Future<String> _researchIdea(String message) async {
    final parsed = AcademicQueryParser.parse(message);
    final topic = parsed.hasClearSubject ? parsed.subject : parsed.rawMessage;
    final lower = message.toLowerCase();
    final isEvaluation = _any(lower, [
      'هل',
      'رأيك',
      'رايك',
      'مناسبة',
      'جيدة',
      'تقييم',
      'رأي',
    ]);

    final buffer = StringBuffer();
    if (isEvaluation) {
      buffer.writeln(appTr(
        'نعم، يمكن العمل على هذه الفكرة — إليك تحليلاً مباشراً:\n',
        'Yes, you can pursue this idea — here is a direct analysis:\n',
      ));
    } else {
      buffer.writeln(appTr(
        'تحليل فكرتك البحثية:\n',
        'Analysis of your research idea:\n',
      ));
    }

    buffer.writeln(appTr(
      '**الموضوع:** $topic\n',
      '**Topic:** $topic\n',
    ));
    buffer.writeln(appTr(
      '**لماذا تستحق الدراسة؟**',
      '**Why is it worth studying?**',
    ));
    buffer.writeln(appTr(
      'الموضوع يرتبط بتحدٍّ أكاديمي/تطبيقي واضح، ويمكن قياسه أو تحليله منهجياً '
      'حسب تخصصك والسياق المحلي.',
      'The topic addresses a clear academic or practical challenge and can be measured or '
      'analyzed systematically according to your field and local context.',
    ));
    buffer.writeln('\n${appTr('**نقاط القوة المحتملة:**', '**Potential strengths:**')}');
    buffer.writeln(appTr(
      '• موضوع معاصر وله أدبيات بحثية متنامية.',
      '• A contemporary topic with growing research literature.',
    ));
    buffer.writeln(appTr(
      '• قابل لصياغة أهداف وأسئلة محددة.',
      '• Can be shaped into clear objectives and research questions.',
    ));
    buffer.writeln(appTr(
      '• يمكن ربطه بتطبيق عملي أو توصيات للمؤسسات.',
      '• Can be linked to practical applications or institutional recommendations.',
    ));

    buffer.writeln('\n${appTr('**تحديات يجب انتباهك لها:**', '**Challenges to watch for:**')}');
    buffer.writeln(appTr(
      '• تحديد مجتمع الدراسة وعينة واضحة.',
      '• Define a clear study population and sample.',
    ));
    buffer.writeln(appTr(
      '• اختيار منهجية مناسبة (كمي/نوعي/مختلط).',
      '• Choose a suitable methodology (quantitative/qualitative/mixed).',
    ));
    buffer.writeln(appTr(
      '• تجنب العنوان الواسع جداً — ضيّق النطاق.',
      '• Avoid an overly broad title — narrow the scope.',
    ));

    buffer.writeln('\n${appTr('**أسئلة بحثية مقترحة:**', '**Suggested research questions:**')}');
    final questionsAr = [
      'ما أثر $topic على ... في السياق المحلي؟',
      'كيف يمكن تحسين تطبيق $topic باستخدام منهجية ...؟',
      'ما العوامل المؤثرة في ... المرتبطة بـ$topic؟',
    ];
    final questionsEn = [
      'What is the impact of $topic on ... in the local context?',
      'How can the application of $topic be improved using a ... methodology?',
      'What factors influence ... related to $topic?',
    ];
    for (var i = 0; i < questionsAr.length; i++) {
      buffer.writeln('${i + 1}. ${appTr(questionsAr[i], questionsEn[i])}');
    }

    buffer.writeln('\n${appTr('**منهجية مناسبة:**', '**Suitable methodology:**')}');
    if (_any(lower, ['تجريب', 'قياس', 'استبيان', 'إحصاء'])) {
      buffer.writeln(appTr(
        'منهج كمي (استبيان/تجربة) مع تحليل إحصائي.',
        'Quantitative approach (survey/experiment) with statistical analysis.',
      ));
    } else if (_any(lower, ['مقابلة', 'دراسة حالة', 'نوعي'])) {
      buffer.writeln(appTr(
        'منهج نوعي (مقابلات/دراسة حالة) مع تحليل موضوعاتي.',
        'Qualitative approach (interviews/case study) with thematic analysis.',
      ));
    } else {
      buffer.writeln(appTr(
        'ابدأ بمنهج مختلط أو كمي حسب قابلية جمع البيانات.',
        'Start with a mixed or quantitative approach depending on data availability.',
      ));
    }

    final profile = await AcademicProfileService.instance.loadProfile();
    if (profile != null && profile.isComplete) {
      final content = await AcademicContentService.instance.fetchAll();
      final ideaProfile = profile.copyWith(researchInterest: topic);
      final matches = SmartMatchmakingEngine.matchResearchIdeas(
        ideaProfile,
        content.ideas,
        limit: 2,
      );
      if (matches.isNotEmpty) {
        buffer.writeln('\n${appTr('**أفكار مشابهة في AcadeGate:**', '**Similar ideas on AcadeGate:**')}');
        for (final match in matches) {
          buffer.writeln(appTr(
            '• ${match.item.title} (${match.item.provider}) — توافق ${match.score}%',
            '• ${match.item.title} (${match.item.provider}) — ${match.score}% match',
          ));
        }
      }
    }

    buffer.writeln(appTr(
      '\n**الخطوة التالية:** اختر سؤالاً بحثياً واحداً وحدد المتغيرات، '
      'ثم ناقشه مع مشرفك أو استخدم المطابقة الذكية.',
      '\n**Next step:** Choose one research question and define the variables, '
      'then discuss it with your supervisor or use smart matching.',
    ));

    return buffer.toString();
  }

  bool _any(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  String _thesisWriter(String message) {
    final topic = extractAdvisorTopic(message) ??
        appTr('موضوع بحثك', 'your research topic');
    return appTr(
      'مسودة مقدمة أكاديمية (أسلوب طبيعي) عن **$topic**:\n\n'
          'شهدت السنوات الأخيرة تزايد الاهتمام البحثي بـ$topic، '
          'وانعكس ذلك في تعدد الدراسات التي حاولت فهم أبعاده بطرق منهجية مختلفة. '
          'ومع ذلك، ما تزال هناك فجوات معرفية تتطلب مزيداً من التحليل في السياق المحلي.\n\n'
          'تهدف هذه الرسالة إلى ... [أضف هدفك ومتغيراتك].\n'
          'وتسعى إلى الإجابة عن السؤال: ... [أضف سؤالك البحثي].\n\n'
          'نصيحة: أضف إحصائية أو مرجعاً حديثاً لجعل المقدمة أقوى.',
      'Academic introduction draft (natural style) on **$topic**:\n\n'
          'Recent years have seen growing research interest in $topic, '
          'reflected in diverse studies that tried to understand its dimensions through different methodologies. '
          'However, knowledge gaps still require further analysis in the local context.\n\n'
          'This thesis aims to ... [add your objective and variables].\n'
          'It seeks to answer: ... [add your research question].\n\n'
          'Tip: Add a statistic or recent reference to strengthen the introduction.',
    );
  }

  String _researchSimulation(String message) {
    final topic = extractAdvisorTopic(message) ??
        appTr('المتغير المدروس', 'the studied variable');
    return appTr(
      '⚠️ نتائج افتراضية للتدريب فقط — ليست بيانات حقيقية.\n\n'
          '**الفرضيات:**\n'
          'H1: يوجد علاقة دالة بين $topic والأداء.\n'
          'H0: لا توجد علاقة ذات دلالة.\n\n'
          '**جدول نتائج نموذجي (n=120):**\n'
          '| المجموعة | المتوسط | الانحراف المعياري | t | p |\n'
          '|---|---:|---:|---:|---:|\n'
          '| تجريبية | 4.2 | 0.6 | 2.31 | 0.023 |\n'
          '| ضابطة | 3.7 | 0.7 | — | — |\n\n'
          '**تفسير:** الفرق ذو دلالة إحصائية عند مستوى 0.05. '
          'فعّل AcadeGate AI السحابي لمحاكاة أدق حسب منهجيتك.',
      '⚠️ Hypothetical results for training only — not real data.\n\n'
          '**Hypotheses:**\n'
          'H1: There is a positive relationship between $topic and performance.\n'
          'H0: There is no significant relationship.\n\n'
          '**Sample results table (n=120):**\n'
          '| Group | Mean | Std. dev. | t | p |\n'
          '|---|---:|---:|---:|---:|\n'
          '| Experimental | 4.2 | 0.6 | 2.31 | 0.023 |\n'
          '| Control | 3.7 | 0.7 | — | — |\n\n'
          '**Interpretation:** The difference is statistically significant at the 0.05 level. '
          'Enable cloud AcadeGate AI for more accurate simulation based on your methodology.',
    );
  }

  String _literatureReview(String message) {
    final topic = extractAdvisorTopic(message) ?? appTr('الموضوع', 'the topic');
    return appTr(
      '**تحليل أدبي مبدئي لموضوع: $topic**\n\n'
          '1. **المحور النظري:** تعريف المفاهيم الأساسية وتطورها.\n'
          '2. **الدراسات السابقة:** تصنيف حسب المنهج (كمي/نوعي) والنتائج.\n'
          '3. **نقد منهجي:** حجم العينة، أدوات القياس، قابلية التعميم.\n'
          '4. **الفجوة البحثية:** ما الذي لم يُغطَّ بعد في السياق المحلي؟\n'
          '5. **إطار نظري مقترح:** ربط المتغيرات المستقلة والتابعة.\n\n'
          'الصق عنوان الورقة أو ملخصها للحصول على تحليل أعمق.',
      '**Initial literature analysis for: $topic**\n\n'
          '1. **Theoretical axis:** Define core concepts and their evolution.\n'
          '2. **Previous studies:** Classify by methodology (quantitative/qualitative) and findings.\n'
          '3. **Methodological critique:** Sample size, measurement tools, generalizability.\n'
          '4. **Research gap:** What remains uncovered in the local context?\n'
          '5. **Suggested theoretical framework:** Link independent and dependent variables.\n\n'
          'Paste the paper title or abstract for deeper analysis.',
    );
  }

  String _citations(String message) {
    return appTr(
      '**تنظيم مراجع (مثال APA):**\n\n'
          'داخل النص: (Smith, 2020)\n\n'
          'قائمة المراجع:\n'
          'Smith, J. (2020). Title of article. *Journal Name*, 12(3), 45-60.\n\n'
          'أرسل قائمة مراجعك غير المرتبة وسأعيد تنسيقها '
          '(APA / IEEE / Chicago / Harvard).',
      '**Reference formatting (APA example):**\n\n'
          'In text: (Smith, 2020)\n\n'
          'Reference list:\n'
          'Smith, J. (2020). Title of article. *Journal Name*, 12(3), 45-60.\n\n'
          'Send your unordered reference list and I will reformat it '
          '(APA / IEEE / Chicago / Harvard).',
    );
  }

  String _academicEditing(String message) {
    final text = message
        .replaceFirst(RegExp(r'حرّر|تحرير|تدقيق', caseSensitive: false), '')
        .replaceFirst(RegExp(r'هذا النص[:\s]*', caseSensitive: false), '')
        .trim();

    if (text.length < 15) {
      return appTr(
        'الصق النص المراد تحريره بعد كلمة «حرّر» لأعيد صياغته أكاديمياً.',
        'Paste the text to edit after the word "edit" and I will rewrite it academically.',
      );
    }

    return appTr(
      '**نسخة محسّنة (مبدئية):**\n'
          'تتناول الدراسة أثر ${text.length > 40 ? '...' : text} '
          'من منظور أكاديمي منهجي.\n\n'
          '**ملاحظات تحريرية:**\n'
          '• استبدل العبارات العامة بمصطلحات دقيقة.\n'
          '• اربط الجمل بأدوات انتقال منطقية.\n'
          '• حدّد المتغيرات والمجتمع بوضوح.\n\n'
          'فعّل الوضع السحابي لتحرير كامل للنص المرفق.',
      '**Improved version (draft):**\n'
          'The study examines the impact of ${text.length > 40 ? '...' : text} '
          'from a systematic academic perspective.\n\n'
          '**Editing notes:**\n'
          '• Replace vague phrases with precise terminology.\n'
          '• Connect sentences with logical transitions.\n'
          '• Define variables and population clearly.\n\n'
          'Enable cloud mode for full editing of the attached text.',
    );
  }

  String _dataAnalysis(String message) {
    final topic = extractAdvisorTopic(message) ??
        appTr('بيانات الاستبيان', 'survey data');
    return appTr(
      '**خطة تحليل مقترحة لـ$topic:**\n\n'
          '1. تنظيف البيانات وفحص القيم المفقودة.\n'
          '2. اختبار التوزيع الطبيعي.\n'
          '3. اختيار الاختبار: t-test / ANOVA / انحدار حسب نوع المتغيرات.\n'
          '4. حساب حجم الأثر والدلالة الإحصائية.\n\n'
          '**مثال Python:**\n'
          '```python\n'
          'import pandas as pd\n'
          'from scipy import stats\n'
          'df = pd.read_csv("data.csv")\n'
          't, p = stats.ttest_ind(df["group_a"], df["group_b"])\n'
          'print(t, p)\n'
          '```',
      '**Suggested analysis plan for $topic:**\n\n'
          '1. Clean data and check for missing values.\n'
          '2. Test for normal distribution.\n'
          '3. Choose the test: t-test / ANOVA / regression based on variable types.\n'
          '4. Calculate effect size and statistical significance.\n\n'
          '**Python example:**\n'
          '```python\n'
          'import pandas as pd\n'
          'from scipy import stats\n'
          'df = pd.read_csv("data.csv")\n'
          't, p = stats.ttest_ind(df["group_a"], df["group_b"])\n'
          'print(t, p)\n'
          '```',
    );
  }

  String _presentations(String message) {
    final topic = extractAdvisorTopic(message) ?? appTr('رسالتك', 'your thesis');
    return appTr(
      '**هيكل عرض مناقشة (15 دقيقة) — $topic:**\n\n'
          '1. العنوان والباحث (1 د)\n'
          '2. المشكلة والأهمية (2 د)\n'
          '3. الأهداف والأسئلة (1 د)\n'
          '4. الإطار النظري المختصر (3 د)\n'
          '5. المنهجية (3 د)\n'
          '6. النتائج الرئيسية (3 د)\n'
          '7. الخاتمة والتوصيات (2 د)\n\n'
          '**أسئلة متوقعة:** المنهجية، حجم العينة، حدود الدراسة، التطبيق العملي.',
      '**Defense presentation outline (15 minutes) — $topic:**\n\n'
          '1. Title and researcher (1 min)\n'
          '2. Problem and significance (2 min)\n'
          '3. Objectives and questions (1 min)\n'
          '4. Brief theoretical framework (3 min)\n'
          '5. Methodology (3 min)\n'
          '6. Key findings (3 min)\n'
          '7. Conclusion and recommendations (2 min)\n\n'
          '**Expected questions:** methodology, sample size, study limitations, practical application.',
    );
  }

  Future<String> respond({
    required String message,
    required AdvisorIntent intent,
  }) async {
    final plan = AdvisorRouter.instance.route(message);
    return respondToAgents(message: message, plan: plan);
  }

  String _suggestTitles(String message, ParsedAcademicQuery parsed) {
    final topic = parsed.hasClearSubject
        ? parsed.subject
        : appTr('مجال بحثك', 'your research field');
    final templatesAr = [
      'دراسة تحليلية لـ$topic في السياق المحلي',
      'تطوير نموذج مقترح لـ$topic باستخدام منهجية مختلطة',
      'قياس أثر $topic على الأداء الأكاديمي: دراسة ميدانية',
      'مقارنة بين أساليب تطبيق $topic في بيئتين مختلفتين',
      'تحديد العوامل المؤثرة في $topic باستخدام تحليل إحصائي',
      'تصميم إطار عمل لتحسين $topic في المؤسسات التعليمية',
      'استكشاف التحديات والفرص المرتبطة بـ$topic',
      'تقييم فعالية $topic من منظور المستفيدين',
      'دمج $topic مع تقنيات حديثة: دراسة تطبيقية',
      'مراجعة نظرية وتجريبية لأبحاث $topic خلال العقد الأخير',
    ];
    final templatesEn = [
      'An analytical study of $topic in the local context',
      'Developing a proposed model for $topic using a mixed methodology',
      'Measuring the impact of $topic on academic performance: a field study',
      'Comparing approaches to applying $topic in two different settings',
      'Identifying factors influencing $topic using statistical analysis',
      'Designing a framework to improve $topic in educational institutions',
      'Exploring challenges and opportunities related to $topic',
      'Evaluating the effectiveness of $topic from beneficiaries\' perspective',
      'Integrating $topic with modern technologies: an applied study',
      'Theoretical and empirical review of $topic research over the last decade',
    ];

    final buffer = StringBuffer(appTr(
      'إليك 10 عناوين مقترحة لرسالة في **$topic**:\n\n',
      'Here are 10 suggested thesis titles in **$topic**:\n\n',
    ));
    for (var i = 0; i < templatesAr.length; i++) {
      buffer.writeln('${i + 1}. ${appTr(templatesAr[i], templatesEn[i])}');
    }
    buffer.writeln(appTr(
      '\nنصيحة: اختر عنواناً محدداً يحدد المجتمع، المنهجية، والمتغيرات بوضوح.',
      '\nTip: Choose a specific title that clearly defines population, methodology, and variables.',
    ));
    return buffer.toString();
  }

  String _researchIdeaSync(String message, ParsedAcademicQuery parsed) {
    final topic = parsed.hasClearSubject ? parsed.subject : message.trim();
    return appTr(
      'صياغات لسؤال بحثي حول **$topic**:\n\n'
          '1. ما أثر $topic على النتائج في السياق المحلي؟\n'
          '2. كيف يمكن قياس تطبيق $topic منهجياً؟\n'
          '3. ما العوامل المؤثرة في نجاح $topic؟',
      'Research question formulations on **$topic**:\n\n'
          '1. What is the impact of $topic on outcomes in the local context?\n'
          '2. How can the application of $topic be measured systematically?\n'
          '3. What factors influence the success of $topic?',
    );
  }

  String _toResearchQuestion(String message, ParsedAcademicQuery parsed) {
    final idea = parsed.hasClearSubject ? parsed.subject : parsed.rawMessage;
    if (idea.length < 4) {
      return _researchIdeaSync(message, parsed);
    }

    final questionsAr = [
      'ما أثر $idea على النتائج البحثية في السياق المحلي؟',
      'كيف يمكن تحسين $idea باستخدام منهجية علمية قابلة للقياس؟',
      'ما العوامل المؤثرة في نجاح تطبيق $idea وفقاً للأدبيات الحديثة؟',
      'إلى أي مدى يرتبط $idea بتحسين الأداء وفق دراسة ميدانية؟',
      'ما الفروق ذات الدلالة الإحصائية في $idea بين المجموعات المدروسة؟',
    ];
    final questionsEn = [
      'What is the impact of $idea on research outcomes in the local context?',
      'How can $idea be improved using a measurable scientific methodology?',
      'What factors influence the success of applying $idea according to recent literature?',
      'To what extent is $idea associated with improved performance in a field study?',
      'What statistically significant differences exist in $idea between studied groups?',
    ];

    final buffer = StringBuffer(appTr(
      'صياغات مقترحة لسؤال بحثي حول **$idea**:\n\n',
      'Suggested research question formulations on **$idea**:\n\n',
    ));
    for (var i = 0; i < questionsAr.length; i++) {
      buffer.writeln('${i + 1}. ${appTr(questionsAr[i], questionsEn[i])}');
    }
    buffer.writeln(appTr(
      '\nاختر سؤالاً واحداً ثم حدّد المتغيرات المستقلة والتابعة والمنهجية.',
      '\nChoose one question, then define independent and dependent variables and methodology.',
    ));
    return buffer.toString();
  }

  String _summarizeText(String message) {
    final text = message
        .replaceFirst(RegExp(r'لخّص|لخص|ملخص|تلخيص', caseSensitive: false), '')
        .replaceFirst(
          RegExp(r'هذا الملخص العلمي[:\s]*', caseSensitive: false),
          '',
        )
        .trim();

    if (text.length < 20) {
      final parsed = AcademicQueryParser.parse(message);
      if (parsed.hasClearSubject) {
        return appTr(
          '**ملخص مبدئي لموضوع: ${parsed.subject}**\n\n'
              '• يمكن دراسته أكاديمياً بتحديد مجتمع ومنهجية واضحة.\n'
              '• اقترح البدء بسؤال بحثي واحد محدد ثم مراجعة الأدبيات.\n'
              '• إذا لديك نص كامل، أرسله وسألخّصه بتفصيل أكبر.',
          '**Initial summary for: ${parsed.subject}**\n\n'
              '• It can be studied academically with a clear population and methodology.\n'
              '• Start with one focused research question, then review the literature.\n'
              '• If you have full text, send it for a more detailed summary.',
        );
      }
    }

    final sentences = text
        .split(RegExp(r'[.!؟\n]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 8)
        .toList();

    final keywords = _extractKeywords(text).take(6).toList();

    final buffer = StringBuffer(appTr('**ملخص منظم**\n\n', '**Structured summary**\n\n'));
    buffer.writeln(appTr(
      '• الهدف: ${sentences.isNotEmpty ? sentences.first : text}',
      '• Objective: ${sentences.isNotEmpty ? sentences.first : text}',
    ));
    if (sentences.length > 1) {
      buffer.writeln(appTr(
        '• المنهج/الإجراء: ${sentences[1]}',
        '• Method/procedure: ${sentences[1]}',
      ));
    }
    if (sentences.length > 2) {
      buffer.writeln(appTr(
        '• النتائج/الاستنتاج: ${sentences.last}',
        '• Results/conclusion: ${sentences.last}',
      ));
    }
    if (keywords.isNotEmpty) {
      buffer.writeln('\n${appTr('**كلمات مفتاحية:**', '**Keywords:**')} ${keywords.join('، ')}');
    }
    buffer.writeln(appTr(
      '\nملاحظة: هذا تلخيص أولي — راجع الصياغة قبل إدراجه في البحث.',
      '\nNote: This is a preliminary summary — review the wording before including it in your research.',
    ));
    return buffer.toString();
  }

  Future<String> supervisorHint(String message) async {
    final parsed = AcademicQueryParser.parse(message);
    final profile = await AcademicProfileService.instance.loadProfile();
    final topic = parsed.hasClearSubject ? parsed.subject : parsed.rawMessage;

    if (profile == null || !profile.isComplete) {
      return appTr(
        'بناءً على سؤالك عن المشرف، أكمل **ملفي الأكاديمي** '
            '(التخصص والاهتمام البحثي) لأعطيك مطابقة أدق.\n\n'
            'حتى ذلك الحين: ابحث عن مشرفين في تخصص **$topic** '
            'من قسم المشرفين أو المطابقة الذكية.',
        'Based on your supervisor question, complete your **academic profile** '
            '(specialization and research interest) for a better match.\n\n'
            'Until then: look for supervisors in **$topic** '
            'via the Supervisors section or smart matching.',
      );
    }

    final effectiveProfile = topic.length >= 3
        ? profile.copyWith(researchInterest: topic)
        : profile;

    final content = await AcademicContentService.instance.fetchAll();
    final matches = SmartMatchmakingEngine.matchSupervisors(
      effectiveProfile,
      content.supervisors,
      limit: 3,
    );

    if (matches.isEmpty) {
      return appTr(
        'لا توجد بيانات مشرفين كافية حالياً. جرّب لاحقاً أو تصفّح قسم المشرفين.',
        'Not enough supervisor data right now. Try again later or browse the Supervisors section.',
      );
    }

    final buffer = StringBuffer(appTr(
      'أفضل المشرفين المقترحين',
      'Top suggested supervisors',
    ));
    if (topic.length >= 3) {
      buffer.write(appTr(
        ' لفكرتك في **$topic**',
        ' for your idea in **$topic**',
      ));
    }
    buffer.writeln(':\n');

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final supervisor = match.item;
      buffer.writeln(appTr(
        '${i + 1}. **${supervisor.name}** — توافق ${match.score}%',
        '${i + 1}. **${supervisor.name}** — ${match.score}% match',
      ));
      buffer.writeln('   ${supervisor.university} • ${supervisor.speciality}');
      if (match.reasons.isNotEmpty) {
        buffer.writeln('   • ${match.reasons.join(' • ')}');
      }
      buffer.writeln();
    }

    buffer.writeln(appTr(
      'يمكنك فتح قسم المشرفين أو المطابقة الذكية لمزيد من التفاصيل.',
      'Open the Supervisors section or smart matching for more details.',
    ));
    return buffer.toString();
  }

  Future<String> _generalHelp(String message) async {
    if (message.trim().length < 3) {
      return advisorGeneralHelp;
    }

    final parsed = AcademicQueryParser.parse(message);
    if (parsed.goal != AcademicQueryGoal.general) {
      return _respondForAgent(_agentIdForGoal(parsed.goal), message);
    }

    final topic = parsed.hasClearSubject ? parsed.subject : message.trim();
    return appTr(
      'بخصوص سؤالك:\n\n'
          '**$topic**\n\n'
          'يمكنك البدء بخطة بسيطة:\n'
          '1. حدّد المشكلة البحثية بدقة.\n'
          '2. اصنع سؤالاً بحثياً واحداً قابلاً للقياس.\n'
          '3. راجع 5-10 دراسات حديثة في نفس المجال.\n'
          '4. اختر المنهجية (كمي/نوعي/مختلط).\n'
          '5. ناقش الفكرة مع مشرفك.\n\n'
          'إذا أردت مساعدة أعمق في نقطة محددة '
          '(فكرة بحثية، تحرير، تحليل بيانات، عرض تقديمي...) '
          'اذكرها وسأتولى ذلك مباشرة.',
      'Regarding your question:\n\n'
          '**$topic**\n\n'
          'You can start with a simple plan:\n'
          '1. Define the research problem precisely.\n'
          '2. Formulate one measurable research question.\n'
          '3. Review 5–10 recent studies in the same field.\n'
          '4. Choose a methodology (quantitative/qualitative/mixed).\n'
          '5. Discuss the idea with your supervisor.\n\n'
          'If you want deeper help on a specific point '
          '(research idea, editing, data analysis, presentation...) '
          'mention it and I will handle it directly.',
    );
  }

  AdvisorAgentId _agentIdForGoal(AcademicQueryGoal goal) {
    return switch (goal) {
      AcademicQueryGoal.researchIdea => AdvisorAgentId.researchIdea,
      AcademicQueryGoal.thesisTitles ||
      AcademicQueryGoal.researchQuestion ||
      AcademicQueryGoal.summarize =>
        AdvisorAgentId.thesisPlanning,
      AcademicQueryGoal.supervisor => AdvisorAgentId.supervisorMatch,
      AcademicQueryGoal.thesisWriting => AdvisorAgentId.thesisWriter,
      AcademicQueryGoal.literatureReview => AdvisorAgentId.literatureReview,
      AcademicQueryGoal.citations => AdvisorAgentId.citations,
      AcademicQueryGoal.editing => AdvisorAgentId.academicEditing,
      AcademicQueryGoal.dataAnalysis => AdvisorAgentId.dataAnalysis,
      AcademicQueryGoal.presentation => AdvisorAgentId.presentations,
      AcademicQueryGoal.simulation => AdvisorAgentId.researchSimulation,
      AcademicQueryGoal.general => AdvisorAgentId.general,
    };
  }

  Iterable<String> _extractKeywords(String text) {
    final words = text
        .toLowerCase()
        .split(RegExp(r'[\s,،.؛;:!؟?]+'))
        .where((w) => w.length >= 4)
        .toList();

    final counts = <String, int>{};
    for (final word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key);
  }
}
