import 'package:flutter/material.dart';

import '../../core/escrow/payment_status.dart';
import 'writing_models.dart';
import 'writing_service.dart';

class ExpertOrdersScreen extends StatelessWidget {
  const ExpertOrdersScreen({super.key});

  static const _brandColor = Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات العملاء'),
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
            return const Center(child: Text('لا توجد طلبات واردة'));
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
        title: const Text('قبول الطلب'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'المبلغ (ج.م)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('قبول')),
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
          const SnackBar(content: Text('تم قبول الطلب')),
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
          const SnackBar(content: Text('تم رفض الطلب')),
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
        title: const Text('تسليم العمل'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظات التسليم',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسليم')),
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
          const SnackBar(content: Text('تم التسليم')),
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
            Text('الحالة: ${order.statusLabel}'),
            if (order.amount > 0) Text('المبلغ: ${order.amount} ج.م'),
            if (order.paymentStatus == PaymentStatus.held)
              const Text('✓ الدفع محجوز', style: TextStyle(color: Colors.green)),
            if (order.isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _accept(context),
                      child: const Text('قبول'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(context),
                      child: const Text('رفض'),
                    ),
                  ),
                ],
              ),
            ],
            if (order.isConfirmed && order.isPaidHeld) ...[
              const SizedBox(height: 8),
              const Text('الطالب دفع — نفّذ العمل ثم سلّم'),
            ],
            if (order.isInProgress && order.isPaidHeld) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _deliver(context),
                child: const Text('تسليم للطالب'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
