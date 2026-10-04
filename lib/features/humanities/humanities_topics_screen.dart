import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../auth/user_account_service.dart';
import '../moderation/approval_status.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../research_marketplace/research_ideas_sync_service.dart';
import '../research_marketplace/seed/egypt_research_ideas_seed.dart';
import 'humanities_faculties.dart';
import 'humanities_gap_ideas_seed.dart';

/// موضوعات أدبية/إنسانية: حزمة فجوات محلية + أفكار حيّة من مزامنة AI.
class HumanitiesTopicsScreen extends StatefulWidget {
  final HumanitiesTrack initialTrack;

  const HumanitiesTopicsScreen({
    super.key,
    this.initialTrack = HumanitiesTrack.education,
  });

  @override
  State<HumanitiesTopicsScreen> createState() => _HumanitiesTopicsScreenState();
}

class _HumanitiesTopicsScreenState extends State<HumanitiesTopicsScreen> {
  static const _brand = Color(0xFFEF6C00);

  late HumanitiesTrack _track;
  bool _syncing = false;
  DateTime? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _track = widget.initialTrack;
    _loadSyncMeta();
  }

  Future<void> _loadSyncMeta() async {
    final at =
        await ResearchIdeasSyncService.instance.loadLastHumanitiesSyncAt();
    if (mounted) setState(() => _lastSyncAt = at);
  }

  Set<String> get _facultyFilter {
    switch (_track) {
      case HumanitiesTrack.education:
        return {'Education', 'PhysicalEducation'};
      case HumanitiesTrack.law:
        return {'Law'};
      case HumanitiesTrack.arts:
        return {'Arts', 'FineArts', 'Tourism'};
      case HumanitiesTrack.business:
        return {'Business', 'ProfessionalStudies'};
      case HumanitiesTrack.media:
        return {'MassCommunication'};
      case HumanitiesTrack.other:
        return humanitiesIdeaFacultyIds;
    }
  }

  List<AcademicResearchIdea> _curatedIdeas() {
    final seeds = humanitiesGapIdeasForFaculties(_facultyFilter);
    return [
      for (final seed in seeds) _fromSeed(seed),
    ];
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
      approvalStatus: ApprovalStatus.approved,
      seedSource: 'humanities_gap_pack_2026',
      importSource: 'curated_gap',
    );
  }

  List<AcademicResearchIdea> _mergeIdeas(
    List<AcademicResearchIdea> live,
  ) {
    final curated = _curatedIdeas();
    final filter = _facultyFilter;
    final liveFiltered = live
        .where(
          (e) =>
              e.isPubliclyVisible &&
              filter.contains(e.category) &&
              humanitiesIdeaFacultyIds.contains(e.category),
        )
        .toList();

    // Avoid near-duplicate titles between curated and live.
    final seen = <String>{
      for (final c in curated) c.title.trim().toLowerCase(),
    };
    final uniqueLive = <AcademicResearchIdea>[];
    for (final idea in liveFiltered) {
      final key = idea.title.trim().toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      uniqueLive.add(idea);
    }

    // Live AI ideas first (fresh), then curated gap pack.
    return [...uniqueLive, ...curated];
  }

  Future<void> _runAiSync() async {
    setState(() => _syncing = true);
    try {
      final result = await ResearchIdeasSyncService.instance.syncNow(
        scope: 'humanities',
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
        title: Text(
          context.t('موضوعات أدبية وإنسانية', 'Humanities research topics'),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              color: _brand.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.t(
                    'أفكار حسب القسم وفجوة بحثية. من تفاصيل أي نقطة: فحص تكرار تقريبي، '
                    'مراجع أولية، أسئلة مقترحة، ثم اعتماد/حجز.',
                    'Ideas by department and research gap. From any point details: approx. '
                    'duplication check, starter refs, suggested questions, then adopt/claim.',
                  ),
                  style: const TextStyle(height: 1.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final t in HumanitiesTrack.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(context.t(t.titleAr(), t.titleEn())),
                      selected: _track == t,
                      selectedColor: _brand.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _track = t),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                                'الأفكار المحلية جاهزة · المزامنة الدورية تضيف المزيد',
                                'Curated ideas ready · scheduled sync adds more',
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
                            : const Icon(Icons.sync, size: 18),
                        label: Text(
                          context.t('مزامنة', 'Sync'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AcademicResearchIdea>>(
              stream: AcademicContentService.instance.researchIdeasStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ideas = _mergeIdeas(snapshot.data ?? const []);
                if (ideas.isEmpty) {
                  return Center(
                    child: Text(
                      context.t(
                        'لا توجد أفكار لهذا المسار حالياً',
                        'No ideas for this track yet',
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: ideas.length,
                  itemBuilder: (context, index) {
                    final idea = ideas[index];
                    final isLive = idea.importSource == 'openalex' ||
                        idea.importSource == 'science_rss' ||
                        idea.seedSource.contains('sync');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        title: Text(
                          idea.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                idea.provider,
                                style: TextStyle(
                                  color: const Color(0xFFB7C3D6),
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      L10nLookup.facultyTitleStatic(idea.category),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: isLive
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFFFF3E0),
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isLive
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFF3E2723),
                                    ),
                                    label: Text(
                                      isLive
                                          ? context.t('مزامنة', 'Sync')
                                          : context.t('فجوة موثّقة', 'Documented gap'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResearchIdeaMarketplaceDetailScreen(
                                idea: idea,
                              ),
                            ),
                          );
                        },
                      ),
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
