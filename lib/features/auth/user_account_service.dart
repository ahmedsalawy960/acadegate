import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/callable_http_client.dart';
import '../admin/admin_activity_service.dart';
import 'merchant_business_profile.dart';
import 'portal_type.dart';
import 'provider_org_profile.dart';
import 'user_account.dart';
import 'user_role.dart';

class UserAccountService {
  UserAccountService._();

  static final UserAccountService instance = UserAccountService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool get preferHttpCallable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get _preferHttpCallable => preferHttpCallable;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Public accessor for admin directory queries.
  CollectionReference<Map<String, dynamic>> get usersCollection => _users;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _users.doc(uid);

  Stream<UserAccount?> watchCurrentAccount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    return _doc(user.uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserAccount.fromMap(snapshot.data() ?? {}, uid: user.uid);
    });
  }

  Future<UserAccount?> loadCurrentAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await _doc(user.uid).get();
    if (!snapshot.exists) return null;
    return UserAccount.fromMap(snapshot.data() ?? {}, uid: user.uid);
  }

  Future<void> createAccount({
    required User firebaseUser,
    required String displayName,
    required String role,
  }) async {
    if (role == UserRole.admin) {
      throw Exception('لا يمكن إنشاء حساب مدير من التطبيق');
    }

    await _doc(firebaseUser.uid).set({
      'uid': firebaseUser.uid,
      'email': firebaseUser.email ?? '',
      'displayName': displayName.trim(),
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ignore: unawaited_futures
    AdminActivityService.instance.logRegister(role: role);

    await submitProviderApplicationIfNeeded(
      uid: firebaseUser.uid,
      role: role,
      displayName: displayName.trim(),
      email: firebaseUser.email ?? '',
    );
  }

  /// Roles that must appear in admin content review after signup.
  static bool isReviewableProviderRole(String role) =>
      role == UserRole.merchant ||
      role == UserRole.labManager ||
      role == UserRole.supervisor ||
      role == UserRole.writer ||
      role == UserRole.ideaPublisher;

  /// Creates/refreshes a pending row in `provider_applications` for moderation.
  Future<void> submitProviderApplicationIfNeeded({
    required String uid,
    required String role,
    required String displayName,
    required String email,
  }) async {
    if (!isReviewableProviderRole(role)) return;

    await _db.collection('provider_applications').doc(uid).set({
      'ownerId': uid,
      'uid': uid,
      'role': role,
      'email': email.trim(),
      'displayName': displayName.trim(),
      'name': displayName.trim(),
      'approvalStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _doc(uid).set(
      {
        'providerApprovalStatus': 'pending',
        'providerRejectionReason': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );

    // ignore: unawaited_futures
    AdminActivityService.instance.logProviderApplication(role: role);
  }

  /// Rejected provider asks for another admin review.
  Future<void> reapplyProviderReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');
    final account = await loadCurrentAccount();
    if (account == null) throw Exception('تعذر تحميل الحساب');
    if (!isReviewableProviderRole(account.role)) {
      throw Exception('هذا الحساب ليس مقدم خدمة');
    }
    await submitProviderApplicationIfNeeded(
      uid: user.uid,
      role: account.role,
      displayName: account.displayName,
      email: account.email,
    );
  }

  Future<void> ensureAccountExists(User user) async {
    final snapshot = await _doc(user.uid).get();
    if (snapshot.exists) return;

    // Profile was deleted while Auth login remained — recreate as incomplete
    // so the user must pick role again (not silently "student forever").
    await _doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? user.email?.split('@').first ?? 'مستخدم',
      'role': UserRole.student,
      'needsRoleSetup': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeRoleSetup(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');
    if (role == UserRole.admin) {
      throw Exception('لا يمكن اختيار دور المدير من هنا');
    }
    if (!UserRole.all.contains(role)) {
      throw Exception('دور غير صالح');
    }
    final suggested = PortalType.suggestedForRole(role);
    await _doc(user.uid).set(
      {
        'role': role,
        'needsRoleSetup': false,
        if (suggested != null) 'activePortal': suggested,
        if (suggested == null) 'activePortal': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
    // ignore: unawaited_futures
    AdminActivityService.instance.logRoleSetup(role: role);
    await submitProviderApplicationIfNeeded(
      uid: user.uid,
      role: role,
      displayName: user.displayName ?? user.email?.split('@').first ?? '',
      email: user.email ?? '',
    );
  }

  /// من شاشة البداية: اعتماد دور مقدم خدمة وتفعيل بوابته.
  /// يحدّث role + activePortal فقط (متوافق مع قواعد Firestore).
  Future<void> adoptServiceProviderRole(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');
    if (role == UserRole.admin || role == UserRole.student) {
      throw Exception('دور غير صالح لمقدم الخدمة');
    }
    if (!UserRole.all.contains(role)) {
      throw Exception('دور غير صالح');
    }
    await _doc(user.uid).update({
      'role': role,
      'activePortal': PortalType.provider,
    });
    // ignore: unawaited_futures
    AdminActivityService.instance.logRoleSetup(role: role);
    await submitProviderApplicationIfNeeded(
      uid: user.uid,
      role: role,
      displayName: user.displayName ?? user.email?.split('@').first ?? '',
      email: user.email ?? '',
    );
  }

  /// Admin-only: remove app profile + Firebase Auth (via Cloud Function).
  Future<void> deleteUserProfile({required String uid}) async {
    final account = await loadCurrentAccount();
    if (account == null || !account.isAdmin) {
      throw Exception('غير مصرح بحذف المستخدمين');
    }
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me != null && me == uid) {
      throw Exception('لا يمكن حذف حسابك الحالي من هنا');
    }

    try {
      if (_preferHttpCallable) {
        await CallableHttpClient.call(
          name: 'adminDeleteUser',
          data: {'uid': uid},
          timeout: const Duration(seconds: 45),
          callableProtocol: true,
        );
      } else {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'adminDeleteUser',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
        );
        await callable.call({'uid': uid});
      }
    } catch (e) {
      // Fallback: at least remove Firestore profile if Auth delete fails/offline.
      await _doc(uid).delete();
      rethrow;
    }
  }

  /// Admin: remove ghost `users/{uid}` profiles with no Auth account
  /// (common after delete + re-register with the same email).
  Future<({int orphansRemoved})> cleanupOrphanUsers() async {
    final account = await loadCurrentAccount();
    if (account == null || !account.isAdmin) {
      throw Exception('غير مصرح');
    }
    final Map<String, dynamic> raw;
    if (_preferHttpCallable) {
      raw = await CallableHttpClient.call(
        name: 'adminCleanupOrphanUsers',
        data: {},
        timeout: const Duration(seconds: 120),
        callableProtocol: true,
      );
    } else {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'adminCleanupOrphanUsers',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final result = await callable.call();
      raw = Map<String, dynamic>.from(result.data as Map? ?? {});
    }
    return (
      orphansRemoved: (raw['orphansRemoved'] as num?)?.toInt() ?? 0,
    );
  }

  /// تطوير فقط: يرفع الحساب الحالي إلى admin إذا كان
  /// `config/app.allowBootstrap == true` في Firestore.
  /// عيّن الوثيقة يدوياً من Firebase Console ثم اضغط زر التفعيل في وضع Debug.
  /// في الإنتاج: عيّن `role: admin` من Console وأبقِ `allowBootstrap` = false.
  Future<bool> tryClaimDevAdmin() async {
    if (!kDebugMode) return false;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final existing = await loadCurrentAccount();
    if (existing?.isAdmin == true) return true;

    final configRef = _db.collection('config').doc('app');
    final config = await configRef.get();
    if (!config.exists || config.data()?['allowBootstrap'] != true) {
      return false;
    }

    await _doc(user.uid).set(
      {
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName':
            user.displayName ?? user.email?.split('@').first ?? 'Admin',
        'role': UserRole.admin,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return true;
  }

  Stream<List<UserAccount>> watchAllUsers() {
    return _users.snapshots().map(
          (snapshot) {
            final users = snapshot.docs
                .map(
                  (doc) => UserAccount.fromMap(doc.data(), uid: doc.id),
                )
                .toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
              );
            return users;
          },
        );
  }

  Stream<List<Map<String, dynamic>>> watchUsersRaw() {
    return _users.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  Future<void> updateUserRole({
    required String uid,
    required String role,
  }) async {
    if (role == UserRole.admin) {
      final account = await loadCurrentAccount();
      if (account == null || !account.isAdmin) {
        throw Exception('غير مصرح بتعيين مدير');
      }
    }

    await _doc(uid).update({'role': role});
  }

  /// Admin-only: set `free` / `pro`, optional expiry, and optional daily caps.
  Future<void> updateUserSubscription({
    required String uid,
    required String subscription,
    DateTime? expiresAt,
    bool clearExpiry = false,
    int? quotaGeminiDaily,
    int? quotaScholarDaily,
    bool clearQuotaOverrides = false,
  }) async {
    final account = await loadCurrentAccount();
    if (account == null || !account.isAdmin) {
      throw Exception('غير مصرح بتعديل الاشتراك');
    }
    final tier = SubscriptionTier.normalize(subscription);
    final data = <String, dynamic>{
      'subscription': tier,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (clearExpiry || tier == SubscriptionTier.free) {
      data['subscriptionExpiresAt'] = FieldValue.delete();
    } else if (expiresAt != null) {
      data['subscriptionExpiresAt'] = Timestamp.fromDate(expiresAt);
    }
    if (clearQuotaOverrides) {
      data['quotaGeminiDaily'] = FieldValue.delete();
      data['quotaScholarDaily'] = FieldValue.delete();
    } else {
      if (quotaGeminiDaily != null) {
        data['quotaGeminiDaily'] = quotaGeminiDaily.clamp(0, 1000000);
      }
      if (quotaScholarDaily != null) {
        data['quotaScholarDaily'] = quotaScholarDaily.clamp(0, 1000000);
      }
    }
    await _doc(uid).set(data, SetOptions(merge: true));
  }

  /// يفعّل دور التاجر للحساب الحالي حتى يمكن إضافة منتجات المتجر.
  Future<void> enableMerchantSelling() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول');
    }
    await ensureAccountExists(user);
    final account = await loadCurrentAccount();
    if (account == null) {
      throw Exception('تعذر تحميل الحساب');
    }
    if (account.isAdmin || account.role == UserRole.merchant) return;
    await _doc(user.uid).update({'role': UserRole.merchant});
  }

  /// يفعّل دور الكاتب ويعرض بوابة مقدم الخدمة لطلبات الكتابة الواردة.
  Future<void> enableWriterRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول');
    }
    await ensureAccountExists(user);
    final account = await loadCurrentAccount();
    if (account == null) {
      throw Exception('تعذر تحميل الحساب');
    }
    if (account.isAdmin ||
        account.role == UserRole.writer ||
        account.role == UserRole.supervisor) {
      return;
    }
    await _doc(user.uid).set(
      {
        'role': UserRole.writer,
        'activePortal': PortalType.provider,
      },
      SetOptions(merge: true),
    );
  }

  /// يفعّل دور المشرف وبوابة مقدم الخدمة لاستقبال طلبات الإشراف.
  Future<void> enableSupervisorRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول');
    }
    await ensureAccountExists(user);
    final account = await loadCurrentAccount();
    if (account == null) {
      throw Exception('تعذر تحميل الحساب');
    }
    if (account.isAdmin || account.role == UserRole.supervisor) return;
    await _doc(user.uid).set(
      {
        'role': UserRole.supervisor,
        'activePortal': PortalType.provider,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setActivePortal(String portal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _doc(user.uid).set(
      {'activePortal': portal},
      SetOptions(merge: true),
    );
    // ignore: unawaited_futures
    AdminActivityService.instance.logPortalSwitch(portal: portal);
  }

  Future<void> clearActivePortal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _doc(user.uid).update({'activePortal': FieldValue.delete()});
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');
    final name = displayName.trim();
    if (name.isEmpty) throw Exception('الاسم مطلوب');

    await _doc(user.uid).set(
      {'displayName': name},
      SetOptions(merge: true),
    );
    await user.updateDisplayName(name);
  }

  Future<void> updatePhotoUrl(String? photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) {
      await _doc(user.uid).set(
        {'photoUrl': FieldValue.delete()},
        SetOptions(merge: true),
      );
      await user.updatePhotoURL(null);
      return;
    }

    await _doc(user.uid).set(
      {'photoUrl': url},
      SetOptions(merge: true),
    );
    await user.updatePhotoURL(url);
  }

  Future<void> updateBusinessProfile(MerchantBusinessProfile profile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');
    final err = profile.validateForSave();
    if (err != null) throw StateError(err);

    await _doc(user.uid).set(
      {
        'businessProfile': profile.toMap(),
        'businessProfileUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateProviderProfile(ProviderOrgProfile profile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');
    final err = profile.validateForSave();
    if (err != null) throw StateError(err);

    await _doc(user.uid).set(
      {
        'providerProfile': profile.toMap(),
        'providerProfileUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// True when this user owns at least one Managed Verified supplier listing.
  Future<bool> hasManagedVerifiedSupplier() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final snap = await _db
        .collection('store_suppliers')
        .where('claimedByUid', isEqualTo: user.uid)
        .where('directoryStatus', isEqualTo: 'managed_verified')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Stream<bool> watchHasManagedVerifiedSupplier() async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      yield false;
      return;
    }
    yield* _db
        .collection('store_suppliers')
        .where('claimedByUid', isEqualTo: user.uid)
        .where('directoryStatus', isEqualTo: 'managed_verified')
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty);
  }

  Stream<bool> watchHasManagedVerifiedLab() async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      yield false;
      return;
    }
    yield* _db
        .collection('labs')
        .where('ownerId', isEqualTo: user.uid)
        .where('directoryStatus', isEqualTo: 'managed_verified')
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty);
  }

  Stream<bool> watchHasManagedVerifiedSupervisor() async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      yield false;
      return;
    }
    yield* _db
        .collection('supervisors')
        .where('ownerId', isEqualTo: user.uid)
        .where('directoryStatus', isEqualTo: 'managed_verified')
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty);
  }
}
