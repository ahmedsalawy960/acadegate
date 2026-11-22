import 'package:flutter/material.dart';

import '../locale/locale_extensions.dart';
import 'payment_method.dart';

/// Bottom sheet: Paymob online vs manual bank/transfer / contact seller.
Future<PaymentCheckoutChoice?> showPaymentCheckoutChooser(
  BuildContext context, {
  required String amountLabel,
  bool includeManual = true,
  bool escrowHold = true,
}) {
  return showModalBottomSheet<PaymentCheckoutChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
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
                style: TextStyle(color: const Color(0xFFB7C3D6)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.payment, color: Colors.green[800]),
                ),
                title: Text(
                  ctx.t('بطاقة بنكية', 'Bank card'),
                ),
                subtitle: Text(
                  ctx.t(
                    escrowHold
                        ? 'فيزا / ماستركارد / ميزة عبر صفحة Paymob الآمنة — يُحجز المبلغ حتى تأكيد الاستلام'
                        : 'فيزا / ماستركارد / ميزة. المبلغ يُحصَّل على حساب Paymob الخاص بالتطبيق',
                    escrowHold
                        ? 'Visa / Mastercard / Meeza via secure Paymob page — held until delivery confirmation'
                        : 'Visa / Mastercard / Meeza. The amount is collected on the app Paymob account',
                  ),
                ),
                onTap: () =>
                    Navigator.pop(ctx, PaymentCheckoutChoice.paymob),
              ),
              const Divider(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.red[800],
                  ),
                ),
                title: Text(
                  ctx.t('محفظة إلكترونية', 'Mobile wallet'),
                ),
                subtitle: Text(
                  ctx.t(
                    escrowHold
                        ? 'فودافون كاش / اتصالات كاش / أورنج كاش / WE Pay — يُحجز المبلغ حتى تأكيد الاستلام'
                        : 'فودافون كاش / اتصالات كاش / أورنج كاش / WE Pay. المبلغ يُحصَّل على حساب Paymob الخاص بالتطبيق',
                    escrowHold
                        ? 'Vodafone Cash / Etisalat Cash / Orange Cash / WE Pay — held until delivery confirmation'
                        : 'Vodafone Cash / Etisalat Cash / Orange Cash / WE Pay. Collected on the app Paymob account',
                  ),
                ),
                onTap: () =>
                    Navigator.pop(ctx, PaymentCheckoutChoice.wallet),
              ),
              if (includeManual) ...[
              const Divider(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF3A2E14),
                  child: const Icon(Icons.account_balance, color: Color(0xFFFBBF24)),
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
              ],
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
