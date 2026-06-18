import 'package:flutter/material.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import 'publish_research_idea_screen.dart';
import 'research_idea_marketplace_detail_screen.dart';

class ResearchMarketplaceScreen extends StatelessWidget {
  const ResearchMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سوق الأفكار البحثية'),
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
              const SnackBar(
                content: Text('تم إرسال الفكرة للمراجعة — ستظهر بعد الموافقة'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('نشر فكرة'),
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
            child: const Text(
              'جهات أكاديمية وصناعية تنشر مشاكل بحثية، والطلاب يقدمون مقترحات ويصوّتون عليها.',
              style: TextStyle(height: 1.4),
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
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }

                final ideas = snapshot.data ?? [];
                if (ideas.isEmpty) {
                  return const Center(
                    child: Text('لا توجد أفكار في السوق حالياً'),
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
                  _StatusChip(isOpen: idea.isOpen),
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
                    label: '${idea.votesCount} تصويت',
                  ),
                  _InfoChip(
                    icon: Icons.description_outlined,
                    label: '${idea.proposalsCount} مقترح',
                  ),
                  if (idea.budget.isNotEmpty)
                    _InfoChip(
                      icon: Icons.payments_outlined,
                      label: idea.budget,
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

  const _StatusChip({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isOpen ? Colors.green : Colors.grey).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? 'مفتوحة' : 'مغلقة',
        style: TextStyle(
          color: isOpen ? Colors.green[800] : Colors.grey[700],
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
