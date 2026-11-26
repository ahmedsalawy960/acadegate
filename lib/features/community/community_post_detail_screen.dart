import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import '../messaging/chat_media.dart';
import '../messaging/chat_screen.dart';
import '../messaging/chat_widgets.dart';
import '../messaging/messaging_service.dart';
import '../moderation/approval_status.dart';
import '../moderation/delete_content_button.dart';
import 'community_data.dart';
import 'community_feed.dart';
import 'community_trust.dart';
import 'community_models.dart';
import 'community_report_dialog.dart';
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

  Future<void> _submitReply({
    ChatAttachment attachment = const ChatAttachment(),
  }) async {
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
      attachment: attachment,
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
    if (!isSafeCommunityLink(url)) return;
    final uri = Uri.parse(url.trim());
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
        actions: [
          if (!isDemo &&
              FirebaseAuth.instance.currentUser?.uid != widget.post.authorId)
            IconButton(
              tooltip: context.t('إبلاغ', 'Report'),
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => showCommunityReportDialog(
                context,
                postId: widget.post.id ?? '',
                postTitle: widget.post.title,
              ),
            ),
          ...deleteAppBarActions(
            collection: 'community_posts',
            documentId: widget.post.id,
            ownerId: widget.post.authorId,
            itemLabel: widget.post.title,
          ),
        ],
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
                  CommunityAuthorLine(
                    name: post.authorName,
                    badge: post.authorBadge,
                    style: TextStyle(color: const Color(0xFFB7C3D6)),
                  ),
                  if (post.university != null) ...[
                    Text(
                      ' • ${post.university}',
                      style: TextStyle(color: const Color(0xFFB7C3D6)),
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
                        color: const Color(0xFFB7C3D6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          detail,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFFB7C3D6),
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
                    style: TextStyle(color: const Color(0xFFB7C3D6)),
                  ),
                )
              else
                ...orderCommunityReplies(replies, post.bestReplyId)
                    .map((r) => _replyTile(r, post)),
              ManageContentActions(
                collection: 'community_posts',
                documentId: post.id,
                ownerId: post.authorId,
                itemLabel: post.title,
              ),
            ],
          ),
        ),
        if (!post.isPubliclyVisible)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                context.t(
                  'الردود تُفتح بعد اعتماد المنشور.',
                  'Replies open once the post is approved.',
                ),
                style: const TextStyle(color: Color(0xFFB7C3D6)),
              ),
            ),
          )
        else
          ChatComposerBar(
            restrictedAttachments: true,
            controller: _replyController,
            sending: _replyLoading,
            accentColor: widget.room.color,
            hintText: context.t('اكتب رداً...', 'Write a reply...'),
            onSend: _submitReply,
            onSendAttachment: (attachment) =>
                _submitReply(attachment: attachment),
          ),
      ],
    );
  }

  Future<void> _confirmDeleteReply(CommunityReply reply) async {
    final postId = widget.post.id;
    final replyId = reply.id;
    if (postId == null || replyId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('حذف الرد', 'Delete reply')),
        content: Text(context.t(
          'هل تريد حذف هذا الرد نهائياً؟',
          'Delete this reply permanently?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await CommunityService.instance
        .deleteReply(postId: postId, replyId: replyId);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Widget _replyTile(CommunityReply reply, CommunityPost post) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data?.isAdmin == true;
        final canDelete = post.isFromFirebase &&
            (reply.id ?? '').isNotEmpty &&
            ((uid != null && uid == reply.authorId) || isAdmin);
        final isBest = post.bestReplyId.isNotEmpty &&
            post.bestReplyId == reply.id;
        final canMarkBest = post.isFromFirebase &&
            post.isPubliclyVisible &&
            (reply.id ?? '').isNotEmpty &&
            uid != null &&
            uid == post.authorId &&
            uid != reply.authorId &&
            !reply.hiddenByReports;
        final canVote = post.isFromFirebase &&
            post.isPubliclyVisible &&
            (reply.id ?? '').isNotEmpty &&
            uid != null &&
            uid != reply.authorId &&
            !reply.hiddenByReports;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: isBest
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isBest)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 16, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 4),
                              Text(
                                context.t('أفضل إجابة', 'Best answer'),
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      CommunityAuthorLine(
                        name: reply.authorName,
                        badge: reply.authorBadge,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (reply.hiddenByReports) ...[
                        const SizedBox(height: 6),
                        Text(
                          context.t(
                            'تم إخفاء هذا الرد مؤقتاً بعد بلاغات، وهو قيد المراجعة.',
                            'This reply is hidden after reports and is under review.',
                          ),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ] else ...[
                      if (reply.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(reply.body, style: const TextStyle(height: 1.4)),
                      ],
                      if (reply.attachment.hasMedia) ...[
                        const SizedBox(height: 8),
                        ChatMessageBubble(
                          text: '',
                          mine: false,
                          attachment: reply.attachment,
                          theirsColor: const Color(0xFFF4F7FB),
                          theirsTextColor: const Color(0xFF1C1917),
                        ),
                      ],
                      ],
                    ],
                  ),
                ),
                if (canVote || reply.upvotesCount > 0)
                  _ReplyVoteButton(
                    postId: post.id ?? '',
                    reply: reply,
                    enabled: canVote,
                  ),
                if (canMarkBest)
                  IconButton(
                    tooltip: isBest
                        ? context.t('إزالة أفضل إجابة', 'Remove best answer')
                        : context.t('اختيار كأفضل إجابة', 'Mark as best answer'),
                    icon: Icon(
                      isBest ? Icons.check_circle : Icons.check_circle_outline,
                      size: 20,
                      color: const Color(0xFF2E7D32),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await CommunityService.instance.setBestReply(
                        postId: post.id!,
                        replyId: isBest ? '' : (reply.id ?? ''),
                      );
                      if (error != null) {
                        messenger.showSnackBar(
                            SnackBar(content: Text(error)));
                      }
                    },
                  ),
                if (canDelete)
                  IconButton(
                    tooltip: context.t('حذف الرد', 'Delete reply'),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmDeleteReply(reply),
                  ),
                if (post.isFromFirebase &&
                    (reply.id ?? '').isNotEmpty &&
                    uid != null &&
                    uid != reply.authorId)
                  IconButton(
                    tooltip: context.t('إبلاغ', 'Report'),
                    icon: const Icon(Icons.flag_outlined, size: 20),
                    onPressed: () => showCommunityReportDialog(
                      context,
                      postId: post.id!,
                      replyId: reply.id,
                      postTitle: post.title,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// "Helpful" vote on a reply, with its count.
class _ReplyVoteButton extends StatelessWidget {
  const _ReplyVoteButton({
    required this.postId,
    required this.reply,
    required this.enabled,
  });

  final String postId;
  final CommunityReply reply;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: enabled
          ? CommunityService.instance.watchReplyVote(postId, reply.id!)
          : Stream.value(false),
      builder: (context, snapshot) {
        final voted = snapshot.data == true;
        return TextButton.icon(
          onPressed: !enabled
              ? null
              : () async {
                  final error = await CommunityService.instance
                      .toggleReplyVote(postId, reply.id!);
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error)));
                  }
                },
          icon: Icon(
            voted ? Icons.thumb_up : Icons.thumb_up_outlined,
            size: 18,
          ),
          label: Text('${reply.upvotesCount}'),
        );
      },
    );
  }
}
