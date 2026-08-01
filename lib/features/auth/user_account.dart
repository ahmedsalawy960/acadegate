import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

class UserAccount {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String? photoUrl;
  final String? activePortal;
  final DateTime? createdAt;

  const UserAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.activePortal,
    this.createdAt,
  });

  bool get isAdmin => UserRole.isAdmin(role);

  bool get hasPhoto {
    final url = photoUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

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
      photoUrl: map['photoUrl']?.toString(),
      activePortal: map['activePortal']?.toString(),
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      if (photoUrl != null && photoUrl!.trim().isNotEmpty)
        'photoUrl': photoUrl!.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
