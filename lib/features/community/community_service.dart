import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../moderation/approval_status.dart';
import 'community_models.dart';

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('community_posts');

  Stream<List<CommunityPost>> watchRoomPosts({
    required String roomId,
    String? type,
    String searchQuery = '',
  }) {
    return _posts
        .where('roomId', isEqualTo: roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final posts = snapshot.docs
          .map((doc) => CommunityPost.fromMap(doc.data(), id: doc.id))
          .where((post) {
        if (post.isPubliclyVisible) return true;
        if (uid != null && post.authorId == uid) return true;
        return false;
      }).where((post) {
        if (type == null || type.isEmpty) return true;
        return post.type == type;
      }).where((post) {
        if (searchQuery.trim().isEmpty) return true;
        final q = searchQuery.trim().toLowerCase();
        return post.title.toLowerCase().contains(q) ||
            post.body.toLowerCase().contains(q) ||
            post.authorName.toLowerCase().contains(q) ||
            post.tags.any((tag) => tag.toLowerCase().contains(q));
      }).toList();

      if (posts.isEmpty) {
        final fallback = fallbackCommunityPosts
            .where((post) => post.roomId == roomId)
            .where((post) => type == null || type.isEmpty || post.type == type)
            .where((post) {
          if (searchQuery.trim().isEmpty) return true;
          final q = searchQuery.trim().toLowerCase();
          return post.title.toLowerCase().contains(q) ||
              post.body.toLowerCase().contains(q) ||
              post.authorName.toLowerCase().contains(q) ||
              post.tags.any((tag) => tag.toLowerCase().contains(q));
        }).toList();
        return fallback;
      }

      return posts;
    });
  }

  Stream<CommunityPost?> watchPost(String postId) {
    return _posts.doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CommunityPost.fromMap(doc.data()!, id: doc.id);
    });
  }

  Stream<List<CommunityReply>> watchReplies(String postId) {
    return _posts
        .doc(postId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => CommunityReply.fromMap(
                  doc.data(),
                  id: doc.id,
                  postId: postId,
                ),
              )
              .toList(),
        );
  }

  Future<String> resolveAuthorName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'طالب';

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final doc = await _db.collection('users').doc(user.uid).get();
    final fromDoc = doc.data()?['displayName']?.toString().trim();
    if (fromDoc != null && fromDoc.isNotEmpty) return fromDoc;

    return user.email?.split('@').first ?? 'طالب';
  }

  Future<String?> createPost({
    required String roomId,
    required String type,
    required String title,
    required String body,
    List<String> tags = const [],
    String? eventDate,
    String? university,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'يجب تسجيل الدخول أولاً';

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      return 'العنوان والمحتوى مطلوبان';
    }

    final authorName = await resolveAuthorName();

    await _posts.add({
      'roomId': roomId,
      'type': type,
      'title': trimmedTitle,
      'body': trimmedBody,
      'authorId': user.uid,
      'authorName': authorName,
      'tags': tags,
      'upvotesCount': 0,
      'repliesCount': 0,
      'approvalStatus': ApprovalStatus.pending,
      if (eventDate != null && eventDate.isNotEmpty) 'eventDate': eventDate,
      if (university != null && university.isNotEmpty) 'university': university,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return null;
  }

  Future<String?> addReply({
    required String postId,
    required String body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'يجب تسجيل الدخول أولاً';

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) return 'اكتب رداً أولاً';

    final authorName = await resolveAuthorName();
    final postRef = _posts.doc(postId);
    final replyRef = postRef.collection('replies').doc();

    await _db.runTransaction((transaction) async {
      transaction.set(replyRef, {
        'authorId': user.uid,
        'authorName': authorName,
        'body': trimmedBody,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(postRef, {
        'repliesCount': FieldValue.increment(1),
      });
    });

    return null;
  }

  Future<bool> toggleUpvote(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final postRef = _posts.doc(postId);
    final voteRef = postRef.collection('upvotes').doc(user.uid);

    var upvoted = false;
    await _db.runTransaction((transaction) async {
      final voteSnap = await transaction.get(voteRef);
      if (voteSnap.exists) {
        transaction.delete(voteRef);
        transaction.update(postRef, {'upvotesCount': FieldValue.increment(-1)});
        upvoted = false;
      } else {
        transaction.set(voteRef, {
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'upvotesCount': FieldValue.increment(1)});
        upvoted = true;
      }
    });

    return upvoted;
  }

  Future<bool> hasUpvoted(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc =
        await _posts.doc(postId).collection('upvotes').doc(user.uid).get();
    return doc.exists;
  }
}
