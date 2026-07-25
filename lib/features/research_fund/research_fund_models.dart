import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../moderation/approval_status.dart';
import '../notifications/notification_service.dart';
import '../../core/locale/app_translate.dart';

class FundPartner {
  final String name;
  final String contactEmail;
  final String logoUrl;

  const FundPartner({
    required this.name,
    this.contactEmail = '',
    this.logoUrl = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'contactEmail': contactEmail.trim(),
        'logoUrl': logoUrl.trim(),
      };

  factory FundPartner.fromMap(Map<String, dynamic> map) {
    return FundPartner(
      name: map['name']?.toString() ?? '',
      contactEmail: map['contactEmail']?.toString() ?? '',
      logoUrl: map['logoUrl']?.toString() ?? '',
    );
  }
}

class ResearchFundConfig {
  final bool isActive;
  final int minVotes;
  final double maxAwardAmount;
  final String currency;
  final String description;
  final List<FundPartner> partners;

  const ResearchFundConfig({
    this.isActive = false,
    this.minVotes = 0,
    this.maxAwardAmount = 0,
    this.currency = '',
    this.description = '',
    this.partners = const [],
  });

  bool get isConfigured =>
      isActive && minVotes > 0 && maxAwardAmount > 0 && currency.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'isActive': isActive,
        'minVotes': minVotes,
        'maxAwardAmount': maxAwardAmount,
        'currency': currency.trim(),
        'description': description.trim(),
        'partners': partners.map((p) => p.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ResearchFundConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ResearchFundConfig();
    final partnersRaw = map['partners'];
    return ResearchFundConfig(
      isActive: map['isActive'] == true,
      minVotes: _parseInt(map['minVotes']),
      maxAwardAmount: _parseDouble(map['maxAwardAmount']),
      currency: map['currency']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      partners: partnersRaw is List
          ? partnersRaw
              .whereType<Map>()
              .map((e) => FundPartner.fromMap(Map<String, dynamic>.from(e)))
              .where((p) => p.name.isNotEmpty)
              .toList()
          : const [],
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

enum FundAwardStatus { proposed, approved, disbursed }

extension FundAwardStatusLabel on FundAwardStatus {
  String get labelAr => switch (this) {
        FundAwardStatus.proposed => 'مقترح',
        FundAwardStatus.approved => 'معتمد',
        FundAwardStatus.disbursed => 'مُصرَّف',
      };

  String get labelEn => switch (this) {
        FundAwardStatus.proposed => 'Proposed',
        FundAwardStatus.approved => 'Approved',
        FundAwardStatus.disbursed => 'Disbursed',
      };
}

class FundAward {
  final String? id;
  final String ideaId;
  final String ideaTitle;
  final int votesAtAward;
  final double amount;
  final String currency;
  final String partnerUniversity;
  final FundAwardStatus status;
  final String publisherId;
  final DateTime? createdAt;

  const FundAward({
    this.id,
    required this.ideaId,
    required this.ideaTitle,
    required this.votesAtAward,
    required this.amount,
    required this.currency,
    required this.partnerUniversity,
    this.status = FundAwardStatus.proposed,
    this.publisherId = '',
    this.createdAt,
  });

  factory FundAward.fromMap(Map<String, dynamic> map, {String? id}) {
    return FundAward(
      id: id,
      ideaId: map['ideaId']?.toString() ?? '',
      ideaTitle: map['ideaTitle']?.toString() ?? '',
      votesAtAward: ResearchFundConfig._parseInt(map['votesAtAward']),
      amount: ResearchFundConfig._parseDouble(map['amount']),
      currency: map['currency']?.toString() ?? '',
      partnerUniversity: map['partnerUniversity']?.toString() ?? '',
      status: FundAwardStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => FundAwardStatus.proposed,
      ),
      publisherId: map['publisherId']?.toString() ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ResearchFundService {
  ResearchFundService._();

  static final ResearchFundService instance = ResearchFundService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _configDoc =>
      _db.collection('research_fund').doc('config');

  CollectionReference<Map<String, dynamic>> get _awards =>
      _db.collection('research_fund_awards');

  CollectionReference<Map<String, dynamic>> get _ideas =>
      _db.collection('research_ideas');

  Stream<ResearchFundConfig> watchConfig() {
    return _configDoc.snapshots().map(
          (snap) => ResearchFundConfig.fromMap(snap.data()),
        );
  }

  Future<void> saveConfig(ResearchFundConfig config) async {
    await _configDoc.set(config.toMap(), SetOptions(merge: true));
  }

  Stream<List<FundAward>> watchAwards() {
    return _awards
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => FundAward.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<List<FundAward>> watchMyAwards() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _awards
        .where('publisherId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => FundAward.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<Set<String>> watchFundedIdeaIds() {
    return _awards.snapshots().map(
          (snap) => snap.docs
              .map((d) => d.data()['ideaId']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
  }

  /// Eligible = approved, votes >= threshold, not already funded.
  Stream<List<Map<String, dynamic>>> watchEligibleIdeas(int minVotes) {
    if (minVotes <= 0) return Stream.value(const []);

    return _ideas
        .where('approvalStatus', isEqualTo: ApprovalStatus.approved)
        .where('votesCount', isGreaterThanOrEqualTo: minVotes)
        .orderBy('votesCount', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      return snap.docs
          .where((d) => d.data()['funded'] != true)
          .map((d) => {...d.data(), 'id': d.id})
          .toList();
    });
  }

  Future<void> createAward({
    required String ideaId,
    required String ideaTitle,
    required int votesAtAward,
    required double amount,
    required String currency,
    required String partnerUniversity,
    required String publisherId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }

    final existing = await _awards
        .where('ideaId', isEqualTo: ideaId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception(appTr(
        'هذه الفكرة ممولة مسبقاً',
        'This idea is already funded',
      ));
    }

    final ideaSnap = await _ideas.doc(ideaId).get();
    if (ideaSnap.data()?['funded'] == true) {
      throw Exception(appTr(
        'هذه الفكرة ممولة مسبقاً',
        'This idea is already funded',
      ));
    }

    final awardRef = await _awards.add({
      'ideaId': ideaId,
      'ideaTitle': ideaTitle,
      'votesAtAward': votesAtAward,
      'amount': amount,
      'currency': currency,
      'partnerUniversity': partnerUniversity,
      'status': FundAwardStatus.approved.name,
      'publisherId': publisherId,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _ideas.doc(ideaId).set({
      'funded': true,
      'fundAwardId': awardRef.id,
      'fundedAmount': amount,
      'fundedCurrency': currency,
      'fundedAt': FieldValue.serverTimestamp(),
      'fundedPartner': partnerUniversity,
    }, SetOptions(merge: true));

    if (publisherId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: publisherId,
        title: appTr('تمويل فكرة بحثية', 'Research idea funded'),
        body: appTr(
          '«$ideaTitle» — $amount $currency عبر $partnerUniversity',
          '"$ideaTitle" — $amount $currency via $partnerUniversity',
        ),
        type: 'fund_award',
        contextId: ideaId,
        contextType: 'research_idea',
      );
    }
  }

  Future<void> updateAwardStatus({
    required String awardId,
    required FundAwardStatus status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }
    await _awards.doc(awardId).update({
      'status': status.name,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'statusUpdatedBy': user.uid,
    });
  }
}
