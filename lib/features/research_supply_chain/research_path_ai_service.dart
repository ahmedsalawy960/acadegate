import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_service.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../profile/academic_profile.dart';
import 'research_supply_chain_models.dart';

class ResearchPathAiService {
  ResearchPathAiService._();

  static final ResearchPathAiService instance = ResearchPathAiService._();

  Future<ResearchPathAiInsight> enrich({
    required ResearchSupplyBundle bundle,
    AcademicProfile? profile,
  }) async {
    if (!GeminiAdvisorClient.isConfigured) {
      return _localInsight(
        bundle,
        profile,
        note: appTr(
          'فعّل AcadeGate AI (مفتاح Gemini) لتحليل أعمق.',
          'Enable AcadeGate AI (Gemini key) for deeper analysis.',
        ),
      );
    }

    final headers = _sectionHeaders;
    final systemPrompt = LocaleService.instance.isEnglish
        ? '''
You are an academic advisor on the AcadeGate platform. Analyze a suggested research bundle for a researcher and connect it to their academic profile and real platform data.

Strict rules:
- Reply in clear, simple English only.
- Do not invent names or institutions not present in the supplied data.
- If a bundle item is missing, suggest a practical alternative within the platform (browse, register, request).
- Use these exact headings in your reply:

${headers.analysis}
(One or two paragraphs linking specialization and interest to each selected item)

${headers.plan}
(4–6 numbered stages: problem definition, literature review, methodology, data/lab collection, writing, review)

${headers.next}
(One or two practical sentences for the researcher today)
'''
        : '''
أنت مستشار أكاديمي في منصة AcadeGate. مهمتك تحليل حزمة بحث مقترحة لباحث عربي وربطها بملفه الأكاديمي وبيانات المنصة الحقيقية.

قواعد صارمة:
- أجب بالعربية الفصحى المبسطة فقط.
- لا تخترع أسماء أو جهات غير موجودة في البيانات المرسلة.
- إن كان عنصراً ناقصاً في الحزمة، اقترح بديلاً عملياً من داخل المنصة (تصفح، تسجيل، طلب).
- استخدم العناوين التالية بالضبط في ردك:

${headers.analysis}
(فقرة أو فقرتان تربط التخصص والاهتمام بكل عنصر مختار)

${headers.plan}
(مراحل مرقّمة 4–6: تحديد المشكلة، مراجعة أدبيات، منهجية، جمع بيانات/مختبر، كتابة، مراجعة)

${headers.next}
(جملة أو جملتان عمليتان للباحث اليوم)
''';

    final userMessage =
        '${appTr('بيانات الباحث والحزمة المقترحة:\n\n', 'Researcher profile and suggested bundle data:\n\n')}'
        '${_buildContext(bundle, profile)}';

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      maxOutputTokens: 4096,
    );

    if (result.isSuccess && result.text != null) {
      final parsed = _parseSections(result.text!);
      return ResearchPathAiInsight(
        analysis: parsed.analysis,
        researchPlan: parsed.plan,
        nextStep: parsed.nextStep,
        fromGemini: true,
        modelUsed: result.modelUsed,
      );
    }

    return _localInsight(
      bundle,
      profile,
      note: result.error ??
          appTr('تعذر الاتصال بالذكاء الاصطناعي', 'Could not reach AI'),
    );
  }

  ({String analysis, String plan, String next}) get _sectionHeaders {
    if (LocaleService.instance.isEnglish) {
      return (
        analysis: '## Why this bundle?',
        plan: '## Suggested research plan',
        next: '## Next step',
      );
    }
    return (
      analysis: '## لماذا هذه الحزمة؟',
      plan: '## خطة البحث المقترحة',
      next: '## الخطوة التالية',
    );
  }

  String _buildContext(ResearchSupplyBundle bundle, AcademicProfile? profile) {
    final buffer = StringBuffer();
    final listSep = L10nLookup.listSeparator();

    buffer.writeln(
      appTr(
        'موضوع البحث: ${bundle.topic}',
        'Research topic: ${bundle.topic}',
      ),
    );
    buffer.writeln(
      appTr(
        'توافق عام: ${bundle.overallScore}%',
        'Overall match: ${bundle.overallScore}%',
      ),
    );

    if (profile != null) {
      buffer.writeln(appTr('--- الملف الأكاديمي ---', '--- Academic profile ---'));
      buffer.writeln(appTr('الاسم: ${profile.fullName}', 'Name: ${profile.fullName}'));
      buffer.writeln(
        appTr('الجامعة: ${profile.university}', 'University: ${profile.university}'),
      );
      buffer.writeln(appTr('الدرجة: ${profile.degree}', 'Degree: ${profile.degree}'));
      buffer.writeln(
        appTr('التخصص: ${profile.specialization}', 'Specialization: ${profile.specialization}'),
      );
      buffer.writeln(
        appTr('الاهتمام: ${profile.researchInterest}', 'Interest: ${profile.researchInterest}'),
      );
      buffer.writeln(
        appTr('المنهجية: ${profile.methodology}', 'Methodology: ${profile.methodology}'),
      );
      buffer.writeln(
        appTr('اللغة: ${profile.preferredLanguage}', 'Language: ${profile.preferredLanguage}'),
      );
      if (profile.skills.isNotEmpty) {
        buffer.writeln(
          appTr(
            'المهارات: ${profile.skills.join(listSep)}',
            'Skills: ${profile.skills.join(listSep)}',
          ),
        );
      }
    }

    buffer.writeln(appTr('--- عناصر الحزمة ---', '--- Bundle items ---'));

    final idea = bundle.idea;
    if (idea != null) {
      buffer.writeln(
        appTr(
          'فكرة (${idea.score}%): ${idea.item.title} — ${idea.item.details}',
          'Idea (${idea.score}%): ${idea.item.title} — ${idea.item.details}',
        ),
      );
    } else {
      buffer.writeln(
        appTr(
          'فكرة: غير متوفرة في المنصة حالياً',
          'Idea: not available on the platform right now',
        ),
      );
    }

    final supervisor = bundle.supervisor;
    if (supervisor != null) {
      buffer.writeln(
        appTr(
          'مشرف (${supervisor.score}%): ${supervisor.item.name} — '
          '${supervisor.item.speciality} @ ${supervisor.item.university}',
          'Supervisor (${supervisor.score}%): ${supervisor.item.name} — '
          '${supervisor.item.speciality} @ ${supervisor.item.university}',
        ),
      );
    } else {
      buffer.writeln(appTr('مشرف: غير متوفر', 'Supervisor: not available'));
    }

    final lab = bundle.lab;
    if (lab != null) {
      buffer.writeln(
        appTr(
          'مختبر (${lab.score}%): ${lab.item.name} — ${lab.item.equipment}',
          'Lab (${lab.score}%): ${lab.item.name} — ${lab.item.equipment}',
        ),
      );
    } else {
      buffer.writeln(appTr('مختبر: غير متوفر', 'Lab: not available'));
    }

    if (bundle.storeCategory != null) {
      buffer.writeln(
        appTr(
          'قسم المتجر: ${L10nLookup.storeCategoryTitle(bundle.storeCategory!.id)}',
          'Store section: ${L10nLookup.storeCategoryTitle(bundle.storeCategory!.id)}',
        ),
      );
    }
    if (bundle.products.isNotEmpty) {
      buffer.writeln(appTr('منتجات مقترحة:', 'Suggested products:'));
      for (final p in bundle.products) {
        buffer.writeln(
          appTr(
            '  • ${p.name} (${p.price} ج.م) — ${p.category}',
            '  • ${p.name} (${p.price} EGP) — ${p.category}',
          ),
        );
      }
    }

    final expert = bundle.writingExpert;
    if (expert != null) {
      buffer.writeln(
        appTr(
          'كاتب (${expert.score}%): ${expert.item.name} — ${expert.item.speciality}',
          'Writer (${expert.score}%): ${expert.item.name} — ${expert.item.speciality}',
        ),
      );
    } else {
      buffer.writeln(
        appTr('كاتب أكاديمي: غير متوفر', 'Academic writer: not available'),
      );
    }

    return buffer.toString();
  }

  ({String analysis, String plan, String? nextStep}) _parseSections(String text) {
    final headers = _sectionHeaders;

    String extractBetween(String start, String? end) {
      final startIdx = text.indexOf(start);
      if (startIdx < 0) return '';
      final contentStart = startIdx + start.length;
      final endIdx = end == null ? text.length : text.indexOf(end, contentStart);
      if (endIdx < 0) return text.substring(contentStart).trim();
      return text.substring(contentStart, endIdx).trim();
    }

    var analysis = extractBetween(headers.analysis, headers.plan);
    var plan = extractBetween(headers.plan, headers.next);
    var nextStep = extractBetween(headers.next, null);

    if (analysis.isEmpty && plan.isEmpty) {
      const fallbackHeaders = (
        analysis: '## لماذا هذه الحزمة؟',
        plan: '## خطة البحث المقترحة',
        next: '## الخطوة التالية',
      );
      const englishHeaders = (
        analysis: '## Why this bundle?',
        plan: '## Suggested research plan',
        next: '## Next step',
      );
      final alt = LocaleService.instance.isEnglish ? fallbackHeaders : englishHeaders;
      analysis = extractBetween(alt.analysis, alt.plan);
      plan = extractBetween(alt.plan, alt.next);
      nextStep = extractBetween(alt.next, null);
    }

    if (analysis.isEmpty && plan.isEmpty) {
      return (analysis: text.trim(), plan: '', nextStep: null);
    }

    return (
      analysis: analysis.isEmpty ? text.trim() : analysis,
      plan: plan,
      nextStep: nextStep.isEmpty ? null : nextStep,
    );
  }

  ResearchPathAiInsight _localInsight(
    ResearchSupplyBundle bundle,
    AcademicProfile? profile, {
    String? note,
  }) {
    final analysis = StringBuffer();
    final storeLabel = bundle.storeCategory != null
        ? L10nLookup.storeCategoryTitle(bundle.storeCategory!.id)
        : appTr('المتجر', 'the store');

    analysis.writeln(
      appTr(
        'بُنيت هذه الحزمة من بيانات منصة AcadeGate وفق تخصصك '
        '${profile?.specialization.isNotEmpty == true ? '«${profile!.specialization}»' : 'وموضوع بحثك'}.',
        'This bundle was built from AcadeGate platform data based on your '
        '${profile?.specialization.isNotEmpty == true ? '"${profile!.specialization}"' : 'research topic'}.',
      ),
    );

    if (bundle.idea != null) {
      analysis.writeln(
        appTr(
          '• الفكرة «${bundle.idea!.item.title}» تتوافق مع اهتمامك (${bundle.idea!.score}%).',
          '• Idea "${bundle.idea!.item.title}" matches your interest (${bundle.idea!.score}%).',
        ),
      );
    }
    if (bundle.supervisor != null) {
      analysis.writeln(
        appTr(
          '• المشرف ${bundle.supervisor!.item.name} قريب من مجالك (${bundle.supervisor!.score}%).',
          '• Supervisor ${bundle.supervisor!.item.name} is close to your field (${bundle.supervisor!.score}%).',
        ),
      );
    }
    if (bundle.lab != null) {
      analysis.writeln(
        appTr(
          '• مختبر ${bundle.lab!.item.name} يخدم احتياجاتك التجريبية.',
          '• Lab ${bundle.lab!.item.name} serves your experimental needs.',
        ),
      );
    }
    if (bundle.products.isNotEmpty) {
      analysis.writeln(
        appTr(
          '• ${bundle.products.length} منتج/ات من $storeLabel.',
          '• ${bundle.products.length} product(s) from $storeLabel.',
        ),
      );
    }
    if (bundle.writingExpert != null) {
      analysis.writeln(
        appTr(
          '• ${bundle.writingExpert!.item.name} لدعم الكتابة أو الإحصاء.',
          '• ${bundle.writingExpert!.item.name} for writing or statistics support.',
        ),
      );
    }
    if (note != null && note.isNotEmpty) {
      analysis.writeln('\n${appTr('ملاحظة:', 'Note:')} $note');
    }

    final plan = StringBuffer()
      ..writeln(appTr(
        '1. حدّد سؤال البحث وصياغة المشكلة بدقة.',
        '1. Define your research question and problem statement clearly.',
      ))
      ..writeln(appTr(
        '2. راجع الأدبيات عبر الفكرة المقترحة أو المساعد الأكاديمي.',
        '2. Review literature via the suggested idea or academic assistant.',
      ))
      ..writeln(appTr(
        '3. تواصل مع المشرف المقترح لاعتماد المنهجية.',
        '3. Contact the suggested supervisor to approve methodology.',
      ))
      ..writeln(appTr(
        '4. احجز المختبر واطلب المواد من المتجر إن لزم.',
        '4. Book the lab and order store supplies if needed.',
      ))
      ..writeln(appTr(
        '5. اطلب دعم الكتابة/الإحصاء حسب مرحلة رسالتك.',
        '5. Request writing/statistics support for your thesis stage.',
      ))
      ..writeln(appTr(
        '6. راجع المسودات قبل التسليم النهائي.',
        '6. Review drafts before final submission.',
      ));

    return ResearchPathAiInsight(
      analysis: analysis.toString().trim(),
      researchPlan: plan.toString().trim(),
      nextStep: bundle.idea != null
          ? appTr(
              'افتح تفاصيل الفكرة المقترحة وناقشها مع مشرفك.',
              'Open the suggested idea details and discuss it with your supervisor.',
            )
          : appTr(
              'أكمل ملفك الأكاديمي أو وسّع وصف موضوع البحث لمطابقة أدق.',
              'Complete your academic profile or expand your research topic for better matching.',
            ),
      fromGemini: false,
      error: note,
    );
  }
}
