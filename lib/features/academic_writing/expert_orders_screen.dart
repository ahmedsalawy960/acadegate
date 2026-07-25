import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/escrow/payment_status.dart';
import 'writing_models.dart';
import 'writing_service.dart';

class ExpertOrdersScreen extends StatelessWidget {
  const ExpertOrdersScreen({super.key});

  static const _brandColor = Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('طلبات العملاء', 'Client orders')),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<WritingOrder>>(
        stream: WritingService.instance.expertOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Text(context.t('لا توجد طلبات واردة', 'No incoming orders')),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return _ExpertOrderCard(order: orders[index]);
            },
          );
        },
      ),
    );
  }
}

class _ExpertOrderCard extends StatelessWidget {
  final WritingOrder order;

  const _ExpertOrderCard({required this.order});

  Future<void> _accept(BuildContext context) async {
    final amountController = TextEditingController(
      text: order.amount > 0 ? '${order.amount}' : '500',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('قبول الطلب', 'Accept order')),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ctx.t('المبلغ (ج.م)', 'Amount (EGP)'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('قبول', 'Accept')),
          ),
        ],
      ),
    );
    if (confirmed != true || order.serviceId == null || order.id == null) return;

    try {
      final amount = num.tryParse(amountController.text.trim()) ?? 0;
      await WritingService.instance.expertAcceptOrder(
        serviceId: order.serviceId!,
        orderId: order.id!,
        amount: amount,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('تم قبول الطلب', 'Order accepted'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    if (order.serviceId == null || order.id == null) return;
    try {
      await WritingService.instance.expertRejectOrder(
        serviceId: order.serviceId!,
        orderId: order.id!,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('تم رفض الطلب', 'Order rejected'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deliver(BuildContext context) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('تسليم العمل', 'Deliver work')),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: ctx.t('ملاحظات التسليم', 'Delivery notes'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('تسليم', 'Deliver')),
          ),
        ],
      ),
    );
    if (confirmed != true || order.serviceId == null || order.id == null) return;

    try {
      await WritingService.instance.expertDeliverOrder(
        serviceId: order.serviceId!,
        orderId: order.id!,
        deliveryNote: noteController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('تم التسليم', 'Delivered'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.topic, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${order.userName} • ${order.category}'),
            Text('${context.t('الحالة', 'Status')}: ${order.statusLabel}'),
            if (order.amount > 0)
              Text('${context.t('المبلغ', 'Amount')}: ${order.amount} ${context.t('ج.م', 'EGP')}'),
            if (order.paymentStatus == PaymentStatus.held)
              Text(
                context.t('✓ الدفع محجوز', '✓ Payment held in escrow'),
                style: const TextStyle(color: Colors.green),
              ),
            if (order.isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _accept(context),
                      child: Text(context.t('قبول', 'Accept')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(context),
                      child: Text(context.t('رفض', 'Reject')),
                    ),
                  ),
                ],
              ),
            ],
            if (order.isConfirmed &&
                order.isManualPayment &&
                order.paymentStatus == PaymentStatus.pending) ...[
              const SizedBox(height: 8),
              Text(
                context.t(
                  'المشتري طلب تحويلاً يدوياً — بعد استلام التحويل أكّد هنا',
                  'Buyer requested a manual transfer — confirm here after you receive it',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: order.serviceId == null || order.id == null
                    ? null
                    : () async {
                        try {
                          await WritingService.instance
                              .confirmManualPaymentReceived(
                            serviceId: order.serviceId!,
                            orderId: order.id!,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.t(
                                    'تم تأكيد التحويل وبدء التنفيذ',
                                    'Transfer confirmed — work started',
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
                icon: const Icon(Icons.account_balance_wallet),
                label: Text(
                  context.t('تأكيد استلام التحويل', 'Confirm transfer received'),
                ),
              ),
            ],
            if (order.isConfirmed && order.isPaidHeld) ...[
              const SizedBox(height: 8),
              Text(
                context.t(
                  'الطالب دفع — نفّذ العمل ثم سلّم',
                  'Student paid — complete the work then deliver',
                ),
              ),
            ],
            if (order.isInProgress && order.isPaidHeld) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _deliver(context),
                child: Text(context.t('تسليم للطالب', 'Deliver to student')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
