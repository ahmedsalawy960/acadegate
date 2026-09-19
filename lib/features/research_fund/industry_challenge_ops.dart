import '../../core/escrow/payment_status.dart';

/// Industry challenge lifecycle: deposit first, then protocol, then release/refund.
class IndustryChallengeOps {
  IndustryChallengeOps._();

  static const open = 'open';
  static const awarded = 'awarded';
  static const closed = 'closed';

  static const protocolSubmitted = 'submitted';
  static const protocolAccepted = 'accepted';

  static bool canHoldDeposit({
    required String paymentStatus,
    required String challengeStatus,
  }) {
    return paymentStatus == PaymentStatus.pending &&
        challengeStatus == open;
  }

  static bool canSubmitProtocol({
    required String paymentStatus,
    required String challengeStatus,
    required String companyId,
    required String researcherId,
  }) {
    return paymentStatus == PaymentStatus.held &&
        challengeStatus == open &&
        researcherId.isNotEmpty &&
        researcherId != companyId;
  }

  static bool canAward({
    required String paymentStatus,
    required String challengeStatus,
  }) {
    return paymentStatus == PaymentStatus.held && challengeStatus == open;
  }

  static bool canRelease({
    required String paymentStatus,
    required String challengeStatus,
  }) {
    return paymentStatus == PaymentStatus.held &&
        challengeStatus == awarded;
  }

  static bool canRefund({
    required String paymentStatus,
    required String challengeStatus,
  }) {
    return paymentStatus == PaymentStatus.held &&
        (challengeStatus == open || challengeStatus == awarded);
  }

  static bool canCloseWithoutAward({
    required String paymentStatus,
    required String challengeStatus,
  }) {
    return challengeStatus == open &&
        (paymentStatus == PaymentStatus.pending ||
            paymentStatus == PaymentStatus.refunded);
  }

  static String escrowStepLabelAr(String paymentStatus, String challengeStatus) {
    if (paymentStatus == PaymentStatus.released) return 'أُفرج عن العربون للباحث';
    if (paymentStatus == PaymentStatus.refunded) return 'أُعيد العربون للشركة';
    if (challengeStatus == awarded) return 'رُسّي البروتوكول — العربون ما زال محجوزاً';
    if (paymentStatus == PaymentStatus.held) return 'العربون محجوز — يمكن تقديم بروتوكول';
    return 'بانتظار إيداع العربون';
  }

  static String escrowStepLabelEn(String paymentStatus, String challengeStatus) {
    if (paymentStatus == PaymentStatus.released) {
      return 'Deposit released to the researcher';
    }
    if (paymentStatus == PaymentStatus.refunded) {
      return 'Deposit refunded to the company';
    }
    if (challengeStatus == awarded) {
      return 'Protocol awarded — deposit still held';
    }
    if (paymentStatus == PaymentStatus.held) {
      return 'Deposit held — protocols can be submitted';
    }
    return 'Awaiting deposit';
  }
}
