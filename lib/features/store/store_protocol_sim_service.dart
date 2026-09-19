import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_service.dart';
import '../ai_advisor/advisor_attachment.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../profile/academic_profile_service.dart';
import 'store_cart_service.dart';
import 'store_catalog_service.dart';
import 'store_protocol_sim_models.dart';

/// محاكاة استرشادية للبروتوكول مقابل سلة المتجر — ليست ضمان نجاح تجريبي.
class StoreProtocolSimService {
  StoreProtocolSimService._();
  static final StoreProtocolSimService instance = StoreProtocolSimService._();

  static const maxBytes = 20 * 1024 * 1024;
  static const maxSizeMb = 20;
  static const inlineCloudMaxBytes = 8 * 1024 * 1024;
  static const maxProtocolChars = 28000;

  static const _disclaimerAr =
      'تنبيه استرشادي من AcadeGate — محاكاة افتراضية تقريبية وليست تجربة معملية حقيقية، '
      'ولا تغني عن مراجعة المشرف أو SDS أو لوائح الكلية.';
  static const _disclaimerEn =
      'Advisory note from AcadeGate — approximate virtual check, not a real lab experiment, '
      'and does not replace supervisor review, SDS, or college rules.';

  Future<({List<int> bytes, String name, String mime})?> pickProtocolFile() async {
    final readFromPath = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'md', 'docx'],
      withData: !readFromPath,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = await _readPlatformFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      throw Exception(appTr(
        'تعذر قراءة الملف — أعد المحاولة',
        'Could not read file — please retry',
      ));
    }
    if (bytes.length > maxBytes) {
      throw Exception(appTr(
        'حجم الملف يجب ألا يتجاوز $maxSizeMb ميجابايت',
        'File size must not exceed $maxSizeMb MB',
      ));
    }
    final mime = _mimeFromName(file.name);
    return (bytes: bytes, name: file.name, mime: mime);
  }

  Future<ProtocolSimResult> analyze({
    required List<StoreCartItem> cartItems,
    String protocolText = '',
    List<int>? fileBytes,
    String? fileName,
    String? fileMime,
  }) async {
    final disclaimer =
        LocaleService.instance.isEnglish ? _disclaimerEn : _disclaimerAr;

    if (cartItems.isEmpty) {
      return ProtocolSimResult(
        error: appTr('العربة فارغة.', 'Cart is empty.'),
        disclaimer: disclaimer,
      );
    }

    final text = protocolText.trim();
    final hasFile = fileBytes != null && fileBytes.isNotEmpty;
    if (text.isEmpty && !hasFile) {
      return ProtocolSimResult(
        error: appTr(
          'أدخل نص البروتوكول أو ارفع ملفاً.',
          'Enter protocol text or upload a file.',
        ),
        disclaimer: disclaimer,
      );
    }

    if (!GeminiAdvisorClient.isAvailable) {
      return ProtocolSimResult(
        error: appTr(
          GeminiAdvisorClient.needsSignInForCloudAi
              ? 'محاكاة البروتوكول تتطلب تسجيل الدخول أو مفتاح Gemini.'
              : 'محاكاة البروتوكول غير متاحة حالياً.',
          GeminiAdvisorClient.needsSignInForCloudAi
              ? 'Protocol simulation requires sign-in or a Gemini key.'
              : 'Protocol simulation is unavailable right now.',
        ),
        disclaimer: disclaimer,
      );
    }

    StoreCatalogBundle? catalog;
    try {
      catalog = await StoreCatalogService.instance.loadPublicCatalog();
    } catch (_) {}

    final enriched = _enrichCart(cartItems, catalog);
    final sourceLabel = hasFile
        ? (fileName ?? 'protocol')
        : appTr('نص ملصق', 'Pasted text');

    try {
      final ai = await _analyzeWithGemini(
        enriched: enriched,
        protocolText: text,
        fileBytes: hasFile ? fileBytes : null,
        fileName: fileName,
        fileMime: fileMime,
        catalog: catalog,
      );
      if (ai != null) {
        return ProtocolSimResult(
          protocolSummary: ai.protocolSummary,
          overallSummary: ai.overallSummary,
          overallLevel: ai.overallLevel,
          feasibility: ai.feasibility,
          risks: ai.risks,
          interactions: ai.interactions,
          gaps: _attachCatalogMatches(ai.gaps, catalog, cartItems),
          quantityChanges: ai.quantityChanges,
          cartNotes: ai.cartNotes,
          fromAi: true,
          modelUsed: ai.modelUsed,
          disclaimer: disclaimer,
          sourceLabel: sourceLabel,
        );
      }
    } catch (e) {
      return ProtocolSimResult(
        error: e.toString(),
        disclaimer: disclaimer,
        sourceLabel: sourceLabel,
      );
    }

    return ProtocolSimResult(
      error: appTr(
        'تعذر تحليل البروتوكول. أعد المحاولة لاحقاً.',
        'Could not analyze the protocol. Please try again later.',
      ),
      disclaimer: disclaimer,
      sourceLabel: sourceLabel,
    );
  }

  List<_ProtoCartItem> _enrichCart(
    List<StoreCartItem> items,
    StoreCatalogBundle? catalog,
  ) {
    final byId = <String, StoreCatalogProduct>{
      if (catalog != null)
        for (final p in catalog.products) p.id: p,
    };
    return items.map((item) {
      final p = byId[item.productId];
      return _ProtoCartItem(
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
        unit: p?.unit ?? '',
      );
    }).toList();
  }

  Future<
      ({
        String protocolSummary,
        String overallSummary,
        ProtocolSimLevel overallLevel,
        ProtocolFeasibility feasibility,
        List<ProtocolSimRisk> risks,
        List<ProtocolSimInteraction> interactions,
        List<ProtocolSimGap> gaps,
        List<ProtocolSimQtyChange> quantityChanges,
        List<ProtocolSimCartNote> cartNotes,
        String? modelUsed,
      })?> _analyzeWithGemini({
    required List<_ProtoCartItem> enriched,
    required String protocolText,
    List<int>? fileBytes,
    String? fileName,
    String? fileMime,
    StoreCatalogBundle? catalog,
  }) async {
    final isEn = LocaleService.instance.isEnglish;
    String researchHint = '';
    try {
      final profile = await AcademicProfileService.instance.loadProfile();
      researchHint = [
        if ((profile?.specialization ?? '').trim().isNotEmpty)
          profile!.specialization.trim(),
        if ((profile?.researchInterest ?? '').trim().isNotEmpty)
          profile!.researchInterest.trim(),
      ].join(' — ');
    } catch (_) {}

    final catalogLines = enriched.asMap().entries.map((e) {
      final i = e.key + 1;
      final p = e.value;
      final desc = p.description.length > 160
          ? p.description.substring(0, 160)
          : p.description;
      return '$i) id=${p.productId} | ${p.name} | qty=${p.quantity} | '
          'unit=${p.unit} | cat=${p.category} | grade=${p.grade} | brand=${p.brand} | '
          'desc=$desc';
    }).join('\n');

    // عيّنة مختصرة من الكتالوج لمساعدة الاقتراحات (بدون اختراع معرفات).
    final catalogHints = _catalogHintLines(catalog, limit: 60);

    final systemPrompt = isEn
        ? '''
You are a research-lab purchasing advisor for Egyptian graduate students.
Given an experiment PROTOCOL and a STORE CART, produce an ADVISORY virtual compatibility check.
This is NOT a real physical simulation and NOT a guarantee of experimental success.

Return ONLY valid JSON (no markdown):
{
  "overallLevel": "low"|"medium"|"high",
  "feasibility": "likely"|"uncertain"|"unlikely",
  "protocolSummary": "2-4 short sentences summarizing the protocol steps/materials",
  "overallSummary": "2-4 short sentences: cart vs protocol fit, key risks, next actions",
  "risks": [
    {"title":"...", "severity":"low|medium|high", "detail":"...", "relatedProductIds":["cart productId if relevant"]}
  ],
  "interactions": [
    {"materials":["A","B"], "issue":"possible unintended interaction/incompatibility", "mitigation":"..."}
  ],
  "gaps": [
    {"needed":"missing material/reagent/consumable", "reason":"why needed", "searchQuery":"2-6 English or Arabic keywords to search the store"}
  ],
  "quantityChanges": [
    {"productId":"must be a cart productId", "suggestedQty":2, "reason":"..."}
  ],
  "cartNotes": [
    {"productId":"cart productId", "note":"how this item maps to the protocol"}
  ]
}
Rules:
- Be practical and conservative. Prefer uncertain over false certainty.
- Only use productId values that appear in the cart list.
- Do NOT invent SDS numbers, exact yields, or brand-specific certificates.
- Flag likely failure modes, missing materials, and unintended interactions when evidence in the protocol/cart supports them.
- quantityChanges: only when protocol volumes/replicates clearly imply different qty; suggestedQty must be >= 1.
- gaps.searchQuery should be useful for catalog search.
- Respond in English.
'''
        : '''
أنت مستشار شراء مختبري لباحثي الدراسات العليا في مصر.
أمامك بروتوكول تجربة وسلة متجر. قدّم فحص توافق افتراضي استرشادي.
هذه ليست محاكاة فيزيائية حقيقية وليست ضمان نجاح تجريبي.

أعد JSON صالحاً فقط (بدون markdown):
{
  "overallLevel": "low"|"medium"|"high",
  "feasibility": "likely"|"uncertain"|"unlikely",
  "protocolSummary": "جملتان إلى أربع تلخّص خطوات/مواد البروتوكول",
  "overallSummary": "جملتان إلى أربع: ملاءمة السلة، أهم المخاطر، ماذا يفعل الباحث",
  "risks": [
    {"title":"...", "severity":"low|medium|high", "detail":"...", "relatedProductIds":["معرّف منتج من السلة إن انطبق"]}
  ],
  "interactions": [
    {"materials":["أ","ب"], "issue":"تفاعل/عدم توافق محتمل", "mitigation":"..."}
  ],
  "gaps": [
    {"needed":"مادة ناقصة", "reason":"لماذا تلزم", "searchQuery":"كلمتان إلى ست للبحث في المتجر"}
  ],
  "quantityChanges": [
    {"productId":"يجب أن يكون من السلة", "suggestedQty":2, "reason":"..."}
  ],
  "cartNotes": [
    {"productId":"من السلة", "note":"كيف يرتبط الصنف بالبروتوكول"}
  ]
}
قواعد:
- كن عملياً ومحافظاً. فضّل uncertain على اليقين الكاذب.
- استخدم فقط productId الظاهر في قائمة السلة.
- لا تخترع أرقام SDS أو نسب نجاح أو شهادات غير موجودة.
- أبرز احتمالات الفشل والنواقص والتفاعلات غير المقصودة عند وجود إشارات في البروتوكول/السلة.
- quantityChanges فقط عند دلالة واضحة على كميات/مكررات؛ suggestedQty >= 1.
- gaps.searchQuery مفيد للبحث في الكتالوج.
- اكتب بالعربية.
''';

    var effectiveText = protocolText;
    final attachments = <GeminiInlinePart>[];
    if (fileBytes != null && fileBytes.isNotEmpty) {
      final name = fileName ?? 'protocol.pdf';
      final mime = (fileMime ?? _mimeFromName(name)).trim();
      final isTextFile = mime.startsWith('text/') ||
          name.toLowerCase().endsWith('.txt') ||
          name.toLowerCase().endsWith('.md');

      if (isTextFile) {
        final decoded = utf8.decode(fileBytes, allowMalformed: true).trim();
        if (effectiveText.isEmpty && decoded.isNotEmpty) {
          effectiveText = decoded;
        }
      } else {
        final useStorage = GeminiAdvisorClient.canUseCloudBackend &&
            (!GeminiAdvisorClient.hasLocalKey ||
                fileBytes.length > inlineCloudMaxBytes);
        if (useStorage && fileBytes.length > inlineCloudMaxBytes) {
          final path = await _uploadProtocol(
            bytes: fileBytes,
            fileName: name,
            mime: mime,
          );
          attachments.add(GeminiInlinePart(
            mimeType: mime,
            base64Data: '',
            fileName: name,
            storagePath: path,
          ));
        } else {
          attachments.add(GeminiInlinePart(
            mimeType: mime,
            base64Data: base64Encode(fileBytes),
            fileName: name,
          ));
        }
      }
    }

    final clippedText = effectiveText.length > maxProtocolChars
        ? effectiveText.substring(0, maxProtocolChars)
        : effectiveText;

    final userParts = <String>[
      if (researchHint.isNotEmpty)
        appTr(
          'سياق البحث (إن وُجد): $researchHint',
          'Research context (if any): $researchHint',
        ),
      appTr('منتجات العربة:', 'Cart products:'),
      catalogLines,
      if (catalogHints.isNotEmpty) ...[
        appTr(
          'عيّنة من كتالوج المتجر (للاستئناس عند اقتراح searchQuery فقط — لا تخترع معرفات):',
          'Store catalog sample (for searchQuery hints only — do not invent IDs):',
        ),
        catalogHints,
      ],
      if (clippedText.isNotEmpty) ...[
        appTr('نص البروتوكول:', 'Protocol text:'),
        clippedText,
      ],
      if (attachments.isNotEmpty)
        appTr(
          'حلّل ملف البروتوكول المرفق مع السلة وأعد JSON المطلوب.',
          'Analyze the attached protocol file with the cart and return the required JSON.',
        )
      else
        appTr(
          'قارن البروتوكول بالسلة وأعد JSON المطلوب.',
          'Compare the protocol to the cart and return the required JSON.',
        ),
    ];

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: systemPrompt,
      userMessage: userParts.join('\n'),
      attachments: attachments,
      maxOutputTokens: 6144,
    );
    if (!result.isSuccess) {
      throw Exception(
        result.error ??
            appTr('تعذر تحليل البروتوكول', 'Could not analyze protocol'),
      );
    }

    final parsed = _parseAiJson(result.text!, enriched);
    if (parsed == null) return null;
    return (
      protocolSummary: parsed.protocolSummary,
      overallSummary: parsed.overallSummary,
      overallLevel: parsed.overallLevel,
      feasibility: parsed.feasibility,
      risks: parsed.risks,
      interactions: parsed.interactions,
      gaps: parsed.gaps,
      quantityChanges: parsed.quantityChanges,
      cartNotes: parsed.cartNotes,
      modelUsed: result.modelUsed,
    );
  }

  String _catalogHintLines(StoreCatalogBundle? catalog, {int limit = 60}) {
    if (catalog == null || catalog.products.isEmpty) return '';
    final list = catalog.products.take(limit).map((p) {
      final bit = [
        p.name,
        if (p.brand.isNotEmpty) p.brand,
        if (p.grade.isNotEmpty) p.grade,
      ].join(' · ');
      return '- $bit';
    });
    return list.join('\n');
  }

  List<ProtocolSimGap> _attachCatalogMatches(
    List<ProtocolSimGap> gaps,
    StoreCatalogBundle? catalog,
    List<StoreCartItem> cart,
  ) {
    if (catalog == null) return gaps;
    final exclude = cart.map((e) => e.productId).toSet();
    return gaps
        .map(
          (g) => g.copyWith(
            catalogMatches: findCatalogMatches(
              catalog: catalog,
              query: g.searchQuery.isNotEmpty ? g.searchQuery : g.needed,
              excludeIds: exclude,
              limit: 4,
            ),
          ),
        )
        .toList();
  }

  /// بحث محلي بسيط في الكتالوج لاقتراح بدائل.
  List<StoreCatalogProduct> findCatalogMatches({
    required StoreCatalogBundle catalog,
    required String query,
    Set<String> excludeIds = const {},
    int limit = 5,
  }) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[\s,;/|+\-_()\[\]{}]+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .toSet()
        .toList();
    if (tokens.isEmpty) return const [];

    final scored = <({StoreCatalogProduct p, int score})>[];
    for (final p in catalog.products) {
      if (excludeIds.contains(p.id)) continue;
      if (!p.inStock && p.price <= 0) continue;
      final hay = [
        p.name,
        p.brand,
        p.grade,
        p.description,
        p.categoryCanonical,
        p.sku,
      ].join(' ').toLowerCase();
      var score = 0;
      for (final t in tokens) {
        if (hay.contains(t)) score += t.length >= 4 ? 3 : 2;
      }
      if (score <= 0) continue;
      if (p.isVerifiedSeller) score += 1;
      if (p.orderCount > 0) score += 1;
      scored.add((p: p, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.p).toList();
  }

  ({
    String protocolSummary,
    String overallSummary,
    ProtocolSimLevel overallLevel,
    ProtocolFeasibility feasibility,
    List<ProtocolSimRisk> risks,
    List<ProtocolSimInteraction> interactions,
    List<ProtocolSimGap> gaps,
    List<ProtocolSimQtyChange> quantityChanges,
    List<ProtocolSimCartNote> cartNotes,
  })? _parseAiJson(String raw, List<_ProtoCartItem> cart) {
    final jsonStr = _extractJson(raw);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr);
      if (map is! Map) return null;
      final byId = {for (final c in cart) c.productId: c};

      final risks = <ProtocolSimRisk>[];
      final riskList = map['risks'];
      if (riskList is List) {
        for (final r in riskList) {
          if (r is! Map) continue;
          risks.add(ProtocolSimRisk(
            title: r['title']?.toString() ?? '',
            severity: r['severity']?.toString() ?? 'medium',
            detail: r['detail']?.toString() ?? '',
            relatedProductIds: _stringList(r['relatedProductIds']),
          ));
        }
      }

      final interactions = <ProtocolSimInteraction>[];
      final intList = map['interactions'];
      if (intList is List) {
        for (final r in intList) {
          if (r is! Map) continue;
          interactions.add(ProtocolSimInteraction(
            materials: _stringList(r['materials']),
            issue: r['issue']?.toString() ?? '',
            mitigation: r['mitigation']?.toString() ?? '',
          ));
        }
      }

      final gaps = <ProtocolSimGap>[];
      final gapList = map['gaps'];
      if (gapList is List) {
        for (final r in gapList) {
          if (r is! Map) continue;
          final needed = (r['needed']?.toString() ?? '').trim();
          if (needed.isEmpty) continue;
          gaps.add(ProtocolSimGap(
            needed: needed,
            reason: r['reason']?.toString() ?? '',
            searchQuery: r['searchQuery']?.toString() ?? needed,
          ));
        }
      }

      final qty = <ProtocolSimQtyChange>[];
      final qtyList = map['quantityChanges'];
      if (qtyList is List) {
        for (final r in qtyList) {
          if (r is! Map) continue;
          final id = r['productId']?.toString() ?? '';
          final item = byId[id];
          if (item == null) continue;
          final suggested = int.tryParse(r['suggestedQty']?.toString() ?? '') ??
              item.quantity;
          if (suggested < 1 || suggested == item.quantity) continue;
          qty.add(ProtocolSimQtyChange(
            productId: id,
            productName: item.name,
            currentQty: item.quantity,
            suggestedQty: suggested,
            reason: r['reason']?.toString() ?? '',
          ));
        }
      }

      final notes = <ProtocolSimCartNote>[];
      final noteList = map['cartNotes'];
      if (noteList is List) {
        for (final r in noteList) {
          if (r is! Map) continue;
          final id = r['productId']?.toString() ?? '';
          final item = byId[id];
          final note = (r['note']?.toString() ?? '').trim();
          if (note.isEmpty) continue;
          notes.add(ProtocolSimCartNote(
            productId: id.isEmpty ? (item?.productId ?? '') : id,
            productName: item?.name ?? id,
            note: note,
          ));
        }
      }

      return (
        protocolSummary: map['protocolSummary']?.toString() ?? '',
        overallSummary: map['overallSummary']?.toString() ?? '',
        overallLevel: _levelFrom(map['overallLevel']?.toString()),
        feasibility: _feasibilityFrom(map['feasibility']?.toString()),
        risks: risks,
        interactions: interactions,
        gaps: gaps,
        quantityChanges: qty,
        cartNotes: notes,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _uploadProtocol({
    required List<int> bytes,
    required String fileName,
    required String mime,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr(
        'سجّل الدخول لرفع ملفات البروتوكول الكبيرة',
        'Sign in to upload large protocol files',
      ));
    }
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path =
        'uploads/${user.uid}/protocol_sim/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: mime),
    );
    return path;
  }

  Future<List<int>?> _readPlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }
    final path = file.path;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      final ioFile = File(path);
      if (await ioFile.exists()) {
        return ioFile.readAsBytes();
      }
    }
    return null;
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return 'text/plain';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
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

  ProtocolSimLevel _levelFrom(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'high':
      case 'مرتفع':
      case 'عالي':
        return ProtocolSimLevel.high;
      case 'low':
      case 'منخفض':
        return ProtocolSimLevel.low;
      default:
        return ProtocolSimLevel.medium;
    }
  }

  ProtocolFeasibility _feasibilityFrom(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'likely':
      case 'محتمل':
      case 'مرجّح':
      case 'مرجح':
        return ProtocolFeasibility.likely;
      case 'unlikely':
      case 'غير محتمل':
      case 'ضعيف':
        return ProtocolFeasibility.unlikely;
      default:
        return ProtocolFeasibility.uncertain;
    }
  }
}

class _ProtoCartItem {
  final String productId;
  final String name;
  final int quantity;
  final String category;
  final String description;
  final String grade;
  final String brand;
  final String unit;

  const _ProtoCartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    this.category = '',
    this.description = '',
    this.grade = '',
    this.brand = '',
    this.unit = '',
  });
}
