import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../features/notifications/notification_service.dart';

/// Escrow notifications only. Payment status is owned by Paymob Cloud Functions.
class EscrowService {
  EscrowService._();

  static final EscrowService instance = EscrowService._();

  Future<void> notifyPaymentHeld({
    required String notifyUserId,
    required String title,
    required num amount,
  }) async {
    if (notifyUserId.isEmpty) return;
    await NotificationService.instance.send(
      userId: notifyUserId,
      title: L10nLookup.paymentConfirmTitle(),
      body: L10nLookup.paymentConfirmBody(amount, title),
      type: 'payment_held',
    );
  }

  Future<void> releaseToSeller({
    required DocumentReference<Map<String, dynamic>> orderRef,
    required String sellerId,
    required String title,
  }) async {
    await NotificationService.instance.send(
      userId: sellerId,
      title: L10nLookup.paymentReleasedTitle(),
      body: L10nLookup.paymentReleasedBody(title),
      type: 'payment_released',
    );
  }

  Future<void> refundBuyer({
    required DocumentReference<Map<String, dynamic>> orderRef,
    required String buyerId,
    required String title,
  }) async {
    await NotificationService.instance.send(
      userId: buyerId,
      title: L10nLookup.refundTitle(),
      body: L10nLookup.refundBody(title),
      type: 'payment_refunded',
    );
  }
}
