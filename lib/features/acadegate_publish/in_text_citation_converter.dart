import 'academic_text.dart';
import 'bibliography_match.dart';
import 'citation_formatter.dart';
import 'citation_linker.dart';
import 'citation_style_shapes.dart';
import 'publish_models.dart';

/// Two conversions, nothing else:
///
/// * Numbered: remove the author–year and put `[n]`. For a numbered journal,
///   `n` is the order of first appearance in the paper, not the old list.
/// * Author–year: remove `[n]` and put `(Author, Year)` of bibliography item n.
class InTextCitationConverter {
  InTextCitationConverter._();

  /// Capitalized surname, including a space before a combining mark.
  static const _surname =
      r"[\p{Lu}](?:[\p{L}\p{M}'\-]|\s(?=[\p{M}]))+";
  static const _initials = r'(?:[\p{Lu}]\.\s*){1,4}';
  static const _year = r'(?:19|20)\d{2}[a-z]?';

  /// One author, with a compound surname (`Raghuram Ulu`) and optional initials.
  static const _person =
      '$_surname(?:\\s+$_surname){0,2}(?:\\s*,\\s*$_initials)?';

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

  /// A group is resolved as a whole; an unknown member never erases siblings.
  static List<PublishReference>? referencesForCitationGroup(
    String text,
    List<PublishReference> references,
  ) {
    var inner = text
        .trim()
        .replaceFirst(RegExp(r'^\('), '')
        .replaceFirst(RegExp(r'\)$'), '');
    inner = inner.replaceAllMapped(
      RegExp(
        r'((?:19|20)\d{2}[a-z]?)\s*(?:,|\band\b)\s*(?=[\p{Lu}])',
        unicode: true,
      ),
      (m) => '${m[1]}; ',
    );
    final match = BibliographyMatch(references);
    final resolved = <PublishReference>[];
    for (final part in inner.split(';')) {
      final years = RegExp(
        r'\b(?:19|20)\d{2}[a-z]?\b',
      ).allMatches(part).toList();
      if (years.length != 1) return null;
      final year = years.single.group(0)!;
      final author = part.substring(0, years.single.start).trim();
      if (author.isEmpty ||
          !RegExp(r'^[\p{Lu}]', unicode: true).hasMatch(author) ||
          RegExp(
            r'\b(?:the|this|these|those|using|used|reported|measured|samples|between|from)\b',
            caseSensitive: false,
          ).hasMatch(author) ||
          !RegExp(r'^[\s,.]*$').hasMatch(part.substring(years.single.end))) {
        return null;
      }
      final ref = match.byAuthorYear(
        author.replaceAll(RegExp(r'[,;:]+$'), ''),
        year,
      );
      if (ref == null) return null;
      resolved.add(ref);
    }
    return resolved.isEmpty ? null : resolved;
  }

  /// Walk one piece of text left to right. The first new work claims the next
  /// number in [order]; a later mention of the same work keeps that number.
  static String rewriteNumberedByAppearance({
    required String text,
    required BibliographyMatch match,
    required NumberedCitationOrder order,
  }) {
    if (text.trim().isEmpty) return text;
    final source = AcademicText.westernDigits(text);
    if (CitationLinker.isEquationNumberLine(source)) return source;
    final spans = _appearanceSpans(source, match);
    if (spans.isEmpty) return _compactAdjacentNumbers(source);
    spans.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return b.end.compareTo(a.end);
    });
    final buffer = StringBuffer();
    var cursor = 0;
    for (final span in spans) {
      if (span.start < cursor) continue;
      buffer.write(source.substring(cursor, span.start));
      buffer.write(span.render(order));
      cursor = span.end;
    }
    buffer.write(source.substring(cursor));
    return _compactAdjacentNumbers(buffer.toString());
  }

  static List<_AppearanceSpan> _appearanceSpans(
    String source,
    BibliographyMatch match,
  ) {
    final spans = <_AppearanceSpan>[];
    final groups = RegExp(r'\(([^()]*\b(?:19|20)\d{2}[^()]*)\)')
        .allMatches(source)
        .where((m) => !RegExp(r'^\s*(?:19|20)\d{2}[a-z]?\s*$').hasMatch(m[1]!))
        .toList();
    final atomic = <_AppearanceSpan>[];
    for (final group in groups) {
      final refs = referencesForCitationGroup(group[0]!, match.references);
      if (refs != null &&
          !CitationLinker.isEquationLeader(source.substring(0, group.start))) {
        atomic.add(
          _AppearanceSpan(
            group.start,
            group.end,
            (order) => '[${refs.map((r) => order.claim(r)).join(',')}]',
          ),
        );
      }
    }

    for (final m in RegExp(citeMarkerPattern).allMatches(source)) {
      final ref = match.byId(m.group(1) ?? '');
      if (ref == null) continue;
      spans.add(_AppearanceSpan(m.start, m.end, (order) => '[${order.claim(ref)}]'));
    }

    for (final m in RegExp(r'\[(\d{1,3}(?:\s*[,;]\s*\d{1,3})*)\]').allMatches(source)) {
      if (_keepBracketAsWritten(source, m.start, m.end)) continue;
      final before = source.substring(0, m.start);
      if (CitationLinker.isEquationNumberContext(before) ||
          CitationLinker.isFloatNumberContext(before) ||
          CitationLinker.isEquationLeader(before)) {
        continue;
      }
      final nums = [
        for (final p in m.group(1)!.split(RegExp(r'\s*[,;]\s*')))
          int.tryParse(p.trim()),
      ].whereType<int>().where((n) => n > 0).toList();
      if (nums.isEmpty) continue;
      if (nums.every((n) => match.byNumber(n) == null)) continue;
      spans.add(_AppearanceSpan(m.start, m.end, (order) {
        final printed = <String>[];
        for (final n in nums) {
          final ref = match.byNumber(n);
          printed.add(ref == null ? '$n' : '${order.claim(ref)}');
        }
        return '[${printed.join(',')}]';
      }));
    }

    for (final m in _parentheticalCite.allMatches(source)) {
      if (CitationLinker.isEquationLeader(source.substring(0, m.start))) continue;
      final ref = _referenceForAuthorYear(m.group(1)!, m.group(2)!, match);
      if (ref == null) continue;
      spans.add(_AppearanceSpan(m.start, m.end, (order) => '[${order.claim(ref)}]'));
    }
    for (final m in _narrativeCite.allMatches(source)) {
      if (CitationLinker.isEquationLeader(source.substring(0, m.start))) continue;
      final ref = _referenceForAuthorYear(m.group(1)!, m.group(2)!, match);
      if (ref == null) continue;
      spans.add(_AppearanceSpan(m.start, m.end, (order) => '[${order.claim(ref)}]'));
    }
    for (final m in _bareCite.allMatches(source)) {
      final authors = m.group(1)!;
      if (!RegExp(r'\bet\s+al\.?|\s+(?:&|and)\s+|,', caseSensitive: false)
          .hasMatch(authors)) {
        continue;
      }
      if (CitationLinker.isEquationLeader(source.substring(0, m.start))) continue;
      final ref = _referenceForAuthorYear(authors, m.group(2)!, match);
      if (ref == null) continue;
      spans.add(_AppearanceSpan(m.start, m.end, (order) => '[${order.claim(ref)}]'));
    }
    for (final m in RegExp(
      r'\b([A-Z][\p{L}\-]{2,}(?:\s+[A-Z][\p{L}\-]{2,}){0,3}(?:\s+et\s+al\.?)?)\s*\(((?:19|20)\d{2}[a-z]?)\)',
      unicode: true,
    ).allMatches(source)) {
      if (CitationLinker.isEquationLeader(source.substring(0, m.start))) continue;
      final ref = _referenceForAuthorYear(m.group(1)!, m.group(2)!, match);
      if (ref == null) continue;
      spans.add(_AppearanceSpan(m.start, m.end, (order) => '[${order.claim(ref)}]'));
    }
    return [
      ...atomic,
      for (final span in spans)
        if (!groups.any((g) => span.start < g.end && span.end > g.start)) span,
    ];
  }

  static String _compactAdjacentNumbers(String result) {
    result = result.replaceAllMapped(
      RegExp(r'\[(\d{1,3})\]\s*\[\1\]'),
      (m) => '[${m.group(1)}]',
    );
    var compact = result;
    final adjacent = RegExp(
      r'\[(\d{1,3}(?:,\d{1,3})*)\],\s*\[(\d{1,3}(?:,\d{1,3})*)\]',
    );
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

  static PublishReference? _referenceForAuthorYearChunk(
    String chunk,
    BibliographyMatch match,
  ) {
    final year = RegExp(
          r'\b((?:19|20)\d{2}[a-z])\b',
          caseSensitive: false,
        ).firstMatch(chunk)?.group(1) ??
        CitationStyleShapes.yearFromCitation(chunk) ??
        RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(chunk)?.group(1);
    if (year == null) return null;
    final names = CitationStyleShapes.lastNamesFromCitation(chunk);
    if (names.isEmpty) return null;
    return match.byLastNames(names, year: year) ??
        match.byAuthorYear(names.first, year);
  }

  static PublishReference? _referenceForAuthorYear(
    String authorPart,
    String year,
    BibliographyMatch match,
  ) {
    return _referenceForAuthorYearChunk('$authorPart $year', match) ??
        match.byAuthorYear(authorPart, year);
  }

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
    final protected = <String>[];
    result = result.replaceAllMapped(
      RegExp(r'\(([^()]*\b(?:19|20)\d{2}[^()]*)\)'),
      (m) {
        if (RegExp(r'^\s*(?:19|20)\d{2}[a-z]?\s*$').hasMatch(m[1]!)) {
          return m[0]!;
        }
        final refs = referencesForCitationGroup(m[0]!, references);
        protected.add(
          refs == null
              ? m[0]!
              : '[${refs.map((r) => match.numberOf(r)).join(',')}]',
        );
        return '\uE000${protected.length - 1}\uE001';
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
    return compact.replaceAllMapped(
      RegExp('\uE000(\\d+)\uE001'),
      (m) => protected[int.parse(m[1]!)],
    );
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
        final bracketNums = [
          for (final p in m.group(1)!.split(RegExp(r'\s*[,;]\s*')))
            int.tryParse(p.trim()),
        ].whereType<int>().where((n) => n > 0).toList();
        // A glued bracket ("features[50]and") is normal after PDF conversion.
        // It stays put only when some number in it names no reference, so
        // identifiers and stray brackets are kept while real citations convert.
        final allResolve = bracketNums.isNotEmpty &&
            bracketNums.every((n) => match.byNumber(n) != null);
        if (!allResolve && _keepBracketAsWritten(source, m.start, m.end)) {
          return m.group(0)!;
        }
        final before = source.substring(0, m.start);
        if (CitationLinker.isEquationNumberContext(before) ||
            CitationLinker.isFloatNumberContext(before) ||
            CitationLinker.isEquationLeader(before) ||
            CitationLinker.isEquationNumberLine(source)) {
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

/// First-citation numbers for one numbered-style export.
class NumberedCitationOrder {
  final Map<String, int> _numbers = {};
  final List<String> ids = [];

  int? numberOf(String id) => _numbers[id];

  int claim(PublishReference ref) {
    final existing = _numbers[ref.id];
    if (existing != null) return existing;
    final n = _numbers.length + 1;
    _numbers[ref.id] = n;
    ids.add(ref.id);
    return n;
  }
}

class _AppearanceSpan {
  final int start;
  final int end;
  final String Function(NumberedCitationOrder order) render;

  _AppearanceSpan(this.start, this.end, this.render);
}
