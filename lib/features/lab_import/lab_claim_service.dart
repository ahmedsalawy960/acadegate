import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../academic/academic_models.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../notifications/admin_recipient_service.dart';

/// Lets a lab manager / admin claim an unowned (e.g. NBSLE) lab listing.
class LabClaimService {
  LabClaimService._();

  static final LabClaimService instance = LabClaimService._();

  final _db = FirebaseFirestore.instance;

  Future<void> claimLab(AcademicLab lab) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    if (!lab.isFromFirebase || lab.id == null) {
      throw Exception(
        appTr('المختبر غير مسجّل في النظام', 'Lab is not registered'),
      );
    }

    final account = await UserAccountService.instance.loadCurrentAccount();
    final role = account?.role ?? '';
    final canClaim =
        role == UserRole.labManager || role == UserRole.admin;
    if (!canClaim) {
      throw Exception(
        appTr(
          'مطالبة المختبر متاحة لمدير المعمل أو المدير فقط',
          'Lab claim is available to lab managers or admins only',
        ),
      );
    }

    final claimerName = account?.displayName.trim().isNotEmpty == true
        ? account!.displayName.trim()
        : (user.displayName ??
            user.email?.split('@').first ??
            appTr('مدير معمل', 'Lab manager'));

    final ref = _db.collection('labs').doc(lab.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception(appTr('المختبر غير موجود', 'Lab not found'));
      }
      final data = snap.data() ?? {};
      final ownerId = data['ownerId']?.toString() ?? '';
      if (ownerId.isNotEmpty) {
        if (ownerId == user.uid) return;
        throw Exception(
          appTr(
            'هذا المختبر مربوط بمالك بالفعل',
            'This lab is already claimed',
          ),
        );
      }
      tx.update(ref, {
        'ownerId': user.uid,
        'claimedByName': claimerName,
        'claimedAt': FieldValue.serverTimestamp(),
      });
    });

    try {
      await AdminRecipientService.instance.notifyAllAdmins(
        title: appTr('تمت مطالبة مختبر', 'Lab claimed'),
        body: '$claimerName — ${lab.name}',
        type: 'lab_claim',
        contextId: lab.id ?? '',
        contextType: 'lab',
      );
    } catch (_) {}
  }
}
