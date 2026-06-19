import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../moderation/approval_status.dart';
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
      ..['status'] = 'pending';

    await _orders(serviceId).add(payload);
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
