import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account.dart';
import 'subscription_request.dart';

/// Pending subscribe / change / cancel requests for an admin.
class SubscriptionRequestsAdmin extends StatelessWidget {
  const SubscriptionRequestsAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SubscriptionRequest>>(
      stream: SubscriptionRequests.instance.watchPending(),
      builder: (context, snap) {
        final items = snap.data ?? const <SubscriptionRequest>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Card(
            child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      'طلبات الاشتراك (${items.length})',
                      'Subscription requests (${items.length})',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.displayName.isEmpty ? item.email : item.displayName,
                      ),
                      subtitle: Text(_line(context, item)),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: context.t('رفض', 'Reject'),
                            onPressed: () => _resolve(context, item, false),
                            icon: const Icon(Icons.close),
                          ),
                          IconButton(
                            tooltip: context.t('موافقة', 'Approve'),
                            onPressed: () => _resolve(context, item, true),
                            icon: const Icon(Icons.check),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            ),
            ),
          ),
        );
      },
    );
  }

  String _line(BuildContext context, SubscriptionRequest item) {
    final plan = SubscriptionTier.label(item.tier);
    return switch (item.action) {
      'cancel' => context.t('إلغاء · $plan', 'Cancel · $plan'),
      'change' => context.t('تغيير إلى $plan', 'Change to $plan'),
      _ => context.t('اشتراك في $plan', 'Subscribe to $plan'),
    };
  }

  Future<void> _resolve(
    BuildContext context,
    SubscriptionRequest item,
    bool approve,
  ) async {
    try {
      await SubscriptionRequests.instance.resolve(request: item, approve: approve);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? context.t('تمت الموافقة', 'Approved')
                : context.t('تم الرفض', 'Rejected'),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('تعذر تنفيذ الطلب', 'The request could not be completed'))),
      );
    }
  }
}
