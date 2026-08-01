import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../../core/escrow/payment_status.dart';
import '../../core/payments/payment_method.dart';
import '../../core/payments/paymob_payment_service.dart';
import '../moderation/approval_status.dart';
import '../notifications/notification_service.dart';
import 'writing_models.dart';

class WritingService {
  WritingService._();

  static final WritingService instance = WritingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _services =>
      _db.collection('writing_services');

  CollectionReference<Map<String, dynamic>> _orders(String serviceId) =>
      _services.doc(serviceId).collection('writing_orders');

  Stream<List<WritingExpert>> expertsStream({required String categoryTitle}) {
    return _services
        .where('category', isEqualTo: categoryTitle)
        .snapshots()
        .map((snapshot) {
      final experts = snapshot.docs
          .map((doc) => WritingExpert.fromMap(doc.data(), id: doc.id))
          .where((expert) => expert.isPubliclyVisible)
          .toList();

      if (experts.isNotEmpty) return experts;
      return const [];
    });
  }

  /// All publicly visible writers (for matching).
  Future<List<WritingExpert>> fetchAllExperts() async {
    final snapshot = await _services.get();
    return snapshot.docs
        .map((doc) => WritingExpert.fromMap(doc.data(), id: doc.id))
        .where((expert) => expert.isPubliclyVisible)
        .toList();
  }

  Stream<List<WritingOrder>> userOrdersStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _db
        .collectionGroup('writing_orders')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => WritingOrder.fromMap(doc.data(), id: doc.id))
              .toList();
          orders.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return orders;
        });
  }

  Future<void> createOrder({
    required WritingExpert expert,
    required WritingOrder order,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول لحجز الخدمة', 'Sign in to book this service'));
    }

    final serviceId = expert.isFromFirebase ? expert.id! : 'direct_requests';
    final payload = order.toMap()
      ..['userId'] = user.uid
      ..['expertName'] = expert.name
      ..['category'] = expert.category
      ..['serviceId'] = serviceId
      ..['serviceOwnerId'] = expert.ownerId ?? ''
      ..['status'] = 'pending'
      ..['paymentStatus'] = 'pending_payment'
      ..['amount'] = 0;

    final orderDoc = await _orders(serviceId).add(payload);

    if (expert.ownerId != null && expert.ownerId!.isNotEmpty) {
      await NotificationService.instance.send(
        userId: expert.ownerId!,
        title: appTr('طلب كتابة جديد', 'New writing order'),
        body: order.topic,
        type: 'writing_order',
        contextId: '$serviceId:${orderDoc.id}',
        contextType: 'writing_order',
      );
    }
  }

  Stream<List<WritingOrder>> expertOrdersStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _db
        .collectionGroup('writing_orders')
        .where('serviceOwnerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => WritingOrder.fromMap(doc.data(), id: doc.id))
              .toList();
          orders.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return orders;
        });
  }

  DocumentReference<Map<String, dynamic>> _orderRef(
    String serviceId,
    String orderId,
  ) =>
      _orders(serviceId).doc(orderId);

  Future<void> expertAcceptOrder({
    required String serviceId,
    required String orderId,
    required num amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception(appTr('الطلب غير موجود', 'Order not found'));
    if (snap.data()?['serviceOwnerId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }

    await ref.update({
      'status': 'confirmed',
      'amount': amount,
    });

    await NotificationService.instance.send(
      userId: snap.data()?['userId']?.toString() ?? '',
      title: appTr('تم قبول طلبك', 'Your order was accepted'),
      body: appTr(
        'الخبير قبل الطلب — ادفع $amount ج.م للبدء',
        'The expert accepted — pay $amount EGP to start',
      ),
      type: 'writing_order',
      contextId: '$serviceId:$orderId',
      contextType: 'writing_order',
    );
  }

  Future<void> expertRejectOrder({
    required String serviceId,
    required String orderId,
    String reason = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['serviceOwnerId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }

    await ref.update({
      'status': 'rejected',
      'rejectedReason': reason,
    });

    await NotificationService.instance.send(
      userId: snap.data()?['userId']?.toString() ?? '',
      title: appTr('تم رفض الطلب', 'Order rejected'),
      body: reason.isEmpty
          ? appTr('رفض الخبير طلب الكتابة', 'The expert declined the writing order')
          : reason,
      type: 'writing_order',
      contextId: '$serviceId:$orderId',
      contextType: 'writing_order',
    );
  }

  Future<void> expertMarkInProgress({
    required String serviceId,
    required String orderId,
  }) async {
    await _expertStatusUpdate(serviceId, orderId, 'in_progress');
  }

  Future<void> expertDeliverOrder({
    required String serviceId,
    required String orderId,
    required String deliveryNote,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['serviceOwnerId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }

    await ref.update({
      'status': 'delivered',
      'deliveryNote': deliveryNote.trim(),
      'deliveredAt': FieldValue.serverTimestamp(),
    });

    await NotificationService.instance.send(
      userId: snap.data()?['userId']?.toString() ?? '',
      title: appTr('تم تسليم العمل', 'Work delivered'),
      body: appTr('راجع التسليم وأكّد الاستلام', 'Review the delivery and confirm receipt'),
      type: 'writing_order',
      contextId: '$serviceId:$orderId',
      contextType: 'writing_order',
    );
  }

  Future<void> _expertStatusUpdate(
    String serviceId,
    String orderId,
    String status,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['serviceOwnerId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }
    await ref.update({'status': status});
  }

  Future<void> payOrder({
    required String serviceId,
    required String orderId,
    required num amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['userId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }

    await ref.set({
      'paymentMethod': PaymentMethod.paymob,
    }, SetOptions(merge: true));

    await PaymobPaymentService.instance.payAndOpen(
      kind: PaymobOrderKind.writing,
      orderId: orderId,
      serviceId: serviceId,
    );
  }

  /// Buyer requests manual bank/InstaPay settlement with the expert.
  Future<void> requestManualPayment({
    required String serviceId,
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['userId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }

    await ref.set({
      'paymentMethod': PaymentMethod.manual,
      'paymentStatus': PaymentStatus.pending,
      'manualPaymentRequestedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final ownerId = data['serviceOwnerId']?.toString() ?? '';
    if (ownerId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: ownerId,
        title: appTr('طلب تحويل يدوي', 'Manual payment request'),
        body: appTr(
          'المشتري يطلب التحويل اليدوي لـ «${data['topic']}»',
          'Buyer requested a manual transfer for «${data['topic']}»',
        ),
        type: 'writing_order',
        contextId: '$serviceId:$orderId',
        contextType: 'writing_order',
      );
    }
  }

  /// Expert confirms a manual transfer was received.
  Future<void> confirmManualPaymentReceived({
    required String serviceId,
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['serviceOwnerId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }
    if (data['paymentMethod']?.toString() != PaymentMethod.manual) {
      throw Exception(appTr(
        'هذا الطلب ليس تحويلاً يدوياً',
        'This order is not a manual transfer',
      ));
    }

    await ref.update({
      'paymentStatus': PaymentStatus.held,
      'paidAt': FieldValue.serverTimestamp(),
      'status': 'in_progress',
    });

    final buyerId = data['userId']?.toString() ?? '';
    if (buyerId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: buyerId,
        title: appTr('تم تأكيد التحويل', 'Transfer confirmed'),
        body: appTr(
          'أكد الخبير استلام التحويل — بدأ تنفيذ الطلب',
          'Expert confirmed your transfer — work has started',
        ),
        type: 'payment_held',
        contextId: '$serviceId:$orderId',
        contextType: 'writing_order',
      );
    }
  }

  Future<void> confirmDelivery({
    required String serviceId,
    required String orderId,
    int? rating,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['userId'] != user.uid) {
      throw Exception(appTr('غير مصرح', 'Not authorized'));
    }

    await PaymobPaymentService.instance.confirmDeliveryRelease(
      kind: PaymobOrderKind.writing,
      orderId: orderId,
      serviceId: serviceId,
      rating: rating,
    );

    final ownerId = snap.data()?['serviceOwnerId']?.toString() ?? '';
    if (ownerId.isNotEmpty && serviceId.isNotEmpty) {
      try {
        final serviceRef = _services.doc(serviceId);
        final serviceSnap = await serviceRef.get();
        if (serviceSnap.exists) {
          final data = serviceSnap.data()!;
          final prevCount = (data['completedOrders'] as num?)?.toInt() ?? 0;
          final prevAvg = (data['avgDeliveryDays'] as num?)?.toDouble() ?? 0;
          final created = snap.data()?['createdAt'];
          var deliveryDays = (data['deliveryDaysMax'] as num?)?.toDouble() ?? 7;
          if (created is Timestamp) {
            deliveryDays =
                DateTime.now().difference(created.toDate()).inDays.toDouble();
            if (deliveryDays < 1) deliveryDays = 1;
          }
          final newCount = prevCount + 1;
          final newAvg = prevCount <= 0
              ? deliveryDays
              : ((prevAvg * prevCount) + deliveryDays) / newCount;
          await serviceRef.update({
            'completedOrders': newCount,
            'avgDeliveryDays': double.parse(newAvg.toStringAsFixed(1)),
            if (rating != null) 'rating': rating.toDouble(),
          });
        }
      } catch (_) {}
    }
  }

  Future<void> cancelOrder({
    required String serviceId,
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final doc = await _orders(serviceId).doc(orderId).get();
    if (!doc.exists) throw Exception(appTr('الطلب غير موجود', 'Order not found'));
    if (doc.data()?['userId'] != user.uid) {
      throw Exception(appTr('لا يمكنك إلغاء هذا الطلب', 'You cannot cancel this order'));
    }

    await _orders(serviceId).doc(orderId).update({'status': 'cancelled'});
  }

  Future<void> publishExpertProfile({
    required WritingExpert expert,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

    final payload = expert.toMap()
      ..['ownerId'] = user.uid
      ..['approvalStatus'] = ApprovalStatus.pending
      ..['rating'] = 0
      ..['completedOrders'] = 0
      ..['createdAt'] = FieldValue.serverTimestamp();

    await _services.add(payload);
  }
}
