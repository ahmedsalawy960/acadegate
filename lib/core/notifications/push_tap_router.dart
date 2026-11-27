import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../features/academic/academic_models.dart';
import '../../features/research_marketplace/research_idea_marketplace_detail_screen.dart';
import 'push_notification_bootstrap.dart';

/// توجيه الضغط على إشعارات Push (خارج التطبيق) إلى الشاشة المناسبة.
/// حالياً: تنبيهات الأفكار الجديدة → صفحة تفاصيل الفكرة.
class PushTapRouter {
  PushTapRouter._();

  static GlobalKey<NavigatorState>? _navigatorKey;

  static void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (!PushNotificationBootstrap.supportsPush) return;
    FirebaseMessaging.onMessageOpenedApp.listen(_handle);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handle(message);
    });
  }

  static Future<void> _handle(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString() ?? '';
    final contextId = data['contextId']?.toString() ?? '';
    if (type != 'new_research_idea' || contextId.isEmpty) return;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('research_ideas')
          .doc(contextId)
          .get();
      if (!doc.exists) return;
      final idea = AcademicResearchIdea.fromMap(doc.data()!, id: doc.id);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ResearchIdeaMarketplaceDetailScreen(idea: idea),
        ),
      );
    } catch (_) {
      // فشل الجلب (أوفلاين مثلاً): يفتح التطبيق عاديًا بدون توجيه.
    }
  }
}
