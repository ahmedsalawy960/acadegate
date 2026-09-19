/// نتيجة بحث موحّدة: كتالوج التطبيق + متاجر الموردين + إشارات ويب.
class ProductDiscoverHit {
  final String name;
  final String storeName;
  final String description;
  final String category;
  final num price;
  final String? imageUrl;
  final String? sourceUrl;
  final String? productId;
  final String? createdBy;
  final String supplierId;
  final String website;
  final String email;
  final String phone;
  final bool fromAppCatalog;
  final bool fromRemoteSite;
  final int score;
  final String sourceLabel; // app | supplier | web

  const ProductDiscoverHit({
    required this.name,
    required this.storeName,
    this.description = '',
    this.category = '',
    this.price = 0,
    this.imageUrl,
    this.sourceUrl,
    this.productId,
    this.createdBy,
    this.supplierId = '',
    this.website = '',
    this.email = '',
    this.phone = '',
    this.fromAppCatalog = false,
    this.fromRemoteSite = false,
    this.score = 0,
    this.sourceLabel = 'app',
  });
}

class ProductDiscoverWebLink {
  final String title;
  final String url;
  final String snippet;
  final String source;

  const ProductDiscoverWebLink({
    required this.title,
    required this.url,
    this.snippet = '',
    this.source = '',
  });
}

class ProductDiscoverResult {
  final String searchQuery;
  final List<String> keywords;
  final List<ProductDiscoverHit> appHits;
  final List<ProductDiscoverHit> supplierHits;
  final List<ProductDiscoverWebLink> webHints;
  final List<ProductDiscoverWebLink> webSearchLinks;
  final String? note;
  final String? error;

  const ProductDiscoverResult({
    this.searchQuery = '',
    this.keywords = const [],
    this.appHits = const [],
    this.supplierHits = const [],
    this.webHints = const [],
    this.webSearchLinks = const [],
    this.note,
    this.error,
  });

  List<ProductDiscoverHit> get allProductHits => [...appHits, ...supplierHits];

  bool get isEmpty =>
      appHits.isEmpty &&
      supplierHits.isEmpty &&
      webHints.isEmpty &&
      webSearchLinks.isEmpty;
}
