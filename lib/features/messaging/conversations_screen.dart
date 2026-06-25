import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'messaging_models.dart';
import 'messaging_service.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرسائل'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('سجّل الدخول لعرض رسائلك'))
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
                          'لا توجد محادثات بعد',
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
                            ? 'ابدأ المحادثة'
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

/// يفتح محادثة مع مستخدم (مشرف/كاتب/بائع).
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
