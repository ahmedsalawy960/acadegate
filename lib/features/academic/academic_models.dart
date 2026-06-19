import 'package:cloud_firestore/cloud_firestore.dart';
import '../moderation/approval_status.dart';

List<String> parseStringList(
  dynamic value, {
  List<String> fallback = const [],
}) {
  if (value is List) {
    return value.map((item) => item.toString()).where((s) => s.isNotEmpty).toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[،,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return fallback;
}

class AcademicSupervisor {
  final String? id;
  final String name;
  final String university;
  final String speciality;
  final String bio;
  final String faculty;
  final String category;
  final List<String> tags;
  final List<String> methodologies;
  final bool isAvailable;
  final String ownerId;
  final String approvalStatus;
  final String verificationStatus;
  final String orcid;
  final String universityEmail;
  final String photoUrl;

  const AcademicSupervisor({
    this.id,
    required this.name,
    required this.university,
    required this.speciality,
    required this.bio,
    required this.faculty,
    required this.category,
    this.tags = const [],
    this.methodologies = const ['كمي', 'نوعي', 'مختلط'],
    this.isAvailable = true,
    this.ownerId = '',
    this.approvalStatus = ApprovalStatus.approved,
    this.verificationStatus = 'unverified',
    this.orcid = '',
    this.universityEmail = '',
    this.photoUrl = '',
  });

  bool get isPubliclyVisible => ApprovalStatus.isPublic(approvalStatus);

  factory AcademicSupervisor.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return AcademicSupervisor(
      id: id,
      name: map['name']?.toString() ?? 'بدون اسم',
      university: map['university']?.toString() ?? '',
      speciality: map['speciality']?.toString() ?? '',
      bio: map['bio']?.toString() ?? '',
      faculty: map['faculty']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      tags: parseStringList(map['tags']),
      methodologies: parseStringList(
        map['methodologies'],
        fallback: const ['كمي', 'نوعي', 'مختلط'],
      ),
      isAvailable: map['isAvailable'] as bool? ?? true,
      ownerId: map['ownerId']?.toString() ?? '',
      approvalStatus:
          map['approvalStatus']?.toString() ?? ApprovalStatus.approved,
      verificationStatus: map['verificationStatus']?.toString() ?? 'unverified',
      orcid: map['orcid']?.toString() ?? '',
      universityEmail: map['universityEmail']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString() ?? '',
    );
  }
}

class AcademicResearchIdea {
  final String? id;
  final String title;
  final String provider;
  final String details;
  final List<String> tags;
  final String budget;
  final String status;
  final int votesCount;
  final int proposalsCount;
  final String approvalStatus;
  final String publisherId;

  const AcademicResearchIdea({
    this.id,
    required this.title,
    required this.provider,
    required this.details,
    this.tags = const [],
    this.budget = '',
    this.status = 'open',
    this.votesCount = 0,
    this.proposalsCount = 0,
    this.approvalStatus = ApprovalStatus.approved,
    this.publisherId = '',
  });

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isFromFirebase => id != null && id!.isNotEmpty;
  bool get isPubliclyVisible => ApprovalStatus.isPublic(approvalStatus);

  factory AcademicResearchIdea.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return AcademicResearchIdea(
      id: id,
      title: map['title']?.toString() ?? 'بدون عنوان',
      provider: map['provider']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      tags: parseStringList(map['tags']),
      budget: map['budget']?.toString() ?? '',
      status: map['status']?.toString() ?? 'open',
      votesCount: _parseInt(map['votesCount']),
      proposalsCount: _parseInt(map['proposalsCount']),
      approvalStatus:
          map['approvalStatus']?.toString() ?? ApprovalStatus.approved,
      publisherId: map['publisherId']?.toString() ?? '',
    );
  }
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class ResearchProposal {
  final String? id;
  final String ideaId;
  final String userId;
  final String authorName;
  final String authorEmail;
  final String summary;
  final String status;
  final DateTime? createdAt;

  const ResearchProposal({
    this.id,
    required this.ideaId,
    this.userId = '',
    required this.authorName,
    required this.authorEmail,
    required this.summary,
    this.status = 'pending',
    this.createdAt,
  });

  factory ResearchProposal.fromMap(
    Map<String, dynamic> map, {
    String? id,
    required String ideaId,
  }) {
    DateTime? created;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    }

    return ResearchProposal(
      id: id,
      ideaId: ideaId,
      userId: map['userId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ?? 'طالب',
      authorEmail: map['authorEmail']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      createdAt: created,
    );
  }
}

class LabEquipment {
  final String id;
  final String name;
  final String code;
  final num costPerSession;
  final int durationMinutes;
  final int waitDays;
  final String storeCategoryTitle;

  const LabEquipment({
    required this.id,
    required this.name,
    this.code = '',
    this.costPerSession = 0,
    this.durationMinutes = 120,
    this.waitDays = 3,
    this.storeCategoryTitle = '',
  });

  factory LabEquipment.fromMap(Map<String, dynamic> map, {String? id}) {
    return LabEquipment(
      id: id ?? map['id']?.toString() ?? map['code']?.toString() ?? 'device',
      name: map['name']?.toString() ?? 'جهاز',
      code: map['code']?.toString() ?? '',
      costPerSession: _parseNum(map['costPerSession'] ?? map['cost']),
      durationMinutes: _parseInt(map['durationMinutes'], fallback: 120),
      waitDays: _parseInt(map['waitDays'], fallback: 3),
      storeCategoryTitle: map['storeCategoryTitle']?.toString() ?? '',
    );
  }
}

num _parseNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

class LabBooking {
  final String? id;
  final String labId;
  final String userId;
  final String userName;
  final String equipmentId;
  final String equipmentName;
  final String date;
  final String slotStart;
  final String slotEnd;
  final String status;
  final num costEstimate;
  final DateTime? createdAt;

  const LabBooking({
    this.id,
    required this.labId,
    required this.userId,
    required this.userName,
    required this.equipmentId,
    required this.equipmentName,
    required this.date,
    required this.slotStart,
    required this.slotEnd,
    this.status = 'confirmed',
    this.costEstimate = 0,
    this.createdAt,
  });

  bool get isConfirmed => status == 'confirmed';

  factory LabBooking.fromMap(
    Map<String, dynamic> map, {
    String? id,
    required String labId,
  }) {
    DateTime? created;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    }

    return LabBooking(
      id: id,
      labId: labId,
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? 'طالب',
      equipmentId: map['equipmentId']?.toString() ?? '',
      equipmentName: map['equipmentName']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      slotStart: map['slotStart']?.toString() ?? '',
      slotEnd: map['slotEnd']?.toString() ?? '',
      status: map['status']?.toString() ?? 'confirmed',
      costEstimate: _parseNum(map['costEstimate']),
      createdAt: created,
    );
  }
}

class LabRating {
  final String? id;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const LabRating({
    this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    this.comment = '',
    this.createdAt,
  });

  factory LabRating.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    DateTime? created;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    }

    return LabRating(
      id: id,
      userId: map['userId']?.toString() ?? id ?? '',
      userName: map['userName']?.toString() ?? 'طالب',
      rating: _parseInt(map['rating'], fallback: 5).clamp(1, 5),
      comment: map['comment']?.toString() ?? '',
      createdAt: created,
    );
  }
}

class AcademicLab {
  final String? id;
  final String name;
  final String location;
  final String equipment;
  final List<String> tags;
  final String city;
  final String university;
  final double ratingAvg;
  final int ratingsCount;
  final int defaultWaitDays;
  final List<LabEquipment> equipmentList;
  final String ownerId;
  final String approvalStatus;

  const AcademicLab({
    this.id,
    required this.name,
    required this.location,
    required this.equipment,
    this.tags = const [],
    this.city = '',
    this.university = '',
    this.ratingAvg = 0,
    this.ratingsCount = 0,
    this.defaultWaitDays = 3,
    this.equipmentList = const [],
    this.ownerId = '',
    this.approvalStatus = ApprovalStatus.approved,
  });

  bool get isFromFirebase => id != null && id!.isNotEmpty;
  bool get isPubliclyVisible => ApprovalStatus.isPublic(approvalStatus);

  String get displayEquipment {
    if (equipmentList.isNotEmpty) {
      return equipmentList.map((item) => item.name).join('، ');
    }
    return equipment;
  }

  int get minWaitDays {
    if (equipmentList.isEmpty) return defaultWaitDays;
    return equipmentList.map((item) => item.waitDays).reduce(
          (a, b) => a < b ? a : b,
        );
  }

  num get minCost {
    if (equipmentList.isEmpty) return 0;
    return equipmentList.map((item) => item.costPerSession).reduce(
          (a, b) => a < b ? a : b,
        );
  }

  List<LabEquipment> get devices {
    if (equipmentList.isNotEmpty) return equipmentList;
    if (equipment.trim().isEmpty) return const [];
    return [
      LabEquipment(
        id: 'main',
        name: equipment,
        waitDays: defaultWaitDays,
      ),
    ];
  }

  factory AcademicLab.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    final rawEquipmentList = map['equipmentList'];
    List<LabEquipment> parsedEquipment = const [];
    if (rawEquipmentList is List) {
      parsedEquipment = rawEquipmentList
          .whereType<Map>()
          .map(
            (item) => LabEquipment.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return AcademicLab(
      id: id,
      name: map['name']?.toString() ?? 'بدون اسم',
      location: map['location']?.toString() ?? '',
      equipment: map['equipment']?.toString() ?? '',
      tags: parseStringList(map['tags']),
      city: map['city']?.toString() ?? '',
      university: map['university']?.toString() ?? '',
      ratingAvg: _parseNum(map['ratingAvg']).toDouble(),
      ratingsCount: _parseInt(map['ratingsCount']),
      defaultWaitDays: _parseInt(map['waitDays'] ?? map['defaultWaitDays'],
          fallback: 3),
      equipmentList: parsedEquipment,
      ownerId: map['ownerId']?.toString() ?? '',
      approvalStatus:
          map['approvalStatus']?.toString() ?? ApprovalStatus.approved,
    );
  }
}

class AcademicContent {
  final List<AcademicSupervisor> supervisors;
  final List<AcademicResearchIdea> ideas;
  final List<AcademicLab> labs;

  const AcademicContent({
    required this.supervisors,
    required this.ideas,
    required this.labs,
  });

  static const empty = AcademicContent(
    supervisors: [],
    ideas: [],
    labs: [],
  );
}
