import 'package:flutter/foundation.dart';

/// عنصر في عربة المتجر (محلي على الجهاز).
class StoreCartItem {
  final String productId;
  final String name;
  final num price;
  final String storeName;
  final String sellerId;
  final String? imageUrl;
  final bool isDirectoryListing;
  final int quantity;
  final String? category;
  final String? description;

  const StoreCartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.storeName,
    required this.sellerId,
    this.imageUrl,
    this.isDirectoryListing = false,
    this.quantity = 1,
    this.category,
    this.description,
  });

  StoreCartItem copyWith({int? quantity}) => StoreCartItem(
        productId: productId,
        name: name,
        price: price,
        storeName: storeName,
        sellerId: sellerId,
        imageUrl: imageUrl,
        isDirectoryListing: isDirectoryListing,
        quantity: quantity ?? this.quantity,
        category: category,
        description: description,
      );

  num get lineTotal => price * quantity;
}

/// عربة تسوق محلية — الطلبات تُنشأ عند الدفع عبر Escrow لكل صنف.
class StoreCartService extends ChangeNotifier {
  StoreCartService._();
  static final StoreCartService instance = StoreCartService._();

  final List<StoreCartItem> _items = [];

  List<StoreCartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold<int>(0, (s, e) => s + e.quantity);

  num get subtotal =>
      _items.fold<num>(0, (s, e) => s + e.lineTotal);

  /// أصناف قابلة للدفع عبر Escrow فقط.
  List<StoreCartItem> get escrowItems => _items
      .where((e) => !e.isDirectoryListing && e.price > 0 && e.sellerId.isNotEmpty)
      .toList();

  Map<String, List<StoreCartItem>> get groupedBySeller {
    final map = <String, List<StoreCartItem>>{};
    for (final item in escrowItems) {
      map.putIfAbsent(item.sellerId, () => []).add(item);
    }
    return map;
  }

  void add(StoreCartItem item) {
    final i = _items.indexWhere((e) => e.productId == item.productId);
    if (i >= 0) {
      _items[i] = _items[i].copyWith(quantity: _items[i].quantity + item.quantity);
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void setQuantity(String productId, int quantity) {
    final i = _items.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    if (quantity <= 0) {
      _items.removeAt(i);
    } else {
      _items[i] = _items[i].copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  void remove(String productId) {
    _items.removeWhere((e) => e.productId == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void removeIds(Iterable<String> productIds) {
    final set = productIds.toSet();
    _items.removeWhere((e) => set.contains(e.productId));
    notifyListeners();
  }
}
