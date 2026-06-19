import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/escrow/escrow_service.dart';
import '../moderation/approval_status.dart';
import '../notifications/notification_service.dart';
import 'writing_fallback_data.dart';
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
      return fallbackExpertsForCategory(categoryTitle);
    });
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
      throw Exception('يجب تسجيل الدخول لحجز الخدمة');
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

    await _orders(serviceId).add(payload);

    if (expert.ownerId != null && expert.ownerId!.isNotEmpty) {
      await NotificationService.instance.send(
        userId: expert.ownerId!,
        title: 'طلب كتابة جديد',
        body: order.topic,
        type: 'writing_order',
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
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('الطلب غير موجود');
    if (snap.data()?['serviceOwnerId'] != user.uid) {
      throw Exception('غير مصرح');
    }

    await ref.update({
      'status': 'confirmed',
      'amount': amount,
    });

    await NotificationService.instance.send(
      userId: snap.data()?['userId']?.toString() ?? '',
      title: 'تم قبول طلبك',
      body: 'الخبير قبل الطلب — ادفع $amount ج.م للبدء',
      type: 'writing_order',
    );
  }

  Future<void> expertRejectOrder({
    required String serviceId,
    required String orderId,
    String reason = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['serviceOwnerId'] != user.uid) {
      throw Exception('غير مصرح');
    }

    await ref.update({
      'status': 'rejected',
      'rejectedReason': reason,
    });

    await NotificationService.instance.send(
      userId: snap.data()?['userId']?.toString() ?? '',
      title: 'تم رفض الطلب',
      body: reason.isEmpty ? 'رفض الخبير طلب الكتابة' : reason,
      type: 'writing_order',
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
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['serviceOwnerId'] != user.uid) {
      throw Exception('غير مصرح');
    }

    await ref.update({
      'status': 'delivered',
      'deliveryNote': deliveryNote.trim(),
      'deliveredAt': FieldValue.serverTimestamp(),
    });

    await NotificationService.instance.send(
      userId: snap.data()?['userId']?.toString() ?? '',
      title: 'تم تسليم العمل',
      body: 'راجع التسليم وأكّد الاستلام',
      type: 'writing_order',
    );
  }

  Future<void> _expertStatusUpdate(
    String serviceId,
    String orderId,
    String status,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['serviceOwnerId'] != user.uid) {
      throw Exception('غير مصرح');
    }
    await ref.update({'status': status});
  }

  Future<void> payOrder({
    required String serviceId,
    required String orderId,
    required num amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['userId'] != user.uid) throw Exception('غير مصرح');

    await EscrowService.instance.markPaidHeld(
      orderRef: ref,
      notifyUserId: snap.data()?['serviceOwnerId']?.toString() ?? '',
      title: snap.data()?['topic']?.toString() ?? 'طلب كتابة',
      amount: amount,
    );

    await ref.update({'status': 'in_progress'});
  }

  Future<void> confirmDelivery({
    required String serviceId,
    required String orderId,
    int? rating,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final ref = _orderRef(serviceId, orderId);
    final snap = await ref.get();
    if (snap.data()?['userId'] != user.uid) throw Exception('غير مصرح');

    final updates = <String, dynamic>{
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    };
    if (rating != null) updates['studentRating'] = rating;
    await ref.update(updates);

    await EscrowService.instance.releaseToSeller(
      orderRef: ref,
      sellerId: snap.data()?['serviceOwnerId']?.toString() ?? '',
      title: snap.data()?['topic']?.toString() ?? 'طلب كتابة',
    );
  }

  Future<void> cancelOrder({
    required String serviceId,
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final doc = await _orders(serviceId).doc(orderId).get();
    if (!doc.exists) throw Exception('الطلب غير موجود');
    if (doc.data()?['userId'] != user.uid) {
      throw Exception('لا يمكنك إلغاء هذا الطلب');
    }

    await _orders(serviceId).doc(orderId).update({'status': 'cancelled'});
  }

  Future<void> publishExpertProfile({
    required WritingExpert expert,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final payload = expert.toMap()
      ..['ownerId'] = user.uid
      ..['approvalStatus'] = ApprovalStatus.pending
      ..['rating'] = 0
      ..['completedOrders'] = 0
      ..['createdAt'] = FieldValue.serverTimestamp();

    await _services.add(payload);
  }
}
