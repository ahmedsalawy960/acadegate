import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisionRequest {
  final String? id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String supervisorDocId;
  final String supervisorName;
  final String supervisorUniversity;
  final String supervisorOwnerId;
  final String requestType;
  final String message;
  final String status;
  final DateTime? createdAt;

  const SupervisionRequest({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.supervisorDocId,
    required this.supervisorName,
    required this.supervisorUniversity,
    this.supervisorOwnerId = '',
    this.requestType = 'supervision',
    this.message = '',
    this.status = 'pending',
    this.createdAt,
  });

  bool get isSupervision => requestType == 'supervision';

  String get typeLabel => isSupervision ? 'طلب إشراف' : 'رسالة تواصل';

  factory SupervisionRequest.fromMap(Map<String, dynamic> map, {String? id}) {
    final created = map['createdAt'];
    DateTime? createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    }

    return SupervisionRequest(
      id: id,
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      studentEmail: map['studentEmail']?.toString() ?? '',
      supervisorDocId: map['supervisorDocId']?.toString() ?? '',
      supervisorName: map['supervisorName']?.toString() ?? '',
      supervisorUniversity: map['supervisorUniversity']?.toString() ?? '',
      supervisorOwnerId: map['supervisorOwnerId']?.toString() ?? '',
      requestType: map['requestType']?.toString() ?? 'supervision',
      message: map['message']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      createdAt: createdAt,
    );
  }
}
