import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import 'user_role.dart';

/// Main portals after sign-in.
class PortalType {
  PortalType._();

  static const provider = 'provider';
  static const user = 'user';

  static String label(String? portal) => L10nLookup.portalLabelStatic(portal);

  static String description(String? portal) {
    if (portal == provider) {
      return appTr(
        'تاجر، مختبر، كاتب أكاديمي، ناشر أفكار، مشرف يقدّم خدماته',
        'Merchant, lab, academic writer, idea publisher, or supervisor offering services',
      );
    }
    return appTr(
      'طالب، باحث، مشرف يبحث عن خدمات، أو مستهلك للمحتوى',
      'Student, researcher, supervisor seeking services, or content consumer',
    );
  }

  /// أدوار تُقترح لها بوابة مقدم الخدمة عند التسجيل.
  static const providerRoles = {
    UserRole.merchant,
    UserRole.labManager,
    UserRole.ideaPublisher,
  };

  /// أدوار تُقترح لها بوابة المستخدم.
  static const userRoles = {
    UserRole.student,
  };

  /// اقتراح بوابة افتراضية من دور الحساب (قد يكون null للمشرف/المدير).
  static String? suggestedForRole(String? role) {
    if (role == null) return null;
    if (providerRoles.contains(role)) return provider;
    if (userRoles.contains(role)) return user;
    if (role == UserRole.supervisor) return null;
    if (role == UserRole.admin) return null;
    return user;
  }

  static bool isProvider(String? portal) => portal == provider;
  static bool isUser(String? portal) => portal == user;
}
