import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
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
                : account.isProActive
                    ? 'Pro'
                    : 'Free';

            final parts = <String>[];
            if (showGemini) {
              parts.add(
                context.t(
                  'المساعد ${usage.geminiRemaining}/${usage.geminiLimit}',
                  'Assistant ${usage.geminiRemaining}/${usage.geminiLimit}',
                ),
              );
            }
            if (showScholar) {
              parts.add(
                context.t(
                  'Scholar ${usage.scholarRemaining}/${usage.scholarLimit}',
                  'Scholar ${usage.scholarRemaining}/${usage.scholarLimit}',
                ),
              );
            }
            if (parts.isEmpty) return const SizedBox.shrink();

            final low = (showGemini && usage.geminiRemaining <= 2) ||
                (showScholar && usage.scholarRemaining <= 1);

            return Padding(
              padding: padding,
              child: Material(
                color: low
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFE8EAF6),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.speed_outlined,
                        size: 18,
                        color: low
                            ? const Color(0xFFE65100)
                            : const Color(0xFF283593),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.t(
                            'اليوم ($tierLabel): ${parts.join(' · ')}',
                            'Today ($tierLabel): ${parts.join(' · ')}',
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: low
                                ? const Color(0xFFBF360C)
                                : const Color(0xFF1A237E),
                          ),
                        ),
                      ),
                    ],
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
