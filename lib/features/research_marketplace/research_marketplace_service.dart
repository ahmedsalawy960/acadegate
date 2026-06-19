import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../academic/academic_models.dart';
import '../moderation/approval_status.dart';

class ResearchMarketplaceService {
  ResearchMarketplaceService._();

  static final ResearchMarketplaceService instance =
      ResearchMarketplaceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ideas =>
      _db.collection('research_ideas');

  Future<void> publishIdea({
    required String title,
    required String provider,
    required String details,
    required String budget,
    List<String> tags = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول لنشر فكرة بحثية');
    }

    await _ideas.add({
      'title': title,
      'provider': provider,
      'details': details,
      'budget': budget,
      'tags': tags,
      'status': 'open',
      'approvalStatus': ApprovalStatus.pending,
      'votesCount': 0,
      'proposalsCount': 0,
      'publisherId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<bool> hasUserVoted(String ideaId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return _ideas
        .doc(ideaId)
        .collection('votes')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> toggleVote(AcademicResearchIdea idea) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول للتصويت');
    }
    if (!idea.isFromFirebase) {
      throw Exception('التصويت متاح للأفكار المسجلة في Firebase فقط');
    }

    final ideaRef = _ideas.doc(idea.id);
    final voteRef = ideaRef.collection('votes').doc(user.uid);

    await _db.runTransaction((transaction) async {
      final voteSnap = await transaction.get(voteRef);
      if (voteSnap.exists) {
        transaction.delete(voteRef);
        transaction.update(ideaRef, {
          'votesCount': FieldValue.increment(-1),
        });
      } else {
        transaction.set(voteRef, {
          'votedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(ideaRef, {
          'votesCount': FieldValue.increment(1),
        });
      }
    });
  }

  Future<void> submitProposal({
    required AcademicResearchIdea idea,
    required String authorName,
    required String authorEmail,
    required String summary,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول لتقديم مقترح');
    }
    if (!idea.isFromFirebase) {
      throw Exception('التقديم متاح للأفكار المسجلة في Firebase فقط');
    }

    final wordCount = summary.trim().split(RegExp(r'\s+')).length;
    if (wordCount > 500) {
      throw Exception('المقترح يجب ألا يتجاوز 500 كلمة');
    }

    final ideaRef = _ideas.doc(idea.id);
    await ideaRef.collection('proposals').add({
      'authorName': authorName,
      'authorEmail': authorEmail,
      'userId': user.uid,
      'summary': summary.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await ideaRef.update({
      'proposalsCount': FieldValue.increment(1),
    });
  }

  Stream<List<ResearchProposal>> proposalsStream(String ideaId) {
    return _ideas
        .doc(ideaId)
        .collection('proposals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ResearchProposal.fromMap(
                  doc.data(),
                  id: doc.id,
                  ideaId: ideaId,
                ),
              )
              .toList(),
        );
  }

  Future<bool> isIdeaPublisher(String ideaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap = await _ideas.doc(ideaId).get();
    return snap.data()?['publisherId']?.toString() == user.uid;
  }

  Future<void> respondToProposal({
    required String ideaId,
    required String proposalId,
    required bool accept,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ideaRef = _ideas.doc(ideaId);
    final ideaSnap = await ideaRef.get();
    if (ideaSnap.data()?['publisherId'] != user.uid) {
      throw Exception('فقط ناشر الفكرة يمكنه إدارة المقترحات');
    }

    final proposalRef = ideaRef.collection('proposals').doc(proposalId);
    final proposalSnap = await proposalRef.get();
    if (!proposalSnap.exists) throw Exception('المقترح غير موجود');

    final newStatus = accept ? 'accepted' : 'rejected';
    await proposalRef.update({
      'status': newStatus,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    final proposerId = proposalSnap.data()?['userId']?.toString() ?? '';
    if (proposerId.isNotEmpty) {
      await _db.collection('notifications').add({
        'userId': proposerId,
        'title': accept ? 'تم قبول مقترحك' : 'تم رفض مقترحك',
        'body': ideaSnap.data()?['title']?.toString() ?? 'فكرة بحثية',
        'type': 'proposal',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
