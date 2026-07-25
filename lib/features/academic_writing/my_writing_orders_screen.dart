import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/escrow/payment_status.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/payments/payment_checkout_chooser.dart';
import '../../core/payments/payment_method.dart';
import 'writing_categories.dart';
import 'writing_models.dart';
import 'writing_service.dart';

class MyWritingOrdersScreen extends StatelessWidget {
  const MyWritingOrdersScreen({super.key});

  static const _brandColor = Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('طلبات الكتابة', 'Writing orders')),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? Center(
              child: Text(
                context.t('سجّل الدخول لعرض طلباتك', 'Sign in to view your orders'),
              ),
            )
          : StreamBuilder<List<WritingOrder>>(
              stream: WritingService.instance.userOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            context.t('تعذر تحميل الطلبات', 'Could not load orders'),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          context.t('لا توجد طلبات حجز بعد', 'No booking orders yet'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderCard(order: order);
                  },
                );
              },
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final WritingOrder order;

  const _OrderCard({required this.order});

  Color _statusColor() {
    if (order.isCompleted) return Colors.green;
    if (order.isCancelled) return Colors.red;
    if (order.isInProgress) return Colors.blue;
    if (order.isConfirmed) return Colors.teal;
    return Colors.orange;
  }

  String _localizedCategory() {
    final cat = writingCategoryByTitle(order.category);
    return cat?.localizedTitle ?? order.category;
  }

  @override
  Widget build(BuildContext context) {
    final amount = order.amount > 0 ? order.amount : 500;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.topic,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${_localizedCategory()} • ${order.expertName}'),
            Text(
              '${localizedAcademicLevel(order.academicLevel)} • ${localizedWritingLanguage(order.language)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (order.deadline != null)
              Text(
                context.t(
                  'التسليم: ${order.deadline!.year}/${order.deadline!.month}/${order.deadline!.day}',
                  'Delivery: ${order.deadline!.year}/${order.deadline!.month}/${order.deadline!.day}',
                ),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            if (order.milestones.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.t('باقة مرحلية', 'Milestone package'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: order.milestones
                    .map(
                      (m) => Chip(
                        label: Text(
                          localizedThesisMilestone(m),
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (order.addons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: order.addons
                    .map(
                      (a) => Chip(
                        label: Text(
                          localizedWritingAddon(a),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (order.isPending || order.isConfirmed) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: order.serviceId == null
                      ? null
                      : () async {
                          try {
                            await WritingService.instance.cancelOrder(
                              serviceId: order.serviceId!,
                              orderId: order.id!,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t('تم إلغاء الطلب', 'Order cancelled'),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(context.t('إلغاء الطلب', 'Cancel order')),
                ),
              ),
            ],
            if (order.isConfirmed &&
                order.paymentStatus == PaymentStatus.pending) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: order.serviceId == null || order.id == null
                      ? null
                      : () async {
                          final choice = await showPaymentCheckoutChooser(
                            context,
                            amountLabel:
                                '$amount ${context.t('ج.م', 'EGP')}',
                          );
                          if (choice == null ||
                              choice == PaymentCheckoutChoice.cancel ||
                              !context.mounted) {
                            return;
                          }
                          try {
                            if (choice == PaymentCheckoutChoice.paymob) {
                              await WritingService.instance.payOrder(
                                serviceId: order.serviceId!,
                                orderId: order.id!,
                                amount: amount,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.t(
                                        'تم فتح صفحة Paymob — بعد الدفع ستتحدث الحالة تلقائياً',
                                        'Paymob opened — status updates automatically after payment',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } else {
                              await WritingService.instance
                                  .requestManualPayment(
                                serviceId: order.serviceId!,
                                orderId: order.id!,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.t(
                                        'تم تسجيل طلب تحويل يدوي — تواصل مع الخبير لإتمام التحويل',
                                        'Manual transfer requested — contact the expert to complete payment',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.payment),
                  label: Text(
                    context.t(
                      'ادفع $amount ج.م — إلكتروني أو يدوي',
                      'Pay $amount EGP — online or manual',
                    ),
                  ),
                ),
              ),
            ],
            if (order.isDelivered) ...[
              if (order.deliveryNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.t(
                      'ملاحظات التسليم: ${order.deliveryNote}',
                      'Delivery notes: ${order.deliveryNote}',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: order.serviceId == null || order.id == null
                      ? null
                      : () async {
                          try {
                            await WritingService.instance.confirmDelivery(
                              serviceId: order.serviceId!,
                              orderId: order.id!,
                              rating: 5,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t(
                                      'تم تأكيد الاستلام وإفراج الدفعة',
                                      'Delivery confirmed and payment released',
                                    ),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(context.t('تأكيد الاستلام', 'Confirm delivery')),
                ),
              ),
            ],
            if (order.isPaidHeld)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  PaymentStatus.label(order.paymentStatus),
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
