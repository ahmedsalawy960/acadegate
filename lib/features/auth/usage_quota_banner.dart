import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../billing/subscription_screen.dart';
import 'usage_quota_service.dart';
import 'user_account.dart';
import 'user_account_service.dart';

/// Compact remaining AI / Scholar quota for signed-in users.
class UsageQuotaBanner extends StatelessWidget {
  final bool showScholar;
  final bool showGemini;
  final EdgeInsetsGeometry padding;

  const UsageQuotaBanner({
    super.key,
    this.showScholar = true,
    this.showGemini = true,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 0),
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserAccount?>(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, accountSnap) {
        final account = accountSnap.data;
        if (account == null) return const SizedBox.shrink();

        return StreamBuilder<DailyUsageSnapshot?>(
          stream: UsageQuotaService.instance.watchToday(account: account),
          builder: (context, usageSnap) {
            final usage = usageSnap.data;
            if (usage == null) return const SizedBox.shrink();

            final tierLabel = account.isAdmin
                ? 'Admin'
                : SubscriptionTier.label(account.effectiveTier);

            final parts = <String>[];
            if (showGemini) {
              parts.add(
                context.t(
                  'الكتابة ${usage.geminiRemaining}/${usage.geminiLimit}',
                  'Writing ${usage.geminiRemaining}/${usage.geminiLimit}',
                ),
              );
            }
            if (showScholar) {
              parts.add(
                context.t(
                  'جلب المراجع ${usage.scholarRemaining}/${usage.scholarLimit}',
                  'References ${usage.scholarRemaining}/${usage.scholarLimit}',
                ),
              );
            }
            if (parts.isEmpty) return const SizedBox.shrink();

            final low = (showGemini && usage.geminiRemaining <= 15) ||
                (showScholar && usage.scholarRemaining <= 5);

            return Padding(
              padding: padding,
              child: Material(
                color: low
                    ? const Color(0xFF3A2E14)
                    : const Color(0xFF1A2744),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  ),
                  child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.speed_outlined,
                        size: 18,
                        color: low
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFB7C3D6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.t(
                            'هذا الشهر ($tierLabel): ${parts.join(' · ')}',
                            'This month ($tierLabel): ${parts.join(' · ')}',
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: low
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFF4F7FB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
