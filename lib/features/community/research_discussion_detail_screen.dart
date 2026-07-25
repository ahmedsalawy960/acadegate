import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'community_data.dart';
import 'research_room_models.dart';
import 'research_room_service.dart';

class ResearchDiscussionDetailScreen extends StatefulWidget {
  final ResearchRoom room;
  final String discussionId;

  const ResearchDiscussionDetailScreen({
    super.key,
    required this.room,
    required this.discussionId,
  });

  @override
  State<ResearchDiscussionDetailScreen> createState() =>
      _ResearchDiscussionDetailScreenState();
}

class _ResearchDiscussionDetailScreenState
    extends State<ResearchDiscussionDetailScreen> {
  final _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_isSending) return;

    setState(() => _isSending = true);
    final error = await ResearchRoomService.instance.addReply(
      roomId: widget.room.id,
      discussionId: widget.discussionId,
      body: _replyController.text,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    _replyController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t(
          'تم إرسال الرد — سيُشعَر منشئ الغرفة',
          'Reply sent — the room creator will be notified',
        )),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('المناقشة البحثية', 'Research discussion')),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<ResearchDiscussion?>(
        stream: ResearchRoomService.instance.watchDiscussion(
          roomId: widget.room.id,
          discussionId: widget.discussionId,
        ),
        builder: (context, discussionSnapshot) {
          final discussion = discussionSnapshot.data;
          if (discussion == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ResearchDiscussionReply>>(
                  stream: ResearchRoomService.instance.watchReplies(
                    roomId: widget.room.id,
                    discussionId: widget.discussionId,
                  ),
                  builder: (context, repliesSnapshot) {
                    final replies = repliesSnapshot.data ?? [];

                    return ListView(
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
                                    Icon(
                                      CommunityPostType.icon(discussion.type),
                                      color: const Color(0xFF00695C),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CommunityPostType.label(discussion.type),
                                      style: const TextStyle(
                                        color: Color(0xFF00695C),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  discussion.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  discussion.body,
                                  style: const TextStyle(height: 1.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  discussion.authorName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (discussion.tags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: discussion.tags
                                        .map(
                                          (tag) => Chip(
                                            label: Text(tag),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.t(
                            'الردود (${replies.length})',
                            'Replies (${replies.length})',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (replies.isEmpty)
                          Text(
                            context.t(
                              'لا توجد ردود بعد — كن أول من يرد.',
                              'No replies yet — be the first to reply.',
                            ),
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        else
                          ...replies.map(_replyTile),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: InputDecoration(
                            hintText: context.t('اكتب ردك...', 'Write your reply...'),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isSending ? null : _sendReply,
                        icon: _isSending
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
        },
      ),
    );
  }

  Widget _replyTile(ResearchDiscussionReply reply) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.authorName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(reply.body, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}
