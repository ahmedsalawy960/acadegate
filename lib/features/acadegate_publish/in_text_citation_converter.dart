import 'citation_formatter.dart';
import 'publish_models.dart';

/// Converts author–date in-text citations to numbered [n] only when the
/// surname + year match a known reference (strict — no guessing).
class InTextCitationConverter {
  InTextCitationConverter._();

  /// Replace (Author, Year) / Author (Year) with [index] only for IEEE/BCSE
  /// when author surname and year exactly match the reference list.
  static String applyNumberedCitations({
    required String text,
    required List<PublishReference> references,
    required PublishCitationStyle targetStyle,
  }) {
    if (!CitationFormatter.isNumberedStyle(targetStyle) ||
        references.isEmpty) {
      return text;
    }
    if (text.trim().isEmpty) return text;

    final matchers = _buildMatchers(references);
    if (matchers.isEmpty) return text;

    var result = text;

    // (Smith, 2020) / (Smith et al., 2020) / (Smith & Jones, 2020)
    result = result.replaceAllMapped(
      RegExp(
        r'\('
        r'([A-Z][A-Za-z\-]{2,}(?:\s+et\s+al\.?)?'
        r'(?:\s+(?:&|and)\s+[A-Z][A-Za-z\-]{2,})?)'
        r',\s*((?:19|20)\d{2})[a-z]?'
        r'\)',
      ),
      (m) => _tryReplace(m.group(0)!, m.group(1)!, m.group(2)!, matchers),
    );

    // Smith (2020) / Smith et al. (2020)
    result = result.replaceAllMapped(
      RegExp(
        r'\b([A-Z][A-Za-z\-]{2,}(?:\s+et\s+al\.?)?)\s+'
        r'\(((?:19|20)\d{2})[a-z]?\)',
      ),
      (m) => _tryReplace(m.group(0)!, m.group(1)!, m.group(2)!, matchers),
    );

    return result;
  }

  static List<_RefMatcher> _buildMatchers(List<PublishReference> references) {
    return [
      for (var i = 0; i < references.length; i++)
        if (_primaryLastName(references[i]).length >= 3)
          _RefMatcher(
            index: i + 1,
            primaryLastName: _primaryLastName(references[i]).toLowerCase(),
            year: _referenceYear(references[i]),
            allLastNames: _allLastNames(references[i])
                .map((n) => n.toLowerCase())
                .where((n) => n.length >= 3)
                .toSet(),
          ),
    ];
  }

  static String _tryReplace(
    String original,
    String authorPart,
    String year,
    List<_RefMatcher> matchers,
  ) {
    if (_isBlockedAuthorToken(authorPart)) return original;

    final normalizedYear = year.replaceAll(RegExp(r'[a-z]$'), '');
    final lead = authorPart
        .replaceAll(RegExp(r'\s+et\s+al\.?', caseSensitive: false), '')
        .trim();
    final firstAuthor = lead
        .split(RegExp(r'\s+(?:&|and)\s+', caseSensitive: false))
        .first
        .trim();
    final lastName = _normalizeName(firstAuthor).toLowerCase();

    if (lastName.length < 3 || _blocklist.contains(lastName)) return original;

    for (final m in matchers) {
      if (m.year != normalizedYear) continue;
      if (m.primaryLastName == lastName || m.allLastNames.contains(lastName)) {
        return '[${m.index}]';
      }
    }
    return original;
  }

  static bool _isBlockedAuthorToken(String authorPart) {
    final token = authorPart
        .replaceAll(RegExp(r'\s+et\s+al\.?', caseSensitive: false), '')
        .split(RegExp(r'\s+(?:&|and)\s+', caseSensitive: false))
        .first
        .trim()
        .toLowerCase();
    return _blocklist.contains(token);
  }

  /// Common scientific / English words — never treat as author surnames.
  static const _blocklist = {
    'aldehydes',
    'alcohols',
    'olefins',
    'nitriles',
    'heterocyclic',
    'ester',
    'esters',
    'terpene',
    'terpenes',
    'ketone',
    'ketones',
    'thiones',
    'flax',
    'flaxseed',
    'rapeseed',
    'abstract',
    'introduction',
    'results',
    'discussion',
    'conclusion',
    'method',
    'methods',
    'table',
    'figure',
    'however',
    'therefore',
    'moreover',
    'furthermore',
    'according',
    'analysis',
    'compound',
    'compounds',
    'sample',
    'samples',
    'study',
    'studies',
    'data',
    'using',
    'based',
    'total',
    'major',
    'minor',
    'acid',
    'acids',
    'fatty',
    'protein',
    'carbohydrate',
    'moisture',
    'ash',
    'fiber',
    'content',
    'volatile',
    'chromatography',
    'spectrometry',
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  };

  static String _normalizeName(String name) {
    return name.replaceAll(RegExp(r"['\-]"), '').trim();
  }

  static String _primaryLastName(PublishReference ref) {
    final fromAuthors = ref.authors
        .where((a) => a.trim().isNotEmpty)
        .map(_lastNameFromAuthor)
        .where((n) => n.length >= 3)
        .toList();
    if (fromAuthors.isNotEmpty) return fromAuthors.first;

    return _lastNameFromRaw(ref.rawText);
  }

  static List<String> _allLastNames(PublishReference ref) {
    final names = <String>{};
    for (final author in ref.authors) {
      final n = _lastNameFromAuthor(author);
      if (n.length >= 3) names.add(n);
    }
    if (names.isEmpty && ref.rawText.isNotEmpty) {
      for (final part in _authorPartsFromRaw(ref.rawText)) {
        final n = _lastNameFromAuthor(part);
        if (n.length >= 3) names.add(n);
      }
    }
    return names.toList();
  }

  static List<String> _authorPartsFromRaw(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(RegExp(r'^\[\d+\]\s*'), '');
    s = s.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
    final yearMatch = RegExp(r',?\s*(19|20)\d{2}\b').firstMatch(s);
    if (yearMatch != null) {
      s = s.substring(0, yearMatch.start);
    }
    if (s.contains(';')) {
      return s.split(';').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }
    return s
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .take(8)
        .toList();
  }

  static String _lastNameFromRaw(String raw) {
    final parts = _authorPartsFromRaw(raw);
    if (parts.isEmpty) return '';
    return _lastNameFromAuthor(parts.first);
  }

  static String _lastNameFromAuthor(String author) {
    final trimmed = author.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(',')) {
      return _normalizeName(trimmed.split(',').first.trim());
    }
    final words = trimmed.split(RegExp(r'\s+'));
    return words.isNotEmpty ? _normalizeName(words.last) : _normalizeName(trimmed);
  }

  static String _referenceYear(PublishReference ref) {
    if (ref.year.trim().isNotEmpty) return ref.year.trim();
    final fromRaw = RegExp(r'\b(19|20)\d{2}\b').firstMatch(ref.rawText);
    return fromRaw?.group(0) ?? '';
  }
}

class _RefMatcher {
  final int index;
  final String primaryLastName;
  final String year;
  final Set<String> allLastNames;

  const _RefMatcher({
    required this.index,
    required this.primaryLastName,
    required this.year,
    required this.allLastNames,
  });
}
