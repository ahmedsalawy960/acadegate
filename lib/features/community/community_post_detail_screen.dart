import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../messaging/chat_screen.dart';
import '../messaging/messaging_service.dart';
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
        SnackBar(
          content: Text(context.t(
            'الردود متاحة على المنشورات الحقيقية فقط',
            'Replies are only available on real posts',
          )),
        ),
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

  Future<void> _messageAuthor(CommunityPost post) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (post.authorId.isEmpty || post.authorId == myUid) return;
    try {
      final id = await MessagingService.instance.openConversation(
        otherUserId: post.authorId,
        otherUserName: post.authorName,
        contextType: 'community_post',
        contextId: post.id ?? post.title,
        contextTitle: post.title,
      );
      final conv = await MessagingService.instance.getConversation(id);
      if (!mounted || conv == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openAcademicLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.post.id;
    final isDemo = postId == null || postId.isEmpty;

    return Scaffold(
      appBar: AcadeGateAppBar(
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
                  child: Text(
                    context.t(
                      'منشورك بانتظار موافقة الإدارة',
                      'Your post is awaiting admin approval',
                    ),
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
                  child: Text(
                    context.t(
                      'منشور تجريبي — أنشئ منشوراً جديداً للتفاعل الحقيقي',
                      'Demo post — create a new post for real interaction',
                    ),
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
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final english =
                      Localizations.localeOf(context).languageCode == 'en';
                  final label = PostAudienceScope.label(
                    post.audienceScope,
                    english: english,
                  );
                  final detail =
                      post.audienceScope == PostAudienceScope.specialization &&
                              (post.targetSpecialization ?? '').isNotEmpty
                          ? '${context.t('الجمهور', 'Audience')}: $label — ${post.targetSpecialization}'
                          : '${context.t('الجمهور', 'Audience')}: $label';
                  return Row(
                    children: [
                      Icon(
                        PostAudienceScope.icon(post.audienceScope),
                        size: 16,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          detail,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (post.eventDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 6),
                    Text(context.t(
                      'موعد المناقشة: ${post.eventDate}',
                      'Seminar date: ${post.eventDate}',
                    )),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(post.body, style: const TextStyle(height: 1.6, fontSize: 15)),
              if ((post.academicLink ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    (post.academicTitle?.isNotEmpty == true)
                        ? post.academicTitle!
                        : context.t('مرجع أكاديمي', 'Academic reference'),
                  ),
                  subtitle: Text(post.academicLink!),
                  onTap: () => _openAcademicLink(post.academicLink!),
                ),
              ],
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
                  Text(context.t(
                    '${post.repliesCount} رد',
                    '${post.repliesCount} replies',
                  )),
                  const Spacer(),
                  if (!isDemo &&
                      post.authorId.isNotEmpty &&
                      post.authorId !=
                          FirebaseAuth.instance.currentUser?.uid)
                    OutlinedButton.icon(
                      onPressed: () => _messageAuthor(post),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(context.t('مراسلة الكاتب', 'Message author')),
                    ),
                ],
              ),
              const Divider(height: 32),
              Text(
                context.t('الردود', 'Replies'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (replies.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.t(
                      'لا توجد ردود بعد — كن أول من يرد.',
                      'No replies yet — be the first to reply.',
                    ),
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
                    decoration: InputDecoration(
                      hintText: context.t('اكتب رداً...', 'Write a reply...'),
                      border: const OutlineInputBorder(),
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
