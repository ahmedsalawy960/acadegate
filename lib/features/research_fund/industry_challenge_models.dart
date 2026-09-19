import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/escrow/escrow_service.dart';
import '../../core/escrow/payment_status.dart';
import '../../core/locale/app_translate.dart';
import '../notifications/notification_service.dart';
import 'industry_challenge_ops.dart';

class IndustryChallenge {
  final String? id;
  final String title;
  final String problem;
  final String acceptanceCriteria;
  final double budgetAmount;
  final String currency;
  final String companyId;
  final String companyName;
  final String status;
  final String paymentStatus;
  final int protocolsCount;
  final String awardedProtocolId;
  final String awardedResearcherId;
  final DateTime? deadline;
  final DateTime? createdAt;

  const IndustryChallenge({
    this.id,
    required this.title,
    required this.problem,
    required this.acceptanceCriteria,
    required this.budgetAmount,
    required this.currency,
    required this.companyId,
    required this.companyName,
    this.status = IndustryChallengeOps.open,
    this.paymentStatus = PaymentStatus.pending,
    this.protocolsCount = 0,
    this.awardedProtocolId = '',
    this.awardedResearcherId = '',
    this.deadline,
    this.createdAt,
  });

  bool get depositHeld => paymentStatus == PaymentStatus.held;
  bool get isOpen => status == IndustryChallengeOps.open;

  factory IndustryChallenge.fromMap(Map<String, dynamic> map, {String? id}) {
    return IndustryChallenge(
      id: id,
      title: map['title']?.toString() ?? '',
      problem: map['problem']?.toString() ?? '',
      acceptanceCriteria: map['acceptanceCriteria']?.toString() ?? '',
      budgetAmount: _parseDouble(map['budgetAmount']),
      currency: map['currency']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      status: map['status']?.toString() ?? IndustryChallengeOps.open,
      paymentStatus: map['paymentStatus']?.toString() ?? PaymentStatus.pending,
      protocolsCount: _parseInt(map['protocolsCount']),
      awardedProtocolId: map['awardedProtocolId']?.toString() ?? '',
      awardedResearcherId: map['awardedResearcherId']?.toString() ?? '',
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class ChallengeProtocol {
  final String? id;
  final String challengeId;
  final String researcherId;
  final String researcherName;
  final String summary;
  final String status;
  final DateTime? createdAt;

  const ChallengeProtocol({
    this.id,
    required this.challengeId,
    required this.researcherId,
    required this.researcherName,
    required this.summary,
    this.status = IndustryChallengeOps.protocolSubmitted,
    this.createdAt,
  });

  factory ChallengeProtocol.fromMap(Map<String, dynamic> map, {String? id}) {
    return ChallengeProtocol(
      id: id,
      challengeId: map['challengeId']?.toString() ?? '',
      researcherId: map['researcherId']?.toString() ?? '',
      researcherName: map['researcherName']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      status: map['status']?.toString() ?? IndustryChallengeOps.protocolSubmitted,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class IndustryChallengeService {
  IndustryChallengeService._();

  static final IndustryChallengeService instance = IndustryChallengeService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _db.collection('industry_challenges');

  CollectionReference<Map<String, dynamic>> get _protocols =>
      _db.collection('industry_challenge_protocols');

  Stream<List<IndustryChallenge>> watchChallenges() {
    return _challenges
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => IndustryChallenge.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Future<List<IndustryChallenge>> getRecentChallenges({int limit = 40}) async {
    try {
      final snap = await _challenges
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => IndustryChallenge.fromMap(d.data(), id: d.id))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Stream<List<IndustryChallenge>> watchMyChallenges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);
    return _challenges
        .where('companyId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => IndustryChallenge.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<IndustryChallenge?> watchChallenge(String id) {
    return _challenges.doc(id).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return IndustryChallenge.fromMap(data, id: snap.id);
    });
  }

  Future<IndustryChallenge?> getChallengeById(String id) async {
    final snap = await _challenges.doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    return IndustryChallenge.fromMap(data, id: snap.id);
  }

  Stream<List<ChallengeProtocol>> watchProtocols(String challengeId) {
    return _protocols
        .where('challengeId', isEqualTo: challengeId)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChallengeProtocol.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<List<ChallengeProtocol>> watchMyProtocolOnChallenge(String challengeId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || challengeId.isEmpty) {
      return Stream.value(const []);
    }
    return _protocols
        .where('challengeId', isEqualTo: challengeId)
        .where('researcherId', isEqualTo: user.uid)
        .limit(5)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChallengeProtocol.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Future<String> createChallenge({
    required String title,
    required String problem,
    required String acceptanceCriteria,
    required double budgetAmount,
    required String currency,
    required String companyName,
    DateTime? deadline,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }
    if (title.trim().length < 8 ||
        problem.trim().length < 20 ||
        acceptanceCriteria.trim().length < 10 ||
        budgetAmount <= 0) {
      throw Exception(appTr(
        'أكمل عنواناً ومشكلة ومعيار قبول وميزانية صحيحة',
        'Complete a title, problem, acceptance criteria, and a valid budget',
      ));
    }

    final ref = await _challenges.add({
      'title': title.trim(),
      'problem': problem.trim(),
      'acceptanceCriteria': acceptanceCriteria.trim(),
      'budgetAmount': budgetAmount,
      'currency': currency.trim(),
      'companyId': user.uid,
      'companyName': companyName.trim(),
      'status': IndustryChallengeOps.open,
      'paymentStatus': PaymentStatus.pending,
      'protocolsCount': 0,
      'awardedProtocolId': '',
      'awardedResearcherId': '',
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> confirmDeposit(IndustryChallenge challenge) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }
    final id = challenge.id;
    if (id == null || id.isEmpty) {
      throw Exception(appTr('تحدٍ غير صالح', 'Invalid challenge'));
    }
    if (challenge.companyId != user.uid) {
      throw Exception(appTr(
        'الشركة الناشرة فقط تؤكد العربون',
        'Only the posting company can confirm the deposit',
      ));
    }
    if (!IndustryChallengeOps.canHoldDeposit(
      paymentStatus: challenge.paymentStatus,
      challengeStatus: challenge.status,
    )) {
      throw Exception(appTr(
        'لا يمكن تأكيد العربون في هذه الحالة',
        'Deposit cannot be confirmed in this state',
      ));
    }

    await _challenges.doc(id).update({
      'paymentStatus': PaymentStatus.held,
      'depositHeldAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitProtocol({
    required IndustryChallenge challenge,
    required String researcherName,
    required String summary,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }
    final challengeId = challenge.id;
    if (challengeId == null || challengeId.isEmpty) {
      throw Exception(appTr('تحدٍ غير صالح', 'Invalid challenge'));
    }
    if (!IndustryChallengeOps.canSubmitProtocol(
      paymentStatus: challenge.paymentStatus,
      challengeStatus: challenge.status,
      companyId: challenge.companyId,
      researcherId: user.uid,
    )) {
      throw Exception(appTr(
        'التقديم متاح بعد حجز العربون فقط، وليس لصاحب التحدي',
        'Submit only after the deposit is held, and not as the challenge owner',
      ));
    }
    if (summary.trim().length < 20) {
      throw Exception(appTr(
        'اكتب بروتوكولاً أوضح (٢٠ حرفاً على الأقل)',
        'Write a clearer protocol (at least 20 characters)',
      ));
    }

    final existing = await _protocols
        .where('challengeId', isEqualTo: challengeId)
        .where('researcherId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception(appTr(
        'قدّمت بروتوكولاً لهذا التحدي مسبقاً',
        'You already submitted a protocol for this challenge',
      ));
    }

    final protocolRef = _protocols.doc();
    final batch = _db.batch();
    batch.set(protocolRef, {
      'challengeId': challengeId,
      'researcherId': user.uid,
      'researcherName': researcherName.trim(),
      'summary': summary.trim(),
      'status': IndustryChallengeOps.protocolSubmitted,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_challenges.doc(challengeId), {
      'protocolsCount': FieldValue.increment(1),
    });
    await batch.commit();

    if (challenge.companyId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: challenge.companyId,
        title: appTr('بروتوكول على تحديك', 'Protocol on your challenge'),
        body: appTr(
          '«${challenge.title}» — $researcherName',
          '"${challenge.title}" — $researcherName',
        ),
        type: 'industry_challenge_protocol',
        contextId: challengeId,
        contextType: 'industry_challenge',
      );
    }
  }

  Future<void> awardProtocol({
    required IndustryChallenge challenge,
    required ChallengeProtocol protocol,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }
    final challengeId = challenge.id;
    final protocolId = protocol.id;
    if (challengeId == null || protocolId == null) {
      throw Exception(appTr('بيانات غير صالحة', 'Invalid data'));
    }
    if (challenge.companyId != user.uid) {
      throw Exception(appTr(
        'الشركة الناشرة فقط ترسّي البروتوكول',
        'Only the posting company can award a protocol',
      ));
    }
    if (!IndustryChallengeOps.canAward(
      paymentStatus: challenge.paymentStatus,
      challengeStatus: challenge.status,
    )) {
      throw Exception(appTr(
        'الترسية متاحة والعربون محجوز والتحدي مفتوح',
        'Award is available while the deposit is held and the challenge is open',
      ));
    }

    final batch = _db.batch();
    batch.update(_challenges.doc(challengeId), {
      'status': IndustryChallengeOps.awarded,
      'awardedProtocolId': protocolId,
      'awardedResearcherId': protocol.researcherId,
      'awardedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_protocols.doc(protocolId), {
      'status': IndustryChallengeOps.protocolAccepted,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    if (protocol.researcherId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: protocol.researcherId,
        title: appTr('رُسّي بروتوكولك', 'Your protocol was awarded'),
        body: appTr(
          '«${challenge.title}» — العربون ما زال محجوزاً حتى التسليم',
          '"${challenge.title}" — deposit stays held until delivery',
        ),
        type: 'industry_challenge_awarded',
        contextId: challengeId,
        contextType: 'industry_challenge',
      );
    }
  }

  Future<void> releaseDeposit(IndustryChallenge challenge) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }
    final id = challenge.id;
    if (id == null) {
      throw Exception(appTr('تحدٍ غير صالح', 'Invalid challenge'));
    }
    if (challenge.companyId != user.uid) {
      throw Exception(appTr(
        'الشركة الناشرة فقط تفرج عن العربون',
        'Only the posting company can release the deposit',
      ));
    }
    if (!IndustryChallengeOps.canRelease(
      paymentStatus: challenge.paymentStatus,
      challengeStatus: challenge.status,
    )) {
      throw Exception(appTr(
        'الإفراج بعد الترسية والعربون المحجوز',
        'Release is after award while the deposit is held',
      ));
    }

    await _challenges.doc(id).update({
      'paymentStatus': PaymentStatus.released,
      'releasedAt': FieldValue.serverTimestamp(),
    });

    if (challenge.awardedResearcherId.isNotEmpty) {
      await EscrowService.instance.releaseToSeller(
        orderRef: _challenges.doc(id),
        sellerId: challenge.awardedResearcherId,
        title: challenge.title,
        contextType: 'industry_challenge',
      );
    }
  }

  Future<void> refundDeposit(IndustryChallenge challenge) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }
    final id = challenge.id;
    if (id == null) {
      throw Exception(appTr('تحدٍ غير صالح', 'Invalid challenge'));
    }
    if (challenge.companyId != user.uid) {
      throw Exception(appTr(
        'الشركة الناشرة فقط ترد العربون',
        'Only the posting company can refund the deposit',
      ));
    }
    if (!IndustryChallengeOps.canRefund(
      paymentStatus: challenge.paymentStatus,
      challengeStatus: challenge.status,
    )) {
      throw Exception(appTr(
        'الرد متاح والعربون محجوز',
        'Refund is available while the deposit is held',
      ));
    }

    await _challenges.doc(id).update({
      'paymentStatus': PaymentStatus.refunded,
      'refundedAt': FieldValue.serverTimestamp(),
      if (challenge.status == IndustryChallengeOps.open)
        'status': IndustryChallengeOps.closed,
    });

    await EscrowService.instance.refundBuyer(
      orderRef: _challenges.doc(id),
      buyerId: challenge.companyId,
      title: challenge.title,
      contextType: 'industry_challenge',
    );
  }
}
