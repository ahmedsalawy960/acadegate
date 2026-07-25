import 'package:flutter/material.dart';

import '../locale/locale_extensions.dart';
import 'payment_method.dart';

/// Bottom sheet: Paymob online vs manual bank/transfer / contact seller.
Future<PaymentCheckoutChoice?> showPaymentCheckoutChooser(
  BuildContext context, {
  required String amountLabel,
}) {
  return showModalBottomSheet<PaymentCheckoutChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.t('اختر طريقة الدفع', 'Choose payment method'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ctx.t(
                  'المبلغ: $amountLabel',
                  'Amount: $amountLabel',
                ),
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.payment, color: Colors.green[800]),
                ),
                title: Text(
                  ctx.t('دفع إلكتروني (Paymob)', 'Online payment (Paymob)'),
                ),
                subtitle: Text(
                  ctx.t(
                    'بطاقة/محفظة عبر صفحة آمنة — يُحجز المبلغ حتى تأكيد الاستلام',
                    'Card/wallet via secure page — held until delivery confirmation',
                  ),
                ),
                onTap: () =>
                    Navigator.pop(ctx, PaymentCheckoutChoice.paymob),
              ),
              const Divider(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade50,
                  child: Icon(Icons.account_balance, color: Colors.orange[800]),
                ),
                title: Text(
                  ctx.t(
                    'تحويل يدوي / تواصل للدفع',
                    'Manual transfer / contact to pay',
                  ),
                ),
                subtitle: Text(
                  ctx.t(
                    'إنشاء طلب والتواصل مع البائع للتحويل البنكي أو إنستاباي',
                    'Create an order and contact the seller for bank/InstaPay transfer',
                  ),
                ),
                onTap: () =>
                    Navigator.pop(ctx, PaymentCheckoutChoice.manual),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, PaymentCheckoutChoice.cancel),
                child: Text(ctx.t('إلغاء', 'Cancel')),
              ),
            ],
          ),
        ),
      );
    },
  );
}
