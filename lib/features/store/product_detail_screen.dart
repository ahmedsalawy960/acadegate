import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/payments/payment_checkout_chooser.dart';
import '../../core/payments/payment_method.dart';
import '../auth/auth_guard.dart';
import '../messaging/chat_screen.dart';
import '../messaging/messaging_models.dart';
import '../messaging/messaging_service.dart';
import '../moderation/delete_content_button.dart';
import 'knowledge_assets/knowledge_asset_access_service.dart';
import 'knowledge_assets/knowledge_asset_models.dart';
import 'knowledge_assets/knowledge_asset_workspace_screen.dart';
import 'assembly_guide/assembly_guide_product_card.dart';
import 'catalog_disclaimer.dart';
import '../../core/directory/directory_trust_status.dart';
import 'ai_compare/store_ai_compare_screen.dart';
import 'product_detail_sections.dart';
import 'rfq_request_screen.dart';
import 'store_badges.dart';
import 'store_cart_service.dart';
import 'store_order_service.dart';
import 'store_theme.dart';
import 'vendor_shop_screen.dart';

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
  final String? sourceUrl;
  final String brand;
  final String unit;
  final String grade;
  final String sellerType;
  final List<String> certifications;
  final bool isVerifiedSeller;
  final bool isDirectoryListing;
  final bool isPartner;
  final String directoryStatus;
  final String dataSourceLabelAr;
  final String dataSourceLabelEn;
  final String lastVerifiedIso;
  final String email;
  final String phone;
  final String whatsapp;
  final String website;
  final String sku;
  final String originCountry;
  final List<String> imageUrls;
  final bool inStock;
  final String city;
  final bool fastShipping;
  final List<String> badges;
  final String categoryTitle;
  final String? supplierId;
  final String productType;
  final String licenseMode;
  final bool hasAssemblyGuide;

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
    this.sourceUrl,
    this.brand = '',
    this.unit = '',
    this.grade = '',
    this.sellerType = '',
    this.certifications = const [],
    this.isVerifiedSeller = false,
    this.isDirectoryListing = false,
    this.isPartner = false,
    this.directoryStatus = 'unverified',
    this.dataSourceLabelAr = '',
    this.dataSourceLabelEn = '',
    this.lastVerifiedIso = '',
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.website = '',
    this.sku = '',
    this.originCountry = '',
    this.imageUrls = const [],
    this.inStock = true,
    this.city = '',
    this.fastShipping = false,
    this.badges = const [],
    this.categoryTitle = '',
    this.supplierId,
    this.productType = KnowledgeProductType.physical,
    this.licenseMode = KnowledgeLicenseMode.sale,
    this.hasAssemblyGuide = false,
  });

  bool get isKnowledgeAsset =>
      productType == KnowledgeProductType.knowledgeAsset;

  List<String> get _gallery {
    final urls = <String>[];
    for (final u in imageUrls) {
      final t = u.trim();
      if (t.isNotEmpty && !urls.contains(t)) urls.add(t);
    }
    final primary = (imageUrl ?? '').trim();
    if (primary.isNotEmpty && !urls.contains(primary)) {
      urls.insert(0, primary);
    }
    return urls;
  }

  String get _email {
    if (email.trim().isNotEmpty) return email.trim();
    return _extractEmail(contact);
  }

  String get _phone {
    if (phone.trim().isNotEmpty) return _normalizePhone(phone);
    return _normalizePhone(_extractPhone(contact));
  }

  String get _whatsapp {
    if (whatsapp.trim().isNotEmpty) return _normalizePhone(whatsapp);
    return _phone;
  }

  String get _website {
    if (website.trim().isNotEmpty) return website.trim();
    final m = RegExp(r'https?://[^\s·]+').firstMatch(contact);
    return m?.group(0) ?? '';
  }

  static String _extractEmail(String raw) {
    final m = RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
            caseSensitive: false)
        .firstMatch(raw);
    return m?.group(0) ?? '';
  }

  static String _extractPhone(String raw) {
    final m = RegExp(r'(\+?\d[\d\s\-]{7,}\d)').firstMatch(raw);
    return m?.group(1)?.trim() ?? '';
  }

  static String _normalizePhone(String raw) {
    var p = raw.trim();
    // Fix RTL-reversed display artifacts like "2010...+"
    if (p.endsWith('+') && !p.startsWith('+')) {
      p = '+${p.substring(0, p.length - 1)}';
    }
    p = p.replaceAll(RegExp(r'[\s\-]'), '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (RegExp(r'^01\d{8,9}$').hasMatch(p)) {
      p = '+2$p';
    } else if (RegExp(r'^201\d{8,9}$').hasMatch(p)) {
      p = '+$p';
    }
    return p;
  }

  Future<void> _launchUri(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openKnowledgeLicense(BuildContext context) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !context.mounted) return;
    final id = productId;
    if (id == null || id.isEmpty) return;
    try {
      final license =
          await KnowledgeAssetAccessService.instance.loadLicenseForProduct(id);
      if (!context.mounted) return;
      if (license == null || !license.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'لا يوجد ترخيص نشط بعد. اشترِ الأصل وانتظر تأكيد الدفع (محجوز).',
                'No active license yet. Purchase and wait for payment held confirmation.',
              ),
            ),
          ),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KnowledgeAssetWorkspaceScreen(license: license),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _purchase(BuildContext context) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !context.mounted) return;
    if (productId == null || createdBy == null || createdBy!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'الشراء متاح للمنتجات المسجلة فقط',
              'Purchase is available for registered products only',
            ),
          ),
        ),
      );
      return;
    }
    if (priceValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'السعر غير متاح داخل المنصة — تواصل مع المورد مباشرة',
              'Price is not available in-app — contact the supplier directly',
            ),
          ),
        ),
      );
      return;
    }

    final choice = await showPaymentCheckoutChooser(
      context,
      amountLabel: '$price ${context.t('ج.م', 'EGP')}',
    );
    if (choice == null ||
        choice == PaymentCheckoutChoice.cancel ||
        !context.mounted) {
      return;
    }

    try {
      if (choice == PaymentCheckoutChoice.paymob) {
        final orderId = await StoreOrderService.instance.createOrder(
          productId: productId!,
          productName: name,
          price: priceValue,
          sellerId: createdBy!,
          paymentMethod: PaymentMethod.paymob,
        );
        await StoreOrderService.instance.payOrder(orderId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t(
                  'تم فتح صفحة الدفع — بعد الإتمام ستتحدث حالة الطلب تلقائياً',
                  'Checkout opened — order status updates automatically after payment',
                ),
              ),
            ),
          );
        }
        return;
      }

      // Manual transfer / contact seller
      await StoreOrderService.instance.createOrder(
        productId: productId!,
        productName: name,
        price: priceValue,
        sellerId: createdBy!,
        paymentMethod: PaymentMethod.manual,
      );
      if (!context.mounted) return;
      await _showManualPaymentNextSteps(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst(RegExp(r'^Exception:\s*'), '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showManualPaymentNextSteps(BuildContext context) async {
    final wa = whatsapp.trim().isNotEmpty
        ? whatsapp.trim()
        : (phone.trim().isNotEmpty ? phone.trim() : '');
    final mail = email.trim();
    final site = website.trim().isNotEmpty
        ? website.trim()
        : (sourceUrl?.trim() ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ctx.t('تم إنشاء طلب تحويل يدوي', 'Manual payment order created'),
        ),
        content: Text(
          ctx.t(
            'تواصل مع البائع لإتمام التحويل البنكي أو إنستاباي.\n'
                'بعد التحويل سيؤكد البائع الاستلام داخل المنصة.',
            'Contact the seller to complete a bank or InstaPay transfer.\n'
                'After you transfer, the seller confirms receipt in the app.',
          ),
        ),
        actions: [
          if (wa.isNotEmpty)
            TextButton(
              onPressed: () {
                final digits = wa.replaceAll(RegExp(r'[^\d]'), '');
                _launchUri('https://wa.me/$digits');
              },
              child: Text(ctx.t('واتساب', 'WhatsApp')),
            ),
          if (mail.isNotEmpty)
            TextButton(
              onPressed: () => _launchUri('mailto:$mail'),
              child: Text(ctx.t('بريد', 'Email')),
            ),
          if (site.isNotEmpty)
            TextButton(
              onPressed: () => _launchUri(site),
              child: Text(ctx.t('موقع المورد', 'Supplier site')),
            ),
          if (createdBy != null && createdBy!.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                try {
                  // Same product thread as "Message supplier".
                  final id =
                      await MessagingService.instance.openConversation(
                    otherUserId: createdBy!,
                    otherUserName: storeName,
                    contextType: 'product',
                    contextId: productId ?? '',
                    contextTitle: name,
                  );
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversation: Conversation(
                          id: id,
                          participantIds: [user.uid, createdBy!],
                          participantNames: {createdBy!: storeName},
                          contextType: 'product',
                          contextId: productId ?? '',
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
              },
              child: Text(ctx.t('مراسلة داخل التطبيق', 'In-app message')),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('حسناً', 'OK')),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: StoreTheme.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StoreTheme.border),
      ),
      child: const Icon(
        Icons.shopping_bag_outlined,
        size: 64,
        color: StoreTheme.muted,
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _ltrText(String value, {TextStyle? style}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(value, style: style, textAlign: TextAlign.left),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onCopy,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: StoreTheme.ink),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: _ltrText(
        value,
        style: TextStyle(color: StoreTheme.muted, fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onCopy != null)
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: onCopy,
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: onTap,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEscrow = !isDirectoryListing && priceValue > 0;
    final resolvedEmail = _email;
    final resolvedPhone = _phone;
    final resolvedWhatsapp = _whatsapp;
    final resolvedWebsite = _website;

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(context.t('تفاصيل المنتج', 'Product details')),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: StoreTheme.appBarForeground,
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
            _ProductGallery(urls: _gallery, placeholder: _placeholderIcon()),
            const SizedBox(height: 20),
            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: StoreTheme.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              priceValue > 0
                  ? price
                  : context.t(
                      'السعر عند المورد / عند الطلب',
                      'Price via supplier / on request',
                    ),
              style: priceValue > 0
                  ? StoreTheme.priceStyle.copyWith(fontSize: 20)
                  : TextStyle(
                      fontSize: 16,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w700,
                    ),
            ),
            if (isDirectoryListing) ...[
              const SizedBox(height: 8),
              DirectoryTrustChip(
                status: DirectoryTrustStatus.resolve(
                  directoryStatus: directoryStatus,
                  isPartner: isPartner,
                  isVerifiedSeller: isVerifiedSeller,
                ),
              ),
              const SizedBox(height: 8),
              CatalogDisclaimerBanner(
                isPartner: isPartner ||
                    DirectoryTrustStatus.isTrusted(directoryStatus),
                isDirectoryListing: true,
              ),
              const SizedBox(height: 8),
              CatalogSourceMeta(
                sourceLabel: () {
                  final isAr =
                      Localizations.localeOf(context).languageCode == 'ar';
                  final custom = isAr ? dataSourceLabelAr : dataSourceLabelEn;
                  if (custom.trim().isNotEmpty) return custom.trim();
                  return isAr
                      ? 'دليل عام من مواقع الموردين المعلنة'
                      : 'Public directory from published supplier websites';
                }(),
                lastVerifiedLabel:
                    lastVerifiedIso.trim().isEmpty ? null : lastVerifiedIso,
              ),
              CatalogReportLink(
                targetType: 'product',
                productId: productId,
                supplierId: supplierId,
                storeName: storeName,
                sourceUrl: sourceUrl,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (brand.isNotEmpty) _infoChip(Icons.verified_outlined, brand),
                if (unit.isNotEmpty) _infoChip(Icons.inventory_2_outlined, unit),
                if (grade.isNotEmpty) _infoChip(Icons.science_outlined, grade),
                if (sku.isNotEmpty) _infoChip(Icons.qr_code_2, 'SKU: $sku'),
                if (originCountry.isNotEmpty)
                  _infoChip(Icons.public, originCountry),
                if (city.isNotEmpty) _infoChip(Icons.location_city, city),
                _infoChip(
                  inStock ? Icons.check_circle_outline : Icons.remove_circle_outline,
                  inStock
                      ? context.t('متوفر', 'In stock')
                      : context.t('غير متوفر', 'Out of stock'),
                ),
                if (fastShipping)
                  _infoChip(
                    Icons.bolt_outlined,
                    context.t('شحن سريع', 'Fast shipping'),
                  ),
                ...StoreBadge.resolve(
                  badges,
                  isVerifiedSeller: isVerifiedSeller,
                ).map(
                  (b) => Chip(
                    avatar: Icon(b.icon, size: 16, color: b.color),
                    label: Text(b.label(), style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: b.color.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront, color: StoreTheme.ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            storeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if ((supplierId != null &&
                                supplierId!.trim().isNotEmpty) ||
                            (createdBy != null && createdBy!.isNotEmpty))
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VendorShopScreen(
                                    sellerId: createdBy ?? '',
                                    supplierId: supplierId,
                                    sellerNameHint: storeName,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              context.t('متجر المورد', 'Vendor shop'),
                            ),
                          ),
                      ],
                    ),
                    if (sellerType.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        sellerType,
                        style: TextStyle(color: StoreTheme.muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      context.t('وسائل التواصل', 'Contact methods'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (resolvedPhone.isNotEmpty)
                      _contactRow(
                        icon: Icons.phone_outlined,
                        label: context.t('هاتف', 'Phone'),
                        value: resolvedPhone,
                        onTap: () => _launchUri('tel:$resolvedPhone'),
                        onCopy: () => Clipboard.setData(
                          ClipboardData(text: resolvedPhone),
                        ),
                      ),
                    if (resolvedWhatsapp.isNotEmpty)
                      _contactRow(
                        icon: Icons.chat_outlined,
                        label: context.t('واتساب', 'WhatsApp'),
                        value: resolvedWhatsapp,
                        onTap: () {
                          final digits =
                              resolvedWhatsapp.replaceAll(RegExp(r'[^\d]'), '');
                          _launchUri('https://wa.me/$digits');
                        },
                        onCopy: () => Clipboard.setData(
                          ClipboardData(text: resolvedWhatsapp),
                        ),
                      ),
                    if (resolvedEmail.isNotEmpty)
                      _contactRow(
                        icon: Icons.email_outlined,
                        label: context.t('بريد', 'Email'),
                        value: resolvedEmail,
                        onTap: () => _launchUri('mailto:$resolvedEmail'),
                        onCopy: () => Clipboard.setData(
                          ClipboardData(text: resolvedEmail),
                        ),
                      ),
                    if (resolvedWebsite.isNotEmpty)
                      _contactRow(
                        icon: Icons.language,
                        label: context.t('الموقع', 'Website'),
                        value: resolvedWebsite,
                        onTap: () => _launchUri(resolvedWebsite),
                      ),
                    if (resolvedPhone.isEmpty &&
                        resolvedEmail.isEmpty &&
                        resolvedWebsite.isEmpty &&
                        contact.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _ltrText(
                          contact,
                          style: TextStyle(color: StoreTheme.muted),
                        ),
                      ),
                    if (certifications.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        context.t(
                          'المؤهلات / الشهادات',
                          'Credentials / certifications',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: certifications
                            .map((c) => Chip(label: Text(c)))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.t('الوصف', 'Description'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(height: 1.5)),
            if (sourceUrl != null && sourceUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _launchUri(sourceUrl!.trim()),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  context.t(
                    'فتح صفحة المنتج لدى المورد',
                    'Open product on supplier site',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (productId != null && productId!.isNotEmpty)
              AssemblyGuideProductCard(
                productId: productId!,
                productName: name,
                createdBy: createdBy,
                hintHasGuide: hasAssemblyGuide,
              ),
            if (isKnowledgeAsset) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD1C4E9)),
                ),
                child: Text(
                  context.t(
                    'أصل معرفي مشفّر · ${licenseMode == KnowledgeLicenseMode.rental ? 'إيجار مؤقت' : 'بيع ترخيص'} · '
                    'يُستخدم داخل AcadeGate بعد تأكيد الدفع. الحماية تقلّل التسريب وليست ضماناً مطلقاً.',
                    'Encrypted knowledge asset · ${licenseMode == KnowledgeLicenseMode.rental ? 'rental' : 'sale'} · '
                    'Used inside AcadeGate after payment confirmation. Protection reduces leakage; not absolute DRM.',
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openKnowledgeLicense(context),
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(
                  context.t(
                    'فتح بيئة الاستخدام المرخّصة',
                    'Open licensed workspace',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (showEscrow) ...[
              FilledButton.icon(
                onPressed: () => _purchase(context),
                style: FilledButton.styleFrom(
                  backgroundColor: StoreTheme.accent,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: Text(
                  context.t(
                    isKnowledgeAsset
                        ? 'شراء / استئجار الترخيص'
                        : 'شراء الآن — ادفع أو حوّل يدوياً',
                    isKnowledgeAsset
                        ? 'Buy / rent license'
                        : 'Buy now — pay or transfer manually',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  if (productId == null ||
                      createdBy == null ||
                      createdBy!.isEmpty) {
                    return;
                  }
                  StoreCartService.instance.add(
                    StoreCartItem(
                      productId: productId!,
                      name: name,
                      price: priceValue,
                      storeName: storeName,
                      sellerId: createdBy!,
                      imageUrl: imageUrl,
                      isDirectoryListing: isDirectoryListing,
                      category: categoryTitle,
                      description: description,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t('أُضيف إلى العربة', 'Added to cart'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: Text(context.t('أضف إلى العربة', 'Add to cart')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ] else if (isDirectoryListing)
              FilledButton.icon(
                onPressed: () {
                  if (resolvedWhatsapp.isNotEmpty) {
                    final digits =
                        resolvedWhatsapp.replaceAll(RegExp(r'[^\d]'), '');
                    _launchUri('https://wa.me/$digits');
                  } else if (resolvedEmail.isNotEmpty) {
                    _launchUri('mailto:$resolvedEmail');
                  } else if (sourceUrl != null && sourceUrl!.trim().isNotEmpty) {
                    _launchUri(sourceUrl!.trim());
                  } else if (resolvedWebsite.isNotEmpty) {
                    _launchUri(resolvedWebsite);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: StoreTheme.accent,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.support_agent),
                label: Text(
                  context.t('تواصل مع المورد مباشرة', 'Contact supplier directly'),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final loggedIn = await ensureLoggedIn(context);
                if (!loggedIn || !context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RfqRequestScreen(
                      productId: productId,
                      productName: name,
                      category: categoryTitle,
                      sellerId: createdBy ?? '',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.request_quote_outlined),
              label: Text(
                context.t('طلب عرض سعر (RFQ)', 'Request a quote (RFQ)'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (!isDirectoryListing &&
                createdBy != null &&
                createdBy!.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final loggedIn = await ensureLoggedIn(context);
                  if (!loggedIn || !context.mounted) return;
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  try {
                    final id = await MessagingService.instance.openConversation(
                      otherUserId: createdBy!,
                      otherUserName: storeName,
                      contextType: 'product',
                      contextId: productId ?? '',
                      contextTitle: name,
                    );
                    if (!context.mounted) return;
                    final conv = Conversation(
                      id: id,
                      participantIds: [user.uid, createdBy!],
                      participantNames: {createdBy!: storeName},
                      contextType: 'product',
                      contextId: productId ?? '',
                    );
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(conversation: conv),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.chat_outlined),
                label: Text(
                  context.t('مراسلة المورد', 'Message supplier'),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreAiCompareScreen(
                      initialQuery: name,
                      brand: brand,
                      categoryTitle: categoryTitle,
                      description: description,
                      productId: productId,
                      storeName: storeName,
                      price: priceValue,
                      imageUrl: imageUrl,
                      sourceUrl: sourceUrl,
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFBBF24),
                foregroundColor: const Color(0xFF071433),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.price_check),
              label: Text(
                context.t(
                  'قارن السعر بين الموردين',
                  'Compare price across suppliers',
                ),
              ),
            ),
            if (productId != null && productId!.isNotEmpty) ...[
              ProductQaSection(
                productId: productId!,
                sellerId: createdBy,
              ),
              ProductSimilarSection(
                productId: productId!,
                categoryTitle: categoryTitle,
                productName: name,
                brand: brand,
                description: description,
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

class _ProductGallery extends StatefulWidget {
  final List<String> urls;
  final Widget placeholder;

  const _ProductGallery({required this.urls, required this.placeholder});

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return Center(child: widget.placeholder);
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: PageView.builder(
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Image.network(
                widget.urls[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => widget.placeholder,
              ),
            ),
          ),
        ),
        if (widget.urls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.urls.length, (i) {
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _index ? StoreTheme.accent : Colors.grey[350],
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
