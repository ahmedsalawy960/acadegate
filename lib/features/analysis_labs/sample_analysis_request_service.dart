import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../academic/academic_models.dart';
import '../notifications/admin_recipient_service.dart';
import '../notifications/notification_service.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import 'sample_analysis_sla.dart';

class SampleAnalysisRequest {
  final String? id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String labId;
  final String labName;
  final String labOwnerId;
  final String serviceId;
  final String serviceName;
  final String specialty;
  final String sampleType;
  final int sampleCount;
  final String researchTitle;
  final String notes;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final int turnaroundDays;
  final int slaResponseDays;

  const SampleAnalysisRequest({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.labId,
    required this.labName,
    this.labOwnerId = '',
    required this.serviceId,
    required this.serviceName,
    this.specialty = '',
    this.sampleType = '',
    this.sampleCount = 1,
    this.researchTitle = '',
    this.notes = '',
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.turnaroundDays = 5,
    this.slaResponseDays = SampleAnalysisSla.responseDaysDefault,
  });

  factory SampleAnalysisRequest.fromMap(Map<String, dynamic> map, {String? id}) {
    final created = map['createdAt'];
    DateTime? createdAt;
    if (created is Timestamp) createdAt = created.toDate();

    final updated = map['updatedAt'];
    DateTime? updatedAt;
    if (updated is Timestamp) updatedAt = updated.toDate();

    final accepted = map['acceptedAt'];
    DateTime? acceptedAt;
    if (accepted is Timestamp) acceptedAt = accepted.toDate();

    return SampleAnalysisRequest(
      id: id,
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      studentEmail: map['studentEmail']?.toString() ?? '',
      labId: map['labId']?.toString() ?? '',
      labName: map['labName']?.toString() ?? '',
      labOwnerId: map['labOwnerId']?.toString() ?? '',
      serviceId: map['serviceId']?.toString() ?? '',
      serviceName: map['serviceName']?.toString() ?? '',
      specialty: map['specialty']?.toString() ?? '',
      sampleType: map['sampleType']?.toString() ?? '',
      sampleCount: _parseInt(map['sampleCount'], fallback: 1),
      researchTitle: map['researchTitle']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      createdAt: createdAt,
      updatedAt: updatedAt,
      acceptedAt: acceptedAt,
      turnaroundDays: _parseInt(map['turnaroundDays'], fallback: 5),
      slaResponseDays: _parseInt(
        map['slaResponseDays'],
        fallback: SampleAnalysisSla.responseDaysDefault,
      ),
    );
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class SampleAnalysisRequestService {
  SampleAnalysisRequestService._();

  static final SampleAnalysisRequestService instance =
      SampleAnalysisRequestService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('sample_analysis_requests');

  Future<void> submit({
    required AcademicLab lab,
    required SampleAnalysisService service,
    required String specialty,
    required String sampleType,
    required int sampleCount,
    required String researchTitle,
    required String notes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
        appTr(
          'سجّل الدخول لطلب تحليل العينة',
          'Sign in to request sample analysis',
        ),
      );
    }

    final studentName =
        user.displayName ??
        user.email?.split('@').first ??
        appTr('باحث', 'Researcher');

    await _requests.add({
      'studentId': user.uid,
      'studentName': studentName,
      'studentEmail': user.email ?? '',
      'labId': lab.id ?? '',
      'labName': lab.name,
      'labOwnerId': lab.ownerId,
      'needsOwnerRouting': lab.ownerId.trim().isEmpty,
      'serviceId': service.id,
      'serviceName': service.name,
      'specialty': specialty,
      'sampleType': sampleType,
      'sampleCount': sampleCount,
      'researchTitle': researchTitle.trim(),
      'notes': notes.trim(),
      'status': 'pending',
      'turnaroundDays': service.turnaroundDays,
      'slaResponseDays': SampleAnalysisSla.responseDaysDefault,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final summary = '$studentName — ${service.name} @ ${lab.name}';
    if (lab.ownerId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: lab.ownerId,
        title: appTr('طلب تحليل عينة', 'Sample analysis request'),
        body: summary,
        type: 'sample_analysis',
        contextId: lab.id ?? '',
        contextType: 'lab',
      );
    } else {
      await AdminRecipientService.instance.notifyAllAdmins(
        title: appTr(
          'طلب تحليل على مختبر غير مربوط',
          'Sample request on unowned lab',
        ),
        body: summary,
        type: 'sample_analysis',
        contextId: lab.id ?? '',
        contextType: 'lab',
      );
    }

    await ThesisProgressService.instance.recordActivity(
      ThesisActivityId.dataCollection.name,
    );
  }

  Stream<List<SampleAnalysisRequest>> myRequestsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _requests
        .where('studentId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SampleAnalysisRequest.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Stream<List<SampleAnalysisRequest>> incomingForLabOwnerStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _requests
        .where('labOwnerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SampleAnalysisRequest.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  /// Unowned / admin-routed sample analysis requests.
  Stream<List<SampleAnalysisRequest>> unownedOpsStream() {
    return _requests
        .where('needsOwnerRouting', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SampleAnalysisRequest.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  Future<void> updateStatus(String requestId, String status) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'accepted') {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    }
    await _requests.doc(requestId).update(updates);
  }

  /// Cancel an open request (student or lab owner).
  Future<void> cancelRequest(String requestId) async {
    await updateStatus(requestId, 'cancelled');
  }

  /// Permanently remove a terminal request from the list.
  Future<void> deleteRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    await _requests.doc(requestId).delete();
  }

  /// Cancel open requests then delete; delete terminal statuses outright.
  Future<void> removeRequest(SampleAnalysisRequest request) async {
    final id = request.id;
    if (id == null || id.isEmpty) return;

    const open = {'pending', 'quoted', 'accepted'};
    if (open.contains(request.status)) {
      await cancelRequest(id);
    }
    await deleteRequest(id);
  }
}
