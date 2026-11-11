import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../messaging/chat_media.dart';
import '../../messaging/chat_widgets.dart';
import '../store_theme.dart';
import 'research_partnership_models.dart';
import 'research_partnership_service.dart';

class ResearchPartnershipChatScreen extends StatefulWidget {
  final String partnershipId;
  final String title;

  const ResearchPartnershipChatScreen({
    super.key,
    required this.partnershipId,
    required this.title,
  });

  @override
  State<ResearchPartnershipChatScreen> createState() =>
      _ResearchPartnershipChatScreenState();
}

class _ResearchPartnershipChatScreenState
    extends State<ResearchPartnershipChatScreen> {
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
      await ResearchPartnershipService.instance.sendMessage(
        partnershipId: widget.partnershipId,
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

    return Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('غرفة المعرفة', 'Knowledge room'),
        ),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: StoreTheme.accentSoft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: StoreTheme.muted),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ResearchPartnershipMessage>>(
              stream: ResearchPartnershipService.instance
                  .watchMessages(widget.partnershipId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      context.t(
                        'لا رسائل بعد — شارك البروتوكول أو النتائج هنا',
                        'No messages yet — share protocols or results here',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m.senderId == myUid;
                    final prev = i > 0 ? messages[i - 1] : null;
                    final showDay = m.createdAt != null &&
                        (prev == null ||
                            !isSameChatDay(prev.createdAt, m.createdAt));
                    return Column(
                      children: [
                        if (showDay) ChatDaySeparator(day: m.createdAt!),
                        ChatMessageBubble(
                          text: m.text,
                          mine: mine,
                          createdAt: m.createdAt,
                          attachment: m.attachment,
                          senderName: m.senderName,
                          mineColor: StoreTheme.accentSoft,
                          theirsColor: Colors.white,
                          mineTextColor: StoreTheme.ink,
                          theirsTextColor: const Color(0xFF18181B),
                          timeColorMine: StoreTheme.muted,
                          timeColorTheirs: const Color(0xFF78716C),
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
            accentColor: StoreTheme.accent,
            hintText: context.t('اكتب رسالة…', 'Write a message…'),
            onSend: () => _send(),
            onSendAttachment: (attachment) => _send(attachment: attachment),
          ),
        ],
      ),
    );
  }
}
