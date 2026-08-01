import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../../core/escrow/payment_status.dart';
import '../../core/payments/payment_method.dart';
import '../../core/payments/paymob_payment_service.dart';
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
  final String paymentMethod;
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
    this.paymentMethod = PaymentMethod.paymob,
    this.createdAt,
  });

  bool get isPendingPayment => paymentStatus == PaymentStatus.pending;
  bool get isPaidHeld => paymentStatus == PaymentStatus.held;
  bool get isManualPayment => paymentMethod == PaymentMethod.manual;

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
      paymentMethod:
          map['paymentMethod']?.toString() ?? PaymentMethod.paymob,
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
    String paymentMethod = PaymentMethod.paymob,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final productSnap =
        await FirebaseFirestore.instance.collection('product').doc(productId).get();
    if (!productSnap.exists) {
      throw Exception(appTr('المنتج غير موجود', 'Product not found'));
    }

    final serverPrice = productSnap.data()?['price'] as num?;
    if (serverPrice == null) {
      throw Exception(appTr('سعر المنتج غير متاح', 'Product price unavailable'));
    }
    final verifiedSeller =
        productSnap.data()?['createdBy']?.toString() ?? sellerId;
    final method = paymentMethod == PaymentMethod.manual
        ? PaymentMethod.manual
        : PaymentMethod.paymob;

    final doc = await _orders.add({
      'productId': productId,
      'productName': productName,
      'price': serverPrice,
      'amount': serverPrice,
      'buyerId': user.uid,
      'buyerName': user.displayName ??
          user.email?.split('@').first ??
          appTr('مشتري', 'Buyer'),
      'sellerId': verifiedSeller,
      'status': 'pending',
      'paymentStatus': PaymentStatus.pending,
      'paymentMethod': method,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final isManual = method == PaymentMethod.manual;
    await NotificationService.instance.send(
      userId: verifiedSeller,
      title: isManual
          ? appTr('طلب تحويل يدوي', 'Manual payment request')
          : appTr('طلب شراء جديد', 'New purchase order'),
      body: isManual
          ? '$productName — $serverPrice ${appTr('ج.م', 'EGP')} — ${appTr('تواصل مع المشتري لإتمام التحويل', 'Contact the buyer to complete the transfer')}'
          : '$productName — $serverPrice ${appTr('ج.م', 'EGP')}',
      type: 'store_order',
      contextId: doc.id,
      contextType: 'store_order',
    );

    return doc.id;
  }

  /// Opens Paymob checkout; [paymentStatus] updates via webhook only.
  Future<void> payOrder(String orderId, {String? phone}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final snap = await _orders.doc(orderId).get();
    if (!snap.exists) {
      throw Exception(appTr('الطلب غير موجود', 'Order not found'));
    }
    final data = snap.data()!;
    if (data['buyerId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }

    await PaymobPaymentService.instance.payAndOpen(
      kind: PaymobOrderKind.store,
      orderId: orderId,
      phone: phone,
    );
  }

  /// Seller confirms that a manual bank/InstaPay transfer was received.
  Future<void> confirmManualPaymentReceived(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final ref = _orders.doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception(appTr('الطلب غير موجود', 'Order not found'));
    }
    final data = snap.data()!;
    if (data['sellerId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }
    if (data['paymentMethod']?.toString() != PaymentMethod.manual) {
      throw Exception(appTr(
        'هذا الطلب ليس تحويلاً يدوياً',
        'This order is not a manual transfer',
      ));
    }
    if (data['paymentStatus'] == PaymentStatus.held ||
        data['paymentStatus'] == PaymentStatus.released) {
      return;
    }

    await ref.update({
      'paymentStatus': PaymentStatus.held,
      'paidAt': FieldValue.serverTimestamp(),
      'status': 'paid',
    });

    final buyerId = data['buyerId']?.toString() ?? '';
    if (buyerId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: buyerId,
        title: appTr('تم تأكيد التحويل', 'Transfer confirmed'),
        body: appTr(
          'أكد البائع استلام التحويل لـ «${data['productName']}» — بانتظار تأكيد الاستلام',
          'Seller confirmed your transfer for «${data['productName']}» — awaiting delivery confirmation',
        ),
        type: 'payment_held',
        contextId: orderId,
        contextType: 'store_order',
      );
    }
  }

  Future<void> confirmDelivery(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final snap = await _orders.doc(orderId).get();
    if (!snap.exists) {
      throw Exception(appTr('الطلب غير موجود', 'Order not found'));
    }
    if (snap.data()?['buyerId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }

    await PaymobPaymentService.instance.confirmDeliveryRelease(
      kind: PaymobOrderKind.store,
      orderId: orderId,
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

  Stream<List<StoreOrder>> sellerOrdersStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _orders
        .where('sellerId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => StoreOrder.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }
}
