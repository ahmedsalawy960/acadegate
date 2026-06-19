import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
        const SnackBar(content: Text('تعذر فتح الرابط')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أخبار علمية'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
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
            child: const Text(
              'آخر الإنجازات والأبحاث من مصادر عالمية (Nature، ScienceDaily، Phys.org...) '
              '— تُحدَّث تلقائياً. اضغط على الخبر لقراءته على الموقع الأصلي.',
              style: TextStyle(height: 1.4),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ScienceNewsCategory.labels.entries.map((entry) {
                final selected = _category == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = entry.key),
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
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }

                final all = snapshot.data ?? const [];
                final items = _service.filterByCategory(all, _category);

                if (items.isEmpty) {
                  return const Center(child: Text('لا توجد أخبار في هذا التصنيف'));
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
                    const Chip(
                      label: Text('مختار', style: TextStyle(fontSize: 11)),
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
                    'قراءة المصدر',
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
