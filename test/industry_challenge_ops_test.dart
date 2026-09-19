import 'package:acadegate/core/escrow/payment_status.dart';
import 'package:acadegate/features/research_fund/industry_challenge_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protocol submit is blocked until the deposit is held', () {
    expect(
      IndustryChallengeOps.canSubmitProtocol(
        paymentStatus: PaymentStatus.pending,
        challengeStatus: IndustryChallengeOps.open,
        companyId: 'co',
        researcherId: 'res',
      ),
      isFalse,
    );
    expect(
      IndustryChallengeOps.canSubmitProtocol(
        paymentStatus: PaymentStatus.held,
        challengeStatus: IndustryChallengeOps.open,
        companyId: 'co',
        researcherId: 'res',
      ),
      isTrue,
    );
  });

  test('the posting company cannot submit a protocol to itself', () {
    expect(
      IndustryChallengeOps.canSubmitProtocol(
        paymentStatus: PaymentStatus.held,
        challengeStatus: IndustryChallengeOps.open,
        companyId: 'co',
        researcherId: 'co',
      ),
      isFalse,
    );
  });

  test('award and release follow hold then award', () {
    expect(
      IndustryChallengeOps.canAward(
        paymentStatus: PaymentStatus.held,
        challengeStatus: IndustryChallengeOps.open,
      ),
      isTrue,
    );
    expect(
      IndustryChallengeOps.canRelease(
        paymentStatus: PaymentStatus.held,
        challengeStatus: IndustryChallengeOps.open,
      ),
      isFalse,
    );
    expect(
      IndustryChallengeOps.canRelease(
        paymentStatus: PaymentStatus.held,
        challengeStatus: IndustryChallengeOps.awarded,
      ),
      isTrue,
    );
  });

  test('refund is available while held; close without award is not', () {
    expect(
      IndustryChallengeOps.canRefund(
        paymentStatus: PaymentStatus.held,
        challengeStatus: IndustryChallengeOps.open,
      ),
      isTrue,
    );
    expect(
      IndustryChallengeOps.canCloseWithoutAward(
        paymentStatus: PaymentStatus.held,
        challengeStatus: IndustryChallengeOps.open,
      ),
      isFalse,
    );
    expect(
      IndustryChallengeOps.canCloseWithoutAward(
        paymentStatus: PaymentStatus.pending,
        challengeStatus: IndustryChallengeOps.open,
      ),
      isTrue,
    );
  });
}
