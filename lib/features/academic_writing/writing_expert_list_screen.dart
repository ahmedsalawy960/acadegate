import 'package:flutter/material.dart';

import 'writing_expert_detail_screen.dart';
import 'writing_fallback_data.dart';
import 'writing_models.dart';
import 'writing_service.dart';
import 'writing_categories.dart';

class WritingExpertListScreen extends StatelessWidget {
  final WritingCategory category;

  const WritingExpertListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.title),
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

          final experts = snapshot.data ?? fallbackExpertsForCategory(category.title);

          if (experts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'لا يوجد كتاب متاح في «${category.title}» حالياً.\n'
                  'يمكنك التسجيل ككاتب من الزر في الأسفل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: experts.length,
            itemBuilder: (context, index) {
              final expert = experts[index];
              return _ExpertCard(
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
              );
            },
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
