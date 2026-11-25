import 'package:cloud_functions/cloud_functions.dart';

/// Client for the server-side academic translation callable.
///
/// The function holds the model key, enforces the academic-translation
/// system instruction (consistent terminology, verbatim DOI/citation/number
/// preservation) and chunks long texts. See functions/academic_translate.js.
class AcademicTranslationService {
  AcademicTranslationService._();
  static final instance = AcademicTranslationService._();

  /// Injectable seam for tests. Signature matches the live call.
  static Future<AcademicTranslationResult> Function({
    required String text,
    required String targetLang,
  })? debugTranslate;

  Future<AcademicTranslationResult> translate({
    required String text,
    required String targetLang,
  }) async {
    final injected = debugTranslate;
    if (injected != null) {
      return injected(text: text, targetLang: targetLang);
    }
    final callable = FirebaseFunctions.instance
        .httpsCallable('translateAcademicText');
    final response =
        await callable.call(<String, dynamic>{'text': text, 'targetLang': targetLang});
    return AcademicTranslationResult.fromMap(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}

class AcademicTranslationResult {
  final String translation;
  final String model;
  final int chunks;

  const AcademicTranslationResult({
    required this.translation,
    required this.model,
    required this.chunks,
  });

  factory AcademicTranslationResult.fromMap(Map<String, dynamic> map) =>
      AcademicTranslationResult(
        translation: (map['translation'] ?? '').toString(),
        model: (map['model'] ?? '').toString(),
        chunks: (map['chunks'] as num?)?.toInt() ?? 0,
      );
}
