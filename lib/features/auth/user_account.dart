import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

class UserAccount {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final DateTime? createdAt;

  const UserAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.createdAt,
  });

  bool get isAdmin => UserRole.isAdmin(role);

  factory UserAccount.fromMap(Map<String, dynamic> map, {required String uid}) {
    DateTime? created;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    }

    return UserAccount(
      uid: uid,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      role: map['role']?.toString() ?? UserRole.student,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
