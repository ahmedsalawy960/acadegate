
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/offline/local_profile_store.dart';
import 'academic_profile.dart';

class AcademicProfileService {
  AcademicProfileService._();

  static final AcademicProfileService instance = AcademicProfileService._();

  AcademicProfile? _cachedProfile;
  final _local = LocalProfileStore.instance;

  Future<AcademicProfile?> loadProfile() async {
    if (_cachedProfile != null) return _cachedProfile;

    final offline = await _local.loadProfile();
    if (offline != null) {
      _cachedProfile = offline;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _cachedProfile;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final remote = AcademicProfile.fromMap(doc.data()!);
        _cachedProfile = _pickNewer(offline, remote);
        await _local.saveProfile(_cachedProfile!);
      }
    } catch (_) {
      // Keep offline copy on weak network.
    }

    return _cachedProfile;
  }

  AcademicProfile? _pickNewer(AcademicProfile? offline, AcademicProfile remote) {
    if (offline == null) return remote;
    // Prefer remote when online; offline is fallback only.
    return remote;
  }

  Future<void> saveProfile(AcademicProfile profile) async {
    _cachedProfile = profile;
    await _local.saveProfile(profile);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(user.uid)
          .set(profile.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Saved locally — will sync on next successful save.
    }
  }

  void saveSessionProfile(AcademicProfile profile) {
    _cachedProfile = profile;
    _local.saveProfile(profile);
  }

  AcademicProfile? get sessionProfile => _cachedProfile;

  void clearCache() {
    _cachedProfile = null;
    _local.clearAllSessionData();
  }

  Future<void> deleteProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('student_profiles')
            .doc(user.uid)
            .delete();
      } catch (_) {}
    }
    clearCache();
  }
}
