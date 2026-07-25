import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../ai_advisor/advisor_branding.dart';
import '../home/home_search_utils.dart';
import '../home/section_search_field.dart';
import '../methodology_integrity/methodology_integrity_screen.dart';
import 'citation_check_screen.dart';
import 'originality_check_screen.dart';

class AcademicIntegrityHubScreen extends StatefulWidget {
  const AcademicIntegrityHubScreen({super.key});

  @override
  State<AcademicIntegrityHubScreen> createState() =>
      _AcademicIntegrityHubScreenState();
}

class _AcademicIntegrityHubScreenState extends State<AcademicIntegrityHubScreen> {
  static const _brand = Color(0xFF1B5E20);
  String _searchQuery = '';

  late final List<_IntegrityTool> _tools = [
    _IntegrityTool(
      color: const Color(0xFF0D47A1),
      icon: Icons.menu_book_outlined,
      titleAr: 'فاحص المراجع',
      titleEn: 'Reference checker',
      subtitleAr: 'تحقق DOI والعناوين — Crossref + OpenAlex + Semantic Scholar',
      subtitleEn: 'Verify DOIs & titles — Crossref + OpenAlex + Semantic Scholar',
      keywords: const [
        'citation',
        'reference',
        'doi',
        'crossref',
        'openalex',
        'مراجع',
        'مرجع',
        'توثيق',
      ],
      screen: const CitationCheckScreen(),
    ),
    _IntegrityTool(
      color: const Color(0xFF6A1B9A),
      icon: Icons.fact_check_outlined,
      titleAr: 'فاحص التشابه',
      titleEn: 'Similarity checker',
      subtitleAr: 'Copyleaks + PlagiarismCheck.org — نسبة التشابه والمصادر',
      subtitleEn: 'Copyleaks + PlagiarismCheck.org — similarity % & sources',
      keywords: const [
        'plagiarism',
        'similarity',
        'copyleaks',
        'originality',
        'انتحال',
        'تشابه',
      ],
      screen: const OriginalityCheckScreen(),
    ),
    _IntegrityTool(
      color: _brand,
      icon: Icons.policy_outlined,
      titleAr: 'كاشف الانتحال المنهجي',
      titleEn: 'Methodology Integrity Check',
      subtitleAr: 'توافق التصميم والعينة والتحليل — تحليل ذكي اختياري',
      subtitleEn: 'Design, sample & analysis alignment — optional smart analysis',
      keywords: const [
        'methodology',
        'method',
        'integrity',
        'منهجيه',
        'منهجية',
        'عينه',
        'تصميم',
      ],
      screen: const MethodologyIntegrityScreen(),
    ),
  ];

  List<_IntegrityTool> get _filteredTools {
    if (_searchQuery.trim().isEmpty) return _tools;
    return _tools
        .where(
          (tool) => homeSearchMatches(_searchQuery, [
            tool.titleAr,
            tool.titleEn,
            tool.subtitleAr,
            tool.subtitleEn,
            ...tool.keywords,
          ]),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tools = _filteredTools;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(AdvisorBranding.integrityTitle),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionSearchField(
            query: _searchQuery,
            onChanged: (value) => setState(() => _searchQuery = value),
            onClear: () => setState(() => _searchQuery = ''),
            hint: context.t(
              'ابحث: مراجع، تشابه، منهجية...',
              'Search: references, similarity, methodology...',
            ),
          ),
          const SizedBox(height: 16),
          if (_searchQuery.trim().isEmpty)
            Card(
              color: _brand.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user, color: _brand, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AdvisorBranding.integrityTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: _brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t(
                        'مجاناً: Crossref · OpenAlex · Semantic Scholar · كاشف المنهجية\n'
                        'مدفوع (رصيد): Copyleaks · PlagiarismCheck — ليس Turnitin رسمياً',
                        'Free: Crossref · OpenAlex · Semantic Scholar · methodology checker\n'
                        'Paid (credits): Copyleaks · PlagiarismCheck — not official Turnitin',
                      ),
                      style: const TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          if (_searchQuery.trim().isEmpty) const SizedBox(height: 16),
          if (tools.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  context.t(
                    'لا توجد أدوات مطابقة لـ «$_searchQuery»',
                    'No tools match "$_searchQuery"',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            )
          else
            ...tools.expand((tool) sync* {
              yield _ToolCard(
                color: tool.color,
                icon: tool.icon,
                title: context.t(tool.titleAr, tool.titleEn),
                subtitle: context.t(tool.subtitleAr, tool.subtitleEn),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => tool.screen),
                  );
                },
              );
              yield const SizedBox(height: 12);
            }),
        ],
      ),
    );
  }
}

class _IntegrityTool {
  final Color color;
  final IconData icon;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final List<String> keywords;
  final Widget screen;

  const _IntegrityTool({
    required this.color,
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.keywords,
    required this.screen,
  });
}

class _ToolCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
