import 'academic_text.dart';
import 'bibliography_match.dart';
import 'citation_formatter.dart';
import 'citation_linker.dart';
import 'citation_style_shapes.dart';
import 'publish_models.dart';

/// Two conversions, nothing else:
///
/// * Numbered: remove the author–year and put `[n]` of that same bibliography row.
/// * Author–year: remove `[n]` and put `(Author, Year)` of bibliography item n.
class InTextCitationConverter {
  InTextCitationConverter._();

  /// Capitalized surname, including a space before a combining mark.
  static const _surname =
      r"[\p{Lu}](?:[\p{L}\p{M}'\-]|\s(?=[\p{M}]))+";
  static const _initials = r'(?:[\p{Lu}]\.\s*){1,4}';
  static const _year = r'(?:19|20)\d{2}[a-z]?';

  /// One author, with optional initials.
  static const _person = '$_surname(?:\\s*,\\s*$_initials)?';

  /// Full in-text author list: `Author and Author`, `Author, Author, and Author`,
  /// `Author et al.`, `Author, A. A., and Author, B.`
  static const _authors = '$_person'
      r'(?:'
      r'(?:\s*,\s*' + _person + r')+'
      r'(?:\s*,?\s*(?:&|and)\s+' + _person + r')?'
      r'(?:\s*,?\s*et\s+al\.?)?'
      r'|'
      r'(?:\s+(?:&|and)\s+' + _person + r')'
      r'(?:\s+et\s+al\.?)?'
      r'|'
      r'(?:\s+et\s+al\.?)'
      r')?';

  static final _parentheticalCite = RegExp(
    '\\(\\s*($_authors)\\s*,?\\s*($_year)\\s*\\)',
    unicode: true,
  );

  static final _narrativeCite = RegExp(
    '(?:\\(\\s*)?\\b($_authors)\\s*\\(($_year)\\)',
    unicode: true,
  );

  static final _bareCite = RegExp(
    '\\b($_authors)\\s+($_year)\\b',
    unicode: true,
  );

  /// Replace (Author, Year) / Author (Year) with [n] of that same row.
  static String applyNumberedCitations({
    required String text,
    required List<PublishReference> references,
    required PublishCitationStyle targetStyle,
  }) {
    if (!CitationFormatter.isNumberedStyle(targetStyle) ||
        references.isEmpty ||
        text.trim().isEmpty) {
      return text;
    }

    final match = BibliographyMatch(references);
    var result = _resolveCiteMarkers(AcademicText.westernDigits(text), match);

    result = result.replaceAllMapped(
      RegExp(r'\(([^()]{8,400})\)'),
      (m) {
        final inner = m.group(1)!;
        if (!inner.contains(';')) return m.group(0)!;
        if (!RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(inner)) return m.group(0)!;
        final nums = <int>[];
        for (final chunk in inner.split(';')) {
          final n = _numberForAuthorYearChunk(chunk.trim(), match);
          if (n == null) return m.group(0)!;
          nums.add(n);
        }
        return nums.isEmpty ? m.group(0)! : '[${nums.join(',')}]';
      },
    );

    result = result.replaceAllMapped(
      _parentheticalCite,
      (m) => _replaceWithNumber(m.group(0)!, m.group(1)!, m.group(2)!, match),
    );
    result = result.replaceAllMapped(
      _narrativeCite,
      (m) => _replaceWithNumber(m.group(0)!, m.group(1)!, m.group(2)!, match),
    );
    result = result.replaceAllMapped(
      _bareCite,
      (m) {
        final authors = m.group(1)!;
        if (!RegExp(r'\bet\s+al\.?|\s+(?:&|and)\s+|,', caseSensitive: false)
            .hasMatch(authors)) {
          return m.group(0)!;
        }
        return _replaceWithNumber(m.group(0)!, authors, m.group(2)!, match);
      },
    );

    result = result.replaceAllMapped(
      RegExp(r'\[(\d{1,3})\]\s*\[\1\]'),
      (m) => '[${m.group(1)}]',
    );
    var compact = result;
    final adjacent = RegExp(r'\[(\d{1,3}(?:,\d{1,3})*)\],\s*\[(\d{1,3}(?:,\d{1,3})*)\]');
    while (true) {
      final next = compact.replaceAllMapped(
        adjacent,
        (m) => '[${m.group(1)},${m.group(2)}]',
      );
      if (next == compact) break;
      compact = next;
    }
    return compact;
  }

  static String _replaceWithNumber(
    String original,
    String authorPart,
    String year,
    BibliographyMatch match,
  ) {
    final n = _numberForAuthorYearChunk('$authorPart $year', match) ??
        _numberForAuthorYear(authorPart, year, match);
    return n == null ? original : '[$n]';
  }

  static int? _numberForAuthorYearChunk(String chunk, BibliographyMatch match) {
    final year = CitationStyleShapes.yearFromCitation(chunk) ??
        RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(chunk)?.group(1);
    if (year == null) return null;
    final names = CitationStyleShapes.lastNamesFromCitation(chunk);
    if (names.isEmpty) return null;
    final ref = match.byLastNames(names, year: year) ??
        match.byAuthorYear(names.first, year);
    if (ref == null) return null;
    return match.numberOf(ref);
  }

  static int? _numberForAuthorYear(
    String authorPart,
    String year,
    BibliographyMatch match,
  ) {
    final ref = match.byAuthorYear(authorPart, year);
    if (ref == null) return null;
    return match.numberOf(ref);
  }

  /// `[n]` → `(Author, Year)` of bibliography item n.
  /// If that same work’s names and year already sit next to `[n]`, only
  /// the number is removed.
  static String applyAuthorDateCitations({
    required String text,
    required List<PublishReference> references,
    required PublishCitationStyle targetStyle,
  }) {
    if (CitationFormatter.isNumberedStyle(targetStyle) ||
        references.isEmpty ||
        text.trim().isEmpty) {
      return text;
    }

    final match = BibliographyMatch(references);
    final source = _resolveCiteMarkers(AcademicText.westernDigits(text), match);
    return source.replaceAllMapped(
      RegExp(r'\[(\d{1,3}(?:\s*[,;]\s*\d{1,3})*)\]'),
      (m) {
        if (_keepBracketAsWritten(source, m.start, m.end)) {
          return m.group(0)!;
        }
        final before = source.substring(0, m.start);
        if (CitationLinker.isEquationNumberContext(before)) {
          return m.group(0)!;
        }
        final nums = [
          for (final p in m.group(1)!.split(RegExp(r'\s*[,;]\s*')))
            int.tryParse(p.trim()),
        ].whereType<int>().where((n) => n > 0).toList();
        if (nums.isEmpty) return m.group(0)!;
        final parts = <String>[];
        for (final n in nums) {
          final ref = match.byNumber(n);
          if (ref == null) {
            parts.add('[$n]');
            continue;
          }
          if (_sameWorkAlreadyInText(before, ref)) continue;
          final inner = _authorYearInner(ref, targetStyle);
          parts.add(inner.isEmpty ? '[$n]' : inner);
        }
        if (parts.isEmpty) return '';
        if (parts.every((p) => p.startsWith('['))) return parts.join(', ');
        return '(${parts.join('; ')})';
      },
    );
  }

  /// A letter glued to `[n]`, or `[n]` glued to a capital word, is not a cite.
  static bool _keepBracketAsWritten(String source, int start, int end) {
    if (start > 0 &&
        RegExp(r'[A-Za-z\u00C0-\u024F\u0600-\u06FF]')
            .hasMatch(source[start - 1])) {
      return true;
    }
    if (end < source.length &&
        RegExp(r'[A-Z\u00C0-\u024F]').hasMatch(source[end])) {
      return true;
    }
    return false;
  }

  static String _authorYearInner(
    PublishReference ref,
    PublishCitationStyle style,
  ) {
    final formatted = CitationFormatter.formatInText(
      reference: ref,
      style: style,
      index: BibliographyMatch.importedNumberOf(ref) ?? 1,
      form: InTextCitationForm.parenthetical,
    ).trim();
    if (formatted.startsWith('(') && formatted.endsWith(')')) {
      return formatted.substring(1, formatted.length - 1);
    }
    if (formatted.isNotEmpty && !RegExp(r'^\[\d+\]$').hasMatch(formatted)) {
      return formatted;
    }
    final year = BibliographyMatch.yearOf(ref);
    final names = BibliographyMatch.lastNamesOf(ref);
    if (names.isEmpty || year.length < 4) return '';
    final lead = names.first;
    final display = lead.isEmpty
        ? lead
        : '${lead[0].toUpperCase()}${lead.substring(1)}';
    return '$display, $year';
  }

  static bool _sameWorkAlreadyInText(String before, PublishReference ref) {
    final tail = before.length > 160
        ? before.substring(before.length - 160)
        : before;
    final year = BibliographyMatch.yearOf(ref);
    if (year.length < 4 || !tail.contains(year)) return false;
    final folded = AcademicText.nameKey(tail);
    for (final name in BibliographyMatch.lastNamesOf(ref)) {
      if (name.length >= 3 && folded.contains(AcademicText.nameKey(name))) {
        return true;
      }
    }
    return false;
  }

  static String _resolveCiteMarkers(String text, BibliographyMatch match) {
    if (!text.contains('{{cite:')) return text;
    return text.replaceAllMapped(RegExp(citeMarkerPattern), (m) {
      final ref = match.byId(m.group(1) ?? '');
      if (ref == null) return m.group(0)!;
      final n = match.numberOf(ref);
      if (n == null) return m.group(0)!;
      return '[$n]';
    });
  }
}
