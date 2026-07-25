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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(L10nLookup.messages),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
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
