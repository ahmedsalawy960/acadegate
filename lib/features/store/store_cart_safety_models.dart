/// نتيجة فحص سلامة منتجات العربة (استرشادي وليس شهادة رسمية).
enum CartSafetyLevel { low, medium, high }

class CartProductSafetyNote {
  final String productId;
  final String productName;
  final CartSafetyLevel level;
  final List<String> hazards;
  final List<String> handling;
  final List<String> storage;
  final String summary;

  const CartProductSafetyNote({
    required this.productId,
    required this.productName,
    required this.level,
    this.hazards = const [],
    this.handling = const [],
    this.storage = const [],
    this.summary = '',
  });
}

class CartSafetyScanResult {
  final List<CartProductSafetyNote> notes;
  final String overallSummary;
  final CartSafetyLevel overallLevel;
  final bool fromAi;
  final String? modelUsed;
  final String? error;
  final String disclaimer;

  const CartSafetyScanResult({
    this.notes = const [],
    this.overallSummary = '',
    this.overallLevel = CartSafetyLevel.low,
    this.fromAi = false,
    this.modelUsed,
    this.error,
    this.disclaimer = '',
  });

  bool get hasError => error != null && error!.trim().isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;
}
