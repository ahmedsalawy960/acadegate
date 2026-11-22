import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account.dart';
import 'subscription_request.dart';

Future<void> confirmSubscriptionRequest(
  BuildContext context, {
  required UserAccount account,
  required String action,
  required String tier,
}) async {
  final title = switch (action) {
    'cancel' => context.t('إلغاء الاشتراك؟', 'Cancel the subscription?'),
    'change' => context.t(
        'طلب الانتقال إلى ${SubscriptionTier.label(tier)}؟',
        'Request a move to ${SubscriptionTier.label(tier)}?',
      ),
    _ => context.t(
        'طلب الاشتراك في ${SubscriptionTier.label(tier)}؟',
        'Request ${SubscriptionTier.label(tier)}?',
      ),
  };
  final body = switch (action) {
    'cancel' => context.t(
        'يصل الطلب إلى الإدارة. لا ينقطع استخدامك الآن. الباقة تتوقف في تاريخ انتهائها، أو نهاية هذا الشهر إن لم يكن لها تاريخ.',
        'The request goes to an admin. Your access does not stop now. The plan ends on its end date, or at the end of this month if it has none.',
      ),
    _ => context.t(
        'لا يُخصم مبلغ الآن. بعد الموافقة تُفعَّل الباقة حتى نهاية الشهر التالي، ويظهر الاستهلاك في هذه الصفحة.',
        'Nothing is charged now. After approval the plan runs through the end of next month, and usage shows on this page.',
      ),
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.t('تراجع', 'Back')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.t('إرسال الطلب', 'Send request')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await SubscriptionRequests.instance.submit(
      account: account,
      action: action,
      tier: tier,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('وصل الطلب وهو قيد المراجعة', 'The request was sent and is under review'),
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تعذر إرسال الطلب', 'The request could not be sent')),
      ),
    );
  }
}
