import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/directory/claim_profile_sheet.dart';
import '../../core/directory/directory_trust_status.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../moderation/approval_status.dart';
import 'import/egypt_store_suppliers_catalog.dart';
import 'catalog_disclaimer.dart';
import 'managed_supplier_profile_screen.dart';
import 'store_badges.dart';
import 'store_catalog_service.dart';
import 'store_product_navigation.dart';
import 'store_theme.dart';

/// متجر مورد عام: كتالوج + تواصل + سياسة تسليم مبسّطة.
///
/// للمنتجات المستوردة من WooCommerce: فلتر بـ [supplierId]
/// (لأن createdBy = أدمن الاستيراد المشترك لكل الموردين).
/// للتجّار الحقيقيين: فلتر بـ [sellerId] = createdBy.
class VendorShopScreen extends StatelessWidget {
  final String sellerId;
  final String? supplierId;
  final String? sellerNameHint;

  const VendorShopScreen({
    super.key,
    this.sellerId = '',
    this.supplierId,
    this.sellerNameHint,
  });

  bool get _useSupplierId => (supplierId ?? '').trim().isNotEmpty;

  Stream<QuerySnapshot<Map<String, dynamic>>> _productStream() {
    final col = FirebaseFirestore.instance.collection('product');
    if (_useSupplierId) {
      return col.where('supplierId', isEqualTo: supplierId!.trim()).snapshots();
    }
    return col.where('createdBy', isEqualTo: sellerId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final canQuery = _useSupplierId || sellerId.trim().isNotEmpty;

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(context.t('متجر المورد', 'Vendor shop')),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
        ),
        body: !canQuery
            ? Center(
                child: Text(
                  context.t('معرف المورد غير متوفر', 'Vendor id unavailable'),
                ),
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _productStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var products = snapshot.data!.docs
                      .where(
                        (d) => ApprovalStatus.isPublic(
                          d.data()['approvalStatus']?.toString(),
                        ),
                      )
                      .map(StoreCatalogProduct.fromDoc)
                      .toList();

                  // حماية إضافية: إن فُتح المتجر بـ createdBy فقط (استيراد مشترك)،
                  // صفِّ حسب اسم المتجر حتى لا تختلط كتالوجات الموردين.
                  if (!_useSupplierId) {
                    final hint = (sellerNameHint ?? '').trim();
                    final mixedImports = products
                        .map((p) => (p.supplierId ?? '').trim())
                        .where((id) => id.isNotEmpty)
                        .toSet();
                    if (mixedImports.length > 1 && hint.isNotEmpty) {
                      products = products
                          .where((p) => p.storeName.trim() == hint)
                          .toList();
                    }
                  }

                  products.sort((a, b) => b.orderCount.compareTo(a.orderCount));

                  if (products.isEmpty) {
                    return Center(
                      child: Text(
                        context.t(
                          'لا منتجات معتمدة لهذا المورد بعد',
                          'No approved products for this vendor yet',
                        ),
                      ),
                    );
                  }

                  final catalogSupplier = _useSupplierId
                      ? egyptStoreSupplierById(supplierId!.trim())
                      : null;

                  final sample = products.firstWhere(
                    (p) {
                      if (_useSupplierId) {
                        return (p.supplierId ?? '').trim() ==
                            supplierId!.trim();
                      }
                      final hint = (sellerNameHint ?? '').trim();
                      return hint.isEmpty || p.storeName.trim() == hint;
                    },
                    orElse: () => products.first,
                  );

                  final name = (sellerNameHint ?? '').trim().isNotEmpty
                      ? sellerNameHint!.trim()
                      : (catalogSupplier?.nameAr.isNotEmpty == true
                          ? catalogSupplier!.nameAr
                          : (sample.storeName.isNotEmpty
                              ? sample.storeName
                              : context.t(
                                  'مورد أكاديمي',
                                  'Academic supplier',
                                )));

                  final email = (catalogSupplier?.email ?? '').isNotEmpty
                      ? catalogSupplier!.email
                      : sample.email;
                  final phone = (catalogSupplier?.phone ?? '').isNotEmpty
                      ? catalogSupplier!.phone
                      : sample.phone;
                  final whatsapp = (catalogSupplier?.whatsapp ?? '').isNotEmpty
                      ? catalogSupplier!.whatsapp
                      : sample.whatsapp;

                  final badges = StoreBadge.resolve(
                    sample.badges,
                    isVerifiedSeller: products.any((p) => p.isVerifiedSeller),
                  );
                  final cities = products
                      .map((p) => p.city.trim())
                      .where((c) => c.isNotEmpty)
                      .toSet()
                      .take(3)
                      .join(' · ');

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: StoreTheme.accentSoft,
                                    child: Icon(
                                      Icons.storefront,
                                      color: StoreTheme.ink,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: StoreTheme.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.t(
                                            '${products.length} منتج · ${products.fold<int>(0, (s, p) => s + p.orderCount)} طلب مدفوع',
                                            '${products.length} products · ${products.fold<int>(0, (s, p) => s + p.orderCount)} paid orders',
                                          ),
                                          style: const TextStyle(
                                            color: StoreTheme.muted,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (badges.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: badges
                                      .map(
                                        (b) => Chip(
                                          avatar: Icon(
                                            b.icon,
                                            size: 16,
                                            color: b.color,
                                          ),
                                          label: Text(
                                            b.label(),
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor:
                                              b.color.withValues(alpha: 0.08),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              if (cities.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${context.t('المدينة', 'City')}: $cities',
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (catalogSupplier != null)
                                StreamBuilder(
                                  stream: FirebaseFirestore.instance
                                      .collection('store_suppliers')
                                      .doc(catalogSupplier.id)
                                      .snapshots(),
                                  builder: (context, supplierSnap) {
                                    final d = supplierSnap.data?.data();
                                    final status =
                                        DirectoryTrustStatus.resolve(
                                      directoryStatus:
                                          d?['directoryStatus']?.toString(),
                                      isPartner: d?['isPartner'] == true,
                                      isVerifiedSeller:
                                          d?['isVerifiedSeller'] == true,
                                      claimedByUid:
                                          d?['claimedByUid']?.toString(),
                                    );
                                    final claimedBy =
                                        d?['claimedByUid']?.toString() ?? '';
                                    final lastManaged =
                                        d?['lastManagedIso']?.toString() ?? '';
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        DirectoryTrustChip(
                                          status: status,
                                          lastManagedLabel: lastManaged,
                                        ),
                                        const SizedBox(height: 8),
                                        CatalogDisclaimerBanner(
                                          isPartner:
                                              DirectoryTrustStatus.isTrusted(
                                            status,
                                          ),
                                          isDirectoryListing: true,
                                        ),
                                        const SizedBox(height: 8),
                                        CatalogSourceMeta(
                                          sourceLabel:
                                              catalogSupplier.dataSourceLabel(
                                            Localizations.localeOf(context)
                                                    .languageCode ==
                                                'ar',
                                          ),
                                          lastVerifiedLabel: (d?[
                                                      'lastVerifiedIso']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true)
                                              ? d!['lastVerifiedIso'].toString()
                                              : catalogSupplier.lastVerifiedIso,
                                          lastManagedLabel: lastManaged,
                                        ),
                                        CatalogReportLink(
                                          targetType: 'supplier',
                                          supplierId: catalogSupplier.id,
                                          storeName: name,
                                          sourceUrl: catalogSupplier.website,
                                          emphasizeFakeSupplier: true,
                                        ),
                                        StreamBuilder(
                                          stream: UserAccountService
                                              .instance
                                              .watchCurrentAccount(),
                                          builder: (context, accountSnap) {
                                            final account = accountSnap.data;
                                            final role = account?.role ?? '';
                                            final uid = account?.uid ?? '';
                                            final isOwner = uid.isNotEmpty &&
                                                uid == claimedBy;
                                            final canManage =
                                                DirectoryTrustStatus
                                                    .canManageListing(
                                              status,
                                              isOwner: isOwner,
                                            );
                                            final canClaim = (role ==
                                                        UserRole.merchant ||
                                                    role == UserRole.admin) &&
                                                !isOwner &&
                                                claimedBy.isEmpty &&
                                                status !=
                                                    DirectoryTrustStatus
                                                        .managedVerified;
                                            final needsRoleHint =
                                                !canManage &&
                                                !canClaim &&
                                                claimedBy.isEmpty &&
                                                status !=
                                                    DirectoryTrustStatus
                                                        .managedVerified;
                                            if (!canManage &&
                                                !canClaim &&
                                                !needsRoleHint) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  if (needsRoleHint)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                        10,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFFFF3E0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFFFCC80,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        context.t(
                                                          'لمطالبة هذا الملف سجّل حساباً بدور «تاجر / مورد»، ثم اضغط «مطالبة هذا الملف».',
                                                          'To claim this profile, register with the Merchant / Supplier role, then tap “Claim this profile”.',
                                                        ),
                                                        style: TextStyle(
                                                          height: 1.35,
                                                          fontSize: 13,
                                                          color:
                                                              Colors.brown[900],
                                                        ),
                                                      ),
                                                    ),
                                                  Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (canManage)
                                                    FilledButton.icon(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .push(
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                ManagedSupplierProfileScreen(
                                                              supplierId:
                                                                  catalogSupplier
                                                                      .id,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.edit_note,
                                                      ),
                                                      label: Text(
                                                        context.t(
                                                          'ترتيب بيانات الملف',
                                                          'Arrange profile data',
                                                        ),
                                                      ),
                                                    ),
                                                  if (canClaim)
                                                    OutlinedButton.icon(
                                                      onPressed: () {
                                                        showClaimProfileSheet(
                                                          context,
                                                          targetType:
                                                              'supplier',
                                                          targetId:
                                                              catalogSupplier
                                                                  .id,
                                                          targetName: name,
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.badge_outlined,
                                                      ),
                                                      label: Text(
                                                        context.t(
                                                          'مطالبة هذا الملف',
                                                          'Claim this profile',
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                )
                              else ...[
                                CatalogDisclaimerBanner(
                                  isPartner: products.any((p) => p.isPartner),
                                  isDirectoryListing: products
                                      .any((p) => p.isDirectoryListing),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                context.t('سياسة التسليم', 'Delivery policy'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.t(
                                  'الشراء عبر ضمان Escrow داخل AcadeGate عند توفر السعر وحساب Partner. الأصناف الدليلية العامة تُشترى بالتواصل المباشر وليست اعتماداً من الشركة.',
                                  'Escrow checkout inside AcadeGate when priced on a Partner account. Public directory items use direct contact and are not a company endorsement.',
                                ),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  height: 1.4,
                                  fontSize: 13,
                                ),
                              ),
                              if (email.isNotEmpty ||
                                  phone.isNotEmpty ||
                                  whatsapp.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  [
                                    if (phone.isNotEmpty) phone,
                                    if (whatsapp.isNotEmpty) whatsapp,
                                    if (email.isNotEmpty) email,
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.t('كتالوج المورد', 'Vendor catalog'),
                        style: StoreTheme.sectionTitle,
                      ),
                      const SizedBox(height: 8),
                      ...products.map((p) {
                        final price = p.price > 0
                            ? '${p.price} ${appTr('ج.م', 'EGP')}'
                            : context.t('عند المورد', 'Via supplier');
                        return Card(
                          child: ListTile(
                            leading: (p.imageUrl ?? '').isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      p.imageUrl!,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.shopping_bag_outlined),
                                    ),
                                  )
                                : const Icon(Icons.shopping_bag_outlined),
                            title: Text(p.name, maxLines: 2),
                            subtitle: Text(price),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => openStoreProductDetail(context, p),
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
