import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/escrow/payment_status.dart';
import '../../core/theme/acadegate_theme.dart';
import '../../core/locale/locale_extensions.dart';
import 'industry_challenge_models.dart';
import 'industry_challenge_ops.dart';
import 'submit_challenge_protocol_screen.dart';

class IndustryChallengeDetailScreen extends StatelessWidget {
  final String challengeId;
  final IndustryChallenge? initial;

  const IndustryChallengeDetailScreen({
    super.key,
    required this.challengeId,
    this.initial,
  });

  static const _brand = Color(0xFFBF360C);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<IndustryChallenge?>(
      stream: IndustryChallengeService.instance.watchChallenge(challengeId),
      builder: (context, snap) {
        final challenge = snap.data ?? initial;
        return Scaffold(
          appBar: AcadeGateAppBar(
            title: Text(context.t(
              'تحدٍ بعربون مضمون',
              'Escrowed industry challenge',
            )),
            backgroundColor: _brand,
            foregroundColor: Colors.white,
          ),
          body: challenge == null
              ? const Center(child: CircularProgressIndicator())
              : _ChallengeBody(challenge: challenge),
        );
      },
    );
  }
}

class _ChallengeBody extends StatelessWidget {
  final IndustryChallenge challenge;

  const _ChallengeBody({required this.challenge});

  static const _brand = Color(0xFFBF360C);

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String okAr,
    String okEn,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(okAr, okEn))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwner = uid.isNotEmpty && uid == challenge.companyId;
    final canSubmit = IndustryChallengeOps.canSubmitProtocol(
      paymentStatus: challenge.paymentStatus,
      challengeStatus: challenge.status,
      companyId: challenge.companyId,
      researcherId: uid,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          challenge.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          [
            challenge.companyName,
            '${challenge.budgetAmount} ${challenge.currency}',
            if (challenge.deadline != null)
              '${challenge.deadline!.year}/${challenge.deadline!.month}/${challenge.deadline!.day}',
          ].join(' · '),
          style: TextStyle(color: const Color(0xFFB7C3D6)),
        ),
        const SizedBox(height: 12),
        Card(
          color: _brand.withValues(alpha: 0.06),
          child: ListTile(
            leading: Icon(
              challenge.depositHeld ||
                      challenge.paymentStatus == PaymentStatus.released
                  ? Icons.lock_outlined
                  : Icons.lock_open_outlined,
              color: acadegateInk(_brand),
            ),
            title: Text(context.t(
              IndustryChallengeOps.escrowStepLabelAr(
                challenge.paymentStatus,
                challenge.status,
              ),
              IndustryChallengeOps.escrowStepLabelEn(
                challenge.paymentStatus,
                challenge.status,
              ),
            )),
            subtitle: Text(
              '${PaymentStatus.label(challenge.paymentStatus)} · ${challenge.protocolsCount}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.t('المشكلة', 'Problem'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(challenge.problem, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 16),
        Text(
          context.t('معيار القبول', 'Acceptance criteria'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(challenge.acceptanceCriteria, style: const TextStyle(height: 1.45)),
        if (isOwner) ...[
          const SizedBox(height: 20),
          if (IndustryChallengeOps.canHoldDeposit(
            paymentStatus: challenge.paymentStatus,
            challengeStatus: challenge.status,
          ))
            FilledButton.icon(
              onPressed: () => _run(
                context,
                () => IndustryChallengeService.instance
                    .confirmDeposit(challenge),
                'تم حجز العربون — يمكن للباحثين التقديم',
                'Deposit held — researchers can submit',
              ),
              icon: const Icon(Icons.verified_outlined),
              style: FilledButton.styleFrom(backgroundColor: _brand),
              label: Text(context.t(
                'تأكيد إيداع العربون',
                'Confirm deposit held',
              )),
            ),
          if (IndustryChallengeOps.canRelease(
            paymentStatus: challenge.paymentStatus,
            challengeStatus: challenge.status,
          )) ...[
            FilledButton.icon(
              onPressed: () => _run(
                context,
                () => IndustryChallengeService.instance
                    .releaseDeposit(challenge),
                'أُفرج عن العربون للباحث',
                'Deposit released to the researcher',
              ),
              icon: const Icon(Icons.payments_outlined),
              style: FilledButton.styleFrom(backgroundColor: _brand),
              label: Text(context.t(
                'إفراج العربون بعد التسليم',
                'Release deposit after delivery',
              )),
            ),
            const SizedBox(height: 8),
          ],
          if (IndustryChallengeOps.canRefund(
            paymentStatus: challenge.paymentStatus,
            challengeStatus: challenge.status,
          ))
            OutlinedButton.icon(
              onPressed: () => _run(
                context,
                () =>
                    IndustryChallengeService.instance.refundDeposit(challenge),
                'أُعيد العربون',
                'Deposit refunded',
              ),
              icon: const Icon(Icons.replay_outlined),
              label: Text(context.t('رد العربون', 'Refund deposit')),
            ),
        ],
        if (canSubmit) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final sent = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SubmitChallengeProtocolScreen(challenge: challenge),
                ),
              );
              if (sent == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t(
                      'أُرسل البروتوكول',
                      'Protocol sent',
                    )),
                  ),
                );
              }
            },
            icon: const Icon(Icons.science_outlined),
            style: FilledButton.styleFrom(backgroundColor: _brand),
            label: Text(context.t('تقديم بروتوكول', 'Submit protocol')),
          ),
        ],
        if (!isOwner &&
            uid.isNotEmpty &&
            challenge.isOpen &&
            !challenge.depositHeld)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              context.t(
                'التقديم يُفتح بعد أن تحجز الشركة العربون.',
                'Submissions open after the company holds the deposit.',
              ),
              style: TextStyle(color: const Color(0xFFB7C3D6)),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          context.t('البروتوكولات', 'Protocols'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<ChallengeProtocol>>(
          stream: isOwner
              ? IndustryChallengeService.instance
                  .watchProtocols(challenge.id ?? '')
              : IndustryChallengeService.instance
                  .watchMyProtocolOnChallenge(challenge.id ?? ''),
          builder: (context, snap) {
            final rows = snap.data ?? [];
            if (!isOwner && rows.isEmpty) {
              return Text(
                context.t(
                  challenge.protocolsCount == 0
                      ? 'لا بروتوكولات بعد'
                      : '${challenge.protocolsCount} بروتوكول مقدَّم',
                  challenge.protocolsCount == 0
                      ? 'No protocols yet'
                      : '${challenge.protocolsCount} protocol(s) submitted',
                ),
                style: TextStyle(color: const Color(0xFFB7C3D6)),
              );
            }
            if (rows.isEmpty) {
              return Text(
                context.t('لا بروتوكولات بعد', 'No protocols yet'),
                style: TextStyle(color: const Color(0xFFB7C3D6)),
              );
            }
            return Column(
              children: rows
                  .map((p) => _protocolTile(context, challenge, p, isOwner))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _protocolTile(
    BuildContext context,
    IndustryChallenge challenge,
    ChallengeProtocol protocol,
    bool canAward,
  ) {
    final accepted = protocol.status == IndustryChallengeOps.protocolAccepted ||
        protocol.id == challenge.awardedProtocolId;
    return Card(
      child: ListTile(
        title: Text(protocol.researcherName),
        subtitle: Text(protocol.summary, maxLines: 4),
        trailing: accepted
            ? Chip(
                label: Text(context.t('مرسّى', 'Awarded')),
                visualDensity: VisualDensity.compact,
              )
            : (canAward &&
                    IndustryChallengeOps.canAward(
                      paymentStatus: challenge.paymentStatus,
                      challengeStatus: challenge.status,
                    )
                ? TextButton(
                    onPressed: () => _run(
                      context,
                      () => IndustryChallengeService.instance.awardProtocol(
                        challenge: challenge,
                        protocol: protocol,
                      ),
                      'تم اختيار البروتوكول',
                      'Protocol awarded',
                    ),
                    child: Text(context.t('ترسية', 'Award')),
                  )
                : null),
      ),
    );
  }
}
