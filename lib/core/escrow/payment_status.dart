/// حالات الدفع بالضمان (Escrow) — MVP بدون بوابة دفع خارجية.
class PaymentStatus {
  PaymentStatus._();

  static const pending = 'pending_payment';
  static const held = 'paid_held';
  static const released = 'released';
  static const refunded = 'refunded';

  static String label(String status) {
    switch (status) {
      case held:
        return 'مدفوع — محجوز';
      case released:
        return 'تم التسليم للبائع';
      case refunded:
        return 'مسترد';
      default:
        return 'بانتظار الدفع';
    }
  }
}
