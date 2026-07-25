import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../profile/academic_profile_service.dart';
import '../research_journey/research_journey_service.dart';
import '../research_journey/research_journey_stage.dart';

class ResearchTopicClaim {
  final String id;
  final String topicTitle;
  final String university;
  final String claimedBy;
  final String claimedByName;
  final String? ideaId;
  final DateTime? claimedAt;

  const ResearchTopicClaim({
    required this.id,
    required this.topicTitle,
    this.university = '',
    required this.claimedBy,
    required this.claimedByName,
    this.ideaId,
    this.claimedAt,
  });

  factory ResearchTopicClaim.fromMap(Map<String, dynamic> map, {required String id}) {
    return ResearchTopicClaim(
      id: id,
      topicTitle: map['topicTitle']?.toString() ?? '',
      university: map['university']?.toString() ?? '',
      claimedBy: map['claimedBy']?.toString() ?? '',
      claimedByName: map['claimedByName']?.toString() ?? '',
      ideaId: map['ideaId']?.toString(),
      claimedAt: _parseClaimDate(map['claimedAt']),
    );
  }
}

DateTime? _parseClaimDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

class ResearchTopicClaimService {
  ResearchTopicClaimService._();

  static final ResearchTopicClaimService instance = ResearchTopicClaimService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _claims =>
      _db.collection('topic_claims');

  String normalizeTopic(String topic) {
    return topic
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[،,؛;]+'), ' ');
  }

  String customClaimDocId({
    required String topicTitle,
    required String university,
  }) {
    final scope = university.trim().isEmpty
        ? 'global'
        : normalizeTopic(university);
    final normalized = normalizeTopic(topicTitle);
    final digest = sha256.convert(utf8.encode('$scope::$normalized')).toString();
    return 'custom_${digest.substring(0, 24)}';
  }

  Future<ResearchTopicClaim?> lookupCustomTopic({
    required String topicTitle,
    String university = '',
  }) async {
    final docId = customClaimDocId(
      topicTitle: topicTitle,
      university: university,
    );
    final snap = await _claims.doc(docId).get();
    if (!snap.exists || snap.data() == null) return null;
    return ResearchTopicClaim.fromMap(snap.data()!, id: snap.id);
  }

  Stream<ResearchTopicClaim?> watchCustomTopic({
    required String topicTitle,
    String university = '',
  }) {
    final docId = customClaimDocId(
      topicTitle: topicTitle,
      university: university,
    );
    return _claims.doc(docId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ResearchTopicClaim.fromMap(snap.data()!, id: snap.id);
    });
  }

  Future<void> claimCustomTopic({
    required String topicTitle,
    String university = '',
    String? ideaId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr(
        'يجب تسجيل الدخول لحجز موضوع بحث',
        'Sign in to claim a research topic',
      ));
    }

    final title = topicTitle.trim();
    if (title.length < 3) {
      throw Exception(appTr(
        'اكتب موضوعاً أوضح (3 أحرف على الأقل)',
        'Enter a clearer topic (at least 3 characters)',
      ));
    }

    final profile = await AcademicProfileService.instance.loadProfile();
    final claimerName = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName.trim()
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email ?? appTr('طالب', 'Student'));

    final uni = university.trim().isNotEmpty
        ? university.trim()
        : (profile?.university.trim() ?? '');

    final docId = ideaId?.isNotEmpty == true
        ? 'idea_$ideaId'
        : customClaimDocId(topicTitle: title, university: uni);

    final claimRef = _claims.doc(docId);

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(claimRef);
      if (existing.exists) {
        final owner = existing.data()?['claimedBy']?.toString() ?? '';
        if (owner.isNotEmpty && owner != user.uid) {
          final ownerName =
              existing.data()?['claimedByName']?.toString() ?? '';
          throw Exception(appTr(
            'هذا الموضوع محجوز بالفعل${ownerName.isNotEmpty ? ' لـ $ownerName' : ''}',
            'This topic is already claimed${ownerName.isNotEmpty ? ' by $ownerName' : ''}',
          ));
        }
        if (owner == user.uid) return;
      }

      transaction.set(claimRef, {
        'topicTitle': title,
        'university': uni,
        'claimedBy': user.uid,
        'claimedByName': claimerName,
        if (ideaId != null && ideaId.isNotEmpty) 'ideaId': ideaId,
        'claimedAt': FieldValue.serverTimestamp(),
      });
    });

    if (profile != null) {
      await AcademicProfileService.instance.saveProfile(
        profile.copyWith(researchInterest: title),
      );
    }

    await ResearchJourneyService.instance.setStage(
      ResearchJourneyStage.choosingTopic,
    );
  }

  Future<void> releaseCustomTopic({
    required String topicTitle,
    String university = '',
    String? ideaId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }

    final uni = university.trim();
    final docId = ideaId?.isNotEmpty == true
        ? 'idea_$ideaId'
        : customClaimDocId(topicTitle: topicTitle, university: uni);

    final snap = await _claims.doc(docId).get();
    if (!snap.exists) return;

    final owner = snap.data()?['claimedBy']?.toString() ?? '';
    if (owner != user.uid) {
      throw Exception(appTr(
        'لا يمكنك إلغاء حجز موضوع ليس ملكك',
        'You cannot release a topic you did not claim',
      ));
    }

    await _claims.doc(docId).delete();
  }
}
