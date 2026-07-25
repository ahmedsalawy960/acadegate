import '../../core/locale/l10n_lookup.dart';

/// Escrow payment statuses.
/// Real transitions must run via Cloud Functions / payment gateway — not the client.
class PaymentStatus {
  PaymentStatus._();

  static const pending = 'pending_payment';
  static const held = 'paid_held';
  static const released = 'released';
  static const refunded = 'refunded';

  static String label(String status) => L10nLookup.paymentStatusLabel(status);
}
