import '../moderation/approval_status.dart';
import 'user_account.dart';
import 'user_account_service.dart';

/// Gates provider publishing by admin approval of `provider_applications`.
class ProviderPublishGate {
  ProviderPublishGate._();

  static bool isProviderRole(String? role) =>
      UserAccountService.isReviewableProviderRole(role ?? '');

  /// Admins always approved. Non-providers (students) are not gated.
  /// Missing status on legacy provider accounts = approved (grandfathered).
  static String statusOf(UserAccount? account) {
    if (account == null) return ApprovalStatus.pending;
    if (account.isAdmin) return ApprovalStatus.approved;
    if (!isProviderRole(account.role)) return ApprovalStatus.approved;
    final raw = (account.providerApprovalStatus ?? '').trim();
    if (raw.isEmpty) return ApprovalStatus.approved;
    return raw;
  }

  static bool isApproved(UserAccount? account) =>
      statusOf(account) == ApprovalStatus.approved;

  static bool isPending(UserAccount? account) =>
      statusOf(account) == ApprovalStatus.pending;

  static bool isRejected(UserAccount? account) =>
      statusOf(account) == ApprovalStatus.rejected;

  /// Rejected providers cannot create products/labs/profiles/services.
  static bool canSubmitContent(UserAccount? account) => !isRejected(account);

  /// Only approved providers get public/auto-approved listings.
  static bool canPublishPublic(UserAccount? account) => isApproved(account);

  /// Status to write on new content from this provider.
  static String contentApprovalStatus(UserAccount? account) {
    if (account?.isAdmin == true) return ApprovalStatus.approved;
    if (isApproved(account)) return ApprovalStatus.approved;
    return ApprovalStatus.pending;
  }

  static String blockMessageAr(UserAccount? account) {
    if (isRejected(account)) {
      final reason = (account?.providerRejectionReason ?? '').trim();
      if (reason.isNotEmpty) {
        return 'تم رفض حساب مقدم الخدمة: $reason\nيمكنك إعادة تقديم الطلب من بوابة المقدم.';
      }
      return 'تم رفض حساب مقدم الخدمة. يمكنك إعادة تقديم الطلب من بوابة المقدم بعد تصحيح البيانات.';
    }
    return 'حسابك قيد مراجعة الإدارة. يمكنك المتابعة بعد القبول.';
  }

  static String blockMessageEn(UserAccount? account) {
    if (isRejected(account)) {
      final reason = (account?.providerRejectionReason ?? '').trim();
      if (reason.isNotEmpty) {
        return 'Your provider account was rejected: $reason\nYou can re-apply from the provider portal.';
      }
      return 'Your provider account was rejected. Re-apply from the provider portal after fixing your details.';
    }
    return 'Your account is pending admin review. You can continue after approval.';
  }
}
