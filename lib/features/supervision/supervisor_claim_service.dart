import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../academic/academic_models.dart';
import '../auth/portal_type.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../notifications/admin_recipient_service.dart';
import '../notifications/notification_service.dart';

/// يربط مشرفاً مسجّلاً بملف مستورد (OpenAlex/CSV) بلا مالك.
class SupervisorClaimService {
  SupervisorClaimService._();

  static final SupervisorClaimService instance = SupervisorClaimService._();

  final _db = FirebaseFirestore.instance;

  Future<SupervisorClaimResult> claimSupervisor(AcademicSupervisor supervisor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    if (supervisor.id == null || supervisor.id!.isEmpty) {
      throw Exception(
        appTr('الملف غير مسجّل في النظام', 'Profile is not registered'),
      );
    }
    if (supervisor.isDemo) {
      throw Exception(
        appTr('لا يمكن مطالبة ملف تجريبي', 'Demo profiles cannot be claimed'),
      );
    }

    final account = await UserAccountService.instance.loadCurrentAccount();
    final role = account?.role ?? '';
    final canClaim = role == UserRole.supervisor ||
        role == UserRole.admin ||
        role == UserRole.student;
    if (!canClaim) {
      throw Exception(
        appTr(
          'مطالبة ملف المشرف متاحة لحساب مشرف أو طالب (يُحوَّل لمشرف) أو مدير',
          'Claiming a supervisor profile is available to supervisors, students (promoted), or admins',
        ),
      );
    }

    final claimerName = account?.displayName.trim().isNotEmpty == true
        ? account!.displayName.trim()
        : (user.displayName ??
            user.email?.split('@').first ??
            appTr('مشرف', 'Supervisor'));

    final ref = _db.collection('supervisors').doc(supervisor.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception(appTr('الملف غير موجود', 'Profile not found'));
      }
      final data = snap.data() ?? {};
      final ownerId = data['ownerId']?.toString() ?? '';
      if (ownerId.isNotEmpty) {
        if (ownerId == user.uid) return;
        final ownerSnap =
            await tx.get(_db.collection('users').doc(ownerId));
        if (ownerSnap.exists) {
          throw Exception(
            appTr(
              'هذا الملف مربوط بحساب بالفعل',
              'This profile is already claimed',
            ),
          );
        }
      }
      tx.update(ref, {
        'ownerId': user.uid,
        'claimedByName': claimerName,
        'claimedAt': FieldValue.serverTimestamp(),
        'isAvailable': true,
        'directoryStatus': 'claimed',
      });
    });

    // ترقية الطالب إلى مشرف حتى تظهر له طلبات الإشراف الواردة.
    if (role == UserRole.student) {
      try {
        await UserAccountService.instance.enableSupervisorRole();
      } catch (_) {}
    } else if (role == UserRole.supervisor) {
      try {
        await UserAccountService.instance.setActivePortal(PortalType.provider);
      } catch (_) {}
    }

    final attached = await attachPendingRequests(
      supervisorDocId: supervisor.id!,
      ownerId: user.uid,
      supervisorName: supervisor.name,
    );

    try {
      await AdminRecipientService.instance.notifyAllAdmins(
        title: appTr('تم ربط ملف مشرف', 'Supervisor profile claimed'),
        body: '$claimerName — ${supervisor.name}',
        type: 'supervisor_claim',
        contextId: supervisor.id ?? '',
        contextType: 'supervisor',
      );
    } catch (_) {}

    return SupervisorClaimResult(pendingRequestsAttached: attached);
  }

  /// يُستدعى بعد اعتماد Managed Verified لربط الطلبات المعلّقة.
  Future<int> attachPendingRequests({
    required String supervisorDocId,
    required String ownerId,
    required String supervisorName,
  }) async {
    final snap = await _db
        .collection('supervision_requests')
        .where('supervisorDocId', isEqualTo: supervisorDocId)
        .get();

    var count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final existingOwner = data['supervisorOwnerId']?.toString() ?? '';
      if (existingOwner.isNotEmpty) continue;
      await doc.reference.update({
        'supervisorOwnerId': ownerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      count++;
      final studentName = data['studentName']?.toString() ?? '';
      final message = data['message']?.toString() ?? '';
      final requestType = data['requestType']?.toString() ?? 'supervision';
      try {
        await NotificationService.instance.send(
          userId: ownerId,
          title: requestType == 'supervision'
              ? appTr('طلب إشراف معلّق', 'Pending supervision request')
              : appTr('رسالة معلّقة', 'Pending message'),
          body: studentName.isEmpty
              ? message
              : '$studentName: $message',
          type: 'supervision_request',
          contextId: doc.id,
          contextType: 'supervision_request',
        );
      } catch (_) {}
    }

    if (count > 0) {
      try {
        await NotificationService.instance.send(
          userId: ownerId,
          title: appTr('طلبات بانتظارك', 'Requests waiting for you'),
          body: appTr(
            'تم ربط ملف «$supervisorName» — لديك $count طلباً معلّقاً.',
            'Linked «$supervisorName» — you have $count pending request(s).',
          ),
          type: 'supervisor_claim',
          contextId: supervisorDocId,
          contextType: 'supervisor',
        );
      } catch (_) {}
    }

    return count;
  }
}

class SupervisorClaimResult {
  final int pendingRequestsAttached;

  const SupervisorClaimResult({this.pendingRequestsAttached = 0});
}
