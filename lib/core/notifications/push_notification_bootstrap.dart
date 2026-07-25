import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/notifications/notification_service.dart';

/// Push (FCM) على Android/iOS فقط.
/// Web و Windows وسطح المكتب: إشعارات داخل التطبيق عبر Firestore فقط.
class PushNotificationBootstrap {
  PushNotificationBootstrap._();

  static bool get supportsPush {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  static Future<void> init() async {
    if (!supportsPush) return;

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
