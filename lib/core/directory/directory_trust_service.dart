import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../locale/app_translate.dart';
import '../../features/auth/user_account_service.dart';
import '../../features/auth/user_role.dart';
import '../../features/notifications/admin_recipient_service.dart';
import 'directory_trust_status.dart';

/// Admin / claim updates for directory trust status on suppliers & labs.
class DirectoryTrustService {
  DirectoryTrustService._();
  static final DirectoryTrustService instance = DirectoryTrustService._();

  final _db = FirebaseFirestore.instance;

  Future<void> setSupplierStatus({
    required String supplierId,
    required String status,
    String? note,
  }) async {
    await _requireAdmin();
    final s = DirectoryTrustStatus.normalize(status);
    if (!DirectoryTrustStatus.isValid(s)) {
      throw StateError('Invalid directory status');
    }
    final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;
    await _db.collection('store_suppliers').doc(supplierId).set({
      'directoryStatus': s,
      'lastReviewedAt': FieldValue.serverTimestamp(),
      'lastVerifiedIso': nowIso,
      'isPartner': DirectoryTrustStatus.isTrusted(s),
      'isVerifiedSeller': DirectoryTrustStatus.isTrusted(s),
      if (note != null && note.trim().isNotEmpty) 'trustNote': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Propagate trust flags to directory products of this supplier.
    await propagateSupplierTrust(supplierId, s);
  }

  /// Instant legacy claim — prefer [ProfileClaimService.submitClaim] for Managed Verified.
  @Deprecated('Use ProfileClaimService.submitClaim for evidence-based Managed Verified')
  Future<void> claimSupplier({
    required String supplierId,
    required String storeName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    final account = await UserAccountService.instance.loadCurrentAccount();
    final role = account?.role ?? '';
    final canClaim = role == UserRole.merchant || role == UserRole.admin;
    if (!canClaim) {
      throw StateError(
        appTr(
          'مطالبة المورد متاحة للتاجر أو المدير فقط',
          'Supplier claim is available to merchants or admins only',
        ),
      );
    }

    final claimerName = account?.displayName.trim().isNotEmpty == true
        ? account!.displayName.trim()
        : (user.displayName ?? user.email?.split('@').first ?? 'Merchant');

    final ref = _db.collection('store_suppliers').doc(supplierId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError(
          appTr('المورد غير موجود في الدليل', 'Supplier not in directory'),
        );
      }
      final data = snap.data() ?? {};
      final existingClaim = data['claimedByUid']?.toString() ?? '';
      if (existingClaim.isNotEmpty && existingClaim != user.uid) {
        final ownerSnap =
            await tx.get(_db.collection('users').doc(existingClaim));
        if (ownerSnap.exists) {
          throw StateError(
            appTr('هذا المورد مُطالَب مسبقاً', 'Supplier already claimed'),
          );
        }
      }
      final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;
      tx.set(
        ref,
        {
          // Self-asserted ownership only — not Managed Verified.
          'directoryStatus': DirectoryTrustStatus.claimed,
          'claimedByUid': user.uid,
          'claimedByName': claimerName,
          'claimedAt': FieldValue.serverTimestamp(),
          'lastReviewedAt': FieldValue.serverTimestamp(),
          'lastVerifiedIso': nowIso,
          'isPartner': false,
          'isVerifiedSeller': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    await propagateSupplierTrust(
      supplierId,
      DirectoryTrustStatus.claimed,
    );

    try {
      await AdminRecipientService.instance.notifyAllAdmins(
        title: appTr('مطالبة مورد (سريعة)', 'Supplier claim (quick)'),
        body: '$claimerName — $storeName',
        type: 'supplier_claim',
        contextId: supplierId,
        contextType: 'store_supplier',
      );
    } catch (_) {}
  }

  Future<void> setLabStatus({
    required String labId,
    required String status,
    String? note,
  }) async {
    await _requireAdmin();
    final s = DirectoryTrustStatus.normalize(status);
    final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;
    await _db.collection('labs').doc(labId).set({
      'directoryStatus': s,
      'lastReviewedAt': FieldValue.serverTimestamp(),
      'lastVerifiedIso': nowIso,
      if (note != null && note.trim().isNotEmpty) 'trustNote': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> propagateSupplierTrust(
    String supplierId,
    String status,
  ) async {
    final trusted = DirectoryTrustStatus.isTrusted(status);
    final snap = await _db
        .collection('product')
        .where('supplierId', isEqualTo: supplierId)
        .limit(400)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;
    for (final doc in snap.docs) {
      batch.set(
        doc.reference,
        {
          'directoryStatus': status,
          'isPartner': trusted,
          'isVerifiedSeller': trusted,
          'lastVerifiedIso': nowIso,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> touchLastManaged({
    required String targetType,
    required String targetId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final col = targetType == 'supplier' ? 'store_suppliers' : 'labs';
    final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;
    await _db.collection(col).doc(targetId).set({
      'lastManagedAt': FieldValue.serverTimestamp(),
      'lastManagedIso': nowIso,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _requireAdmin() async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    if (account?.isAdmin != true) {
      throw StateError(appTr('مدير فقط', 'Admin only'));
    }
  }
}
