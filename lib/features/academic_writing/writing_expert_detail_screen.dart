import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import '../messaging/conversations_screen.dart';
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
      appBar: AcadeGateAppBar(
        title: Text(context.t('ملف الكاتب', 'Writer profile')),
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
                      _chip(
                        Icons.star,
                        context.t(
                          '${expert.rating} تقييم',
                          '${expert.rating} rating',
                        ),
                      ),
                      _chip(
                        Icons.task_alt,
                        context.t(
                          '${expert.completedOrders} طلب',
                          '${expert.completedOrders} orders',
                        ),
                      ),
                      _chip(Icons.schedule, expert.avgDeliveryLabel),
                      _chip(Icons.payments_outlined, expert.priceRange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section(context.t('نبذة', 'Bio'), expert.bio),
          if (expert.portfolioSamples.isNotEmpty) ...[
            Text(
              context.t('معرض الأعمال (مجهّل)', 'Portfolio (anonymized)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...expert.portfolioSamples.map(
              (sample) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.article_outlined, color: category.color),
                  title: Text(sample, style: const TextStyle(height: 1.35)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (expert.languages.isNotEmpty)
            _section(
              context.t('اللغات', 'Languages'),
              expert.languages.join(' • '),
            ),
          if (expert.tools.isNotEmpty)
            _section(
              context.t('الأدوات', 'Tools'),
              expert.tools.join(' • '),
            ),
          if (expert.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.t('مجالات', 'Fields'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          if (expert.ownerId != null && expert.ownerId!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final loggedIn = await ensureLoggedIn(context);
                  if (!loggedIn || !context.mounted) return;
                  await openChatWithUser(
                    context,
                    otherUserId: expert.ownerId!,
                    otherUserName: expert.name,
                    contextType: 'writing',
                    contextId: expert.id ?? '',
                    contextTitle: expert.name,
                  );
                },
                icon: const Icon(Icons.chat),
                label: Text(context.t('مراسلة الكاتب', 'Message writer')),
              ),
            ),
          const SizedBox(height: 12),
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
              label: Text(context.t('حجز خدمة كتابة', 'Book writing service')),
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
