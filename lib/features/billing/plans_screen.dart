import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import 'app_plans.dart';
import 'subscription_checkout.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('الباقات', 'Plans')),
      ),
      body: StreamBuilder<UserAccount?>(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, snap) {
          final account = snap.data;
          final current = account?.effectiveTier ?? SubscriptionTier.free;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.t(
                  'الرصيد شهري ويتجدد أول كل شهر. لكل مهمة سقف يومي حتى لا يُستهلك الشهر في يوم واحد. '
                  'الدفع بالبطاقة أو المحفظة يُحصَّل على حساب Paymob الخاص بالتطبيق، ثم تُفعَّل الباقة لشهر.',
                  'The balance is monthly and renews on the first of each month. Each task has a daily ceiling so one day cannot spend the month. '
                  'Card or wallet payment is collected on the app Paymob account, then the plan runs for one month.',
                ),
                style: const TextStyle(height: 1.5, color: Color(0xFFB7C3D6)),
              ),
              const SizedBox(height: 16),
              for (final plan in AppPlans.plans) ...[
                _PlanCard(
                  plan: plan,
                  account: account,
                  current: current == plan.id ||
                      (current == 'admin' && plan.id == SubscriptionTier.pro),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                context.t('متاح في كل الباقات', 'Included in every plan'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              for (final item in AppPlans.includedEverywhere)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check, size: 18),
                  title: Text(context.t(item.$1, item.$2)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    required this.account,
  });

  final AppPlan plan;
  final bool current;
  final UserAccount? account;

  @override
  Widget build(BuildContext context) {
    final onDark = current ? Colors.white : null;
    final muted = current ? Colors.white70 : const Color(0xFFB7C3D6);
    return Card(
      color: current ? const Color(0xFF1A237E) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.t(plan.nameAr, plan.nameEn),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: onDark,
                  ),
                ),
                const Spacer(),
                if (plan.priceEgp > 0)
                  Text(
                    context.t('${plan.priceEgp} ج.م / شهر', '${plan.priceEgp} EGP / month'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: current ? const Color(0xFFFBBF24) : null,
                    ),
                  )
                else if (current)
                  Text(
                    context.t('باقتك الحالية', 'Your plan'),
                    style: const TextStyle(color: Color(0xFFFBBF24)),
                  ),
              ],
            ),
            if (current)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.t('باقتك الحالية', 'Your plan'),
                  style: const TextStyle(color: Color(0xFFFBBF24)),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              context.t(plan.summaryAr, plan.summaryEn),
              style: TextStyle(height: 1.4, color: muted),
            ),
            const SizedBox(height: 12),
            for (final item in plan.allowances) ...[
              Text(
                context.t(item.titleAr, item.titleEn),
                style: TextStyle(fontWeight: FontWeight.w700, color: onDark),
              ),
              const SizedBox(height: 2),
              Text(
                item.included
                    ? context.t(
                        '${item.perMonth} في الشهر، وبحد ${item.perDay} في اليوم',
                        '${item.perMonth} a month, up to ${item.perDay} a day',
                      )
                    : context.t('غير مشمول', 'Not included'),
                style: TextStyle(color: onDark),
              ),
              if (item.included)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    context.t(item.countsAr, item.countsEn),
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            if (account != null &&
                !account!.isAdmin &&
                !current &&
                plan.id != SubscriptionTier.free)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  onPressed: () => startSubscriptionPayment(
                    context,
                    tier: plan.id,
                    priceEgp: plan.priceEgp,
                  ),
                  child: Text(
                    context.t(
                      'ادفع ${plan.priceEgp} ج.م',
                      'Pay ${plan.priceEgp} EGP',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
