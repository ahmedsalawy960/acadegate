import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../ai_advisor/gemini_advisor_client.dart';
import '../../../core/locale/app_translate.dart';
import '../import/store_product_search_service.dart';
import '../store_catalog_service.dart';
import '../store_categories.dart';

class StoreAiCompareOffer {
  final String name;
  final String storeName;
  final num price;
  final String brand;
  final String sku;
  final String description;
  final String? productId;
  final String? sourceUrl;
  final String? imageUrl;
  final StoreCatalogProduct? catalogProduct;
  final bool isCurrent;

  const StoreAiCompareOffer({
    required this.name,
    required this.storeName,
    this.price = 0,
    this.brand = '',
    this.sku = '',
    this.description = '',
    this.productId,
    this.sourceUrl,
    this.imageUrl,
    this.catalogProduct,
    this.isCurrent = false,
  });
}

class StoreAiCompareRow {
  final StoreAiCompareOffer offer;
  final String verdict;
  final String model;
  final String notes;
  final String confidence;

  const StoreAiCompareRow({
    required this.offer,
    required this.verdict,
    this.model = '',
    this.notes = '',
    this.confidence = '',
  });

  bool get isSame => verdict == 'same';
  bool get isRelated => verdict == 'related';
}

class StoreAiCompareResult {
  final String deviceLabel;
  final String summary;
  final List<StoreAiCompareRow> same;
  final List<StoreAiCompareRow> related;
  final bool usedAi;
  final String? notice;

  const StoreAiCompareResult({
    required this.deviceLabel,
    required this.summary,
    required this.same,
    required this.related,
    required this.usedAi,
    this.notice,
  });
}

/// يجمع عروض نفس الجهاز من الكتالوج ومتاجر الموردين، ثم يميّز تطابق الاسم عبر الذكاء.
class StoreAiCompareService {
  StoreAiCompareService._();
  static final StoreAiCompareService instance = StoreAiCompareService._();

  Future<StoreAiCompareResult> compare({
    required String query,
    String brand = '',
    String categoryTitle = '',
    String description = '',
    String? excludeProductId,
    StoreAiCompareOffer? current,
    void Function(StoreAiCompareResult preview)? onPreview,
  }) async {
    final name = query.trim();
    if (name.length < 2) {
      throw Exception(appTr(
        'اكتب اسم الجهاز أو الموديل.',
        'Enter a device name or model.',
      ));
    }

    final offers = await _collectOffers(
      name: name,
      brand: brand,
      categoryTitle: categoryTitle,
      description: description,
      excludeProductId: excludeProductId,
      current: current,
    );

    final preview = _localFallback(name: name, brand: brand, offers: offers);
    onPreview?.call(preview);

    final shortQuery = _shortQuery(name, brand);
    if (shortQuery.length >= 2) {
      try {
        final remote = await StoreProductSearchService.instance
            .searchSupplierSites(shortQuery, perSupplier: 2)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => const <StoreSearchHit>[],
            );
        _appendRemote(offers, remote);
      } catch (e) {
        debugPrint('store AI compare remote search: $e');
      }
    }

    if (offers.length <= 1) {
      return StoreAiCompareResult(
        deviceLabel: name,
        summary: appTr(
          'لم نجد عروضاً أخرى لهذا الجهاز لدى باقي الموردين حالياً.',
          'No other supplier offers were found for this device yet.',
        ),
        same: [
          if (current != null)
            StoreAiCompareRow(offer: current, verdict: 'same', model: brand),
        ],
        related: const [],
        usedAi: false,
      );
    }

    final ai = await _askAi(
      name: name,
      brand: brand,
      description: description,
      offers: offers.take(10).toList(),
    );
    if (ai != null) return ai;

    return _localFallback(name: name, brand: brand, offers: offers);
  }

  Future<List<StoreAiCompareOffer>> _collectOffers({
    required String name,
    required String brand,
    required String categoryTitle,
    required String description,
    required String? excludeProductId,
    required StoreAiCompareOffer? current,
  }) async {
    final catalog = await StoreCatalogService.instance.loadPublicCatalog();

    final titles = _categoryTitles(categoryTitle);
    final needle = _tokens('$name $brand');
    final ranked = <({StoreCatalogProduct product, int score})>[];
    for (final product in catalog.products) {
      if (excludeProductId != null && product.id == excludeProductId) continue;
      final nameHay = _tokens(
        '${product.name} ${product.brand} ${product.sku}',
      );
      final descHay = _tokens(product.description);
      final nameOverlap = needle.intersection(nameHay).length;
      final descOverlap = needle.intersection(descHay).length;
      final cat = product.categoryCanonical.isNotEmpty
          ? product.categoryCanonical
          : product.categoryRaw;
      final sameCat = titles.isNotEmpty &&
          (titles.contains(cat) ||
              titles.contains(storeCategoryLegacyAliases[cat] ?? cat));
      if (!sameCat && nameOverlap == 0 && descOverlap == 0) continue;
      final score = nameOverlap * 5 + descOverlap + (sameCat ? 1 : 0);
      ranked.add((product: product, score: score));
    }
    final currentStore = (current?.storeName ?? '').trim().toLowerCase();
    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      if (currentStore.isEmpty) return 0;
      final aOther = a.product.storeName.trim().toLowerCase() != currentStore;
      final bOther = b.product.storeName.trim().toLowerCase() != currentStore;
      if (aOther == bOther) return 0;
      return aOther ? -1 : 1;
    });

    final offers = <StoreAiCompareOffer>[
      if (current != null) current,
    ];
    final seen = <String>{
      if (current != null) _key(current.name, current.storeName, current.sourceUrl),
    };

    void addOffer(StoreAiCompareOffer offer) {
      final key = _key(offer.name, offer.storeName, offer.sourceUrl);
      if (seen.contains(key)) return;
      seen.add(key);
      offers.add(offer);
    }

    for (final row in ranked.take(8)) {
      final p = row.product;
      addOffer(
        StoreAiCompareOffer(
          name: p.name,
          storeName: p.storeName,
          price: p.price,
          brand: p.brand,
          sku: p.sku,
          description: _clip(p.description),
          productId: p.id,
          sourceUrl: p.sourceUrl,
          imageUrl: p.imageUrl,
          catalogProduct: p,
        ),
      );
    }

    return offers;
  }

  void _appendRemote(List<StoreAiCompareOffer> offers, List<StoreSearchHit> remote) {
    final seen = <String>{
      for (final offer in offers) _key(offer.name, offer.storeName, offer.sourceUrl),
    };
    for (final hit in remote.take(4)) {
      final offer = StoreAiCompareOffer(
        name: hit.name,
        storeName: hit.storeName,
        price: hit.price,
        description: _clip(hit.description),
        productId: hit.productId,
        sourceUrl: hit.sourceUrl,
        imageUrl: hit.imageUrl,
      );
      final key = _key(offer.name, offer.storeName, offer.sourceUrl);
      if (!seen.add(key)) continue;
      offers.add(offer);
    }
  }

  Future<StoreAiCompareResult?> _askAi({
    required String name,
    required String brand,
    required String description,
    required List<StoreAiCompareOffer> offers,
  }) async {
    if (!GeminiAdvisorClient.isAvailable) return null;

    final lines = <String>[];
    for (var i = 0; i < offers.length; i++) {
      final o = offers[i];
      final price = o.price > 0 ? '${o.price}' : 'unknown';
      lines.add(
        '[$i] name=${_clip(o.name, 140)} | brand=${o.brand} | sku=${o.sku} | '
        'price=$price | store=${o.storeName} | '
        'note=${_clip(o.description, 160)}'
        '${o.isCurrent ? ' | CURRENT' : ''}',
      );
    }

    const system = '''
You compare scientific/lab devices sold by different suppliers.
The same commercial device often has slightly different titles (Arabic vs English, word order, extra words like "جهاز" or "analyzer").
Decide if each candidate is the SAME model as the target, a RELATED model (same family, different model number or spec), or DIFFERENT.
Do not treat a whole category as the same device.
Return ONLY JSON:
{"deviceLabel":"","summary":"Arabic, 2 sentences, mention the cheapest same-device offer if a price exists","items":[{"i":0,"verdict":"same|related|different","model":"","notes":"Arabic short note","confidence":"high|medium|low"}]}
The CURRENT item is the device the user selected. Mark it verdict=same.
''';

    final user = '''
Target device: $name
Brand: $brand
Description: ${_clip(description, 400)}

Candidates:
${lines.join('\n')}
''';

    try {
      final result = await GeminiAdvisorClient.instance.generateResult(
        systemPrompt: system,
        userMessage: user,
        maxOutputTokens: 2048,
      );
      if (!result.isSuccess || result.text == null) return null;
      final parsed = _parse(result.text!);
      if (parsed == null) return null;
      return _fromAi(name: name, offers: offers, parsed: parsed);
    } catch (e) {
      debugPrint('store AI compare: $e');
      return null;
    }
  }

  StoreAiCompareResult? _fromAi({
    required String name,
    required List<StoreAiCompareOffer> offers,
    required Map<String, dynamic> parsed,
  }) {
    final items = parsed['items'];
    if (items is! List || items.isEmpty) return null;
    final same = <StoreAiCompareRow>[];
    final related = <StoreAiCompareRow>[];
    final seen = <int>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final i = raw['i'] is num ? (raw['i'] as num).toInt() : int.tryParse('${raw['i']}');
      if (i == null || i < 0 || i >= offers.length || !seen.add(i)) continue;
      final verdict = raw['verdict']?.toString() ?? 'different';
      final row = StoreAiCompareRow(
        offer: offers[i],
        verdict: verdict == 'same' || verdict == 'related' ? verdict : 'different',
        model: raw['model']?.toString() ?? '',
        notes: raw['notes']?.toString() ?? '',
        confidence: raw['confidence']?.toString() ?? '',
      );
      if (row.isSame) {
        same.add(row);
      } else if (row.isRelated) {
        related.add(row);
      }
    }
    if (same.isEmpty && related.isEmpty) return null;
    _sortByPrice(same);
    _sortByPrice(related);
    final label = (parsed['deviceLabel'] ?? '').toString().trim();
    final summary = (parsed['summary'] ?? '').toString().trim();
    return StoreAiCompareResult(
      deviceLabel: label.isNotEmpty ? label : name,
      summary: summary.isNotEmpty
          ? summary
          : appTr(
              'رتّبنا العروض التي تطابق نفس الجهاز، والأقل سعراً أولاً.',
              'Matching offers for the same device are listed with the lowest price first.',
            ),
      same: same,
      related: related,
      usedAi: true,
    );
  }

  StoreAiCompareResult _localFallback({
    required String name,
    required String brand,
    required List<StoreAiCompareOffer> offers,
  }) {
    final needle = _tokens('$name $brand');
    final models = _modelTokens('$name $brand');
    final same = <StoreAiCompareRow>[];
    final related = <StoreAiCompareRow>[];
    for (final offer in offers) {
      if (offer.isCurrent) {
        same.add(StoreAiCompareRow(
          offer: offer,
          verdict: 'same',
          model: brand,
          notes: appTr('العرض الذي اخترته', 'The offer you selected'),
        ));
        continue;
      }
      final hay = _tokens('${offer.name} ${offer.brand} ${offer.sku}');
      final shared = needle.intersection(hay);
      final sharedModels = models.intersection(_modelTokens('${offer.name} ${offer.sku}'));
      if (sharedModels.isNotEmpty || shared.length >= 2) {
        same.add(StoreAiCompareRow(
          offer: offer,
          verdict: 'same',
          model: offer.brand,
          notes: appTr(
            'تطابق تقريبي في الاسم أو الموديل',
            'Approximate name or model match',
          ),
          confidence: 'low',
        ));
      } else if (shared.isNotEmpty) {
        related.add(StoreAiCompareRow(
          offer: offer,
          verdict: 'related',
          model: offer.brand,
          notes: appTr(
            'قريب من الجهاز، وقد يختلف الموديل',
            'Close to this device; the model may differ',
          ),
          confidence: 'low',
        ));
      }
    }
    _sortByPrice(same);
    _sortByPrice(related);
    return StoreAiCompareResult(
      deviceLabel: name,
      summary: appTr(
        'هذه مطابقة بالاسم والموديل، والأقل سعراً أولاً.',
        'This matches by name and model, with the lowest price first.',
      ),
      same: same,
      related: related,
      usedAi: false,
      notice: GeminiAdvisorClient.isAvailable
          ? null
          : appTr(
              'سجّل الدخول لمطابقة أدق عندما يختلف اسم الجهاز قليلاً بين الموردين.',
              'Sign in for a closer match when suppliers use slightly different names.',
            ),
    );
  }

  void _sortByPrice(List<StoreAiCompareRow> rows) {
    rows.sort((a, b) {
      final ap = a.offer.price;
      final bp = b.offer.price;
      if (ap <= 0 && bp <= 0) return 0;
      if (ap <= 0) return 1;
      if (bp <= 0) return -1;
      return ap.compareTo(bp);
    });
  }

  Map<String, dynamic>? _parse(String raw) {
    var t = raw.trim();
    if (!t.startsWith('{')) {
      final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
          .firstMatch(t);
      if (fence != null) t = fence.group(1)?.trim() ?? t;
      final start = t.indexOf('{');
      final end = t.lastIndexOf('}');
      if (start >= 0 && end > start) t = t.substring(start, end + 1);
    }
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Set<String> _categoryTitles(String categoryTitle) {
    final trimmed = categoryTitle.trim();
    if (trimmed.isEmpty) return const {};
    final category = storeCategoryByTitle(trimmed);
    final titles = category != null
        ? storeCategoryQueryTitles(category)
        : <String>[trimmed];
    return titles.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
  }

  String _shortQuery(String name, String brand) {
    final models = _modelTokens('$brand $name').take(4).join(' ');
    if (models.length >= 2) return models;
    final words = _tokens(name).take(4).join(' ');
    return words;
  }

  Set<String> _modelTokens(String raw) {
    final out = <String>{};
    for (final token in _tokens(raw)) {
      final latin = RegExp(r'[a-z0-9]').hasMatch(token);
      if (!latin) continue;
      if (token.contains(RegExp(r'\d')) || token.length >= 5) out.add(token);
    }
    return out;
  }

  Set<String> _tokens(String raw) {
    final folded = raw
        .toLowerCase()
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
    const stop = {
      'the', 'and', 'for', 'with', 'from', 'plus', 'touch', 'device', 'devices',
      'جهاز', 'اجهزه', 'من', 'في', 'علي', 'مع', 'او', 'الي', 'هذا', 'هذه',
      'مواصفات', 'ضمان',
    };
    final out = <String>{};
    for (final part in folded.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))) {
      var token = part.trim();
      if (token.startsWith('ال') && token.length > 4) token = token.substring(2);
      if (token.length < 3 || stop.contains(token)) continue;
      out.add(token);
    }
    return out;
  }

  String _key(String name, String store, String? url) {
    final link = (url ?? '').trim().toLowerCase();
    if (link.isNotEmpty) return link;
    return '${store.trim().toLowerCase()}|${name.trim().toLowerCase()}';
  }

  String _clip(String raw, [int max = 180]) {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= max) return text;
    return text.substring(0, max);
  }
}
