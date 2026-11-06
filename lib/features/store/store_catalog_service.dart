import 'package:cloud_firestore/cloud_firestore.dart';

import '../moderation/approval_status.dart';
import 'store_categories.dart';

/// منتج معتمد جاهز للعرض في واجهة المتجر.
class StoreCatalogProduct {
  final String id;
  final String name;
  final num price;
  final String categoryRaw;
  final String categoryCanonical;
  final String storeName;
  final String description;
  final String contact;
  final String? createdBy;
  final String? imageUrl;
  final String? sourceUrl;
  final String brand;
  final String unit;
  final String grade;
  final String sellerType;
  final List<String> certifications;
  final bool isVerifiedSeller;
  final bool isDirectoryListing;
  final bool isPartner;
  final String directoryStatus;
  final String dataSourceLabelAr;
  final String dataSourceLabelEn;
  final String lastVerifiedIso;
  final String email;
  final String phone;
  final String whatsapp;
  final String website;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// عدد طلبات Escrow المدفوعة (paid_held / released) — يحدّثه Cloud Function.
  final int orderCount;
  final String sku;
  final String originCountry;
  final List<String> imageUrls;
  final bool inStock;
  final String city;
  final bool fastShipping;
  final List<String> badges;
  final String? supplierId;
  final String productType;
  final String licenseMode;
  final bool hasAssemblyGuide;

  const StoreCatalogProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryRaw,
    required this.categoryCanonical,
    required this.storeName,
    this.description = '',
    this.contact = '',
    this.createdBy,
    this.imageUrl,
    this.sourceUrl,
    this.brand = '',
    this.unit = '',
    this.grade = '',
    this.sellerType = '',
    this.certifications = const [],
    this.isVerifiedSeller = false,
    this.isDirectoryListing = false,
    this.isPartner = false,
    this.directoryStatus = 'unverified',
    this.dataSourceLabelAr = '',
    this.dataSourceLabelEn = '',
    this.lastVerifiedIso = '',
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.website = '',
    this.createdAt,
    this.updatedAt,
    this.orderCount = 0,
    this.sku = '',
    this.originCountry = '',
    this.imageUrls = const [],
    this.inStock = true,
    this.city = '',
    this.fastShipping = false,
    this.badges = const [],
    this.supplierId,
    this.productType = 'physical',
    this.licenseMode = 'sale',
    this.hasAssemblyGuide = false,
  });

  StoreCategory? get category =>
      storeCategoryByTitle(categoryCanonical.isNotEmpty
          ? categoryCanonical
          : categoryRaw);

  List<String> get galleryUrls {
    final urls = <String>[];
    for (final u in imageUrls) {
      final t = u.trim();
      if (t.isNotEmpty && !urls.contains(t)) urls.add(t);
    }
    final primary = (imageUrl ?? '').trim();
    if (primary.isNotEmpty && !urls.contains(primary)) {
      urls.insert(0, primary);
    }
    return urls;
  }

  factory StoreCatalogProduct.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawCategory = data['category']?.toString() ?? '';
    final canonical = storeCategoryLegacyAliases[rawCategory] ?? rawCategory;
    final importSource = data['importSource']?.toString() ?? '';
    final certs = data['certifications'];
    final badgeRaw = data['badges'];
    final imagesRaw = data['imageUrls'];
    return StoreCatalogProduct(
      id: doc.id,
      name: (data['name']?.toString() ?? '').trim().isEmpty
          ? 'منتج'
          : data['name'].toString().trim(),
      price: data['price'] is num
          ? data['price'] as num
          : num.tryParse(data['price']?.toString() ?? '') ?? 0,
      categoryRaw: rawCategory,
      categoryCanonical: canonical,
      storeName: (data['storeName']?.toString() ?? '').trim(),
      description: data['description']?.toString() ?? '',
      contact: data['contact']?.toString() ?? '',
      createdBy: data['createdBy']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      sourceUrl: data['sourceUrl']?.toString(),
      brand: data['brand']?.toString() ?? '',
      unit: data['unit']?.toString() ?? '',
      grade: data['grade']?.toString() ?? '',
      sellerType: data['sellerType']?.toString() ?? '',
      certifications: certs is List
          ? certs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      isVerifiedSeller: data['isVerifiedSeller'] == true,
      isDirectoryListing: data['isDirectoryListing'] == true ||
          importSource.startsWith('wc_'),
      isPartner: data['isPartner'] == true,
      directoryStatus: () {
        final raw = data['directoryStatus']?.toString() ?? '';
        if (raw.isNotEmpty) return raw;
        if (data['isPartner'] == true || data['isVerifiedSeller'] == true) {
          return 'verified';
        }
        return 'unverified';
      }(),
      dataSourceLabelAr: data['dataSourceLabelAr']?.toString() ?? '',
      dataSourceLabelEn: data['dataSourceLabelEn']?.toString() ?? '',
      lastVerifiedIso: data['lastVerifiedIso']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      website: data['website']?.toString() ?? '',
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
      orderCount: _asInt(data['orderCount']),
      sku: data['sku']?.toString() ?? '',
      originCountry: data['originCountry']?.toString() ??
          data['countryOfOrigin']?.toString() ??
          '',
      imageUrls: imagesRaw is List
          ? imagesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      inStock: data['inStock'] != false,
      city: data['city']?.toString() ?? '',
      fastShipping: data['fastShipping'] == true,
      badges: badgeRaw is List
          ? badgeRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      supplierId: data['supplierId']?.toString(),
      productType: data['productType']?.toString() ?? 'physical',
      licenseMode: data['licenseMode']?.toString() ?? 'sale',
      hasAssemblyGuide: data['hasAssemblyGuide'] == true,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class StoreCatalogBundle {
  final List<StoreCatalogProduct> products;
  final Map<String, int> countsByCanonicalTitle;
  final Map<String, int> orderCountsByCanonicalTitle;
  final Object? error;

  const StoreCatalogBundle({
    this.products = const [],
    this.countsByCanonicalTitle = const {},
    this.orderCountsByCanonicalTitle = const {},
    this.error,
  });

  bool get hasError => error != null;

  /// منتجات أُنشئت خلال آخر [within] (افتراضي أسبوع).
  List<StoreCatalogProduct> newThisWeek({
    int limit = 12,
    Duration within = const Duration(days: 7),
  }) {
    final cutoff = DateTime.now().subtract(within);
    final fresh = products.where((p) {
      final created = p.createdAt;
      return created != null && !created.isBefore(cutoff);
    }).toList()
      ..sort((a, b) {
        final aAt = a.createdAt!;
        final bAt = b.createdAt!;
        return bAt.compareTo(aAt);
      });
    return fresh.take(limit).toList();
  }

  /// الأكثر طلباً حسب [orderCount] (طلبات Escrow المدفوعة).
  List<StoreCatalogProduct> mostRequested({int limit = 12}) {
    final ranked = products.where((p) => p.orderCount > 0).toList()
      ..sort((a, b) {
        final byOrders = b.orderCount.compareTo(a.orderCount);
        if (byOrders != 0) return byOrders;
        final aAt = a.updatedAt ?? a.createdAt;
        final bAt = b.updatedAt ?? b.createdAt;
        if (aAt == null && bAt == null) return 0;
        if (aAt == null) return 1;
        if (bAt == null) return -1;
        return bAt.compareTo(aAt);
      });
    return ranked.take(limit).toList();
  }

  /// أقسام مرتبة بحجم الطلبات، ثم بعدد المنتجات عند التعادل / الفراغ.
  List<StoreCategory> activeCategories({int limit = 6}) {
    final ranked = [...storeCategories]..sort((a, b) {
        final oa = orderCountsByCanonicalTitle[a.title] ?? 0;
        final ob = orderCountsByCanonicalTitle[b.title] ?? 0;
        if (oa != ob) return ob.compareTo(oa);
        final ca = countsByCanonicalTitle[a.title] ?? 0;
        final cb = countsByCanonicalTitle[b.title] ?? 0;
        return cb.compareTo(ca);
      });
    return ranked.take(limit).toList();
  }

  int countFor(StoreCategory category) =>
      countsByCanonicalTitle[category.title] ?? 0;

  int orderCountFor(StoreCategory category) =>
      orderCountsByCanonicalTitle[category.title] ?? 0;
}

/// تحميل كتالوج المتجر مع قواعد الاعتماد والألقاب القديمة موحّدة.
class StoreCatalogService {
  StoreCatalogService._();

  static final StoreCatalogService instance = StoreCatalogService._();

  final _db = FirebaseFirestore.instance;
  StoreCatalogBundle? _cache;
  DateTime? _cachedAt;

  static const _hubPerTitleLimit = 50;
  static const _listPerTitleLimit = 180;
  static const _cacheTtl = Duration(minutes: 12);

  void invalidateCache() {
    _cache = null;
    _cachedAt = null;
  }

  /// كتالوج الواجهة: استعلامات محدودة لكل قسم بدل تحميل المجموعة كاملة.
  Future<StoreCatalogBundle> loadPublicCatalog({bool forceRefresh = false}) async {
    final cached = _cache;
    final at = _cachedAt;
    if (!forceRefresh &&
        cached != null &&
        cached.error == null &&
        at != null &&
        DateTime.now().difference(at) < _cacheTtl) {
      return cached;
    }
    try {
      final titles = <String>{};
      for (final category in storeCategories) {
        titles.addAll(storeCategoryQueryTitles(category));
      }

      final byId = await _fetchByCategoryTitles(
        titles.toList(),
        perTitleLimit: _hubPerTitleLimit,
      );

      // Rails: الأكثر طلباً / الأحدث — إن وُجدت فهارس؛ وإلا نتجاهل بهدوء.
      await _tryIngestOrdered(
        byId,
        orderBy: 'orderCount',
        limit: 40,
      );
      await _tryIngestOrdered(
        byId,
        orderBy: 'createdAt',
        limit: 40,
      );

      final products = byId.values.toList();
      final counts = <String, int>{};
      final orderCounts = <String, int>{};
      for (final product in products) {
        if (product.categoryCanonical.isEmpty) continue;
        counts[product.categoryCanonical] =
            (counts[product.categoryCanonical] ?? 0) + 1;
        if (product.orderCount > 0) {
          orderCounts[product.categoryCanonical] =
              (orderCounts[product.categoryCanonical] ?? 0) +
                  product.orderCount;
        }
      }

      final bundle = StoreCatalogBundle(
        products: products,
        countsByCanonicalTitle: counts,
        orderCountsByCanonicalTitle: orderCounts,
      );
      _cache = bundle;
      _cachedAt = DateTime.now();
      return bundle;
    } catch (e) {
      if (cached != null && cached.error == null) return cached;
      return StoreCatalogBundle(error: e);
    }
  }

  /// منتجات قسم واحد (أو ألقابه القديمة) — لقائمة القسم.
  Future<List<StoreCatalogProduct>> loadByCategoryTitles(
    List<String> titles, {
    int? perTitleLimit,
  }) async {
    final cleaned = titles
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isEmpty) return const [];

    // أعد استخدام الكاش إن غطّى القسم بالفعل.
    final cached = _cache;
    if (cached != null &&
        cached.error == null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      final titleSet = cleaned.toSet();
      final fromCache = cached.products.where((p) {
        return titleSet.contains(p.categoryRaw) ||
            titleSet.contains(p.categoryCanonical);
      }).toList();
      // إن وُجدت منتجات كافية من الكاش نعرضها فوراً؛ وإلا نجلب من الشبكة.
      if (fromCache.isNotEmpty) {
        // Refresh in background without blocking first paint when cache is warm.
        // ignore: unawaited_futures
        _refreshCategoryIntoCache(cleaned, perTitleLimit ?? _listPerTitleLimit);
        return fromCache;
      }
    }

    final byId = await _fetchByCategoryTitles(
      cleaned,
      perTitleLimit: perTitleLimit ?? _listPerTitleLimit,
    );
    return byId.values.toList();
  }

  Future<void> _refreshCategoryIntoCache(
    List<String> titles,
    int perTitleLimit,
  ) async {
    try {
      final fresh = await _fetchByCategoryTitles(
        titles,
        perTitleLimit: perTitleLimit,
      );
      final cached = _cache;
      if (cached == null || cached.error != null) return;
      final merged = <String, StoreCatalogProduct>{
        for (final p in cached.products) p.id: p,
        ...fresh,
      };
      final products = merged.values.toList();
      final counts = <String, int>{};
      final orderCounts = <String, int>{};
      for (final product in products) {
        if (product.categoryCanonical.isEmpty) continue;
        counts[product.categoryCanonical] =
            (counts[product.categoryCanonical] ?? 0) + 1;
        if (product.orderCount > 0) {
          orderCounts[product.categoryCanonical] =
              (orderCounts[product.categoryCanonical] ?? 0) +
                  product.orderCount;
        }
      }
      _cache = StoreCatalogBundle(
        products: products,
        countsByCanonicalTitle: counts,
        orderCountsByCanonicalTitle: orderCounts,
      );
      _cachedAt = DateTime.now();
    } catch (_) {}
  }

  Future<Map<String, StoreCatalogProduct>> _fetchByCategoryTitles(
    List<String> titles, {
    required int perTitleLimit,
  }) async {
    final byId = <String, StoreCatalogProduct>{};
    if (titles.isEmpty) return byId;

    // دفعات صغيرة حتى لا نفتح عشرات الاستعلامات دفعة واحدة على الشبكة الضعيفة.
    const chunkSize = 8;
    for (var i = 0; i < titles.length; i += chunkSize) {
      final chunk = titles.skip(i).take(chunkSize).toList();
      final snaps = await Future.wait(
        chunk.map(
          (title) => _db
              .collection('product')
              .where('category', isEqualTo: title)
              .limit(perTitleLimit)
              .get(),
        ),
      );
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          final status = doc.data()['approvalStatus']?.toString();
          if (!ApprovalStatus.isPublic(status)) continue;
          byId.putIfAbsent(doc.id, () => StoreCatalogProduct.fromDoc(doc));
        }
      }
    }
    return byId;
  }

  Future<void> _tryIngestOrdered(
    Map<String, StoreCatalogProduct> byId, {
    required String orderBy,
    required int limit,
  }) async {
    try {
      final snap = await _db
          .collection('product')
          .orderBy(orderBy, descending: true)
          .limit(limit)
          .get();
      for (final doc in snap.docs) {
        final status = doc.data()['approvalStatus']?.toString();
        if (!ApprovalStatus.isPublic(status)) continue;
        byId.putIfAbsent(doc.id, () => StoreCatalogProduct.fromDoc(doc));
      }
    } catch (_) {
      // فهرس ناقص أو حقل غير مفهرس — نكتفي باستعلامات الأقسام.
    }
  }
}
