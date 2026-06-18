class ApprovalStatus {
  ApprovalStatus._();

  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const suspended = 'suspended';

  static const labels = <String, String>{
    pending: 'بانتظار المراجعة',
    approved: 'معتمد',
    rejected: 'مرفوض',
    suspended: 'موقوف',
  };

  static bool isPublic(String? value) {
    if (value == null || value.isEmpty) return true;
    return value == approved;
  }

  static String label(String? value) {
    return labels[value] ?? value ?? 'غير محدد';
  }
}
