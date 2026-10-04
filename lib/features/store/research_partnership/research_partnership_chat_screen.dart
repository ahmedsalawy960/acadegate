import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/locale_extensions.dart';
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
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ResearchPartnershipService.instance.sendMessage(
        partnershipId: widget.partnershipId,
        text: _controller.text,
      );
      _controller.clear();
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
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m.senderId == myUid;
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
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? StoreTheme.accentSoft
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: StoreTheme.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.senderName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: mine
                                    ? StoreTheme.muted
                                    : const Color(0xFF57534E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.text,
                              style: TextStyle(
                                color: mine
                                    ? StoreTheme.ink
                                    : const Color(0xFF18181B),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.t('اكتب رسالة…', 'Write a message…'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: StoreTheme.accent,
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
      ),
    );
  }
}
