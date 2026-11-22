import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// منتجات يحفظها المشتري على الجهاز. ليست عملة ولا رصيداً.
class StoreFavorites extends ChangeNotifier {
  StoreFavorites._();

  static final StoreFavorites instance = StoreFavorites._();
  static const _key = 'store_favorite_product_ids';

  final Set<String> _ids = {};
  bool _loaded = false;

  Set<String> get ids => Set.unmodifiable(_ids);

  bool contains(String id) => _ids.contains(id);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? const []);
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(String productId) async {
    if (productId.trim().isEmpty) return;
    await ensureLoaded();
    if (!_ids.add(productId)) _ids.remove(productId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());
    notifyListeners();
  }
}
