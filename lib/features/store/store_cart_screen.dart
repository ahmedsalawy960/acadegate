import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/payments/payment_checkout_chooser.dart';
import '../../core/payments/payment_method.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../auth/auth_guard.dart';
import 'research_partnership/create_research_partnership_screen.dart';
import 'store_cart_safety_service.dart';
import 'store_cart_safety_sheet.dart';
import 'store_cart_service.dart';
import 'store_order_service.dart';
import 'store_protocol_sim_sheet.dart';
import 'store_theme.dart';

class StoreCartScreen extends StatefulWidget {
  const StoreCartScreen({super.key});

  @override
  State<StoreCartScreen> createState() => _StoreCartScreenState();
}

class _StoreCartScreenState extends State<StoreCartScreen> {
  final _cart = StoreCartService.instance;
  bool _checkingOut = false;
  bool _scanningSafety = false;
  bool _simulatingProtocol = false;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCart);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCart);
    super.dispose();
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  Future<void> _scanSafety() async {
    if (_cart.items.isEmpty) return;

    setState(() => _scanningSafety = true);
    try {
      final result =
          await StoreCartSafetyService.instance.scanCart(_cart.items);
      if (!mounted) return;
      if (result.hasError && !result.hasNotes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error!)),
        );
        return;
      }
      await showCartSafetySheet(context, result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _scanningSafety = false);
    }
  }

  Future<void> _simulateProtocol() async {
    if (_cart.items.isEmpty) return;
    setState(() => _simulatingProtocol = true);
    try {
      await showProtocolSimFlow(context, cartItems: List.of(_cart.items));
    } finally {
      if (mounted) setState(() => _simulatingProtocol = false);
    }
  }

  Future<void> _checkout() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    final items = _cart.escrowItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'لا توجد أصناف قابلة للدفع عبر الضمان في العربة',
              'No escrow-eligible items in the cart',
            ),
          ),
        ),
      );
      return;
    }

    final choice = await showPaymentCheckoutChooser(
      context,
      amountLabel: '${_cart.subtotal} ${appTr('ج.م', 'EGP')}',
    );
    if (choice == null ||
        choice == PaymentCheckoutChoice.cancel ||
        !mounted) {
      return;
    }

    setState(() => _checkingOut = true);
    final createdIds = <String>[];
    final paidProductIds = <String>[];
    try {
      final payMethod = choice == PaymentCheckoutChoice.paymob
          ? PaymentMethod.paymob
          : PaymentMethod.manual;
      for (final item in items) {
        for (var q = 0; q < item.quantity; q++) {
          final orderId = await StoreOrderService.instance.createOrder(
            productId: item.productId,
            productName: item.name,
            price: item.price,
            sellerId: item.sellerId,
            paymentMethod: payMethod,
          );
          createdIds.add(orderId);
          if (payMethod == PaymentMethod.paymob) {
            await StoreOrderService.instance.payOrder(orderId);
          }
        }
        paidProductIds.add(item.productId);
      }
      _cart.removeIds(paidProductIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            payMethod == PaymentMethod.manual
                ? context.t(
                    'تم إنشاء ${createdIds.length} طلب تحويل يدوي',
                    'Created ${createdIds.length} manual transfer order(s)',
                  )
                : context.t(
                    'تم إنشاء ${createdIds.length} طلب ودفع الضمان',
                    'Created ${createdIds.length} escrow order(s)',
                  ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_cart.items.isEmpty && mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _cart.items;
    final groups = _cart.groupedBySeller;

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(context.t('عربة التسوق', 'Shopping cart')),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: StoreTheme.appBarForeground,
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                context.t('العربة فارغة', 'Your cart is empty'),
                style: const TextStyle(color: StoreTheme.muted),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in groups.entries) ...[
                        Text(
                          items
                                  .firstWhere(
                                    (e) => e.sellerId == entry.key,
                                    orElse: () => entry.value.first,
                                  )
                                  .storeName
                                  .isNotEmpty
                              ? items
                                  .firstWhere((e) => e.sellerId == entry.key)
                                  .storeName
                              : context.t('مورد', 'Supplier'),
                          style: StoreTheme.sectionTitle.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        ...entry.value.map((item) {
                          return Card(
                            child: ListTile(
                              leading: item.imageUrl != null &&
                                      item.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item.imageUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const Icon(Icons.shopping_bag),
                                      ),
                                    )
                                  : const Icon(Icons.shopping_bag_outlined),
                              title: Text(item.name, maxLines: 2),
                              subtitle: Text(
                                '${item.price} ${appTr('ج.م', 'EGP')} × ${item.quantity}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => _cart.setQuantity(
                                      item.productId,
                                      item.quantity - 1,
                                    ),
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => _cart.setQuantity(
                                      item.productId,
                                      item.quantity + 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],
                      if (_cart.items.any((e) =>
                          e.isDirectoryListing ||
                          e.price <= 0 ||
                          e.sellerId.isEmpty))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            context.t(
                              'بعض الأصناف دليلية أو بدون بائع — تواصل معها من صفحة المنتج.',
                              'Some items are directory listings — contact from the product page.',
                            ),
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              context.t('الإجمالي (Escrow)', 'Escrow subtotal'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              '${_cart.subtotal} ${appTr('ج.م', 'EGP')}',
                              style: StoreTheme.priceStyle.copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: (_checkingOut ||
                                  _scanningSafety ||
                                  _simulatingProtocol)
                              ? null
                              : _scanSafety,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: StoreTheme.ink,
                            side: const BorderSide(color: StoreTheme.hairline),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: _scanningSafety
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.health_and_safety_outlined),
                          label: Text(
                            _scanningSafety
                                ? context.t('جارٍ فحص السلامة…', 'Scanning safety…')
                                : context.t(
                                    'فحص سلامة المنتجات (مخاطر / تعامل / تخزين)',
                                    'Scan product safety (hazards / handling / storage)',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: (_checkingOut ||
                                  _scanningSafety ||
                                  _simulatingProtocol)
                              ? null
                              : _simulateProtocol,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: StoreTheme.ink,
                            side: const BorderSide(color: StoreTheme.hairline),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: _simulatingProtocol
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.science_outlined),
                          label: Text(
                            _simulatingProtocol
                                ? context.t(
                                    'جارٍ محاكاة البروتوكول…',
                                    'Simulating protocol…',
                                  )
                                : context.t(
                                    'محاكاة البروتوكول قبل الشراء',
                                    'Protocol check before purchase',
                                  ),
                          ),
                        ),
                        if (!GeminiAdvisorClient.isAvailable) ...[
                          const SizedBox(height: 4),
                          Text(
                            context.t(
                              'بدون تسجيل دخول: فحص السلامة محلي بالكلمات. محاكاة البروتوكول تحتاج تسجيل الدخول أو مفتاح Gemini.',
                              'Without sign-in: local keyword safety scan. Protocol simulation needs sign-in or a Gemini key.',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: StoreTheme.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: (_checkingOut ||
                                  _scanningSafety ||
                                  _simulatingProtocol)
                              ? null
                              : () async {
                                  final loggedIn =
                                      await ensureLoggedIn(context);
                                  if (!loggedIn || !mounted) return;
                                  final items = _cart.escrowItems;
                                  if (items.isEmpty) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.t(
                                            'أضف أصنافاً قابلة للضمان أولاً',
                                            'Add escrow-eligible items first',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!mounted) return;
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CreateResearchPartnershipScreen(
                                        items: List.of(items),
                                      ),
                                    ),
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: StoreTheme.accent,
                            side: const BorderSide(color: StoreTheme.accent),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.handshake_outlined),
                          label: Text(
                            context.t(
                              'اطرح كشراكة بحثية',
                              'Offer as research partnership',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: (_checkingOut || _scanningSafety)
                              ? null
                              : _checkout,
                          style: FilledButton.styleFrom(
                            backgroundColor: StoreTheme.accent,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: _checkingOut
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.lock_outline),
                          label: Text(
                            context.t(
                              'إتمام الدفع — طلب لكل صنف/مورد',
                              'Checkout — one order per item/vendor',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ),
    );
  }
}
