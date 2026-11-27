import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/acadegate_app_bar.dart';
import '../academic/academic_models.dart';
import 'research_idea_favorites_service.dart';
import 'research_idea_marketplace_detail_screen.dart';

/// قائمة الأفكار المحفوظة (مفضلة الطالب).
class MyFavoriteIdeasScreen extends StatelessWidget {
  const MyFavoriteIdeasScreen({super.key});

  Future<void> _openIdea(BuildContext context, String ideaId) async {
    final doc = await FirebaseFirestore.instance
        .collection('research_ideas')
        .doc(ideaId)
        .get();
    if (!context.mounted) return;
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'الفكرة لم تعد متاحة',
            'This idea is no longer available',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final idea = AcademicResearchIdea.fromMap(doc.data()!, id: doc.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResearchIdeaMarketplaceDetailScreen(idea: idea),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('أفكاري المحفوظة', 'My saved ideas')),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ResearchIdeaFavoritesService.instance.watchFavorites(),
        builder: (context, snap) {
          final items = snap.data ?? const <Map<String, dynamic>>[];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return Center(
              child: Text(
                context.t(
                  'لا أفكار محفوظة بعد — احفظ أي فكرة من صفحتها',
                  'No saved ideas yet — save any idea from its page',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB7C3D6)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final ideaId = item['id']?.toString() ?? '';
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.bookmark,
                    color: Colors.orange,
                  ),
                  title: Text(
                    item['title']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: (item['titleEn']?.toString() ?? '').isEmpty
                      ? null
                      : Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            item['titleEn'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB7C3D6),
                            ),
                          ),
                        ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _openIdea(context, ideaId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
