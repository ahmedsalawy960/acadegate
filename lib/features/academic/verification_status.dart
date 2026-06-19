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
        return 'موثّق';
      case pending:
        return 'قيد التحقق';
      case rejected:
        return 'مرفوض';
      default:
        return 'غير موثّق';
    }
  }

  static bool isVerified(String status) => status == verified;
}
