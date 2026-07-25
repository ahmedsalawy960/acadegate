import '../../core/locale/app_translate.dart';

/// حالة توثيق الهوية الأكاديمية للمشرف.
class VerificationStatus {
  VerificationStatus._();

  static const unverified = 'unverified';
  static const pending = 'pending';
  static const verified = 'verified';
  static const rejected = 'rejected';

  static String label(String status) {
    switch (status) {
      case verified:
        return appTr('موثّق', 'Verified');
      case pending:
        return appTr('قيد التحقق', 'Pending verification');
      case rejected:
        return appTr('مرفوض', 'Rejected');
      default:
        return appTr('غير موثّق', 'Unverified');
    }
  }

  static bool isVerified(String status) => status == verified;
}
