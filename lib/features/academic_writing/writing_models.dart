import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/locale/app_translate.dart';
import '../moderation/approval_status.dart';

List<String> parseStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

class WritingExpert {
  final String? id;
  final String name;
  final String category;
  final String speciality;
  final String bio;
  final String priceRange;
  final int deliveryDaysMin;
  final int deliveryDaysMax;
  final double rating;
  final int completedOrders;
  final List<String> languages;
  final List<String> tools;
  final List<String> tags;
  final String contact;
  final String approvalStatus;
  final String? ownerId;
  /// Anonymized work samples shown on the writer profile.
  final List<String> portfolioSamples;
  /// Average delivery days from completed orders (0 = unknown).
  final double avgDeliveryDays;

  const WritingExpert({
    this.id,
    required this.name,
    required this.category,
    required this.speciality,
    required this.bio,
    required this.priceRange,
    this.deliveryDaysMin = 3,
    this.deliveryDaysMax = 14,
    this.rating = 4.5,
    this.completedOrders = 0,
    this.languages = const ['العربية', 'الإنجليزية'],
    this.tools = const [],
    this.tags = const [],
    this.contact = '',
    this.approvalStatus = ApprovalStatus.approved,
    this.ownerId,
    this.portfolioSamples = const [],
    this.avgDeliveryDays = 0,
  });

  bool get isFromFirebase => id != null && id!.isNotEmpty;

  bool get isPubliclyVisible => ApprovalStatus.isPublic(approvalStatus);

  String get deliveryLabel => appTr(
        '$deliveryDaysMin–$deliveryDaysMax يوم',
        '$deliveryDaysMin–$deliveryDaysMax days',
      );

  String get avgDeliveryLabel {
    if (avgDeliveryDays <= 0) return deliveryLabel;
    final days = avgDeliveryDays.round();
    return appTr('متوسط التسليم: $days يوم', 'Avg delivery: $days days');
  }

  factory WritingExpert.fromMap(Map<String, dynamic> map, {String? id}) {
    return WritingExpert(
      id: id,
      name: map['name']?.toString() ?? appTr('كاتب أكاديمي', 'Academic writer'),
      category: map['category']?.toString() ?? '',
      speciality: map['speciality']?.toString() ?? '',
      bio: map['bio']?.toString() ?? '',
      priceRange: map['priceRange']?.toString() ?? appTr('حسب الطلب', 'On request'),
      deliveryDaysMin: (map['deliveryDaysMin'] as num?)?.toInt() ?? 3,
      deliveryDaysMax: (map['deliveryDaysMax'] as num?)?.toInt() ?? 14,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      completedOrders: (map['completedOrders'] as num?)?.toInt() ?? 0,
      languages: parseStringList(map['languages']),
      tools: parseStringList(map['tools']),
      tags: parseStringList(map['tags']),
      contact: map['contact']?.toString() ?? '',
      approvalStatus:
          map['approvalStatus']?.toString() ?? ApprovalStatus.approved,
      ownerId: map['ownerId']?.toString(),
      portfolioSamples: parseStringList(map['portfolioSamples']),
      avgDeliveryDays: (map['avgDeliveryDays'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'speciality': speciality,
        'bio': bio,
        'priceRange': priceRange,
        'deliveryDaysMin': deliveryDaysMin,
        'deliveryDaysMax': deliveryDaysMax,
        'rating': rating,
        'completedOrders': completedOrders,
        'languages': languages,
        'tools': tools,
        'tags': tags,
        'contact': contact,
        'approvalStatus': approvalStatus,
        'portfolioSamples': portfolioSamples,
        'avgDeliveryDays': avgDeliveryDays,
        if (ownerId != null) 'ownerId': ownerId,
      };
}

class WritingOrder {
  final String? id;
  final String? serviceId;
  final String userId;
  final String userName;
  final String expertName;
  final String category;
  final String topic;
  final String requirements;
  final String academicLevel;
  final String citationStyle;
  final String language;
  final String urgency;
  final String wordCount;
  final String statisticsTool;
  final List<String> addons;
  /// Selected thesis package stages (empty = single delivery).
  final List<String> milestones;
  final DateTime? deadline;
  final String status;
  final String? serviceOwnerId;
  final String paymentStatus;
  final String paymentMethod;
  final num amount;
  final String deliveryNote;
  final int? studentRating;
  final String rejectedReason;
  final DateTime? createdAt;

  const WritingOrder({
    this.id,
    this.serviceId,
    required this.userId,
    required this.userName,
    required this.expertName,
    required this.category,
    required this.topic,
    required this.requirements,
    required this.academicLevel,
    required this.citationStyle,
    required this.language,
    required this.urgency,
    required this.wordCount,
    this.statisticsTool = 'لا ينطبق',
    this.addons = const [],
    this.milestones = const [],
    this.deadline,
    this.status = 'pending',
    this.serviceOwnerId,
    this.paymentStatus = 'pending_payment',
    this.paymentMethod = 'paymob',
    this.amount = 0,
    this.deliveryNote = '',
    this.studentRating,
    this.rejectedReason = '',
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isInProgress => status == 'in_progress';
  bool get isDelivered => status == 'delivered';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  bool get isPaidHeld => paymentStatus == 'paid_held';
  bool get isManualPayment => paymentMethod == 'manual';

  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return appTr('مقبول', 'Accepted');
      case 'in_progress':
        return appTr('قيد التنفيذ', 'In progress');
      case 'delivered':
        return appTr('تم التسليم', 'Delivered');
      case 'completed':
        return appTr('مكتمل', 'Completed');
      case 'cancelled':
        return appTr('ملغى', 'Cancelled');
      case 'rejected':
        return appTr('مرفوض', 'Rejected');
      default:
        return appTr('بانتظار قبول الخبير', 'Awaiting expert acceptance');
    }
  }

  factory WritingOrder.fromMap(Map<String, dynamic> map, {String? id}) {
    final deadlineRaw = map['deadline'];
    DateTime? deadline;
    if (deadlineRaw is Timestamp) deadline = deadlineRaw.toDate();

    final createdRaw = map['createdAt'];
    DateTime? createdAt;
    if (createdRaw is Timestamp) createdAt = createdRaw.toDate();

    return WritingOrder(
      id: id,
      serviceId: map['serviceId']?.toString(),
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      expertName: map['expertName']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      topic: map['topic']?.toString() ?? '',
      requirements: map['requirements']?.toString() ?? '',
      academicLevel: map['academicLevel']?.toString() ?? '',
      citationStyle: map['citationStyle']?.toString() ?? '',
      language: map['language']?.toString() ?? '',
      urgency: map['urgency']?.toString() ?? '',
      wordCount: map['wordCount']?.toString() ?? '',
      statisticsTool: map['statisticsTool']?.toString() ?? 'لا ينطبق',
      addons: parseStringList(map['addons']),
      milestones: parseStringList(map['milestones']),
      deadline: deadline,
      status: map['status']?.toString() ?? 'pending',
      serviceOwnerId: map['serviceOwnerId']?.toString(),
      paymentStatus: map['paymentStatus']?.toString() ?? 'pending_payment',
      paymentMethod: map['paymentMethod']?.toString() ?? 'paymob',
      amount: (map['amount'] as num?) ?? 0,
      deliveryNote: map['deliveryNote']?.toString() ?? '',
      studentRating: (map['studentRating'] as num?)?.toInt(),
      rejectedReason: map['rejectedReason']?.toString() ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (serviceId != null) 'serviceId': serviceId,
        'userId': userId,
        'userName': userName,
        'expertName': expertName,
        'category': category,
        'topic': topic,
        'requirements': requirements,
        'academicLevel': academicLevel,
        'citationStyle': citationStyle,
        'language': language,
        'urgency': urgency,
        'wordCount': wordCount,
        'statisticsTool': statisticsTool,
        'addons': addons,
        'milestones': milestones,
        if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
