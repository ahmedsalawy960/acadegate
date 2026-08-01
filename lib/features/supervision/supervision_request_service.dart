import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../notifications/notification_service.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import 'supervision_request_models.dart';

class SupervisionRequestService {
  SupervisionRequestService._();

  static final SupervisionRequestService instance = SupervisionRequestService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('supervision_requests');

  Future<void> submit({
    required String supervisorDocId,
    required String supervisorName,
    required String supervisorUniversity,
    String supervisorOwnerId = '',
    required String requestType,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('سجّل الدخول لإرسال الطلب', 'Sign in to send the request'));
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception(appTr(
        'اكتب رسالة قصيرة توضّح طلبك',
        'Write a short message explaining your request',
      ));
    }

    final studentName =
        user.displayName ?? user.email?.split('@').first ?? appTr('طالب', 'Student');
    final studentEmail = user.email ?? '';

    final reqDoc = await _requests.add({
      'studentId': user.uid,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'supervisorDocId': supervisorDocId,
      'supervisorName': supervisorName,
      'supervisorUniversity': supervisorUniversity,
      'supervisorOwnerId': supervisorOwnerId,
      'requestType': requestType,
      'message': trimmed,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (supervisorOwnerId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: supervisorOwnerId,
        title: requestType == 'supervision'
            ? appTr('طلب إشراف جديد', 'New supervision request')
            : appTr('رسالة تواصل', 'Contact message'),
        body: '$studentName: $trimmed',
        type: 'supervision_request',
        contextId: reqDoc.id,
        contextType: 'supervision_request',
      );
    }

    if (requestType == 'supervision') {
      await ThesisProgressService.instance.recordActivity(
        ThesisActivityId.supervisorMatch.name,
      );
    }
  }

  Stream<List<SupervisionRequest>> myRequestsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _requests
        .where('studentId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupervisionRequest.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Stream<List<SupervisionRequest>> incomingForOwnerStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _requests
        .where('supervisorOwnerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupervisionRequest.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Future<void> updateStatus(String requestId, String status) async {
    await _requests.doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRequest(String requestId) async {
    await _requests.doc(requestId).delete();
  }

  /// Cancel pending then delete; delete terminal statuses outright.
  Future<void> removeRequest(SupervisionRequest request) async {
    final id = request.id;
    if (id == null || id.isEmpty) return;
    if (request.status == 'pending') {
      await updateStatus(id, 'cancelled');
    }
    await deleteRequest(id);
  }

  /// True if the student already contacted or was linked to this supervisor.
  Future<bool> hasExistingSupervisorLink(String supervisorDocId) async {
    if (supervisorDocId.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot = await _requests
        .where('studentId', isEqualTo: user.uid)
        .limit(50)
        .get();

    const activeStatuses = {'pending', 'approved', 'accepted', 'active'};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['supervisorDocId']?.toString() != supervisorDocId) continue;
      final status = data['status']?.toString().toLowerCase() ?? '';
      if (activeStatuses.contains(status)) return true;
    }
    return false;
  }
}
