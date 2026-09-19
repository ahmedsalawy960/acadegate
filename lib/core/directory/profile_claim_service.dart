import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../locale/app_translate.dart';
import '../../features/admin/admin_activity_service.dart';
import '../../features/analytics/kpi_analytics_service.dart';
import '../../features/auth/provider_publish_gate.dart';
import '../../features/auth/user_account_service.dart';
import '../../features/auth/user_role.dart';
import '../../features/notifications/admin_recipient_service.dart';
import '../../features/notifications/notification_service.dart';
import '../../features/supervision/supervisor_claim_service.dart';
import 'directory_trust_service.dart';
import 'directory_trust_status.dart';

class ProfileClaimEvidence {
  const ProfileClaimEvidence({
    required this.legalName,
    this.tradeName = '',
    this.jobTitle = '',
    this.commercialRegisterNo = '',
    this.taxId = '',
    required this.officialEmail,
    this.officialPhone = '',
    this.websiteUrl = '',
    this.proofUrl = '',
    this.notes = '',
  });

  final String legalName;
  final String tradeName;
  final String jobTitle;
  final String commercialRegisterNo;
  final String taxId;
  final String officialEmail;
  final String officialPhone;
  final String websiteUrl;
  final String proofUrl;
  final String notes;

  Map<String, dynamic> toMap() => {
        'legalName': legalName.trim(),
        'tradeName': tradeName.trim(),
        'jobTitle': jobTitle.trim(),
        'commercialRegisterNo': commercialRegisterNo.trim(),
        'taxId': taxId.trim(),
        'officialEmail': officialEmail.trim(),
        'officialPhone': officialPhone.trim(),
        'websiteUrl': websiteUrl.trim(),
        'proofUrl': proofUrl.trim(),
        'notes': notes.trim(),
      };

  /// Returns an error message, or null when evidence is complete enough to submit.
  static String? validateForSubmit(ProfileClaimEvidence evidence) {
    if (evidence.legalName.trim().length < 3) {
      return appTr('أدخل الاسم القانوني للمنشأة', 'Enter the legal entity name');
    }
    if (!evidence.officialEmail.contains('@')) {
      return appTr('أدخل بريداً رسمياً صالحاً', 'Enter a valid official email');
    }
    if (evidence.jobTitle.trim().length < 2) {
      return appTr(
        'أدخل المسمى الوظيفي / صفة التمثيل',
        'Enter your job title / role',
      );
    }
    if (evidence.proofUrl.trim().isEmpty) {
      return appTr(
        'ارفع إثبات التمثيل (سجل / خطاب / بطاقة) قبل الإرسال',
        'Upload representation proof (CR / letter / ID) before submitting',
      );
    }
    return null;
  }
}

/// Claim Profile: evidence → admin review → Managed Verified.
class ProfileClaimService {
  ProfileClaimService._();
  static final ProfileClaimService instance = ProfileClaimService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _claims =>
      _db.collection('profile_claims');

  Future<String> submitClaim({
    required String targetType,
    required String targetId,
    required String targetName,
    required ProfileClaimEvidence evidence,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    if (targetType != 'supplier' &&
        targetType != 'lab' &&
        targetType != 'supervisor') {
      throw StateError('Invalid target type');
    }
    final evidenceError = ProfileClaimEvidence.validateForSubmit(evidence);
    if (evidenceError != null) {
      throw StateError(evidenceError);
    }

    final account = await UserAccountService.instance.loadCurrentAccount();
    if (ProviderPublishGate.isProviderRole(account?.role) &&
        !ProviderPublishGate.canSubmitContent(account)) {
      throw StateError(
        appTr(
          ProviderPublishGate.blockMessageAr(account),
          ProviderPublishGate.blockMessageEn(account),
        ),
      );
    }
    final role = account?.role ?? '';
    final okRole = switch (targetType) {
      'supplier' => role == UserRole.merchant || role == UserRole.admin,
      'lab' => role == UserRole.labManager || role == UserRole.admin,
      'supervisor' =>
        role == UserRole.supervisor ||
            role == UserRole.student ||
            role == UserRole.admin,
      _ => false,
    };
    if (!okRole) {
      throw StateError(
        switch (targetType) {
          'supplier' => appTr(
              'مطالبة المورد للتاجر أو المدير فقط',
              'Supplier claims require merchant or admin',
            ),
          'lab' => appTr(
              'مطالبة المختبر لمدير المعمل أو المدير فقط',
              'Lab claims require lab manager or admin',
            ),
          _ => appTr(
              'مطالبة المشرف لحساب مشرف أو طالب أو مدير',
              'Supervisor claims require supervisor, student, or admin',
            ),
        },
      );
    }

    // Block if already managed by someone else.
    final targetCol = switch (targetType) {
      'supplier' => 'store_suppliers',
      'lab' => 'labs',
      _ => 'supervisors',
    };
    final targetSnap = await _db.collection(targetCol).doc(targetId).get();
    if (!targetSnap.exists) {
      throw StateError(
        appTr('الملف غير موجود في الدليل', 'Profile not found in directory'),
      );
    }
    final t = targetSnap.data() ?? {};
    final ownerKey = targetType == 'supplier' ? 'claimedByUid' : 'ownerId';
    final owner = t[ownerKey]?.toString() ?? '';
    final status = DirectoryTrustStatus.normalize(t['directoryStatus']?.toString());
    if (owner.isNotEmpty &&
        owner != user.uid &&
        status == DirectoryTrustStatus.managedVerified) {
      final ownerDoc = await _db.collection('users').doc(owner).get();
      if (ownerDoc.exists) {
        throw StateError(
          appTr(
            'هذا الملف مُدار بالفعل من حساب آخر',
            'This profile is already managed by another account',
          ),
        );
      }
      // Previous owner was deleted — free the listing for a new claim/review.
      await targetSnap.reference.set(
        {
          ownerKey: FieldValue.delete(),
          'directoryStatus': DirectoryTrustStatus.unverified,
          'isPartner': false,
          'isVerifiedSeller': false,
          'managedClaimId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final pending = await _claims
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .where('status', isEqualTo: 'pending_review')
        .limit(5)
        .get();
    for (final d in pending.docs) {
      if (d.data()['claimantUid'] == user.uid) {
        throw StateError(
          appTr(
            'لديك مطالبة قيد المراجعة لهذا الملف',
            'You already have a pending claim for this profile',
          ),
        );
      }
    }

    final claimerName = account?.displayName.trim().isNotEmpty == true
        ? account!.displayName.trim()
        : (user.displayName ?? user.email?.split('@').first ?? 'User');

    final ref = await _claims.add({
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName.trim(),
      'claimantUid': user.uid,
      'claimantName': claimerName,
      'claimantRole': role,
      'status': 'pending_review',
      'evidence': evidence.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ignore: unawaited_futures
    AdminActivityService.instance.logProfileClaim(
      targetType: targetType,
      targetName: targetName.trim(),
    );
    // ignore: unawaited_futures
    KpiAnalyticsService.instance.logProfileClaim(
      targetType: targetType,
      targetId: targetId,
    );

    try {
      await AdminRecipientService.instance.notifyAllAdmins(
        title: appTr('مطالبة ملف — مراجعة', 'Profile claim — review'),
        body: '$claimerName — $targetName',
        type: 'profile_claim',
        contextId: ref.id,
        contextType: 'profile_claim',
      );
    } catch (_) {}

    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPending() {
    return _claims.orderBy('createdAt', descending: true).limit(80).snapshots();
  }

  Future<void> approveClaim(String claimId, {String? reviewNote}) async {
    await _requireAdmin();
    final admin = FirebaseAuth.instance.currentUser!;
    final claimRef = _claims.doc(claimId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(claimRef);
      if (!snap.exists) {
        throw StateError(appTr('المطالبة غير موجودة', 'Claim not found'));
      }
      final data = snap.data()!;
      if (data['status'] != 'pending_review') {
        throw StateError(
          appTr('المطالبة ليست قيد المراجعة', 'Claim is not pending'),
        );
      }

      final targetType = data['targetType']?.toString() ?? '';
      final targetId = data['targetId']?.toString() ?? '';
      final claimantUid = data['claimantUid']?.toString() ?? '';
      final claimantName = data['claimantName']?.toString() ?? '';
      if (targetId.isEmpty || claimantUid.isEmpty) {
        throw StateError('Invalid claim payload');
      }

      final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;
      final targetCol = switch (targetType) {
        'supplier' => 'store_suppliers',
        'lab' => 'labs',
        'supervisor' => 'supervisors',
        _ => '',
      };
      if (targetCol.isEmpty) {
        throw StateError('Invalid target type');
      }
      final targetRef = _db.collection(targetCol).doc(targetId);

      final patch = <String, dynamic>{
        'directoryStatus': DirectoryTrustStatus.managedVerified,
        'lastReviewedAt': FieldValue.serverTimestamp(),
        'lastVerifiedIso': nowIso,
        'lastManagedAt': FieldValue.serverTimestamp(),
        'lastManagedIso': nowIso,
        'managedClaimId': claimId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (targetType == 'supplier') {
        patch['claimedByUid'] = claimantUid;
        patch['claimedByName'] = claimantName;
        patch['claimedAt'] = FieldValue.serverTimestamp();
        patch['isPartner'] = true;
        patch['isVerifiedSeller'] = true;
      } else if (targetType == 'lab') {
        patch['ownerId'] = claimantUid;
        patch['claimedByName'] = claimantName;
        patch['claimedAt'] = FieldValue.serverTimestamp();
        patch['isPartner'] = true;
        patch['isVerifiedSeller'] = true;
      } else {
        // supervisor
        patch['ownerId'] = claimantUid;
        patch['claimedByName'] = claimantName;
        patch['claimedAt'] = FieldValue.serverTimestamp();
        patch['isAvailable'] = true;
        patch['verificationStatus'] = DirectoryTrustStatus.managedVerified;
      }

      tx.set(targetRef, patch, SetOptions(merge: true));
      tx.update(claimRef, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedByUid': admin.uid,
        if (reviewNote != null && reviewNote.trim().isNotEmpty)
          'reviewNote': reviewNote.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Propagate supplier products after transaction.
    final claim = await claimRef.get();
    final d = claim.data();
    if (d != null) {
      // ignore: unawaited_futures
      KpiAnalyticsService.instance.logProfileVerified(
        targetType: d['targetType']?.toString() ?? '',
        targetId: d['targetId']?.toString() ?? '',
        claimantUid: d['claimantUid']?.toString(),
      );
    }
    if (d?['targetType'] == 'supplier') {
      await DirectoryTrustService.instance.propagateSupplierTrust(
        d!['targetId'].toString(),
        DirectoryTrustStatus.managedVerified,
      );
    }

    if (d?['targetType'] == 'supervisor') {
      final targetId = d!['targetId']?.toString() ?? '';
      final claimantUid = d['claimantUid']?.toString() ?? '';
      final targetName = d['targetName']?.toString() ?? '';
      final claimantRole = d['claimantRole']?.toString() ?? '';
      if (claimantUid.isNotEmpty && targetId.isNotEmpty) {
        if (claimantRole == UserRole.student) {
          try {
            // Admin approval path: promote via direct write if needed.
            await FirebaseFirestore.instance.collection('users').doc(claimantUid).set({
              'role': UserRole.supervisor,
              'activePortal': 'provider',
            }, SetOptions(merge: true));
          } catch (_) {}
        }
        try {
          await SupervisorClaimService.instance.attachPendingRequests(
            supervisorDocId: targetId,
            ownerId: claimantUid,
            supervisorName: targetName,
          );
        } catch (_) {}
      }
    }

    final claimantUid = d?['claimantUid']?.toString() ?? '';
    final targetName = d?['targetName']?.toString() ?? '';
    if (claimantUid.isNotEmpty) {
      try {
        await NotificationService.instance.send(
          userId: claimantUid,
          title: appTr(
            'تمت الموافقة — موثّق ومُدار',
            'Approved — Managed Verified',
          ),
          body: appTr(
            'تم اعتماد مطالبة «$targetName». يمكنك الآن ترتيب بيانات الملف.',
            'Your claim for “$targetName” was approved. You can arrange the profile now.',
          ),
          type: 'profile_claim',
          contextId: claimId,
          contextType: 'profile_claim',
        );
      } catch (_) {}
    }
  }

  Future<void> rejectClaim(String claimId, {String? reviewNote}) async {
    await _requireAdmin();
    final admin = FirebaseAuth.instance.currentUser!;
    final claimRef = _claims.doc(claimId);
    final before = await claimRef.get();
    final d = before.data();
    await claimRef.update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedByUid': admin.uid,
      if (reviewNote != null && reviewNote.trim().isNotEmpty)
        'reviewNote': reviewNote.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final claimantUid = d?['claimantUid']?.toString() ?? '';
    final targetName = d?['targetName']?.toString() ?? '';
    if (claimantUid.isNotEmpty) {
      try {
        await NotificationService.instance.send(
          userId: claimantUid,
          title: appTr('تم رفض مطالبة الملف', 'Profile claim rejected'),
          body: appTr(
            'رُفضت مطالبة «$targetName». راجع الإثبات أو تواصل مع الدعم.',
            'Your claim for “$targetName” was rejected. Review proof or contact support.',
          ),
          type: 'profile_claim',
          contextId: claimId,
          contextType: 'profile_claim',
        );
      } catch (_) {}
    }
  }

  Future<void> _requireAdmin() async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    if (account?.isAdmin != true) {
      throw StateError(appTr('مدير فقط', 'Admin only'));
    }
  }
}
