import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../academic/academic_models.dart';
import '../moderation/approval_status.dart';
import '../profile/academic_profile_service.dart';
import '../research_journey/research_journey_service.dart';
import '../research_journey/research_journey_stage.dart';

class ResearchMarketplaceService {
  ResearchMarketplaceService._();

  static final ResearchMarketplaceService instance =
      ResearchMarketplaceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ideas =>
      _db.collection('research_ideas');

  Future<AcademicResearchIdea?> getIdeaById(String ideaId) async {
    if (ideaId.isEmpty) return null;
    final snap = await _ideas.doc(ideaId).get();
    if (!snap.exists || snap.data() == null) return null;
    return AcademicResearchIdea.fromMap(snap.data()!, id: snap.id);
  }

  Future<void> publishIdea({
    required String title,
    required String provider,
    required String details,
    required String budget,
    List<String> tags = const [],
    String category = '',
    bool autoApprove = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr(
        'يجب تسجيل الدخول لنشر فكرة بحثية',
        'Sign in to publish a research idea',
      ));
    }

    await _ideas.add({
      'title': title,
      'provider': provider,
      'details': details,
      'budget': budget,
      'tags': tags,
      if (category.isNotEmpty) 'category': category,
      'status': 'open',
      'approvalStatus':
          autoApprove ? ApprovalStatus.approved : ApprovalStatus.pending,
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
      throw Exception(appTr('يجب تسجيل الدخول للتصويت', 'Sign in to vote'));
    }
    if (!idea.isFromFirebase) {
      throw Exception(appTr(
        'التصويت متاح للأفكار المسجلة في Firebase فقط',
        'Voting is only available for ideas stored in Firebase',
      ));
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
      throw Exception(appTr(
        'يجب تسجيل الدخول لتقديم مقترح',
        'Sign in to submit a proposal',
      ));
    }
    if (!idea.isFromFirebase) {
      throw Exception(appTr(
        'التقديم متاح للأفكار المسجلة في Firebase فقط',
        'Submission is only available for ideas stored in Firebase',
      ));
    }

    final wordCount = summary.trim().split(RegExp(r'\s+')).length;
    if (wordCount > 500) {
      throw Exception(appTr(
        'المقترح يجب ألا يتجاوز 500 كلمة',
        'Proposal must not exceed 500 words',
      ));
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
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }

    final ideaRef = _ideas.doc(ideaId);
    final ideaSnap = await ideaRef.get();
    if (ideaSnap.data()?['publisherId'] != user.uid) {
      throw Exception(appTr(
        'فقط ناشر الفكرة يمكنه إدارة المقترحات',
        'Only the idea publisher can manage proposals',
      ));
    }

    final proposalRef = ideaRef.collection('proposals').doc(proposalId);
    final proposalSnap = await proposalRef.get();
    if (!proposalSnap.exists) {
      throw Exception(appTr('المقترح غير موجود', 'Proposal not found'));
    }

    final newStatus = accept ? 'accepted' : 'rejected';
    await proposalRef.update({
      'status': newStatus,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    final proposerId = proposalSnap.data()?['userId']?.toString() ?? '';
    if (proposerId.isNotEmpty) {
      await _db.collection('notifications').add({
        'userId': proposerId,
        'title': accept
            ? appTr('تم قبول مقترحك', 'Your proposal was accepted')
            : appTr('تم رفض مقترحك', 'Your proposal was rejected'),
        'body': ideaSnap.data()?['title']?.toString() ??
            appTr('فكرة بحثية', 'Research idea'),
        'type': 'proposal',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> claimIdea(AcademicResearchIdea idea) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr(
        'يجب تسجيل الدخول لاختيار الموضوع',
        'Sign in to claim this topic',
      ));
    }
    if (!idea.isFromFirebase) {
      throw Exception(appTr(
        'الحجز متاح للأفكار المسجلة في Firebase فقط',
        'Claiming is only available for ideas stored in Firebase',
      ));
    }
    if (!idea.isAvailableForClaim) {
      if (idea.claimedBy == user.uid) {
        throw Exception(appTr(
          'أنت من اختار هذا الموضوع مسبقاً',
          'You already claimed this topic',
        ));
      }
      throw Exception(appTr(
        'هذا الموضوع محجوز أو مغلق',
        'This topic is already claimed or closed',
      ));
    }

    final profile = await AcademicProfileService.instance.loadProfile();
    final claimerName = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName.trim()
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email ?? appTr('طالب', 'Student'));

    final ideaRef = _ideas.doc(idea.id);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ideaRef);
      final data = snap.data();
      if (data == null) {
        throw Exception(appTr('الفكرة غير موجودة', 'Idea not found'));
      }

      final currentClaimer = data['claimedBy']?.toString() ?? '';
      final status = data['status']?.toString() ?? 'open';
      if (currentClaimer.isNotEmpty || status.toLowerCase() == 'claimed') {
        final name = data['claimedByName']?.toString() ?? '';
        throw Exception(appTr(
          'تم اختيار هذا الموضوع${name.isNotEmpty ? ' من $name' : ''}',
          'This topic was already claimed${name.isNotEmpty ? ' by $name' : ''}',
        ));
      }
      if (status.toLowerCase() != 'open') {
        throw Exception(appTr('الموضوع مغلق', 'Topic is closed'));
      }

      transaction.update(ideaRef, {
        'status': 'claimed',
        'claimedBy': user.uid,
        'claimedByName': claimerName,
        'claimedAt': FieldValue.serverTimestamp(),
      });
    });

    if (profile != null) {
      await AcademicProfileService.instance.saveProfile(
        profile.copyWith(researchInterest: idea.title),
      );
    }

    await ResearchJourneyService.instance.setStage(
      ResearchJourneyStage.choosingTopic,
    );
  }

  Future<void> releaseIdea(AcademicResearchIdea idea) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }
    if (!idea.isFromFirebase) return;

    final ideaRef = _ideas.doc(idea.id);
    final snap = await ideaRef.get();
    final data = snap.data();
    if (data == null) return;

    final claimer = data['claimedBy']?.toString() ?? '';
    final publisher = data['publisherId']?.toString() ?? '';
    if (claimer != user.uid && publisher != user.uid) {
      throw Exception(appTr(
        'فقط صاحب الحجز أو ناشر الفكرة يمكنه إلغاء الحجز',
        'Only the claimer or idea publisher can release the claim',
      ));
    }

    await ideaRef.update({
      'status': 'open',
      'claimedBy': '',
      'claimedByName': '',
      'claimedAt': FieldValue.delete(),
    });
  }
}
