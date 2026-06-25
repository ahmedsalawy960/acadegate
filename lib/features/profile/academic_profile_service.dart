import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'academic_profile.dart';

class AcademicProfileService {
  AcademicProfileService._();

  static final AcademicProfileService instance = AcademicProfileService._();

  AcademicProfile? _cachedProfile;

  Future<AcademicProfile?> loadProfile() async {
    if (_cachedProfile != null) return _cachedProfile;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _cachedProfile;

    final doc = await FirebaseFirestore.instance
        .collection('student_profiles')
        .doc(user.uid)
        .get();

    if (!doc.exists || doc.data() == null) return null;

    _cachedProfile = AcademicProfile.fromMap(doc.data()!);
    return _cachedProfile;
  }

  Future<void> saveProfile(AcademicProfile profile) async {
    _cachedProfile = profile;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('student_profiles')
        .doc(user.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// حفظ مؤقت للجلسة الحالية حتى بدون تسجيل دخول.
  void saveSessionProfile(AcademicProfile profile) {
    _cachedProfile = profile;
  }

  AcademicProfile? get sessionProfile => _cachedProfile;

  void clearCache() {
    _cachedProfile = null;
  }

  Future<void> deleteProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(user.uid)
          .delete();
    }
    clearCache();
  }
}
