import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../academic/academic_models.dart';
import '../notifications/notification_service.dart';

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
  });

  factory SampleAnalysisRequest.fromMap(Map<String, dynamic> map, {String? id}) {
    final created = map['createdAt'];
    DateTime? createdAt;
    if (created is Timestamp) createdAt = created.toDate();

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
    if (user == null) throw Exception('سجّل الدخول لطلب تحليل العينة');

    final studentName =
        user.displayName ?? user.email?.split('@').first ?? 'باحث';

    await _requests.add({
      'studentId': user.uid,
      'studentName': studentName,
      'studentEmail': user.email ?? '',
      'labId': lab.id ?? '',
      'labName': lab.name,
      'labOwnerId': lab.ownerId,
      'serviceId': service.id,
      'serviceName': service.name,
      'specialty': specialty,
      'sampleType': sampleType,
      'sampleCount': sampleCount,
      'researchTitle': researchTitle.trim(),
      'notes': notes.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (lab.ownerId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: lab.ownerId,
        title: 'طلب تحليل عينة',
        body: '$studentName — ${service.name}',
        type: 'sample_analysis',
      );
    }
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

  Future<void> updateStatus(String requestId, String status) async {
    await _requests.doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
