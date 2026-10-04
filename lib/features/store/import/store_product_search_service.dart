import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../moderation/approval_status.dart';
import '../store_catalog_service.dart';
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

  /// بحث فوري داخل الكتالوج المحمّل، بترتيب الأقرب، دون انتظار مواقع الموردين.
  List<StoreSearchHit> rankLoaded(
    List<StoreCatalogProduct> products,
    String rawQuery, {
    int limit = 40,
  }) {
    final query = rawQuery.trim();
    if (query.length < 2 || products.isEmpty) return const [];
    final phrase = _fold(query);
    final tokens = _queryTokens(phrase);
    final ranked = <({StoreSearchHit hit, int score})>[];
    for (final product in products) {
      final score = _matchScore(
        phrase: phrase,
        tokens: tokens,
        name: product.name,
        brand: '${product.brand} ${product.sku}',
        category: product.categoryCanonical.isNotEmpty
            ? product.categoryCanonical
            : product.categoryRaw,
        description: product.description,
      );
      if (score <= 0) continue;
      ranked.add((hit: _hitFromProduct(product), score: score));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(limit).map((e) => e.hit).toList();
  }

  Future<List<StoreSearchHit>> searchSupplierSites(
    String rawQuery, {
    int perSupplier = 4,
  }) {
    final query = rawQuery.trim();
    if (query.length < 2 || kIsWeb) return Future.value(const []);
    return _searchRemote(query, perSupplier: perSupplier);
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
        final description = data['description']?.toString() ?? '';
        final grade = data['grade']?.toString() ?? '';
        final sku = data['sku']?.toString() ?? '';
        final tags = (data['tags'] is List)
            ? (data['tags'] as List).map((e) => e.toString()).join(' ')
            : '';
        final hay =
            '$name $store $category $brand $description $grade $sku $tags'
                .toLowerCase();
        // دعم وصف طويل: تطابق كامل العبارة أو أي كلمة ≥ 3 أحرف
        final tokens = needle
            .split(RegExp(r'\s+'))
            .where((t) => t.length >= 3)
            .toList();
        final matched = hay.contains(needle) ||
            (tokens.isNotEmpty && tokens.any(hay.contains));
        if (!matched) continue;
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

String _fold(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const _searchStop = {
  'the', 'and', 'for', 'with', 'from',
  'من', 'في', 'علي', 'مع', 'او', 'الي', 'هذا', 'هذه', 'عن',
};

List<String> _queryTokens(String folded) {
  final out = <String>[];
  for (final part in folded.split(' ')) {
    var token = part.trim();
    if (token.startsWith('ال') && token.length > 4) token = token.substring(2);
    if (token.isEmpty || _searchStop.contains(token)) continue;
    final latin = RegExp(r'[a-z0-9]').hasMatch(token);
    if (token.length < (latin ? 3 : 2)) continue;
    out.add(token);
  }
  return out;
}

bool _fieldHit(String hay, String token) {
  if (hay.contains(token)) return true;
  if (token.length < 4) return false;
  final prefix = token.substring(0, token.length >= 5 ? 5 : 4);
  for (final word in hay.split(' ')) {
    if (word.length < 4) continue;
    if (word.startsWith(prefix) || token.startsWith(word.substring(0, 4))) {
      return true;
    }
  }
  return false;
}

int _matchScore({
  required String phrase,
  required List<String> tokens,
  required String name,
  required String brand,
  required String category,
  required String description,
}) {
  final nameF = _fold(name);
  final brandF = _fold(brand);
  final categoryF = _fold(category);
  final descriptionF = _fold(description);
  final probes = tokens.isEmpty ? <String>[phrase] : tokens;
  if (probes.isEmpty) return 0;

  var score = 0;
  var matched = 0;
  if (phrase.isNotEmpty && nameF.contains(phrase)) score += 24;
  for (final token in probes) {
    if (_fieldHit(nameF, token)) {
      score += 10;
      matched++;
    } else if (_fieldHit(brandF, token)) {
      score += 7;
      matched++;
    } else if (_fieldHit(categoryF, token)) {
      score += 3;
      matched++;
    } else if (_fieldHit(descriptionF, token)) {
      score += 1;
      matched++;
    }
  }
  if (matched == 0) return 0;
  if (matched == probes.length) score += 8;
  return score;
}

StoreSearchHit _hitFromProduct(StoreCatalogProduct product) {
  return StoreSearchHit(
    name: product.name,
    storeName: product.storeName,
    contact: product.contact,
    email: product.email,
    phone: product.phone,
    whatsapp: product.whatsapp,
    website: product.website,
    productId: product.id,
    createdBy: product.createdBy,
    price: product.price,
    imageUrl: product.imageUrl,
    sourceUrl: product.sourceUrl,
    description: product.description,
    category: product.categoryCanonical.isNotEmpty
        ? product.categoryCanonical
        : product.categoryRaw,
    supplierId: product.supplierId ?? '',
    isDirectoryListing: product.isDirectoryListing,
  );
}
