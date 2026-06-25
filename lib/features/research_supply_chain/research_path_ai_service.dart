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
        note: 'فعّل AcadeGate AI (مفتاح Gemini) لتحليل أعمق.',
      );
    }

    final systemPrompt = '''
أنت مستشار أكاديمي في منصة AcadeGate. مهمتك تحليل حزمة بحث مقترحة لباحث عربي وربطها بملفه الأكاديمي وبيانات المنصة الحقيقية.

قواعد صارمة:
- أجب بالعربية الفصحى المبسطة فقط.
- لا تخترع أسماء أو جهات غير موجودة في البيانات المرسلة.
- إن كان عنصراً ناقصاً في الحزمة، اقترح بديلاً عملياً من داخل المنصة (تصفح، تسجيل، طلب).
- استخدم العناوين التالية بالضبط في ردك:

## لماذا هذه الحزمة؟
(فقرة أو فقرتان تربط التخصص والاهتمام بكل عنصر مختار)

## خطة البحث المقترحة
(مراحل مرقّمة 4–6: تحديد المشكلة، مراجعة أدبيات، منهجية، جمع بيانات/مختبر، كتابة، مراجعة)

## الخطوة التالية
(جملة أو جملتان عمليتان للباحث اليوم)
''';

    final userMessage =
        'بيانات الباحث والحزمة المقترحة:\n\n${_buildContext(bundle, profile)}';

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
      note: result.error ?? 'تعذر الاتصال بالذكاء الاصطناعي',
    );
  }

  String _buildContext(ResearchSupplyBundle bundle, AcademicProfile? profile) {
    final buffer = StringBuffer();

    buffer.writeln('موضوع البحث: ${bundle.topic}');
    buffer.writeln('توافق عام: ${bundle.overallScore}%');

    if (profile != null) {
      buffer.writeln('--- الملف الأكاديمي ---');
      buffer.writeln('الاسم: ${profile.fullName}');
      buffer.writeln('الجامعة: ${profile.university}');
      buffer.writeln('الدرجة: ${profile.degree}');
      buffer.writeln('التخصص: ${profile.specialization}');
      buffer.writeln('الاهتمام: ${profile.researchInterest}');
      buffer.writeln('المنهجية: ${profile.methodology}');
      buffer.writeln('اللغة: ${profile.preferredLanguage}');
      if (profile.skills.isNotEmpty) {
        buffer.writeln('المهارات: ${profile.skills.join('، ')}');
      }
    }

    buffer.writeln('--- عناصر الحزمة ---');

    final idea = bundle.idea;
    if (idea != null) {
      buffer.writeln(
        'فكرة (${idea.score}%): ${idea.item.title} — ${idea.item.details}',
      );
    } else {
      buffer.writeln('فكرة: غير متوفرة في المنصة حالياً');
    }

    final supervisor = bundle.supervisor;
    if (supervisor != null) {
      buffer.writeln(
        'مشرف (${supervisor.score}%): ${supervisor.item.name} — '
        '${supervisor.item.speciality} @ ${supervisor.item.university}',
      );
    } else {
      buffer.writeln('مشرف: غير متوفر');
    }

    final lab = bundle.lab;
    if (lab != null) {
      buffer.writeln(
        'مختبر (${lab.score}%): ${lab.item.name} — ${lab.item.equipment}',
      );
    } else {
      buffer.writeln('مختبر: غير متوفر');
    }

    if (bundle.storeCategory != null) {
      buffer.writeln('قسم المتجر: ${bundle.storeCategory!.title}');
    }
    if (bundle.products.isNotEmpty) {
      buffer.writeln('منتجات مقترحة:');
      for (final p in bundle.products) {
        buffer.writeln('  • ${p.name} (${p.price} ج.م) — ${p.category}');
      }
    }

    final expert = bundle.writingExpert;
    if (expert != null) {
      buffer.writeln(
        'كاتب (${expert.score}%): ${expert.item.name} — ${expert.item.speciality}',
      );
    } else {
      buffer.writeln('كاتب أكاديمي: غير متوفر');
    }

    return buffer.toString();
  }

  ({String analysis, String plan, String? nextStep}) _parseSections(String text) {
    const analysisHeader = '## لماذا هذه الحزمة؟';
    const planHeader = '## خطة البحث المقترحة';
    const nextHeader = '## الخطوة التالية';

    String extractBetween(String start, String? end) {
      final startIdx = text.indexOf(start);
      if (startIdx < 0) return '';
      final contentStart = startIdx + start.length;
      final endIdx = end == null ? text.length : text.indexOf(end, contentStart);
      if (endIdx < 0) return text.substring(contentStart).trim();
      return text.substring(contentStart, endIdx).trim();
    }

    final analysis = extractBetween(analysisHeader, planHeader);
    final plan = extractBetween(planHeader, nextHeader);
    final nextStep = extractBetween(nextHeader, null);

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
    analysis.writeln(
      'بُنيت هذه الحزمة من بيانات منصة AcadeGate وفق تخصصك '
      '${profile?.specialization.isNotEmpty == true ? '«${profile!.specialization}»' : 'وموضوع بحثك'}.',
    );

    if (bundle.idea != null) {
      analysis.writeln(
        '• الفكرة «${bundle.idea!.item.title}» تتوافق مع اهتمامك (${bundle.idea!.score}%).',
      );
    }
    if (bundle.supervisor != null) {
      analysis.writeln(
        '• المشرف ${bundle.supervisor!.item.name} قريب من مجالك (${bundle.supervisor!.score}%).',
      );
    }
    if (bundle.lab != null) {
      analysis.writeln(
        '• مختبر ${bundle.lab!.item.name} يخدم احتياجاتك التجريبية.',
      );
    }
    if (bundle.products.isNotEmpty) {
      analysis.writeln(
        '• ${bundle.products.length} منتج/ات من ${bundle.storeCategory?.title ?? 'المتجر'}.',
      );
    }
    if (bundle.writingExpert != null) {
      analysis.writeln(
        '• ${bundle.writingExpert!.item.name} لدعم الكتابة أو الإحصاء.',
      );
    }
    if (note != null && note.isNotEmpty) {
      analysis.writeln('\nملاحظة: $note');
    }

    final plan = StringBuffer()
      ..writeln('1. حدّد سؤال البحث وصياغة المشكلة بدقة.')
      ..writeln('2. راجع الأدبيات عبر الفكرة المقترحة أو المساعد الأكاديمي.')
      ..writeln('3. تواصل مع المشرف المقترح لاعتماد المنهجية.')
      ..writeln('4. احجز المختبر واطلب المواد من المتجر إن لزم.')
      ..writeln('5. اطلب دعم الكتابة/الإحصاء حسب مرحلة رسالتك.')
      ..writeln('6. راجع المسودات قبل التسليم النهائي.');

    return ResearchPathAiInsight(
      analysis: analysis.toString().trim(),
      researchPlan: plan.toString().trim(),
      nextStep: bundle.idea != null
          ? 'افتح تفاصيل الفكرة المقترحة وناقشها مع مشرفك.'
          : 'أكمل ملفك الأكاديمي أو وسّع وصف موضوع البحث لمطابقة أدق.',
      fromGemini: false,
      error: note,
    );
  }
}
