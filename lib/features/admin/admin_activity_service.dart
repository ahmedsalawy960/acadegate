import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Admin-visible audit trail of logins and important app movements.
class AdminActivityService {
  AdminActivityService._();

  static final AdminActivityService instance = AdminActivityService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('admin_activity');

  static const login = 'login';
  static const register = 'register';
  static const logout = 'logout';
  static const roleSetup = 'role_setup';
  static const portalSwitch = 'portal_switch';
  static const providerApplication = 'provider_application';
  static const contentSubmit = 'content_submit';
  static const contentDecision = 'content_decision';
  static const profileClaim = 'profile_claim';
  static const other = 'other';

  /// Fire-and-forget — never blocks user flows.
  Future<void> log({
    required String type,
    required String titleAr,
    required String titleEn,
    String detail = '',
    String? uid,
    String? email,
    String? displayName,
    String? role,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final eventUid = (uid ?? user?.uid ?? '').trim();
      // Logout may run after signOut cleared currentUser — uid must be passed.
      if (eventUid.isEmpty) return;

      await _col.add({
        'type': type,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'detail': detail,
        'uid': eventUid,
        'email': (email ?? user?.email ?? '').trim(),
        'displayName': (displayName ??
                user?.displayName ??
                user?.email?.split('@').first ??
                '')
            .trim(),
        'role': role ?? '',
        'meta': meta ?? {},
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('AdminActivityService.log failed: $e\n$st');
    }
  }

  Future<void> logLogin({String method = 'email'}) {
    return log(
      type: login,
      titleAr: 'تسجيل دخول',
      titleEn: 'Sign-in',
      detail: method,
      meta: {'method': method},
    );
  }

  Future<void> logRegister({required String role}) {
    return log(
      type: register,
      titleAr: 'تسجيل حساب جديد',
      titleEn: 'New account registration',
      detail: role,
      role: role,
      meta: {'role': role},
    );
  }

  Future<void> logLogout({
    required String uid,
    String? email,
    String? displayName,
  }) {
    return log(
      type: logout,
      titleAr: 'تسجيل خروج',
      titleEn: 'Sign-out',
      uid: uid,
      email: email,
      displayName: displayName,
    );
  }

  Future<void> logRoleSetup({required String role}) {
    return log(
      type: roleSetup,
      titleAr: 'اختيار / تغيير الدور',
      titleEn: 'Role chosen / changed',
      detail: role,
      role: role,
    );
  }

  Future<void> logPortalSwitch({required String portal}) {
    return log(
      type: portalSwitch,
      titleAr: 'تبديل البوابة',
      titleEn: 'Portal switch',
      detail: portal,
      meta: {'portal': portal},
    );
  }

  Future<void> logProviderApplication({required String role}) {
    return log(
      type: providerApplication,
      titleAr: 'طلب مقدم خدمة',
      titleEn: 'Provider application',
      detail: role,
      role: role,
    );
  }

  Future<void> logContentSubmit({
    required String collection,
    required String itemId,
    String title = '',
  }) {
    return log(
      type: contentSubmit,
      titleAr: 'إرسال محتوى للمراجعة',
      titleEn: 'Content submitted for review',
      detail: '$collection${title.isEmpty ? '' : ' · $title'}',
      meta: {'collection': collection, 'itemId': itemId},
    );
  }

  Future<void> logProfileClaim({
    required String targetType,
    required String targetName,
  }) {
    return log(
      type: profileClaim,
      titleAr: 'مطالبة ملف',
      titleEn: 'Profile claim',
      detail: '$targetType · $targetName',
      meta: {'targetType': targetType, 'targetName': targetName},
    );
  }

  Stream<List<AdminActivityEvent>> watchRecent({int limit = 120}) {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(AdminActivityEvent.fromDoc)
              .toList(growable: false),
        );
  }

  Future<void> deleteEvent(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    await _col.doc(trimmed).delete();
  }

  /// Deletes the currently loaded recent docs (up to [limit] each pass).
  /// Repeats until the collection is empty or [maxPasses] is reached.
  Future<int> clearAll({int pageSize = 200, int maxPasses = 25}) async {
    var deleted = 0;
    for (var pass = 0; pass < maxPasses; pass++) {
      final snap = await _col.limit(pageSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
      if (snap.docs.length < pageSize) break;
    }
    return deleted;
  }

  /// Deletes events older than [olderThan].
  Future<int> deleteOlderThan(DateTime olderThan, {int pageSize = 200}) async {
    var deleted = 0;
    while (true) {
      final snap = await _col
          .where('createdAt', isLessThan: Timestamp.fromDate(olderThan))
          .limit(pageSize)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
      if (snap.docs.length < pageSize) break;
    }
    return deleted;
  }
}

class AdminActivityEvent {
  final String id;
  final String type;
  final String titleAr;
  final String titleEn;
  final String detail;
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String platform;
  final DateTime? createdAt;
  final Map<String, dynamic> meta;

  const AdminActivityEvent({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.detail,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.platform,
    required this.meta,
    this.createdAt,
  });

  factory AdminActivityEvent.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    DateTime? created;
    final raw = d['createdAt'];
    if (raw is Timestamp) created = raw.toDate();
    final metaRaw = d['meta'];
    final legacyTitle = d['title']?.toString() ?? '';
    return AdminActivityEvent(
      id: doc.id,
      type: d['type']?.toString() ?? AdminActivityService.other,
      titleAr: d['titleAr']?.toString() ?? legacyTitle,
      titleEn: d['titleEn']?.toString() ?? legacyTitle,
      detail: d['detail']?.toString() ?? '',
      uid: d['uid']?.toString() ?? '',
      email: d['email']?.toString() ?? '',
      displayName: d['displayName']?.toString() ?? '',
      role: d['role']?.toString() ?? '',
      platform: d['platform']?.toString() ?? '',
      meta: metaRaw is Map
          ? Map<String, dynamic>.from(metaRaw)
          : const <String, dynamic>{},
      createdAt: created,
    );
  }

  String title({required bool isAr}) => isAr ? titleAr : titleEn;
}
