import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import '../messaging/chat_media.dart';
import '../messaging/chat_widgets.dart';
import 'research_room_models.dart';
import 'research_room_service.dart';

class ResearchRoomChatPanel extends StatefulWidget {
  final ResearchRoom room;

  const ResearchRoomChatPanel({super.key, required this.room});

  @override
  State<ResearchRoomChatPanel> createState() => _ResearchRoomChatPanelState();
}

class _ResearchRoomChatPanelState extends State<ResearchRoomChatPanel> {
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  final _linkTitleController = TextEditingController();
  final _scrollController = ScrollController();
  String _channelId = 'general';
  bool _sending = false;
  bool _showLinkFields = false;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await ResearchRoomService.instance.ensureDefaultChannels(widget.room.id);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final role = user.uid == widget.room.creatorId ? 'owner' : 'member';
        await ResearchRoomService.instance.ensureMemberRole(
          roomId: widget.room.id,
          role: role,
        );
      }
    } catch (_) {
      // Chat still works with local default channel chips.
    }
    if (mounted) setState(() => _bootstrapped = true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _linkController.dispose();
    _linkTitleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send({ChatAttachment attachment = const ChatAttachment()}) async {
    if (_sending) return;
    setState(() => _sending = true);
    final error = await ResearchRoomService.instance.sendChannelMessage(
      roomId: widget.room.id,
      channelId: _channelId,
      text: _textController.text,
      academicLink: _showLinkFields ? _linkController.text : null,
      academicTitle: _showLinkFields ? _linkTitleController.text : null,
      attachment: attachment,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    _textController.clear();
    _linkController.clear();
    _linkTitleController.clear();
    setState(() => _showLinkFields = false);
    _jumpToEnd();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = LocaleService.instance.isEnglish;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (!_bootstrapped) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        StreamBuilder<List<ResearchRoomChannel>>(
          stream: ResearchRoomService.instance.watchChannels(widget.room.id),
          builder: (context, snapshot) {
            final channels = snapshot.data?.isNotEmpty == true
                ? snapshot.data!
                : ResearchRoomChannel.defaults;
            return SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final channel in channels)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text('#${channel.label(isEnglish)}'),
                        selected: _channelId == channel.id,
                        onSelected: (_) =>
                            setState(() => _channelId = channel.id),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: StreamBuilder<List<ResearchChannelMessage>>(
            stream: ResearchRoomService.instance.watchChannelMessages(
              roomId: widget.room.id,
              channelId: _channelId,
            ),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    context.t(
                      'ابدأ النقاش الحي في هذه القناة',
                      'Start the live discussion in this channel',
                    ),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final mine = msg.authorId == myUid;
                  final prev = index > 0 ? messages[index - 1] : null;
                  final showDay = msg.createdAt != null &&
                      (prev == null ||
                          !isSameChatDay(prev.createdAt, msg.createdAt));

                  Widget? academicFooter;
                  if ((msg.academicLink ?? '').isNotEmpty) {
                    academicFooter = InkWell(
                      onTap: () => _openLink(msg.academicLink!),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              (msg.academicTitle?.isNotEmpty == true)
                                  ? msg.academicTitle!
                                  : msg.academicLink!,
                              style: const TextStyle(
                                color: Color(0xFF00695C),
                                decoration: TextDecoration.underline,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      if (showDay) ChatDaySeparator(day: msg.createdAt!),
                      ChatMessageBubble(
                        text: msg.text,
                        mine: mine,
                        createdAt: msg.createdAt,
                        attachment: msg.attachment,
                        senderName: msg.authorName,
                        mineColor:
                            const Color(0xFF00695C).withValues(alpha: 0.12),
                        theirsColor: Colors.grey.shade200,
                        mineTextColor: Colors.black87,
                        theirsTextColor: Colors.black87,
                        timeColorMine: Colors.black54,
                        timeColorTheirs: Colors.black45,
                        footerExtra: academicFooter,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        if (_showLinkFields)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _linkTitleController,
                  decoration: InputDecoration(
                    labelText: context.t(
                      'عنوان الورقة / المرجع',
                      'Paper / reference title',
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    labelText: context.t(
                      'رابط DOI أو URL',
                      'DOI or URL link',
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ChatComposerBar(
          controller: _textController,
          sending: _sending,
          accentColor: const Color(0xFF00695C),
          hintText: context.t('اكتب رسالة...', 'Write a message...'),
          onSend: () => _send(),
          onSendAttachment: (attachment) => _send(attachment: attachment),
          leadingActions: [
            IconButton(
              tooltip: context.t('مرجع أكاديمي', 'Academic reference'),
              onPressed: () =>
                  setState(() => _showLinkFields = !_showLinkFields),
              icon: Icon(
                Icons.menu_book_outlined,
                color: _showLinkFields
                    ? const Color(0xFF00695C)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
