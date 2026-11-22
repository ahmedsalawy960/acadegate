import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../auth/user_account.dart';

class SubscriptionPaymentsPanel extends StatelessWidget {
  const SubscriptionPaymentsPanel({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AcadeGateColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AcadeGateColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('المدفوعات', 'Payments'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              context.t(
                'كل دفعة ناجحة تُحصَّل على حساب Paymob الخاص بالتطبيق ثم تُفعَّل الباقة.',
                'Each successful payment is collected on the app Paymob account, then the plan starts.',
              ),
              style: const TextStyle(color: AcadeGateColors.muted, height: 1.4, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('subscription_payments')
                  .where('userId', isEqualTo: uid)
                  .limit(8)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(context.t('تعذر قراءة المدفوعات', 'Payments could not be loaded'));
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return Text(
                    context.t('لا توجد مدفوعات بعد', 'No payments yet'),
                    style: const TextStyle(color: AcadeGateColors.muted),
                  );
                }
                final items = [...docs]..sort((a, b) {
                    final am = a.data()['createdAt'];
                    final bm = b.data()['createdAt'];
                    final ad = am is Timestamp ? am.millisecondsSinceEpoch : 0;
                    final bd = bm is Timestamp ? bm.millisecondsSinceEpoch : 0;
                    return bd.compareTo(ad);
                  });
                return Column(
                  children: [
                    for (final doc in items) _row(context, doc.data()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> data) {
    final tier = SubscriptionTier.label(data['tier']?.toString() ?? '');
    final amount = data['amount'];
    final status = data['paymentStatus']?.toString() ?? 'pending';
    final statusLabel = switch (status) {
      'paid' => context.t('تم التحصيل', 'Collected'),
      'failed' => context.t('فشلت', 'Failed'),
      _ => context.t('بانتظار إتمام الدفع', 'Waiting for payment'),
    };
    final created = data['createdAt'];
    final when = created is Timestamp ? _date(created.toDate()) : '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('$tier · $amount ${context.t('ج.م', 'EGP')}'),
          ),
          Text(
            when.isEmpty ? statusLabel : '$statusLabel · $when',
            style: const TextStyle(color: AcadeGateColors.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
