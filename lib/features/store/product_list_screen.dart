import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../moderation/approval_status.dart';
import 'add_product_screen.dart';
import 'import/egypt_store_suppliers_catalog.dart';
import 'product_detail_screen.dart';
import 'store_categories.dart';

class ProductListScreen extends StatelessWidget {
  final String categoryTitle;

  const ProductListScreen({super.key, required this.categoryTitle});

  String _formatPrice(num price) => '$price ${appTr('ج.م', 'EGP')}';

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  List<String> _queryTitles(StoreCategory? category, String fallback) {
    if (category == null) return [fallback];
    return storeCategoryQueryTitles(category);
  }

  Future<void> _openSupplier(EgyptStoreSupplier supplier) async {
    final uri = Uri.tryParse(supplier.website);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final category = storeCategoryByTitle(categoryTitle);
    final accentColor = category?.color ?? Colors.green[700]!;
    final displayTitle = category != null
        ? L10nLookup.storeCategoryTitle(category.id)
        : categoryTitle;
    final queryTitles = _queryTitles(category, categoryTitle);
    final suppliers = egyptStoreSuppliersForCategory(
      categoryId: category?.id,
      categoryTitle: categoryTitle,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AcadeGateAppBar(
        title: Text(displayTitle),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('إضافة منتج كمورد', 'Add product as supplier'),
            icon: const Icon(Icons.add),
            onPressed: () async {
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
                        'تم إرسال المنتج للمراجعة — سيظهر بعد الموافقة',
                        'Product sent for review — it will appear after approval',
                      ),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
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
          final docs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['approvalStatus']?.toString();
            if (!ApprovalStatus.isPublic(status)) return false;
            final cat = data['category']?.toString() ?? '';
            final canonical = storeCategoryLegacyAliases[cat] ?? cat;
            return titleSet.contains(cat) || titleSet.contains(canonical);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                    'تواصل مباشرة — حتى لو لم تُدرج كل منتجاتهم بعد',
                    'Contact directly — even if not every product is listed yet',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                      subtitle: Text(
                        [
                          if (s.city.isNotEmpty) s.city,
                          if (s.phone.isNotEmpty) s.phone,
                          if (s.email.isNotEmpty) s.email,
                          if (s.focusAreas.isNotEmpty)
                            s.focusAreas.take(2).join(' · '),
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.open_in_new, size: 18),
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
              if (docs.isEmpty)
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
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddProductScreen(
                                categoryTitle: category?.title ?? categoryTitle,
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                        ),
                        icon: const Icon(Icons.add_business_outlined),
                        label: Text(
                          context.t(
                            'إضافة منتج كمورد',
                            'Add product as supplier',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(docs.length, (index) {
                  final productData =
                      docs[index].data() as Map<String, dynamic>;
                  final price = productData['price'] ?? 0;
                  final certifications =
                      _stringList(productData['certifications']);
                  final brand = productData['brand']?.toString() ?? '';
                  final unit = productData['unit']?.toString() ?? '';
                  final grade = productData['grade']?.toString() ?? '';
                  final sellerType =
                      productData['sellerType']?.toString() ?? '';
                  final storeName = productData['storeName']?.toString() ??
                      context.t('متجر غير معروف', 'Unknown store');
                  final verified = productData['isVerifiedSeller'] == true;
                  final name = productData['name']?.toString() ??
                      context.t('منتج', 'Product');
                  final formattedPrice = price is num && price > 0
                      ? _formatPrice(price)
                      : context.t(
                          'السعر عند المورد',
                          'Price via supplier',
                        );
                  final isDirectory =
                      productData['isDirectoryListing'] == true ||
                          (productData['importSource']?.toString() ?? '')
                              .startsWith('wc_');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProductCard(
                      name: name,
                      price: formattedPrice,
                      storeName: storeName,
                      brand: brand,
                      unit: unit,
                      grade: grade,
                      isVerifiedSeller: verified,
                      icon: category?.icon ?? Icons.shopping_bag_outlined,
                      color: accentColor,
                      imageUrl: productData['imageUrl']?.toString(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(
                              name: name,
                              price: formattedPrice,
                              description:
                                  productData['description']?.toString() ??
                                  context.t(
                                    'لا يوجد وصف متاح لهذا المنتج حالياً.',
                                    'No description available for this product yet.',
                                  ),
                              storeName: storeName,
                              contact:
                                  productData['contact']?.toString() ?? '',
                              productId: docs[index].id,
                              createdBy:
                                  productData['createdBy']?.toString(),
                              priceValue:
                                  (productData['price'] as num?) ?? 0,
                              imageUrl:
                                  productData['imageUrl']?.toString(),
                              sourceUrl:
                                  productData['sourceUrl']?.toString(),
                              brand: brand,
                              unit: unit,
                              grade: grade,
                              sellerType: sellerType,
                              certifications: certifications,
                              isVerifiedSeller: verified,
                              isDirectoryListing: isDirectory,
                              email:
                                  productData['email']?.toString() ?? '',
                              phone:
                                  productData['phone']?.toString() ?? '',
                              whatsapp: productData['whatsapp']
                                      ?.toString() ??
                                  '',
                              website: productData['website']
                                      ?.toString() ??
                                  '',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          );
        },
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

    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.storefront, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        if (isVerifiedSeller)
                          Icon(Icons.verified, size: 16, color: Colors.green[700]),
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

  Widget _iconBox() {
    return Container(
      color: color.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(icon, size: 28, color: color),
    );
  }
}
