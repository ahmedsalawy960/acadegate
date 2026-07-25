import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../moderation/approval_status.dart';
import 'egypt_store_suppliers_catalog.dart';
import 'woocommerce_store_api_client.dart';

class StoreSearchHit {
  final String name;
  final String storeName;
  final String contact;
  final String email;
  final String phone;
  final String whatsapp;
  final String website;
  final String? productId;
  final String? createdBy;
  final num price;
  final String? imageUrl;
  final String? sourceUrl;
  final String description;
  final String category;
  final bool fromRemoteSite;
  final String supplierId;
  final bool isDirectoryListing;

  const StoreSearchHit({
    required this.name,
    required this.storeName,
    this.contact = '',
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.website = '',
    this.productId,
    this.createdBy,
    this.price = 0,
    this.imageUrl,
    this.sourceUrl,
    this.description = '',
    this.category = '',
    this.fromRemoteSite = false,
    this.supplierId = '',
    this.isDirectoryListing = false,
  });
}

class StoreProductSearchResult {
  final List<StoreSearchHit> local;
  final List<StoreSearchHit> remote;

  const StoreProductSearchResult({
    this.local = const [],
    this.remote = const [],
  });

  bool get isEmpty => local.isEmpty && remote.isEmpty;
}

/// Searches products already in Firestore + live catalogs of imported suppliers.
class StoreProductSearchService {
  StoreProductSearchService._();

  static final StoreProductSearchService instance =
      StoreProductSearchService._();

  final _db = FirebaseFirestore.instance;

  Future<StoreProductSearchResult> search(
    String rawQuery, {
    int localLimit = 40,
    int remotePerSupplier = 8,
  }) async {
    final query = rawQuery.trim();
    if (query.length < 2) {
      return const StoreProductSearchResult();
    }

    final localFuture = _searchLocal(query, limit: localLimit);
    final remoteFuture = kIsWeb
        ? Future.value(const <StoreSearchHit>[])
        : _searchRemote(query, perSupplier: remotePerSupplier);

    final local = await localFuture;
    final remote = await remoteFuture;

    // Drop remote hits that are already present locally (same source URL / name+supplier).
    final localKeys = <String>{
      for (final h in local)
        if (h.sourceUrl != null && h.sourceUrl!.isNotEmpty)
          h.sourceUrl!.toLowerCase()
        else
          '${h.supplierId}|${h.name.toLowerCase()}',
    };

    final remoteOnly = remote.where((h) {
      final key = (h.sourceUrl != null && h.sourceUrl!.isNotEmpty)
          ? h.sourceUrl!.toLowerCase()
          : '${h.supplierId}|${h.name.toLowerCase()}';
      return !localKeys.contains(key);
    }).toList();

    return StoreProductSearchResult(local: local, remote: remoteOnly);
  }

  Future<List<StoreSearchHit>> _searchLocal(
    String query, {
    required int limit,
  }) async {
    final needle = query.toLowerCase();
    try {
      final snap = await _db.collection('product').limit(500).get();
      final hits = <StoreSearchHit>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['approvalStatus']?.toString();
        if (!ApprovalStatus.isPublic(status)) continue;
        final name = data['name']?.toString() ?? '';
        final store = data['storeName']?.toString() ?? '';
        final category = data['category']?.toString() ?? '';
        final brand = data['brand']?.toString() ?? '';
        final tags = (data['tags'] is List)
            ? (data['tags'] as List).map((e) => e.toString()).join(' ')
            : '';
        final hay = '$name $store $category $brand $tags'.toLowerCase();
        if (!hay.contains(needle)) continue;
        hits.add(
          StoreSearchHit(
            name: name,
            storeName: store,
            contact: data['contact']?.toString() ?? '',
            email: data['email']?.toString() ?? '',
            phone: data['phone']?.toString() ?? '',
            whatsapp: data['whatsapp']?.toString() ?? '',
            website: data['website']?.toString() ?? '',
            productId: doc.id,
            createdBy: data['createdBy']?.toString(),
            price: (data['price'] as num?) ?? 0,
            imageUrl: data['imageUrl']?.toString(),
            sourceUrl: data['sourceUrl']?.toString(),
            description: data['description']?.toString() ?? '',
            category: category,
            fromRemoteSite: false,
            supplierId: data['supplierId']?.toString() ?? '',
            isDirectoryListing: data['isDirectoryListing'] == true ||
                (data['importSource']?.toString() ?? '').startsWith('wc_'),
          ),
        );
        if (hits.length >= limit) break;
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  Future<List<StoreSearchHit>> _searchRemote(
    String query, {
    required int perSupplier,
  }) async {
    final suppliers = egyptStoreSuppliersWithProductSync
        .where((s) => (s.wooCommerceBaseUrl ?? '').isNotEmpty)
        .toList();
    if (suppliers.isEmpty) return const [];

    final futures = suppliers.map((supplier) async {
      final products = await WooCommerceStoreApiClient.instance.searchProducts(
        baseUrl: supplier.wooCommerceBaseUrl!,
        query: query,
        perPage: perSupplier,
      );
      return products
          .map(
            (p) => StoreSearchHit(
              name: p.name,
              storeName: supplier.nameAr,
              contact: supplier.displayContact,
              email: supplier.email,
              phone: supplier.phone,
              whatsapp: supplier.whatsapp,
              website: supplier.website,
              price: p.price,
              imageUrl: p.imageUrl,
              sourceUrl: p.permalink,
              description: p.description,
              category: p.categoryNames.isNotEmpty
                  ? p.categoryNames.first
                  : supplier.defaultCategoryTitle,
              fromRemoteSite: true,
              supplierId: supplier.id,
              isDirectoryListing: true,
            ),
          )
          .toList();
    });

    final batches = await Future.wait(futures);
    return batches.expand((e) => e).toList();
  }
}
