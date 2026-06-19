import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'writing_models.dart';
import 'writing_service.dart';

class MyWritingOrdersScreen extends StatelessWidget {
  const MyWritingOrdersScreen({super.key});

  static const _brandColor = Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الكتابة'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('سجّل الدخول لعرض طلباتك'))
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
                            'تعذر تحميل الطلبات',
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
                          'لا توجد طلبات حجز بعد',
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

  @override
  Widget build(BuildContext context) {
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
            Text('${order.category} • ${order.expertName}'),
            Text(
              '${order.academicLevel} • ${order.language}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (order.deadline != null)
              Text(
                'التسليم: ${order.deadline!.year}/${order.deadline!.month}/${order.deadline!.day}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            if (order.addons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: order.addons
                    .map((a) => Chip(label: Text(a, style: const TextStyle(fontSize: 11))))
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
                                const SnackBar(
                                  content: Text('تم إلغاء الطلب'),
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
                  child: const Text('إلغاء الطلب'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
