import 'dart:convert';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_service.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../profile/academic_profile_service.dart';
import 'store_cart_safety_models.dart';
import 'store_cart_service.dart';
import 'store_catalog_service.dart';

/// فحص استرشادي لسلامة منتجات العربة: مخاطر + تعامل + تخزين.
class StoreCartSafetyService {
  StoreCartSafetyService._();
  static final StoreCartSafetyService instance = StoreCartSafetyService._();

  static const _disclaimerAr =
      'تنبيه استرشادي من AcadeGate — ليس شهادة سلامة رسمية ولا يغني عن لوائح الكلية/الجامعة أو SDS الشركة المصنّعة.';
  static const _disclaimerEn =
      'Advisory note from AcadeGate — not an official safety certificate and does not replace college/university rules or manufacturer SDS.';

  Future<CartSafetyScanResult> scanCart(List<StoreCartItem> items) async {
    if (items.isEmpty) {
      return CartSafetyScanResult(
        error: appTr('العربة فارغة.', 'Cart is empty.'),
        disclaimer: LocaleService.instance.isEnglish ? _disclaimerEn : _disclaimerAr,
      );
    }

    final enriched = await _enrichItems(items);
    final localNotes = enriched.map(_localNote).toList();

    if (!GeminiAdvisorClient.isAvailable) {
      return CartSafetyScanResult(
        notes: localNotes,
        overallSummary: _overallFromNotes(localNotes),
        overallLevel: _maxLevel(localNotes),
        fromAi: false,
        disclaimer:
            LocaleService.instance.isEnglish ? _disclaimerEn : _disclaimerAr,
      );
    }

    try {
      final ai = await _scanWithGemini(enriched, localNotes);
      if (ai != null) return ai;
    } catch (_) {}

    return CartSafetyScanResult(
      notes: localNotes,
      overallSummary: _overallFromNotes(localNotes),
      overallLevel: _maxLevel(localNotes),
      fromAi: false,
      disclaimer:
          LocaleService.instance.isEnglish ? _disclaimerEn : _disclaimerAr,
    );
  }

  Future<List<_CartScanItem>> _enrichItems(List<StoreCartItem> items) async {
    StoreCatalogBundle? catalog;
    try {
      catalog = await StoreCatalogService.instance.loadPublicCatalog();
    } catch (_) {}

    final byId = <String, StoreCatalogProduct>{
      if (catalog != null)
        for (final p in catalog.products) p.id: p,
    };

    return items.map((item) {
      final p = byId[item.productId];
      return _CartScanItem(
        productId: item.productId,
        name: item.name,
        quantity: item.quantity,
        category: (item.category ?? '').trim().isNotEmpty
            ? item.category!.trim()
            : (p?.categoryCanonical.isNotEmpty == true
                ? p!.categoryCanonical
                : (p?.categoryRaw ?? '')),
        description: (item.description ?? '').trim().isNotEmpty
            ? item.description!.trim()
            : (p?.description ?? ''),
        grade: p?.grade ?? '',
        brand: p?.brand ?? '',
      );
    }).toList();
  }

  CartProductSafetyNote _localNote(_CartScanItem item) {
    final hay = [
      item.name,
      item.category,
      item.description,
      item.grade,
      item.brand,
    ].join(' ').toLowerCase();

    final flags = <String>{};
    void flag(String k) => flags.add(k);

    if (_matches(hay, const [
      'acid',
      'حمض',
      'hcl',
      'h2so4',
      'nitric',
      'sulfuric',
      'acetic',
      'خل',
    ])) {
      flag('corrosive');
    }
    if (_matches(hay, const [
      'solvent',
      'مذيب',
      'ethanol',
      'methanol',
      'acetone',
      'hexane',
      'toluene',
      'chloroform',
      'إيثانول',
      'ميثانول',
      'أسيتون',
    ])) {
      flag('flammable');
    }
    if (_matches(hay, const [
      'toxic',
      'سم',
      'cyanide',
      'mercury',
      'زئبق',
      'formaldehyde',
      'فورمالين',
      'phenol',
      'فينول',
    ])) {
      flag('toxic');
    }
    if (_matches(hay, const [
      'oxidizer',
      'peroxide',
      'بيروكسيد',
      'permanganate',
      'nitrate',
      'مؤكسد',
    ])) {
      flag('oxidizer');
    }
    if (_matches(hay, const [
      'bio',
      'blood',
      'دم',
      'serum',
      'virus',
      'بكتيريا',
      'pathogen',
      'culture',
      'مزرعة',
    ])) {
      flag('bio');
    }
    if (_matches(hay, const [
      'radio',
      'إشعاع',
      'isotope',
      'x-ray',
      'أشعة',
      'laser',
      'ليزر',
    ])) {
      flag('radiation');
    }
    if (_matches(hay, const [
      'gas',
      'غاز',
      'cylinder',
      'أسطوانة',
      'compressed',
      'cryogen',
      'nitrogen',
      'نيتروجين سائل',
    ])) {
      flag('gas_pressure');
    }
    if (_matches(hay, const [
      'chemical',
      'كيميائي',
      'reagent',
      'كاشف',
      'buffer',
      'محلول',
    ]) &&
        flags.isEmpty) {
      flag('general_chem');
    }

    if (flags.isEmpty) {
      return CartProductSafetyNote(
        productId: item.productId,
        productName: item.name,
        level: CartSafetyLevel.low,
        summary: appTr(
          'لا تظهر مؤشرات خطر واضحة من الاسم/الوصف — راجع تعليمات المورّد إن وُجدت.',
          'No clear hazard signals from name/description — check supplier instructions if available.',
        ),
        handling: [
          appTr(
            'اتبع تعليمات الاستخدام على العبوة.',
            'Follow the usage instructions on the package.',
          ),
        ],
        storage: [
          appTr(
            'خزّن في مكان جاف وبارد بعيداً عن أشعة الشمس المباشرة.',
            'Store in a cool, dry place away from direct sunlight.',
          ),
        ],
      );
    }

    final level = flags.any((f) =>
            f == 'toxic' || f == 'radiation' || f == 'oxidizer' || f == 'bio')
        ? CartSafetyLevel.high
        : (flags.contains('corrosive') ||
                flags.contains('flammable') ||
                flags.contains('gas_pressure'))
            ? CartSafetyLevel.medium
            : CartSafetyLevel.low;

    final hazards = <String>[];
    final handling = <String>[];
    final storage = <String>[];

    if (flags.contains('corrosive')) {
      hazards.add(appTr('مادة أكّالة / حمضية محتملة', 'Possible corrosive/acid'));
      handling.add(appTr(
        'استخدم قفازات ونظارات واقية؛ تجنّب ملامسة الجلد والعينين.',
        'Use gloves and goggles; avoid skin and eye contact.',
      ));
      storage.add(appTr(
        'خزّن في عبوة محكمة برف مقاوم للأحماض، بعيداً عن القواعد والمذيبات.',
        'Keep tightly closed on an acid-resistant shelf, away from bases and solvents.',
      ));
    }
    if (flags.contains('flammable')) {
      hazards.add(appTr('قابل للاشتعال', 'Flammable'));
      handling.add(appTr(
        'بعيداً عن اللهب والشرر؛ استخدم في مكان جيد التهوية.',
        'Keep away from flames/sparks; use in a well-ventilated area.',
      ));
      storage.add(appTr(
        'خزانة مذيبات / مكان بارد بعيد عن مصادر الاشتعال.',
        'Solvent cabinet / cool place away from ignition sources.',
      ));
    }
    if (flags.contains('toxic')) {
      hazards.add(appTr('سمية محتملة', 'Possibly toxic'));
      handling.add(appTr(
        'لا تستنشق الأبخرة؛ استخدم شفاط المختبر عند الحاجة.',
        'Do not inhale vapors; use a fume hood when needed.',
      ));
      storage.add(appTr(
        'خزّن مغلقاً وبعيداً عن الطعام والوصول غير المصرّح.',
        'Store sealed, away from food and unauthorized access.',
      ));
    }
    if (flags.contains('oxidizer')) {
      hazards.add(appTr('مؤكسد — خطر تفاعل عنيف', 'Oxidizer — reactive hazard'));
      handling.add(appTr(
        'لا تخلطه مع مواد عضوية أو مذيبات قابلة للاشتعال.',
        'Do not mix with organics or flammable solvents.',
      ));
      storage.add(appTr(
        'افصل عن المواد القابلة للاشتعال والأحماض المركّزة.',
        'Separate from flammables and concentrated acids.',
      ));
    }
    if (flags.contains('bio')) {
      hazards.add(appTr('مادة بيولوجية / عينات حيوية محتملة', 'Possible biological material'));
      handling.add(appTr(
        'اتبع إجراءات التعقيم؛ تخلّص من النفايات حسب بروتوكول المختبر.',
        'Follow aseptic procedures; dispose of waste per lab protocol.',
      ));
      storage.add(appTr(
        'ثلاجة/مجمّد حسب تعليمات المنتج؛ لا تخلط مع طعام.',
        'Fridge/freezer per product instructions; never with food.',
      ));
    }
    if (flags.contains('radiation')) {
      hazards.add(appTr('إشعاع / ليزر — يحتاج إجراءات خاصة', 'Radiation/laser — special controls'));
      handling.add(appTr(
        'لا تشغّل دون تدريب وموافقة سلامة المختبر.',
        'Do not operate without training and lab-safety approval.',
      ));
      storage.add(appTr(
        'حسب تعليمات الجهاز ومسؤول السلامة.',
        'Follow device instructions and the safety officer.',
      ));
    }
    if (flags.contains('gas_pressure')) {
      hazards.add(appTr('غاز مضغوط / أسطوانة', 'Compressed gas / cylinder'));
      handling.add(appTr(
        'ثبّت الأسطوانة؛ افتح الصمام ببطء؛ لا تنقل بدون غطاء الحماية.',
        'Secure the cylinder; open the valve slowly; never move without the cap.',
      ));
      storage.add(appTr(
        'مكان جيد التهوية، مثبت، بعيداً عن الحرارة.',
        'Well-ventilated, secured, away from heat.',
      ));
    }
    if (flags.contains('general_chem')) {
      hazards.add(appTr('مادة كيميائية مخبرية عامة', 'General lab chemical'));
      handling.add(appTr(
        'اقرأ ورقة بيانات السلامة (SDS) قبل الاستخدام.',
        'Read the SDS before use.',
      ));
      storage.add(appTr(
        'حسب تعليمات العبوة؛ أغلق الغطاء بإحكام بعد كل استخدام.',
        'Per package instructions; reseal tightly after each use.',
      ));
    }

    return CartProductSafetyNote(
      productId: item.productId,
      productName: item.name,
      level: level,
      hazards: hazards,
      handling: handling,
      storage: storage,
      summary: hazards.join(' · '),
    );
  }

  Future<CartSafetyScanResult?> _scanWithGemini(
    List<_CartScanItem> items,
    List<CartProductSafetyNote> fallback,
  ) async {
    final isEn = LocaleService.instance.isEnglish;
    final profile = await AcademicProfileService.instance.loadProfile();
    final researchHint = [
      if ((profile?.specialization ?? '').trim().isNotEmpty)
        profile!.specialization.trim(),
      if ((profile?.researchInterest ?? '').trim().isNotEmpty)
        profile!.researchInterest.trim(),
    ].join(' — ');

    final catalogLines = items.asMap().entries.map((e) {
      final i = e.key + 1;
      final p = e.value;
      return '$i) id=${p.productId} | ${p.name} | qty=${p.quantity} | '
          'cat=${p.category} | grade=${p.grade} | '
          'desc=${p.description.length > 180 ? p.description.substring(0, 180) : p.description}';
    }).join('\n');

    final systemPrompt = isEn
        ? '''
You are a lab safety assistant for Egyptian graduate researchers.
Given cart products, return ONLY valid JSON (no markdown):
{
  "overallLevel": "low"|"medium"|"high",
  "overallSummary": "2-3 short sentences in English",
  "items": [
    {
      "productId": "...",
      "level": "low"|"medium"|"high",
      "summary": "one short line",
      "hazards": ["..."],
      "handling": ["..."],
      "storage": ["..."]
    }
  ]
}
Rules:
- Be practical and concise. Do NOT invent brand-specific SDS numbers.
- If unsure, say so and keep level medium (not high) unless clear toxic/flammable/corrosive/bio signals.
- This is advisory only, not official certification.
- Respond in English.
'''
        : '''
أنت مساعد سلامة مختبرات لباحثي الدراسات العليا في مصر.
من منتجات العربة، أعد JSON صالحاً فقط (بدون markdown):
{
  "overallLevel": "low"|"medium"|"high",
  "overallSummary": "جملتان إلى ثلاث قصيرة بالعربية",
  "items": [
    {
      "productId": "...",
      "level": "low"|"medium"|"high",
      "summary": "سطر مختصر",
      "hazards": ["..."],
      "handling": ["..."],
      "storage": ["..."]
    }
  ]
}
قواعد:
- كن عملياً ومختصراً. لا تخترع أرقام SDS غير موجودة.
- إن لم تكن متأكداً، وضّح ذلك ولا ترفع المستوى إلى high إلا مع إشارات واضحة (سمّي/قابل اشتعال/أكّال/بيولوجي).
- هذا استرشادي فقط وليس شهادة رسمية.
''';

    final userMessage = [
      if (researchHint.isNotEmpty)
        appTr(
          'سياق البحث (إن وُجد): $researchHint',
          'Research context (if any): $researchHint',
        ),
      appTr('منتجات العربة:', 'Cart products:'),
      catalogLines,
      appTr(
        'حلّل كل منتج: المخاطر إن وُجدت، كيفية التعامل، والتخزين الآمن.',
        'For each product: hazards if any, handling, and safe storage.',
      ),
    ].join('\n');

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      maxOutputTokens: 4096,
    );
    if (!result.isSuccess) return null;

    final parsed = _parseAiJson(result.text!, items, fallback);
    if (parsed == null) return null;
    return CartSafetyScanResult(
      notes: parsed.notes,
      overallSummary: parsed.overallSummary,
      overallLevel: parsed.overallLevel,
      fromAi: true,
      modelUsed: result.modelUsed,
      disclaimer: isEn ? _disclaimerEn : _disclaimerAr,
    );
  }

  ({
    List<CartProductSafetyNote> notes,
    String overallSummary,
    CartSafetyLevel overallLevel,
  })? _parseAiJson(
    String raw,
    List<_CartScanItem> items,
    List<CartProductSafetyNote> fallback,
  ) {
    final jsonStr = _extractJson(raw);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr);
      if (map is! Map) return null;
      final byId = {for (final f in fallback) f.productId: f};
      final notes = <CartProductSafetyNote>[];
      final list = map['items'];
      if (list is List) {
        for (final item in list) {
          if (item is! Map) continue;
          final id = item['productId']?.toString() ?? '';
          final name = items
              .firstWhere(
                (e) => e.productId == id,
                orElse: () => _CartScanItem(
                  productId: id,
                  name: byId[id]?.productName ?? id,
                  quantity: 1,
                ),
              )
              .name;
          notes.add(
            CartProductSafetyNote(
              productId: id.isEmpty ? name : id,
              productName: name,
              level: _levelFrom(item['level']?.toString()),
              summary: item['summary']?.toString() ?? '',
              hazards: _stringList(item['hazards']),
              handling: _stringList(item['handling']),
              storage: _stringList(item['storage']),
            ),
          );
        }
      }
      if (notes.isEmpty) {
        // إن أعاد AI ملخصاً فقط دون عناصر، أبقِ المحلي
        notes.addAll(fallback);
      } else {
        // أكمل أي منتجات ناقصة من المحلي
        final seen = notes.map((n) => n.productId).toSet();
        for (final f in fallback) {
          if (!seen.contains(f.productId)) notes.add(f);
        }
      }
      return (
        notes: notes,
        overallSummary: map['overallSummary']?.toString() ??
            _overallFromNotes(notes),
        overallLevel: _levelFrom(map['overallLevel']?.toString()),
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) return trimmed;
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
        .firstMatch(trimmed);
    if (fence != null) return fence.group(1)?.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) return trimmed.substring(start, end + 1);
    return null;
  }

  List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  CartSafetyLevel _levelFrom(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'high':
      case 'مرتفع':
      case 'عالي':
        return CartSafetyLevel.high;
      case 'medium':
      case 'متوسط':
        return CartSafetyLevel.medium;
      default:
        return CartSafetyLevel.low;
    }
  }

  CartSafetyLevel _maxLevel(List<CartProductSafetyNote> notes) {
    var max = CartSafetyLevel.low;
    for (final n in notes) {
      if (n.level == CartSafetyLevel.high) return CartSafetyLevel.high;
      if (n.level == CartSafetyLevel.medium) max = CartSafetyLevel.medium;
    }
    return max;
  }

  String _overallFromNotes(List<CartProductSafetyNote> notes) {
    final high = notes.where((n) => n.level == CartSafetyLevel.high).length;
    final med = notes.where((n) => n.level == CartSafetyLevel.medium).length;
    if (high > 0) {
      return appTr(
        'يوجد $high منتج بمستوى خطر مرتفع — راجع التعامل والتخزين قبل الشراء/الاستخدام.',
        '$high product(s) marked high hazard — review handling and storage before purchase/use.',
      );
    }
    if (med > 0) {
      return appTr(
        'يوجد $med منتج يحتاج احتياطات متوسطة (اشتعال/تآكل/غاز…).',
        '$med product(s) need medium precautions (flammable/corrosive/gas…).',
      );
    }
    return appTr(
      'لا تظهر مخاطر واضحة من أسماء المنتجات الحالية — راجع تعليمات المورّد دائماً.',
      'No clear hazards from current product names — always check supplier instructions.',
    );
  }

  bool _matches(String hay, List<String> keys) {
    for (final k in keys) {
      if (hay.contains(k.toLowerCase())) return true;
    }
    return false;
  }
}

class _CartScanItem {
  final String productId;
  final String name;
  final int quantity;
  final String category;
  final String description;
  final String grade;
  final String brand;

  const _CartScanItem({
    required this.productId,
    required this.name,
    required this.quantity,
    this.category = '',
    this.description = '',
    this.grade = '',
    this.brand = '',
  });
}
