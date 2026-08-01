import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/escrow/payment_status.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/payments/payment_method.dart';
import '../messaging/chat_screen.dart';
import '../messaging/messaging_models.dart';
import '../messaging/messaging_service.dart';
import '../moderation/approval_status.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';
import 'store_categories.dart';
import 'store_order_service.dart';

/// لوحة المورد داخل المتجر: منتجاته + إضافة المزيد + الطلبات الواردة.
class MerchantStoreScreen extends StatefulWidget {
  const MerchantStoreScreen({super.key});

  @override
  State<MerchantStoreScreen> createState() => _MerchantStoreScreenState();
}

class _MerchantStoreScreenState extends State<MerchantStoreScreen>
    with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFFE65100);

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    final category = await showModalBottomSheet<StoreCategory>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  ctx.t('اختر قسم المنتج', 'Choose product category'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ctx.t(
                    'ثم أضف المنتج — يمكنك إضافة أكثر من منتج من هذه الصفحة',
                    'Then add the product — you can add more from this page',
                  ),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: storeCategories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = storeCategories[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: c.color.withValues(alpha: 0.15),
                          child: Icon(c.icon, color: c.color, size: 22),
                        ),
                        title: Text(L10nLookup.storeCategoryTitle(c.id)),
                        subtitle: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? c.audienceAr
                              : c.audienceEn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(ctx, c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (category == null || !mounted) return;

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(categoryTitle: category.title),
      ),
    );

    if (!mounted || created != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'تم إرسال المنتج للمراجعة — يمكنك إضافة منتج آخر من الزر أدناه',
            'Product sent for review — add another with the button below',
          ),
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: context.t('إضافة آخر', 'Add another'),
          onPressed: _addProduct,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AcadeGateAppBar(
        title: Text(context.t('متجري', 'My store')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: context.t('منتجاتي', 'My products')),
            Tab(text: context.t('الطلبات', 'Orders')),
          ],
        ),
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addProduct,
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(context.t('إضافة منتج', 'Add product')),
            ),
      body: user == null
          ? Center(
              child: Text(
                context.t(
                  'سجّل الدخول لإدارة متجرك',
                  'Sign in to manage your store',
                ),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _MyProductsTab(uid: user.uid, onAdd: _addProduct),
                const _SellerOrdersTab(),
              ],
            ),
    );
  }
}

class _MyProductsTab extends StatelessWidget {
  final String uid;
  final VoidCallback onAdd;

  const _MyProductsTab({required this.uid, required this.onAdd});

  String _formatPrice(num price) => '$price ${appTr('ج.م', 'EGP')}';

  Color _statusColor(String? status) {
    switch (status) {
      case ApprovalStatus.approved:
        return const Color(0xFF2E7D32);
      case ApprovalStatus.rejected:
        return const Color(0xFFC62828);
      case ApprovalStatus.suspended:
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFFEF6C00);
    }
  }

  Future<void> _deleteProduct(BuildContext context, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('حذف المنتج؟', 'Delete product?')),
        content: Text(
          ctx.t(
            'سيتم حذف «$name» نهائياً.',
            '«$name» will be permanently deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('product').doc(id).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم الحذف', 'Deleted')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('فشل الحذف', 'Delete failed')}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('product')
          .where('createdBy', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${context.t('تعذر تحميل المنتجات', 'Could not load products')}\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    context.t('لا منتجات بعد', 'No products yet'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'أضف أول منتجك ثم تابع إضافة المزيد من نفس الصفحة',
                      'Add your first product, then keep adding more here',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(context.t('إضافة منتج', 'Add product')),
                  ),
                ],
              ),
            ),
          );
        }

        final sorted = [...docs]..sort((a, b) {
            final aAt = (a.data() as Map?)?['createdAt'];
            final bAt = (b.data() as Map?)?['createdAt'];
            if (aAt is Timestamp && bAt is Timestamp) {
              return bAt.compareTo(aAt);
            }
            if (aAt is Timestamp) return -1;
            if (bAt is Timestamp) return 1;
            return 0;
          });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final doc = sorted[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name']?.toString() ?? '—';
            final price = data['price'] is num
                ? data['price'] as num
                : num.tryParse('${data['price']}') ?? 0;
            final category = data['category']?.toString() ?? '';
            final storeName = data['storeName']?.toString() ?? '';
            final status = data['approvalStatus']?.toString() ?? ApprovalStatus.pending;
            final imageUrl = data['imageUrl']?.toString();
            final description = data['description']?.toString() ?? '';
            final contact = data['contact']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: Colors.orange.shade50,
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: Colors.orange.shade50,
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFFE65100),
                            ),
                          ),
                  ),
                ),
                title: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${_formatPrice(price)}${category.isNotEmpty ? ' · $category' : ''}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    if (storeName.isNotEmpty)
                      Text(
                        storeName,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ApprovalStatus.label(status),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                            name: name,
                            price: _formatPrice(price),
                            description: description,
                            storeName: storeName,
                            contact: contact,
                            productId: doc.id,
                            createdBy: uid,
                            priceValue: price,
                            imageUrl: imageUrl,
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      _deleteProduct(context, doc.id, name);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Text(ctx.t('عرض', 'View')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        ctx.t('حذف', 'Delete'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        name: name,
                        price: _formatPrice(price),
                        description: description,
                        storeName: storeName,
                        contact: contact,
                        productId: doc.id,
                        createdBy: uid,
                        priceValue: price,
                        imageUrl: imageUrl,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _SellerOrdersTab extends StatelessWidget {
  const _SellerOrdersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoreOrder>>(
      stream: StoreOrderService.instance.sellerOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${context.t('تعذر تحميل الطلبات', 'Could not load orders')}\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final orders = [...(snapshot.data ?? [])]..sort((a, b) {
            final aAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bAt.compareTo(aAt);
          });

        if (orders.isEmpty) {
          return Center(
            child: Text(
              context.t('لا توجد طلبات شراء بعد', 'No purchase orders yet'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: orders.length,
          itemBuilder: (context, i) => _SellerOrderCard(order: orders[i]),
        );
      },
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  final StoreOrder order;

  const _SellerOrderCard({required this.order});

  Future<void> _confirmTransfer(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('تأكيد استلام التحويل؟', 'Confirm transfer received?')),
        content: Text(
          ctx.t(
            'أكد فقط بعد التحقق من وصول المبلغ لحسابك.',
            'Confirm only after the amount reached your account.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('تأكيد', 'Confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final orderId = order.id;
    if (orderId == null || orderId.isEmpty) return;

    try {
      await StoreOrderService.instance.confirmManualPaymentReceived(orderId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم تأكيد التحويل', 'Transfer confirmed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _messageBuyer(BuildContext context) async {
    final buyerId = order.buyerId;
    final user = FirebaseAuth.instance.currentUser;
    if (buyerId.isEmpty || user == null) return;

    // Same thread as student "Message supplier" on the product page.
    final productId = order.productId.trim();
    final contextType = productId.isNotEmpty ? 'product' : 'store_order';
    final contextId =
        productId.isNotEmpty ? productId : (order.id ?? order.productId);

    try {
      final conversationId = await MessagingService.instance.openConversation(
        otherUserId: buyerId,
        otherUserName: order.buyerName,
        contextType: contextType,
        contextId: contextId,
        contextTitle: order.productName,
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversation: Conversation(
              id: conversationId,
              participantIds: [user.uid, buyerId],
              participantNames: {buyerId: order.buyerName},
              contextType: contextType,
              contextId: contextId,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManual = order.paymentMethod == PaymentMethod.manual;
    final canConfirmManual = isManual &&
        order.paymentStatus != PaymentStatus.held &&
        order.paymentStatus != PaymentStatus.released;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.productName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '${order.buyerName} · ${order.price} ${appTr('ج.م', 'EGP')}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    isManual
                        ? context.t('تحويل يدوي', 'Manual transfer')
                        : context.t('Paymob', 'Paymob'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    PaymentStatus.label(order.paymentStatus),
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (canConfirmManual)
                  FilledButton(
                    onPressed: () => _confirmTransfer(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                    ),
                    child: Text(
                      context.t('تأكيد التحويل', 'Confirm transfer'),
                    ),
                  ),
                if (canConfirmManual) const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _messageBuyer(context),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: Text(context.t('مراسلة', 'Message')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
