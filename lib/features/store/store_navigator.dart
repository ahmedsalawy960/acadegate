import 'package:flutter/material.dart';

import 'product_list_screen.dart';
import 'store_categories.dart';
import 'store_hub_screen.dart';

class StoreNavigator {
  static void openStore(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StoreHubScreen()),
    );
  }

  static void openStoreCategory(BuildContext context, String categoryTitle) {
    // طبيعياً نفتح القسم بالعنوان الكانوني إن وُجد alias قديم
    final category = storeCategoryByTitle(categoryTitle);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductListScreen(
          categoryTitle: category?.title ?? categoryTitle,
        ),
      ),
    );
  }
}
