import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../notifications/notification_service.dart';
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
      throw Exception('سجّل الدخول لإرسال الطلب');
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('اكتب رسالة قصيرة توضّح طلبك');
    }

    final studentName =
        user.displayName ?? user.email?.split('@').first ?? 'طالب';
    final studentEmail = user.email ?? '';

    await _requests.add({
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
        title: requestType == 'supervision' ? 'طلب إشراف جديد' : 'رسالة تواصل',
        body: '$studentName: $trimmed',
        type: 'supervision_request',
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
}
