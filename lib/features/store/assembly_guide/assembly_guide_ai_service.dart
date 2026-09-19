import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/locale/app_translate.dart';
import '../../../core/locale/locale_service.dart';
import '../../ai_advisor/gemini_advisor_client.dart';
import 'assembly_guide_models.dart';

class AssemblyGuideAiDraft {
  final AssemblyGuide guide;
  final String? notes;
  final List<String> suggestedVideoSearches;

  const AssemblyGuideAiDraft({
    required this.guide,
    this.notes,
    this.suggestedVideoSearches = const [],
  });
}

/// يولّد مسودة دليل تفاعلي + روابط بحث فيديو (يوتيوب) من بيانات المنتج.
/// لا يصنع فيديو AI — يقترح محتوى وبحثاً للمراجعة قبل الحفظ.
class AssemblyGuideAiService {
  AssemblyGuideAiService._();
  static final AssemblyGuideAiService instance = AssemblyGuideAiService._();

  final _db = FirebaseFirestore.instance;

  Future<AssemblyGuideAiDraft> generateForProduct({
    required String productId,
    String? productNameHint,
  }) async {
    if (!GeminiAdvisorClient.isAvailable) {
      throw Exception(appTr(
        'ولّد الدليل يحتاج تسجيل الدخول أو مفتاح Gemini محلياً.',
        'Guide generation needs sign-in or a local Gemini key.',
      ));
    }

    final snap = await _db.collection('product').doc(productId).get();
    final data = snap.data() ?? {};
    final name = (productNameHint ?? data['name']?.toString() ?? '').trim();
    if (name.isEmpty) {
      throw Exception(appTr(
        'اسم المنتج مطلوب لتوليد الدليل',
        'Product name is required to generate a guide',
      ));
    }

    final description = data['description']?.toString() ?? '';
    final brand = data['brand']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final unit = data['unit']?.toString() ?? '';
    final grade = data['grade']?.toString() ?? '';

    final isEn = LocaleService.instance.isEnglish;
    final system = isEn
        ? '''
You are an academic product-usage coach for AcadeGate marketplace sellers.
Create a practical INTERACTIVE PRODUCT GUIDE draft for buyers — covering use, handling, operation, safety, or setup as relevant (not assembly-only).
The demonstration SETTING must match the store category / specialty of THIS product.
Do NOT assume a chemistry laboratory unless the product is a chemical reagent, solvent, or similar wet-lab item.
Examples: electronics → workshop/bench; medical → clinic or pharmacy; agriculture → greenhouse/field/vet room; computing → computer lab or desk; books → library; field tools → outdoor survey; office → writing desk; humanities → seminar room.
Return ONLY valid JSON (no markdown fences):
{
  "introAr": "short Arabic intro",
  "introEn": "short English intro",
  "notes": "1 short seller note about reviewing AI content",
  "videoSearches": ["youtube search query 1", "query 2"],
  "steps": [
    {
      "titleAr": "",
      "titleEn": "",
      "bodyAr": "2-4 sentences safety-aware",
      "bodyEn": "",
      "speakAr": "short TTS script AR",
      "speakEn": "short TTS script EN",
      "checkHintAr": "what a photo should show to verify this step",
      "checkHintEn": "",
      "videoSearchQuery": "english youtube search terms for this step"
    }
  ]
}
Rules:
- 4 to 7 steps. Adapt to the product: chemicals (storage, PPE, dilution, disposal), instruments (power, settings, first run), kits, electronics, field tools, books, or other supplies.
- Mention PPE/safety only when relevant to this product.
- Do NOT invent certification claims or fake specific YouTube video IDs.
- Prefer videoSearchQuery over inventing watch URLs.
- Respond with bilingual fields filled.
'''
        : '''
أنت مدرّب استخدام أكاديمي لبائعي متجر AcadeGate.
أنشئ مسودة دليل تفاعلي عملية للمشتري — استخدام أو تعامل أو تشغيل أو أمان حسب نوع المنتج (ليست للتركيب فقط).
مكان الشرح يجب أن يطابق قسم/تخصص هذا المنتج.
لا تفترض مختبر كيمياء إلا إذا كان المنتج مادة كيميائية أو كاشفاً أو مذيباً.
أمثلة: إلكترونيات → ورشة/منضدة؛ طبي → عيادة أو صيدلية؛ زراعة → صوبة/حقل/عيادة بيطرية؛ حوسبة → معمل حاسب أو مكتب؛ كتب → مكتبة؛ أدوات ميدانية → موقع مسح؛ مكتبي → مكتب كتابة؛ إنسانيات → قاعة ندوة.
أعد JSON صالحاً فقط (بدون سياج markdown):
{
  "introAr": "مقدمة قصيرة",
  "introEn": "short English intro",
  "notes": "ملاحظة قصيرة للبائع لمراجعة المحتوى",
  "videoSearches": ["عبارة بحث يوتيوب 1", "عبارة 2"],
  "steps": [
    {
      "titleAr": "",
      "titleEn": "",
      "bodyAr": "٢–٤ جمل مع تنبيه أمان إن لزم",
      "bodyEn": "",
      "speakAr": "نص صوت قصير",
      "speakEn": "",
      "checkHintAr": "ماذا يجب أن تظهره صورة التحقق",
      "checkHintEn": "",
      "videoSearchQuery": "english youtube search for this step"
    }
  ]
}
القواعد:
- من ٤ إلى ٧ خطوات. كيّفها حسب المنتج: مواد كيميائية (تخزين، وقاية، تخفيف، تخلص)، أجهزة (تشغيل، إعدادات، تجربة أولى)، إلكترونيات، أدوات ميدانية، كتب، أو غيرها.
- اذكر الوقاية فقط عندما تناسب هذا المنتج.
- لا تخترع شهادات ولا روابط يوتيوب watch مزيفة بمعرّفات فيديو.
- فضّل videoSearchQuery على اختلاق روابط مشاهدة.
- املأ الحقول بالعربي والإنجليزي.
''';

    final userMsg = [
      appTr('اسم المنتج: $name', 'Product name: $name'),
      if (brand.trim().isNotEmpty) appTr('العلامة: $brand', 'Brand: $brand'),
      if (category.trim().isNotEmpty)
        appTr('القسم: $category', 'Category: $category'),
      if (unit.trim().isNotEmpty) appTr('الوحدة: $unit', 'Unit: $unit'),
      if (grade.trim().isNotEmpty) appTr('الدرجة: $grade', 'Grade: $grade'),
      if (description.trim().isNotEmpty)
        appTr('الوصف: $description', 'Description: $description'),
      appTr(
        'أنشئ مسودة دليل تفاعلي مناسبة لهذا المنتج في المكان الذي يُستخدم فيه فعلاً حسب تخصصه (ليس مختبر كيمياء إلا إذا كان المنتج كيميائياً).',
        'Create an interactive product guide for the real setting of this specialty (not a chemistry lab unless the product is chemical).',
      ),
    ].join('\n');

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: system,
      userMessage: userMsg,
      maxOutputTokens: 4096,
    );
    if (!result.isSuccess) {
      throw Exception(
        result.error ??
            appTr('تعذر توليد الدليل', 'Could not generate the guide'),
      );
    }

    final parsed = _parse(result.text!);
    if (parsed == null) {
      throw Exception(appTr(
        'تعذر قراءة نتيجة التوليد. أعد المحاولة.',
        'Could not parse generation result. Please retry.',
      ));
    }
    return parsed;
  }

  AssemblyGuideAiDraft? _parse(String raw) {
    var t = raw.trim();
    if (!t.startsWith('{')) {
      final fence =
          RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
              .firstMatch(t);
      if (fence != null) t = fence.group(1)?.trim() ?? t;
      final start = t.indexOf('{');
      final end = t.lastIndexOf('}');
      if (start >= 0 && end > start) t = t.substring(start, end + 1);
    }
    try {
      final map = jsonDecode(t);
      if (map is! Map) return null;
      final m = Map<String, dynamic>.from(map);
      final stepsRaw = m['steps'];
      if (stepsRaw is! List || stepsRaw.isEmpty) return null;

      final steps = <AssemblyGuideStep>[];
      final videoSearches = <String>[];
      final globalSearches = m['videoSearches'];
      if (globalSearches is List) {
        for (final q in globalSearches) {
          final s = q.toString().trim();
          if (s.isNotEmpty) videoSearches.add(s);
        }
      }

      for (var i = 0; i < stepsRaw.length; i++) {
        final item = stepsRaw[i];
        if (item is! Map) continue;
        final s = Map<String, dynamic>.from(item);
        final titleAr = s['titleAr']?.toString().trim() ?? '';
        final titleEn = s['titleEn']?.toString().trim() ?? '';
        if (titleAr.isEmpty && titleEn.isEmpty) continue;

        final searchQ = (s['videoSearchQuery']?.toString() ?? '').trim();
        final videoUrl = searchQ.isNotEmpty
            ? youtubeSearchUrl(searchQ)
            : _sanitizeVideoUrl(s['videoUrl']?.toString());

        if (searchQ.isNotEmpty) videoSearches.add(searchQ);

        steps.add(AssemblyGuideStep(
          id: 'ai_${DateTime.now().microsecondsSinceEpoch}_$i',
          titleAr: titleAr.isNotEmpty ? titleAr : titleEn,
          titleEn: titleEn.isNotEmpty ? titleEn : titleAr,
          bodyAr: s['bodyAr']?.toString() ?? '',
          bodyEn: s['bodyEn']?.toString() ?? '',
          speakAr: s['speakAr']?.toString() ?? '',
          speakEn: s['speakEn']?.toString() ?? '',
          videoUrl: videoUrl,
          checkHintAr: s['checkHintAr']?.toString() ?? '',
          checkHintEn: s['checkHintEn']?.toString() ?? '',
        ));
      }
      if (steps.isEmpty) return null;

      return AssemblyGuideAiDraft(
        guide: AssemblyGuide(
          enabled: true,
          unlock: AssemblyGuideUnlock.afterPurchase,
          introAr: m['introAr']?.toString() ?? '',
          introEn: m['introEn']?.toString() ?? '',
          steps: steps,
        ),
        notes: m['notes']?.toString(),
        suggestedVideoSearches: videoSearches.toSet().toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static String youtubeSearchUrl(String query) {
    final q = Uri.encodeComponent(query.trim());
    return 'https://www.youtube.com/results?search_query=$q';
  }

  static String? _sanitizeVideoUrl(String? raw) {
    final u = (raw ?? '').trim();
    if (u.isEmpty) return null;
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.hasScheme) return null;
    final host = uri.host.toLowerCase();
    if (host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('vimeo.com')) {
      return u;
    }
    // Avoid hallucinated random URLs
    return null;
  }
}
