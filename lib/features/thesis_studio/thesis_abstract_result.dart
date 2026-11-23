/// Generation failure is not content and must never be saved as an abstract.
class ThesisAbstractGenerationException implements Exception {
  final String message;
  const ThesisAbstractGenerationException(this.message);
  @override
  String toString() => message;
}

String requireGeneratedAbstract(
  String? text, {
  required String failureMessage,
}) {
  final cleaned = text?.trim() ?? '';
  if (cleaned.length < 80) {
    throw ThesisAbstractGenerationException(failureMessage);
  }
  return cleaned;
}

/// A syntactically usable DOI is not proof of independent verification.
Uri? thesisDoiUri(String value) {
  final doi = value.trim().replaceFirst(
    RegExp(r'^https?://(?:dx\.)?doi\.org/', caseSensitive: false),
    '',
  );
  if (!RegExp(r'^10\.\d{4,9}/\S+$').hasMatch(doi) ||
      RegExp(r'[\x00-\x20\x7f]').hasMatch(doi))
    return null;
  return Uri.https('doi.org', '/$doi');
}
