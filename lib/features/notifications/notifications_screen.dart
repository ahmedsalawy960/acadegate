import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../auth/auth_guard.dart';
import '../research_fund/my_funded_ideas_screen.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../research_marketplace/research_marketplace_service.dart';
import 'notification_models.dart';
import 'notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _openNotification(
    BuildContext context,
    AppNotification n,
  ) async {
    if (n.id != null && !n.read) {
      NotificationService.instance.markRead(n.id!);
    }

    final isFund = n.type == 'fund_award' ||
        n.contextType == 'research_idea';
    if (!isFund || n.contextId.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final idea = await ResearchMarketplaceService.instance
          .getIdeaById(n.contextId);
      if (!context.mounted) return;
      Navigator.pop(context); // loading
      if (idea == null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyFundedIdeasScreen()),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResearchIdeaMarketplaceDetailScreen(idea: idea),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10nLookup.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(L10nLookup.delete),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteOne(BuildContext context, AppNotification n) async {
    if (n.id == null) return;

    final confirmed = await _confirm(
      context,
      title: L10nLookup.confirmDelete,
      message: L10nLookup.deleteNotificationConfirm(n.title),
    );
    if (!confirmed || !context.mounted) return;

    try {
      await NotificationService.instance.delete(n.id!);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10nLookup.deleteFailed(e))),
      );
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: L10nLookup.confirmDelete,
      message: L10nLookup.deleteAllNotificationsConfirm,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await NotificationService.instance.deleteAll();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10nLookup.deleteFailed(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService.instance.userNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            appBar: AcadeGateAppBar(
              title: Text(L10nLookup.notifications),
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final items = snapshot.data ?? [];
        final hasItems = items.isNotEmpty;

        return Scaffold(
          appBar: AcadeGateAppBar(
            title: Text(L10nLookup.notifications),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            actions: [
              if (hasItems)
                IconButton(
                  tooltip: L10nLookup.deleteAll,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _deleteAll(context),
                ),
              TextButton(
                onPressed: hasItems
                    ? () => NotificationService.instance.markAllRead()
                    : null,
                child: Text(
                  L10nLookup.markAllRead,
                  style: TextStyle(
                    color: hasItems ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ],
          ),
          body: !hasItems
              ? Center(child: Text(L10nLookup.noNotifications))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final n = items[index];
                    return ListTile(
                      leading: Icon(
                        n.read
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: n.read ? Colors.grey : const Color(0xFF1A237E),
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight:
                              n.read ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(n.body),
                      trailing: IconButton(
                        tooltip: L10nLookup.delete,
                        icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                        onPressed: () => _deleteOne(context, n),
                      ),
                      onTap: () => _openNotification(context, n),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Notification icon with badge — for AppBar.
class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          tooltip: L10nLookup.notifications,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () async {
            final loggedIn = await ensureLoggedIn(context);
            if (!loggedIn || !context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
