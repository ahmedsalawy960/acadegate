/// How the buyer intends to settle an order.
class PaymentMethod {
  PaymentMethod._();

  static const paymob = 'paymob';
  static const manual = 'manual';
}

/// [paymob] = card, [wallet] = mobile wallet; both settle through Paymob
/// and are stored as [PaymentMethod.paymob].
enum PaymentCheckoutChoice { paymob, wallet, manual, cancel }

extension PaymentCheckoutChoiceX on PaymentCheckoutChoice {
  bool get isOnline =>
      this == PaymentCheckoutChoice.paymob ||
      this == PaymentCheckoutChoice.wallet;

  bool get isWallet => this == PaymentCheckoutChoice.wallet;
}
