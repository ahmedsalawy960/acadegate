import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/notifications/notification_service.dart';
import 'payment_status.dart';

/// ضمان مبسّط: الطالب يؤكد الدفع → المبلغ «محجوز» → بعد التسليم يُفرج عنه.
class EscrowService {
  EscrowService._();

  static final EscrowService instance = EscrowService._();

  Future<void> markPaidHeld({
    required DocumentReference<Map<String, dynamic>> orderRef,
    required String notifyUserId,
    required String title,
    required num amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    await orderRef.update({
      'paymentStatus': PaymentStatus.held,
      'paidAt': FieldValue.serverTimestamp(),
    });

    await NotificationService.instance.send(
      userId: notifyUserId,
      title: 'تأكيد دفع',
      body: 'تم استلام دفعة بقيمة $amount ج.م — $title',
      type: 'payment_held',
    );
  }

  Future<void> releaseToSeller({
    required DocumentReference<Map<String, dynamic>> orderRef,
    required String sellerId,
    required String title,
  }) async {
    await orderRef.update({
      'paymentStatus': PaymentStatus.released,
      'releasedAt': FieldValue.serverTimestamp(),
    });

    await NotificationService.instance.send(
      userId: sellerId,
      title: 'تم تحرير الدفعة',
      body: 'تم إفراج المبلغ لطلب: $title',
      type: 'payment_released',
    );
  }

  Future<void> refundBuyer({
    required DocumentReference<Map<String, dynamic>> orderRef,
    required String buyerId,
    required String title,
  }) async {
    await orderRef.update({
      'paymentStatus': PaymentStatus.refunded,
      'refundedAt': FieldValue.serverTimestamp(),
    });

    await NotificationService.instance.send(
      userId: buyerId,
      title: 'استرداد',
      body: 'تم استرداد المبلغ لطلب: $title',
      type: 'payment_refunded',
    );
  }
}
