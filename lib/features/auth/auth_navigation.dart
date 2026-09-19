import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_activity_service.dart';
import '../analytics/kpi_analytics_service.dart';
import '../profile/academic_profile_service.dart';
import 'portal_service.dart';

/// تنقل موحّد بعد الدخول/الخروج حتى لا يُدمَّر جذر `_AppRoot`.
///
/// `_AppRoot` (StreamBuilder على userChanges) هو من يعرض Welcome /
/// EmailVerification / PortalGateway — لا تستبدل مسار الجذر أبداً.
class AuthNavigation {
  AuthNavigation._();

  /// بعد نجاح تسجيل الدخول / تسجيل اجتماعي.
  /// يفرّغ الشاشات فوق الجذر فقط؛ `_AppRoot` يحدّث الواجهة من حالة Auth.
  static void goAfterSignIn(
    BuildContext context, {
    String method = 'email',
  }) {
    // Ignore future — audit must not block navigation.
    AdminActivityService.instance.logLogin(method: method);
    KpiAnalyticsService.instance.markActive(force: true);
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// تسجيل خروج ثم الرجوع لجذر التطبيق (StreamBuilder يعرض Welcome).
  static Future<void> signOutToWelcome(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final email = user?.email;
    final name = user?.displayName;

    // Log while still authenticated (rules require auth.uid == event.uid).
    if (uid != null && uid.isNotEmpty) {
      await AdminActivityService.instance.logLogout(
        uid: uid,
        email: email,
        displayName: name,
      );
    }

    AcademicProfileService.instance.clearCache();
    PortalService.clearGuestPortal();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    // أفرغ المسارات فوق الجذر دون استبدال `_AppRoot` بشاشة يتيمة.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
