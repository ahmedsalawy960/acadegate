import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../academic/faculty_categories.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import 'community_service.dart';
import 'research_room_service.dart';
import 'study_circle_models.dart';

class StudyCircleService {
  StudyCircleService._();

  static final StudyCircleService instance = StudyCircleService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _circles =>
      _db.collection('study_circles');

  Stream<List<StudyCircle>> watchCircles({String? facultyCategory}) {
    return _circles
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snap) {
      var circles = snap.docs
          .map((doc) => StudyCircle.fromMap(doc.id, doc.data()))
          .toList();
      if (facultyCategory != null && facultyCategory.isNotEmpty) {
        circles = circles
            .where((c) => c.facultyCategory == facultyCategory)
            .toList();
      }
      return circles;
    });
  }

  Future<List<StudyCircle>> suggestForProfile(AcademicProfile? profile) async {
    final all = await _circles
        .orderBy('createdAt', descending: true)
        .limit(80)
        .get();
    final circles = all.docs
        .map((doc) => StudyCircle.fromMap(doc.id, doc.data()))
        .toList();
    if (profile == null) return circles.take(8).toList();

    final faculty = profile.resolvedFacultyCategory ?? '';
    final keywords = profile.keywords.map((k) => k.toLowerCase()).toList();

    int score(StudyCircle c) {
      var s = 0;
      if (faculty.isNotEmpty && c.facultyCategory == faculty) s += 40;
      final text =
          '${c.title} ${c.specialization} ${c.researchInterest}'.toLowerCase();
      for (final kw in keywords) {
        if (kw.length >= 3 && text.contains(kw)) s += 10;
      }
      s += c.membersCount.clamp(0, 20);
      return s;
    }

    circles.sort((a, b) => score(b).compareTo(score(a)));
    final matched = circles.where((c) => score(c) > 0).take(10).toList();
    if (matched.isNotEmpty) return matched;
    return circles.take(8).toList();
  }

  Future<String?> createCircle({
    required String title,
    required String description,
    required String facultyCategory,
    required String specialization,
    required String researchInterest,
    bool createLinkedRoom = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return appTr('اسم الدائرة مطلوب', 'Circle name is required');
    }

    final authorName = await CommunityService.instance.resolveAuthorName();
    String? roomId;
    if (createLinkedRoom) {
      final roomResult = await ResearchRoomService.instance.createRoom(
        title: appTr('غرفة: $trimmed', 'Room: $trimmed'),
        description: description.trim().isEmpty
            ? appTr(
                'غرفة مرتبطة بدائرة دراسة «$trimmed»',
                'Room linked to study circle "$trimmed"',
              )
            : description.trim(),
        categoryId: facultyCategory.isEmpty ? null : facultyCategory,
        isPasswordProtected: false,
      );
      if (roomResult.error != null) return roomResult.error;
      roomId = roomResult.roomId;
    }

    final ref = await _circles.add({
      'title': trimmed,
      'description': description.trim(),
      'facultyCategory': facultyCategory,
      'specialization': specialization.trim(),
      'researchInterest': researchInterest.trim(),
      'creatorId': user.uid,
      'creatorName': authorName,
      'researchRoomId': ?roomId,
      'membersCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await ref.collection('members').doc(user.uid).set({
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return null;
  }

  Future<String?> joinCircle(StudyCircle circle) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return appTr('يجب تسجيل الدخول أولاً', 'You must sign in first');
    }

    final memberRef = _circles.doc(circle.id).collection('members').doc(user.uid);
    final existing = await memberRef.get();
    if (!existing.exists) {
      await memberRef.set({
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      await _circles.doc(circle.id).set(
        {
          'membersCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final roomId = circle.researchRoomId;
    if (roomId != null && roomId.isNotEmpty) {
      await ResearchRoomService.instance.ensureMemberRole(
        roomId: roomId,
        role: 'member',
      );
      await ResearchRoomService.instance.ensureDefaultChannels(roomId);
    }

    return null;
  }

  Future<StudyCircle?> getCircle(String id) async {
    final doc = await _circles.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return StudyCircle.fromMap(doc.id, doc.data()!);
  }

  Future<AcademicProfile?> currentProfile() {
    return AcademicProfileService.instance.loadProfile();
  }

  String facultyLabel(String facultyId) {
    if (facultyId.isEmpty) return appTr('عام', 'General');
    return facultyTitleForCategory(facultyId);
  }
}
