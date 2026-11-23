/// Generation failure is not content and must never be saved as an abstract.
class ThesisAbstractGenerationException implements Exception {
  final String message;
  const ThesisAbstractGenerationException(this.message);
  @override
  String toString() => message;
}

/// The prompts ask for 180-250 (or 180-280) words. Allow some variation,
/// but do not accept a short fragment as a completed abstract.
const thesisAbstractMinimumWords = 140;

/// A conservative completeness heuristic, not a factual/semantic quality check.
/// Punctuation-only tokens are not words. Arabic and English are supported.
bool isUsableGeneratedAbstract(String? text) {
  final cleaned = text?.trim() ?? '';
  final wordLike = RegExp(
    r'[A-Za-z0-9\u0621-\u064A\u0660-\u0669\u0671-\u06D3]',
  );
  final words = cleaned.split(RegExp(r'\s+')).where(wordLike.hasMatch).length;
  if (words < thesisAbstractMinimumWords) return false;

  // Allow closing quotation marks and numeric citations after a full stop.
  // Do not append punctuation to repair output: that would hide truncation.
  var ending = cleaned;
  final suffix = RegExp(r'''(?:["'”’»)]|\[\d+(?:\s*[,،–-]\s*\d+)*\])\s*$''');
  while (suffix.hasMatch(ending)) {
    ending = ending.replaceFirst(suffix, '').trimRight();
  }
  if (RegExp(r'(?:\.{2,}|…)[.!?؟۔]*$').hasMatch(ending)) return false;
  return RegExp(r'[.!?؟۔]$').hasMatch(ending);
}

/// Invalid generated content cannot replace an existing abstract.
String generatedAbstractOrPrevious(String? text, String previous) =>
    isUsableGeneratedAbstract(text) ? text!.trim() : previous;

String requireGeneratedAbstract(
  String? text, {
  required String failureMessage,
}) {
  if (!isUsableGeneratedAbstract(text)) {
    throw ThesisAbstractGenerationException(failureMessage);
  }
  return text!.trim();
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
