import 'dart:convert';

import '../../../core/locale/app_translate.dart';
import '../../../core/locale/locale_service.dart';
import '../../ai_advisor/advisor_attachment.dart';
import '../../ai_advisor/gemini_advisor_client.dart';
import '../store_catalog_service.dart';
import 'store_custom_fit_matcher.dart';
import 'store_custom_fit_models.dart';

class DiagramExtractResult {
  final String? text;
  final String? error;

  const DiagramExtractResult({this.text, this.error});

  bool get isSuccess => text != null && text!.trim().isNotEmpty;
}

/// تحليل رسم/مواصفات تجربة + مطابقة كتالوج المتجر + موجز تصنيع رقمي.
class StoreCustomFitAiService {
  StoreCustomFitAiService._();
  static final StoreCustomFitAiService instance = StoreCustomFitAiService._();

  /// يستخرج وصف بحث / مواصفات من الرسم فقط (بدون نص من المستخدم).
  Future<DiagramExtractResult> extractSearchQueryFromDiagram({
    required List<GeminiInlinePart> diagramParts,
    String? experimentTitle,
  }) async {
    if (diagramParts.isEmpty) {
      return DiagramExtractResult(
        error: appTr('لا توجد صورة مرفقة.', 'No image attached.'),
      );
    }
    if (!GeminiAdvisorClient.isAvailable) {
      return DiagramExtractResult(
        error: appTr(
          'سجّل الدخول لتحليل الصورة.',
          'Sign in to analyze the image.',
        ),
      );
    }

    final isEn = LocaleService.instance.isEnglish;
    final systemPrompt = isEn
        ? '''
You are a lab-equipment procurement assistant. From the attached diagram/photo only, extract what product or part is needed.
Return plain text only (no JSON, no markdown):
Line 1: short English product search query (keywords for store search)
Line 2: Arabic short description of the part/specs if possible
Line 3+: bullet critical specs (dimensions, material, pressure, interface…)
Do not invent brand names not visible in the image.
'''
        : '''
أنت مساعد توريد معدات مخبرية. من الرسم/الصورة المرفقة فقط، استخرج المنتج أو القطعة المطلوبة.
أعد نصاً عادياً فقط (بدون JSON وبدون markdown):
السطر 1: كلمات بحث إنجليزية قصيرة للمتجر
السطر 2: وصف عربي مختصر للقطعة/المواصفات
ثم أسطر بنقاط للمواصفات الحرجة (أبعاد، مادة، ضغط، واجهة…)
لا تخترع علامات تجارية غير ظاهرة في الصورة.
''';

    final title = (experimentTitle ?? '').trim();
    final userMessage = [
      if (title.isNotEmpty)
        appTr(
          'عنوان اختياري: $title',
          'Optional title: $title',
        ),
      appTr(
        'حلّل الرسم المرفق واستخرج وصف البحث والمواصفات.',
        'Analyze the attached diagram and extract a search description and specs.',
      ),
    ].join('\n');

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      attachments: diagramParts,
      maxOutputTokens: 1024,
    );
    if (!result.isSuccess || result.text == null || result.text!.trim().isEmpty) {
      return DiagramExtractResult(
        error: result.error?.trim().isNotEmpty == true
            ? result.error!
            : appTr(
                'تعذر تحليل الصورة. أعد المحاولة.',
                'The image could not be analyzed. Try again.',
              ),
      );
    }
    return DiagramExtractResult(text: result.text!.trim());
  }

  Future<CustomFitAnalysisResult> analyze({
    required String specsText,
    required List<StoreCatalogProduct> catalog,
    List<GeminiInlinePart> diagramParts = const [],
    String? experimentTitle,
  }) async {
    var trimmed = specsText.trim();
    if (trimmed.length < 12 && diagramParts.isEmpty) {
      return CustomFitAnalysisResult(
        requirements: const CustomFitRequirements(),
        error: appTr(
          'أدخل مواصفات التجربة أو ارفع رسم الجهاز/القطعة.',
          'Enter experiment specs or upload a diagram of the device/part.',
        ),
      );
    }

    // صورة فقط: استخرج وصفاً من الرسم لتحسين مسح الكتالوج
    if (trimmed.length < 12 && diagramParts.isNotEmpty) {
      final fromImage = await extractSearchQueryFromDiagram(
        diagramParts: diagramParts,
        experimentTitle: experimentTitle,
      );
      if (fromImage.text != null && fromImage.text!.trim().isNotEmpty) {
        trimmed = fromImage.text!.trim();
      } else if (!GeminiAdvisorClient.isAvailable) {
        return CustomFitAnalysisResult(
          requirements: const CustomFitRequirements(),
          error: fromImage.error ??
              appTr(
                'لتحليل الرسم فقط سجّل الدخول، أو اكتب وصفاً قصيراً.',
                'To analyze an image alone, sign in, or type a short description.',
              ),
        );
      }
      // إن فشل الاستخراج المنفصل، نكمل بالتحليل الكامل مع المرفق مباشرة
    }

    final candidates = StoreCustomFitMatcher.instance.rankCandidates(
      catalog: catalog,
      specsText: trimmed,
      limit: 36,
    );

    if (!GeminiAdvisorClient.isAvailable) {
      return _localFallback(
        specsText: trimmed,
        candidates: candidates,
        note: appTr(
          'سجّل الدخول لتحليل أدق للرسم والمواصفات.',
          'Sign in for a closer reading of the diagram and specs.',
        ),
      );
    }

    final systemPrompt = LocaleService.instance.isEnglish
        ? _systemEn
        : _systemAr;

    final catalogBlock = _catalogBlock(candidates);
    final userMessage = StringBuffer()
      ..writeln(appTr('--- طلب الباحث ---', '--- Researcher request ---'))
      ..writeln(
        appTr(
          'العنوان: ${experimentTitle?.trim().isNotEmpty == true ? experimentTitle!.trim() : '(بدون عنوان)'}',
          'Title: ${experimentTitle?.trim().isNotEmpty == true ? experimentTitle!.trim() : '(untitled)'}',
        ),
      )
      ..writeln(appTr('المواصفات / وصف التجربة:', 'Specs / experiment description:'))
      ..writeln(trimmed.isEmpty ? '(انظر الرسم المرفق)' : trimmed)
      ..writeln()
      ..writeln(
        appTr(
          '--- مرشحو الكتالوج (اختر من هذه المعرفات فقط) ---',
          '--- Catalog candidates (pick IDs only from this list) ---',
        ),
      )
      ..writeln(
        catalogBlock.trim().isEmpty
            ? appTr(
                '(لا مرشحين محليين بعد — حلّل الرسم واستخرج كلمات بحث ومواصفات؛ اترك matches فارغة إن لم يوجد تطابق)',
                '(No local candidates yet — analyze the diagram, extract search keywords/specs; leave matches empty if none fit)',
              )
            : catalogBlock,
      );

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: systemPrompt,
      userMessage: userMessage.toString(),
      attachments: diagramParts,
      maxOutputTokens: 4096,
    );

    if (!result.isSuccess || result.text == null) {
      return _localFallback(
        specsText: trimmed,
        candidates: candidates,
        note: result.error ??
            appTr('تعذر تحليل الطلب', 'The request could not be analyzed'),
      );
    }

    final parsed = _parseAiJson(result.text!);
    if (parsed == null) {
      return _localFallback(
        specsText: trimmed,
        candidates: candidates,
        note: appTr(
          'تعذر قراءة نتيجة التحليل — عُرضت مطابقة محلية.',
          'Could not read the analysis — showing local matches.',
        ),
      );
    }

    final byId = {for (final p in candidates) p.id: p};
    // also allow full catalog lookup for ids AI might copy incorrectly from nearby
    for (final p in catalog) {
      byId.putIfAbsent(p.id, () => p);
    }

    final matches = <CustomFitMatchItem>[];
    final rawMatches = parsed['matches'];
    if (rawMatches is List) {
      for (final raw in rawMatches) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final id = m['productId']?.toString() ?? '';
        if (id.isEmpty || !byId.containsKey(id)) continue;
        final product = byId[id]!;
        final pct = ((m['matchPercent'] as num?)?.toInt() ?? 0).clamp(1, 99);
        matches.add(
          CustomFitMatchItem(
            productId: id,
            productName: product.name,
            matchPercent: pct,
            whyAr: m['whyAr']?.toString() ?? m['why']?.toString() ?? '',
            whyEn: m['whyEn']?.toString() ?? '',
            gapAr: m['gapAr']?.toString() ?? m['gap']?.toString() ?? '',
            gapEn: m['gapEn']?.toString() ?? '',
            product: product,
          ),
        );
      }
    }

    if (matches.isEmpty) {
      matches.addAll(
        StoreCustomFitMatcher.instance.localMatches(
          candidates: candidates,
          specsText: trimmed,
          requirements: CustomFitRequirements.fromMap(
            parsed['requirements'] is Map
                ? Map<String, dynamic>.from(parsed['requirements'] as Map)
                : const {},
          ),
        ),
      );
    }

    matches.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));

    final reqMap = parsed['requirements'] is Map
        ? Map<String, dynamic>.from(parsed['requirements'] as Map)
        : <String, dynamic>{};
    final fabMap = parsed['fabrication'] is Map
        ? Map<String, dynamic>.from(parsed['fabrication'] as Map)
        : <String, dynamic>{};

    final needsCustom = parsed['needsCustomFabrication'] == true ||
        matches.every((m) => m.matchPercent < 85);

    return CustomFitAnalysisResult(
      requirements: CustomFitRequirements.fromMap(reqMap),
      matches: matches.take(8).toList(),
      fabrication: CustomFitFabricationBrief.fromMap(fabMap),
      needsCustomFabrication: needsCustom,
      confidenceNoteAr: parsed['confidenceNoteAr']?.toString() ??
          'المطابقة تقديرية — راجع المقاسات مع مسؤول المختبر قبل الشراء.',
      confidenceNoteEn: parsed['confidenceNoteEn']?.toString() ??
          'Match scores are estimates — verify dimensions with your lab before ordering.',
      fromAi: true,
      modelUsed: result.modelUsed,
    );
  }

  CustomFitAnalysisResult _localFallback({
    required String specsText,
    required List<StoreCatalogProduct> candidates,
    required String note,
  }) {
    final req = CustomFitRequirements(
      summaryAr: specsText.length > 220 ? '${specsText.substring(0, 220)}…' : specsText,
      summaryEn: specsText.length > 220 ? '${specsText.substring(0, 220)}…' : specsText,
      keywords: StoreCustomFitMatcher.instance
          .rankCandidates(catalog: candidates, specsText: specsText, limit: 1)
          .isEmpty
          ? const []
          : specsText
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .where((w) => w.length >= 3)
              .take(12)
              .toList(),
    );
    final matches = StoreCustomFitMatcher.instance.localMatches(
      candidates: candidates,
      specsText: specsText,
      requirements: req,
    );
    final fab = CustomFitFabricationBrief(
      processHint: 'CNC / 3D print / supplier modification (TBD with vendor)',
      materialHint: appTr(
        'يُحدَّد حسب توافق الجهاز والدرجة المطلوبة',
        'To be confirmed for instrument compatibility and required grade',
      ),
      supplierAskAr:
          'نحتاج تصنيع/تعديل قطعة لتلائم المواصفات التالية:\n$specsText',
      supplierAskEn:
          'We need a custom or modified part matching these specs:\n$specsText',
      checklist: const [
        'تأكيد الأبعاد والوحدات',
        'درجة النقاء / المواد',
        'ضغط وحرارة التشغيل إن وُجدت',
        'توافق الواجهة مع الجهاز',
      ],
    );
    return CustomFitAnalysisResult(
      requirements: req,
      matches: matches,
      fabrication: fab,
      needsCustomFabrication: matches.isEmpty ||
          matches.first.matchPercent < 85,
      confidenceNoteAr: note,
      confidenceNoteEn: note,
      fromAi: false,
      // لا نعرض منتجات عشوائية كنجاح — نظهر الخطأ إن لم توجد مطابقة حقيقية
      error: matches.isEmpty ? note : null,
    );
  }

  String _catalogBlock(List<StoreCatalogProduct> products) {
    final buf = StringBuffer();
    var i = 0;
    for (final p in products) {
      i++;
      final desc = p.description.trim();
      final shortDesc =
          desc.length > 160 ? '${desc.substring(0, 160)}…' : desc;
      buf.writeln(
        '$i) id=${p.id} | ${p.name} | cat=${p.categoryCanonical.isNotEmpty ? p.categoryCanonical : p.categoryRaw} '
        '| brand=${p.brand} | grade=${p.grade} | unit=${p.unit} | price=${p.price} '
        '| store=${p.storeName} | desc=$shortDesc',
      );
    }
    return buf.toString();
  }

  Map<String, dynamic>? _parseAiJson(String raw) {
    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
    final m = fence.firstMatch(text);
    if (m != null) {
      text = m.group(1)!.trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  static const _systemAr = '''
أنت مهندس توافُق مخبري في منصة AcadeGate للمتجر الأكاديمي.
المهمة: من مواصفات تجربة و/أو رسم مرفق، استخرج المتطلبات الحرجة، وطابق منتجات الكتالوج المعطى فقط، واقترح موجز تصنيع رقمي إن لزم التعديل/التصنيع المخصص.

قواعد صارمة:
- أعد JSON صالحاً فقط بدون نص خارجي.
- لا تخترع productId غير موجود في قائمة المرشحين.
- matchPercent عدد صحيح 1–99 (لا تدّعِ 100 إلا إذا كانت كل المواصفات الحرجة مذكورة صراحة في وصف المنتج).
- needsCustomFabrication=true إذا أفضل تطابق < 85 أو المواصفات تتطلب قطعة غير قياسية.
- fabrication موجز عملي للمورد (عملية، مادة، تحمّلات، أبعاد، طلب واضح).

شكل JSON:
{
  "requirements": {
    "summaryAr": "",
    "summaryEn": "",
    "equipmentOrContext": "",
    "criticalSpecs": ["..."],
    "materialsHints": ["..."],
    "keywords": ["..."],
    "riskNotes": ""
  },
  "matches": [
    {
      "productId": "",
      "matchPercent": 72,
      "whyAr": "",
      "whyEn": "",
      "gapAr": "",
      "gapEn": ""
    }
  ],
  "needsCustomFabrication": true,
  "fabrication": {
    "processHint": "CNC | FDM/SLA | laser cut | supplier mod",
    "materialHint": "",
    "tolerances": "",
    "dimensionsSummary": "",
    "modificationNotes": "",
    "supplierAskAr": "",
    "supplierAskEn": "",
    "checklist": ["..."]
  },
  "confidenceNoteAr": "",
  "confidenceNoteEn": ""
}
''';

  static const _systemEn = '''
You are a lab-compatibility engineer for the AcadeGate academic marketplace.
From experiment specs and/or an attached diagram, extract critical requirements, match ONLY the given catalog candidates, and propose a digital-manufacturing brief when a custom/modified part is needed.

Strict rules:
- Return valid JSON only (no markdown outside JSON if possible).
- Never invent productId values not in the candidate list.
- matchPercent integer 1–99 (do not claim 100 unless every critical spec is explicitly present in the product text).
- needsCustomFabrication=true if best match < 85 or specs need a non-standard part.
- fabrication must be practical for a supplier (process, material, tolerances, dimensions, clear ask).

JSON shape:
{
  "requirements": {
    "summaryAr": "",
    "summaryEn": "",
    "equipmentOrContext": "",
    "criticalSpecs": ["..."],
    "materialsHints": ["..."],
    "keywords": ["..."],
    "riskNotes": ""
  },
  "matches": [
    {
      "productId": "",
      "matchPercent": 72,
      "whyAr": "",
      "whyEn": "",
      "gapAr": "",
      "gapEn": ""
    }
  ],
  "needsCustomFabrication": true,
  "fabrication": {
    "processHint": "CNC | FDM/SLA | laser cut | supplier mod",
    "materialHint": "",
    "tolerances": "",
    "dimensionsSummary": "",
    "modificationNotes": "",
    "supplierAskAr": "",
    "supplierAskEn": "",
    "checklist": ["..."]
  },
  "confidenceNoteAr": "",
  "confidenceNoteEn": ""
}
''';
}
