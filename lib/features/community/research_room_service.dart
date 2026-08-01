import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../notifications/notification_service.dart';
import 'community_service.dart';
import 'research_room_models.dart';

class ResearchRoomService {
  ResearchRoomService._();

  static final ResearchRoomService instance = ResearchRoomService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('research_rooms');

  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    return sha256.convert(bytes).toString();
  }

  static String buildSearchText({
    required String title,
    required String body,
    List<String> tags = const [],
    List<String> replyBodies = const [],
  }) {
    return [
      title,
      body,
      ...tags,
      ...replyBodies,
    ].join(' ').toLowerCase();
  }

  Stream<List<ResearchRoom>> watchMyRooms() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _rooms
        .where('creatorId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ResearchRoom.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<ResearchRoom>> watchPublicRooms() {
    return _rooms
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ResearchRoom.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<ResearchRoom?> getRoom(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return null;
    return ResearchRoom.fromMap(doc.id, doc.data()!);
  }

  Future<bool> hasRoomAccess(String roomId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final room = await getRoom(roomId);
    if (room == null) return false;
    if (!room.isPasswordProtected) return true;
    if (room.creatorId == user.uid) return true;

    final member = await _rooms
        .doc(roomId)
        .collection('members')
        .doc(user.uid)
        .get();
    return member.exists;
  }

  Future<String?> unlockRoom({
    required String roomId,
    required String password,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }

    final room = await getRoom(roomId);
    if (room == null) {
      return appTr('الغرفة غير موجودة', 'Room not found');
    }
    if (!room.isPasswordProtected) return null;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'joinResearchRoom',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call<Map<String, dynamic>>({
        'roomId': roomId,
        'password': password,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        return appTr('كلمة المرور غير صحيحة', 'Incorrect password');
      }
      if (e.code == 'not-found') {
        return appTr('الغرفة غير موجودة', 'Room not found');
      }
      if (e.code == 'unauthenticated') {
        return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
      }
      return e.message ??
          appTr('تعذر الدخول للغرفة', 'Could not enter the room');
    } catch (_) {
      // احتياطي محلي للغرف القديمة إن لم تُنشر الدالة بعد
      if (room.passwordHash != null &&
          hashPassword(password) == room.passwordHash) {
        await _rooms.doc(roomId).collection('members').doc(user.uid).set({
          'grantedAt': FieldValue.serverTimestamp(),
          'method': 'legacy',
          'role': 'member',
        });
        return null;
      }
      return appTr(
        'تعذر التحقق — انشر Cloud Function joinResearchRoom',
        'Verification failed — deploy Cloud Function joinResearchRoom',
      );
    }
  }

  /// Returns `(error: null, roomId: id)` on success for open rooms.
  /// Password-protected rooms via Cloud Function may return `roomId: null`.
  Future<({String? error, String? roomId})> createRoom({
    required String title,
    required String description,
    String? categoryId,
    bool isPasswordProtected = false,
    String? password,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return (
        error: appTr('يجب تسجيل الدخول لإنشاء غرفة', 'Sign in to create a room'),
        roomId: null,
      );
    }

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return (
        error: appTr('اسم الغرفة مطلوب', 'Room name is required'),
        roomId: null,
      );
    }

    if (isPasswordProtected) {
      final pass = password?.trim() ?? '';
      if (pass.length < 4) {
        return (
          error: appTr(
            'كلمة المرور يجب أن تكون 4 أحرف على الأقل',
            'Password must be at least 4 characters',
          ),
          roomId: null,
        );
      }
    }

    final authorName = await CommunityService.instance.resolveAuthorName();

    if (isPasswordProtected) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'createResearchRoom',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        );
        final result = await callable.call<Map<String, dynamic>>({
          'title': trimmedTitle,
          'description': description.trim(),
          if (categoryId != null && categoryId.isNotEmpty)
            'categoryId': categoryId,
          'isPasswordProtected': true,
          'password': password!.trim(),
          'creatorName': authorName,
        });
        final data = result.data;
        final roomId = data['roomId']?.toString();
        if (roomId != null && roomId.isNotEmpty) {
          await ensureDefaultChannels(roomId);
        }
        return (error: null, roomId: roomId);
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'unauthenticated') {
          return (
            error: appTr(
              'يجب تسجيل الدخول لإنشاء غرفة',
              'Sign in to create a room',
            ),
            roomId: null,
          );
        }
        return (
          error: e.message ??
              appTr('تعذر إنشاء الغرفة المحمية', 'Could not create protected room'),
          roomId: null,
        );
      } catch (_) {
        return (
          error: appTr(
            'تعذر إنشاء الغرفة — تأكد من نشر createResearchRoom',
            'Could not create room — ensure createResearchRoom is deployed',
          ),
          roomId: null,
        );
      }
    }

    final roomRef = await _rooms.add({
      'title': trimmedTitle,
      'description': description.trim(),
      'creatorId': user.uid,
      'creatorName': authorName,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      'isPasswordProtected': false,
      'discussionsCount': 0,
      'membersCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await roomRef.collection('members').doc(user.uid).set({
      'role': 'owner',
      'grantedAt': FieldValue.serverTimestamp(),
      'method': 'create',
    });
    await ensureDefaultChannels(roomRef.id);

    return (error: null, roomId: roomRef.id);
  }

  Future<void> ensureDefaultChannels(String roomId) async {
    try {
      final channels = _rooms.doc(roomId).collection('channels');
      final existing = await channels.limit(1).get();
      if (existing.docs.isNotEmpty) return;

      final batch = _db.batch();
      for (final channel in ResearchRoomChannel.defaults) {
        batch.set(channels.doc(channel.id), {
          'nameAr': channel.nameAr,
          'nameEn': channel.nameEn,
          'sortOrder': channel.sortOrder,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      // Rules/index may be missing; chat UI falls back to default labels.
    }
  }

  Future<void> ensureMemberRole({
    required String roomId,
    required String role,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final normalized = _normalizeRole(role);
      final ref = _rooms.doc(roomId).collection('members').doc(user.uid);
      final snap = await ref.get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        if ((data['role']?.toString() ?? '').isEmpty) {
          await ref.set({'role': normalized}, SetOptions(merge: true));
        }
        return;
      }
      await ref.set({
        'role': normalized,
        'grantedAt': FieldValue.serverTimestamp(),
        'method': 'open',
      });
      try {
        await _rooms.doc(roomId).set(
          {'membersCount': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      } catch (_) {
        // Optional room meta bump.
      }
    } catch (_) {
      // Membership bootstrap must never crash room entry.
    }
  }

  static String _normalizeRole(String role) {
    if (role == 'owner' || role == 'moderator' || role == 'member') {
      return role;
    }
    return 'member';
  }

  Stream<List<ResearchRoomMember>> watchRoomMembers(String roomId) async* {
    try {
      await for (final snapshot
          in _rooms.doc(roomId).collection('members').snapshots()) {
        final members = snapshot.docs
            .map((doc) => ResearchRoomMember.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) {
            int rank(String role) => switch (role) {
                  'owner' => 0,
                  'moderator' => 1,
                  _ => 2,
                };
            final byRole = rank(a.role).compareTo(rank(b.role));
            if (byRole != 0) return byRole;
            return a.uid.compareTo(b.uid);
          });
        yield members;
      }
    } catch (_) {
      yield const <ResearchRoomMember>[];
    }
  }

  Future<String?> setMemberRole({
    required String roomId,
    required String memberId,
    required String role,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }
    final roomSnap = await _rooms.doc(roomId).get();
    if (!roomSnap.exists || roomSnap.data()?['creatorId'] != user.uid) {
      return appTr(
        'المالك فقط يمكنه تغيير الأدوار',
        'Only the room owner can change roles',
      );
    }
    final normalized = _normalizeRole(role);
    if (normalized == 'owner' && memberId != user.uid) {
      return appTr(
        'لا يمكن نقل ملكية الغرفة من هنا',
        'Room ownership cannot be transferred here',
      );
    }
    await _rooms.doc(roomId).collection('members').doc(memberId).set(
      {'role': normalized},
      SetOptions(merge: true),
    );
    return null;
  }

  Stream<List<ResearchRoom>> watchJoinedRooms() {
    // collectionGroup + documentId equality often lacks an index and has caused
    // native Windows process exits. Keep this feed empty until a safer query
    // (Cloud Function / stored roomIds on the user doc) is available.
    return Stream.value(const []);
  }

  Stream<List<ResearchRoomChannel>> watchChannels(String roomId) async* {
    try {
      await for (final snapshot in _rooms
          .doc(roomId)
          .collection('channels')
          .orderBy('sortOrder')
          .snapshots()) {
        yield snapshot.docs
            .map((doc) => ResearchRoomChannel.fromMap(doc.id, doc.data()))
            .toList();
      }
    } catch (_) {
      yield ResearchRoomChannel.defaults;
    }
  }

  Stream<List<ResearchChannelMessage>> watchChannelMessages({
    required String roomId,
    required String channelId,
  }) async* {
    try {
      await for (final snapshot in _rooms
          .doc(roomId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()) {
        final items = snapshot.docs
            .map(
              (doc) => ResearchChannelMessage.fromMap(
                doc.id,
                doc.data(),
                channelId: channelId,
              ),
            )
            .toList();
        yield items.reversed.toList();
      }
    } catch (_) {
      yield const <ResearchChannelMessage>[];
    }
  }

  Future<String?> sendChannelMessage({
    required String roomId,
    required String channelId,
    required String text,
    String? academicLink,
    String? academicTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }

    final hasAccess = await hasRoomAccess(roomId);
    if (!hasAccess) {
      return appTr(
        'لا تملك صلاحية الدخول لهذه الغرفة',
        'You do not have access to this room',
      );
    }

    final trimmed = text.trim();
    final link = academicLink?.trim() ?? '';
    if (trimmed.isEmpty && link.isEmpty) {
      return appTr('اكتب رسالة أولاً', 'Write a message first');
    }

    await ensureDefaultChannels(roomId);
    final authorName = await CommunityService.instance.resolveAuthorName();
    final room = await getRoom(roomId);
    final matched = ResearchRoomChannel.defaults.where((c) => c.id == channelId);
    final channelLabel =
        matched.isEmpty ? channelId : matched.first.nameAr;

    await _rooms
        .doc(roomId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .add({
      'authorId': user.uid,
      'authorName': authorName,
      'text': trimmed,
      if (link.isNotEmpty) 'academicLink': link,
      if ((academicTitle ?? '').trim().isNotEmpty)
        'academicTitle': academicTitle!.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _rooms.doc(roomId).set({
      'lastChannelActivity': trimmed.isNotEmpty
          ? trimmed
          : (academicTitle?.trim().isNotEmpty == true
              ? academicTitle!.trim()
              : link),
      'lastActivityAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (room != null &&
        room.creatorId.isNotEmpty &&
        room.creatorId != user.uid) {
      await NotificationService.instance.send(
        userId: room.creatorId,
        title: appTr('رسالة جديدة في غرفتك', 'New message in your room'),
        body: appTr(
          '$authorName في #$channelLabel: ${trimmed.isEmpty ? link : trimmed}',
          '$authorName in #$channelLabel: ${trimmed.isEmpty ? link : trimmed}',
        ),
        type: 'research_room_chat',
        contextId: roomId,
        contextType: 'research_room',
      );
    }

    return null;
  }

  Stream<List<ResearchDiscussion>> watchDiscussions({
    required String roomId,
    String searchQuery = '',
  }) async* {
    try {
      await for (final snapshot in _rooms
          .doc(roomId)
          .collection('discussions')
          .orderBy('createdAt', descending: true)
          .snapshots()) {
        final items = snapshot.docs
            .map((doc) => ResearchDiscussion.fromMap(doc.id, doc.data()))
            .toList();
        if (searchQuery.trim().isEmpty) {
          yield items;
        } else {
          yield items.where((item) => item.matchesQuery(searchQuery)).toList();
        }
      }
    } catch (_) {
      yield const <ResearchDiscussion>[];
    }
  }

  Stream<ResearchDiscussion?> watchDiscussion({
    required String roomId,
    required String discussionId,
  }) {
    return _rooms
        .doc(roomId)
        .collection('discussions')
        .doc(discussionId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ResearchDiscussion.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<ResearchDiscussionReply>> watchReplies({
    required String roomId,
    required String discussionId,
  }) {
    return _rooms
        .doc(roomId)
        .collection('discussions')
        .doc(discussionId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ResearchDiscussionReply.fromMap(
                  doc.id,
                  doc.data(),
                  discussionId: discussionId,
                ),
              )
              .toList(),
        );
  }

  Future<String?> createDiscussion({
    required String roomId,
    required String type,
    required String title,
    required String body,
    List<String> tags = const [],
    String? academicLink,
    String? academicTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }

    final hasAccess = await hasRoomAccess(roomId);
    if (!hasAccess) {
      return appTr(
        'لا تملك صلاحية الدخول لهذه الغرفة',
        'You do not have access to this room',
      );
    }

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      return appTr('العنوان والمحتوى مطلوبان', 'Title and content are required');
    }

    final authorName = await CommunityService.instance.resolveAuthorName();
    final link = academicLink?.trim() ?? '';
    final linkTitle = academicTitle?.trim() ?? '';
    final searchText = buildSearchText(
      title: trimmedTitle,
      body: trimmedBody,
      tags: [...tags, if (linkTitle.isNotEmpty) linkTitle, if (link.isNotEmpty) link],
    );

    final roomRef = _rooms.doc(roomId);
    final discussionRef = roomRef.collection('discussions').doc();

    await _db.runTransaction((transaction) async {
      transaction.set(discussionRef, {
        'roomId': roomId,
        'type': type,
        'title': trimmedTitle,
        'body': trimmedBody,
        'authorId': user.uid,
        'authorName': authorName,
        'tags': tags,
        'searchText': searchText,
        if (link.isNotEmpty) 'academicLink': link,
        if (linkTitle.isNotEmpty) 'academicTitle': linkTitle,
        'repliesCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(roomRef, {
        'discussionsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return null;
  }

  Future<String?> addReply({
    required String roomId,
    required String discussionId,
    required String body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }

    final hasAccess = await hasRoomAccess(roomId);
    if (!hasAccess) {
      return appTr(
        'لا تملك صلاحية الدخول لهذه الغرفة',
        'You do not have access to this room',
      );
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return appTr('اكتب رداً أولاً', 'Write a reply first');
    }

    final authorName = await CommunityService.instance.resolveAuthorName();
    final room = await getRoom(roomId);
    final discussionRef =
        _rooms.doc(roomId).collection('discussions').doc(discussionId);
    final discussionSnap = await discussionRef.get();
    if (!discussionSnap.exists) {
      return appTr('المناقشة غير موجودة', 'Discussion not found');
    }

    final discussionData = discussionSnap.data()!;
    final discussionAuthorId = discussionData['authorId']?.toString() ?? '';
    final discussionTitle = discussionData['title']?.toString() ??
        appTr('مناقشة', 'Discussion');

    final repliesSnap = await discussionRef.collection('replies').get();
    final replyBodies = repliesSnap.docs
        .map((doc) => doc.data()['body']?.toString() ?? '')
        .toList()
      ..add(trimmedBody);

    final searchText = buildSearchText(
      title: discussionData['title']?.toString() ?? '',
      body: discussionData['body']?.toString() ?? '',
      tags: (discussionData['tags'] as List<dynamic>?)
              ?.map((tag) => tag.toString())
              .toList() ??
          const [],
      replyBodies: replyBodies,
    );

    final replyRef = discussionRef.collection('replies').doc();

    await _db.runTransaction((transaction) async {
      transaction.set(replyRef, {
        'authorId': user.uid,
        'authorName': authorName,
        'body': trimmedBody,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(discussionRef, {
        'repliesCount': FieldValue.increment(1),
        'searchText': searchText,
      });
      transaction.update(_rooms.doc(roomId), {
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (room != null &&
        room.creatorId.isNotEmpty &&
        room.creatorId != user.uid) {
      await NotificationService.instance.send(
        userId: room.creatorId,
        title: appTr('رد جديد في غرفتك البحثية', 'New reply in your research room'),
        body: appTr(
          '$authorName رد في «$discussionTitle» — ${room.title}',
          '$authorName replied in "$discussionTitle" — ${room.title}',
        ),
        type: 'research_room_reply',
        contextId: roomId,
        contextType: 'research_room',
      );
    }

    if (discussionAuthorId.isNotEmpty &&
        discussionAuthorId != user.uid &&
        discussionAuthorId != room?.creatorId) {
      await NotificationService.instance.send(
        userId: discussionAuthorId,
        title: appTr('رد جديد على مناقشتك', 'New reply on your discussion'),
        body: appTr(
          '$authorName رد في «$discussionTitle»',
          '$authorName replied in "$discussionTitle"',
        ),
        type: 'research_discussion_reply',
        contextId: roomId,
        contextType: 'research_room',
      );
    }

    return null;
  }
}
