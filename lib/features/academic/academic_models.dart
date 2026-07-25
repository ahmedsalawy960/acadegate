import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/locale/app_translate.dart';
import '../moderation/approval_status.dart';
import 'faculty_categories.dart';

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
  final String openAlexId;
  final int worksCount;
  final int citedByCount;
  final int hIndex;
  final String scholarUrl;
  final String researchGateUrl;
  final String importSource;
  /// بيانات تجريبية للعرض عند غياب مشرفين حقيقيين في قاعدة البيانات.
  final bool isDemo;

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
    this.openAlexId = '',
    this.worksCount = 0,
    this.citedByCount = 0,
    this.hIndex = 0,
    this.scholarUrl = '',
    this.researchGateUrl = '',
    this.importSource = '',
    this.isDemo = false,
  });

  /// ملف مستورد من OpenAlex/CSV — ليس حساباً حقيقياً للمشرف بعد.
  bool get isImportedListing =>
      importSource == 'openalex' ||
      importSource == 'csv' ||
      (importSource.isEmpty && openAlexId.isNotEmpty);

  /// مشرف مسجّل فعلياً ويمكن مراسلته مباشرة داخل التطبيق.
  bool get hasMessagingAccount =>
      ownerId.isNotEmpty && !isImportedListing;

  bool get hasPublicationIds =>
      openAlexId.isNotEmpty || orcid.isNotEmpty;

  bool get hasStoredMetrics => worksCount > 0 || citedByCount > 0;

  bool get isPubliclyVisible => ApprovalStatus.isPublic(approvalStatus);

  factory AcademicSupervisor.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return AcademicSupervisor(
      id: id,
      name: map['name']?.toString() ?? appTr('بدون اسم', 'Unnamed'),
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
      openAlexId: map['openAlexId']?.toString() ?? '',
      worksCount: _parseInt(map['worksCount']),
      citedByCount: _parseInt(map['citedByCount']),
      hIndex: _parseInt(map['hIndex']),
      scholarUrl: map['scholarUrl']?.toString() ?? '',
      researchGateUrl: map['researchGateUrl']?.toString() ?? '',
      importSource: map['importSource']?.toString() ?? '',
      isDemo: map['isDemo'] as bool? ?? false,
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
  final String category;
  final String status;
  final int votesCount;
  final int proposalsCount;
  final String approvalStatus;
  final String publisherId;
  final String claimedBy;
  final String claimedByName;
  final DateTime? claimedAt;
  final bool funded;
  final String fundAwardId;
  final double? fundedAmount;
  final String fundedCurrency;

  const AcademicResearchIdea({
    this.id,
    required this.title,
    required this.provider,
    required this.details,
    this.tags = const [],
    this.budget = '',
    this.category = '',
    this.status = 'open',
    this.votesCount = 0,
    this.proposalsCount = 0,
    this.approvalStatus = ApprovalStatus.approved,
    this.publisherId = '',
    this.claimedBy = '',
    this.claimedByName = '',
    this.claimedAt,
    this.funded = false,
    this.fundAwardId = '',
    this.fundedAmount,
    this.fundedCurrency = '',
  });

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isClaimed =>
      claimedBy.isNotEmpty || status.toLowerCase() == 'claimed';
  bool get isAvailableForClaim => isOpen && !isClaimed;
  bool get isFromFirebase => id != null && id!.isNotEmpty;
  bool get isPubliclyVisible => ApprovalStatus.isPublic(approvalStatus);

  factory AcademicResearchIdea.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return AcademicResearchIdea(
      id: id,
      title: map['title']?.toString() ?? appTr('بدون عنوان', 'Untitled'),
      provider: map['provider']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      tags: parseStringList(map['tags']),
      budget: map['budget']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      status: map['status']?.toString() ?? 'open',
      votesCount: _parseInt(map['votesCount']),
      proposalsCount: _parseInt(map['proposalsCount']),
      approvalStatus:
          map['approvalStatus']?.toString() ?? ApprovalStatus.approved,
      publisherId: map['publisherId']?.toString() ?? '',
      claimedBy: map['claimedBy']?.toString() ?? '',
      claimedByName: map['claimedByName']?.toString() ?? '',
      claimedAt: _parseDateTime(map['claimedAt']),
      funded: map['funded'] == true,
      fundAwardId: map['fundAwardId']?.toString() ?? '',
      fundedAmount: map['fundedAmount'] is num
          ? (map['fundedAmount'] as num).toDouble()
          : double.tryParse(map['fundedAmount']?.toString() ?? ''),
      fundedCurrency: map['fundedCurrency']?.toString() ?? '',
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
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
      authorName: map['authorName']?.toString() ?? appTr('طالب', 'Student'),
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
      name: map['name']?.toString() ?? appTr('جهاز', 'Device'),
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

/// Lab staff / coordinator contact (often from NBSLE device pages).
class LabContactPerson {
  final String role;
  final String name;
  final String email;
  final String phone;

  const LabContactPerson({
    this.role = '',
    this.name = '',
    this.email = '',
    this.phone = '',
  });

  bool get hasUsableContact {
    final e = email.trim();
    final p = phone.trim();
    return e.contains('@') || p.length >= 8;
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'name': name,
        'email': email,
        'phone': phone,
      };

  factory LabContactPerson.fromMap(Map<String, dynamic> map) {
    var phone = map['phone']?.toString().trim() ?? '';
    if (phone.toLowerCase() == 'null') phone = '';
    return LabContactPerson(
      role: map['role']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: phone,
    );
  }
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
  final String labOwnerId;
  final String labName;
  final bool needsOwnerRouting;

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
    this.labOwnerId = '',
    this.labName = '',
    this.needsOwnerRouting = false,
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
      userName: map['userName']?.toString() ?? appTr('طالب', 'Student'),
      equipmentId: map['equipmentId']?.toString() ?? '',
      equipmentName: map['equipmentName']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      slotStart: map['slotStart']?.toString() ?? '',
      slotEnd: map['slotEnd']?.toString() ?? '',
      status: map['status']?.toString() ?? 'confirmed',
      costEstimate: _parseNum(map['costEstimate']),
      createdAt: created,
      labOwnerId: map['labOwnerId']?.toString() ?? '',
      labName: map['labName']?.toString() ?? '',
      needsOwnerRouting: map['needsOwnerRouting'] == true,
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
      userName: map['userName']?.toString() ?? appTr('طالب', 'Student'),
      rating: _parseInt(map['rating'], fallback: 5).clamp(1, 5),
      comment: map['comment']?.toString() ?? '',
      createdAt: created,
    );
  }
}

/// خدمة تحليل عينات في مختبر أو مركز بحوث.
class SampleAnalysisService {
  final String id;
  final String name;
  final String description;
  final List<String> specialties;
  final List<String> sampleTypes;
  final int turnaroundDays;
  final num priceFrom;

  const SampleAnalysisService({
    required this.id,
    required this.name,
    this.description = '',
    this.specialties = const [],
    this.sampleTypes = const [],
    this.turnaroundDays = 5,
    this.priceFrom = 0,
  });

  factory SampleAnalysisService.fromMap(Map<String, dynamic> map, {String? id}) {
    return SampleAnalysisService(
      id: id ?? map['id']?.toString() ?? map['name']?.toString() ?? 'service',
      name: map['name']?.toString() ?? appTr('تحليل', 'Analysis'),
      description: map['description']?.toString() ?? '',
      specialties: parseStringList(map['specialties']),
      sampleTypes: parseStringList(map['sampleTypes']),
      turnaroundDays: _parseInt(map['turnaroundDays'], fallback: 5),
      priceFrom: _parseNum(map['priceFrom'] ?? map['price']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'specialties': specialties,
        'sampleTypes': sampleTypes,
        'turnaroundDays': turnaroundDays,
        'priceFrom': priceFrom,
      };
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
  final String labType;
  final String category;
  final String facultyId;
  final String facultyNameAr;
  final String description;
  final bool acceptsExternalSamples;
  final String contactEmail;
  final String contactPhone;
  final String contactName;
  final List<LabContactPerson> contacts;
  final List<SampleAnalysisService> sampleServices;
  final String importSource;
  final String sourceUrl;
  final String nbsleLabId;
  /// Device count when [equipmentList] was not fully parsed (list views).
  final int equipmentCountHint;

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
    this.labType = 'university_lab',
    this.category = '',
    this.facultyId = '',
    this.facultyNameAr = '',
    this.description = '',
    this.acceptsExternalSamples = true,
    this.contactEmail = '',
    this.contactPhone = '',
    this.contactName = '',
    this.contacts = const [],
    this.sampleServices = const [],
    this.importSource = '',
    this.sourceUrl = '',
    this.nbsleLabId = '',
    this.equipmentCountHint = 0,
  });

  bool get isFromFirebase => id != null && id!.isNotEmpty;
  bool get isPubliclyVisible => ApprovalStatus.isPublic(approvalStatus);
  bool get isResearchCenter =>
      labType == 'research_center' || labType == 'core_facility';
  bool get offersSampleAnalysis => sampleServices.isNotEmpty;
  bool get isUnowned => ownerId.trim().isEmpty;
  bool get isNbsleImport =>
      importSource == 'nbsle' || nbsleLabId.trim().isNotEmpty;
  int get deviceCount =>
      equipmentList.isNotEmpty ? equipmentList.length : equipmentCountHint;

  bool get hasLabContact {
    if (contactEmail.contains('@') || contactPhone.trim().length >= 8) {
      return true;
    }
    return contacts.any((c) => c.hasUsableContact);
  }

  String get displayContactEmail {
    if (contactEmail.contains('@')) return contactEmail.trim();
    for (final c in contacts) {
      if (c.email.contains('@')) return c.email.trim();
    }
    return '';
  }

  String get displayContactPhone {
    if (contactPhone.trim().length >= 8) return contactPhone.trim();
    for (final c in contacts) {
      if (c.phone.trim().length >= 8) return c.phone.trim();
    }
    return '';
  }

  String get labTypeLabel => switch (labType) {
        'research_center' => appTr('مركز بحوث', 'Research center'),
        'core_facility' => appTr('منشأة تحليل مركزية', 'Core analysis facility'),
        _ => appTr('مختبر جامعي', 'University lab'),
      };

  String get linkedFacultyId =>
      facultyId.isNotEmpty ? facultyId : category;

  String get displayFacultyName => facultyNameAr.isNotEmpty
      ? facultyNameAr
      : facultyTitleForCategory(linkedFacultyId);

  bool get hasFacultyLink => linkedFacultyId.isNotEmpty;

  /// هل ينتمي المختبر/المركز لهذه الكلية؟
  bool matchesFaculty(String facultyCategoryId) {
    if (facultyCategoryId.isEmpty || facultyCategoryId == 'All') return true;
    if (linkedFacultyId == facultyCategoryId) return true;
    return matchesSpecialty(facultyCategoryId);
  }

  String get displayEquipment {
    if (equipmentList.isNotEmpty) {
      return equipmentList.map((item) => item.name).join('، ');
    }
    return equipment;
  }

  int get minWaitDays {
    if (sampleServices.isNotEmpty) {
      return sampleServices
          .map((s) => s.turnaroundDays)
          .reduce((a, b) => a < b ? a : b);
    }
    if (equipmentList.isEmpty) return defaultWaitDays;
    return equipmentList.map((item) => item.waitDays).reduce(
          (a, b) => a < b ? a : b,
        );
  }

  num get minCost {
    if (sampleServices.isNotEmpty) {
      final prices = sampleServices.map((s) => s.priceFrom).where((p) => p > 0);
      if (prices.isNotEmpty) {
        return prices.reduce((a, b) => a < b ? a : b);
      }
    }
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

  bool matchesSpecialty(String specialtyId) {
    if (specialtyId.isEmpty || specialtyId == 'All') return true;
    if (category == specialtyId) return true;
    if (tags.any((tag) => tag.toLowerCase().contains(specialtyId.toLowerCase()))) {
      return true;
    }
    return sampleServices.any(
      (service) => service.specialties.any(
        (s) => s.toLowerCase() == specialtyId.toLowerCase(),
      ),
    );
  }

  factory AcademicLab.fromMap(
    Map<String, dynamic> map, {
    String? id,
    bool lightweight = false,
  }) {
    List<LabEquipment> parsedEquipment = const [];
    List<SampleAnalysisService> parsedServices = const [];
    var equipmentCountHint = 0;

    final rawEquipmentList = map['equipmentList'];
    if (rawEquipmentList is List) {
      equipmentCountHint = rawEquipmentList.length;
      if (!lightweight) {
        parsedEquipment = rawEquipmentList
            .whereType<Map>()
            .map(
              (item) => LabEquipment.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
    }

    final rawServices = map['sampleServices'];
    if (rawServices is List && !lightweight) {
      parsedServices = rawServices
          .whereType<Map>()
          .map(
            (item) => SampleAnalysisService.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } else if (rawServices is List) {
      // Lightweight: keep empty services but know if any exist via flag below.
      equipmentCountHint = equipmentCountHint; // no-op keep analyzer happy
    }

    // For lightweight list rows, detect "has sample services" without full parse.
    final hasSampleServicesFlag = rawServices is List && rawServices.isNotEmpty;

    return AcademicLab(
      id: id,
      name: map['name']?.toString() ?? appTr('بدون اسم', 'Unnamed'),
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
      labType: map['labType']?.toString() ?? 'university_lab',
      facultyId: _readFacultyId(map),
      facultyNameAr: _readFacultyNameAr(map),
      category: _readFacultyId(map),
      description: lightweight
          ? ''
          : (map['description']?.toString() ?? ''),
      acceptsExternalSamples: map['acceptsExternalSamples'] as bool? ?? true,
      contactEmail: map['contactEmail']?.toString() ?? '',
      contactPhone: map['contactPhone']?.toString() ?? '',
      contactName: map['contactName']?.toString() ?? '',
      contacts: () {
        final raw = map['contacts'];
        if (raw is! List) return const <LabContactPerson>[];
        return raw
            .whereType<Map>()
            .map((item) => LabContactPerson.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      }(),
      sampleServices: lightweight && hasSampleServicesFlag
          ? [
              // Placeholder so offersSampleAnalysis is true in list filters.
              SampleAnalysisService(
                id: '_listed',
                name: appTr('خدمات تحليل', 'Analysis services'),
              ),
            ]
          : parsedServices,
      importSource: map['importSource']?.toString() ?? '',
      sourceUrl: map['sourceUrl']?.toString() ?? '',
      nbsleLabId:
          (map['nbsleLabId'] ?? map['externalId'])?.toString() ?? '',
      equipmentCountHint: equipmentCountHint,
    );
  }
}

String _readFacultyId(Map<String, dynamic> map) {
  final raw = map['facultyId']?.toString() ?? map['category']?.toString() ?? '';
  return resolveFacultyId(raw) ?? raw;
}

String _readFacultyNameAr(Map<String, dynamic> map) {
  final stored = map['facultyNameAr']?.toString() ?? '';
  if (stored.isNotEmpty) return stored;
  final facultyId = _readFacultyId(map);
  if (facultyId.isEmpty) return '';
  return facultyNameForStorage(facultyId);
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
