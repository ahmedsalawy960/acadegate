import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/user_account.dart';
import '../auth/user_account_service.dart';

class SubscriptionRequest {
  final String uid;
  final String email;
  final String displayName;
  final String action;
  final String tier;
  final String status;
  final String note;
  final DateTime? updatedAt;

  const SubscriptionRequest({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.action,
    required this.tier,
    required this.status,
    required this.note,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';

  factory SubscriptionRequest.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? updated;
    final raw = map['updatedAt'];
    if (raw is Timestamp) updated = raw.toDate();
    return SubscriptionRequest(
      uid: map['uid']?.toString() ?? uid,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      action: map['action']?.toString() ?? 'subscribe',
      tier: SubscriptionTier.normalize(map['tier']?.toString()),
      status: map['status']?.toString() ?? 'pending',
      note: map['note']?.toString() ?? '',
      updatedAt: updated,
    );
  }
}

class SubscriptionRequests {
  SubscriptionRequests._();
  static final SubscriptionRequests instance = SubscriptionRequests._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('subscription_requests');

  Stream<SubscriptionRequest?> watchMine() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _col.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return SubscriptionRequest.fromMap(data, uid);
    });
  }

  Stream<List<SubscriptionRequest>> watchPending() {
    return _col.where('status', isEqualTo: 'pending').snapshots().map(
          (snap) => snap.docs
              .map((doc) => SubscriptionRequest.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> submit({
    required UserAccount account,
    required String action,
    required String tier,
    String note = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != account.uid) {
      throw Exception('سجّل الدخول أولاً');
    }
    final cleanNote = note.trim();
    if (cleanNote.length > 300) {
      throw Exception('الملاحظة أطول من المسموح');
    }
    await _col.doc(uid).set({
      'uid': uid,
      'email': account.email,
      'displayName': account.displayName,
      'action': action,
      'tier': SubscriptionTier.normalize(tier),
      'status': 'pending',
      'note': cleanNote,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> withdraw() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _col.doc(uid).update({
      'status': 'withdrawn',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Grants the plan through the end of next month, or ends it this month.
  Future<void> resolve({
    required SubscriptionRequest request,
    required bool approve,
  }) async {
    final status = approve ? 'approved' : 'rejected';
    if (approve && request.action == 'cancel') {
      await _stopAtPeriodEnd(request.uid);
    } else if (approve) {
      await UserAccountService.instance.updateUserSubscription(
        uid: request.uid,
        subscription: request.tier,
        expiresAt: _endOfNextUtcMonth(),
      );
    }
    await _col.doc(request.uid).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _stopAtPeriodEnd(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    final tier = SubscriptionTier.normalize(data['subscription']?.toString());
    if (tier == SubscriptionTier.free) return;
    final raw = data['subscriptionExpiresAt'];
    if (raw is Timestamp) return;
    await UserAccountService.instance.updateUserSubscription(
      uid: uid,
      subscription: tier,
      expiresAt: _endOfThisUtcMonth(),
    );
  }

  static DateTime _endOfThisUtcMonth([DateTime? now]) {
    final utc = (now ?? DateTime.now()).toUtc();
    return DateTime.utc(utc.year, utc.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));
  }

  static DateTime _endOfNextUtcMonth([DateTime? now]) {
    final utc = (now ?? DateTime.now()).toUtc();
    return DateTime.utc(utc.year, utc.month + 2, 1)
        .subtract(const Duration(milliseconds: 1));
  }
}
