import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:acadegate/core/widgets/arrow_scroll_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import '../guides/section_guide_catalog.dart';
import '../guides/section_guide_screen.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import 'science_news_feeds.dart';
import 'science_news_models.dart';
import 'science_news_personalizer.dart';
import 'science_news_service.dart';

class ScienceNewsScreen extends StatefulWidget {
  const ScienceNewsScreen({super.key});

  @override
  State<ScienceNewsScreen> createState() => _ScienceNewsScreenState();
}

class _ScienceNewsScreenState extends State<ScienceNewsScreen> {
  final _service = ScienceNewsService.instance;
  Future<List<ScienceNewsItem>>? _newsFuture;
  AcademicProfile? _profile;
  String _category = ScienceNewsCategory.forYou;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNews();
    LocaleService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      if (profile == null || !ScienceNewsPersonalizer.weeklyDigest(
            items: const [],
            profile: profile,
          ).isPersonalized) {
        _category = ScienceNewsCategory.all;
      }
    });
  }

  void _onLocaleChanged() {
    _loadNews(refresh: true);
  }

  void _loadNews({bool refresh = false}) {
    setState(() {
      _newsFuture = _service.fetchLiveNews(forceRefresh: refresh);
    });
  }

  List<ScienceNewsItem> _visibleItems(
    List<ScienceNewsItem> all,
    List<RankedScienceNews> ranked,
  ) {
    if (_category == ScienceNewsCategory.forYou) {
      final mine = ranked.where((r) => r.score > 0).map((r) => r.item).toList();
      if (mine.isNotEmpty) return mine;
      return all;
    }
    return _service.filterByCategory(all, _category);
  }

  Widget _banner(BuildContext context) {
    final focus = ScienceNewsPersonalizer.focusLabel(_profile);
    if (focus.isNotEmpty) {
      return Text(
        context.t(
          'موجز أسبوعي من ملفك الأكاديمي — $focus. '
          'الأخبار نفسها، مرتبة لما تبحثه أنت لا لأخبار المنصة عامة. اضغط الخبر للمصدر.',
          'Weekly digest from your academic profile — $focus. '
          'The same news, ranked for your research, not generic platform headlines. Tap to read the source.',
        ),
        style: const TextStyle(height: 1.4),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(
            'أكمل ملفك الأكاديمي (التخصص والاهتمام البحثي) ليصبح الموجز الأسبوعى لك أنت، لا أخباراً عامة.',
            'Complete your academic profile (specialty and research interest) so the weekly digest is yours, not generic.',
          ),
          style: const TextStyle(height: 1.4),
        ),
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AcademicProfileScreen()),
            );
            await _loadProfile();
          },
          child: Text(context.t('فتح الملف الأكاديمي', 'Open academic profile')),
        ),
      ],
    );
  }

  Widget _digestHeader(BuildContext context, ResearcherNewsDigest digest) {
    if (_category != ScienceNewsCategory.forYou) {
      return const SizedBox(height: 4);
    }
    if (!digest.isPersonalized) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          context.t(
            'بدون ملف أكاديمي نعرض الأخبار كما هي. أضف تخصصك لتصفية الموجز.',
            'Without an academic profile we show the raw feed. Add your specialty to filter the digest.',
          ),
          style: TextStyle(color: Colors.grey[700], height: 1.35),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        context.t(
          'هذا الأسبوع في «${digest.focusLabel}» — ${digest.items.length} خبر يطابق ملفك',
          'This week in «${digest.focusLabel}» — ${digest.items.length} stories matching your file',
        ),
        style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تعذر فتح الرابط', 'Could not open link')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('أخبار علمية', 'Science news')),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          const SectionGuideAppBarButton(
            guideId: SectionGuideCatalog.news,
            accent: Color(0xFF0D47A1),
          ),
          IconButton(
            tooltip: context.t('تحديث', 'Refresh'),
            onPressed: () => _loadNews(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SectionGuideBanner(
              guideId: SectionGuideCatalog.news,
              accent: Color(0xFF0D47A1),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
              ),
            ),
            child: _banner(context),
          ),
          ArrowScrollView(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: ScienceNewsCategory.orderedIds.map((id) {
                final selected = _category == id;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(ScienceNewsCategory.label(id)),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = id),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ScienceNewsItem>>(
              future: _newsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      context.t(
                        'حدث خطأ: ${snapshot.error}',
                        'An error occurred: ${snapshot.error}',
                      ),
                    ),
                  );
                }

                final all = snapshot.data ?? const [];
                final digest = ScienceNewsPersonalizer.weeklyDigest(
                  items: all,
                  profile: _profile,
                );
                final ranked = ScienceNewsPersonalizer.rank(
                  items: all,
                  profile: _profile,
                );
                final items = _visibleItems(all, ranked);

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      context.t(
                        'لا توجد أخبار في هذا التصنيف',
                        'No news in this category',
                      ),
                    ),
                  );
                }

                final matchByTitle = {
                  for (final r in ranked)
                    if (r.matchedTerms.isNotEmpty) r.item.title: r.matchedTerms,
                };

                return RefreshIndicator(
                  onRefresh: () async => _loadNews(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _digestHeader(context, digest);
                      }
                      final item = items[index - 1];
                      return _NewsCard(
                        item: item,
                        why: matchByTitle[item.title],
                        onTap: () => _openUrl(item.url),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final ScienceNewsItem item;
  final VoidCallback onTap;
  final List<String>? why;

  const _NewsCard({required this.item, required this.onTap, this.why});

  @override
  Widget build(BuildContext context) {
    final date = item.publishedAt;
    final dateLabel = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                  Chip(
                    label: Text(
                      ScienceNewsCategory.label(item.category),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  ),
                  if (item.isCurated) ...[
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(
                        context.t('مختار', 'Featured'),
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  const Spacer(),
                  if (dateLabel.isNotEmpty)
                    Text(dateLabel, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
              if (why != null && why!.isNotEmpty) ...[
                Text(
                  context.t(
                    'يطابق ملفك: ${why!.take(3).join(' · ')}',
                    'Matches your file: ${why!.take(3).join(' · ')}',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[800], height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    item.source,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  const Icon(Icons.open_in_new, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    context.t('قراءة المصدر', 'Read source'),
                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
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
