import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/app_translate.dart';
import '../../../core/locale/locale_extensions.dart';
import '../../auth/provider_publish_gate.dart';
import '../import/woocommerce_store_api_client.dart';
import '../store_categories.dart';
import '../store_theme.dart';
import 'bulk_listing_form.dart';
import 'merchant_product_bulk_service.dart';
import 'merchant_sell_gate.dart';

/// Pulls a supplier's public WooCommerce catalog into their AcadeGate store.
class WooStoreLinkScreen extends StatefulWidget {
  const WooStoreLinkScreen({
    super.key,
    this.supplierId,
    this.storeNameHint,
    this.contactHint,
    this.websiteHint,
  });

  final String? supplierId;
  final String? storeNameHint;
  final String? contactHint;
  final String? websiteHint;

  @override
  State<WooStoreLinkScreen> createState() => _WooStoreLinkScreenState();
}

class _WooStoreLinkScreenState extends State<WooStoreLinkScreen> {
  final _url = TextEditingController();
  final _markup = TextEditingController();
  late final TextEditingController _storeName;
  late final TextEditingController _contact;
  StoreCategory _category = storeCategories.last;

  bool _busy = false;
  bool _cancel = false;
  String? _status;
  double? _fraction;
  String? _baseUrl;
  List<WooImportedProduct>? _products;
  bool _includeOutOfStock = true;

  @override
  void initState() {
    super.initState();
    _storeName = TextEditingController(text: widget.storeNameHint ?? '');
    _contact = TextEditingController(text: widget.contactHint ?? '');
    _url.text = widget.websiteHint ?? '';
    if (_url.text.trim().isEmpty) {
      MerchantProductBulkService.instance.loadSavedWooUrl().then((saved) {
        if (mounted && saved != null && _url.text.trim().isEmpty) {
          _url.text = saved;
          _loadMarkupFor(saved);
        }
      });
    } else {
      final base = MerchantProductBulkService.normalizeStoreUrl(_url.text);
      if (base != null) _loadMarkupFor(base);
    }
  }

  Future<void> _loadMarkupFor(String baseUrl) async {
    final saved = await MerchantProductBulkService.instance.loadMarkup(baseUrl);
    if (!mounted || saved == null || _markup.text.trim().isNotEmpty) return;
    setState(() => _markup.text = _formatPercent(saved));
  }

  static String _formatPercent(num v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  num get _markupPercent => BulkListingFields.parseMarkup(_markup);

  @override
  void dispose() {
    _url.dispose();
    _markup.dispose();
    _storeName.dispose();
    _contact.dispose();
    super.dispose();
  }

  List<WooImportedProduct> get _selected => (_products ?? const [])
      .where((p) => _includeOutOfStock || p.inStock)
      .toList();

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetch() async {
    final base = MerchantProductBulkService.normalizeStoreUrl(_url.text);
    if (base == null) {
      _toast(context.t('أدخل رابط متجر صحيح', 'Enter a valid store URL'),
          error: true);
      return;
    }
    setState(() {
      _busy = true;
      _cancel = false;
      _products = null;
      _fraction = null;
      _status = context.t('جارٍ الاتصال بالمتجر…', 'Connecting to store…');
    });
    try {
      final products = await MerchantProductBulkService.instance.fetchWooCatalog(
        baseUrl: base,
        shouldCancel: () => _cancel,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _fraction = p.fraction;
            _status = appTr(
              'صفحة ${p.page}/${p.totalPages} · ${p.productsSoFar} منتج',
              'Page ${p.page}/${p.totalPages} · ${p.productsSoFar} products',
            );
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _baseUrl = base;
        _products = products;
        _status = null;
      });
      await _loadMarkupFor(base);
      if (!mounted) return;
      if (products.isEmpty) {
        _toast(context.t('لم يتم العثور على منتجات في هذا المتجر',
            'No products found in this store'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = null);
      final msg = '$e';
      if (msg.contains('cancelled')) {
        _toast(context.t('تم الإلغاء', 'Cancelled'));
      } else {
        _toast(
          context.t(
            'تعذر قراءة الكتالوج. تأكد أن المتجر يعمل بـ WooCommerce وأن الرابط صحيح.\n$msg',
            'Could not read the catalog. Make sure the store runs WooCommerce and the URL is correct.\n$msg',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final base = _baseUrl;
    final products = _selected;
    if (base == null || products.isEmpty) return;
    final account = await ensureMerchantCanSell(context);
    if (account == null || !mounted) return;
    final markup = _markupPercent;

    setState(() {
      _busy = true;
      _cancel = false;
      _fraction = 0;
      _status = context.t('جارٍ الحفظ…', 'Saving…');
    });
    try {
      await MerchantProductBulkService.instance.saveMarkup(base, markup);
      final result = await MerchantProductBulkService.instance.saveWooCatalog(
        baseUrl: base,
        products: products,
        shouldCancel: () => _cancel,
        listing: MerchantListingContext(
          defaultCategory: _category.title,
          approvalStatus: ProviderPublishGate.contentApprovalStatus(account),
          storeName: _storeName.text.trim(),
          contact: _contact.text.trim(),
          supplierId: widget.supplierId,
          markupPercent: markup,
        ),
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _fraction = p.fraction;
            _status = appTr('حفظ ${p.done} / ${p.total}',
                'Saving ${p.done} / ${p.total}');
          });
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('تم ربط المتجر', 'Store linked')),
          content: Text(
            ctx.t(
              'منتجات جديدة: ${result.created}\nمحدّثة: ${result.updated}\n${markup != 0 ? 'نسبة الربح المطبّقة: ${_formatPercent(markup)}%\n' : ''}\nلتحديث الأسعار والتوفر لاحقاً افتح هذه الشاشة واضغط «جلب الكتالوج» ثم «حفظ» — نسبة الربح محفوظة وتُطبَّق تلقائياً.',
              'New products: ${result.created}\nUpdated: ${result.updated}\n${markup != 0 ? 'Margin applied: ${_formatPercent(markup)}%\n' : ''}\nTo refresh prices and stock later, reopen this screen, fetch and save again — your margin is remembered and re-applied.',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('تم', 'Done')),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('${context.t('فشل الحفظ', 'Save failed')}: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(context.t('ربط متجري الإلكتروني', 'Link my online store')),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StoreTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StoreTheme.border),
              ),
              child: Text(
                context.t(
                  'إذا كان متجرك مبنياً على WordPress + WooCommerce، اكتب رابطه وسنسحب كل المنتجات (الاسم، السعر، الصورة، الوصف، التوفر) من الكتالوج العام — بدون مفاتيح أو كلمات مرور.\n'
                  'إعادة الربط لاحقاً تحدّث نفس المنتجات ولا تكررها.',
                  'If your shop runs WordPress + WooCommerce, enter its URL and we will pull every product (name, price, image, description, stock) from the public catalog — no keys or passwords.\n'
                  'Re-linking later refreshes the same products without duplicates.',
                ),
                style: const TextStyle(height: 1.5, fontSize: 13),
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 10),
              Text(
                context.t(
                  'غير متاح من نسخة الويب بسبب قيود المتصفح — استخدم تطبيق Windows أو Android.',
                  'Not available on web due to browser restrictions — use the Windows or Android app.',
                ),
                style: const TextStyle(color: StoreTheme.danger),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.t('رابط المتجر', 'Store URL'),
                hintText: 'https://example-lab-store.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
              ),
              onSubmitted: (_) => _busy ? null : _fetch(),
            ),
            const SizedBox(height: 12),
            BulkListingFields(
              category: _category,
              onCategoryChanged: (c) => setState(() => _category = c),
              storeNameController: _storeName,
              contactController: _contact,
              markupController: _markup,
              onMarkupChanged: () => setState(() {}),
              enabled: !_busy,
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'نحاول تحديد قسم كل منتج تلقائياً من اسمه وتصنيفه، والقسم الافتراضي يُستخدم عند عدم التأكد.',
                'We auto-detect each product\'s category from its name and tags; the default is used when unsure.',
              ),
              style: TextStyle(color: StoreTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || kIsWeb ? null : _fetch,
              style: FilledButton.styleFrom(
                backgroundColor: StoreTheme.ink,
                foregroundColor: StoreTheme.bg,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(context.t('جلب الكتالوج', 'Fetch catalog')),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _fraction,
                color: StoreTheme.accent,
                backgroundColor: StoreTheme.border,
              ),
              const SizedBox(height: 6),
              if (_status != null) Text(_status!),
              TextButton(
                onPressed: () => setState(() => _cancel = true),
                child: Text(context.t('إلغاء', 'Cancel')),
              ),
            ],
            if (products != null && products.isNotEmpty && !_busy)
              ..._preview(context, products),
          ],
        ),
      ),
    );
  }

  String _priceLabel(BuildContext context, WooImportedProduct p) {
    final markup = _markupPercent;
    if (markup == 0) return '${p.price} ${p.currency}';
    final selling = MerchantProductBulkService.applyMarkup(p.price, markup);
    return context.t(
      'سعر المورد ${p.price} ← سعرك $selling ${p.currency}',
      'Supplier ${p.price} → yours $selling ${p.currency}',
    );
  }

  List<Widget> _preview(BuildContext context, List<WooImportedProduct> all) {
    final outOfStock = all.where((p) => !p.inStock).length;
    final selected = _selected;
    return [
      const SizedBox(height: 16),
      Text(
        context.t(
          'تم العثور على ${all.length} منتج ($outOfStock غير متوفر)',
          'Found ${all.length} products ($outOfStock out of stock)',
        ),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      if (outOfStock > 0)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('تضمين المنتجات غير المتوفرة',
              'Include out-of-stock products')),
          value: _includeOutOfStock,
          onChanged: (v) => setState(() => _includeOutOfStock = v),
        ),
      const SizedBox(height: 8),
      ...selected.take(20).map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: p.imageUrl == null
                        ? const ColoredBox(
                            color: StoreTheme.accentSoft,
                            child: Icon(Icons.inventory_2_outlined),
                          )
                        : Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: StoreTheme.accentSoft,
                              child: Icon(Icons.inventory_2_outlined),
                            ),
                          ),
                  ),
                ),
                title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${_priceLabel(context, p)}${p.inStock ? '' : ' · ${context.t('غير متوفر', 'Out of stock')}'}',
                ),
              ),
            ),
          ),
      if (selected.length > 20)
        Text(
          context.t('... و ${selected.length - 20} منتج آخر',
              '... and ${selected.length - 20} more'),
          style: TextStyle(color: StoreTheme.muted),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: selected.isEmpty ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: StoreTheme.accent,
          minimumSize: const Size.fromHeight(50),
        ),
        icon: const Icon(Icons.save_outlined),
        label: Text(
          context.t('حفظ ${selected.length} منتج في متجري',
              'Save ${selected.length} products to my store'),
        ),
      ),
    ];
  }
}
