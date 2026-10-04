import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../auth/user_account_service.dart';
import '../home/section_search_field.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import '../supervisor_metrics/scimago_quartile_service.dart';
import 'admin_journal_form_screen.dart';
import 'journal_format_apply_screen.dart';
import 'journal_guidelines_service.dart';
import 'journal_pick_item.dart';
import 'journal_recommendation_engine.dart';
import 'publish_models.dart';
import 'publish_services.dart';

export 'journal_pick_item.dart';

class JournalSelectionScreen extends StatefulWidget {
  final String manuscriptId;

  const JournalSelectionScreen({super.key, required this.manuscriptId});

  @override
  State<JournalSelectionScreen> createState() => _JournalSelectionScreenState();
}

class _JournalSelectionScreenState extends State<JournalSelectionScreen> {
  static const _brand = Color(0xFF4A148C);

  String _searchQuery = '';
  String? _quartileFilter;
  bool _loadingCatalog = true;
  String? _loadError;

  PublishManuscript? _manuscript;
  AcademicProfile? _profile;
  List<JournalMatch> _recommendations = const [];
  String _matchBasis = '';
  List<PublishJournal> _lastPartners = const [];
  String? _lastQuartileForRecs;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadCatalog(),
      _loadContext(),
    ]);
    if (mounted) _refreshRecommendations(_lastPartners);
  }

  Future<void> _loadContext() async {
    final manuscript =
        await ManuscriptService.instance.getById(widget.manuscriptId);
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;
    setState(() {
      _manuscript = manuscript;
      _profile = profile;
      _matchBasis = _describeBasis(manuscript, profile);
    });
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _loadError = null;
    });
    try {
      await ScimagoQuartileService.instance.ensureLoaded();
      if (!mounted) return;
      setState(() => _loadingCatalog = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _loadError = '$e';
      });
    }
  }

  void _refreshRecommendations(List<PublishJournal> partners) {
    if (_loadingCatalog) return;
    final matches = JournalRecommendationEngine.recommend(
      manuscript: _manuscript,
      profile: _profile,
      partners: partners,
      quartileFilter: _quartileFilter,
      limit: 8,
    );
    _lastPartners = partners;
    _lastQuartileForRecs = _quartileFilter;
    if (!mounted) return;
    setState(() => _recommendations = matches);
  }

  void _ensureRecommendationsFresh(List<PublishJournal> partners) {
    final partnersChanged = !identical(partners, _lastPartners) &&
        (partners.length != _lastPartners.length ||
            !_samePartnerIds(partners, _lastPartners));
    final quartileChanged = _quartileFilter != _lastQuartileForRecs;
    if (partnersChanged || quartileChanged) {
      _refreshRecommendations(partners);
    }
  }

  bool _samePartnerIds(List<PublishJournal> a, List<PublishJournal> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].id ?? a[i].name) != (b[i].id ?? b[i].name)) return false;
    }
    return true;
  }

  String _describeBasis(
    PublishManuscript? manuscript,
    AcademicProfile? profile,
  ) {
    final parts = <String>[];
    final title = manuscript?.title.trim() ?? '';
    if (title.isNotEmpty) {
      parts.add(title.length > 48 ? '${title.substring(0, 48)}…' : title);
    }
    final interest = profile?.researchInterest.trim() ?? '';
    if (interest.isNotEmpty) parts.add(interest);
    final spec = profile?.specialization.trim() ?? '';
    if (spec.isNotEmpty) parts.add(spec);
    return parts.join(' · ');
  }

  List<JournalPickItem> _buildItems(List<PublishJournal> partners) {
    final partnerTitles = partners
        .map((j) => j.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();

    final partnerItems = partners
        .map(JournalPickItem.fromFirebase)
        .where((item) {
          if (_searchQuery.trim().isEmpty) return true;
          return _matchesQuery(item);
        })
        .toList();

    final scimagoItems = ScimagoQuartileService.instance
        .searchCatalog(
          query: _searchQuery,
          quartile: _quartileFilter,
          limit: 300,
        )
        .where(
          (journal) =>
              !partnerTitles.contains(journal.title.trim().toLowerCase()),
        )
        .map(JournalPickItem.fromScimago)
        .toList();

    return [...partnerItems, ...scimagoItems];
  }

  bool _matchesQuery(JournalPickItem item) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack =
        '${item.name} ${item.publisher} ${item.categories} ${item.partnerUniversity ?? ''}'
            .toLowerCase();
    return haystack.contains(q) ||
        q.split(RegExp(r'\s+')).every((token) => haystack.contains(token));
  }

  Future<void> _pickJournal(BuildContext context, JournalPickItem item) async {
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalFormatApplyScreen(
          manuscriptId: widget.manuscriptId,
          journal: item,
        ),
      ),
    );
  }

  Future<void> _openResourceLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _quartileColor(String quartile) {
    return switch (quartile) {
      'Q1' => const Color(0xFF1B5E20),
      'Q2' => const Color(0xFF0D47A1),
      'Q3' => const Color(0xFFE65100),
      'Q4' => Colors.grey,
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('اختيار المجلة', 'Choose journal')),
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
                tooltip: context.t('إضافة مجلة', 'Add journal'),
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminJournalFormScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PublishJournal>>(
        stream: JournalCatalogService.instance.watchApproved(),
        builder: (context, partnerSnapshot) {
          final partners = partnerSnapshot.data ?? [];
          if (!_loadingCatalog) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _ensureRecommendationsFresh(partners);
            });
          }
          final recs = _recommendations;
          final items =
              _loadingCatalog ? <JournalPickItem>[] : _buildItems(partners);
          final showRecs =
              _searchQuery.trim().isEmpty && recs.isNotEmpty && !_loadingCatalog;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SectionSearchField(
                  query: _searchQuery,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onClear: () => setState(() => _searchQuery = ''),
                  hint: context.t(
                    'ابحث باسم المجلة، الناشر، أو التخصص...',
                    'Search by journal, publisher, or field...',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _QuartileChip(
                      label: context.t('الكل', 'All'),
                      selected: _quartileFilter == null,
                      onTap: () {
                        setState(() => _quartileFilter = null);
                        _refreshRecommendations(partners);
                      },
                    ),
                    for (final q in const ['Q1', 'Q2', 'Q3', 'Q4'])
                      _QuartileChip(
                        label: q,
                        selected: _quartileFilter == q,
                        color: _quartileColor(q),
                        onTap: () {
                          setState(() => _quartileFilter = q);
                          _refreshRecommendations(partners);
                        },
                      ),
                  ],
                ),
              ),
              if (_loadingCatalog)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty && !showRecs)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _loadError != null
                                ? context.t(
                                    'تعذّر تحميل كتالوج المجلات',
                                    'Could not load journal catalog',
                                  )
                                : context.t(
                                    'لا توجد مجلات مطابقة',
                                    'No matching journals',
                                  ),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_loadError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: const Color(0xFFB7C3D6)),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _loadCatalog,
                              child: Text(context.t('إعادة المحاولة', 'Retry')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      if (showRecs) ...[
                        _RecommendationsHeader(
                          brand: _brand,
                          count: recs.length,
                          basis: _matchBasis,
                        ),
                        const SizedBox(height: 8),
                        for (final match in recs)
                          _JournalCard(
                            item: match.journal,
                            brand: _brand,
                            quartileColor: _quartileColor,
                            matchScore: match.score,
                            reasons: match.reasons,
                            onTap: () => _pickJournal(context, match.journal),
                            onGuidelines: () => _openResourceLink(
                              JournalGuidelinesService.authorGuidelinesSearchUrl(
                                match.journal.name,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          context.t('كل المجلات', 'All journals'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ] else if (_searchQuery.trim().isEmpty &&
                          recs.isEmpty &&
                          !_loadingCatalog) ...[
                        _EmptyRecommendationsHint(brand: _brand),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        context.t(
                          '${items.length} مجلة — اختر المجلة ثم راجع دليل المؤلفين',
                          '${items.length} journals — pick one then verify author guidelines',
                        ),
                        style: TextStyle(fontSize: 13, color: const Color(0xFFB7C3D6)),
                      ),
                      const SizedBox(height: 8),
                      for (final item in items)
                        _JournalCard(
                          item: item,
                          brand: _brand,
                          quartileColor: _quartileColor,
                          onTap: () => _pickJournal(context, item),
                          onGuidelines: () => _openResourceLink(
                            JournalGuidelinesService.authorGuidelinesSearchUrl(
                              item.name,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecommendationsHeader extends StatelessWidget {
  final Color brand;
  final int count;
  final String basis;

  const _RecommendationsHeader({
    required this.brand,
    required this.count,
    required this.basis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brand.withValues(alpha: 0.12),
            const Color(0xFF00695C).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.recommend, color: Color(0xFFE9D5FF), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(
                    'ترشيحات لك ($count مجلات)',
                    'Recommended for you ($count journals)',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFE9D5FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'بناءً على نقطة بحثك وتخصصك — اختر الأنسب ثم راجع دليل المؤلفين',
              'Based on your research focus and specialization — pick the best fit then check author guidelines',
            ),
            style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          if (basis.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.t('المرجع: $basis', 'Based on: $basis'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyRecommendationsHint extends StatelessWidget {
  final Color brand;

  const _EmptyRecommendationsHint({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber.shade800, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t(
                'لإظهار ترشيحات متعددة: أضف عنواناً/ملخصاً للمخطوطة وأكمل التخصص والاهتمام البحثي في ملفك الأكاديمي.',
                'For multi-journal recommendations: add a manuscript title/abstract and complete specialization + research interest in your academic profile.',
              ),
              style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final JournalPickItem item;
  final Color brand;
  final Color Function(String) quartileColor;
  final VoidCallback onTap;
  final VoidCallback onGuidelines;
  final int? matchScore;
  final List<String>? reasons;

  const _JournalCard({
    required this.item,
    required this.brand,
    required this.quartileColor,
    required this.onTap,
    required this.onGuidelines,
    this.matchScore,
    this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    final isRec = matchScore != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isRec ? 1.5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRec
            ? BorderSide(color: brand.withValues(alpha: 0.35), width: 1.2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isRec)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        context.t(
                          'تطابق $matchScore%',
                          'Match $matchScore%',
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE9D5FF),
                        ),
                      ),
                    ),
                  if (item.isPartner)
                    Chip(
                      label: Text(
                        context.t('شريك', 'Partner'),
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: brand.withValues(alpha: 0.12),
                    )
                  else if (item.quartile.isNotEmpty)
                    Chip(
                      label: Text(
                        item.quartile,
                        style: TextStyle(
                          fontSize: 11,
                          color: quartileColor(item.quartile),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (item.publisher.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.publisher,
                    style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 13),
                  ),
                ),
              if (item.partnerUniversity?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.school_outlined,
                          size: 15, color: const Color(0xFFB7C3D6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.partnerUniversity!,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFB7C3D6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (item.categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    item.categories,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFB7C3D6),
                      height: 1.35,
                    ),
                  ),
                ),
              if (reasons != null && reasons!.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final reason in reasons!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 15, color: brand.withValues(alpha: 0.85)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFB7C3D6),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.sjr != null)
                    Text(
                      'SJR ${item.sjr!.toStringAsFixed(3)}',
                      style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onGuidelines,
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
                    label: Text(
                      context.t('دليل المؤلفين', 'Author guide'),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AcadeGateColors.gold,
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

class _QuartileChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _QuartileChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _JournalSelectionScreenState._brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: chipColor.withValues(alpha: 0.18),
        checkmarkColor: chipColor,
      ),
    );
  }
}
