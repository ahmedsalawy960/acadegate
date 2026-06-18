import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../moderation/approval_status.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';
import 'store_categories.dart';

class ProductListScreen extends StatelessWidget {
  final String categoryTitle;

  const ProductListScreen({super.key, required this.categoryTitle});

  @override
  Widget build(BuildContext context) {
    final category = storeCategoryByTitle(categoryTitle);
    final accentColor = category?.color ?? Colors.green[700]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'إضافة منتج',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddProductScreen(categoryTitle: categoryTitle),
                ),
              );

              if (!context.mounted) return;
              if (created == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال المنتج للمراجعة — سيظهر بعد الموافقة'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('product')
            .where('category', isEqualTo: categoryTitle)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['approvalStatus']?.toString();
            return ApprovalStatus.isPublic(status);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد منتجات في هذا القسم حالياً',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تأكد أن حقل category في Firebase يساوي:\n"$categoryTitle"',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final productData = docs[index].data() as Map<String, dynamic>;
              return _ProductCard(
                name: productData['name']?.toString() ?? 'منتج',
                price: '${productData['price'] ?? 0} ج.م',
                icon: category?.icon ?? Icons.shopping_bag_outlined,
                color: accentColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        name: productData['name']?.toString() ?? 'بدون اسم',
                        price: '${productData['price'] ?? 0} ج.م',
                        description:
                            productData['description']?.toString() ??
                            'لا يوجد وصف متاح لهذا المنتج حالياً.',
                        storeName:
                            productData['storeName']?.toString() ??
                            'متجر غير معروف',
                        contact: productData['contact']?.toString() ?? '',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String price;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ProductCard({
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Icon(icon, size: 45, color: color),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
