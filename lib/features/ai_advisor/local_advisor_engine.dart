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
        sections.add('## ${agent.shortLabel}\n$section');
      } else {
        sections.add(section);
      }
    }

    if (plan.isMultiAgent) {
      return 'رد مجمّع من ${plan.allAgents.length} وكلاء متخصصين:\n\n'
          '${sections.join('\n\n')}';
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
      buffer.writeln('نعم، يمكن العمل على هذه الفكرة — إليك تحليلاً مباشراً:\n');
    } else {
      buffer.writeln('تحليل فكرتك البحثية:\n');
    }

    buffer.writeln('**الموضوع:** $topic\n');
    buffer.writeln('**لماذا تستحق الدراسة؟**');
    buffer.writeln(
      'الموضوع يرتبط بتحدٍّ أكاديمي/تطبيقي واضح، ويمكن قياسه أو تحليله منهجياً '
      'حسب تخصصك والسياق المحلي.',
    );
    buffer.writeln('\n**نقاط القوة المحتملة:**');
    buffer.writeln('• موضوع معاصر وله أدبيات بحثية متنامية.');
    buffer.writeln('• قابل لصياغة أهداف وأسئلة محددة.');
    buffer.writeln('• يمكن ربطه بتطبيق عملي أو توصيات للمؤسسات.');

    buffer.writeln('\n**تحديات يجب انتباهك لها:**');
    buffer.writeln('• تحديد مجتمع الدراسة وعينة واضحة.');
    buffer.writeln('• اختيار منهجية مناسبة (كمي/نوعي/مختلط).');
    buffer.writeln('• تجنب العنوان الواسع جداً — ضيّق النطاق.');

    buffer.writeln('\n**أسئلة بحثية مقترحة:**');
    final questions = [
      'ما أثر $topic على ... في السياق المحلي؟',
      'كيف يمكن تحسين تطبيق $topic باستخدام منهجية ...؟',
      'ما العوامل المؤثرة في ... المرتبطة بـ$topic؟',
    ];
    for (var i = 0; i < questions.length; i++) {
      buffer.writeln('${i + 1}. ${questions[i]}');
    }

    buffer.writeln('\n**منهجية مناسبة:**');
    if (_any(lower, ['تجريب', 'قياس', 'استبيان', 'إحصاء'])) {
      buffer.writeln('منهج كمي (استبيان/تجربة) مع تحليل إحصائي.');
    } else if (_any(lower, ['مقابلة', 'دراسة حالة', 'نوعي'])) {
      buffer.writeln('منهج نوعي (مقابلات/دراسة حالة) مع تحليل موضوعاتي.');
    } else {
      buffer.writeln('ابدأ بمنهج مختلط أو كمي حسب قابلية جمع البيانات.');
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
        buffer.writeln('\n**أفكار مشابهة في AcadeGate:**');
        for (final match in matches) {
          buffer.writeln(
            '• ${match.item.title} (${match.item.provider}) — توافق ${match.score}%',
          );
        }
      }
    }

    buffer.writeln(
      '\n**الخطوة التالية:** اختر سؤالاً بحثياً واحداً وحدد المتغيرات، '
      'ثم ناقشه مع مشرفك أو استخدم المطابقة الذكية.',
    );

    return buffer.toString();
  }

  bool _any(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  String _thesisWriter(String message) {
    final topic = extractAdvisorTopic(message) ?? 'موضوع بحثك';
    return 'مسودة مقدمة أكاديمية (أسلوب طبيعي) عن **$topic**:\n\n'
        'شهدت السنوات الأخيرة تزايد الاهتمام البحثي بـ$topic، '
        'وانعكس ذلك في تعدد الدراسات التي حاولت فهم أبعاده بطرق منهجية مختلفة. '
        'ومع ذلك، ما تزال هناك فجوات معرفية تتطلب مزيداً من التحليل في السياق المحلي.\n\n'
        'تهدف هذه الرسالة إلى ... [أضف هدفك ومتغيراتك].\n'
        'وتسعى إلى الإجابة عن السؤال: ... [أضف سؤالك البحثي].\n\n'
        'نصيحة: أضف إحصائية أو مرجعاً حديثاً لجعل المقدمة أقوى.';
  }

  String _researchSimulation(String message) {
    final topic = extractAdvisorTopic(message) ?? 'المتغير المدروس';
    return '⚠️ نتائج افتراضية للتدريب فقط — ليست بيانات حقيقية.\n\n'
        '**الفرضيات:**\n'
        'H1: يوجد علاقة دالة بين $topic والأداء.\n'
        'H0: لا توجد علاقة ذات دلالة.\n\n'
        '**جدول نتائج نموذجي (n=120):**\n'
        '| المجموعة | المتوسط | الانحراف المعياري | t | p |\n'
        '|---|---:|---:|---:|---:|\n'
        '| تجريبية | 4.2 | 0.6 | 2.31 | 0.023 |\n'
        '| ضابطة | 3.7 | 0.7 | — | — |\n\n'
        '**تفسير:** الفرق ذو دلالة إحصائية عند مستوى 0.05. '
        'فعّل AcadeGate AI السحابي لمحاكاة أدق حسب منهجيتك.';
  }

  String _literatureReview(String message) {
    final topic = extractAdvisorTopic(message) ?? 'الموضوع';
    return '**تحليل أدبي مبدئي لموضوع: $topic**\n\n'
        '1. **المحور النظري:** تعريف المفاهيم الأساسية وتطورها.\n'
        '2. **الدراسات السابقة:** تصنيف حسب المنهج (كمي/نوعي) والنتائج.\n'
        '3. **نقد منهجي:** حجم العينة، أدوات القياس، قابلية التعميم.\n'
        '4. **الفجوة البحثية:** ما الذي لم يُغطَّ بعد في السياق المحلي؟\n'
        '5. **إطار نظري مقترح:** ربط المتغيرات المستقلة والتابعة.\n\n'
        'الصق عنوان الورقة أو ملخصها للحصول على تحليل أعمق.';
  }

  String _citations(String message) {
    return '**تنظيم مراجع (مثال APA):**\n\n'
        'داخل النص: (Smith, 2020)\n\n'
        'قائمة المراجع:\n'
        'Smith, J. (2020). Title of article. *Journal Name*, 12(3), 45-60.\n\n'
        'أرسل قائمة مراجعك غير المرتبة وسأعيد تنسيقها '
        '(APA / IEEE / Chicago / Harvard).';
  }

  String _academicEditing(String message) {
    final text = message
        .replaceFirst(RegExp(r'حرّر|تحرير|تدقيق', caseSensitive: false), '')
        .replaceFirst(RegExp(r'هذا النص[:\s]*', caseSensitive: false), '')
        .trim();

    if (text.length < 15) {
      return 'الصق النص المراد تحريره بعد كلمة «حرّر» لأعيد صياغته أكاديمياً.';
    }

    return '**نسخة محسّنة (مبدئية):**\n'
        'تتناول الدراسة أثر ${text.length > 40 ? '...' : text} '
        'من منظور أكاديمي منهجي.\n\n'
        '**ملاحظات تحريرية:**\n'
        '• استبدل العبارات العامة بمصطلحات دقيقة.\n'
        '• اربط الجمل بأدوات انتقال منطقية.\n'
        '• حدّد المتغيرات والمجتمع بوضوح.\n\n'
        'فعّل الوضع السحابي لتحرير كامل للنص المرفق.';
  }

  String _dataAnalysis(String message) {
    final topic = extractAdvisorTopic(message) ?? 'بيانات الاستبيان';
    return '**خطة تحليل مقترحة لـ$topic:**\n\n'
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
        '```';
  }

  String _presentations(String message) {
    final topic = extractAdvisorTopic(message) ?? 'رسالتك';
    return '**هيكل عرض مناقشة (15 دقيقة) — $topic:**\n\n'
        '1. العنوان والباحث (1 د)\n'
        '2. المشكلة والأهمية (2 د)\n'
        '3. الأهداف والأسئلة (1 د)\n'
        '4. الإطار النظري المختصر (3 د)\n'
        '5. المنهجية (3 د)\n'
        '6. النتائج الرئيسية (3 د)\n'
        '7. الخاتمة والتوصيات (2 د)\n\n'
        '**أسئلة متوقعة:** المنهجية، حجم العينة، حدود الدراسة، التطبيق العملي.';
  }

  Future<String> respond({
    required String message,
    required AdvisorIntent intent,
  }) async {
    final plan = AdvisorRouter.instance.route(message);
    return respondToAgents(message: message, plan: plan);
  }

  String _suggestTitles(String message, ParsedAcademicQuery parsed) {
    final topic = parsed.hasClearSubject ? parsed.subject : 'مجال بحثك';
    final templates = [
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

    final buffer =
        StringBuffer('إليك 10 عناوين مقترحة لرسالة في **$topic**:\n\n');
    for (var i = 0; i < templates.length; i++) {
      buffer.writeln('${i + 1}. ${templates[i]}');
    }
    buffer.writeln(
      '\nنصيحة: اختر عنواناً محدداً يحدد المجتمع، المنهجية، والمتغيرات بوضوح.',
    );
    return buffer.toString();
  }

  String _researchIdeaSync(String message, ParsedAcademicQuery parsed) {
    final topic = parsed.hasClearSubject ? parsed.subject : message.trim();
    return 'صياغات لسؤال بحثي حول **$topic**:\n\n'
        '1. ما أثر $topic على النتائج في السياق المحلي؟\n'
        '2. كيف يمكن قياس تطبيق $topic منهجياً؟\n'
        '3. ما العوامل المؤثرة في نجاح $topic؟';
  }

  String _toResearchQuestion(String message, ParsedAcademicQuery parsed) {
    final idea = parsed.hasClearSubject ? parsed.subject : parsed.rawMessage;
    if (idea.length < 4) {
      return _researchIdeaSync(message, parsed);
    }

    final questions = [
      'ما أثر $idea على النتائج البحثية في السياق المحلي؟',
      'كيف يمكن تحسين $idea باستخدام منهجية علمية قابلة للقياس؟',
      'ما العوامل المؤثرة في نجاح تطبيق $idea وفقاً للأدبيات الحديثة؟',
      'إلى أي مدى يرتبط $idea بتحسين الأداء وفق دراسة ميدانية؟',
      'ما الفروق ذات الدلالة الإحصائية في $idea بين المجموعات المدروسة؟',
    ];

    final buffer = StringBuffer('صياغات مقترحة لسؤال بحثي حول **$idea**:\n\n');
    for (var i = 0; i < questions.length; i++) {
      buffer.writeln('${i + 1}. ${questions[i]}');
    }
    buffer.writeln(
      '\nاختر سؤالاً واحداً ثم حدّد المتغيرات المستقلة والتابعة والمنهجية.',
    );
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
        return '**ملخص مبدئي لموضوع: ${parsed.subject}**\n\n'
            '• يمكن دراسته أكاديمياً بتحديد مجتمع ومنهجية واضحة.\n'
            '• اقترح البدء بسؤال بحثي واحد محدد ثم مراجعة الأدبيات.\n'
            '• إذا لديك نص كامل، أرسله وسألخّصه بتفصيل أكبر.';
      }
    }

    final sentences = text
        .split(RegExp(r'[.!؟\n]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 8)
        .toList();

    final keywords = _extractKeywords(text).take(6).toList();

    final buffer = StringBuffer('**ملخص منظم**\n\n');
    buffer.writeln('• الهدف: ${sentences.isNotEmpty ? sentences.first : text}');
    if (sentences.length > 1) {
      buffer.writeln('• المنهج/الإجراء: ${sentences[1]}');
    }
    if (sentences.length > 2) {
      buffer.writeln('• النتائج/الاستنتاج: ${sentences.last}');
    }
    if (keywords.isNotEmpty) {
      buffer.writeln('\n**كلمات مفتاحية:** ${keywords.join('، ')}');
    }
    buffer.writeln(
      '\nملاحظة: هذا تلخيص أولي — راجع الصياغة قبل إدراجه في البحث.',
    );
    return buffer.toString();
  }

  Future<String> supervisorHint(String message) async {
    final parsed = AcademicQueryParser.parse(message);
    final profile = await AcademicProfileService.instance.loadProfile();
    final topic = parsed.hasClearSubject ? parsed.subject : parsed.rawMessage;

    if (profile == null || !profile.isComplete) {
      return 'بناءً على سؤالك عن المشرف، أكمل **ملفي الأكاديمي** '
          '(التخصص والاهتمام البحثي) لأعطيك مطابقة أدق.\n\n'
          'حتى ذلك الحين: ابحث عن مشرفين في تخصص **$topic** '
          'من قسم المشرفين أو المطابقة الذكية.';
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
      return 'لا توجد بيانات مشرفين كافية حالياً. جرّب لاحقاً أو تصفّح قسم المشرفين.';
    }

    final buffer = StringBuffer('أفضل المشرفين المقترحين');
    if (topic.length >= 3) {
      buffer.write(' لفكرتك في **$topic**');
    }
    buffer.writeln(':\n');

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final supervisor = match.item;
      buffer.writeln(
        '${i + 1}. **${supervisor.name}** — توافق ${match.score}%',
      );
      buffer.writeln('   ${supervisor.university} • ${supervisor.speciality}');
      if (match.reasons.isNotEmpty) {
        buffer.writeln('   • ${match.reasons.join(' • ')}');
      }
      buffer.writeln();
    }

    buffer.writeln(
      'يمكنك فتح قسم المشرفين أو المطابقة الذكية لمزيد من التفاصيل.',
    );
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
    return 'بخصوص سؤالك:\n\n'
        '**$topic**\n\n'
        'يمكنك البدء بخطة بسيطة:\n'
        '1. حدّد المشكلة البحثية بدقة.\n'
        '2. اصنع سؤالاً بحثياً واحداً قابلاً للقياس.\n'
        '3. راجع 5-10 دراسات حديثة في نفس المجال.\n'
        '4. اختر المنهجية (كمي/نوعي/مختلط).\n'
        '5. ناقش الفكرة مع مشرفك.\n\n'
        'إذا أردت مساعدة أعمق في نقطة محددة '
        '(فكرة بحثية، تحرير، تحليل بيانات، عرض تقديمي...) '
        'اذكرها وسأتولى ذلك مباشرة.';
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
