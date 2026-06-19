import 'package:flutter/material.dart';

import '../moderation/approval_status.dart';
import 'community_data.dart';
import 'community_models.dart';
import 'community_post_detail_screen.dart';
import 'community_service.dart';
import 'create_community_post_screen.dart';

class CommunityRoomScreen extends StatefulWidget {
  final CommunityRoom room;

  const CommunityRoomScreen({super.key, required this.room});

  @override
  State<CommunityRoomScreen> createState() => _CommunityRoomScreenState();
}

class _CommunityRoomScreenState extends State<CommunityRoomScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = <String?, String>{
    null: 'الكل',
    CommunityPostType.question: 'أسئلة',
    CommunityPostType.discussion: 'نقاش',
    CommunityPostType.announcement: 'إعلانات',
    CommunityPostType.studyGroup: 'مجموعات',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _selectedType => _tabs.keys.elementAt(_tabController.index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('غرفة ${widget.room.title}'),
        backgroundColor: widget.room.color,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (_) => setState(() {}),
          tabs: _tabs.values.map((label) => Tab(text: label)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CreateCommunityPostScreen(
                room: widget.room,
                initialType: _selectedType ?? CommunityPostType.discussion,
              ),
            ),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إرسال المنشور للمراجعة — سيظهر بعد الموافقة'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: widget.room.color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('منشور جديد'),
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: CommunityService.instance.watchRoomPosts(
          roomId: widget.room.id,
          type: _selectedType,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'لا توجد منشورات في هذا القسم بعد.\nاضغط «منشور جديد» لتبدأ النقاش.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], height: 1.5),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _PostCard(
                post: post,
                roomColor: widget.room.color,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityPostDetailScreen(
                        post: post,
                        room: widget.room,
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

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final Color roomColor;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.roomColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = CommunityPostType.label(post.type);
    final pending = post.approvalStatus == ApprovalStatus.pending;

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
                  Icon(
                    CommunityPostType.icon(post.type),
                    size: 18,
                    color: roomColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      color: roomColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'بانتظار المراجعة',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (post.eventDate != null)
                    Text(
                      post.eventDate!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                post.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[800], height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    post.authorName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (post.university != null) ...[
                    Text(
                      ' • ${post.university}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.thumb_up_alt_outlined,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${post.upvotesCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  Icon(Icons.chat_bubble_outline,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${post.repliesCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
