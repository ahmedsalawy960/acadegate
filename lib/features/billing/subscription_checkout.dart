import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/payments/payment_checkout_chooser.dart';
import '../../core/payments/payment_method.dart';
import '../../core/payments/paymob_payment_service.dart';

/// Charges the plan on the app Paymob account, then the webhook activates it.
Future<void> startSubscriptionPayment(
  BuildContext context, {
  required String tier,
  required int priceEgp,
}) async {
  final choice = await showPaymentCheckoutChooser(
    context,
    amountLabel: context.t('$priceEgp ج.م شهرياً', '$priceEgp EGP / month'),
    includeManual: false,
    escrowHold: false,
  );
  if (choice == null || !choice.isOnline || !context.mounted) return;
  try {
    await PaymobPaymentService.instance.payAndOpen(
      kind: PaymobOrderKind.subscription,
      tier: tier,
      wallet: choice.isWallet,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'بعد نجاح الدفع تُفعَّل الباقة تلقائياً. المبلغ يُحصَّل على حساب Paymob الخاص بالتطبيق.',
            'After a successful payment the plan turns on by itself. The amount is collected on the app Paymob account.',
          ),
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    final raw = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          raw.isEmpty
              ? context.t('تعذر فتح الدفع', 'Could not open payment')
              : raw,
        ),
      ),
    );
  }
}
