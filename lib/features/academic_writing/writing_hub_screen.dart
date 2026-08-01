import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/category_visual.dart';
import '../ai_advisor/ai_advisor_screen.dart';
import '../data_analysis/statistical_assumptions_screen.dart';
import '../home/home_search_utils.dart';
import '../home/section_search_field.dart';
import '../viva_simulator/viva_screen.dart';
import 'my_writing_orders_screen.dart';
import 'publish_writing_service_screen.dart';
import 'writer_match_screen.dart';
import 'writing_categories.dart';
import 'writing_expert_list_screen.dart';

class WritingHubScreen extends StatefulWidget {
  const WritingHubScreen({super.key});

  @override
  State<WritingHubScreen> createState() => _WritingHubScreenState();
}

class _WritingHubScreenState extends State<WritingHubScreen> {
  static const _brandColor = Color(0xFF5D4037);

  String _searchQuery = '';

  bool _showCompanionTools(String query) {
    if (query.trim().isEmpty) return true;
    return homeSearchMatches(query, [
      'مساعد',
      'ذكاء',
      'مناقشة',
      'viva',
      'إحصاء',
      'SPSS',
      'ai',
      'advisor',
    ]);
  }

  bool _showStatsWizard(String query) {
    if (query.trim().isEmpty) return true;
    return homeSearchMatches(query, [
      'معالج الافتراضات الإحصائية',
      'Statistical assumptions wizard',
      'SPSS',
      'R',
      'تطبيع',
      'افتراضات',
      'احصاء',
      'statistics',
      'normality',
      'power',
    ]);
  }

  List<WritingCategory> get _filteredCategories {
    if (_searchQuery.trim().isEmpty) return writingCategories;
    return writingCategories
        .where(
          (category) => homeSearchMatches(_searchQuery, [
            category.localizedTitle,
            category.localizedSubtitle,
            category.title,
            category.subtitle,
            category.id,
          ]),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _filteredCategories;
    final showStats = _showStatsWizard(_searchQuery);
    final showTools = _showCompanionTools(_searchQuery);
    final isFiltering = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('خدمات الكتابة الأكاديمية', 'Academic writing services')),
        centerTitle: true,
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('طلباتي', 'My orders'),
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyWritingOrdersScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SectionSearchField(
                  query: _searchQuery,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onClear: () => setState(() => _searchQuery = ''),
                  hint: context.t(
                    'ابحث عن نوع خدمة: رسائل، إحصاء، مراجعة...',
                    'Search service type: thesis, statistics, review...',
                  ),
                ),
                const SizedBox(height: 16),
                if (!isFiltering) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _brandColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: _brandColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _brandColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.groups_3_outlined,
                            color: _brandColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.t(
                              'كتابة بشرية متخصصة — ليست ذكاء اصطناعي. '
                              'اختر الخدمة، حدّد متطلباتك، واحجز مع خبير.',
                              'Specialist human writing — not AI. '
                              'Choose a service, set your requirements, and book an expert.',
                            ),
                            style: const TextStyle(height: 1.4, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (showTools) ...[
                  Text(
                    context.t(
                      'أدوات مساعدة بجانب الكاتب',
                      'Companion tools alongside a writer',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      'ليست بديلاً عن الكاتب — استخدمها قبل أو أثناء الطلب',
                      'Not a substitute for a writer — use before or during your order',
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  _CompanionToolCard(
                    icon: Icons.psychology_alt_outlined,
                    color: const Color(0xFF4527A0),
                    title: context.t('راجع بالذكاء', 'Review with AI'),
                    subtitle: context.t(
                      'المساعد الأكاديمي — مسودة وملاحظات',
                      'AI advisor — draft & feedback',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AiAdvisorScreen()),
                    ),
                  ),
                  _CompanionToolCard(
                    icon: Icons.record_voice_over_outlined,
                    color: const Color(0xFFBF360C),
                    title: context.t('تمرّن للمناقشة', 'Practice viva'),
                    subtitle: context.t(
                      'محاكي المناقشة — أسئلة اللجنة',
                      'Viva simulator — committee questions',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VivaSimulatorScreen(),
                      ),
                    ),
                  ),
                  if (showStats)
                    _CompanionToolCard(
                      icon: Icons.functions_outlined,
                      color: const Color(0xFF00838F),
                      title: context.t(
                        'معالج الافتراضات الإحصائية',
                        'Statistical assumptions wizard',
                      ),
                      subtitle: context.t(
                        'تطبيع، قوة العينة، SPSS/R',
                        'Normality, power, SPSS/R',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const StatisticalAssumptionsScreen(),
                        ),
                      ),
                    ),
                  _CompanionToolCard(
                    icon: Icons.handshake_outlined,
                    color: _brandColor,
                    title: context.t('مطابقة كاتب', 'Match a writer'),
                    subtitle: context.t(
                      'حسب تخصصك ولغتك وأدواتك',
                      'By your specialty, language & tools',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WriterMatchScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (categories.isNotEmpty)
                  Text(
                    context.t('اختر نوع الخدمة', 'Choose a service type'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        context.t(
                          'لا توجد خدمات مطابقة لـ «$_searchQuery»',
                          'No services match "$_searchQuery"',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          if (categories.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 168,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = categories[index];
                    return _CategoryCard(
                      category: category,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                WritingExpertListScreen(category: category),
                          ),
                        );
                      },
                    );
                  },
                  childCount: categories.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PublishWritingServiceScreen(),
            ),
          );
        },
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(context.t('أضف خدمتك', 'Add your service')),
      ),
    );
  }
}

class _CompanionToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CompanionToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final WritingCategory category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: category.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryVisual(
                imageUrl: category.imageUrl,
                icon: category.icon,
                color: category.color,
                height: 52,
              ),
              const Spacer(),
              Text(
                category.localizedTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: category.color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.localizedSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
