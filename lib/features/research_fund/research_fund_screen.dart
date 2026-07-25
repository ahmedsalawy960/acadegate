import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import '../auth/user_account_service.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../research_marketplace/research_marketplace_screen.dart';
import '../research_marketplace/research_marketplace_service.dart';
import 'admin_fund_config_screen.dart';
import 'research_fund_models.dart';

class ResearchFundScreen extends StatelessWidget {
  const ResearchFundScreen({super.key});

  static const _brand = Color(0xFFBF360C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.l10n.serviceFund),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (snapshot.data?.isAdmin != true) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: context.t('إعدادات الصندوق', 'Fund settings'),
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminFundConfigScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<ResearchFundConfig>(
        stream: ResearchFundService.instance.watchConfig(),
        builder: (context, configSnap) {
          final config = configSnap.data ?? const ResearchFundConfig();

          if (!config.isConfigured) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.savings_outlined,
                        size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      context.t(
                        'الصندوق غير مُفعّل بعد',
                        'Fund is not configured yet',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t(
                        'يُفعَّل من مدير النظام مع شركاء الجامعات — بدون بيانات افتراضية',
                        'Enabled by admin with university partners — no default data',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResearchMarketplaceScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.lightbulb_outline),
                      label: Text(context.t(
                        'تصفح سوق الأفكار',
                        'Browse ideas marketplace',
                      )),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _configCard(context, config),
              const SizedBox(height: 12),
              Card(
                color: Colors.amber.withValues(alpha: 0.1),
                child: ListTile(
                  leading: const Icon(Icons.how_to_vote_outlined),
                  title: Text(context.t(
                    'كيف تتأهل الفكرة؟',
                    'How does an idea qualify?',
                  )),
                  subtitle: Text(context.t(
                    'انشر فكرة في السوق → احصل على ≥ ${config.minVotes} تصويت → يراجعها المدير للتمويل (حتى ${config.maxAwardAmount} ${config.currency})',
                    'Publish in marketplace → reach ≥ ${config.minVotes} votes → admin reviews funding (up to ${config.maxAwardAmount} ${config.currency})',
                  )),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResearchMarketplaceScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.t(
                  'أفكار مؤهلة (≥ ${config.minVotes} تصويت)',
                  'Eligible ideas (≥ ${config.minVotes} votes)',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: ResearchFundService.instance
                    .watchEligibleIdeas(config.minVotes),
                builder: (context, ideasSnap) {
                  if (ideasSnap.connectionState == ConnectionState.waiting &&
                      !ideasSnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final ideas = ideasSnap.data ?? [];
                  if (ideas.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(
                              'لا توجد أفكار مؤهلة حالياً — صوّت في السوق لرفع الأفكار',
                              'No eligible ideas yet — vote in the marketplace to raise ideas',
                            ),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ResearchMarketplaceScreen(),
                              ),
                            ),
                            child: Text(context.t(
                              'فتح سوق الأفكار',
                              'Open ideas marketplace',
                            )),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: ideas.map((raw) {
                      final idea = AcademicResearchIdea.fromMap(
                        raw,
                        id: raw['id']?.toString(),
                      );
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _brand.withValues(alpha: 0.12),
                            child: Text(
                              '${idea.votesCount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(idea.title),
                          subtitle: Text(
                            [
                              idea.provider,
                              if (idea.budget.isNotEmpty) idea.budget,
                            ].join(' · '),
                          ),
                          trailing: Chip(
                            label: Text(
                              context.t('مؤهلة', 'Eligible'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor:
                                Colors.amber.withValues(alpha: 0.2),
                            visualDensity: VisualDensity.compact,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ResearchIdeaMarketplaceDetailScreen(
                                idea: idea,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                context.t('تمويلات سابقة', 'Past awards'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<FundAward>>(
                stream: ResearchFundService.instance.watchAwards(),
                builder: (context, awardsSnap) {
                  final awards = awardsSnap.data ?? [];
                  if (awards.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        context.t('لا تمويلات بعد', 'No awards yet'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }
                  return Column(
                    children: awards.map((a) {
                      final date = a.createdAt;
                      final dateLabel = date == null
                          ? ''
                          : '${date.year}/${date.month}/${date.day}';
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.volunteer_activism,
                              color: _brand),
                          title: Text(a.ideaTitle),
                          subtitle: Text(
                            [
                              '${a.amount} ${a.currency}',
                              a.partnerUniversity,
                              if (dateLabel.isNotEmpty) dateLabel,
                            ].join(' · '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${a.votesAtAward} ↑'),
                              Text(
                                context.t(a.status.labelAr, a.status.labelEn),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          onTap: a.ideaId.isEmpty
                              ? null
                              : () async {
                                  final idea =
                                      await ResearchMarketplaceService.instance
                                          .getIdeaById(a.ideaId);
                                  if (!context.mounted) return;
                                  if (idea == null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ResearchMarketplaceScreen(),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ResearchIdeaMarketplaceDetailScreen(
                                        idea: idea,
                                      ),
                                    ),
                                  );
                                },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _configCard(BuildContext context, ResearchFundConfig config) {
    return Card(
      color: _brand.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('صندوق أفكار بحثية', 'Research ideas fund'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (config.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(config.description),
            ],
            const SizedBox(height: 8),
            Text(
              context.t(
                'حد التصويت: ${config.minVotes} · حد التمويل: ${config.maxAwardAmount} ${config.currency}',
                'Vote threshold: ${config.minVotes} · Max award: ${config.maxAwardAmount} ${config.currency}',
              ),
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            if (config.partners.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.t('شركاء جامعات', 'University partners'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...config.partners.map(
                (p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.school_outlined, size: 20),
                  title: Text(p.name),
                  subtitle: p.contactEmail.isNotEmpty
                      ? Text(p.contactEmail)
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
