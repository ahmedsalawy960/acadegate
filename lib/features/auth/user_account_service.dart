import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_account.dart';
import 'user_role.dart';

class UserAccountService {
  UserAccountService._();

  static final UserAccountService instance = UserAccountService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

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
  }

  Future<void> ensureAccountExists(User user) async {
    final snapshot = await _doc(user.uid).get();
    if (snapshot.exists) return;

    await _doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? user.email?.split('@').first ?? 'مستخدم',
      'role': UserRole.student,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// لم يعد التطبيق يرفع صلاحيات المدير تلقائياً — عيّن المدير من Firebase Console.
  Future<bool> tryClaimDevAdmin() async {
    final account = await loadCurrentAccount();
    return account?.isAdmin == true;
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

  Future<void> setActivePortal(String portal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _doc(user.uid).set(
      {'activePortal': portal},
      SetOptions(merge: true),
    );
  }

  Future<void> clearActivePortal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _doc(user.uid).update({'activePortal': FieldValue.delete()});
  }
}
