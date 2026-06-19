import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/notifications/notification_service.dart';

/// تهيئة FCM — على Windows قد لا تكون مدعومة بالكامل؛ نستخدم الإشعارات داخل التطبيق.
class PushNotificationBootstrap {
  PushNotificationBootstrap._();

  static Future<void> init() async {
    if (kIsWeb) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await NotificationService.instance.saveFcmToken(token);
      }
      messaging.onTokenRefresh.listen(
        NotificationService.instance.saveFcmToken,
      );
    } catch (e) {
      debugPrint('FCM init skipped: $e');
    }
  }
}
