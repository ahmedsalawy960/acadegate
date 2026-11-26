import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../moderation/approval_status.dart';
import 'community_data.dart';
import 'community_models.dart';
import 'community_post_detail_screen.dart';
import 'community_service.dart';

/// The member's own posts in every room, with their review status.
class MyCommunityPostsScreen extends StatelessWidget {
  const MyCommunityPostsScreen({super.key});

  String _statusLabel(BuildContext context, String? status) {
    switch (status) {
      case ApprovalStatus.pending:
        return context.t('بانتظار المراجعة', 'Pending review');
      case ApprovalStatus.suspended:
        return context.t(
          'مخفي مؤقتاً بعد بلاغات (قيد المراجعة)',
          'Hidden after reports (under review)',
        );
      case ApprovalStatus.rejected:
        return context.t('مرفوض', 'Not approved');
      default:
        return context.t('منشور', 'Published');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('منشوراتي', 'My posts')),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: CommunityService.instance.watchMyPosts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.t(
                    'لم تنشر شيئاً بعد. افتح أي غرفة واضغط «منشور جديد».',
                    'You have not posted yet. Open any room and tap "New post".',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final post = posts[i];
              final room = communityRoomById(post.roomId) ??
                  communityRoomById('general');
              return ListTile(
                title: Text(post.title, maxLines: 2),
                subtitle: Text(
                  '${_statusLabel(context, post.approvalStatus)} · '
                  '${post.repliesCount} ${context.t('ردود', 'replies')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: room == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityPostDetailScreen(
                              post: post,
                              room: room,
                            ),
                          ),
                        ),
              );
            },
          );
        },
      ),
    );
  }
}
