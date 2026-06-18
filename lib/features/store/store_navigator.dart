import 'package:flutter/material.dart';
import 'store_categories_screen.dart';
import 'product_list_screen.dart';

class StoreNavigator {
  static void openStore(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StoreCategoriesScreen()),
    );
  }

  static void openStoreCategory(BuildContext context, String categoryTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductListScreen(categoryTitle: categoryTitle),
      ),
    );
  }
}
