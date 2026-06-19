import 'package:flutter/material.dart';

import '../moderation/approval_status.dart';
import '../moderation/delete_content_button.dart';
import 'community_data.dart';
import 'community_models.dart';
import 'community_service.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final CommunityPost post;
  final CommunityRoom room;

  const CommunityPostDetailScreen({
    super.key,
    required this.post,
    required this.room,
  });

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final _replyController = TextEditingController();
  bool _upvoted = false;
  bool _upvoteLoading = false;
  bool _replyLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUpvoteState();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadUpvoteState() async {
    final postId = widget.post.id;
    if (postId == null) return;

    final upvoted = await CommunityService.instance.hasUpvoted(postId);
    if (mounted) setState(() => _upvoted = upvoted);
  }

  Future<void> _toggleUpvote(CommunityPost post) async {
    final postId = post.id;
    if (postId == null) return;

    setState(() => _upvoteLoading = true);
    final upvoted = await CommunityService.instance.toggleUpvote(postId);
    if (mounted) {
      setState(() {
        _upvoted = upvoted;
        _upvoteLoading = false;
      });
    }
  }

  Future<void> _submitReply() async {
    final postId = widget.post.id;
    if (postId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الردود متاحة على المنشورات الحقيقية فقط')),
      );
      return;
    }

    setState(() => _replyLoading = true);
    final error = await CommunityService.instance.addReply(
      postId: postId,
      body: _replyController.text,
    );

    if (!mounted) return;
    setState(() => _replyLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _replyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.post.id;
    final isDemo = postId == null || postId.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(CommunityPostType.label(widget.post.type)),
        backgroundColor: widget.room.color,
        foregroundColor: Colors.white,
        actions: deleteAppBarActions(
          collection: 'community_posts',
          documentId: widget.post.id,
          ownerId: widget.post.authorId,
          itemLabel: widget.post.title,
        ),
      ),
      body: isDemo
          ? _buildBody(widget.post, const [])
          : StreamBuilder<CommunityPost?>(
              stream: CommunityService.instance.watchPost(postId),
              builder: (context, postSnapshot) {
                final livePost = postSnapshot.data ?? widget.post;
                return StreamBuilder<List<CommunityReply>>(
                  stream: CommunityService.instance.watchReplies(postId),
                  builder: (context, repliesSnapshot) {
                    final replies = repliesSnapshot.data ?? const [];
                    return _buildBody(livePost, replies);
                  },
                );
              },
            ),
    );
  }

  Widget _buildBody(CommunityPost post, List<CommunityReply> replies) {
    final isDemo = post.id == null || post.id!.isEmpty;
    final pending = post.approvalStatus == ApprovalStatus.pending;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'منشورك بانتظار موافقة الإدارة',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (isDemo)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'منشور تجريبي — أنشئ منشوراً جديداً للتفاعل الحقيقي',
                    textAlign: TextAlign.center,
                  ),
                ),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    post.authorName,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (post.university != null) ...[
                    Text(
                      ' • ${post.university}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
              if (post.eventDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 6),
                    Text('موعد المناقشة: ${post.eventDate}'),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(post.body, style: const TextStyle(height: 1.6, fontSize: 15)),
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: post.tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isDemo || _upvoteLoading
                        ? null
                        : () => _toggleUpvote(post),
                    icon: _upvoteLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _upvoted
                                ? Icons.thumb_up
                                : Icons.thumb_up_alt_outlined,
                          ),
                    label: Text('${post.upvotesCount}'),
                  ),
                  const SizedBox(width: 12),
                  Text('${post.repliesCount} رد'),
                ],
              ),
              const Divider(height: 32),
              Text(
                'الردود',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (replies.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'لا توجد ردود بعد — كن أول من يرد.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                ...replies.map(_replyTile),
              ManageContentActions(
                collection: 'community_posts',
                documentId: post.id,
                ownerId: post.authorId,
                itemLabel: post.title,
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رداً...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _replyLoading ? null : _submitReply,
                  icon: _replyLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _replyTile(CommunityReply reply) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.authorName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(reply.body, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}
