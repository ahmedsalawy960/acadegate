import 'package:flutter/material.dart';

import '../moderation/delete_content_button.dart';
import 'book_writing_order_screen.dart';
import 'writing_categories.dart';
import 'writing_models.dart';

class WritingExpertDetailScreen extends StatelessWidget {
  final WritingExpert expert;
  final WritingCategory category;

  const WritingExpertDetailScreen({
    super.key,
    required this.expert,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملف الكاتب'),
        backgroundColor: category.color,
        foregroundColor: Colors.white,
        actions: deleteAppBarActions(
          collection: 'writing_services',
          documentId: expert.id,
          ownerId: expert.ownerId,
          itemLabel: expert.name,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: category.color.withValues(alpha: 0.12),
                        child: Icon(Icons.person, size: 36, color: category.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expert.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              expert.speciality,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(Icons.star, '${expert.rating} تقييم'),
                      _chip(Icons.task_alt, '${expert.completedOrders} طلب'),
                      _chip(Icons.schedule, expert.deliveryLabel),
                      _chip(Icons.payments_outlined, expert.priceRange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section('نبذة', expert.bio),
          if (expert.languages.isNotEmpty)
            _section('اللغات', expert.languages.join(' • ')),
          if (expert.tools.isNotEmpty)
            _section('الأدوات', expert.tools.join(' • ')),
          if (expert.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'مجالات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: expert.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: category.color.withValues(alpha: 0.08),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () async {
                final booked = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookWritingOrderScreen(
                      expert: expert,
                      category: category,
                    ),
                  ),
                );
                if (booked == true && context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.edit_calendar),
              label: const Text('حجز خدمة كتابة'),
              style: FilledButton.styleFrom(
                backgroundColor: category.color,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          ManageContentActions(
            collection: 'writing_services',
            documentId: expert.id,
            ownerId: expert.ownerId,
            itemLabel: expert.name,
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.5, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
