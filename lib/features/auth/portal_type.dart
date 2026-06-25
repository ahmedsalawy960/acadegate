import 'user_role.dart';

/// البوابتان الرئيسيتان بعد الدخول للتطبيق.
class PortalType {
  PortalType._();

  static const provider = 'provider';
  static const user = 'user';

  static const labels = <String, String>{
    provider: 'مقدم خدمة',
    user: 'مستخدم البوابة',
  };

  static const descriptions = <String, String>{
    provider:
        'تاجر، مختبر، كاتب أكاديمي، ناشر أفكار، مشرف يقدّم خدماته',
    user: 'طالب، باحث، مشرف يبحث عن خدمات، أو مستهلك للمحتوى',
  };

  static String label(String? portal) =>
      labels[portal] ?? portal ?? 'البوابة';

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
