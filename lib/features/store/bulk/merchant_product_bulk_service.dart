import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../import/store_category_mapper.dart';
import '../import/woocommerce_store_api_client.dart';
import 'product_import_parser.dart';

class BulkWriteProgress {
  final int done;
  final int total;

  const BulkWriteProgress(this.done, this.total);

  double get fraction => total == 0 ? 1 : done / total;
}

class BulkImportResult {
  final int created;
  final int updated;
  final int skipped;

  const BulkImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
  });
}

/// Supplier context stamped on every product written in bulk.
class MerchantListingContext {
  final String defaultCategory;
  final String approvalStatus;
  final String storeName;
  final String contact;
  /// Directory supplier page this catalog belongs to (Managed Verified flow).
  final String? supplierId;
  /// Reseller margin added on top of the supplier price.
  final num markupPercent;

  const MerchantListingContext({
    required this.defaultCategory,
    required this.approvalStatus,
    this.storeName = '',
    this.contact = '',
    this.supplierId,
    this.markupPercent = 0,
  });

  num sellingPrice(num supplierPrice) =>
      MerchantProductBulkService.applyMarkup(supplierPrice, markupPercent);

  Map<String, dynamic> get supplierFields {
    final id = (supplierId ?? '').trim();
    if (id.isEmpty) return const {};
    return {
      'supplierId': id,
      'isPartner': true,
      'isVerifiedSeller': true,
      'directoryStatus': 'managed_verified',
      'isDirectoryListing': false,
    };
  }
}

enum BulkPriceMode { setExact, percent, add }

/// Bulk create / update / delete for the signed-in merchant's own products.
class MerchantProductBulkService {
  MerchantProductBulkService._();

  static final MerchantProductBulkService instance =
      MerchantProductBulkService._();

  static const _collection = 'product';
  static const _batchSize = 400;
  static const _wooUrlPrefKey = 'merchant_woo_store_url';

  final _db = FirebaseFirestore.instance;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('يجب تسجيل الدخول');
    return uid;
  }

  Future<Map<String, Map<String, dynamic>>> _ownProducts(String uid) async {
    final snap = await _db
        .collection(_collection)
        .where('createdBy', isEqualTo: uid)
        .get();
    return {for (final d in snap.docs) d.id: d.data()};
  }

  /// Creates products from sheet rows. Rows whose SKU matches one of the
  /// merchant's existing products update that product instead.
  Future<BulkImportResult> importRows({
    required List<ProductImportRow> rows,
    required MerchantListingContext listing,
    bool updateExistingBySku = true,
    void Function(BulkWriteProgress progress)? onProgress,
  }) async {
    final uid = _uid;
    final valid = rows.where((r) => r.isValid).toList();

    final idBySku = <String, String>{};
    if (updateExistingBySku) {
      final own = await _ownProducts(uid);
      for (final entry in own.entries) {
        final sku = entry.value['sku']?.toString().trim().toLowerCase() ?? '';
        if (sku.isNotEmpty) idBySku.putIfAbsent(sku, () => entry.key);
      }
    }

    final batchId = DateTime.now().millisecondsSinceEpoch.toString();
    var created = 0;
    var updated = 0;
    var done = 0;
    onProgress?.call(BulkWriteProgress(0, valid.length));

    for (var i = 0; i < valid.length; i += _batchSize) {
      final batch = _db.batch();
      for (final row in valid.skip(i).take(_batchSize)) {
        final payload = <String, dynamic>{
          'name': row.name,
          'price': listing.sellingPrice(row.price!),
          'category': row.category ?? listing.defaultCategory,
          'description': row.description,
          'sku': row.sku,
          'brand': row.brand,
          'unit': row.unit,
          'grade': row.grade,
          'originCountry': row.originCountry,
          'city': row.city,
          'inStock': row.inStock,
          'fastShipping': row.fastShipping,
          if (row.imageUrl != null) ...{
            'imageUrl': row.imageUrl,
            'imageUrls': [row.imageUrl],
          },
          'importSource': 'merchant_sheet',
          'importBatchId': batchId,
          'updatedAt': FieldValue.serverTimestamp(),
          ...listing.supplierFields,
        };

        final existingId =
            row.sku.isEmpty ? null : idBySku[row.sku.toLowerCase()];
        if (existingId != null) {
          batch.set(
            _db.collection(_collection).doc(existingId),
            payload,
            SetOptions(merge: true),
          );
          updated++;
        } else {
          final ref = _db.collection(_collection).doc();
          batch.set(ref, {
            ...payload,
            if (listing.storeName.isNotEmpty) 'storeName': listing.storeName,
            if (listing.contact.isNotEmpty) 'contact': listing.contact,
            'badges': const <String>[],
            'createdBy': uid,
            'approvalStatus': listing.approvalStatus,
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (row.sku.isNotEmpty) idBySku[row.sku.toLowerCase()] = ref.id;
          created++;
        }
        done++;
      }
      await batch.commit();
      onProgress?.call(BulkWriteProgress(done, valid.length));
    }

    return BulkImportResult(
      created: created,
      updated: updated,
      skipped: rows.length - valid.length,
    );
  }

  Future<String?> loadSavedWooUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_wooUrlPrefKey);
  }

  /// Normalizes `shop.com`, `https://shop.com/shop/` → `https://shop.com`.
  static String? normalizeStoreUrl(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return null;
    if (!v.startsWith(RegExp(r'https?://'))) v = 'https://$v';
    final uri = Uri.tryParse(v);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      return null;
    }
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  Future<List<WooImportedProduct>> fetchWooCatalog({
    required String baseUrl,
    void Function(WooFetchProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final products = await WooCommerceStoreApiClient.instance.fetchAllProducts(
      baseUrl: baseUrl,
      supplierId: Uri.parse(baseUrl).host,
      onProgress: onProgress,
      shouldCancel: shouldCancel,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wooUrlPrefKey, baseUrl);
    return products;
  }

  /// Upserts a fetched WooCommerce catalog. Re-running refreshes prices and
  /// stock of the same products instead of duplicating them.
  Future<BulkImportResult> saveWooCatalog({
    required String baseUrl,
    required List<WooImportedProduct> products,
    required MerchantListingContext listing,
    void Function(BulkWriteProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final uid = _uid;
    final storeKey = storeKeyFor(baseUrl);
    final own = await _ownProducts(uid);

    var created = 0;
    var updated = 0;
    var done = 0;
    onProgress?.call(BulkWriteProgress(0, products.length));

    for (var i = 0; i < products.length; i += _batchSize) {
      if (shouldCancel?.call() == true) throw StateError('cancelled');
      final batch = _db.batch();
      for (final p in products.skip(i).take(_batchSize)) {
        final id = 'wcm_${uid}_${storeKey}_${p.externalId}';
        // Product docs are publicly readable, so nothing here may point
        // buyers back to the supplier's own shop or price.
        final payload = <String, dynamic>{
          'name': p.name,
          'price': listing.sellingPrice(p.price),
          'currency': p.currency,
          'description': p.description,
          'sku': p.sku,
          'inStock': p.inStock,
          if (p.imageUrl != null && p.imageUrl!.isNotEmpty) ...{
            'imageUrl': p.imageUrl,
            'imageUrls': [p.imageUrl],
          },
          if (p.categoryNames.isNotEmpty) 'brand': p.categoryNames.first,
          'importSource': 'merchant_woo',
          'externalProductId': p.externalId,
          'syncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          ...listing.supplierFields,
        };

        final ref = _db.collection(_collection).doc(id);
        if (own.containsKey(id)) {
          // Keep the merchant's manual category choice on refresh.
          batch.set(
            ref,
            {
              ...payload,
              'sourceUrl': FieldValue.delete(),
              'externalStoreUrl': FieldValue.delete(),
            },
            SetOptions(merge: true),
          );
          updated++;
        } else {
          batch.set(ref, {
            ...payload,
            'category': mapImportedProductCategory(
              product: p,
              fallbackTitle: listing.defaultCategory,
            ),
            if (listing.storeName.isNotEmpty) 'storeName': listing.storeName,
            if (listing.contact.isNotEmpty) 'contact': listing.contact,
            'badges': const <String>[],
            'createdBy': uid,
            'approvalStatus': listing.approvalStatus,
            'createdAt': FieldValue.serverTimestamp(),
          });
          created++;
        }
        done++;
      }
      await batch.commit();
      onProgress?.call(BulkWriteProgress(done, products.length));
    }

    return BulkImportResult(created: created, updated: updated, skipped: 0);
  }

  /// Short stable id for a store URL so document ids don't reveal the
  /// supplier's domain.
  static String storeKeyFor(String baseUrl) {
    final host = Uri.parse(baseUrl).host.toLowerCase();
    var hash = 0x811c9dc5;
    for (final unit in host.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(36);
  }

  Future<void> updateFields(
    Iterable<String> productIds,
    Map<String, dynamic> fields,
  ) async {
    final ids = productIds.toList();
    for (var i = 0; i < ids.length; i += _batchSize) {
      final batch = _db.batch();
      for (final id in ids.skip(i).take(_batchSize)) {
        batch.update(_db.collection(_collection).doc(id), {
          ...fields,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// [currentPrices] maps product id → its current price.
  Future<void> adjustPrices({
    required Map<String, num> currentPrices,
    required BulkPriceMode mode,
    required num value,
  }) async {
    final entries = currentPrices.entries.toList();
    for (var i = 0; i < entries.length; i += _batchSize) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(_batchSize)) {
        batch.update(_db.collection(_collection).doc(e.key), {
          'price': newPrice(e.value, mode, value),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// Supplier price + margin, rounded to whole pounds once a margin is set.
  static num applyMarkup(num supplierPrice, num markupPercent) {
    if (markupPercent == 0) return supplierPrice;
    final raw = supplierPrice * (1 + markupPercent / 100);
    return raw < 0 ? 0 : raw.round();
  }

  static String _markupPrefKey(String scope) => 'merchant_markup_$scope';

  /// [scope] is a store URL for linked catalogs or `sheet` for uploads.
  Future<num?> loadMarkup(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_markupPrefKey(scope));
  }

  Future<void> saveMarkup(String scope, num percent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_markupPrefKey(scope), percent.toDouble());
  }

  static num newPrice(num current, BulkPriceMode mode, num value) {
    final raw = switch (mode) {
      BulkPriceMode.setExact => value,
      BulkPriceMode.percent => current * (1 + value / 100),
      BulkPriceMode.add => current + value,
    };
    final rounded = (raw * 100).round() / 100;
    return rounded < 0 ? 0 : rounded;
  }

  Future<void> deleteAll(Iterable<String> productIds) async {
    final ids = productIds.toList();
    for (var i = 0; i < ids.length; i += _batchSize) {
      final batch = _db.batch();
      for (final id in ids.skip(i).take(_batchSize)) {
        batch.delete(_db.collection(_collection).doc(id));
      }
      await batch.commit();
    }
  }
}
