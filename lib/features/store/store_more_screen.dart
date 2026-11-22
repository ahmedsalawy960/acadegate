import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/acadegate_app_bar.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import 'ai_compare/store_ai_compare_screen.dart';
import 'store_catalog_service.dart';
import 'store_favorites.dart';
import 'store_order_service.dart';
import 'store_product_navigation.dart';
import 'store_theme.dart';

/// صفحة المتجر: الطلبات والمفضلة والعروض والمقارنة.
class StoreMoreScreen extends StatelessWidget {
  const StoreMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(context.t('حساب المتجر', 'Store account')),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            StreamBuilder(
              stream: UserAccountService.instance.watchCurrentAccount(),
              builder: (context, snapshot) {
                final account = snapshot.data;
                final name = account?.displayName.trim().isNotEmpty == true
                    ? account!.displayName.trim()
                    : (user?.displayName ?? '');
                final email = account?.email ?? user?.email ?? '';
                final role = UserRole.label(account?.role ?? UserRole.student);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StoreTheme.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('أهلاً', 'Hello'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name.isEmpty ? context.t('حسابك', 'Your account') : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(email, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text(
                        context.t('نوع الحساب: $role', 'Account type: $role'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<StoreOrder>>(
              stream: StoreOrderService.instance.buyerOrdersStream(),
              builder: (context, snapshot) {
                final paid = (snapshot.data ?? const <StoreOrder>[])
                    .where((o) => !o.isPendingPayment)
                    .length;
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.stars_outlined,
                        value: '$paid',
                        label: context.t('نقاط الطلبات', 'Order points'),
                        hint: context.t(
                          'نقطة لكل طلب دُفع. ليست رصيداً يُصرف.',
                          'One point per paid order. Not spendable credit.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        value: context.t('عند الطلب', 'Per order'),
                        label: context.t('الدفع', 'Payment'),
                        hint: context.t(
                          'لا يوجد رصيد مخزّن. كل شراء يُدفع وقت الطلب.',
                          'No stored balance. Each purchase is paid at checkout.',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _Row(
              icon: Icons.receipt_long_outlined,
              title: context.t('طلباتي', 'My orders'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreBuyerOrdersScreen()),
              ),
            ),
            _Row(
              icon: Icons.favorite_border,
              title: context.t('المفضلة لدي', 'Favorites'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreFavoritesScreen()),
              ),
            ),
            _Row(
              icon: Icons.local_offer_outlined,
              title: context.t('الخصومات', 'Offers'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreOffersScreen()),
              ),
            ),
            _Row(
              icon: Icons.price_check,
              title: context.t('مقارنة الأسعار', 'Compare prices'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreAiCompareScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String value;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StoreTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StoreTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: StoreTheme.accent),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(fontSize: 11, color: StoreTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: StoreTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: StoreTheme.border),
          ),
          leading: CircleAvatar(
            backgroundColor: StoreTheme.accent.withValues(alpha: 0.12),
            child: Icon(icon, color: StoreTheme.accent),
          ),
          title: Text(title),
          onTap: onTap,
        ),
      ),
    );
  }
}

class StoreBuyerOrdersScreen extends StatelessWidget {
  const StoreBuyerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(context.t('طلباتي', 'My orders')),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: StoreTheme.appBarForeground,
      ),
      body: StreamBuilder<List<StoreOrder>>(
        stream: StoreOrderService.instance.buyerOrdersStream(),
        builder: (context, snapshot) {
          final orders = [...?snapshot.data]
            ..sort((a, b) {
              final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });
          if (orders.isEmpty) {
            return Center(
              child: Text(
                context.t('لا توجد طلبات بعد.', 'No orders yet.'),
                style: const TextStyle(color: StoreTheme.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final order = orders[i];
              return ListTile(
                tileColor: StoreTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: StoreTheme.border),
                ),
                title: Text(order.productName),
                subtitle: Text(
                  '${order.price} ${context.t('ج.م', 'EGP')} · ${order.paymentStatus}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StoreFavoritesScreen extends StatefulWidget {
  const StoreFavoritesScreen({super.key});

  @override
  State<StoreFavoritesScreen> createState() => _StoreFavoritesScreenState();
}

class _StoreFavoritesScreenState extends State<StoreFavoritesScreen> {
  List<StoreCatalogProduct> _products = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    StoreFavorites.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    StoreFavorites.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    await StoreFavorites.instance.ensureLoaded();
    final catalog = await StoreCatalogService.instance.loadPublicCatalog();
    final ids = StoreFavorites.instance.ids;
    if (!mounted) return;
    setState(() {
      _products = catalog.products.where((p) => ids.contains(p.id)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(context.t('المفضلة لدي', 'Favorites')),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: StoreTheme.appBarForeground,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Text(
                    context.t(
                      'لم تحفظ منتجات بعد. اضغط القلب على بطاقة المنتج.',
                      'No saved products yet. Tap the heart on a product card.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: StoreTheme.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final product = _products[i];
                    return ListTile(
                      tileColor: StoreTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: StoreTheme.border),
                      ),
                      title: Text(product.name),
                      subtitle: Text(product.storeName),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.redAccent),
                        onPressed: () => StoreFavorites.instance.toggle(product.id),
                      ),
                      onTap: () => openStoreProductDetail(context, product),
                    );
                  },
                ),
    );
  }
}

class StoreOffersScreen extends StatelessWidget {
  const StoreOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(context.t('الخصومات', 'Offers')),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: StoreTheme.appBarForeground,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          context.t(
            'لا نعرض خصماً إلا إذا كتبه المورد على منتج Partner. قوائم الدليل أسعار معلنة وليست عرضاً من AcadeGate. قارن السعر بين البائعين من زر المقارنة.',
            'A discount is shown only when a Partner seller sets it on a product. Directory prices are published listings, not an AcadeGate sale. Compare sellers from the compare action.',
          ),
          style: const TextStyle(height: 1.5, color: StoreTheme.ink),
        ),
      ),
    );
  }
}

