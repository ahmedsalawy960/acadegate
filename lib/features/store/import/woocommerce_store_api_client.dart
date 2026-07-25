import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One product row from a public WooCommerce Store API catalog.
class WooImportedProduct {
  final int externalId;
  final String name;
  final String permalink;
  final String description;
  final String sku;
  final num price;
  final String currency;
  final String? imageUrl;
  final List<String> categoryNames;
  final bool inStock;

  const WooImportedProduct({
    required this.externalId,
    required this.name,
    required this.permalink,
    required this.description,
    required this.sku,
    required this.price,
    required this.currency,
    this.imageUrl,
    this.categoryNames = const [],
    this.inStock = true,
  });
}

class WooFetchProgress {
  final String supplierId;
  final int page;
  final int totalPages;
  final int productsSoFar;

  const WooFetchProgress({
    required this.supplierId,
    required this.page,
    required this.totalPages,
    required this.productsSoFar,
  });

  double get fraction =>
      totalPages <= 0 ? 0 : (page / totalPages).clamp(0.0, 1.0);
}

/// Fetches public catalogs via WooCommerce Store API
/// (`/wp-json/wc/store/v1/products`) — no private keys required.
class WooCommerceStoreApiClient {
  WooCommerceStoreApiClient._();

  static final WooCommerceStoreApiClient instance =
      WooCommerceStoreApiClient._();

  static const _userAgent =
      'AcadeGate/1.0 (academic supplier directory; +https://acadegate.app)';

  Future<List<WooImportedProduct>> fetchAllProducts({
    required String baseUrl,
    required String supplierId,
    int perPage = 100,
    int? maxProducts,
    Duration delayBetweenPages = const Duration(milliseconds: 120),
    void Function(WooFetchProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    if (kIsWeb) {
      throw StateError(
        'استيراد المتاجر غير متاح على الويب بسبب CORS — استخدم Windows/Android',
      );
    }

    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final products = <WooImportedProduct>[];
    var page = 1;
    var totalPages = 1;

    while (page <= totalPages) {
      if (shouldCancel?.call() == true) {
        throw StateError('cancelled');
      }
      if (maxProducts != null && products.length >= maxProducts) break;

      final uri = Uri.parse('$root/wp-json/wc/store/v1/products').replace(
        queryParameters: {
          'per_page': '$perPage',
          'page': '$page',
        },
      );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'WooCommerce HTTP ${response.statusCode} for $supplierId page $page',
        );
      }

      final totalHeader = response.headers['x-wp-totalpages'];
      totalPages = int.tryParse(totalHeader ?? '') ?? totalPages;
      if (totalPages < 1) totalPages = 1;

      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! List) {
        throw StateError('Unexpected WooCommerce payload for $supplierId');
      }

      for (final item in decoded) {
        if (item is! Map) continue;
        final mapped = _mapProduct(Map<String, dynamic>.from(item));
        if (mapped == null) continue;
        products.add(mapped);
        if (maxProducts != null && products.length >= maxProducts) break;
      }

      onProgress?.call(
        WooFetchProgress(
          supplierId: supplierId,
          page: page,
          totalPages: totalPages,
          productsSoFar: products.length,
        ),
      );

      page++;
      if (page <= totalPages && delayBetweenPages > Duration.zero) {
        await Future<void>.delayed(delayBetweenPages);
      }
    }

    return products;
  }

  /// Live search on a single WooCommerce store (public Store API).
  Future<List<WooImportedProduct>> searchProducts({
    required String baseUrl,
    required String query,
    int perPage = 12,
  }) async {
    if (kIsWeb) return const [];
    final q = query.trim();
    if (q.isEmpty) return const [];

    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$root/wp-json/wc/store/v1/products').replace(
      queryParameters: {
        'search': q,
        'per_page': '$perPage',
        'page': '1',
      },
    );

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! List) return const [];
      final out = <WooImportedProduct>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final mapped = _mapProduct(Map<String, dynamic>.from(item));
        if (mapped != null) out.add(mapped);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  WooImportedProduct? _mapProduct(Map<String, dynamic> json) {
    final id = json['id'];
    final name = (json['name']?.toString() ?? '').trim();
    if (id is! num || name.isEmpty) return null;

    final prices = json['prices'];
    num price = 0;
    var currency = 'EGP';
    if (prices is Map) {
      currency = prices['currency_code']?.toString() ?? 'EGP';
      final minor = int.tryParse('${prices['currency_minor_unit'] ?? 2}') ?? 2;
      final raw = num.tryParse('${prices['price'] ?? 0}') ?? 0;
      price = raw / _pow10(minor);
    }

    final images = json['images'];
    String? imageUrl;
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        imageUrl = first['src']?.toString() ?? first['thumbnail']?.toString();
      }
    }

    final categories = <String>[];
    final cats = json['categories'];
    if (cats is List) {
      for (final c in cats) {
        if (c is Map) {
          final n = c['name']?.toString().trim() ?? '';
          if (n.isNotEmpty) categories.add(n);
        }
      }
    }

    final description = _stripHtml(
      (json['short_description']?.toString().trim().isNotEmpty == true)
          ? json['short_description'].toString()
          : (json['description']?.toString() ?? ''),
    );

    return WooImportedProduct(
      externalId: id.toInt(),
      name: _decodeHtml(name),
      permalink: json['permalink']?.toString() ?? '',
      description: description,
      sku: json['sku']?.toString() ?? '',
      price: price,
      currency: currency,
      imageUrl: imageUrl,
      categoryNames: categories,
      inStock: json['is_in_stock'] != false,
    );
  }

  static num _pow10(int exp) {
    var v = 1;
    for (var i = 0; i < exp; i++) {
      v *= 10;
    }
    return v;
  }

  static String _stripHtml(String raw) {
    return _decodeHtml(
      raw
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    );
  }

  static String _decodeHtml(String raw) {
    return raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}
