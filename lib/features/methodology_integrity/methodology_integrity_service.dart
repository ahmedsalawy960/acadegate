import 'dart:convert';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_service.dart';
import '../ai_advisor/advisor_attachment.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../profile/academic_profile.dart';
import 'methodology_integrity_models.dart';

class MethodologyIntegrityService {
  MethodologyIntegrityService._();

  static final MethodologyIntegrityService instance =
      MethodologyIntegrityService._();

  bool get isCloudEnabled => GeminiAdvisorClient.isAvailable;

  Future<MethodologyIntegrityReport> analyze({
    required MethodologyIntegrityInput input,
    AcademicProfile? profile,
  }) async {
    final local = _localAnalyze(input, profile);

    if (!isCloudEnabled) {
      return local.copyWith(
        note: appTr(
          'التحليل المحلي فقط — سجّل الدخول أو فعّل الذكاء السحابي لتحليل أعمق.',
          'Local analysis only — sign in or enable cloud AI for deeper checks.',
        ),
      );
    }

    final cloud = await _cloudAnalyze(input, profile, local);
    return cloud ?? local;
  }

  MethodologyIntegrityReport _localAnalyze(
    MethodologyIntegrityInput input,
    AcademicProfile? profile,
  ) {
    final issues = <IntegrityIssue>[];
    final strengths = <String>[];
    final text = input.methodologyText.trim().toLowerCase();
    final stated = input.statedMethodology.trim();

    if (text.length < 80) {
      issues.add(
        IntegrityIssue(
          severity: IntegritySeverity.high,
          category: IntegrityIssueCategory.documentation,
          title: appTr('فصل المنهجية قصير جداً', 'Methodology section is too short'),
          description: appTr(
            'النص المدخل لا يكفي لتقييم سلامة المنهجية أو اكتشاف التناقضات.',
            'The entered text is insufficient to assess methodological integrity or detect inconsistencies.',
          ),
          suggestion: appTr(
            'أضف وصفاً تفصيلياً للتصميم، العينة، أدوات الجمع، وخطوات التحليل.',
            'Add detailed design, sample, data collection tools, and analysis steps.',
          ),
        ),
      );
    }

    if (input.researchQuestion.trim().isEmpty) {
      issues.add(
        IntegrityIssue(
          severity: IntegritySeverity.medium,
          category: IntegrityIssueCategory.alignment,
          title: appTr('سؤال البحث غير محدد', 'Research question not specified'),
          description: appTr(
            'بدون سؤال بحث واضح يصعب الحكم على ملاءمة المنهجية.',
            'Without a clear research question, methodological fit cannot be judged.',
          ),
          suggestion: appTr(
            'اذكر سؤال/فرضية البحث قبل فحص المنهجية.',
            'State your research question/hypothesis before checking methodology.',
          ),
        ),
      );
    }

    final isQuant = stated.contains('كمي') || stated.toLowerCase().contains('quant');
    final isQual = stated.contains('نوعي') || stated.toLowerCase().contains('qual');
    final isMixed = stated.contains('مختلط') || stated.toLowerCase().contains('mixed');

    final quantSignals = _countSignals(text, const [
      'استبانة',
      'questionnaire',
      'survey',
      'spss',
      'عينة عشوائية',
      'random sample',
      'تحليل إحصائي',
      'statistical',
      'معامل',
      'correlation',
      'regression',
    ]);
    final qualSignals = _countSignals(text, const [
      'مقابلة',
      'interview',
      'تركيز',
      'focus group',
      'تحليل محتوى',
      'content analysis',
      'موضوعي',
      'thematic',
      'ظاهرة',
      'phenomen',
    ]);

    if (isQuant && qualSignals > quantSignals + 1) {
      issues.add(
        IntegrityIssue(
          severity: IntegritySeverity.high,
          category: IntegrityIssueCategory.alignment,
          title: appTr(
            'تعارض بين المنهجية المعلنة والإجراءات',
            'Stated methodology conflicts with procedures',
          ),
          description: appTr(
            'أعلنت منهجية كمية لكن الوصف يشير بقوة لإجراءات نوعية.',
            'You declared a quantitative approach but the description strongly suggests qualitative procedures.',
          ),
          suggestion: appTr(
            'وحّد التصنيف المنهجي مع أدوات الجمع والتحليل، أو غيّر التصنيف إلى مختلط.',
            'Align your methodological label with collection/analysis tools, or switch to mixed methods.',
          ),
        ),
      );
    }

    if (isQual && quantSignals > qualSignals + 1) {
      issues.add(
        IntegrityIssue(
          severity: IntegritySeverity.high,
          category: IntegrityIssueCategory.alignment,
          title: appTr(
            'تعارض بين المنهجية المعلنة والإجراءات',
            'Stated methodology conflicts with procedures',
          ),
          description: appTr(
            'أعلنت منهجية نوعية لكن الوصف يشير لإجراءات كمية/statistical.',
            'You declared qualitative methods but the description suggests quantitative/statistical procedures.',
          ),
          suggestion: appTr(
            'برّر استخدام الأدوات الكمية ضمن إطار نوعي أو عدّل التصنيف المنهجي.',
            'Justify quantitative tools within a qualitative frame or revise the methodological label.',
          ),
        ),
      );
    }

    if ((isQuant || isMixed) &&
        !_mentionsAny(text, ['عينة', 'sample', 'مجتمع', 'population'])) {
      issues.add(
        IntegrityIssue(
          severity: IntegritySeverity.medium,
          category: IntegrityIssueCategory.sampling,
          title: appTr('العينة غير موصوفة', 'Sampling not described'),
          description: appTr(
            'المنهج الكمي/المختلط يتطلب توضيح المجتمع والعينة وآلية الاختيار.',
            'Quantitative/mixed designs require population, sample, and selection procedure.',
          ),
          suggestion: appTr(
            'أضف حجم العينة، معايير الانضمام، وطريقة الاختيار.',
            'Add sample size, inclusion criteria, and selection method.',
          ),
        ),
      );
    }

    if (_mentionsAny(text, const [
      'كما ورد في',
      'as described in',
      'نفس المنهجية',
      'same methodology',
      'نسخ من',
      'copied from',
      'بحسب الدراسة',
      'without modification',
      'دون تعديل',
    ])) {
      issues.add(
        IntegrityIssue(
          severity: IntegritySeverity.high,
          category: IntegrityIssueCategory.plagiarism,
          title: appTr(
            'مؤشرات انتحال منهجي محتملة',
            'Possible methodological plagiarism indicators',
          ),
          description: appTr(
            'النص يحتوي عبارات قد تدل على نقل المنهجية دون تكييف مع سياق بحثك.',
            'The text contains phrases that may indicate copying methodology without adapting it to your study.',
          ),
          suggestion: appTr(
            'أعد صياغة المنهجية بما يناسب سؤال بحثك، مجتمعك، وأدواتك مع الاستشهاد بالمصادر.',
            'Rewrite methodology for your question, population, and tools while citing sources.',
          ),
        ),
      );
    }

    if (!_mentionsAny(text, const [
      'أخلاق',
      'ethic',
      'موافقة',
      'consent',
      'إذن',
      'permission',
      'سرية',
      'confidential',
    ])) {
      issues.add(
        IntegrityIssue(
          severity: IntegritySeverity.low,
          category: IntegrityIssueCategory.ethics,
          title: appTr('لم تُذكر الأخلاقيات البحثية', 'Research ethics not mentioned'),
          description: appTr(
            'لم يظهر ذكر للموافقة أو السرية أو إجراءات الأخلاقيات.',
            'No mention of consent, confidentiality, or ethics procedures was found.',
          ),
          suggestion: appTr(
            'أضف فقرة موجزة عن الموافقة المستنيرة وسرية البيانات إن كان البحث يشمل بشراً.',
            'Add a brief section on informed consent and data confidentiality if human subjects are involved.',
          ),
        ),
      );
    }

    if (text.length >= 200) {
      strengths.add(
        appTr(
          'وصف منهجي يوفر أساساً للمراجعة التفصيلية.',
          'Methodological description provides a basis for detailed review.',
        ),
      );
    }
    if (input.researchQuestion.trim().length >= 20) {
      strengths.add(
        appTr(
          'سؤال البحث محدد ويساعد على تقييم الملاءمة.',
          'Research question is defined and helps assess fit.',
        ),
      );
    }
    if (profile != null && profile.methodology.isNotEmpty) {
      strengths.add(
        appTr(
          'الملف الأكاديمي يوفر سياقاً للتخصص (${profile.specialization}).',
          'Academic profile adds context for specialization (${profile.specialization}).',
        ),
      );
    }

    var score = 88;
    for (final issue in issues) {
      score -= switch (issue.severity) {
        IntegritySeverity.high => 18,
        IntegritySeverity.medium => 10,
        IntegritySeverity.low => 4,
      };
    }
    score = score.clamp(15, 95);

    return MethodologyIntegrityReport(
      integrityScore: score,
      summary: appTr(
        'فحص محلي أولي: ${issues.length} ملاحظة. '
        'الدرجة تقديرية وتحتاج مراجعة بشرية وليست حكماً نهائياً.',
        'Preliminary local check: ${issues.length} note(s). '
        'Score is indicative and needs human review — not a final verdict.',
      ),
      issues: issues,
      strengths: strengths,
      recommendations: _defaultRecommendations(),
      fromCloudAi: false,
    );
  }

  Future<MethodologyIntegrityReport?> _cloudAnalyze(
    MethodologyIntegrityInput input,
    AcademicProfile? profile,
    MethodologyIntegrityReport local,
  ) async {
    final system = LocaleService.instance.isEnglish
        ? '''
You are a research methodology integrity examiner on AcadeGate.
Detect methodological plagiarism, misalignment, weak justification, sampling flaws, and ethics gaps.
Do NOT accuse of academic misconduct without evidence — flag risks and suggest fixes.
Return ONLY valid JSON (no markdown) with keys:
integrityScore (0-100 integer),
summary (2-3 sentences),
issues (array of {severity: low|medium|high, category: alignment|plagiarism|sampling|ethics|analysis|documentation|other, title, description, suggestion}),
strengths (array of strings),
recommendations (array of strings, 3-5 items).
'''
        : '''
أنت فاحص سلامة المنهجية البحثية في منصة AcadeGate.
اكشف الانتحال المنهجي، عدم التوافق، ضعف التبرير، أخطاء العينة، وثغرات الأخلاقيات.
لا تُصدر حكماً بالانتحال دون مبرر — اذكر المخاطر واقترح التحسين.
أعد JSON صالحاً فقط (بدون markdown) بالمفاتيح:
integrityScore (عدد صحيح 0-100),
summary (2-3 جمل),
issues (مصفوفة من {severity: low|medium|high, category: alignment|plagiarism|sampling|ethics|analysis|documentation|other, title, description, suggestion}),
strengths (مصفوفة نصوص),
recommendations (مصفوفة 3-5 عناصر).
''';

    final user = StringBuffer()
      ..writeln(_buildContext(input, profile))
      ..writeln('\n--- ${appTr('نتائج الفحص المحلي', 'Local pre-check')} ---')
      ..writeln('Score: ${local.integrityScore}')
      ..writeln('Issues: ${local.issues.length}');

    if (input.hasPdfSource) {
      user.writeln(
        appTr(
          '\nملاحظة: مرفق PDF الأصلي للرسالة — راجع فصل المنهجية كاملاً في الملف.',
          '\nNote: Original thesis PDF attached — review the full methodology chapter in the file.',
        ),
      );
    }

    final attachments = <GeminiInlinePart>[];
    if (input.hasPdfSource) {
      attachments.add(
        GeminiInlinePart(
          mimeType: 'application/pdf',
          base64Data: base64Encode(input.pdfBytes!),
          fileName: input.pdfFileName ?? 'thesis.pdf',
        ),
      );
    }

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: system,
      userMessage: user.toString(),
      attachments: attachments,
      maxOutputTokens: 6144,
    );

    if (!result.isSuccess || result.text == null) return null;

    try {
      final json = _extractJson(result.text!);
      final map = jsonDecode(json) as Map<String, dynamic>;
      final issues = (map['issues'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => IntegrityIssue.fromMap(Map<String, dynamic>.from(e)))
          .where((i) => i.title.isNotEmpty)
          .toList();

      return MethodologyIntegrityReport(
        integrityScore: (map['integrityScore'] as num?)?.round().clamp(0, 100) ??
            local.integrityScore,
        summary: map['summary']?.toString() ?? local.summary,
        issues: issues.isEmpty ? local.issues : issues,
        strengths: _stringList(map['strengths']).isEmpty
            ? local.strengths
            : _stringList(map['strengths']),
        recommendations: _stringList(map['recommendations']).isEmpty
            ? local.recommendations
            : _stringList(map['recommendations']),
        fromCloudAi: true,
        modelUsed: result.modelUsed,
      );
    } catch (_) {
      return MethodologyIntegrityReport(
        integrityScore: local.integrityScore,
        summary: result.text!.trim(),
        issues: local.issues,
        strengths: local.strengths,
        recommendations: local.recommendations,
        fromCloudAi: true,
        modelUsed: result.modelUsed,
        note: appTr(
          'رد الذكاء الاصطناعي لم يُحلَّل كـ JSON — عُرض كنص.',
          'AI response could not be parsed as JSON — shown as text.',
        ),
      );
    }
  }

  String _buildContext(MethodologyIntegrityInput input, AcademicProfile? profile) {
    final b = StringBuffer();
    if (profile != null) {
      b.writeln(appTr('--- الملف الأكاديمي ---', '--- Academic profile ---'));
      b.writeln(appTr('التخصص: ${profile.specialization}', 'Specialization: ${profile.specialization}'));
      b.writeln(appTr('المنهجية في الملف: ${profile.methodology}', 'Profile methodology: ${profile.methodology}'));
      b.writeln(appTr('الاهتمام: ${profile.researchInterest}', 'Interest: ${profile.researchInterest}'));
    }
    b.writeln(appTr('عنوان البحث: ${input.thesisTitle}', 'Thesis title: ${input.thesisTitle}'));
    b.writeln(appTr('سؤال البحث: ${input.researchQuestion}', 'Research question: ${input.researchQuestion}'));
    b.writeln(appTr('المنهجية المعلنة: ${input.statedMethodology}', 'Stated methodology: ${input.statedMethodology}'));
    b.writeln(appTr('نص المنهجية:\n${input.methodologyText}', 'Methodology text:\n${input.methodologyText}'));
    if (input.population?.isNotEmpty == true) {
      b.writeln(appTr('المجتمع/العينة: ${input.population}', 'Population/sample: ${input.population}'));
    }
    if (input.dataCollection?.isNotEmpty == true) {
      b.writeln(appTr('جمع البيانات: ${input.dataCollection}', 'Data collection: ${input.dataCollection}'));
    }
    if (input.analysisApproach?.isNotEmpty == true) {
      b.writeln(appTr('التحليل: ${input.analysisApproach}', 'Analysis: ${input.analysisApproach}'));
    }
    return b.toString();
  }

  String _extractJson(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) return trimmed;
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return trimmed;
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  int _countSignals(String text, List<String> signals) {
    var count = 0;
    for (final signal in signals) {
      if (text.contains(signal.toLowerCase())) count++;
    }
    return count;
  }

  bool _mentionsAny(String text, List<String> terms) {
    return terms.any((t) => text.contains(t.toLowerCase()));
  }

  List<String> _defaultRecommendations() => [
        appTr(
          'قارن منهجيتك بدراسات مشابهة في تخصصك وبيّن الاختلافات الصريحة.',
          'Compare your methodology with similar studies in your field and state explicit differences.',
        ),
        appTr(
          'تأكد من توافق سؤال البحث → التصميم → العينة → الأدوات → التحليل.',
          'Ensure alignment: research question → design → sample → instruments → analysis.',
        ),
        appTr(
          'استشر مشرفك قبل اعتماد أي تعديل جوهري على المنهجية.',
          'Consult your supervisor before adopting any major methodological change.',
        ),
      ];
}

extension on MethodologyIntegrityReport {
  MethodologyIntegrityReport copyWith({String? note}) {
    return MethodologyIntegrityReport(
      integrityScore: integrityScore,
      summary: summary,
      issues: issues,
      strengths: strengths,
      recommendations: recommendations,
      fromCloudAi: fromCloudAi,
      modelUsed: modelUsed,
      note: note ?? this.note,
    );
  }
}
