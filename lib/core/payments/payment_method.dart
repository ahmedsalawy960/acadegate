/// How the buyer intends to settle an order.
class PaymentMethod {
  PaymentMethod._();

  static const paymob = 'paymob';
  static const manual = 'manual';
}

enum PaymentCheckoutChoice { paymob, manual, cancel }
