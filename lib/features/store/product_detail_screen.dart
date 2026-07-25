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
import 'store_order_service.dart';

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
  final String email;
  final String phone;
  final String whatsapp;
  final String website;

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
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.website = '',
  });

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
                  final id =
                      await MessagingService.instance.openConversation(
                    otherUserId: createdBy!,
                    otherUserName: storeName,
                    contextType: 'manual_payment',
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
                          contextType: 'manual_payment',
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
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.green[700]),
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
      leading: Icon(icon, color: Colors.green[700]),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: _ltrText(
        value,
        style: TextStyle(color: Colors.grey[900], fontSize: 14),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AcadeGateAppBar(
        title: Text(context.t('تفاصيل المنتج', 'Product details')),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
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
            Center(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholderIcon(),
                      ),
                    )
                  : _placeholderIcon(),
            ),
            const SizedBox(height: 20),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              priceValue > 0
                  ? price
                  : context.t(
                      'السعر عند المورد / عند الطلب',
                      'Price via supplier / on request',
                    ),
              style: TextStyle(
                fontSize: 18,
                color: priceValue > 0 ? Colors.green[700] : Colors.orange[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isDirectoryListing) ...[
              const SizedBox(height: 8),
              Text(
                context.t(
                  'عرض استرشادي من كتالوج المورد — التواصل والشراء يتمان مباشرة مع المورد.',
                  'Directory listing from the supplier catalog — contact and purchase happen directly with the supplier.',
                ),
                style: TextStyle(color: Colors.grey[700], height: 1.35),
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
                        Icon(Icons.storefront, color: Colors.green[700]),
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
                        if (isVerifiedSeller)
                          Chip(
                            label: Text(
                              context.t('مورّد موثوق', 'Verified seller'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.green.shade50,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    if (sellerType.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        sellerType,
                        style: TextStyle(color: Colors.grey[700]),
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
                          style: TextStyle(color: Colors.grey[800]),
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
            if (showEscrow)
              FilledButton.icon(
                onPressed: () => _purchase(context),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: Text(
                  context.t('شراء — ادفع أو حوّل يدوياً', 'Buy — pay or transfer manually'),
                ),
              )
            else if (isDirectoryListing)
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
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.support_agent),
                label: Text(
                  context.t('تواصل مع المورد مباشرة', 'Contact supplier directly'),
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
          ],
        ),
      ),
    );
  }
}
