import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/escrow/payment_status.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/payments/payment_method.dart';
import '../messaging/chat_screen.dart';
import '../messaging/messaging_models.dart';
import '../messaging/messaging_service.dart';
import '../moderation/approval_status.dart';
import 'add_product_screen.dart';
import 'assembly_guide/assembly_guide_screen.dart';
import 'assembly_guide/assembly_guide_service.dart';
import 'assembly_guide/edit_assembly_guide_screen.dart';
import 'bulk/bulk_listing_form.dart';
import 'bulk/merchant_product_bulk_service.dart';
import 'bulk/product_import_parser.dart';
import 'bulk/product_sheet_import_screen.dart';
import 'bulk/woo_store_link_screen.dart';
import 'product_detail_screen.dart';
import 'store_categories.dart';
import 'store_order_service.dart';
import 'store_theme.dart';

/// لوحة المورد داخل المتجر: منتجاته + إضافة المزيد + الطلبات الواردة.
class MerchantStoreScreen extends StatefulWidget {
  const MerchantStoreScreen({super.key});

  @override
  State<MerchantStoreScreen> createState() => _MerchantStoreScreenState();
}

class _MerchantStoreScreenState extends State<MerchantStoreScreen>
    with SingleTickerProviderStateMixin {
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

  Future<void> _showAddOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ctx.t('كيف تريد إضافة منتجاتك؟', 'How do you want to add products?'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.add_box_outlined, color: StoreTheme.ink),
                title: Text(ctx.t('منتج واحد', 'Single product')),
                subtitle: Text(ctx.t('نموذج كامل مع صورة', 'Full form with image')),
                onTap: () => Navigator.pop(ctx, 'single'),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined, color: StoreTheme.ink),
                title: Text(ctx.t('رفع قائمة (Excel / CSV)', 'Upload list (Excel / CSV)')),
                subtitle: Text(ctx.t(
                  'عشرات أو مئات المنتجات دفعة واحدة من قالب جاهز',
                  'Tens or hundreds of products at once from a template',
                )),
                onTap: () => Navigator.pop(ctx, 'sheet'),
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: StoreTheme.ink),
                title: Text(ctx.t('ربط متجري الإلكتروني', 'Link my online store')),
                subtitle: Text(ctx.t(
                  'سحب الكتالوج من متجر WooCommerce مع التحديث لاحقاً',
                  'Pull the catalog from a WooCommerce shop and refresh later',
                )),
                onTap: () => Navigator.pop(ctx, 'woo'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;

    final Widget? screen = switch (choice) {
      'sheet' => const ProductSheetImportScreen(),
      'woo' => const WooStoreLinkScreen(),
      _ => null,
    };
    if (screen == null) {
      await _addProduct();
      return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _addProduct() async {
    final category = await pickStoreCategory(
      context,
      subtitleAr: 'ثم أضف المنتج — يمكنك إضافة أكثر من منتج من هذه الصفحة',
      subtitleEn: 'Then add the product — you can add more from this page',
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
            'تم حفظ المنتج — يمكنك إضافة منتج آخر من الزر أدناه',
            'Product saved — add another with the button below',
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

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(context.t('متجري', 'My store')),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: StoreTheme.accent,
            labelColor: StoreTheme.ink,
            unselectedLabelColor: StoreTheme.muted,
            tabs: [
              Tab(text: context.t('منتجاتي', 'My products')),
              Tab(text: context.t('الطلبات', 'Orders')),
            ],
          ),
        ),
        floatingActionButton: user == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _showAddOptions,
                backgroundColor: StoreTheme.accent,
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
                  _MyProductsTab(uid: user.uid, onAdd: _showAddOptions),
                  const _SellerOrdersTab(),
                ],
              ),
      ),
    );
  }
}

class _MyProductsTab extends StatefulWidget {
  final String uid;
  final VoidCallback onAdd;

  const _MyProductsTab({required this.uid, required this.onAdd});

  @override
  State<_MyProductsTab> createState() => _MyProductsTabState();
}

class _MyProductsTabState extends State<_MyProductsTab> {
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _bulkBusy = false;

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<void> _duplicate(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    final category = data['category']?.toString() ?? '';
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          categoryTitle: category.isEmpty ? storeCategories.last.title : category,
          supplierId: data['supplierId']?.toString(),
          duplicateOf: ProductDuplicateSource(id: id, data: data),
        ),
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم إنشاء النسخة', 'Copy created')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _runBulk(
    BuildContext context,
    Future<void> Function() action,
    String doneAr,
    String doneEn,
  ) async {
    setState(() => _bulkBusy = true);
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(doneAr, doneEn)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _exitSelection();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('فشلت العملية', 'Operation failed')}: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _bulkPrice(
    BuildContext context,
    Map<String, num> currentPrices,
  ) async {
    final input = await showDialog<(BulkPriceMode, num)>(
      context: context,
      builder: (_) => const _BulkPriceDialog(),
    );
    if (input == null || !context.mounted) return;
    final n = currentPrices.length;
    await _runBulk(
      context,
      () => MerchantProductBulkService.instance.adjustPrices(
        currentPrices: currentPrices,
        mode: input.$1,
        value: input.$2,
      ),
      'تم تحديث سعر $n منتج',
      'Updated price of $n product(s)',
    );
  }

  Future<void> _bulkStock(BuildContext context, bool inStock) {
    final n = _selected.length;
    return _runBulk(
      context,
      () => MerchantProductBulkService.instance
          .updateFields(_selected.toList(), {'inStock': inStock}),
      inStock ? 'تم تعيين $n منتج كمتوفر' : 'تم تعيين $n منتج كغير متوفر',
      inStock ? 'Marked $n product(s) in stock' : 'Marked $n product(s) out of stock',
    );
  }

  Future<void> _bulkCategory(BuildContext context) async {
    final category = await pickStoreCategory(context);
    if (category == null || !context.mounted) return;
    final n = _selected.length;
    await _runBulk(
      context,
      () => MerchantProductBulkService.instance
          .updateFields(_selected.toList(), {'category': category.title}),
      'تم نقل $n منتج إلى القسم الجديد',
      'Moved $n product(s) to the new category',
    );
  }

  Future<void> _bulkDelete(BuildContext context) async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('حذف $n منتج؟', 'Delete $n product(s)?')),
        content: Text(ctx.t(
          'سيتم حذف المنتجات المحددة نهائياً.',
          'The selected products will be permanently deleted.',
        )),
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
    if (ok != true || !context.mounted) return;
    await _runBulk(
      context,
      () => MerchantProductBulkService.instance.deleteAll(_selected.toList()),
      'تم حذف $n منتج',
      'Deleted $n product(s)',
    );
  }

  Widget _selectionBar(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
  ) {
    final allSelected = _selected.length == docs.length;
    final prices = <String, num>{
      for (final d in docs)
        if (_selected.contains(d.id))
          d.id: (d.data() as Map<String, dynamic>)['price'] is num
              ? (d.data() as Map<String, dynamic>)['price'] as num
              : num.tryParse('${(d.data() as Map)['price']}') ?? 0,
    };
    final enabled = !_bulkBusy && _selected.isNotEmpty;
    return Material(
      color: StoreTheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.t('إلغاء التحديد', 'Cancel selection'),
                  icon: const Icon(Icons.close),
                  onPressed: _bulkBusy ? null : _exitSelection,
                ),
                Expanded(
                  child: Text(
                    context.t('${_selected.length} محدد', '${_selected.length} selected'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _bulkBusy
                      ? null
                      : () => setState(() {
                            if (allSelected) {
                              _selected.clear();
                            } else {
                              _selected.addAll(docs.map((d) => d.id));
                            }
                          }),
                  child: Text(allSelected
                      ? context.t('إلغاء الكل', 'Clear all')
                      : context.t('تحديد الكل', 'Select all')),
                ),
              ],
            ),
            if (_bulkBusy) const LinearProgressIndicator(minHeight: 2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _bulkButton(Icons.sell_outlined, context.t('السعر', 'Price'),
                      enabled ? () => _bulkPrice(context, prices) : null),
                  _bulkButton(Icons.check_circle_outline,
                      context.t('متوفر', 'In stock'),
                      enabled ? () => _bulkStock(context, true) : null),
                  _bulkButton(Icons.remove_shopping_cart_outlined,
                      context.t('غير متوفر', 'Out of stock'),
                      enabled ? () => _bulkStock(context, false) : null),
                  _bulkButton(Icons.category_outlined,
                      context.t('القسم', 'Category'),
                      enabled ? () => _bulkCategory(context) : null),
                  _bulkButton(Icons.delete_outline, context.t('حذف', 'Delete'),
                      enabled ? () => _bulkDelete(context) : null,
                      color: Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulkButton(
    IconData icon,
    String label,
    VoidCallback? onPressed, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? StoreTheme.ink,
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  String _formatPrice(num price) => '$price ${appTr('ج.م', 'EGP')}';

  Color _statusColor(String? status) {
    switch (status) {
      case ApprovalStatus.approved:
        return StoreTheme.verified;
      case ApprovalStatus.rejected:
        return StoreTheme.danger;
      case ApprovalStatus.suspended:
        return const Color(0xFF475569);
      default:
        return StoreTheme.accent;
    }
  }

  Future<void> _tryGuide(BuildContext context, String productId, String name) async {
    try {
      final guide = await AssemblyGuideService.instance.ensurePlayableGuide(
        productId: productId,
        productName: name,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssemblyGuideScreen(
            productId: productId,
            productName: name,
            guide: guide,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
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
          .where('createdBy', isEqualTo: widget.uid)
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
                    style: TextStyle(color: StoreTheme.muted),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: widget.onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: StoreTheme.accent,
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

        return Column(
          children: [
            if (_selecting)
              _selectionBar(context, sorted)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t('${sorted.length} منتج', '${sorted.length} products'),
                        style: TextStyle(color: StoreTheme.muted),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _selecting = true),
                      icon: const Icon(Icons.checklist, size: 18),
                      label: Text(context.t('تحديد وتعديل جماعي', 'Select & bulk edit')),
                    ),
                  ],
                ),
              ),
            Expanded(child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final doc = sorted[index];
            final data = doc.data() as Map<String, dynamic>;
            final isSelected = _selected.contains(doc.id);
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
              shape: isSelected
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: StoreTheme.accent, width: 2),
                    )
                  : null,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onLongPress: _selecting
                    ? null
                    : () => setState(() {
                          _selecting = true;
                          _selected.add(doc.id);
                        }),
                leading: _selecting
                    ? Checkbox(
                        value: isSelected,
                        activeColor: StoreTheme.accent,
                        onChanged: (_) => _toggle(doc.id),
                      )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: StoreTheme.accentSoft,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: StoreTheme.ink,
                              ),
                            ),
                          )
                        : const ColoredBox(
                            color: StoreTheme.accentSoft,
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: StoreTheme.ink,
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
                      style: TextStyle(color: StoreTheme.muted, fontSize: 13),
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
                trailing: _selecting ? null : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'duplicate') {
                      _duplicate(context, doc.id, data);
                    } else if (value == 'view') {
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
                            createdBy: widget.uid,
                            priceValue: price,
                            imageUrl: imageUrl,
                          ),
                        ),
                      );
                    } else if (value == 'try_guide') {
                      _tryGuide(context, doc.id, name);
                    } else if (value == 'guide') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditAssemblyGuideScreen(
                            productId: doc.id,
                            productName: name,
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
                      value: 'duplicate',
                      child: Text(ctx.t('نسخ كمنتج جديد', 'Duplicate as new product')),
                    ),
                    PopupMenuItem(
                      value: 'try_guide',
                      child: Text(ctx.t(
                        'جرّب الدليل الآن',
                        'Try the guide now',
                      )),
                    ),
                    PopupMenuItem(
                      value: 'guide',
                      child: Text(ctx.t(
                        'تعديل الدليل التفاعلي',
                        'Edit interactive product guide',
                      )),
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
                  if (_selecting) {
                    _toggle(doc.id);
                    return;
                  }
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
                        createdBy: widget.uid,
                        priceValue: price,
                        imageUrl: imageUrl,
                      ),
                    ),
                  );
                },
              ),
            );
          },
            )),
          ],
        );
      },
    );
  }
}

class _BulkPriceDialog extends StatefulWidget {
  const _BulkPriceDialog();

  @override
  State<_BulkPriceDialog> createState() => _BulkPriceDialogState();
}

class _BulkPriceDialogState extends State<_BulkPriceDialog> {
  BulkPriceMode _mode = BulkPriceMode.percent;
  final _value = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final v = ProductImportParser.parsePrice(_value.text.trim().replaceFirst('-', ''));
    final negative = _value.text.trim().startsWith('-');
    if (v == null) {
      setState(() => _error = context.t('أدخل رقماً صحيحاً', 'Enter a valid number'));
      return;
    }
    final value = negative ? -v : v;
    if (_mode == BulkPriceMode.setExact && value < 0) {
      setState(() => _error = context.t('السعر لا يمكن أن يكون سالباً', 'Price cannot be negative'));
      return;
    }
    Navigator.pop(context, (_mode, value));
  }

  @override
  Widget build(BuildContext context) {
    final hint = switch (_mode) {
      BulkPriceMode.percent => context.t('مثال: 10 للزيادة أو -5 للخصم', 'e.g. 10 to raise or -5 to discount'),
      BulkPriceMode.add => context.t('مثال: 25 أو -25 ج.م', 'e.g. 25 or -25 EGP'),
      BulkPriceMode.setExact => context.t('السعر الجديد لكل المنتجات المحددة', 'New price for all selected'),
    };
    return AlertDialog(
      title: Text(context.t('تعديل السعر جماعياً', 'Bulk price change')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<BulkPriceMode>(
            segments: [
              ButtonSegment(value: BulkPriceMode.percent, label: Text(context.t('نسبة %', 'Percent'))),
              ButtonSegment(value: BulkPriceMode.add, label: Text(context.t('مبلغ ±', 'Amount ±'))),
              ButtonSegment(value: BulkPriceMode.setExact, label: Text(context.t('سعر ثابت', 'Fixed'))),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            decoration: InputDecoration(
              hintText: hint,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.t('تطبيق', 'Apply')),
        ),
      ],
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
              style: TextStyle(color: StoreTheme.muted),
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
              style: TextStyle(color: StoreTheme.muted),
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
                      backgroundColor: StoreTheme.accent,
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
