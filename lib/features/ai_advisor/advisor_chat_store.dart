import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'advisor_conversation.dart';
import 'advisor_message.dart';

class AdvisorChatStore {
  AdvisorChatStore._();

  static final AdvisorChatStore instance = AdvisorChatStore._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Map<String, AdvisorConversation> _localConversations = {};
  final Map<String, List<AdvisorMessage>> _localMessages = {};

  bool get canPersist => FirebaseAuth.instance.currentUser != null;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return _db.collection('advisor_chats').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>>? _conversationsRef() {
    return _userRef()?.collection('conversations');
  }

  String _titleFromMessage(String message) {
    final trimmed = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return 'محادثة جديدة';
    return trimmed.length > 48 ? '${trimmed.substring(0, 48)}…' : trimmed;
  }

  Future<List<AdvisorConversation>> loadConversations({int limit = 50}) async {
    if (!canPersist) {
      return _localConversations.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    try {
      await _migrateLegacyIfNeeded();
      final snapshot = await _conversationsRef()!
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) => _conversationFromDoc(doc.id, doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<AdvisorConversation>> watchConversations({int limit = 50}) {
    if (!canPersist) {
      return Stream.value(_localConversations.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
    }

    return _conversationsRef()!
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _conversationFromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> createConversation({String? title}) async {
    final now = DateTime.now();
    final id = 'conv_${now.millisecondsSinceEpoch}';
    final conversation = AdvisorConversation(
      id: id,
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'محادثة جديدة',
      createdAt: now,
      updatedAt: now,
    );

    if (!canPersist) {
      _localConversations[id] = conversation;
      _localMessages[id] = [];
      return id;
    }

    try {
      await _conversationsRef()!.doc(id).set({
        'title': conversation.title,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    } catch (_) {}

    return id;
  }

  Future<List<AdvisorMessage>> loadMessages(
    String conversationId, {
    int limit = 200,
  }) async {
    if (!canPersist) {
      return List<AdvisorMessage>.from(_localMessages[conversationId] ?? []);
    }

    try {
      final snapshot = await _conversationsRef()!
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt')
          .limitToLast(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) => _messageFromDoc(doc.id, doc.data()))
          .where((message) => message.content.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessage({
    required String conversationId,
    required AdvisorMessage message,
    String? titleIfFirstUserMessage,
  }) async {
    final now = DateTime.now();

    if (!canPersist) {
      final list = _localMessages.putIfAbsent(conversationId, () => []);
      list.add(message);
      final meta = _localConversations[conversationId];
      if (meta != null) {
        _localConversations[conversationId] = AdvisorConversation(
          id: meta.id,
          title: titleIfFirstUserMessage != null
              ? _titleFromMessage(titleIfFirstUserMessage)
              : meta.title,
          createdAt: meta.createdAt,
          updatedAt: now,
        );
      }
      return;
    }

    try {
      final convRef = _conversationsRef()!.doc(conversationId);
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(now),
      };
      if (titleIfFirstUserMessage != null) {
        updates['title'] = _titleFromMessage(titleIfFirstUserMessage);
      }
      await convRef.set(updates, SetOptions(merge: true));

      await convRef.collection('messages').doc(message.id).set({
        ...message.toMap(),
        'createdAt': Timestamp.fromDate(message.createdAt),
      });
    } catch (_) {}
  }

  Future<void> deleteConversation(String conversationId) async {
    if (!canPersist) {
      _localConversations.remove(conversationId);
      _localMessages.remove(conversationId);
      return;
    }

    try {
      final convRef = _conversationsRef()!.doc(conversationId);
      final snapshot = await convRef.collection('messages').get();
      var batch = _db.batch();
      var count = 0;
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 400) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();
      await convRef.delete();
    } catch (_) {}
  }

  AdvisorConversation _conversationFromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final map = Map<String, dynamic>.from(data);
    for (final key in ['createdAt', 'updatedAt']) {
      final value = map[key];
      if (value is Timestamp) {
        map[key] = value.toDate().toIso8601String();
      }
    }
    return AdvisorConversation.fromMap(id, map);
  }

  AdvisorMessage _messageFromDoc(String id, Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final createdAt = map['createdAt'];
    if (createdAt is Timestamp) {
      map['createdAt'] = createdAt.toDate().toIso8601String();
    }
    return AdvisorMessage.fromMap(id, map);
  }

  Future<void> _migrateLegacyIfNeeded() async {
    final userRef = _userRef();
    if (userRef == null) return;

    final legacySnapshot = await userRef.collection('messages').limit(1).get();
    if (legacySnapshot.docs.isEmpty) return;

    const migrationId = 'legacy_chat';
    final migrationRef = userRef.collection('conversations').doc(migrationId);
    if ((await migrationRef.get()).exists) return;

    final allLegacy = await userRef.collection('messages').orderBy('createdAt').get();
    if (allLegacy.docs.isEmpty) return;

    String title = 'محادثة سابقة';
    for (final doc in allLegacy.docs) {
      final data = doc.data();
      if (data['role'] == 'user') {
        title = _titleFromMessage(data['content']?.toString() ?? '');
        break;
      }
    }

    final firstCreated = allLegacy.docs.first.data()['createdAt'];
    final lastCreated = allLegacy.docs.last.data()['createdAt'];
    final createdAt = firstCreated is Timestamp ? firstCreated.toDate() : DateTime.now();
    final updatedAt = lastCreated is Timestamp ? lastCreated.toDate() : DateTime.now();

    await migrationRef.set({
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    });

    var batch = _db.batch();
    var count = 0;
    for (final doc in allLegacy.docs) {
      batch.set(migrationRef.collection('messages').doc(doc.id), doc.data());
      batch.delete(doc.reference);
      count += 2;
      if (count >= 400) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }
}
