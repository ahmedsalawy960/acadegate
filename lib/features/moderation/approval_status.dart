import '../../core/locale/l10n_lookup.dart';

class ApprovalStatus {
  ApprovalStatus._();

  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const suspended = 'suspended';

  static bool isPublic(String? value) {
    if (value == null || value.isEmpty) return true;
    return value == approved;
  }

  static String label(String? value) => L10nLookup.approvalStatusLabel(value);
}
