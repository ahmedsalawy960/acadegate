import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:acadegate/core/widgets/arrow_scroll_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import 'science_news_feeds.dart';
import 'science_news_models.dart';
import 'science_news_service.dart';

class ScienceNewsScreen extends StatefulWidget {
  const ScienceNewsScreen({super.key});

  @override
  State<ScienceNewsScreen> createState() => _ScienceNewsScreenState();
}

class _ScienceNewsScreenState extends State<ScienceNewsScreen> {
  final _service = ScienceNewsService.instance;
  Future<List<ScienceNewsItem>>? _newsFuture;
  String _category = ScienceNewsCategory.all;

  @override
  void initState() {
    super.initState();
    _loadNews();
    LocaleService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    _loadNews(refresh: true);
  }

  void _loadNews({bool refresh = false}) {
    setState(() {
      _newsFuture = _service.fetchLiveNews(forceRefresh: refresh);
    });
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
            child: Text(
              context.t(
                'أخبار علمية من مجلات وبوابات متخصصة (Nature، ScienceDaily، Phys.org، NASA...) '
                '— تُجلب عبر السحابة. بالعربية: دويتشه فيله + مصادر علمية عالمية. '
                'اضغط على الخبر لقراءته في المصدر.',
                'Scientific news from journals and portals (Nature, ScienceDaily, Phys.org, NASA...) '
                '— fetched via cloud, sorted by field. Tap to read at the source.',
              ),
              style: const TextStyle(height: 1.4),
            ),
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
                final items = _service.filterByCategory(all, _category);

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

                return RefreshIndicator(
                  onRefresh: () async => _loadNews(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _NewsCard(
                        item: item,
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

  const _NewsCard({required this.item, required this.onTap});

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
