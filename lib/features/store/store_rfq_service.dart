import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../notifications/notification_service.dart';

class StoreRfq {
  final String id;
  final String buyerId;
  final String buyerName;
  final String? productId;
  final String productName;
  final String category;
  final String sellerId;
  final String details;
  final int quantity;
  final String status;
  final DateTime? createdAt;

  const StoreRfq({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    this.productId,
    required this.productName,
    this.category = '',
    this.sellerId = '',
    required this.details,
    this.quantity = 1,
    this.status = 'open',
    this.createdAt,
  });

  factory StoreRfq.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return StoreRfq(
      id: doc.id,
      buyerId: d['buyerId']?.toString() ?? '',
      buyerName: d['buyerName']?.toString() ?? '',
      productId: d['productId']?.toString(),
      productName: d['productName']?.toString() ?? '',
      category: d['category']?.toString() ?? '',
      sellerId: d['sellerId']?.toString() ?? '',
      details: d['details']?.toString() ?? '',
      quantity: (d['quantity'] as num?)?.toInt() ?? 1,
      status: d['status']?.toString() ?? 'open',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class StoreRfqService {
  StoreRfqService._();
  static final StoreRfqService instance = StoreRfqService._();

  final _db = FirebaseFirestore.instance;

  Future<String> submit({
    String? productId,
    required String productName,
    String category = '',
    String sellerId = '',
    required String details,
    int quantity = 1,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    final text = details.trim();
    if (text.length < 10) {
      throw Exception(
        appTr('اكتب تفاصيل أوضح للطلب', 'Please add more quote details'),
      );
    }

    final buyerName = user.displayName ??
        user.email?.split('@').first ??
        appTr('باحث', 'Researcher');

    final doc = await _db.collection('store_rfqs').add({
      'buyerId': user.uid,
      'buyerName': buyerName,
      'productId': productId,
      'productName': productName,
      'category': category,
      'sellerId': sellerId,
      'details': text,
      'quantity': quantity < 1 ? 1 : quantity,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (sellerId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: sellerId,
        title: appTr('طلب عرض سعر جديد', 'New quote request'),
        body: '$productName — $buyerName',
        type: 'store_order',
        contextId: doc.id,
        contextType: 'store_rfq',
      );
    }

    return doc.id;
  }

  Stream<List<StoreRfq>> watchForSeller(String sellerId) {
    return _db
        .collection('store_rfqs')
        .where('sellerId', isEqualTo: sellerId)
        .limit(50)
        .snapshots()
        .map((s) {
      final list = s.docs.map(StoreRfq.fromDoc).toList()
        ..sort((a, b) {
          final aAt = a.createdAt;
          final bAt = b.createdAt;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return bAt.compareTo(aAt);
        });
      return list;
    });
  }

  Stream<List<StoreRfq>> watchMine() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);
    return _db
        .collection('store_rfqs')
        .where('buyerId', isEqualTo: user.uid)
        .limit(50)
        .snapshots()
        .map((s) {
      final list = s.docs.map(StoreRfq.fromDoc).toList()
        ..sort((a, b) {
          final aAt = a.createdAt;
          final bAt = b.createdAt;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return bAt.compareTo(aAt);
        });
      return list;
    });
  }
}
