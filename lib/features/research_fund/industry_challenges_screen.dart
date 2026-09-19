import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/escrow/payment_status.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import 'create_industry_challenge_screen.dart';
import 'industry_challenge_detail_screen.dart';
import 'industry_challenge_models.dart';
import 'industry_challenge_ops.dart';

class IndustryChallengesScreen extends StatelessWidget {
  const IndustryChallengesScreen({super.key});

  static const brand = Color(0xFFBF360C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t(
          'تحديات الصناعة بعربون مضمون',
          'Industry challenges with escrow',
        )),
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: StreamBuilder(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, snap) {
          if (!UserRole.canPostIndustryChallenge(snap.data?.role)) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateIndustryChallengeScreen(),
                ),
              );
              if (created == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t(
                      'نُشر التحدي — أكد إيداع العربون لفتح التقديم',
                      'Challenge posted — confirm the deposit to open submissions',
                    )),
                  ),
                );
              }
            },
            backgroundColor: brand,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(context.t('نشر تحدٍ', 'Post challenge')),
          );
        },
      ),
      body: StreamBuilder<List<IndustryChallenge>>(
        stream: IndustryChallengeService.instance.watchChallenges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.t(
                    'لا تحديات بعد. الشركة تنشر المشكلة وتحجز العربون قبل أي بروتوكول.',
                    'No challenges yet. A company posts the problem and holds the deposit before any protocol.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], height: 1.45),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Card(
                  color: brand.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      context.t(
                        'ResearchGate شبكة بلا عقد. هنا العربون يُحبس أولاً، ثم يقدّم الباحث بروتوكولاً، ثم يُفرَج أو يُرد حسب معيار القبول.',
                        'ResearchGate is a network without a contract. Here the deposit is held first, then a researcher submits a protocol, then funds are released or refunded against the acceptance criteria.',
                      ),
                      style: const TextStyle(height: 1.45),
                    ),
                  ),
                );
              }
              return IndustryChallengeTile(challenge: items[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class IndustryChallengeTile extends StatelessWidget {
  final IndustryChallenge challenge;

  const IndustryChallengeTile({super.key, required this.challenge});

  static const _brand = Color(0xFFBF360C);

  @override
  Widget build(BuildContext context) {
    final held = challenge.depositHeld ||
        challenge.paymentStatus == PaymentStatus.released;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _brand.withValues(alpha: 0.12),
          child: Icon(
            held ? Icons.lock_outlined : Icons.factory_outlined,
            color: _brand,
            size: 20,
          ),
        ),
        title: Text(challenge.title),
        subtitle: Text(
          [
            challenge.companyName,
            '${challenge.budgetAmount} ${challenge.currency}',
            context.t(
              IndustryChallengeOps.escrowStepLabelAr(
                challenge.paymentStatus,
                challenge.status,
              ),
              IndustryChallengeOps.escrowStepLabelEn(
                challenge.paymentStatus,
                challenge.status,
              ),
            ),
          ].join(' · '),
          maxLines: 2,
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: challenge.id == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IndustryChallengeDetailScreen(
                      challengeId: challenge.id!,
                      initial: challenge,
                    ),
                  ),
                ),
      ),
    );
  }
}

class IndustryChallengesFundItem extends StatelessWidget {
  const IndustryChallengesFundItem({super.key});

  static const _brand = Color(0xFFBF360C);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: _brand.withValues(alpha: 0.08),
          child: ListTile(
            leading: const Icon(Icons.factory_outlined, color: _brand),
            title: Text(
              context.t(
                'تحديات الصناعة بعربون مضمون',
                'Industry challenges with escrow',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(context.t(
              'شركة تنشر مشكلة وتحجز العربون مسبقاً — الباحث يقدّم بروتوكولاً بعقد، لا بمنشور على شبكة.',
              'A company posts a problem and holds the deposit first — the researcher submits a protocol under escrow, not a social post.',
            )),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const IndustryChallengesScreen(),
              ),
            ),
          ),
        ),
        StreamBuilder<List<IndustryChallenge>>(
          stream: IndustryChallengeService.instance.watchChallenges(),
          builder: (context, snap) {
            final items = (snap.data ?? []).take(3).toList();
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const IndustryChallengesScreen(),
                    ),
                  ),
                  child: Text(context.t(
                    'فتح لوحة التحديات',
                    'Open challenges board',
                  )),
                ),
              );
            }
            return Column(
              children: [
                ...items.map((c) => IndustryChallengeTile(challenge: c)),
                if ((snap.data ?? []).length > 3)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IndustryChallengesScreen(),
                      ),
                    ),
                    child: Text(context.t('عرض كل التحديات', 'See all challenges')),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
