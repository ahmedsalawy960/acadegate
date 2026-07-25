import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import '../home/home_search_utils.dart';
import '../home/section_search_field.dart';
import 'add_product_screen.dart';
import 'import/admin_store_import_screen.dart';
import 'import/store_product_search_service.dart';
import 'product_detail_screen.dart';
import 'product_list_screen.dart';
import 'store_categories.dart';

class StoreCategoriesScreen extends StatefulWidget {
  const StoreCategoriesScreen({super.key});

  @override
  State<StoreCategoriesScreen> createState() => _StoreCategoriesScreenState();
}

class _StoreCategoriesScreenState extends State<StoreCategoriesScreen> {
  String _searchQuery = '';
  Map<String, int> _counts = {};
  Timer? _debounce;
  bool _searching = false;
  StoreProductSearchResult _productHits = const StoreProductSearchResult();

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('product').get();
      final map = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['approvalStatus']?.toString();
        if (status != null && status.isNotEmpty && status != 'approved') {
          continue;
        }
        final raw = data['category']?.toString() ?? '';
        if (raw.isEmpty) continue;
        final canonical = storeCategoryLegacyAliases[raw] ?? raw;
        map[canonical] = (map[canonical] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() => _counts = map);
    } catch (_) {}
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
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final result = await StoreProductSearchService.instance.search(q);
      if (!mounted || _searchQuery.trim() != q) return;
      setState(() {
        _productHits = result;
        _searching = false;
      });
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

  Future<void> _openSupplierAdd() async {
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
                        leading: Icon(cat.icon, color: cat.color),
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
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(categoryTitle: category.title),
      ),
    );
    if (mounted) _loadCounts();
  }

  void _openHit(StoreSearchHit hit) {
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
    final categories = _filteredCategories;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final showProductSearch = _searchQuery.trim().length >= 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AcadeGateAppBar(
        title: Text(context.t('المتجر الأكاديمي', 'Academic store')),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      'أقسام لجميع الباحثين والموردين',
                      'Sections for all researchers and suppliers',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      'ابحث عن منتج أو قسم — يشمل منتجات التطبيق ومواقع الموردين المستوردة.',
                      'Search a product or section — includes in-app products and imported supplier sites.',
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openSupplierAdd,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green[800],
                side: BorderSide(color: Colors.green.shade700),
                minimumSize: const Size.fromHeight(44),
              ),
              icon: const Icon(Icons.add_business_outlined),
              label: Text(
                context.t(
                  'أنا مورد — أضف منتجاً',
                  'I am a supplier — add a product',
                ),
              ),
            ),
            StreamBuilder(
              stream: UserAccountService.instance.watchCurrentAccount(),
              builder: (context, snapshot) {
                if (snapshot.data?.isAdmin != true) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminStoreImportScreen(),
                        ),
                      );
                      if (mounted) _loadCounts();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo[700],
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.cloud_sync_outlined),
                    label: Text(
                      context.t(
                        'استيراد / مزامنة الموردين والمنتجات',
                        'Import / sync suppliers & products',
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SectionSearchField(
              query: _searchQuery,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
              hint: context.t(
                'ابحث عن منتج أو قسم: إيثانول، Arduino، ELISA...',
                'Search product or section: ethanol, Arduino, ELISA...',
              ),
            ),
            if (kIsWeb && showProductSearch) ...[
              const SizedBox(height: 6),
              Text(
                context.t(
                  'البحث المباشر في مواقع الموردين متاح على Windows/Android (قيود الويب).',
                  'Live supplier-site search works on Windows/Android (web CORS limits).',
                ),
                style: TextStyle(fontSize: 11, color: Colors.orange[800]),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: showProductSearch
                  ? _buildSearchResults(context, categories, isAr)
                  : _buildCategoryGrid(context, categories),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context,
    List<StoreCategory> categories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('أيقونات الأقسام', 'Category icons'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            'لكل باحثين كل الكليات · وللموردين لعرض عروضهم',
            'For researchers across faculties · and suppliers to list offers',
          ),
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 68,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              final count = _counts[category.title] ?? 0;
              return _StoreCategoryIconTile(
                category: category,
                productCount: count,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductListScreen(
                        categoryTitle: category.title,
                      ),
                    ),
                  );
                  if (mounted) _loadCounts();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    List<StoreCategory> categories,
    bool isAr,
  ) {
    if (_searching && _productHits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        if (categories.isNotEmpty) ...[
          Text(
            context.t('أقسام مطابقة', 'Matching sections'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...categories.map(
            (category) => Card(
              child: ListTile(
                leading: Icon(category.icon, color: category.color),
                title: Text(L10nLookup.storeCategoryTitle(category.id)),
                subtitle: Text(category.audience(isAr)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductListScreen(categoryTitle: category.title),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          context.t(
            'منتجات داخل التطبيق (${_productHits.local.length})',
            'In-app products (${_productHits.local.length})',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (_productHits.local.isEmpty)
          Text(
            context.t(
              'لا نتائج محلية بعد — جارٍ البحث في مواقع الموردين إن أمكن.',
              'No local hits yet — searching supplier sites when possible.',
            ),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          )
        else
          ..._productHits.local.map((hit) => _ProductHitTile(
                hit: hit,
                badge: context.t('في التطبيق', 'In app'),
                badgeColor: Colors.green,
                onTap: () => _openHit(hit),
              )),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                context.t(
                  'من مواقع الموردين (${_productHits.remote.length})',
                  'From supplier sites (${_productHits.remote.length})',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            if (_searching)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            'حتى لو لم يُعرض المنتج في التطبيق بعد — يظهر من كتالوج الموقع مباشرة.',
            'Even if not listed in the app yet — shown live from the supplier catalog.',
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        if (!_searching && _productHits.remote.isEmpty)
          Text(
            context.t(
              'لا نتائج من المواقع لهذه الكلمة، أو المواقع غير متاحة حالياً.',
              'No site results for this query, or sites are unavailable right now.',
            ),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          )
        else
          ..._productHits.remote.map((hit) => _ProductHitTile(
                hit: hit,
                badge: context.t('من الموقع', 'From site'),
                badgeColor: Colors.indigo,
                onTap: () => _openHit(hit),
              )),
        if (categories.isEmpty && _productHits.isEmpty && !_searching)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                context.t(
                  'لا توجد نتائج لـ «$_searchQuery»',
                  'No results for "$_searchQuery"',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductHitTile extends StatelessWidget {
  final StoreSearchHit hit;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _ProductHitTile({
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

class _StoreCategoryIconTile extends StatelessWidget {
  final StoreCategory category;
  final int productCount;
  final VoidCallback onTap;

  const _StoreCategoryIconTile({
    required this.category,
    required this.productCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(category.icon, color: category.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  L10nLookup.storeCategoryTitle(category.id),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: category.color,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
              if (productCount > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$productCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
