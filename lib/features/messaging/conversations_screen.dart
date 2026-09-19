import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import 'chat_screen.dart';
import 'messaging_models.dart';
import 'messaging_service.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  Future<void> _hideOne(BuildContext context, Conversation conv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('إزالة المحادثة؟', 'Remove conversation?')),
        content: Text(
          ctx.t(
            'تُزال من قائمتك فقط. الطرف الآخر يحتفظ بالمحادثة، ويمكن إعادة فتحها عند مراسلة جديدة.',
            'Removed from your list only. The other person keeps the chat, and it can reopen on a new message.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10nLookup.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await MessagingService.instance.hideConversationForMe(conv.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تمت إزالة المحادثة من قائمتك', 'Conversation removed from your list'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10nLookup.deleteFailed(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _hideAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('إزالة كل المحادثات؟', 'Remove all conversations?')),
        content: Text(
          ctx.t(
            'تُزال من قائمتك فقط — لا تُحذف عند الطرف الآخر.',
            'Removed from your list only — not deleted for the other person.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10nLookup.deleteAll),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await MessagingService.instance.hideAllConversationsForMe();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تمت إزالة المحادثات من قائمتك', 'Conversations removed from your list'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10nLookup.deleteFailed(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(L10nLookup.messages),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (user != null)
            IconButton(
              tooltip: L10nLookup.deleteAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _hideAll(context),
            ),
        ],
      ),
      body: user == null
          ? Center(
              child: Text(
                context.t(
                  'سجّل الدخول لعرض رسائلك',
                  'Sign in to view your messages',
                ),
              ),
            )
          : StreamBuilder<List<Conversation>>(
              stream: MessagingService.instance.myConversationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final conversations = snapshot.data ?? [];
                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          context.t(
                            'لا توجد محادثات بعد',
                            'No conversations yet',
                          ),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            context.t(
                              'المحادثات المباشرة تظهر هنا. طلبات الإشراف من الباحثين تظهر في بوابة مقدم الخدمة ← طلبات الإشراف الواردة.',
                              'Direct chats appear here. Supervision requests from researchers appear in the provider portal → Incoming supervision requests.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(
                        conv.otherParticipantName(user.uid),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        conv.lastMessage.isEmpty
                            ? context.t('ابدأ المحادثة', 'Start the conversation')
                            : conv.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: L10nLookup.delete,
                        icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                        onPressed: () => _hideOne(context, conv),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChatScreen(conversation: conv),
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

/// Opens a chat with a user (supervisor/writer/seller).
Future<void> openChatWithUser(
  BuildContext context, {
  required String otherUserId,
  required String otherUserName,
  required String contextType,
  required String contextId,
  String contextTitle = '',
}) async {
  try {
    final id = await MessagingService.instance.openConversation(
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      contextType: contextType,
      contextId: contextId,
      contextTitle: contextTitle,
    );
    if (!context.mounted) return;

    final conv = Conversation(
      id: id,
      participantIds: [
        FirebaseAuth.instance.currentUser!.uid,
        otherUserId,
      ],
      participantNames: {otherUserId: otherUserName},
      contextType: contextType,
      contextId: contextId,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(conversation: conv)),
    );
  } catch (e) {
    if (!context.mounted) rethrow;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: Colors.red),
    );
    rethrow;
  }
}
