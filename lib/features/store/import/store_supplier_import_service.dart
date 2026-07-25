import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/user_account_service.dart';
import '../../moderation/approval_status.dart';
import 'egypt_store_suppliers_catalog.dart';
import 'store_category_mapper.dart';
import 'woocommerce_store_api_client.dart';

class StoreSupplierSyncProgress {
  final String stage;
  final String detail;
  final double? fraction;

  const StoreSupplierSyncProgress({
    required this.stage,
    required this.detail,
    this.fraction,
  });
}

class StoreSupplierSyncResult {
  final int suppliersUpserted;
  final int productsImported;
  final int productsUpdated;
  final int productsSkipped;
  final Map<String, int> productsBySupplier;

  const StoreSupplierSyncResult({
    required this.suppliersUpserted,
    required this.productsImported,
    required this.productsUpdated,
    required this.productsSkipped,
    required this.productsBySupplier,
  });
}

/// Publishes curated suppliers + syncs WooCommerce public catalogs into
/// `store_suppliers` and `product`.
class StoreSupplierImportService {
  StoreSupplierImportService._();

  static final StoreSupplierImportService instance =
      StoreSupplierImportService._();

  final _db = FirebaseFirestore.instance;

  static const metaDoc = 'app_meta/store_suppliers_sync';
  static const suppliersCollection = 'store_suppliers';
  static const productsCollection = 'product';

  Future<DateTime?> loadLastSyncAt() async {
    final snap = await _db.doc(metaDoc).get();
    final ts = snap.data()?['syncedAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  /// Upsert all curated suppliers (with contacts). Optionally sync products
  /// from WooCommerce-enabled suppliers.
  Future<StoreSupplierSyncResult> syncAll({
    bool syncProducts = true,
    int? maxProductsPerSupplier,
    void Function(StoreSupplierSyncProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول');
    }
    final account =
        await UserAccountService.instance.watchCurrentAccount().first;
    if (account?.isAdmin != true) {
      throw Exception('المزامنة متاحة للمسؤولين فقط');
    }

    onProgress?.call(
      const StoreSupplierSyncProgress(
        stage: 'suppliers',
        detail: 'حفظ دليل الموردين…',
        fraction: 0.02,
      ),
    );

    final now = DateTime.now();
    var suppliersUpserted = 0;
    final supplierBatch = _db.batch();
    for (final supplier in egyptStoreSuppliersCatalog) {
      final ref = _db.collection(suppliersCollection).doc(supplier.id);
      supplierBatch.set(
        ref,
        {
          ...supplier.toFirestoreMap(syncedAt: now),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      suppliersUpserted++;
    }
    await supplierBatch.commit();

    var imported = 0;
    var updated = 0;
    var skipped = 0;
    final bySupplier = <String, int>{};

    if (syncProducts) {
      final targets = egyptStoreSuppliersWithProductSync;
      for (var i = 0; i < targets.length; i++) {
        if (shouldCancel?.call() == true) {
          throw StateError('cancelled');
        }
        final supplier = targets[i];
        final base = supplier.wooCommerceBaseUrl;
        if (base == null || base.isEmpty) continue;

        onProgress?.call(
          StoreSupplierSyncProgress(
            stage: 'fetch',
            detail: 'جلب منتجات ${supplier.nameAr}…',
            fraction: 0.05 + (0.55 * i / targets.length),
          ),
        );

        final products =
            await WooCommerceStoreApiClient.instance.fetchAllProducts(
          baseUrl: base,
          supplierId: supplier.id,
          maxProducts: maxProductsPerSupplier ?? supplier.syncMaxProducts,
          onProgress: (p) {
            onProgress?.call(
              StoreSupplierSyncProgress(
                stage: 'fetch',
                detail:
                    '${supplier.nameAr}: صفحة ${p.page}/${p.totalPages} · ${p.productsSoFar} منتج',
                fraction: 0.05 +
                    (0.55 * (i + p.fraction) / targets.length),
              ),
            );
          },
          shouldCancel: shouldCancel,
        );

        onProgress?.call(
          StoreSupplierSyncProgress(
            stage: 'write',
            detail: 'حفظ ${products.length} منتجاً لـ ${supplier.nameAr}…',
            fraction: 0.6 + (0.35 * i / targets.length),
          ),
        );

        final writeStats = await _upsertProducts(
          supplier: supplier,
          products: products,
          adminUid: user.uid,
          shouldCancel: shouldCancel,
        );
        imported += writeStats.$1;
        updated += writeStats.$2;
        skipped += writeStats.$3;
        bySupplier[supplier.id] = products.length;
      }
    }

    await _db.doc(metaDoc).set({
      'syncedAt': FieldValue.serverTimestamp(),
      'suppliersUpserted': suppliersUpserted,
      'productsImported': imported,
      'productsUpdated': updated,
      'productsBySupplier': bySupplier,
      'syncedBy': user.uid,
      'autoUpdateReady': true,
    }, SetOptions(merge: true));

    onProgress?.call(
      const StoreSupplierSyncProgress(
        stage: 'done',
        detail: 'اكتملت المزامنة',
        fraction: 1,
      ),
    );

    return StoreSupplierSyncResult(
      suppliersUpserted: suppliersUpserted,
      productsImported: imported,
      productsUpdated: updated,
      productsSkipped: skipped,
      productsBySupplier: bySupplier,
    );
  }

  /// Returns (imported, updated, skipped).
  Future<(int, int, int)> _upsertProducts({
    required EgyptStoreSupplier supplier,
    required List<WooImportedProduct> products,
    required String adminUid,
    bool Function()? shouldCancel,
  }) async {
    var imported = 0;
    var updated = 0;
    var skipped = 0;

    const chunk = 400;
    for (var i = 0; i < products.length; i += chunk) {
      if (shouldCancel?.call() == true) {
        throw StateError('cancelled');
      }
      final slice = products.skip(i).take(chunk).toList();
      final refs = slice
          .map(
            (p) => _db
                .collection(productsCollection)
                .doc(_productDocId(supplier.id, p.externalId)),
          )
          .toList();

      final existingSnaps = await Future.wait(refs.map((r) => r.get()));
      final batch = _db.batch();

      for (var j = 0; j < slice.length; j++) {
        final product = slice[j];
        final ref = refs[j];
        final exists = existingSnaps[j].exists;
        final category = mapImportedProductCategory(
          product: product,
          fallbackTitle: supplier.defaultCategoryTitle,
          supplierId: supplier.id,
        );

        final description = product.description.isNotEmpty
            ? product.description
            : 'منتج من كتالوج ${supplier.nameAr}. للتفاصيل والتواصل راجع بيانات المورد أو رابط المصدر.';

        final payload = <String, dynamic>{
          'name': product.name,
          'price': product.price,
          'currency': product.currency,
          'category': category,
          'description': description,
          'storeName': supplier.nameAr,
          'contact': supplier.displayContact,
          'email': supplier.email,
          'phone': supplier.phone,
          'whatsapp': supplier.whatsapp,
          'website': supplier.website,
          'sourceUrl': product.permalink,
          if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
            'imageUrl': product.imageUrl,
          if (product.sku.isNotEmpty) 'sku': product.sku,
          'brand': product.categoryNames.isNotEmpty
              ? product.categoryNames.first
              : supplier.nameEn,
          'supplierId': supplier.id,
          'importSource': 'wc_${supplier.id}',
          'externalProductId': product.externalId,
          'isVerifiedSeller': true,
          'isDirectoryListing': true,
          'inStock': product.inStock,
          'approvalStatus': ApprovalStatus.approved,
          'syncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!exists) {
          payload['createdBy'] = adminUid;
          payload['createdAt'] = FieldValue.serverTimestamp();
          batch.set(ref, payload);
          imported++;
        } else {
          // Do not overwrite ownership / manual edits of non-imported docs.
          final existing = existingSnaps[j].data() ?? {};
          final existingSource = existing['importSource']?.toString() ?? '';
          if (existingSource.isNotEmpty &&
              !existingSource.startsWith('wc_')) {
            skipped++;
            continue;
          }
          batch.set(ref, payload, SetOptions(merge: true));
          updated++;
        }
      }

      await batch.commit();
    }

    return (imported, updated, skipped);
  }

  static String _productDocId(String supplierId, int externalId) =>
      'wc_${supplierId}_$externalId';
}
