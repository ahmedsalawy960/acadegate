import 'package:flutter/material.dart';

import '../auth/auth_guard.dart';
import 'notification_models.dart';
import 'notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => NotificationService.instance.markAllRead(),
            child: const Text('قراءة الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.instance.userNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('لا إشعارات'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final n = items[index];
              return ListTile(
                leading: Icon(
                  n.read ? Icons.notifications_none : Icons.notifications_active,
                  color: n.read ? Colors.grey : const Color(0xFF1A237E),
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(n.body),
                onTap: () {
                  if (n.id != null && !n.read) {
                    NotificationService.instance.markRead(n.id!);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// أيقونة إشعارات مع عدّاد — للـ AppBar.
class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'الإشعارات',
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
