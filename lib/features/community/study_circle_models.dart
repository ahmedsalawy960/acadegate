import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/locale/app_translate.dart';

class StudyCircle {
  final String id;
  final String title;
  final String description;
  final String facultyCategory;
  final String specialization;
  final String researchInterest;
  final String creatorId;
  final String creatorName;
  final String? researchRoomId;
  final int membersCount;
  final DateTime? createdAt;

  const StudyCircle({
    required this.id,
    required this.title,
    required this.description,
    required this.facultyCategory,
    required this.specialization,
    required this.researchInterest,
    required this.creatorId,
    required this.creatorName,
    this.researchRoomId,
    this.membersCount = 0,
    this.createdAt,
  });

  factory StudyCircle.fromMap(String id, Map<String, dynamic> map) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    return StudyCircle(
      id: id,
      title: map['title']?.toString() ??
          appTr('دائرة دراسة', 'Study circle'),
      description: map['description']?.toString() ?? '',
      facultyCategory: map['facultyCategory']?.toString() ?? '',
      specialization: map['specialization']?.toString() ?? '',
      researchInterest: map['researchInterest']?.toString() ?? '',
      creatorId: map['creatorId']?.toString() ?? '',
      creatorName: map['creatorName']?.toString() ??
          appTr('باحث', 'Researcher'),
      researchRoomId: map['researchRoomId']?.toString(),
      membersCount: map['membersCount'] is int
          ? map['membersCount'] as int
          : int.tryParse('${map['membersCount']}') ?? 0,
      createdAt: created,
    );
  }
}
