import 'citation_parser.dart';

/// Pull bibliography lines from a thesis/manuscript without inventing rows.
class BibliographyHarvest {
  BibliographyHarvest._();

  static final _header = RegExp(
    r'^(references|bibliography|works cited|المراجع|قائمة المراجع|المصادر)\b',
    caseSensitive: false,
  );

  static String fromLines(Iterable<String> lines) {
    final out = <String>[];
    for (final line in lines) {
      final trimmed = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (trimmed.length < 12) continue;
      out.add(trimmed);
    }
    return out.join('\n');
  }

  /// Prefer the last References/المراجع block; otherwise the tail if it looks
  /// like a list (numbered lines or DOIs).
  static String fromThesisText(String text, {int tailChars = 22000}) {
    final cleaned = text.replaceAll('\r\n', '\n').trim();
    if (cleaned.length < 24) return '';

    final fromHeader = _afterLastHeader(cleaned);
    if (fromHeader.length >= 40) {
      return _cap(fromHeader, tailChars);
    }

    final tail = cleaned.length > tailChars
        ? cleaned.substring(cleaned.length - tailChars)
        : cleaned;
    if (!_looksLikeBibliography(tail)) return '';
    return tail.trim();
  }

  static String combine(String a, String b) {
    final seen = <String>{};
    final lines = <String>[];
    for (final chunk in [a, b]) {
      for (final line in chunk.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.length < 12) continue;
        final key = trimmed.toLowerCase();
        if (!seen.add(key)) continue;
        lines.add(trimmed);
      }
    }
    return lines.join('\n');
  }

  static String _afterLastHeader(String text) {
    final lines = text.split('\n');
    var lastHeader = -1;
    for (var i = 0; i < lines.length; i++) {
      if (_header.hasMatch(lines[i].trim())) lastHeader = i;
    }
    if (lastHeader < 0) return '';
    return lines.skip(lastHeader + 1).join('\n').trim();
  }

  static bool _looksLikeBibliography(String text) {
    final dois = CitationParser.doiPattern.allMatches(text).length;
    if (dois >= 2) return true;
    final numbered = RegExp(r'^(\[\d+\]|\d+\.)\s+', multiLine: true)
        .allMatches(text)
        .length;
    return numbered >= 3;
  }

  static String _cap(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return text.substring(text.length - maxChars);
  }
}
