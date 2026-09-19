import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../notifications/notification_service.dart';
import 'messaging_models.dart';

class MessagingService {
  MessagingService._();

  static final MessagingService instance = MessagingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  String _conversationId(String uidA, String uidB, String contextType, String contextId) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}_${contextType}_$contextId';
  }

  Future<String> openConversation({
    required String otherUserId,
    required String otherUserName,
    required String contextType,
    required String contextId,
    String contextTitle = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
        appTr('يجب تسجيل الدخول للمراسلة', 'You must sign in to message'),
      );
    }
    if (otherUserId.isEmpty) {
      throw Exception(
        appTr(
          'لا يمكن بدء محادثة بدون مستخدم',
          'Cannot start a conversation without a user',
        ),
      );
    }
    if (otherUserId == user.uid) {
      throw Exception(
        appTr(
          'لا يمكن مراسلة نفسك — جرّب من حساب مشتري آخر',
          'You cannot message yourself — try from another buyer account',
        ),
      );
    }

    final id = _conversationId(user.uid, otherUserId, contextType, contextId);
    final ref = _conversations.doc(id);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'participantIds': [user.uid, otherUserId],
        'participantNames': {
          user.uid: user.displayName ??
              user.email?.split('@').first ??
              L10nLookup.user,
          otherUserId: otherUserName,
        },
        'contextType': contextType,
        'contextId': contextId,
        'contextTitle': contextTitle,
        'lastMessage': '',
        'hiddenFor': <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // إعادة فتح محادثة سبق إخفاؤها من قائمتي.
      await ref.update({
        'hiddenFor': FieldValue.arrayRemove([user.uid]),
      });
    }

    return id;
  }

  Stream<List<Conversation>> myConversationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _conversations
        .where('participantIds', arrayContains: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Conversation.fromMap(doc.data(), id: doc.id))
              .where((c) => !c.isHiddenFor(user.uid))
              .toList(),
        );
  }

  /// يخفي المحادثة من قائمتي فقط (مثل مسح إشعار) — الطرف الآخر يحتفظ بها.
  Future<void> hideConversationForMe(String conversationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(L10nLookup.loginRequiredMessage);
    await _conversations.doc(conversationId).update({
      'hiddenFor': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> hideAllConversationsForMe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(L10nLookup.loginRequiredMessage);
    final snap = await _conversations
        .where('participantIds', arrayContains: user.uid)
        .get();
    final batch = _db.batch();
    var n = 0;
    for (final doc in snap.docs) {
      final hidden = (doc.data()['hiddenFor'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (hidden.contains(user.uid)) continue;
      batch.update(doc.reference, {
        'hiddenFor': FieldValue.arrayUnion([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      n++;
      if (n >= 400) break;
    }
    if (n > 0) await batch.commit();
  }

  Future<Conversation?> getConversation(String conversationId) async {
    if (conversationId.isEmpty) return null;
    final snap = await _conversations.doc(conversationId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Conversation.fromMap(snap.data()!, id: snap.id);
  }

  Stream<List<ChatMessage>> messagesStream(String conversationId) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(L10nLookup.loginRequiredMessage);

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final convRef = _conversations.doc(conversationId);
    final conv = await convRef.get();
    if (!conv.exists) {
      throw Exception(
        appTr('المحادثة غير موجودة', 'Conversation not found'),
      );
    }

    final participants =
        (conv.data()?['participantIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

    final senderName =
        user.displayName ?? user.email?.split('@').first ?? L10nLookup.user;

    await convRef.collection('messages').add({
      'senderId': user.uid,
      'senderName': senderName,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await convRef.update({
      'lastMessage': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
      // أعد إظهار المحادثة للطرفين عند رسالة جديدة.
      'hiddenFor': FieldValue.arrayRemove(participants),
    });

    for (final participantId in participants) {
      if (participantId == user.uid) continue;
      await NotificationService.instance.send(
        userId: participantId,
        title: L10nLookup.newMessageTitle(),
        body: '$senderName: $trimmed',
        type: 'message',
        contextId: conversationId,
        contextType: 'conversation',
      );
    }
  }
}
