import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../auth/usage_quota_service.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import 'app_plans.dart';
import 'plans_screen.dart';
import 'subscription_checkout.dart';
import 'subscription_payments_panel.dart';
import 'subscription_request.dart';

/// Where a member sees the current plan, what was used, what remains,
/// and how to start, change, or cancel.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('الاشتراك', 'Subscription')),
      ),
      body: StreamBuilder<UserAccount?>(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, accountSnap) {
          final account = accountSnap.data;
          if (account == null) {
            return Center(
              child: Text(context.t('سجّل الدخول لعرض اشتراكك', 'Sign in to see your subscription')),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CurrentPlanCard(account: account),
              const SizedBox(height: 12),
              _RequestCard(account: account),
              const SizedBox(height: 12),
              SubscriptionPaymentsPanel(uid: account.uid),
              const SizedBox(height: 12),
              _UsageCard(account: account),
              const SizedBox(height: 12),
              const _HowItWorksCard(),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlansScreen()),
                  ),
                  icon: const Icon(Icons.list_alt_outlined),
                  label: Text(context.t('تفاصيل ما تشمله كل باقة', 'What each plan includes')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.account});

  final UserAccount account;

  @override
  Widget build(BuildContext context) {
    final tier = account.effectiveTier;
    final paid = tier == SubscriptionTier.plus || tier == SubscriptionTier.pro;
    final name = account.isAdmin ? 'Admin' : SubscriptionTier.label(tier);
    final expiry = account.subscriptionExpiresAt;
    final status = account.isAdmin
        ? context.t('غير محدودة', 'Unlimited')
        : !paid
            ? context.t('لا يوجد اشتراك مدفوع', 'No paid subscription')
            : expiry == null
                ? context.t('مفعّلة بلا تاريخ انتهاء', 'Active with no end date')
                : context.t(
                    'مفعّلة حتى ${_date(expiry)}',
                    'Active until ${_date(expiry)}',
                  );
    final renewal = account.isAdmin
        ? context.t('لا تُحسب عليك حدود الباقات.', 'Plan limits do not apply.')
        : !paid
            ? context.t(
                'المهام المدفوعة تنتظر تفعيل أساسية أو شاملة.',
                'Paid tasks wait until Plus or Pro is activated.',
              )
            : expiry == null
                ? context.t(
                    'لا يُخصم مبلغ جديد إلا عندما تدفع شهراً آخر.',
                    'Nothing new is charged until you pay another month.',
                  )
                : context.t(
                    'الدفعة تغطي شهراً حتى ${_date(expiry)}. لا يُخصم تجديد تلقائي. للتجديد ادفع الشهر التالي.',
                    'This payment covers one month until ${_date(expiry)}. There is no automatic renewal. Pay the next month to continue.',
                  );

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('باقتك الآن', 'Your plan now'),
            style: const TextStyle(color: AcadeGateColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(status, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(renewal, style: const TextStyle(height: 1.45, color: AcadeGateColors.muted)),
          if (!account.isAdmin) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!paid) ...[
                  _PayButton(
                    tier: SubscriptionTier.plus,
                    label: context.t('ادفع الأساسية', 'Pay for Plus'),
                  ),
                  _PayButton(
                    tier: SubscriptionTier.pro,
                    label: context.t('ادفع الشاملة', 'Pay for Pro'),
                    tonal: true,
                  ),
                ],
                if (paid)
                  _PayButton(
                    tier: tier == SubscriptionTier.plus
                        ? SubscriptionTier.pro
                        : SubscriptionTier.plus,
                    label: tier == SubscriptionTier.plus
                        ? context.t('ادفع للانتقال إلى الشاملة', 'Pay to move to Pro')
                        : context.t('ادفع للانتقال إلى الأساسية', 'Pay to move to Plus'),
                  ),
                if (paid)
                  _PayButton(
                    tier: tier,
                    label: context.t('تجديد شهر', 'Renew one month'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({
    required this.tier,
    required this.label,
    this.tonal = false,
  });

  final String tier;
  final String label;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final price = AppPlans.byId(tier).priceEgp;
    final child = Text('$label · $price ${context.t('ج.م', 'EGP')}');
    void pay() {
      startSubscriptionPayment(
        context,
        tier: tier,
        priceEgp: price,
      );
    }
    if (tonal) {
      return FilledButton.tonal(onPressed: pay, child: child);
    }
    return FilledButton(onPressed: pay, child: child);
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.account});

  final UserAccount account;

  @override
  Widget build(BuildContext context) {
    if (account.isAdmin) return const SizedBox.shrink();
    return StreamBuilder<SubscriptionRequest?>(
      stream: SubscriptionRequests.instance.watchMine(),
      builder: (context, snap) {
        final request = snap.data;
        if (request == null || !request.isPending) return const SizedBox.shrink();
        final action = switch (request.action) {
          'cancel' => context.t('إلغاء الاشتراك', 'Cancel subscription'),
          'change' => context.t(
              'تغيير الباقة إلى ${SubscriptionTier.label(request.tier)}',
              'Change plan to ${SubscriptionTier.label(request.tier)}',
            ),
          _ => context.t(
              'الاشتراك في ${SubscriptionTier.label(request.tier)}',
              'Subscribe to ${SubscriptionTier.label(request.tier)}',
            ),
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('طلب قيد المراجعة', 'Request under review'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(action),
                const SizedBox(height: 4),
                Text(
                  context.t(
                    'الباقة لا تتبدل إلا بعد الموافقة. يمكنك سحب الطلب قبلها.',
                    'The plan changes only after approval. You can withdraw the request before that.',
                  ),
                  style: const TextStyle(color: AcadeGateColors.muted, height: 1.4),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () async {
                      await SubscriptionRequests.instance.withdraw();
                    },
                    child: Text(context.t('سحب الطلب', 'Withdraw request')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.account});

  final UserAccount account;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('استهلاك هذا الشهر', 'Used this month'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            context.t(
              'الرصيد يتجدد في أول كل شهر. السقف اليومي يمنع أن يُستهلك الشهر كله في يوم واحد، ثم يكمل في اليوم التالي.',
              'The balance renews on the first of each month. The daily ceiling stops one day from spending the whole month, then it continues the next day.',
            ),
            style: const TextStyle(color: AcadeGateColors.muted, height: 1.4, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          StreamBuilder<PlanUsageSnapshot>(
            stream: UsageQuotaService.instance.watchPeriod(account: account),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text(
                  context.t('تعذر قراءة الاستهلاك الآن', 'Usage could not be loaded'),
                );
              }
              final meters = snap.data?.meters ?? const <UsageMeter>[];
              if (meters.isEmpty) {
                return const LinearProgressIndicator();
              }
              return Column(
                children: [
                  for (final meter in meters) ...[
                    _MeterTile(meter: meter),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MeterTile extends StatelessWidget {
  const _MeterTile({required this.meter});

  final UsageMeter meter;

  @override
  Widget build(BuildContext context) {
    final fraction = meter.unlimited || meter.monthLimit == 0
        ? 0.0
        : (meter.monthUsed / meter.monthLimit).clamp(0.0, 1.0);
    final monthLine = meter.unlimited
        ? context.t(
            'استُخدم ${meter.monthUsed} · غير محدود',
            'Used ${meter.monthUsed} · unlimited',
          )
        : meter.monthLimit == 0
            ? context.t('غير مشمول في باقتك', 'Not included in your plan')
            : context.t(
                'استُخدم ${meter.monthUsed} من ${meter.monthLimit} · المتبقي ${meter.monthRemaining}',
                'Used ${meter.monthUsed} of ${meter.monthLimit} · ${meter.monthRemaining} left',
              );
    final dayLine = meter.unlimited
        ? context.t('اليوم ${meter.dayUsed}', 'Today ${meter.dayUsed}')
        : meter.dayLimit == 0
            ? ''
            : context.t(
                'اليوم ${meter.dayUsed} من ${meter.dayLimit} · المتبقي اليوم ${meter.dayRemaining}',
                'Today ${meter.dayUsed} of ${meter.dayLimit} · ${meter.dayRemaining} left today',
              );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(meter.titleAr, meter.titleEn),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: meter.monthLimit == 0 ? 0 : fraction,
            minHeight: 8,
            backgroundColor: AcadeGateColors.line,
            color: fraction >= 0.9 ? const Color(0xFFE65100) : AcadeGateColors.gold,
          ),
        ),
        const SizedBox(height: 4),
        Text(monthLine, style: const TextStyle(fontSize: 13)),
        if (dayLine.isNotEmpty)
          Text(
            dayLine,
            style: const TextStyle(fontSize: 12.5, color: AcadeGateColors.muted),
          ),
      ],
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final steps = <(String, String)>[
      (
        'الاشتراك: من حسابي ثم الاشتراك، اختر الباقة وادفع بالبطاقة أو المحفظة. المبلغ يُحصَّل على حساب Paymob الخاص بالتطبيق، وبعد نجاح الدفع تُفعَّل الباقة لشهر.',
        'Subscribe: from Account, then Subscription, choose a plan and pay by card or wallet. The amount is collected on the app Paymob account, and after success the plan runs for one month.',
      ),
      (
        'الاستهلاك: كل سطر أعلاه مهمة. الرقم الأول ما استُخدم هذا الشهر، ثم حد الشهر، ثم المتبقي. السطر الأصغر هو سقف اليوم نفسه.',
        'Usage: each row is one task. The first number is what you used this month, then the monthly limit, then what is left. The smaller line is today’s ceiling.',
      ),
      (
        'التجديد والتغيير: لا يوجد خصم تلقائي. لتجديد نفس الباقة ادفع شهراً آخر ويُضاف إلى تاريخ الانتهاء. للانتقال إلى باقة أخرى ادفع سعرها ويبدأ شهر جديد من يوم الدفع.',
        'Renewal and changes: there is no automatic charge. To renew the same plan, pay another month and it is added to the end date. To move to another plan, pay its price and a new month starts on the payment day.',
      ),
      (
        'التوقف: لا تضغط تجديداً. عند تاريخ الانتهاء تعود الباقة مجانية ولا يُخصم شيء.',
        'Stopping: do not renew. On the end date the plan returns to Free and nothing is charged.',
      ),
      (
        'أين يذهب المبلغ: إلى حساب Paymob المرتبط بالتطبيق، وهو حساب التاجر نفسه المستخدم في المتجر. العملية تظهر في هذه الصفحة تحت المدفوعات.',
        'Where the money goes: to the Paymob account linked to the app, the same merchant account used by the store. The payment appears on this page under Payments.',
      ),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('كيف يعمل الاشتراك', 'How subscription works'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++) ...[
            Text(
              '${i + 1}. ${context.t(steps[i].$1, steps[i].$2)}',
              style: const TextStyle(height: 1.45),
            ),
            if (i != steps.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AcadeGateColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AcadeGateColors.line),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
