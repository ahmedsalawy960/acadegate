import 'package:firebase_auth/firebase_auth.dart';
import 'portal_type.dart';
import 'user_account_service.dart';

/// يحفظ البوابة النشطة: Firestore للمسجّلين، ذاكرة للضيف.
class PortalService {
  PortalService._();

  static final PortalService instance = PortalService._();

  static String? _guestPortal;

  Future<String?> getActivePortal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final account = await UserAccountService.instance.loadCurrentAccount();
      final portal = account?.activePortal;
      if (portal == PortalType.provider || portal == PortalType.user) {
        return portal;
      }
      return null;
    }
    return _guestPortal;
  }

  Future<void> setActivePortal(String portal) async {
    if (portal != PortalType.provider && portal != PortalType.user) {
      throw ArgumentError('بوابة غير معروفة: $portal');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await UserAccountService.instance.setActivePortal(portal);
    } else {
      _guestPortal = portal;
    }
  }

  Future<void> clearActivePortal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await UserAccountService.instance.clearActivePortal();
    } else {
      _guestPortal = null;
    }
  }

  static void clearGuestPortal() => _guestPortal = null;
}
