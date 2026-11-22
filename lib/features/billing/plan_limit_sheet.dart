import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'subscription_screen.dart';

/// Shown when a paid tool's balance or daily plan limit is used up.
Future<void> showPlanLimitSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      void openPlans() {
        Navigator.pop(ctx);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }

      Widget action(IconData icon, String ar, String en) => ListTile(
            leading: Icon(icon),
            title: Text(ctx.t(ar, en)),
            trailing: const Icon(Icons.chevron_left),
            onTap: openPlans,
          );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text(
                  ctx.t(
                    'انتهى حد باقتك الحالية. اختر كيف تريد المتابعة.',
                    'Your current plan limit is used up. Choose how to continue.',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              action(Icons.verified_outlined, 'تفعيل الاشتراك', 'Activate a subscription'),
              action(Icons.tune, 'تعديل الباقة', 'Adjust plan'),
              action(Icons.add_chart_outlined, 'زيادة حد الباقة', 'Raise the plan limit'),
            ],
          ),
        ),
      );
    },
  );
}
