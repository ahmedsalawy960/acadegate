import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'external_writing_tools_panel.dart';
import 'writing_expert_detail_screen.dart';
import 'writing_models.dart';
import 'writing_service.dart';
import 'writing_categories.dart';

class WritingExpertListScreen extends StatelessWidget {
  final WritingCategory category;

  const WritingExpertListScreen({super.key, required this.category});

  bool get _isEditingCategory => category.id == 'editing';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(category.localizedTitle),
        backgroundColor: category.color,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<WritingExpert>>(
        stream: WritingService.instance.expertsStream(
          categoryTitle: category.title,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final experts = snapshot.data ?? const [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isEditingCategory) ...[
                ExternalWritingToolsPanel(accent: category.color),
                const SizedBox(height: 16),
                Text(
                  context.t(
                    'خبراء تحرير بشريون',
                    'Human editing experts',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (experts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    context.t(
                      'لا يوجد كتاب متاح في «${category.localizedTitle}» حالياً.\n'
                      'يمكنك التسجيل ككاتب من الزر في الأسفل'
                      '${_isEditingCategory ? '، أو استخدم أدوات التحرير أعلاه.' : '.'}',
                      'No writers available in «${category.localizedTitle}» yet.\n'
                      'You can register as a writer using the button below'
                      '${_isEditingCategory ? ', or use the editing tools above.' : '.'}',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                ...experts.map(
                  (expert) => _ExpertCard(
                    expert: expert,
                    accent: category.color,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WritingExpertDetailScreen(
                            expert: expert,
                            category: category,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  final WritingExpert expert;
  final Color accent;
  final VoidCallback onTap;

  const _ExpertCard({
    required this.expert,
    required this.accent,
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
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(Icons.person, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expert.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      expert.speciality,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        Text(' ${expert.rating}'),
                        const SizedBox(width: 10),
                        Text(
                          expert.priceRange,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
