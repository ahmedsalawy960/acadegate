import 'package:flutter/material.dart';

import '../moderation/delete_content_button.dart';

class ProductDetailScreen extends StatelessWidget {
  final String name;
  final String price;
  final String description;
  final String storeName;
  final String contact;
  final String? productId;
  final String? createdBy;

  const ProductDetailScreen({
    super.key,
    required this.name,
    required this.price,
    required this.description,
    required this.storeName,
    required this.contact,
    this.productId,
    this.createdBy,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنتج'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: deleteAppBarActions(
          collection: 'product',
          documentId: productId,
          ownerId: createdBy,
          itemLabel: name,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_outlined,
                    size: 80, color: Colors.green[700]),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 32),
            const Text(
              'المورد / المتجر:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              storeName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            const Text(
              'وصف المنتج:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'رقم التواصل:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                contact,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: contact.isEmpty
                    ? null
                    : () {
                        // يمكن ربط url_launcher لاحقاً للاتصال المباشر
                      },
                icon: const Icon(Icons.phone),
                label: const Text(
                  'اتصال بالمورد الآن',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            ManageContentActions(
              collection: 'product',
              documentId: productId,
              ownerId: createdBy,
              itemLabel: name,
            ),
          ],
        ),
      ),
    );
  }
}
