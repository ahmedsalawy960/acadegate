import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/escrow/escrow_service.dart';
import '../../core/escrow/payment_status.dart';
import '../notifications/notification_service.dart';

class StoreOrder {
  final String? id;
  final String productId;
  final String productName;
  final num price;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String status;
  final String paymentStatus;
  final DateTime? createdAt;

  const StoreOrder({
    this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    this.status = 'pending',
    this.paymentStatus = PaymentStatus.pending,
    this.createdAt,
  });

  factory StoreOrder.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    return StoreOrder(
      id: id,
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      price: map['price'] as num? ?? map['amount'] as num? ?? 0,
      buyerId: map['buyerId']?.toString() ?? '',
      buyerName: map['buyerName']?.toString() ?? '',
      sellerId: map['sellerId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      paymentStatus:
          map['paymentStatus']?.toString() ?? PaymentStatus.pending,
      createdAt: created,
    );
  }
}

class StoreOrderService {
  StoreOrderService._();

  static final StoreOrderService instance = StoreOrderService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('store_orders');

  Future<String> createOrder({
    required String productId,
    required String productName,
    required num price,
    required String sellerId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final doc = await _orders.add({
      'productId': productId,
      'productName': productName,
      'price': price,
      'amount': price,
      'buyerId': user.uid,
      'buyerName': user.displayName ?? user.email?.split('@').first ?? 'مشتري',
      'sellerId': sellerId,
      'status': 'pending',
      'paymentStatus': PaymentStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await NotificationService.instance.send(
      userId: sellerId,
      title: 'طلب شراء جديد',
      body: '$productName — $price ج.م',
      type: 'store_order',
    );

    return doc.id;
  }

  Future<void> payOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ref = _orders.doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('الطلب غير موجود');
    final data = snap.data()!;
    if (data['buyerId'] != user.uid) throw Exception('غير مصرح');

    await EscrowService.instance.markPaidHeld(
      orderRef: ref,
      notifyUserId: data['sellerId']?.toString() ?? '',
      title: data['productName']?.toString() ?? 'منتج',
      amount: data['price'] as num? ?? 0,
    );
  }

  Future<void> confirmDelivery(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ref = _orders.doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('الطلب غير موجود');
    final data = snap.data()!;
    if (data['buyerId'] != user.uid) throw Exception('غير مصرح');

    await ref.update({'status': 'delivered'});
    await EscrowService.instance.releaseToSeller(
      orderRef: ref,
      sellerId: data['sellerId']?.toString() ?? '',
      title: data['productName']?.toString() ?? 'منتج',
    );
  }

  Stream<List<StoreOrder>> buyerOrdersStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _orders
        .where('buyerId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => StoreOrder.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }
}
