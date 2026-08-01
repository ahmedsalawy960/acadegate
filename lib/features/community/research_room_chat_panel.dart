import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
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

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final error = await ResearchRoomService.instance.sendChannelMessage(
      roomId: widget.room.id,
      channelId: _channelId,
      text: _textController.text,
      academicLink: _showLinkFields ? _linkController.text : null,
      academicTitle: _showLinkFields ? _linkTitleController.text : null,
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
                    style: TextStyle(color: Colors.grey[600]),
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
                  return Align(
                    alignment:
                        mine ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: mine
                            ? const Color(0xFF00695C).withValues(alpha: 0.12)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.authorName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (msg.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(msg.text, style: const TextStyle(height: 1.35)),
                          ],
                          if ((msg.academicLink ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            InkWell(
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
                            ),
                          ],
                        ],
                      ),
                    ),
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.t('مرجع أكاديمي', 'Academic reference'),
                  onPressed: () =>
                      setState(() => _showLinkFields = !_showLinkFields),
                  icon: Icon(
                    Icons.menu_book_outlined,
                    color: _showLinkFields
                        ? const Color(0xFF00695C)
                        : Colors.grey[700],
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: context.t('اكتب رسالة...', 'Write a message...'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                  ),
                  icon: _sending
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
}
