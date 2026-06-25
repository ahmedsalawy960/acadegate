import 'package:flutter/material.dart';

import '../../core/widgets/category_visual.dart';
import 'my_writing_orders_screen.dart';
import 'publish_writing_service_screen.dart';
import 'writing_categories.dart';
import 'writing_expert_list_screen.dart';

class WritingHubScreen extends StatelessWidget {
  const WritingHubScreen({super.key});

  static const _brandColor = Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خدمات الكتابة الأكاديمية'),
        centerTitle: true,
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'طلباتي',
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _brandColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _brandColor.withValues(alpha: 0.2)),
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
                  const Expanded(
                    child: Text(
                      'كتابة بشرية متخصصة — ليست ذكاء اصطناعي. '
                      'اختر الخدمة، حدّد متطلباتك، واحجز مع خبير.',
                      style: TextStyle(height: 1.4, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اختر نوع الخدمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'رسائل، أبحاث، إحصاء، مراجعة أدبيات، وتحرير أكاديمي',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: writingCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 168,
                ),
                itemBuilder: (context, index) {
                  final category = writingCategories[index];
                  return _CategoryCard(
                    category: category,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WritingExpertListScreen(
                            category: category,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const PublishWritingServiceScreen(),
            ),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إرسال ملفك ككاتب أكاديمي للمراجعة'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('سجّل ككاتب'),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final WritingCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CategoryVisual(
              imageUrl: category.imageUrl,
              icon: category.icon,
              color: category.color,
              height: 76,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(category.icon, size: 15, color: category.color),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            category.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
