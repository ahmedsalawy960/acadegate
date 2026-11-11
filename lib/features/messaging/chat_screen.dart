import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'chat_media.dart';
import 'chat_widgets.dart';
import 'messaging_models.dart';
import 'messaging_service.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send({ChatAttachment attachment = const ChatAttachment()}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await MessagingService.instance.sendMessage(
        conversationId: widget.conversation.id,
        text: _controller.text,
        attachment: attachment,
      );
      _controller.clear();
      _jumpToEnd();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final title = widget.conversation.otherParticipantName(myUid);

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: MessagingService.instance
                  .messagesStream(widget.conversation.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      context.t(
                        'لا رسائل بعد — ابدأ المحادثة',
                        'No messages yet — start the conversation',
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final mine = msg.senderId == myUid;
                    final prev = index > 0 ? messages[index - 1] : null;
                    final showDay = msg.createdAt != null &&
                        (prev == null ||
                            !isSameChatDay(prev.createdAt, msg.createdAt));

                    return Column(
                      children: [
                        if (showDay)
                          ChatDaySeparator(day: msg.createdAt!),
                        ChatMessageBubble(
                          text: msg.text,
                          mine: mine,
                          createdAt: msg.createdAt,
                          attachment: msg.attachment,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          ChatComposerBar(
            controller: _controller,
            sending: _sending,
            accentColor: const Color(0xFF1A237E),
            onSend: () => _send(),
            onSendAttachment: (attachment) => _send(attachment: attachment),
          ),
        ],
      ),
    );
  }
}
