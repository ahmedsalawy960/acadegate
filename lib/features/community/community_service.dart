import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../home/home_search_utils.dart';
import '../moderation/approval_status.dart';
import '../profile/academic_profile_service.dart';
import 'community_data.dart';
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
    String? viewerFaculty,
    String? viewerSpecialization,
  }) {
    final queryIds = communityRoomQueryIds(roomId);
    final primaryId = queryIds.first;

    return _posts
        .where('roomId', isEqualTo: primaryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      var posts = snapshot.docs
          .map((doc) => CommunityPost.fromMap(doc.data(), id: doc.id))
          .toList();

      // Also pull legacy room id posts when the canonical id differs.
      if (queryIds.length > 1) {
        try {
          final legacySnap = await _posts
              .where('roomId', isEqualTo: queryIds[1])
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();
          final byId = {for (final p in posts) p.id ?? '': p};
          for (final doc in legacySnap.docs) {
            byId[doc.id] = CommunityPost.fromMap(doc.data(), id: doc.id);
          }
          posts = byId.values.toList()
            ..sort((a, b) {
              final aAt =
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bAt =
                  b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bAt.compareTo(aAt);
            });
        } catch (_) {
          // Ignore legacy query failures (missing index / empty).
        }
      }

      // Surface app-wide posts inside faculty rooms as well.
      if (normalizeCommunityRoomId(roomId) != 'general') {
        try {
          final appSnap = await _posts
              .where('audienceScope', isEqualTo: PostAudienceScope.app)
              .orderBy('createdAt', descending: true)
              .limit(30)
              .get();
          final byId = {for (final p in posts) if (p.id != null) p.id!: p};
          for (final doc in appSnap.docs) {
            byId[doc.id] = CommunityPost.fromMap(doc.data(), id: doc.id);
          }
          posts = byId.values.toList()
            ..sort((a, b) {
              final aAt =
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bAt =
                  b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bAt.compareTo(aAt);
            });
        } catch (_) {
          // Composite index may be missing until first deploy; room posts still work.
        }
      }

      return _filterPosts(
        posts,
        type: type,
        searchQuery: searchQuery,
        viewerFaculty: viewerFaculty,
        viewerSpecialization: viewerSpecialization,
      );
    });
  }

  List<CommunityPost> _filterPosts(
    List<CommunityPost> posts, {
    String? type,
    String searchQuery = '',
    String? viewerFaculty,
    String? viewerSpecialization,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return posts.where((post) {
      if (!post.isVisibleToViewer(
        viewerUid: uid,
        viewerFaculty: viewerFaculty,
        viewerSpecialization: viewerSpecialization,
      )) {
        return false;
      }
      if (type != null && type.isNotEmpty && post.type != type) {
        return false;
      }
      if (searchQuery.trim().isEmpty) return true;
      return homeSearchMatches(searchQuery, [
        post.title,
        post.body,
        post.authorName,
        post.targetSpecialization ?? '',
        ...post.tags,
      ]);
    }).toList();
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
    if (user == null) return appTr('طالب', 'Student');

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final doc = await _db.collection('users').doc(user.uid).get();
    final fromDoc = doc.data()?['displayName']?.toString().trim();
    if (fromDoc != null && fromDoc.isNotEmpty) return fromDoc;

    return user.email?.split('@').first ?? appTr('طالب', 'Student');
  }

  Future<String?> createPost({
    required String roomId,
    required String type,
    required String title,
    required String body,
    List<String> tags = const [],
    String? eventDate,
    String? university,
    String? academicLink,
    String? academicTitle,
    String audienceScope = PostAudienceScope.faculty,
    String? facultyCategory,
    String? targetSpecialization,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      return appTr('العنوان والمحتوى مطلوبان', 'Title and content are required');
    }

    final scope = PostAudienceScope.all.contains(audienceScope)
        ? audienceScope
        : PostAudienceScope.faculty;

    final specialization = targetSpecialization?.trim() ?? '';
    if (scope == PostAudienceScope.specialization && specialization.isEmpty) {
      return appTr(
        'حدد التخصص المستهدف للمنشور',
        'Enter the target specialization for this post',
      );
    }

    final profile = await AcademicProfileService.instance.loadProfile();
    final room = communityRoomById(roomId);
    final faculty = (facultyCategory?.trim().isNotEmpty == true)
        ? facultyCategory!.trim()
        : (room?.facultyCategoryId ??
            profile?.resolvedFacultyCategory ??
            '');

    // App-wide posts are stored under the general room for discovery.
    final storedRoomId = scope == PostAudienceScope.app
        ? 'general'
        : normalizeCommunityRoomId(roomId);

    final authorName = await resolveAuthorName();
    final link = academicLink?.trim() ?? '';
    final linkTitle = academicTitle?.trim() ?? '';

    await _posts.add({
      'roomId': storedRoomId,
      'type': type,
      'title': trimmedTitle,
      'body': trimmedBody,
      'authorId': user.uid,
      'authorName': authorName,
      'tags': tags,
      'upvotesCount': 0,
      'repliesCount': 0,
      'approvalStatus': ApprovalStatus.pending,
      'audienceScope': scope,
      if (faculty.isNotEmpty) 'facultyCategory': faculty,
      if (scope == PostAudienceScope.specialization)
        'targetSpecialization': specialization,
      if (eventDate != null && eventDate.isNotEmpty) 'eventDate': eventDate,
      if (university != null && university.isNotEmpty) 'university': university,
      if (link.isNotEmpty) 'academicLink': link,
      if (linkTitle.isNotEmpty) 'academicTitle': linkTitle,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return null;
  }

  Future<String?> addReply({
    required String postId,
    required String body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return appTr('اكتب رداً أولاً', 'Write a reply first');
    }

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
