import 'academic_text.dart';
import 'bibliography_match.dart';
import 'citation_cues.dart';
import 'citation_style_shapes.dart';
import 'docx_scientific_extractor.dart';
import 'publish_models.dart';

/// Links in-text citations to bibliography entries.
/// `[n]` always means imported bibliography item n — never remapped.
///
/// Bold spans imported from Word are wrapped as `<<CITE:…>>` so they are
/// treated as citations even when the surrounding sentence is noisy.
class CitationLinker {
  CitationLinker._();

  static const hintOpen = '<<CITE:';
  static const hintClose = '>>';

  static bool looksLikeCitationHint(String raw, {bool inBody = false, String before = ''}) {
    final t = AcademicText.westernDigits(raw.trim());
    if (t.isEmpty || looksLikeBibliographyLine(t)) return false;
    if (CitationStyleShapes.looksLikeSectionHeading(t)) return false;
    if (CitationStyleShapes.looksLikeAuthorCitation(t)) return true;
    if (_authorDatePart.hasMatch(t)) return true;
    if (_narrativeCite.hasMatch(t)) return true;
    // In the paper body, bold/superscript "1" or "1–3" is a citation.
    // On the title page the same digits are affiliation marks.
    if (inBody &&
        t.length <= 24 &&
        RegExp(r'^\d{1,3}(?:\s*[,;–-]\s*\d{1,3}){0,8}$').hasMatch(t)) {
      if (looksLikeMathExponent(t, before)) return false;
      if (CitationLinker.isEquationNumberContext(before)) return false;
      return true;
    }
    return false;
  }

  /// Entire bibliography entries are often bold in Word — never treat as in-text.
  static bool looksLikeBibliographyLine(String raw) {
    final s = AcademicText.westernDigits(raw.trim());
    if (s.length < 40) return false;
    if (RegExp(r'^\[\d{1,3}\]\s+\S').hasMatch(s)) return true;
    if (RegExp(r'^\d{1,3}\.\s+[A-Z][A-Za-z\-]+,').hasMatch(s)) return true;
    return RegExp(r'^[A-Z][A-Za-z\-]+(?:\s+[A-Z][A-Za-z\-]+)?,\s*[A-Z]\.').hasMatch(s) &&
        RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(s) &&
        (s.contains(';') ||
            s.toLowerCase().contains('doi') ||
            s.toLowerCase().contains('vol.') ||
            s.toLowerCase().contains('doi.org') ||
            RegExp(r':\s*[A-Z][A-Za-z]').hasMatch(s));
  }

  /// Wrap a Word bold/superscript span so the linker can resolve it later.
  static String applyHintWrap(
    String raw, {
    required bool inBody,
    String before = '',
  }) {
    if (raw.isEmpty) return raw;
    if (CitationStyleShapes.looksLikeSectionHeading(raw)) return raw;
    if (looksLikeMathExponent(raw, before)) {
      return toSuperscriptDigits(asciiDigits(raw));
    }
    if (CitationLinker.isEquationNumberContext(before)) {
      return raw;
    }
    if (!inBody) {
      return looksLikeCitationHint(raw, inBody: false, before: before)
          ? '$hintOpen$raw$hintClose'
          : raw;
    }
    if (looksLikeBibliographyLine(raw)) return raw;
    if (looksLikeCitationHint(raw, inBody: true, before: before)) {
      return '$hintOpen$raw$hintClose';
    }
    return wrapInnerCitationPatterns(raw);
  }

  /// `mol²`, `R²`, `cm⁻¹` — exponents, not bibliography numbers.
  static bool looksLikeMathExponent(String raw, String before) {
    var t = (_fromSuperscriptDigits(raw.trim()) ?? asciiDigits(raw)).trim();
    t = t.replaceAll(RegExp(r'[−–—]'), '-');
    if (RegExp(r'^-?\d{1,4}$').hasMatch(t) && t.startsWith('-')) return true;
    if (!RegExp(r'^\d{1,4}$').hasMatch(t)) return false;
    final token = _trailingToken(before);
    if (token.isEmpty) return false;
    if (RegExp(r'^\d+$').hasMatch(token)) return true;
    if (_unitOrSymbol.hasMatch(token)) return true;
    if (RegExp(r'^[A-Za-zα-ωΑ-Ωε]$').hasMatch(token)) return true;
    final n = int.tryParse(t) ?? 0;
    // mol² / kJ² / cm²: short identifier + a small power (not ACS 33).
    if (t.length == 1 &&
        n <= 6 &&
        token.length <= 3 &&
        RegExp(r"^[A-Za-z]{1,3}$").hasMatch(token)) {
      return true;
    }
    return false;
  }

  static bool isEquationNumberContext(String before) {
    final tail = before.trimRight();
    if (tail.isEmpty) return false;
    return RegExp(
      r'(?:equations?|eq(?:ns?|uations?)?\.?|formulae?|models?)\s*$',
      caseSensitive: false,
    ).hasMatch(tail);
  }

  static String _trailingToken(String before) {
    final t = before.trimRight();
    if (t.isEmpty) return '';
    final m = RegExp(r"([A-Za-zα-ωΑ-Ωε]{1,12}|\d+)\s*$").firstMatch(t);
    return m?.group(1) ?? '';
  }

  static final _unitOrSymbol = RegExp(
    r'^(?:mol|mmol|kmol|kJ|kcal|cal|J|eV|cm|mm|nm|um|μm|kg|mg|ug|μg|'
    r'mL|ml|L|Pa|kPa|MPa|bar|atm|K|eq|log|ln|sin|cos|tan|exp|max|min|'
    r'pH|ppm|ppb|wt|vol|hr|min|sec|yr)$',
    caseSensitive: false,
  );

  static String wrapInnerCitationPatterns(String raw) {
    if (raw.contains(hintOpen)) return raw;
    var s = raw;
    s = s.replaceAllMapped(
      RegExp(r'\[\d{1,3}(?:\s*[,;–-]\s*\d{1,3})*\]'),
      (m) => '$hintOpen${m.group(0)}$hintClose',
    );
    s = s.replaceAllMapped(
      RegExp(
        r'\('
        r'(?:'
        r'[A-Z][A-Za-z\-]{1,}(?:\s+[A-Z][A-Za-z\-]{1,}){0,2}'
        r'(?:,\s*(?:[A-Z]\.\s*)+)?'
        r'(?:\s+et\s+al\.?)?'
        r'(?:'
        r'\s*,\s*[A-Z][A-Za-z\-]{1,}(?:\s+[A-Z][A-Za-z\-]{1,}){0,2}'
        r'(?:,\s*(?:[A-Z]\.\s*)+)?'
        r')*'
        r'(?:\s*,?\s*(?:&|and)\s+[A-Z][A-Za-z\-]{1,}(?:\s+[A-Z][A-Za-z\-]{1,}){0,2}'
        r'(?:,\s*(?:[A-Z]\.\s*)+)?'
        r')?'
        r',?\s*(?:19|20)\d{2}[a-z]?'
        r')'
        r'(?:\s*;\s*[A-Z][A-Za-z\-][^;)]{0,100},?\s*(?:19|20)\d{2}[a-z]?){0,8}'
        r'\)|'
        r'\('
        r'[A-Z][A-Za-z\-][^()]{8,160}'
        r'\(\s*(?:19|20)\d{2}[a-z]?\s*\)?'
        r'\.?'
      ),
      (m) => '$hintOpen${m.group(0)}$hintClose',
    );
    return s;
  }

  /// Turn `[1⁴]`, `[¹⁴]`, and split bold `<<CITE:1>><<CITE:4>>` back into 14.
  /// Does not flatten math exponents like `R²` / `mol²` in the surrounding text.
  static String normalizeNumberedCiteDigits(String text) {
    var t = text.replaceAllMapped(
      RegExp(r'\[([^\[\]]{1,24})\]'),
      (m) => '[${asciiDigits(m.group(1)!).replaceAll(RegExp(r'\s+'), '')}]',
    );
    t = t.replaceAllMapped(
      RegExp('$hintOpen([^$hintClose]{1,24})$hintClose'),
      (m) => '$hintOpen${asciiDigits(m.group(1)!)}$hintClose',
    );
    t = t.replaceAllMapped(
      RegExp(r'\[(\d(?:\s+\d){1,2})\]'),
      (m) => '[${m.group(1)!.replaceAll(RegExp(r'\s+'), '')}]',
    );
    t = t.replaceAllMapped(
      RegExp('$hintOpen(\\d)$hintClose(?:$hintOpen(\\d)$hintClose)+'),
      (m) {
        final digits = [
          for (final hit in RegExp('$hintOpen(\\d)$hintClose').allMatches(m.group(0)!))
            hit.group(1)!,
        ].join();
        if (digits.length < 2 || digits.length > 3) return m.group(0)!;
        return '$hintOpen$digits$hintClose';
      },
    );
    t = t.replaceAllMapped(
      RegExp('\\[$hintOpen(\\d{1,3})$hintClose\\]'),
      (m) => '$hintOpen${m.group(1)}$hintClose',
    );
    // Word often bolds only the last digit of [14] → [1<<CITE:4>>]
    t = t.replaceAllMapped(
      RegExp('\\[(\\d{1,2})\\s*$hintOpen(\\d{1,2})$hintClose\\s*\\]'),
      (m) => '[${m.group(1)}${m.group(2)}]',
    );
    t = t.replaceAllMapped(
      RegExp('\\[(\\d{1,2})\\s*$hintOpen(\\d{1,2})$hintClose'),
      (m) => '[${m.group(1)}${m.group(2)}]',
    );
    return t;
  }

  static String asciiDigits(String input) {
    const map = {
      '⁰': '0',
      '¹': '1',
      '²': '2',
      '³': '3',
      '⁴': '4',
      '⁵': '5',
      '⁶': '6',
      '⁷': '7',
      '⁸': '8',
      '⁹': '9',
    };
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (final c in input.split('')) {
      buffer.write(map[c] ?? c);
    }
    return buffer.toString();
  }

  static String toSuperscriptDigits(String input) {
    const map = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '-': '⁻',
    };
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (final c in asciiDigits(input).split('')) {
      buffer.write(map[c] ?? c);
    }
    return buffer.toString();
  }

  static bool _hasBracketCiteSoon(String text, int from) {
    if (from >= text.length) return false;
    final window = text.substring(
      from,
      from + 48 > text.length ? text.length : from + 48,
    );
    final clause = window.contains('.') ? window.split('.').first : window;
    final bracket = RegExp(
      '\\[\\d{1,3}\\]|\\{\\{cite:|$hintOpen\\d{1,3}',
    ).firstMatch(clause);
    if (bracket == null) return false;
    final between = clause.substring(0, bracket.start);
    // "(Author, Year) and [n]" are two works. "Author (Year) … [n]" in the
    // same clause is one.
    if (RegExp(r'\b(?:and|&)\b|;').hasMatch(between)) return false;
    return true;
  }

  static String stripHints(String text) {
    if (text.isEmpty || !text.contains(hintOpen)) return text;
    return text.replaceAll(hintOpen, '').replaceAll(hintClose, '');
  }

  static ({
    List<PublishReference> references,
    List<ManuscriptBlock> bodyBlocks,
  }) linkParsed({
    required List<PublishReference> references,
    required List<ManuscriptBlock> bodyBlocks,
    bool numbersOnly = false,
  }) {
    final refs = dedupe(references);
    if (refs.isEmpty) {
      return (references: references, bodyBlocks: bodyBlocks);
    }
    final index = _RefIndex(refs);
    return (
      references: refs,
      bodyBlocks: _linkDocumentBlocks(
        bodyBlocks,
        index,
        numbersOnly: numbersOnly,
      ),
    );
  }

  /// [n] → bibliography item n. When [numbersOnly] is true, names already in
  /// the sentence are left untouched (APA from a numbered file).
  static PublishManuscript linkManuscript(
    PublishManuscript manuscript, {
    bool numbersOnly = false,
  }) {
    if (manuscript.references.isEmpty) return manuscript;
    final refs = dedupe(manuscript.references);
    final index = _RefIndex(refs);
    return manuscript.copyWith(
      references: refs,
      abstractText: _linkText(
        manuscript.abstractText,
        index,
        numbersOnly: numbersOnly,
      ),
      body: _linkText(manuscript.body, index, numbersOnly: numbersOnly),
      bodyBlocks: _linkDocumentBlocks(
        manuscript.bodyBlocks,
        index,
        numbersOnly: numbersOnly,
      ),
    );
  }

  static List<ManuscriptBlock> _linkDocumentBlocks(
    List<ManuscriptBlock> blocks,
    _RefIndex index, {
    bool numbersOnly = false,
  }) {
    final out = <ManuscriptBlock>[];
    var pastTitlePage = false;
    ManuscriptBlock? prev;
    for (final block in blocks) {
      if (!pastTitlePage && _startsBodyRegion(block)) {
        pastTitlePage = true;
      }
      if (!pastTitlePage) {
        if (RegExp(r'\((?:[^)]{0,160}\b(?:19|20)\d{2})').hasMatch(block.text)) {
          pastTitlePage = true;
        } else {
          out.add(block.copyWith(text: stripHints(block.text)));
          prev = out.last;
          continue;
        }
      }
      if (_isBareEquationNumber(block.text) &&
          (prev?.type == ManuscriptBlockType.equation ||
              CitationLinker.isEquationNumberContext(prev?.text ?? ''))) {
        out.add(block.copyWith(text: stripHints(block.text)));
        prev = out.last;
        continue;
      }
      out.add(
        _linkBlockRespectingFrontMatter(
          block,
          index,
          numbersOnly: numbersOnly,
        ),
      );
      prev = out.last;
    }
    return out;
  }

  static bool _isBareEquationNumber(String text) {
    final t = text.trim();
    return RegExp(r'^[\(\[]?\d{1,3}[\)\]]?\.?$').hasMatch(t);
  }

  static bool _startsBodyRegion(ManuscriptBlock block) {
    final t = block.text.trim();
    return RegExp(
      r'^(?:\d+\.?\s*)?(Abstract|Introduction|Background|الملخص|المقدمة)\b',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static ManuscriptBlock _linkBlockRespectingFrontMatter(
    ManuscriptBlock block,
    _RefIndex index, {
    bool numbersOnly = false,
  }) {
    if (block.type == ManuscriptBlockType.heading ||
        CitationStyleShapes.looksLikeSectionHeading(block.text)) {
      return block.copyWith(text: stripHints(block.text));
    }
    if (DocxScientificExtractor.isFrontMatterAuthorText(block.text)) {
      return block.copyWith(text: stripHints(block.text));
    }
    return _linkBlock(block, index, numbersOnly: numbersOnly);
  }

  static List<PublishReference> dedupe(List<PublishReference> refs) {
    if (refs.length < 2) return refs;
    final out = <PublishReference>[];
    final seen = <String>{};
    final seenNumber = <int>{};
    for (final ref in refs) {
      final n = ref.importedNumber ??
          PublishReference.numberFromImportedLine(ref.rawText);
      if (n != null) {
        if (seenNumber.add(n)) {
          out.add(ref);
          continue;
        }
        final prev = out.firstWhere(
          (r) =>
              (r.importedNumber ??
                  PublishReference.numberFromImportedLine(r.rawText)) ==
              n,
        );
        if (_sameNumberedWork(prev, ref)) continue;
        out.add(ref.copyWith(importedNumber: null, id: '${ref.id}_alt'));
        continue;
      }
      final doi = ref.doi.trim().toLowerCase();
      final raw =
          _normalizeRawKey(ref.rawText.isNotEmpty ? ref.rawText : ref.title);
      final work = _workKey(ref);
      final key = doi.isNotEmpty
          ? 'doi:$doi'
          : work.isNotEmpty
              ? 'work:$work'
              : 'raw:$raw';
      if (raw.length < 12 && doi.isEmpty && work.isEmpty) {
        out.add(ref);
        continue;
      }
      if (seen.add(key)) out.add(ref);
    }
    return out;
  }

  static bool _sameNumberedWork(PublishReference a, PublishReference b) {
    final da = a.doi.trim().toLowerCase();
    final db = b.doi.trim().toLowerCase();
    if (da.isNotEmpty && db.isNotEmpty) {
      return da.replaceAll(RegExp(r'[.,;]+$'), '') ==
          db.replaceAll(RegExp(r'[.,;]+$'), '');
    }
    final ka = _workKey(a);
    final kb = _workKey(b);
    if (ka.isNotEmpty && ka == kb) return true;
    final ra = _normalizeRawKey(a.rawText);
    final rb = _normalizeRawKey(b.rawText);
    if (ra.length >= 48 && rb.length >= 48) {
      return ra.substring(0, 48) == rb.substring(0, 48);
    }
    return ra == rb && ra.isNotEmpty;
  }

  static String _workKey(PublishReference ref) {
    final year = (ref.year.trim().isNotEmpty
            ? ref.year.trim()
            : RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(ref.rawText)?.group(1) ??
                '')
        .replaceAll(RegExp(r'[a-z]$'), '');
    if (year.length < 4) return '';
    final last = ref.authors.isNotEmpty
        ? ref.authors.first
            .split(',')
            .first
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z]'), '')
        : '';
    if (last.length < 3) return '';
    var title = ref.title.trim().toLowerCase();
    if (title.length < 8) {
      title = ref.rawText.toLowerCase().replaceAll(
            RegExp(r'^\[\d+\]\s*'),
            '',
          );
      title = title.replaceFirst(RegExp(r'^.*?\((?:19|20)\d{2}[a-z]?\)\.\s*'), '');
    }
    title = title.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    if (title.length > 48) title = title.substring(0, 48);
    if (title.length < 8) return '$last|$year';
    return '$last|$year|$title';
  }

  static String linkTextWithRefs(
    String text,
    List<PublishReference> refs, {
    bool numbersOnly = false,
  }) {
    if (text.isEmpty || refs.isEmpty) return text;
    return _linkText(
      text,
      _RefIndex(dedupe(refs)),
      numbersOnly: numbersOnly,
    );
  }

  static String _linkText(
    String text,
    _RefIndex index, {
    bool numbersOnly = false,
  }) {
    if (text.isEmpty || index.isEmpty) return text;
    text = AcademicText.westernDigits(text);
    text = normalizeNumberedCiteDigits(text);
    final out = StringBuffer();
    var i = 0;
    while (i < text.length) {
      if (text.startsWith('{{cite:', i)) {
        final end = text.indexOf('}}', i + 7);
        if (end > i) {
          out.write(text.substring(i, end + 2));
          i = end + 2;
          continue;
        }
      }

      if (text.startsWith(hintOpen, i)) {
        final end = text.indexOf(hintClose, i + hintOpen.length);
        if (end > i) {
          final inner = text.substring(i + hintOpen.length, end);
          final before = text.substring(0, i);
          if (numbersOnly) {
            out.write(
              _resolveHintNumbersOnly(inner, index, before: before) ?? inner,
            );
          } else {
            out.write(_resolveHint(inner, index, before: before) ?? inner);
          }
          i = end + hintClose.length;
          continue;
        }
      }

      final bracket = _matchBracketCite(text, i);
      if (bracket != null) {
        final markers = _markersForNumbers(
              bracket.numbers,
              index,
              before: text.substring(0, i),
            ) ??
            bracket.raw;
        out.write(markers);
        i = bracket.end;
        if (_needsSpaceAfterCite(text, i, markers)) out.write(' ');
        continue;
      }

      if (numbersOnly) {
        out.write(text[i]);
        i++;
        continue;
      }

      final paren = _matchParenAuthorDate(text, i);
      if (paren != null && !_hasBracketCiteSoon(text, paren.end)) {
        final markers = _markersForAuthorDates(paren.parts, index);
        if (markers != null) {
          out.write(markers);
          i = paren.end;
          continue;
        }
        // Unresolved group: keep scanning inside instead of skipping it.
      }

      final orphan = _matchOrphanAuthorYear(text, i);
      if (orphan != null && !_hasBracketCiteSoon(text, orphan.end)) {
        final markers = _markersForAuthorDates(orphan.parts, index);
        if (markers != null) {
          out.write(markers);
          i = orphan.end;
          continue;
        }
      }

      final narrative = _matchNarrative(text, i, index);
      if (narrative != null && !_hasBracketCiteSoon(text, narrative.end)) {
        out.write(narrative.markers);
        i = narrative.end;
        if (i < text.length && RegExp(r'[A-Za-z0-9]').hasMatch(text[i])) {
          out.write(' ');
        }
        continue;
      }

      out.write(text[i]);
      i++;
    }
    return out.toString();
  }

  static ManuscriptBlock _linkBlock(
    ManuscriptBlock block,
    _RefIndex index, {
    bool numbersOnly = false,
  }) {
    return block.copyWith(
      text: _linkText(block.text, index, numbersOnly: numbersOnly),
      caption: block.caption == null
          ? null
          : _linkText(block.caption!, index, numbersOnly: numbersOnly),
    );
  }

  static String? _resolveHintNumbersOnly(
    String inner,
    _RefIndex index, {
    required String before,
  }) {
    final t = AcademicText.westernDigits(inner.trim());
    if (t.isEmpty) return null;
    final fromSuper = _fromSuperscriptDigits(t);
    final source = fromSuper ?? t;
    if (_isAffiliationMark(source, before)) return inner;
    if (looksLikeMathExponent(source, before) ||
        looksLikeMathExponent(t, before)) {
      return toSuperscriptDigits(asciiDigits(source));
    }
    if (CitationLinker.isEquationNumberContext(before)) return inner;
    final bracket = _matchBracketCite(
      source.startsWith('[') ? source : '[$source]',
      0,
    );
    if (bracket != null) {
      return _markersForNumbers(bracket.numbers, index, before: before);
    }
    if (RegExp(r'^\d{1,3}(?:\s*[,;–-]\s*\d{1,3})*$').hasMatch(source)) {
      return _markersForNumbers(_parseNumberList(source), index, before: before);
    }
    return inner;
  }

  static String? _resolveHint(
    String inner,
    _RefIndex index, {
    String before = '',
  }) {
    final t = AcademicText.westernDigits(inner.trim());
    if (t.isEmpty) return null;

    final fromSuper = _fromSuperscriptDigits(t);
    final source = fromSuper ?? t;
    if (_isAffiliationMark(source, before)) return inner;
    if (looksLikeMathExponent(source, before) ||
        looksLikeMathExponent(t, before)) {
      return toSuperscriptDigits(asciiDigits(source));
    }
    if (CitationLinker.isEquationNumberContext(before)) return inner;

    final bracket = _matchBracketCite(
      source.startsWith('[') ? source : '[$source]',
      0,
    );
    if (bracket != null &&
        bracket.end >=
            (source.startsWith('[') ? source.length : source.length + 2)) {
      return _markersForNumbers(bracket.numbers, index, before: before);
    }
    if (RegExp(r'^\d{1,3}(?:\s*[,;–-]\s*\d{1,3})*$').hasMatch(source)) {
      return _markersForNumbers(_parseNumberList(source), index, before: before);
    }

    final bracketAt = source.indexOf('[');
    if (bracketAt >= 0) {
      final nested = _matchBracketCite(source, bracketAt);
      if (nested != null) {
        return _markersForNumbers(nested.numbers, index, before: before);
      }
    }

    final stripped = source.replaceAll(RegExp(r'^\(|\)$'), '').trim();
    final parts = stripped
        .split(';')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty && parts.any((p) => _splitAuthorYear(p) != null)) {
      final markers = _markersForAuthorDates(parts, index);
      if (markers != null) return markers;
    }
    return _markersForAuthorNames(source, index);
  }

  static bool _isAffiliationMark(String source, String before) {
    final mark = source.replaceAll(RegExp(r'^\[|\]$'), '').trim();
    if (!RegExp(r'^\d{1,2}$').hasMatch(mark)) return false;
    final tail = before.length > 240 ? before.substring(before.length - 240) : before;
    if (CitationCues.affiliationNearby.hasMatch(tail)) {
      return true;
    }
    return false;
  }

  static _ParenHit? _matchOrphanAuthorYear(String text, int i) {
    if (i >= text.length || !RegExp(r'[A-Z]').hasMatch(text[i])) return null;
    if (i > 0) {
      final prev = text[i - 1];
      if (prev != ' ' && prev != ']' && prev != '}' && prev != '\n') return null;
    }
    final close = text.indexOf(')', i);
    if (close < 0 || close - i < 8 || close - i > 180) return null;
    final chunk = text.substring(i, close).trim();
    if (chunk.contains('(')) return null;
    if (_splitAuthorYear(chunk) == null) return null;
    return _ParenHit(
      raw: text.substring(i, close + 1),
      parts: [chunk],
      end: close + 1,
    );
  }

  static _BracketHit? _matchBracketCite(String text, int i) {
    if (i >= text.length || text[i] != '[') return null;
    if (DocxScientificExtractor.looksLikeAffiliationBracket(text, i)) {
      return null;
    }
    if (CitationLinker.isEquationNumberContext(text.substring(0, i))) {
      return null;
    }
    final close = text.indexOf(']', i + 1);
    if (close < 0 || close - i > 40) return null;
    final inner = asciiDigits(text.substring(i + 1, close).trim());
    if (inner.isEmpty) return null;
    if (!RegExp(r'^\d{1,3}(?:\s*[,;–-]\s*\d{1,3})*$').hasMatch(inner)) {
      return null;
    }
    final numbers = _parseNumberList(inner);
    if (numbers.isEmpty) return null;
    return _BracketHit(raw: text.substring(i, close + 1), numbers: numbers, end: close + 1);
  }

  static _ParenHit? _matchParenAuthorDate(String text, int i) {
    if (i >= text.length || text[i] != '(') return null;
    final span = _parenCiteSpan(text, i);
    if (span == null) return null;
    var inner = text.substring(i + 1, span.close).trim();
    if (inner.isEmpty) return null;
    inner = inner.replaceAllMapped(
      RegExp(r'\(((?:19|20)\d{2})[a-z]?\)'),
      (m) => m.group(1)!,
    );
    inner = inner.replaceAllMapped(
      RegExp(r'\(\s*((?:19|20)\d{2})[a-z]?\s*$'),
      (m) => m.group(1)!,
    );
    if (RegExp(r'^(?:19|20)\d{2}[a-z]?$').hasMatch(inner)) return null;
    if (RegExp(r'^[\d\s.<>=%,;+×xX/−-]+$').hasMatch(inner)) return null;

    final parts = inner
        .split(';')
        .map((p) => p.trim().replaceAll(RegExp(r'[.]+$'), ''))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    final parsed = [for (final p in parts) _splitAuthorYear(p)];
    if (parsed.every((p) => p == null)) return null;
    return _ParenHit(
      raw: text.substring(i, span.end),
      parts: parts,
      end: span.end,
    );
  }

  /// Nested `(Author (Year)` and long multi-cites: (A Year; B et al. Year).
  ///
  /// Must stop at THIS citation group. Scanning to the last year in the
  /// paragraph would swallow the whole Introduction and miss every cite.
  static ({int close, int end})? _parenCiteSpan(String text, int i) {
    var depth = 0;
    var lastYearEnd = -1;
    final limit = i + 480 > text.length ? text.length : i + 480;
    for (var j = i; j < limit; j++) {
      final ch = text[j];
      if (ch == '(') {
        depth++;
        continue;
      }
      if (ch == ')') {
        depth--;
        if (depth == 0) {
          return (close: j, end: j + 1);
        }
        // Unclosed outer: (Author … (Year). NextSentence
        if (depth == 1 && lastYearEnd > i) {
          var end = j + 1;
          if (end < text.length && text[end] == '.') end++;
          if (end >= text.length || text[end] == ' ' || text[end] == '\n') {
            return (close: j, end: end);
          }
        }
        continue;
      }
      if (j + 4 <= text.length &&
          RegExp(r'^(?:19|20)\d{2}').hasMatch(text.substring(j, j + 4))) {
        lastYearEnd = j + 4;
        if (depth != 1) continue;
        var peek = j + 4;
        while (peek < text.length &&
            (text[peek] == ' ' || text[peek] == '.' || text[peek] == ',')) {
          peek++;
        }
        if (peek >= text.length) continue;
        if (text[peek] == ';' ||
            text[peek] == ')' ||
            text[peek] == '(' ||
            _continuesAuthorList(text, peek)) {
          continue;
        }
        if (_looksLikeSentenceStart(text, peek)) {
          var end = j + 4;
          if (end < text.length && text[end] == '.') end++;
          return (close: lastYearEnd, end: end);
        }
      }
    }
    if (lastYearEnd > i && depth > 0) {
      final inner = text.substring(i + 1, lastYearEnd);
      if (RegExp(r'\.\s+[A-Z]').hasMatch(inner)) return null;
      var end = lastYearEnd;
      if (end < text.length && text[end] == '.') end++;
      return (close: lastYearEnd, end: end);
    }
    return null;
  }

  static bool _continuesAuthorList(String text, int k) {
    if (k >= text.length) return false;
    final rest = text.substring(k);
    if (RegExp(r'^(et\s+al|and|&)\b', caseSensitive: false).hasMatch(rest)) {
      return true;
    }
    // Next author–year inside the same parentheses: Surname, Given…
    if (RegExp(
      r'^[A-Z][A-Za-z\-]{1,}\s*,',
    ).hasMatch(rest)) {
      return true;
    }
    if (RegExp(
      r'^[A-Z][A-Za-z\-]{1,}(?:\s+et\s+al|\s+and\s+[A-Z])',
      caseSensitive: false,
    ).hasMatch(rest)) {
      return true;
    }
    if (RegExp(r'^[A-Z]{2,8}(?:\s+(?:19|20)\d{2}|\.)').hasMatch(rest)) {
      return true;
    }
    return false;
  }

  static bool _looksLikeSentenceStart(String text, int k) {
    if (k >= text.length) return false;
    return RegExp(
      r'^(The|This|These|Those|That|It|Its|Many|Most|However|'
      r'Therefore|Moreover|Furthermore|Although|Because|While|'
      r'Introduction|Abstract|According|Figure|Table)\b',
      caseSensitive: false,
    ).hasMatch(text.substring(k));
  }

  static _NarrativeHit? _matchNarrative(String text, int i, _RefIndex index) {
    if (i > 0 && RegExp(r'[A-Za-z]').hasMatch(text[i - 1])) return null;
    final m = _narrativeCite.matchAsPrefix(text, i);
    if (m == null) return null;
    final name = m.group(1)!;
    final year = m.group(2)!;
    if (_isBlocked(name)) return null;
    final ref = index.byAuthorYear(name, year);
    if (ref == null) return null;
    // Keep "Author (Year)" from the file; the marker becomes [n] after it.
    return _NarrativeHit(
      markers: '${m.group(0)} ${ManuscriptCitationHelperMarker.wrap(ref.id)}',
      end: m.end,
    );
  }

  static String? _markersForNumbers(
    List<int> numbers,
    _RefIndex index, {
    String before = '',
  }) {
    if (numbers.isEmpty) return null;
    final parts = <String>[];
    var linked = 0;
    for (final n in numbers) {
      // `[n]` is always bibliography item n from the imported list.
      // Never replace it with an author-year guess sitting next to it.
      final ref = index.byOriginalNumber(n);
      if (ref == null) {
        parts.add('[$n]');
        continue;
      }
      linked++;
      parts.add(ManuscriptCitationHelperMarker.wrap(ref.id));
    }
    if (linked == 0) return null;
    return parts.join(', ');
  }

  static bool _needsSpaceAfterCite(String text, int i, String replacement) {
    if (i >= text.length || replacement.isEmpty) return false;
    if (replacement.endsWith(' ')) return false;
    final next = text[i];
    return RegExp(r'[A-Za-z]').hasMatch(next);
  }

  static String? _markersForAuthorDates(List<String> parts, _RefIndex index) {
    final ids = <String>[];
    for (final part in parts) {
      final parsed = _splitAuthorYear(part);
      if (parsed == null || _isBlocked(parsed.$1)) continue;
      final ref = index.byAuthorYear(parsed.$1, parsed.$2) ??
          index.byLastNames(
            CitationStyleShapes.lastNamesFromCitation(parsed.$1),
            year: parsed.$2,
          );
      // Do not drop a sibling cite in `(A, 2025; B, 2024)` if B is missing.
      if (ref == null) return null;
      ids.add(ref.id);
    }
    if (ids.isEmpty) return null;
    return ids.map(ManuscriptCitationHelperMarker.wrap).join(', ');
  }

  static String? _markersForAuthorNames(String raw, _RefIndex index) {
    if (CitationStyleShapes.looksLikeSectionHeading(raw)) return null;
    final names = CitationStyleShapes.lastNamesFromCitation(raw);
    if (names.isEmpty || names.any(_isBlocked)) return null;
    final year = CitationStyleShapes.yearFromCitation(raw);
    final ref = index.byLastNames(names, year: year);
    if (ref == null) return null;
    return ManuscriptCitationHelperMarker.wrap(ref.id);
  }

  static List<int> _parseNumberList(String inner) {
    final out = <int>[];
    for (final chunk in inner.split(RegExp(r'[,;]'))) {
      final piece = chunk.trim();
      if (piece.isEmpty) continue;
      final range = RegExp(r'^(\d{1,3})\s*[–-]\s*(\d{1,3})$').firstMatch(piece);
      if (range != null) {
        final a = int.parse(range.group(1)!);
        final b = int.parse(range.group(2)!);
        if (b < a || b - a > 30) continue;
        for (var n = a; n <= b; n++) {
          out.add(n);
        }
        continue;
      }
      final n = int.tryParse(piece);
      if (n != null && n > 0 && n < 1000) out.add(n);
    }
    return out;
  }

  static (String, String)? _splitAuthorYear(String part) {
    var s = part.trim();
    s = s.replaceAll(RegExp(r'\((?:[Ee]ds?\.?)\)'), ' ');
    s = s.replaceAll(RegExp(r'\b[Ee]ds?\.?\b'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r'^\(+|\)+$'), '');
    final strict = _authorDatePart.firstMatch(s);
    if (strict != null) return (strict.group(1)!, strict.group(2)!);

    final yearM = RegExp(r'((?:19|20)\d{2})[a-z]?\s*\.?$').firstMatch(s);
    if (yearM == null) return null;
    var authors = s.substring(0, yearM.start).trim().replaceAll(
          RegExp(r'[.,;:]+$'),
          '',
        );
    if (authors.length < 2 || authors.length > 180) return null;
    if (_looksLikeProse(authors)) return null;
    if (!RegExp(r'[A-Za-z]{2,}').hasMatch(authors)) return null;
    return (authors, yearM.group(1)!);
  }

  static bool _looksLikeProse(String authors) {
    return authors.length > 48 &&
        RegExp(
          r'\b(the|this|these|those|that|which|was|were|have|has|using|with)\b',
          caseSensitive: false,
        ).hasMatch(authors);
  }

  static String? _fromSuperscriptDigits(String t) {
    const map = {
      '⁰': '0',
      '¹': '1',
      '²': '2',
      '³': '3',
      '⁴': '4',
      '⁵': '5',
      '⁶': '6',
      '⁷': '7',
      '⁸': '8',
      '⁹': '9',
    };
    if (!t.split('').every(map.containsKey)) return null;
    return t.split('').map((c) => map[c]!).join();
  }

  static String _normalizeRawKey(String raw) {
    return AcademicText.westernDigits(raw)
        .replaceFirst(RegExp(r'^\[\d+\]\s*'), '')
        .replaceFirst(RegExp(r'^\d+[.)]\s+'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isBlocked(String authorPart) {
    final token = authorPart
        .replaceAll(RegExp(r'\s+et\s+al\.?', caseSensitive: false), '')
        .split(RegExp(r'\s+(?:&|and)\s+', caseSensitive: false))
        .first
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"['\-]"), '');
    return _blocklist.contains(token);
  }

  static final _authorDatePart = RegExp(
    r'^('
    r'[\p{Lu}][\p{L}\-]+(?:\s+[\p{Lu}][\p{L}\-]+){0,2}'
    r'(?:,\s*(?:[\p{Lu}]\.\s*)+)?'
    r'(?:\s+et\s+al\.?)?'
    r'(?:'
    r'\s*,\s*[\p{Lu}][\p{L}\-]+(?:\s+[\p{Lu}][\p{L}\-]+){0,2}'
    r'(?:,\s*(?:[\p{Lu}]\.\s*)+)?'
    r')*'
    r'(?:'
    r'\s*,?\s*(?:&|and)\s+[\p{Lu}][\p{L}\-]+(?:\s+[\p{Lu}][\p{L}\-]+){0,2}'
    r'(?:,\s*(?:[\p{Lu}]\.\s*)+)?'
    r')?'
    r')'
    r',?\s*((?:19|20)\d{2})[a-z]?$',
    caseSensitive: false,
    unicode: true,
  );

  /// Narrative: `Author et al. (Year)`, `Author and Author (Year)`.
  static final _narrativeCite = RegExp(
    r'('
    r'[\p{Lu}][\p{L}\-]{1,}'
    r'(?:'
    r'(?:,\s*[\p{Lu}][\p{L}\-]{1,}){1,6}'
    r'(?:,?\s+(?:and|&)\s+[\p{Lu}][\p{L}\-]{1,})'
    r'|'
    r'(?:,\s*(?:[\p{Lu}]\.\s*)+){1,4}'
    r'(?:,?\s+(?:and|&)\s+(?:[\p{Lu}]\.\s*)*[\p{Lu}][\p{L}\-]{1,})'
    r'|'
    r'(?:\s+et\s+al\.?)'
    r'|'
    r'(?:\s+(?:and|&)\s+[\p{Lu}][\p{L}\-]{1,}(?:\s+[\p{Lu}][\p{L}\-]{1,}){0,2})'
    r')?'
    r')'
    r'\s+\(((?:19|20)\d{2})[a-z]?\)',
    unicode: true,
  );

  static const _blocklist = CitationCues.notAuthorSurnames;
}

/// Tiny helper so [CitationLinker] does not import the Flutter citation helper.
class ManuscriptCitationHelperMarker {
  static String wrap(String refId) => '{{cite:$refId}}';
}

class _RefIndex {
  final List<PublishReference> refs;
  final BibliographyMatch match;

  _RefIndex(this.refs) : match = BibliographyMatch(refs);

  bool get isEmpty => refs.isEmpty;

  PublishReference? byOriginalNumber(int n) => match.byNumber(n);

  PublishReference? byAuthorYear(String authorPart, String year) =>
      match.byAuthorYear(authorPart, year);

  PublishReference? byLastNames(List<String> names, {String? year}) =>
      match.byLastNames(names, year: year);
}

class _BracketHit {
  final String raw;
  final List<int> numbers;
  final int end;
  const _BracketHit({required this.raw, required this.numbers, required this.end});
}

class _ParenHit {
  final String raw;
  final List<String> parts;
  final int end;
  const _ParenHit({required this.raw, required this.parts, required this.end});
}

class _NarrativeHit {
  final String markers;
  final int end;
  const _NarrativeHit({required this.markers, required this.end});
}
