import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/directory/directory_trust_status.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/section_cover_image.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../moderation/approval_status.dart';
import 'add_product_screen.dart';
import 'catalog_disclaimer.dart';
import 'import/egypt_store_suppliers_catalog.dart';
import 'store_catalog_service.dart';
import 'store_categories.dart';
import 'store_product_navigation.dart';
import 'store_theme.dart';

enum _ProductSort { newest, priceAsc, priceDesc, mostOrdered }

const _kGradeOptions = ['AR', 'ACS', 'HPLC', 'Analytical'];
const _kPriceMaxOptions = <num?>[null, 500, 2000, 10000];

class ProductListScreen extends StatefulWidget {
  final String categoryTitle;

  const ProductListScreen({super.key, required this.categoryTitle});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  bool _inStockOnly = false;
  bool _fastShippingOnly = false;
  bool _verifiedOnly = false;
  final Set<String> _selectedGrades = {};
  num? _priceMax;
  String? _city;
  String? _storeName;
  _ProductSort _sort = _ProductSort.newest;

  String get categoryTitle => widget.categoryTitle;

  String _formatPrice(num price) => '$price ${appTr('ج.م', 'EGP')}';

  List<String> _queryTitles(StoreCategory? category, String fallback) {
    if (category == null) return [fallback];
    return storeCategoryQueryTitles(category);
  }

  Future<void> _openSupplier(EgyptStoreSupplier supplier) async {
    final uri = Uri.tryParse(supplier.website);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<StoreCatalogProduct> _categoryProducts(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    Set<String> titleSet,
  ) {
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final status = data['approvalStatus']?.toString();
      if (!ApprovalStatus.isPublic(status)) return false;
      final cat = data['category']?.toString() ?? '';
      final canonical = storeCategoryLegacyAliases[cat] ?? cat;
      return titleSet.contains(cat) || titleSet.contains(canonical);
    }).map(StoreCatalogProduct.fromDoc).toList();
  }

  List<StoreCatalogProduct> _applyFilters(
    List<StoreCatalogProduct> input, {
    String? cityOverride,
    String? storeOverride,
  }) {
    final city = cityOverride ?? _city;
    final store = storeOverride ?? _storeName;
    var list = input.where((p) {
      if (_inStockOnly && !p.inStock) return false;
      if (_fastShippingOnly && !p.fastShipping) return false;
      if (_verifiedOnly && !p.isVerifiedSeller) return false;
      if (_priceMax != null && (p.price <= 0 || p.price > _priceMax!)) {
        return false;
      }
      if (city != null &&
          city.isNotEmpty &&
          p.city.trim().toLowerCase() != city.trim().toLowerCase()) {
        return false;
      }
      if (store != null &&
          store.isNotEmpty &&
          p.storeName.trim().toLowerCase() != store.trim().toLowerCase()) {
        return false;
      }
      if (_selectedGrades.isNotEmpty) {
        final g = p.grade.toLowerCase();
        final match =
            _selectedGrades.any((sel) => g.contains(sel.toLowerCase()));
        if (!match) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case _ProductSort.priceAsc:
          return a.price.compareTo(b.price);
        case _ProductSort.priceDesc:
          return b.price.compareTo(a.price);
        case _ProductSort.mostOrdered:
          return b.orderCount.compareTo(a.orderCount);
        case _ProductSort.newest:
          final aAt = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bAt = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bAt.compareTo(aAt);
      }
    });
    return list;
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    final set = <String>{};
    for (final v in values) {
      final t = v.trim();
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  bool get _hasActiveFilters =>
      _inStockOnly ||
      _fastShippingOnly ||
      _verifiedOnly ||
      _selectedGrades.isNotEmpty ||
      _priceMax != null ||
      (_city != null && _city!.isNotEmpty) ||
      (_storeName != null && _storeName!.isNotEmpty) ||
      _sort != _ProductSort.newest;

  void _clearFilters() {
    setState(() {
      _inStockOnly = false;
      _fastShippingOnly = false;
      _verifiedOnly = false;
      _selectedGrades.clear();
      _priceMax = null;
      _city = null;
      _storeName = null;
      _sort = _ProductSort.newest;
    });
  }

  Future<void> _pickPriceMax(Color accent) async {
    num? draft = _priceMax;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        context.t('الحد الأقصى للسعر', 'Max price'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    for (final option in _kPriceMaxOptions)
                      ListTile(
                        leading: Icon(
                          draft == option
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: accent,
                        ),
                        title: Text(_priceMaxLabel(option)),
                        onTap: () => setSheet(() => draft = option),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: accent),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(context.t('تطبيق', 'Apply')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || confirmed != true) return;
    setState(() => _priceMax = draft);
  }

  String _priceMaxLabel(num? max) {
    if (max == null) return context.t('أي سعر', 'Any price');
    return context.t('أقل من $max ج.م', 'Under $max EGP');
  }

  String _sortLabel(_ProductSort sort) {
    switch (sort) {
      case _ProductSort.newest:
        return context.t('الأحدث', 'Newest');
      case _ProductSort.priceAsc:
        return context.t('السعر ↑', 'Price ↑');
      case _ProductSort.priceDesc:
        return context.t('السعر ↓', 'Price ↓');
      case _ProductSort.mostOrdered:
        return context.t('الأكثر طلباً', 'Most ordered');
    }
  }

  Future<void> _pickSort(Color accent) async {
    final picked = await showModalBottomSheet<_ProductSort>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in _ProductSort.values)
                ListTile(
                  leading: Icon(
                    s == _sort ? Icons.check_circle : Icons.circle_outlined,
                    color: accent,
                  ),
                  title: Text(_sortLabel(s)),
                  onTap: () => Navigator.pop(ctx, s),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _sort = picked);
  }

  Future<void> _pickCity(Color accent, List<String> cities) async {
    if (cities.isEmpty) return;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(context.t('كل المدن', 'All cities')),
                leading: Icon(
                  _city == null ? Icons.check_circle : Icons.circle_outlined,
                  color: accent,
                ),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final c in cities)
                ListTile(
                  title: Text(c),
                  leading: Icon(
                    _city == c ? Icons.check_circle : Icons.circle_outlined,
                    color: accent,
                  ),
                  onTap: () => Navigator.pop(ctx, c),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _city = picked.isEmpty ? null : picked);
  }

  Future<void> _pickStore(Color accent, List<String> stores) async {
    if (stores.isEmpty) return;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(context.t('كل الموردين', 'All suppliers')),
                leading: Icon(
                  _storeName == null ? Icons.check_circle : Icons.circle_outlined,
                  color: accent,
                ),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final s in stores)
                ListTile(
                  title: Text(s),
                  leading: Icon(
                    _storeName == s ? Icons.check_circle : Icons.circle_outlined,
                    color: accent,
                  ),
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _storeName = picked.isEmpty ? null : picked);
  }

  Widget _filterChips({
    required Color accent,
    required List<String> cities,
    required List<String> stores,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(context.t('متوفر', 'In stock')),
                selected: _inStockOnly,
                selectedColor: accent.withValues(alpha: 0.18),
                checkmarkColor: accent,
                onSelected: (v) => setState(() => _inStockOnly = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(context.t('شحن سريع', 'Fast shipping')),
                selected: _fastShippingOnly,
                selectedColor: accent.withValues(alpha: 0.18),
                checkmarkColor: accent,
                onSelected: (v) => setState(() => _fastShippingOnly = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(context.t('موثّق ومُدار', 'Managed Verified')),
                selected: _verifiedOnly,
                selectedColor: accent.withValues(alpha: 0.18),
                checkmarkColor: accent,
                onSelected: (v) => setState(() => _verifiedOnly = v),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(Icons.payments_outlined, size: 18, color: accent),
                label: Text(
                  _priceMax == null
                      ? context.t('السعر', 'Price')
                      : _priceMaxLabel(_priceMax),
                ),
                onPressed: () => _pickPriceMax(accent),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(Icons.location_city_outlined, size: 18, color: accent),
                label: Text(
                  (_city == null || _city!.isEmpty)
                      ? context.t('المدينة', 'City')
                      : _city!,
                ),
                onPressed: cities.isEmpty ? null : () => _pickCity(accent, cities),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(Icons.storefront_outlined, size: 18, color: accent),
                label: Text(
                  (_storeName == null || _storeName!.isEmpty)
                      ? context.t('المورد', 'Supplier')
                      : _storeName!,
                ),
                onPressed:
                    stores.isEmpty ? null : () => _pickStore(accent, stores),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(Icons.sort, size: 18, color: accent),
                label: Text(_sortLabel(_sort)),
                onPressed: () => _pickSort(accent),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.clear, size: 18),
                  label: Text(context.t('مسح', 'Clear')),
                  onPressed: _clearFilters,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final grade in _kGradeOptions)
              FilterChip(
                label: Text(grade),
                selected: _selectedGrades.contains(grade),
                selectedColor: accent.withValues(alpha: 0.18),
                checkmarkColor: accent,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedGrades.add(grade);
                    } else {
                      _selectedGrades.remove(grade);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _openAddProduct(BuildContext context, StoreCategory? category) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(
          categoryTitle: category?.title ?? categoryTitle,
        ),
      ),
    );

    if (!context.mounted) return;
    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم حفظ المنتج — يظهر الآن في قسم المتجر',
              'Product saved — it now appears in the store section',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = storeCategoryByTitle(categoryTitle);
    final accentColor = category?.color ?? StoreTheme.accent;
    final displayTitle = category != null
        ? L10nLookup.storeCategoryTitle(category.id)
        : categoryTitle;
    final queryTitles = _queryTitles(category, categoryTitle);
    final suppliers = egyptStoreSuppliersForCategory(
      categoryId: category?.id,
      categoryTitle: categoryTitle,
    );

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(displayTitle),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: StoreTheme.appBarForeground,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (!UserRole.canSellProducts(snapshot.data?.role)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: context.t('إضافة منتج كمورد', 'Add product as supplier'),
                icon: const Icon(Icons.add),
                onPressed: () => _openAddProduct(context, category),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('product').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${context.t('حدث خطأ: ', 'Error: ')}${snapshot.error}',
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final titleSet = queryTitles.toSet();
          final categoryDocs =
              _categoryProducts(snapshot.data!, titleSet);
          final cities = _uniqueSorted(categoryDocs.map((p) => p.city));
          final stores = _uniqueSorted(categoryDocs.map((p) => p.storeName));
          // Ignore stale dropdown selections that no longer exist in this category.
          final effectiveCity =
              _city != null && cities.contains(_city) ? _city : null;
          final effectiveStore = _storeName != null && stores.contains(_storeName)
              ? _storeName
              : null;
          final docs = _applyFilters(
            categoryDocs,
            cityOverride: effectiveCity,
            storeOverride: effectiveStore,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (category != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SectionCoverImage(
                          category.backgroundAsset,
                          errorBuilder: (_, _, _) =>
                              Container(color: accentColor),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                accentColor.withValues(alpha: 0.85),
                                Colors.black.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category.audience(
                                  Directionality.of(context) ==
                                      TextDirection.rtl,
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.t(
                                  '${docs.length} منتج متاح · ضمان Escrow',
                                  '${docs.length} products · Escrow protection',
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (category?.id == 'office') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    context.t(
                      'هذا القسم لكتابة وتوثيق البحث: دفاتر وملاحظات، ملفات وأرشفة، ملصقات عينات، طباعة وتجليد الأطروحات والرسائل العلمية — وليس للكيماويات أو أجهزة المعمل.',
                      'This section is for writing & documenting research: notebooks, folders & archiving, sample labels, thesis/dissertation printing & binding — not for chemicals or lab instruments.',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.grey[850],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (suppliers.isNotEmpty) ...[
                Text(
                  context.t(
                    'موردون لهذا التخصص (${suppliers.length})',
                    'Suppliers for this specialty (${suppliers.length})',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t(
                    'بيانات عامة من مواقع معلنة — ليست اعتماداً من الشركة ما لم تظهر حالة Partner. تواصل مباشرة حتى لو لم تُدرج كل منتجاتهم.',
                    'Public website data — not a company endorsement unless Partner is shown. Contact directly even if not every product is listed.',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.35),
                ),
                const SizedBox(height: 10),
                ...suppliers.map(
                  (s) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accentColor.withValues(alpha: 0.12),
                        child: Icon(
                          category?.icon ?? Icons.storefront,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        s.nameAr,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          DirectoryTrustChip(
                            status: s.resolvedDirectoryStatus,
                            compact: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (s.city.isNotEmpty) s.city,
                              s.dataSourceLabel(
                                Localizations.localeOf(context).languageCode ==
                                    'ar',
                              ),
                              if (s.lastVerifiedIso.isNotEmpty)
                                '${context.t('آخر تحقق', 'Last checked')} ${s.lastVerifiedIso}',
                            ].join(' · '),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: context.t('بلّغ عن خطأ', 'Report an error'),
                        icon: const Icon(Icons.flag_outlined, size: 20),
                        onPressed: () => showCatalogReportSheet(
                          context,
                          targetType: 'supplier',
                          supplierId: s.id,
                          storeName: s.nameAr,
                          sourceUrl: s.website,
                        ),
                      ),
                      onTap: () => _openSupplier(s),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.t('المنتجات', 'Products'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (categoryDocs.isNotEmpty)
                _filterChips(
                  accent: accentColor,
                  cities: cities,
                  stores: stores,
                ),
              if (categoryDocs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        category?.icon ?? Icons.inventory_2_outlined,
                        size: 56,
                        color: accentColor.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.t(
                          'لا توجد منتجات مدرجة في هذا القسم بعد — استخدم قائمة الموردين أعلاه للتواصل.',
                          'No listed products in this section yet — use the suppliers above to contact them.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder(
                        stream:
                            UserAccountService.instance.watchCurrentAccount(),
                        builder: (context, snapshot) {
                          if (!UserRole.canSellProducts(snapshot.data?.role)) {
                            return const SizedBox.shrink();
                          }
                          return FilledButton.icon(
                            onPressed: () => _openAddProduct(context, category),
                            style: FilledButton.styleFrom(
                              backgroundColor: StoreTheme.accent,
                            ),
                            icon: const Icon(Icons.add_business_outlined),
                            label: Text(
                              context.t(
                                'إضافة منتج كمورد',
                                'Add product as supplier',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )
              else if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.filter_alt_off_outlined,
                        size: 48,
                        color: accentColor.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.t(
                          'لا توجد منتجات مطابقة للفلاتر الحالية.',
                          'No products match the current filters.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _clearFilters,
                        child: Text(context.t('مسح الفلاتر', 'Clear filters')),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(docs.length, (index) {
                  final product = docs[index];
                  final formattedPrice = product.price > 0
                      ? _formatPrice(product.price)
                      : context.t(
                          'السعر عند المورد',
                          'Price via supplier',
                        );
                  final storeName = product.storeName.isNotEmpty
                      ? product.storeName
                      : context.t('متجر غير معروف', 'Unknown store');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProductCard(
                      name: product.name,
                      price: formattedPrice,
                      storeName: storeName,
                      brand: product.brand,
                      unit: product.unit,
                      grade: product.grade,
                      isVerifiedSeller: product.isVerifiedSeller,
                      inStock: product.inStock,
                      fastShipping: product.fastShipping,
                      icon: category?.icon ?? Icons.shopping_bag_outlined,
                      color: StoreTheme.accent,
                      imageUrl: product.imageUrl,
                      onTap: () => openStoreProductDetail(context, product),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String price;
  final String storeName;
  final String brand;
  final String unit;
  final String grade;
  final bool isVerifiedSeller;
  final bool inStock;
  final bool fastShipping;
  final IconData icon;
  final Color color;
  final String? imageUrl;
  final VoidCallback onTap;

  const _ProductCard({
    required this.name,
    required this.price,
    required this.storeName,
    required this.brand,
    required this.unit,
    required this.grade,
    required this.isVerifiedSeller,
    required this.inStock,
    required this.fastShipping,
    required this.icon,
    required this.color,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (brand.isNotEmpty) brand,
      if (unit.isNotEmpty) unit,
      if (grade.isNotEmpty) grade,
    ].join(' · ');
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final statusChips = <Widget>[
      if (!inStock)
        _miniChip(
          context.t('غير متوفر', 'Out of stock'),
          Colors.red[700]!,
        ),
      if (fastShipping)
        _miniChip(
          context.t('شحن سريع', 'Fast ship'),
          Colors.blue[700]!,
        ),
      if (isVerifiedSeller)
        _miniChip(
          context.t('موثّق ومُدار', 'Managed Verified'),
          StoreTheme.verified,
        ),
    ];

    return Material(
      color: StoreTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: StoreTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: hasImage
                      ? Image.network(
                          imageUrl!.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _iconBox(),
                        )
                      : _iconBox(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: StoreTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: StoreTheme.priceStyle.copyWith(fontSize: 14),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: StoreTheme.muted,
                        ),
                      ),
                    ],
                    if (statusChips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: statusChips,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront,
                          size: 14,
                          color: StoreTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: StoreTheme.ink,
                            ),
                          ),
                        ),
                        if (isVerifiedSeller)
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: StoreTheme.verified,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      color: color.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(icon, size: 28, color: color),
    );
  }
}
