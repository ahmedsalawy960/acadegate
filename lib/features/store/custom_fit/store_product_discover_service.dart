import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/callable_http_client.dart';
import '../../../core/locale/app_translate.dart';
import '../import/egypt_store_suppliers_catalog.dart';
import '../import/store_product_search_service.dart';
import '../store_catalog_service.dart';
import 'store_custom_fit_matcher.dart';
import 'store_product_discover_models.dart';

/// يمسح كتالوج التطبيق + متاجر الموردين (Woo) + إشارات بحث على الإنترنت
/// حسب وصف العميل — بدون اشتراكات CAD.
class StoreProductDiscoverService {
  StoreProductDiscoverService._();
  static final StoreProductDiscoverService instance =
      StoreProductDiscoverService._();

  Future<ProductDiscoverResult> discover({
    required String description,
    int appLimit = 24,
    int supplierPerStore = 6,
  }) async {
    final text = description.trim();
    if (text.length < 3) {
      return ProductDiscoverResult(
        error: appTr(
          'اكتب وصفاً أوضح للمنتج أو المواصفات.',
          'Enter a clearer product description or specs.',
        ),
      );
    }

    final keywords = _keywords(text);
    // WooCommerce يفشل غالباً مع فقرات طويلة — استخدم استعلام متجر قصير
    final storeQuery = _storeSearchQuery(text, keywords);

    final appFuture = _searchAppCatalog(text, keywords, limit: appLimit);
    final cloudFuture = FirebaseAuth.instance.currentUser == null
        ? Future.value(<String, dynamic>{})
        : _searchSuppliersAndWeb(
            description: text,
            keywords: keywords,
            storeQuery: storeQuery,
            perSupplier: supplierPerStore,
          );

    // Fallback: client-side Woo (Windows/Android) if CF fails
    final localRemoteFuture = (!kIsWeb)
        ? StoreProductSearchService.instance.search(
            storeQuery,
            localLimit: 1,
            remotePerSupplier: supplierPerStore,
          )
        : Future.value(const StoreProductSearchResult());

    final appHits = await appFuture;
    Map<String, dynamic> cloud = const {};
    try {
      cloud = await cloudFuture;
    } catch (_) {
      cloud = const {};
    }

    var supplierHits = _parseRemote(cloud['remote']);
    final webHints = _parseWeb(cloud['webHints']);
    var webLinks = _parseWeb(cloud['webSearchLinks']);

    if (supplierHits.isEmpty && !kIsWeb) {
      try {
        final fallback = await localRemoteFuture;
        supplierHits = fallback.remote
            .map(
              (h) => ProductDiscoverHit(
                name: h.name,
                storeName: h.storeName,
                description: h.description,
                category: h.category,
                price: h.price,
                imageUrl: h.imageUrl,
                sourceUrl: h.sourceUrl,
                productId: h.productId,
                createdBy: h.createdBy,
                supplierId: h.supplierId,
                website: h.website,
                email: h.email,
                phone: h.phone,
                fromRemoteSite: true,
                score: 50,
                sourceLabel: 'supplier',
              ),
            )
            .toList();
      } catch (_) {}
    }

    if (webLinks.isEmpty) {
      final q = Uri.encodeComponent(storeQuery);
      webLinks = [
        ProductDiscoverWebLink(
          title: appTr('Google — بحث منتجات', 'Google — product search'),
          url: 'https://www.google.com/search?q=$q+lab+OR+scientific+supply',
          snippet: appTr(
            'افتح نتائج البحث العامة على الإنترنت',
            'Open general web search results',
          ),
          source: 'google',
        ),
        ProductDiscoverWebLink(
          title: 'Google Shopping',
          url: 'https://www.google.com/search?tbm=shop&q=$q',
          snippet: appTr('مقارنة أسعار', 'Compare prices'),
          source: 'google_shopping',
        ),
      ];
    }

    // Deduplicate supplier vs app by URL/name
    final appKeys = <String>{
      for (final h in appHits)
        if ((h.sourceUrl ?? '').isNotEmpty)
          h.sourceUrl!.toLowerCase()
        else
          '${h.supplierId}|${h.name.toLowerCase()}',
    };
    supplierHits = supplierHits.where((h) {
      final key = (h.sourceUrl ?? '').isNotEmpty
          ? h.sourceUrl!.toLowerCase()
          : '${h.supplierId}|${h.name.toLowerCase()}';
      return !appKeys.contains(key);
    }).toList();

    final wooCount = egyptStoreSuppliersWithProductSync
        .where((s) => (s.wooCommerceBaseUrl ?? '').isNotEmpty)
        .length;

    return ProductDiscoverResult(
      searchQuery: cloud['searchQuery']?.toString() ?? storeQuery,
      keywords: keywords,
      appHits: appHits,
      supplierHits: supplierHits,
      webHints: webHints,
      webSearchLinks: webLinks,
      note: cloud['note']?.toString() ??
          appTr(
            'البحث في: كتالوج AcadeGate + $wooCount متاجر WooCommerce مباشرة. '
            'باقي الموردين المستوردين دليل اتصال فقط (بدون فهرس منتجات حي). '
            'والإنترنت = روابط بحث عامة — ليست زيارة كل مواقع الموردين. راجع التوافق قبل الشراء.',
            'Searches: AcadeGate catalog + $wooCount live WooCommerce stores. '
            'Other imported suppliers are contact listings only (no live product index). '
            'Web results are public search links — not a crawl of every supplier site. Verify fit before buying.',
          ),
    );
  }

  Future<List<ProductDiscoverHit>> _searchAppCatalog(
    String text,
    List<String> keywords, {
    required int limit,
  }) async {
    final catalog = await StoreCatalogService.instance.loadPublicCatalog();
    final ranked = StoreCustomFitMatcher.instance.rankCandidates(
      catalog: catalog.products,
      specsText: text,
      limit: limit * 2,
    );

    final hits = <ProductDiscoverHit>[];
    for (final p in ranked) {
      final hay = [
        p.name,
        p.description,
        p.brand,
        p.grade,
        p.categoryCanonical,
        p.sku,
      ].join(' ').toLowerCase();
      var score = 10;
      for (final k in keywords) {
        if (hay.contains(k)) score += k.length >= 4 ? 4 : 2;
      }
      hits.add(
        ProductDiscoverHit(
          name: p.name,
          storeName: p.storeName,
          description: p.description,
          category: p.categoryCanonical.isNotEmpty
              ? p.categoryCanonical
              : p.categoryRaw,
          price: p.price,
          imageUrl: p.imageUrl,
          sourceUrl: p.sourceUrl,
          productId: p.id,
          createdBy: p.createdBy,
          supplierId: p.supplierId ?? '',
          website: p.website,
          email: p.email,
          phone: p.phone,
          fromAppCatalog: true,
          score: score,
          sourceLabel: 'app',
        ),
      );
      if (hits.length >= limit) break;
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits;
  }

  Future<Map<String, dynamic>> _searchSuppliersAndWeb({
    required String description,
    required List<String> keywords,
    required String storeQuery,
    required int perSupplier,
  }) async {
    final suppliers = egyptStoreSuppliersWithProductSync
        .where((s) => (s.wooCommerceBaseUrl ?? '').isNotEmpty)
        .map(
          (s) => {
            'id': s.id,
            'nameAr': s.nameAr,
            'nameEn': s.nameEn,
            'baseUrl': s.wooCommerceBaseUrl,
            'website': s.website,
            'email': s.email,
            'phone': s.phone,
          },
        )
        .toList();

    final payload = {
      'description': description,
      'keywords': keywords.take(8).toList(),
      'storeQuery': storeQuery,
      'suppliers': suppliers,
      'perSupplier': perSupplier,
    };

    if (_preferHttpCallable) {
      return CallableHttpClient.call(
        name: 'storeProductDiscover',
        data: payload,
        timeout: const Duration(seconds: 90),
        callableProtocol: true,
      );
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'storeProductDiscover',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );
      final res = await callable.call<Map<String, dynamic>>(payload);
      return Map<String, dynamic>.from(res.data);
    } on FirebaseFunctionsException catch (e) {
      if (_isPluginChannelError(e.message)) {
        return CallableHttpClient.call(
          name: 'storeProductDiscover',
          data: payload,
          timeout: const Duration(seconds: 90),
          callableProtocol: true,
        );
      }
      rethrow;
    }
  }

  List<ProductDiscoverHit> _parseRemote(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ProductDiscoverHit>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final name = m['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      out.add(
        ProductDiscoverHit(
          name: name,
          storeName: m['storeName']?.toString() ?? '',
          description: m['description']?.toString() ?? '',
          category: m['category']?.toString() ?? '',
          price: (m['price'] as num?) ?? 0,
          imageUrl: m['imageUrl']?.toString(),
          sourceUrl: m['sourceUrl']?.toString(),
          supplierId: m['supplierId']?.toString() ?? '',
          website: m['website']?.toString() ?? '',
          email: m['email']?.toString() ?? '',
          phone: m['phone']?.toString() ?? '',
          fromRemoteSite: true,
          score: 40,
          sourceLabel: 'supplier',
        ),
      );
    }
    return out;
  }

  List<ProductDiscoverWebLink> _parseWeb(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ProductDiscoverWebLink>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final url = m['url']?.toString() ?? '';
      final title = m['title']?.toString() ?? '';
      if (url.isEmpty || title.isEmpty) continue;
      out.add(
        ProductDiscoverWebLink(
          title: title,
          url: url,
          snippet: m['snippet']?.toString() ?? '',
          source: m['source']?.toString() ?? '',
        ),
      );
    }
    return out;
  }

  /// استعلام قصير مناسب لـ Woo/Google — السطر الأول الإنجليزي إن وُجد.
  String _storeSearchQuery(String text, List<String> keywords) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim().replaceFirst(RegExp(r'^[\-\*\d\.\)\s]+'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
    for (final line in lines.take(3)) {
      final hasLatin = RegExp(r'[A-Za-z]').hasMatch(line);
      if (hasLatin && line.length <= 100) {
        return line.length > 80 ? line.substring(0, 80) : line;
      }
    }
    if (keywords.isNotEmpty) {
      final latinKw = keywords
          .where((k) => RegExp(r'^[a-z0-9.\-]+$', caseSensitive: false).hasMatch(k))
          .take(5)
          .toList();
      if (latinKw.isNotEmpty) return latinKw.join(' ');
      return keywords.take(5).join(' ');
    }
    return text.length > 80 ? text.substring(0, 80) : text;
  }

  List<String> _keywords(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9.\-\s]'), ' ');
    const stop = {
      'the',
      'and',
      'for',
      'with',
      'from',
      'this',
      'that',
      'من',
      'إلى',
      'على',
      'في',
      'مع',
      'عن',
      'هذا',
      'هذه',
      'أو',
      'و',
      'أن',
      'يحتاج',
      'مطلوب',
      'تجربة',
      'جهاز',
      'قطعة',
      'منتج',
    };
    final counts = <String, int>{};
    for (final w in cleaned.split(RegExp(r'\s+'))) {
      if (w.length < 3 || stop.contains(w)) continue;
      counts[w] = (counts[w] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return b.key.length.compareTo(a.key.length);
      });
    return ranked.take(10).map((e) => e.key).toList();
  }

  static bool get _preferHttpCallable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool _isPluginChannelError(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('unable to establish connection on channel') ||
        lower.contains('cloudfunctionshostapi') ||
        lower.contains('pigeon');
  }
}
