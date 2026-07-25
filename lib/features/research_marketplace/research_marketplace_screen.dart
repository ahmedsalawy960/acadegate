import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/l10n_lookup.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import 'publish_research_idea_screen.dart';
import 'research_idea_marketplace_detail_screen.dart';

class ResearchMarketplaceScreen extends StatelessWidget {
  const ResearchMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t(
          'سوق الأفكار البحثية',
          'Research ideas marketplace',
        )),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const PublishResearchIdeaScreen(),
            ),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t(
                  'تم إرسال الفكرة للمراجعة — ستظهر بعد الموافقة',
                  'Idea sent for review — it will appear after approval',
                )),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(context.t('نشر فكرة', 'Publish idea')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Text(
              context.t(
                'جهات أكاديمية وصناعية تنشر مشاكل بحثية، والطلاب يقدمون مقترحات ويصوّتون عليها.',
                'Academic and industry partners publish research problems; students submit proposals and vote.',
              ),
              style: const TextStyle(height: 1.4),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AcademicResearchIdea>>(
              stream: AcademicContentService.instance.researchIdeasStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(context.t(
                      'حدث خطأ: ${snapshot.error}',
                      'Error: ${snapshot.error}',
                    )),
                  );
                }

                final ideas = snapshot.data ?? [];
                if (ideas.isEmpty) {
                  return Center(
                    child: Text(context.t(
                      'لا توجد أفكار في السوق حالياً',
                      'No ideas in the marketplace yet',
                    )),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: ideas.length,
                  itemBuilder: (context, index) {
                    final idea = ideas[index];
                    return _MarketIdeaCard(
                      idea: idea,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ResearchIdeaMarketplaceDetailScreen(
                              idea: idea,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketIdeaCard extends StatelessWidget {
  final AcademicResearchIdea idea;
  final VoidCallback onTap;

  const _MarketIdeaCard({
    required this.idea,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      idea.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (idea.funded)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: Chip(
                        avatar: const Icon(Icons.volunteer_activism, size: 14),
                        label: Text(
                          context.t('ممولة', 'Funded'),
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            const Color(0xFFBF360C).withValues(alpha: 0.12),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  _StatusChip(
                    isOpen: idea.isOpen,
                    isClaimed: idea.isClaimed,
                    claimedByName: idea.claimedByName,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                idea.provider,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.thumb_up_alt_outlined,
                    label: context.t(
                      '${idea.votesCount} تصويت',
                      '${idea.votesCount} votes',
                    ),
                  ),
                  _InfoChip(
                    icon: Icons.description_outlined,
                    label: context.t(
                      '${idea.proposalsCount} مقترح',
                      '${idea.proposalsCount} proposals',
                    ),
                  ),
                  if (idea.budget.isNotEmpty)
                    _InfoChip(
                      icon: Icons.payments_outlined,
                      label: idea.budget,
                    ),
                  if (idea.category.isNotEmpty)
                    _InfoChip(
                      icon: Icons.school_outlined,
                      label: L10nLookup.facultyTitleStatic(idea.category),
                    ),
                  if (idea.funded && idea.fundedAmount != null)
                    _InfoChip(
                      icon: Icons.savings_outlined,
                      label:
                          '${idea.fundedAmount} ${idea.fundedCurrency}'.trim(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOpen;
  final bool isClaimed;
  final String claimedByName;

  const _StatusChip({
    required this.isOpen,
    this.isClaimed = false,
    this.claimedByName = '',
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;
    if (isClaimed) {
      bgColor = Colors.blue;
      textColor = Colors.blue[800]!;
      label = context.t('تم اختياره', 'Claimed');
    } else if (isOpen) {
      bgColor = Colors.green;
      textColor = Colors.green[800]!;
      label = context.t('مفتوحة', 'Open');
    } else {
      bgColor = Colors.grey;
      textColor = Colors.grey[700]!;
      label = context.t('مغلقة', 'Closed');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.orange[800]),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
