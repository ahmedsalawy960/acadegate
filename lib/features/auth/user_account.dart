import 'package:cloud_firestore/cloud_firestore.dart';
import 'merchant_business_profile.dart';
import 'provider_org_profile.dart';
import 'user_role.dart';

/// Billing / AI quota tier (manual Pro for beta; Paymob later).
class SubscriptionTier {
  static const free = 'free';
  static const pro = 'pro';

  static String normalize(String? raw) {
    final v = (raw ?? free).trim().toLowerCase();
    return v == pro ? pro : free;
  }

  static String label(String tier) {
    switch (normalize(tier)) {
      case pro:
        return 'Pro';
      default:
        return 'Free';
    }
  }
}

class UserAccount {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String? photoUrl;
  final String? activePortal;
  final DateTime? createdAt;
  /// `free` | `pro` — admins are unlimited via role, not this field.
  final String subscription;
  final DateTime? subscriptionExpiresAt;
  /// Optional per-user daily caps (null = use tier defaults).
  final int? quotaGeminiDaily;
  final int? quotaScholarDaily;
  /// Merchant/supplier business entity (does not grant Verified by itself).
  final MerchantBusinessProfile businessProfile;
  /// Lab / supervisor / writer / publisher org credentials.
  final ProviderOrgProfile providerProfile;
  /// True when Auth login survived but Firestore profile was wiped — pick role again.
  final bool needsRoleSetup;
  /// `pending` | `approved` | `rejected` — admin review of provider signup.
  final String? providerApprovalStatus;
  final String providerRejectionReason;

  const UserAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.activePortal,
    this.createdAt,
    this.subscription = SubscriptionTier.free,
    this.subscriptionExpiresAt,
    this.quotaGeminiDaily,
    this.quotaScholarDaily,
    this.businessProfile = const MerchantBusinessProfile(),
    this.providerProfile = const ProviderOrgProfile(),
    this.needsRoleSetup = false,
    this.providerApprovalStatus,
    this.providerRejectionReason = '',
  });

  bool get isAdmin => UserRole.isAdmin(role);

  bool get isMerchant => role == UserRole.merchant;

  bool get isStudentOrResearcher => role == UserRole.student;

  bool get hasPhoto {
    final url = photoUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  /// Effective paid Pro (not expired). Admins are treated as Pro for UI.
  bool get isProActive {
    if (isAdmin) return true;
    if (SubscriptionTier.normalize(subscription) != SubscriptionTier.pro) {
      return false;
    }
    final exp = subscriptionExpiresAt;
    if (exp == null) return true;
    return exp.isAfter(DateTime.now());
  }

  String get effectiveTier {
    if (isAdmin) return 'admin';
    return isProActive ? SubscriptionTier.pro : SubscriptionTier.free;
  }

  static int? _optionalInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw < 0 ? null : raw;
    if (raw is num) {
      final v = raw.toInt();
      return v < 0 ? null : v;
    }
    return int.tryParse(raw.toString());
  }

  factory UserAccount.fromMap(Map<String, dynamic> map, {required String uid}) {
    DateTime? created;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    }

    DateTime? subExp;
    final rawExp = map['subscriptionExpiresAt'];
    if (rawExp is Timestamp) {
      subExp = rawExp.toDate();
    } else if (rawExp is String && rawExp.trim().isNotEmpty) {
      subExp = DateTime.tryParse(rawExp.trim());
    }

    return UserAccount(
      uid: uid,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      role: map['role']?.toString() ?? UserRole.student,
      photoUrl: map['photoUrl']?.toString(),
      activePortal: map['activePortal']?.toString(),
      createdAt: created,
      subscription: SubscriptionTier.normalize(map['subscription']?.toString()),
      subscriptionExpiresAt: subExp,
      quotaGeminiDaily: _optionalInt(map['quotaGeminiDaily']),
      quotaScholarDaily: _optionalInt(map['quotaScholarDaily']),
      businessProfile: MerchantBusinessProfile.fromMap(
        (map['businessProfile'] as Map?)?.cast<String, dynamic>(),
      ),
      providerProfile: ProviderOrgProfile.fromMap(
        (map['providerProfile'] as Map?)?.cast<String, dynamic>(),
      ),
      needsRoleSetup: map['needsRoleSetup'] == true,
      providerApprovalStatus: map['providerApprovalStatus']?.toString(),
      providerRejectionReason:
          map['providerRejectionReason']?.toString() ?? '',
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
      'subscription': SubscriptionTier.normalize(subscription),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
