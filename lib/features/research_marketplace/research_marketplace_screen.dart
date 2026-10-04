import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/l10n_lookup.dart';
import '../guides/section_guide_catalog.dart';
import '../guides/section_guide_screen.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../auth/user_account_service.dart';
import 'publish_research_idea_screen.dart';
import 'research_idea_marketplace_detail_screen.dart';
import 'research_ideas_sync_service.dart';
import 'seed/egypt_research_ideas_seed.dart';

class ResearchMarketplaceScreen extends StatefulWidget {
  const ResearchMarketplaceScreen({super.key});

  @override
  State<ResearchMarketplaceScreen> createState() =>
      _ResearchMarketplaceScreenState();
}

class _ResearchMarketplaceScreenState extends State<ResearchMarketplaceScreen> {
  static const _brand = Color(0xFFEF6C00);

  bool _syncing = false;
  DateTime? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _loadSyncMeta();
  }

  Future<void> _loadSyncMeta() async {
    final at = await ResearchIdeasSyncService.instance.loadLastSyncAt();
    if (mounted) setState(() => _lastSyncAt = at);
  }

  AcademicResearchIdea _fromSeed(SeedResearchIdea seed) {
    return AcademicResearchIdea(
      title: seed.title,
      provider: seed.provider,
      details: seed.details,
      tags: seed.tags,
      budget: seed.budget,
      category: seed.category,
      degreeLevel: 'both',
      status: 'open',
      seedSource: 'egypt_research_ideas_seed',
      importSource: 'curated_marketplace',
    );
  }

  List<AcademicResearchIdea> _mergeIdeas(List<AcademicResearchIdea> live) {
    final public = live.where((e) => e.isPubliclyVisible).toList();
    final curated = [for (final s in egyptResearchIdeasSeed) _fromSeed(s)];
    if (public.isEmpty) return curated;

    final seen = <String>{
      for (final i in public) i.title.trim().toLowerCase(),
    };
    final extras = <AcademicResearchIdea>[];
    for (final c in curated) {
      final key = c.title.trim().toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      extras.add(c);
    }
    // Live/synced first, then curated pack fillers.
    return [...public, ...extras];
  }

  Future<void> _runAiSync() async {
    setState(() => _syncing = true);
    try {
      final result = await ResearchIdeasSyncService.instance.syncNow(
        scope: 'all',
      );
      await _loadSyncMeta();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تمت المزامنة: +${result.imported} جديدة · ${result.updated} محدّثة',
              'Synced: +${result.imported} new · ${result.updated} updated',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

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
        actions: [
          SectionGuideAppBarButton(
            guideId: SectionGuideCatalog.ideas,
            accent: Colors.orange.shade800,
          ),
        ],
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SectionGuideBanner(
              guideId: SectionGuideCatalog.ideas,
              accent: Color(0xFFEF6C00),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Text(
              context.t(
                'جهات أكاديمية وصناعية تنشر مشاكل بحثية. افتح أي نقطة لجلب دراسات سابقة وفحص التكرار واعتمادها (يشمل Scholar — بدون إلزام DOI).',
                'Partners publish research problems. Open any idea for prior studies, duplication check & adopt (incl. Scholar — DOI not required).',
              ),
              style: const TextStyle(height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: StreamBuilder(
              stream: UserAccountService.instance.watchCurrentAccount(),
              builder: (context, snap) {
                final isAdmin = snap.data?.isAdmin == true;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lastSyncAt == null
                            ? context.t(
                                'الحزمة المحلية جاهزة · المزامنة تضيف نقاطاً جديدة من OpenAlex والأخبار',
                                'Curated pack ready · sync adds new points from OpenAlex and news',
                              )
                            : context.t(
                                'آخر مزامنة: ${_lastSyncAt!.toLocal().toString().split('.').first}',
                                'Last sync: ${_lastSyncAt!.toLocal().toString().split('.').first}',
                              ),
                        style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6)),
                      ),
                    ),
                    if (isAdmin)
                      FilledButton.tonalIcon(
                        onPressed: _syncing ? null : _runAiSync,
                        icon: _syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_sync, size: 18),
                        label: Text(context.t('مزامنة', 'Sync')),
                        style: FilledButton.styleFrom(
                          foregroundColor: _brand,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AcademicResearchIdea>>(
              stream: AcademicContentService.instance.researchIdeasStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(context.t(
                      'حدث خطأ: ${snapshot.error}',
                      'Error: ${snapshot.error}',
                    )),
                  );
                }

                final ideas = _mergeIdeas(snapshot.data ?? const []);
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
                style: TextStyle(color: const Color(0xFFB7C3D6)),
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
                  if (idea.degreeLevel.isNotEmpty)
                    _InfoChip(
                      icon: Icons.workspace_premium_outlined,
                      label: idea.degreeLevel == 'phd'
                          ? context.t('دكتوراه', 'PhD')
                          : idea.degreeLevel == 'masters'
                              ? context.t('ماجستير', 'Master\'s')
                              : context.t('ماجستير/دكتوراه', 'MSc/PhD'),
                    ),
                  if (idea.isSyncedImport)
                    _InfoChip(
                      icon: Icons.cloud_sync_outlined,
                      label: context.t('مزامنة', 'Synced'),
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
      textColor = const Color(0xFF93C5FD);
      label = context.t('تم اختياره', 'Claimed');
    } else if (isOpen) {
      bgColor = Colors.green;
      textColor = Colors.green[800]!;
      label = context.t('مفتوحة', 'Open');
    } else {
      bgColor = Colors.grey;
      textColor = const Color(0xFFB7C3D6);
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
