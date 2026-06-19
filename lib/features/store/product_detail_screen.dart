import 'package:flutter/material.dart';

import '../auth/auth_guard.dart';
import '../messaging/conversations_screen.dart';
import 'store_order_service.dart';
import '../moderation/delete_content_button.dart';

class ProductDetailScreen extends StatelessWidget {
  final String name;
  final String price;
  final String description;
  final String storeName;
  final String contact;
  final String? productId;
  final String? createdBy;
  final num priceValue;
  final String? imageUrl;

  const ProductDetailScreen({
    super.key,
    required this.name,
    required this.price,
    required this.description,
    required this.storeName,
    required this.contact,
    this.productId,
    this.createdBy,
    this.priceValue = 0,
    this.imageUrl,
  });

  Future<void> _purchase(BuildContext context) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !context.mounted) return;
    if (productId == null || createdBy == null || createdBy!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الشراء متاح للمنتجات المسجلة فقط')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('شراء مع ضمان'),
        content: Text(
          'سيتم حجز $price في المنصة حتى تؤكد استلام المنتج.\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final orderId = await StoreOrderService.instance.createOrder(
        productId: productId!,
        productName: name,
        price: priceValue > 0 ? priceValue : 0,
        sellerId: createdBy!,
      );
      await StoreOrderService.instance.payOrder(orderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الدفع — المبلغ محجوز حتى تأكيد الاستلام'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderIcon(),
                      ),
                    )
                  : _placeholderIcon(),
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
            Text(
              storeName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Text(description, style: const TextStyle(fontSize: 15, height: 1.5)),
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(contact, style: const TextStyle(fontSize: 16)),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: productId == null ? null : () => _purchase(context),
                icon: const Icon(Icons.lock),
                label: const Text('شراء مع ضمان (Escrow)'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[700],
                ),
              ),
            ),
            if (createdBy != null && createdBy!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final loggedIn = await ensureLoggedIn(context);
                    if (!loggedIn || !context.mounted) return;
                    await openChatWithUser(
                      context,
                      otherUserId: createdBy!,
                      otherUserName: storeName,
                      contextType: 'product',
                      contextId: productId ?? '',
                      contextTitle: name,
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('مراسلة المورد'),
                ),
              ),
            ],
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

  Widget _placeholderIcon() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.green[50],
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.inventory_2_outlined, size: 80, color: Colors.green[700]),
    );
  }
}
