import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/section_cover_image.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../guides/section_guide_catalog.dart';
import '../guides/section_guide_screen.dart';
import '../home/home_search_utils.dart';
import '../home/section_search_field.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import 'add_product_screen.dart';
import 'import/admin_store_import_screen.dart';
import 'import/egypt_store_suppliers_catalog.dart';
import 'import/store_product_search_service.dart';
import 'knowledge_assets/my_knowledge_licenses_screen.dart';
import 'knowledge_assets/publish_knowledge_asset_screen.dart';
import 'merchant_store_screen.dart';
import 'product_detail_screen.dart';
import 'product_list_screen.dart';
import 'store_cart_screen.dart';
import 'store_cart_service.dart';
import 'store_catalog_service.dart';
import 'store_categories.dart';
import 'store_product_navigation.dart';
import 'ai_compare/store_ai_compare_screen.dart';
import 'custom_fit/store_custom_fit_screen.dart';
import 'custom_fit/store_product_discover_screen.dart';
import 'research_partnership/research_partnerships_list_screen.dart';
import 'store_recommendation_engine.dart';
import 'store_theme.dart';
import 'vendor_shop_screen.dart';

/// واجهة سوق المتجر: بحث · الأكثر طلباً · جديد هذا الأسبوع · أقسام · شبكة.
class StoreHubScreen extends StatefulWidget {
  const StoreHubScreen({super.key});

  @override
  State<StoreHubScreen> createState() => _StoreHubScreenState();
}

class _StoreHubScreenState extends State<StoreHubScreen> {

  String _searchQuery = '';
  Timer? _debounce;
  bool _searching = false;
  bool _loadingCatalog = true;
  StoreCatalogBundle _catalog = const StoreCatalogBundle();
  StoreProductSearchResult _productHits = const StoreProductSearchResult();
  AcademicProfile? _profile;
  List<StoreCatalogProduct> _recommended = const [];

  @override
  void initState() {
    super.initState();
    StoreCartService.instance.addListener(_onCartChanged);
    _loadCatalog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    StoreCartService.instance.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCatalog() async {
    setState(() => _loadingCatalog = true);
    final results = await Future.wait([
      StoreCatalogService.instance.loadPublicCatalog(),
      AcademicProfileService.instance.loadProfile(),
    ]);
    if (!mounted) return;
    final bundle = results[0] as StoreCatalogBundle;
    final profile = results[1] as AcademicProfile?;
    final recommended = StoreRecommendationEngine.instance.recommend(
      products: bundle.products,
      profile: profile,
      limit: 12,
    );
    setState(() {
      _catalog = bundle;
      _profile = profile;
      _recommended = recommended;
      _loadingCatalog = false;
    });
  }

  List<StoreCategory> get _filteredCategories {
    if (_searchQuery.trim().isEmpty) return storeCategories;
    return storeCategories
        .where(
          (category) => homeSearchMatches(_searchQuery, [
            category.title,
            category.id,
            category.audienceAr,
            category.audienceEn,
            L10nLookup.storeCategoryTitle(category.id),
          ]),
        )
        .toList();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _productHits = const StoreProductSearchResult();
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      final local = StoreProductSearchService.instance.rankLoaded(
        _catalog.products,
        q,
      );
      if (!mounted || _searchQuery.trim() != q) return;
      setState(() {
        _productHits = StoreProductSearchResult(local: local);
        _searching = !kIsWeb;
      });
      if (kIsWeb) return;
      try {
        final remote = await StoreProductSearchService.instance
            .searchSupplierSites(q)
            .timeout(const Duration(seconds: 18));
        if (!mounted || _searchQuery.trim() != q) return;
        final seen = <String>{
          for (final hit in local)
            (hit.sourceUrl ?? '').trim().isNotEmpty
                ? hit.sourceUrl!.toLowerCase()
                : '${hit.supplierId}|${hit.name.toLowerCase()}',
        };
        final extra = remote.where((hit) {
          final key = (hit.sourceUrl ?? '').trim().isNotEmpty
              ? hit.sourceUrl!.toLowerCase()
              : '${hit.supplierId}|${hit.name.toLowerCase()}';
          return seen.add(key);
        }).toList();
        setState(() {
          _productHits = StoreProductSearchResult(local: local, remote: extra);
          _searching = false;
        });
      } catch (_) {
        if (!mounted || _searchQuery.trim() != q) return;
        setState(() => _searching = false);
      }
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    setState(() {
      _searchQuery = '';
      _productHits = const StoreProductSearchResult();
      _searching = false;
    });
  }

  Future<void> _openCategory(StoreCategory category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductListScreen(categoryTitle: category.title),
      ),
    );
    if (mounted) _loadCatalog();
  }

  Future<void> _openSupplierAdd() async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    if (!mounted) return;
    if (!UserRole.canSellProducts(account?.role)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'إضافة المنتجات للتاجر/المورد فقط. أنشئ حساباً بدور تاجر من شاشة التسجيل.',
              'Only merchants can add products. Create a merchant account from the register screen.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final category = await showModalBottomSheet<StoreCategory>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ctx.t(
                    'اختر القسم لإضافة منتجك كمورد',
                    'Choose a section to list your product as a supplier',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: storeCategories.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final cat = storeCategories[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SectionCoverImage(
                            cat.backgroundAsset,
                            width: 40,
                            height: 40,
                            errorBuilder: (_, _, _) =>
                                Icon(cat.icon, color: cat.color),
                          ),
                        ),
                        title: Text(L10nLookup.storeCategoryTitle(cat.id)),
                        subtitle: Text(
                          cat.audience(
                            Directionality.of(ctx) == TextDirection.rtl,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => Navigator.pop(ctx, cat),
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
    if (!mounted) return;
    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم إرسال المنتج للمراجعة — سيظهر بعد الموافقة',
              'Product sent for review — it will appear after approval',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _loadCatalog();
  }

  void _openCatalogProduct(StoreCatalogProduct product) {
    openStoreProductDetail(context, product);
  }

  void _openSearchHit(StoreSearchHit hit) {
    final priceLabel = hit.price > 0
        ? '${hit.price} ${appTr('ج.م', 'EGP')}'
        : context.t('السعر عند المورد', 'Price via supplier');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          name: hit.name,
          price: priceLabel,
          description: hit.description.isNotEmpty
              ? hit.description
              : context.t(
                  'نتيجة بحث من كتالوج المورد. افتح صفحة المنتج أو تواصل مباشرة.',
                  'Search hit from supplier catalog. Open the product page or contact them.',
                ),
          storeName: hit.storeName,
          contact: hit.contact,
          productId: hit.productId,
          createdBy: hit.createdBy,
          priceValue: hit.price,
          imageUrl: hit.imageUrl,
          sourceUrl: hit.sourceUrl,
          brand: hit.category,
          isVerifiedSeller: true,
          isDirectoryListing: hit.isDirectoryListing || hit.fromRemoteSite,
          email: hit.email,
          phone: hit.phone,
          whatsapp: hit.whatsapp,
          website: hit.website,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final showProductSearch = _searchQuery.trim().length >= 2;
    final categories = _filteredCategories;

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(context.t('المتجر الأكاديمي', 'Academic store')),
        centerTitle: true,
        backgroundColor: StoreTheme.appBar,
        foregroundColor: StoreTheme.appBarForeground,
        actions: [
          const SectionGuideAppBarButton(
            guideId: SectionGuideCatalog.store,
            accent: StoreTheme.accent,
          ),
          IconButton(
            tooltip: context.t('توافق مخصص', 'Custom fit'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreCustomFitScreen()),
              );
            },
            icon: const Icon(Icons.design_services_outlined),
          ),
          IconButton(
            tooltip: context.t('بحث بالمواصفات', 'Search by specs'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StoreProductDiscoverScreen(),
                ),
              );
            },
            icon: const Icon(Icons.travel_explore),
          ),
          IconButton(
            tooltip: context.t('بحث ومقارنة الأسعار', 'Search and compare prices'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreAiCompareScreen(
                    initialQuery: _searchQuery,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.price_check),
          ),
          IconButton(
            tooltip: context.t('شراكات بحثية', 'Research partnerships'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ResearchPartnershipsListScreen(),
                ),
              );
            },
            icon: const Icon(Icons.handshake_outlined),
          ),
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              final account = snapshot.data;
              final canSell = UserRole.canSellProducts(account?.role);
              final isAdmin = account?.isAdmin == true;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canSell)
                    IconButton(
                      tooltip: context.t(
                        'نشر أصل معرفي',
                        'Publish knowledge asset',
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PublishKnowledgeAssetScreen(),
                          ),
                        );
                        if (mounted) _loadCatalog();
                      },
                      icon: const Icon(Icons.enhanced_encryption),
                    ),
                  if (account != null)
                    IconButton(
                      tooltip: context.t(
                        'تراخيص الأصول المعرفية',
                        'My knowledge licenses',
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyKnowledgeLicensesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.vpn_key_outlined),
                    ),
                  if (isAdmin)
                    IconButton(
                      tooltip: context.t(
                        'استيراد / مزامنة الموردين',
                        'Import / sync suppliers',
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminStoreImportScreen(),
                          ),
                        );
                        if (mounted) _loadCatalog();
                      },
                      icon: const Icon(Icons.cloud_sync_outlined),
                    ),
                ],
              );
            },
          ),
          ListenableBuilder(
            listenable: StoreCartService.instance,
            builder: (context, _) {
              final count = StoreCartService.instance.itemCount;
              return IconButton(
                tooltip: context.t('العربة', 'Cart'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StoreCartScreen()),
                  );
                },
                icon: Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: StoreTheme.accent,
                  label: Text('$count'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              );
            },
          ),
          IconButton(
            tooltip: context.t('تحديث', 'Refresh'),
            onPressed: _loadingCatalog ? null : _loadCatalog,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                _HubActions(
                  onAddProduct: _openSupplierAdd,
                  onMyStore: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MerchantStoreScreen(),
                      ),
                    ).then((_) {
                      if (mounted) _loadCatalog();
                    });
                  },
                ),
                const SizedBox(height: 8),
                SectionSearchField(
                  query: _searchQuery,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                  hint: context.t(
                    'ابحث عن منتج أو قسم',
                    'Search product or section',
                  ),
                ),
                if (kIsWeb && showProductSearch) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      'البحث المباشر في مواقع الموردين متاح على Windows/Android (قيود الويب).',
                      'Live supplier-site search works on Windows/Android (web CORS limits).',
                    ),
                    style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: showProductSearch
                ? _SearchBody(
                    searching: _searching,
                    hits: _productHits,
                    categories: categories,
                    isAr: isAr,
                    onOpenCategory: _openCategory,
                    onOpenHit: _openSearchHit,
                    query: _searchQuery,
                  )
                : _loadingCatalog
                    ? const Center(child: CircularProgressIndicator())
                    : _catalog.hasError
                        ? _CatalogError(
                            onRetry: _loadCatalog,
                            detail: '${_catalog.error}',
                          )
                        : _BrowseBody(
                            catalog: _catalog,
                            categories: categories,
                            isAr: isAr,
                            recommended: _recommended,
                            onOpenCategory: _openCategory,
                            onOpenProduct: _openCatalogProduct,
                          ),
          ),
        ],
      ),
    ),
    );
  }
}

class _HubActions extends StatelessWidget {
  final VoidCallback onAddProduct;
  final VoidCallback onMyStore;

  const _HubActions({
    required this.onAddProduct,
    required this.onMyStore,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, snapshot) {
        final account = snapshot.data;
        final canSell = UserRole.canSellProducts(account?.role);

        if (!canSell) return const SizedBox.shrink();
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddProduct,
                style: OutlinedButton.styleFrom(
                  foregroundColor: StoreTheme.ink,
                  side: const BorderSide(color: StoreTheme.hairline),
                  minimumSize: const Size.fromHeight(36),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_business_outlined, size: 16),
                label: Text(
                  context.t('أضف منتجاً', 'Add product'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onMyStore,
                style: FilledButton.styleFrom(
                  backgroundColor: StoreTheme.accent,
                  minimumSize: const Size.fromHeight(36),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.sell_outlined, size: 16),
                label: Text(
                  context.t('متجري', 'My store'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CatalogError extends StatelessWidget {
  final VoidCallback onRetry;
  final String detail;

  const _CatalogError({required this.onRetry, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(
              context.t(
                'تعذّر تحميل كتالوج المتجر',
                'Could not load the store catalog',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: StoreTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.t('إعادة المحاولة', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseBody extends StatelessWidget {
  final StoreCatalogBundle catalog;
  final List<StoreCategory> categories;
  final bool isAr;
  final List<StoreCatalogProduct> recommended;
  final ValueChanged<StoreCategory> onOpenCategory;
  final ValueChanged<StoreCatalogProduct> onOpenProduct;

  const _BrowseBody({
    required this.catalog,
    required this.categories,
    required this.isAr,
    required this.recommended,
    required this.onOpenCategory,
    required this.onOpenProduct,
  });

  @override
  Widget build(BuildContext context) {
    final mostRequested = catalog.mostRequested(limit: 12);
    final newThisWeek = catalog.newThisWeek(limit: 12);
    final active = catalog.activeCategories(limit: 6);
    final trusted = catalog.products
        .where((p) => p.isVerifiedSeller && (p.createdBy ?? '').isNotEmpty)
        .fold<Map<String, StoreCatalogProduct>>({}, (map, p) {
      map.putIfAbsent(p.createdBy!, () => p);
      return map;
    }).values.take(8).toList();
    final egyptSuppliers = egyptStoreSuppliersCatalog.take(8).toList();

    return CustomScrollView(
      slivers: [
        if (recommended.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: _SectionTitle(
                title: context.t(
                  'معدات تناسب رسالتك',
                  'Equipment for your thesis',
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _HScrollRail(
              height: 148,
              itemCount: recommended.length,
              separatorWidth: 8,
              scrollStep: 130,
              itemBuilder: (context, index) {
                final product = recommended[index];
                return _HubProductCard(
                  product: product,
                  onTap: () => onOpenProduct(product),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
        if (mostRequested.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _SectionTitle(
                title: context.t('الأكثر طلباً', 'Most requested'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _HScrollRail(
              height: 148,
              itemCount: mostRequested.length,
              separatorWidth: 8,
              scrollStep: 130,
              itemBuilder: (context, index) {
                final product = mostRequested[index];
                return _HubProductCard(
                  product: product,
                  onTap: () => onOpenProduct(product),
                  badge: context.t(
                    '${product.orderCount} طلب',
                    '${product.orderCount} orders',
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
        if (newThisWeek.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _SectionTitle(
                title: context.t('جديد هذا الأسبوع', 'New this week'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _HScrollRail(
              height: 148,
              itemCount: newThisWeek.length,
              separatorWidth: 8,
              scrollStep: 130,
              itemBuilder: (context, index) {
                final product = newThisWeek[index];
                return _HubProductCard(
                  product: product,
                  onTap: () => onOpenProduct(product),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
        if (active.any((c) => catalog.countFor(c) > 0)) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _SectionTitle(
                title: context.t('أقسام نشطة', 'Active sections'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _HScrollRail(
              height: 52,
              itemCount: active.length,
              separatorWidth: 6,
              scrollStep: 150,
              itemBuilder: (context, index) {
                final category = active[index];
                final count = catalog.countFor(category);
                return _ActiveCategoryChip(
                  category: category,
                  count: count,
                  isAr: isAr,
                  onTap: () => onOpenCategory(category),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
        if (trusted.isNotEmpty || egyptSuppliers.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _SectionTitle(
                title: context.t('موردون ودليل عام', 'Suppliers & directory'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.t(
                  'الدليل العام ليس اعتماداً من الشركات ما لم تظهر حالة Partner.',
                  'Public directory is not a company endorsement unless Partner is shown.',
                ),
                style: TextStyle(fontSize: 12, color: StoreTheme.muted, height: 1.35),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _HScrollRail(
              height: 40,
              itemCount: trusted.length + egyptSuppliers.length,
              separatorWidth: 6,
              scrollStep: 150,
              itemBuilder: (context, index) {
                if (index < trusted.length) {
                  final p = trusted[index];
                  return ActionChip(
                    avatar: const Icon(
                      Icons.verified,
                      color: StoreTheme.verified,
                      size: 18,
                    ),
                    label: Text(
                      p.storeName.isNotEmpty
                          ? p.storeName
                          : context.t('مورد', 'Supplier'),
                    ),
                    onPressed: () {
                      final sid = (p.supplierId ?? '').trim();
                      final uid = (p.createdBy ?? '').trim();
                      if (sid.isEmpty && uid.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VendorShopScreen(
                            sellerId: uid,
                            supplierId: sid.isEmpty ? null : sid,
                            sellerNameHint: p.storeName,
                          ),
                        ),
                      );
                    },
                  );
                }
                final s = egyptSuppliers[index - trusted.length];
                return ActionChip(
                  avatar: const Icon(Icons.public, size: 18),
                  label: Text(isAr ? s.nameAr : s.nameEn),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VendorShopScreen(
                          sellerId: '',
                          supplierId: s.id,
                          sellerNameHint: isAr ? s.nameAr : s.nameEn,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _SectionTitle(
              title: context.t('تسوق حسب القسم', 'Shop by category'),
            ),
          ),
        ),
        if (categories.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                context.t('لا أقسام مطابقة', 'No matching sections'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.35,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = categories[index];
                  return _CategoryCoverTile(
                    category: category,
                    productCount: catalog.countFor(category),
                    onTap: () => onOpenCategory(category),
                  );
                },
                childCount: categories.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title}) : subtitle = null;

  @override
  Widget build(BuildContext context) {
    final sub = (subtitle ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: StoreTheme.sectionTitle.copyWith(fontSize: 14.5),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(sub, style: StoreTheme.sectionSubtitle.copyWith(fontSize: 11)),
        ],
      ],
    );
  }
}

/// شريط أفقي مع أسهم تنقل (مفيد خصوصاً على Windows/سطح المكتب).
class _HScrollRail extends StatefulWidget {
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double separatorWidth;
  final double scrollStep;

  const _HScrollRail({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorWidth = 10,
    this.scrollStep = 180,
  });

  @override
  State<_HScrollRail> createState() => _HScrollRailState();
}

class _HScrollRailState extends State<_HScrollRail> {
  final _controller = ScrollController();
  bool _canPrev = false;
  bool _canNext = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncArrows());
  }

  @override
  void didUpdateWidget(covariant _HScrollRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncArrows());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncArrows);
    _controller.dispose();
    super.dispose();
  }

  void _syncArrows() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final canPrev = pos.pixels > 2;
    final canNext = pos.pixels < pos.maxScrollExtent - 2;
    if (canPrev != _canPrev || canNext != _canNext) {
      setState(() {
        _canPrev = canPrev;
        _canNext = canNext;
      });
    }
  }

  Future<void> _scrollBy(double delta) async {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _syncArrows();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final showArrows = widget.itemCount > 1;

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: showArrows ? 40 : 16),
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => SizedBox(width: widget.separatorWidth),
            itemBuilder: widget.itemBuilder,
          ),
          if (showArrows) ...[
            PositionedDirectional(
              start: 4,
              child: _ScrollArrowButton(
                icon: isRtl ? Icons.chevron_right : Icons.chevron_left,
                enabled: _canPrev,
                tooltip: context.t('السابق', 'Previous'),
                onPressed: () => _scrollBy(-widget.scrollStep),
              ),
            ),
            PositionedDirectional(
              end: 4,
              child: _ScrollArrowButton(
                icon: isRtl ? Icons.chevron_left : Icons.chevron_right,
                enabled: _canNext,
                tooltip: context.t('التالي', 'Next'),
                onPressed: () => _scrollBy(widget.scrollStep),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScrollArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  const _ScrollArrowButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StoreTheme.surface.withValues(alpha: enabled ? 0.98 : 0.55),
      elevation: enabled ? 1 : 0,
      shadowColor: Colors.black26,
      shape: CircleBorder(
        side: BorderSide(color: StoreTheme.border.withValues(alpha: 0.9)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          icon,
          size: 26,
          color: enabled ? StoreTheme.ink : StoreTheme.muted,
        ),
      ),
    );
  }
}

class _HubProductCard extends StatelessWidget {
  final StoreCatalogProduct product;
  final VoidCallback onTap;
  final String? badge;

  const _HubProductCard({
    required this.product,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final category = product.category;
    final priceText = product.price > 0
        ? '${product.price} ${appTr('ج.م', 'EGP')}'
        : context.t('عند المورد', 'Via supplier');
    final image = (product.imageUrl ?? '').trim();
    final badgeText = (badge ?? '').trim();

    return SizedBox(
      width: 118,
      child: Material(
        color: StoreTheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: StoreTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image.isNotEmpty
                        ? Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder(category),
                          )
                        : _placeholder(category),
                    if (badgeText.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1F4D).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1.2,
                        color: StoreTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      priceText,
                      style: StoreTheme.priceStyle.copyWith(fontSize: 11.5),
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

  Widget _placeholder(StoreCategory? category) {
    if (category != null) {
      return SectionCoverImage(
        category.backgroundAsset,
        errorBuilder: (_, _, _) => Container(
          color: (category.color).withValues(alpha: 0.15),
          child: Icon(category.icon, color: category.color),
        ),
      );
    }
    return Container(
      color: StoreTheme.surface,
      child: const Icon(Icons.shopping_bag_outlined, color: StoreTheme.muted),
    );
  }
}

class _ActiveCategoryChip extends StatelessWidget {
  final StoreCategory category;
  final int count;
  final bool isAr;
  final VoidCallback onTap;

  const _ActiveCategoryChip({
    required this.category,
    required this.count,
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StoreTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: StoreTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 140,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 52,
                child: SectionCoverImage(
                  category.backgroundAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: category.color.withValues(alpha: 0.2)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        L10nLookup.storeCategoryTitle(category.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: StoreTheme.ink,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        count > 0
                            ? context.t('$count منتج', '$count products')
                            : category.audience(isAr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: StoreTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCoverTile extends StatelessWidget {
  final StoreCategory category;
  final int productCount;
  final VoidCallback onTap;

  const _CategoryCoverTile({
    required this.category,
    required this.productCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: StoreTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SectionCoverImage(
              category.backgroundAsset,
              errorBuilder: (_, _, _) => Container(color: category.color),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(category.icon, color: const Color(0xFF18181B), size: 8),
                  ),
                  const Spacer(),
                  Text(
                    L10nLookup.storeCategoryTitle(category.id),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 9.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    productCount > 0
                        ? context.t(
                            '$productCount',
                            '$productCount',
                          )
                        : context.t('تصفح', 'Browse'),
                    style: TextStyle(
                      fontSize: 8.5,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
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

class _SearchBody extends StatelessWidget {
  final bool searching;
  final StoreProductSearchResult hits;
  final List<StoreCategory> categories;
  final bool isAr;
  final ValueChanged<StoreCategory> onOpenCategory;
  final ValueChanged<StoreSearchHit> onOpenHit;
  final String query;

  const _SearchBody({
    required this.searching,
    required this.hits,
    required this.categories,
    required this.isAr,
    required this.onOpenCategory,
    required this.onOpenHit,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    if (searching && hits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (categories.isNotEmpty) ...[
          Text(
            context.t('أقسام مطابقة', 'Matching sections'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...categories.map(
            (category) => Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SectionCoverImage(
                    category.backgroundAsset,
                    width: 52,
                    height: 52,
                    errorBuilder: (_, _, _) =>
                        Icon(category.icon, color: category.color),
                  ),
                ),
                title: Text(L10nLookup.storeCategoryTitle(category.id)),
                subtitle: Text(category.audience(isAr)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => onOpenCategory(category),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          context.t(
            'منتجات داخل التطبيق (${hits.local.length})',
            'In-app products (${hits.local.length})',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (hits.local.isEmpty)
          Text(
            searching
                ? context.t(
                    'لا نتائج محلية بعد — جارٍ البحث في مواقع الموردين إن أمكن.',
                    'No local hits yet — searching supplier sites when possible.',
                  )
                : context.t(
                    'لا نتائج محلية لهذا البحث. جرّب كلمات أطول أو قسماً مختلفاً.',
                    'No in-app products for this search. Try longer keywords or another category.',
                  ),
            style: TextStyle(color: StoreTheme.muted, fontSize: 13),
          )
        else
          ...hits.local.map(
            (hit) => _HitTile(
              hit: hit,
              badge: context.t('في التطبيق', 'In app'),
              badgeColor: StoreTheme.verified,
              onTap: () => onOpenHit(hit),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                context.t(
                  'من مواقع الموردين (${hits.remote.length})',
                  'From supplier sites (${hits.remote.length})',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            if (searching)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!searching && hits.remote.isEmpty)
          Text(
            context.t(
              'لا نتائج من المواقع لهذه الكلمة، أو المواقع غير متاحة حالياً.',
              'No site results for this query, or sites are unavailable right now.',
            ),
            style: TextStyle(color: StoreTheme.muted, fontSize: 13),
          )
        else
          ...hits.remote.map(
            (hit) => _HitTile(
              hit: hit,
              badge: context.t('من الموقع', 'From site'),
              badgeColor: Colors.indigo,
              onTap: () => onOpenHit(hit),
            ),
          ),
        if (categories.isEmpty && hits.isEmpty && !searching)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                context.t(
                  'لا توجد نتائج لـ «$query»',
                  'No results for "$query"',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _HitTile extends StatelessWidget {
  final StoreSearchHit hit;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _HitTile({
    required this.hit,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: hit.imageUrl != null && hit.imageUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  hit.imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.shopping_bag_outlined),
                ),
              )
            : const Icon(Icons.shopping_bag_outlined),
        title: Text(
          hit.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [
            hit.storeName,
            if (hit.price > 0) '${hit.price} ${appTr('ج.م', 'EGP')}',
            if (hit.category.isNotEmpty) hit.category,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Chip(
          label: Text(badge, style: const TextStyle(fontSize: 10)),
          backgroundColor: badgeColor.withValues(alpha: 0.12),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        onTap: onTap,
      ),
    );
  }
}
