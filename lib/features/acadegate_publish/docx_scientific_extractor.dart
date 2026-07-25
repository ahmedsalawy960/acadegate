import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'publish_models.dart';

enum TitlePageSegmentKind { equation, title, authors, body }

class TitlePageSegment {
  final String text;
  final TitlePageSegmentKind kind;

  const TitlePageSegment({required this.text, required this.kind});

  bool get isEquation => kind == TitlePageSegmentKind.equation;
  bool get isTitle => kind == TitlePageSegmentKind.title;
  bool get isAuthors => kind == TitlePageSegmentKind.authors;
}

class ScientificTextSegment {
  final String text;
  final bool isEquation;

  const ScientificTextSegment({required this.text, required this.isEquation});
}

/// Extracts equations, chemical notation, and embedded visuals from Word XML.
class DocxScientificExtractor {
  DocxScientificExtractor._();

  static bool isEquationPlaceholder(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (RegExp(r'\.{4,}').hasMatch(t)) return true;
    if (RegExp(r'=\s*[\.\u00B7·…_]{2,}').hasMatch(t)) return true;
    if (RegExp(r'[\u00B7·…]{6,}').hasMatch(t)) return true;
    if (RegExp(r'^%\s*\w+\s*=').hasMatch(t)) return true;
    return false;
  }

  static bool isEquationFragment(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (isEquationPlaceholder(t)) return true;
    if (RegExp(r'^%\s*\w+', caseSensitive: false).hasMatch(t)) return true;
    if (RegExp(r'determined\s+%', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'Difference in wt\.', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'\bW[0-9٠-٩]+\s*=').hasMatch(t) && t.length < 180) {
      return true;
    }
    if (t.length < 90 &&
        RegExp(r'=\s*\(?\s*W[0-9٠-٩]').hasMatch(t) &&
        !RegExp(r'\b(method|sample|used|acid)\b', caseSensitive: false)
            .hasMatch(t)) {
      return true;
    }
    return false;
  }

  static bool isPaperTitle(String text) {
    final t = text.trim();
    if (t.length < 25 || t.length > 320) return false;
    if (isEquationFragment(t) || isEquationPlaceholder(t)) return false;
    if (RegExp(r'@|corresponding author|University|Department|Faculty',
            caseSensitive: false)
        .hasMatch(t)) {
      return false;
    }
    if (RegExp(
      r'\b(Analysis|Profile|Study|Characterization|Composition|Investigation|Review)\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    final words = t.split(RegExp(r'\s+'));
    if (words.length >= 7 &&
        RegExp(r'^[A-Z]').hasMatch(t) &&
        !RegExp(r'=\s*[\.\d]').hasMatch(t.substring(0, t.length.clamp(0, 40)))) {
      return true;
    }
    return false;
  }

  static bool isAuthorsBlock(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    return RegExp(
      r'@|corresponding author|\*Corresponding|University|Department|Faculty|\d+\*?\s*,',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static bool isOleScientificObject(XmlElement element) {
    final tag = element.localName;
    if (tag != 'object' && tag != 'OLEObject') return false;
    for (final ole in element.findAllElements('*')) {
      if (ole.localName != 'OLEObject') continue;
      final progId = _attr(ole, 'ProgID').toLowerCase();
      if (progId.contains('equation') ||
          progId.contains('mathtype') ||
          progId.contains('chemdraw') ||
          progId.contains('chem') ||
          progId.contains('msoffice') && progId.contains('equation')) {
        return true;
      }
    }
    // Pasted pictures (chromatograms, etc.) use w:object + VML preview — not equations.
    return false;
  }

  static bool paragraphHasEquationField(XmlElement paragraph) {
    for (final el in paragraph.findAllElements('*')) {
      if (el.localName == 'instrText') {
        final instr = el.innerText.toLowerCase();
        if (instr.contains(' eq ') ||
            instr.startsWith('eq ') ||
            instr.contains('equation')) {
          return true;
        }
      }
      if (el.localName == 'fldSimple') {
        final instr = _attr(el, 'instr').toLowerCase();
        if (instr.contains('eq') || instr.contains('equation')) return true;
      }
    }
    return false;
  }

  static String formatChemicalFormula(String text) {
    if (text.isEmpty) return text;
    var out = text.replaceAllMapped(
      RegExp(r'([A-Z][a-z]?)([0-9٠-٩]+)'),
      (m) => '${m.group(1)}${_toSubscriptUnicode(m.group(2)!)}',
    );
    out = formatVariableSubscripts(out);
    return out;
  }

  static String formatVariableSubscripts(String text) {
    return text.replaceAllMapped(
      RegExp(r'\bW([0-9٠-٩]+)\b'),
      (m) => 'W${_toSubscriptUnicode(m.group(1)!)}',
    );
  }

  static String cleanScientificText(String text) {
    var out = text
        .replaceAll(RegExp(r'\.{4,}'), ' ')
        .replaceAll(RegExp(r'[\u00B7·…_]{4,}'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    out = formatChemicalFormula(out);
    return out;
  }

  /// Pull paper title from merged title-page text (never equation debris).
  static String? extractPaperTitle(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (isPaperTitle(normalized)) return normalized;

    final patterns = [
      RegExp(
        r'((?:Comprehensive|[A-Z][A-Za-z\-]+(?:\s+[A-Za-z\-]+){4,35})\s+(?:[\w\s,\-()]+)?(?:Analysis|Profile|Study|Characterization|Composition)[\w\s,\-()]*(?:Spectrometry|Chromatography|Spectroscopy|Microscopy)?[\w\s,\-()]*)',
        caseSensitive: false,
      ),
      RegExp(
        r'([A-Z][A-Za-z\-]+(?:\s+[A-Za-z\-]+){5,40}(?:using|for|of)\s+[A-Za-z][\w\s,\-()]{8,120})',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match == null) continue;
      final candidate = match.group(1)!.trim();
      if (isPaperTitle(candidate)) return candidate;
    }
    return null;
  }

  static String? extractAuthorsBlock(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = RegExp(
      r'([A-Z][A-Za-z\-]+(?:\s+[A-Z]\.?)?\s+[A-Za-z\-]+(?:\s+\d+\*?,?\s*)+(?:and\s+)?[A-Za-z\s\d\*\-]+?(?=\d+\s*[A-Za-z]+(?:\s+Department|\s+University)|\*Corresponding|Corresponding author))',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match != null) return match.group(1)!.trim();

    final emailIdx = normalized.indexOf('@');
    if (emailIdx > 20) {
      final start = normalized.lastIndexOf('.', emailIdx - 5);
      final sliceStart = (start > 0 ? start + 1 : 0).clamp(0, normalized.length);
      final end = normalized.indexOf(';', emailIdx);
      final sliceEnd = end > 0 ? end : normalized.length;
      final block = normalized.substring(sliceStart, sliceEnd).trim();
      if (block.length > 15) return block;
    }
    return null;
  }

  static List<TitlePageSegment> decomposeTitlePageText(String raw) {
    var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return const [];

    final segments = <TitlePageSegment>[];

    while (text.isNotEmpty) {
      final leadingEq = RegExp(
        r'^(%\s*\w+[\s\S]{0,80}?(?:[٠-٩0-9]|\.{2,}))',
        caseSensitive: false,
      ).firstMatch(text);
      if (leadingEq != null) {
        segments.add(TitlePageSegment(
          text: leadingEq.group(1)!.trim(),
          kind: TitlePageSegmentKind.equation,
        ));
        text = text.substring(leadingEq.end).trim();
        continue;
      }
      break;
    }

    final title = extractPaperTitle(text);
    if (title != null) {
      segments.add(TitlePageSegment(
        text: title,
        kind: TitlePageSegmentKind.title,
      ));
      text = text.replaceFirst(title, '').trim();
    }

    final authors = extractAuthorsBlock(text);
    if (authors != null) {
      segments.add(TitlePageSegment(
        text: authors,
        kind: TitlePageSegmentKind.authors,
      ));
      text = text.replaceFirst(authors, '').trim();
    }

    if (text.isNotEmpty) {
      if (isEquationFragment(text)) {
        segments.add(TitlePageSegment(
          text: text,
          kind: TitlePageSegmentKind.equation,
        ));
      } else if (isAuthorsBlock(text)) {
        segments.add(TitlePageSegment(
          text: text,
          kind: TitlePageSegmentKind.authors,
        ));
      } else {
        segments.add(TitlePageSegment(
          text: text,
          kind: TitlePageSegmentKind.body,
        ));
      }
    }

    return segments;
  }

  static bool needsScientificSplit(String text) {
    final t = text.trim();
    if (t.length < 80) return isEquationFragment(t);
    return RegExp(
      r'determined\s+%|Difference in wt\.|% \w+\s*=.*(?:A modified|The |In this |Concentrated )',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static List<ScientificTextSegment> splitRunOnScientificParagraph(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return const [];

    final splitPattern = RegExp(
      r'(?=(?:determined\s+%|Difference in wt\.|% \w+\s*=|\bW[0-9٠-٩]+\s*=|A modified |The sample|The |In this |Concentrated |After ))',
      caseSensitive: false,
    );

    final rawParts = t.split(splitPattern).where((p) => p.trim().isNotEmpty);
    final out = <ScientificTextSegment>[];

    for (final part in rawParts) {
      final p = part.trim();
      if (p.isEmpty) continue;
      out.add(ScientificTextSegment(
        text: cleanScientificText(p),
        isEquation: isEquationFragment(p),
      ));
    }

    return out.isEmpty
        ? [ScientificTextSegment(text: cleanScientificText(t), isEquation: false)]
        : out;
  }

  /// Split a long merged paragraph into section headings + body parts.
  static List<ManuscriptBlock> splitTextBySectionHeadings(
    String text,
    String Function() nextId,
  ) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    const sectionNames =
        'Abstract|Keywords?|Introduction|Experimental|Background|'
        'Materials\\s+and\\s+Methods|Materials|Methods|Results|Discussion|'
        'Conclusions?|Acknowledgments?|References?|'
        'الملخص|المقدمة|الخلفية|التجريبي|المنهجية?|المواد والطرق|'
        'النتائج|المناقشة|الخاتمة|الاستنتاجات?|المراجع';

    final headingRe = RegExp(
      r'(?:^|\n)\s*(?:\d+\.?\s*)?(' + sectionNames + r')\s*:?\s*(?=\n|$)',
      caseSensitive: false,
      multiLine: true,
    );

    final matches = headingRe.allMatches(trimmed).toList();
    if (matches.isEmpty) {
      final lines = trimmed.split('\n');
      if (lines.length > 1 &&
          _isKnownSectionHeading(lines.first.trim())) {
        return [
          ManuscriptBlock(
            id: nextId(),
            type: ManuscriptBlockType.heading,
            text: _normalizeSectionHeading(lines.first),
          ),
          if (lines.sublist(1).join('\n').trim().isNotEmpty)
            ManuscriptBlock(
              id: nextId(),
              type: ManuscriptBlockType.paragraph,
              text: lines.sublist(1).join('\n').trim(),
            ),
        ];
      }
      return [
        ManuscriptBlock(
          id: nextId(),
          type: ManuscriptBlockType.paragraph,
          text: trimmed,
        ),
      ];
    }

    final out = <ManuscriptBlock>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        final before = trimmed.substring(cursor, m.start).trim();
        if (before.isNotEmpty) {
          out.add(ManuscriptBlock(
            id: nextId(),
            type: ManuscriptBlockType.paragraph,
            text: before,
          ));
        }
      }
      final heading = _normalizeSectionHeading(m.group(1)!);
      out.add(ManuscriptBlock(
        id: nextId(),
        type: ManuscriptBlockType.heading,
        text: heading,
      ));
      cursor = m.end;
    }
    final tail = trimmed.substring(cursor).trim();
    if (tail.isNotEmpty) {
      out.add(ManuscriptBlock(
        id: nextId(),
        type: ManuscriptBlockType.paragraph,
        text: tail,
      ));
    }
    return out;
  }

  static bool _isKnownSectionHeading(String line) {
    if (line.length > 80) return false;
    final t = line.trim();
    return RegExp(
      r'^(?:\d+\.?\s*)?(Abstract|Keywords?|Introduction|Experimental|Background|'
      r'Materials(\s+and\s+Methods)?|Methods|Results|Discussion|Conclusions?|'
      r'References?|الملخص|المقدمة|الخلفية|التجريبي|المنهجية?|النتائج|'
      r'المناقشة|الخاتمة|الاستنتاجات?|المراجع)\s*:?\s*$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static String _normalizeSectionHeading(String raw) {
    var h = raw.trim().replaceAll(RegExp(r'\s*:+\s*$'), '');
    if (h.isEmpty) return raw.trim();
    final lower = h.toLowerCase();
    if (lower == 'keywords' || lower.startsWith('keyword')) return 'Keywords';
    if (RegExp(r'^abstract').hasMatch(lower) || h.contains('الملخص')) {
      return 'Abstract';
    }
    if (RegExp(r'^(introduction|background)').hasMatch(lower) ||
        h.contains('المقدمة') ||
        h.contains('الخلفية')) {
      return 'Introduction';
    }
    if (RegExp(r'^(experimental|materials|methods?)').hasMatch(lower) ||
        h.contains('التجريبي') ||
        h.contains('المنهج') ||
        h.contains('المواد')) {
      return 'Experimental';
    }
    if (RegExp(r'^results?').hasMatch(lower) || h.contains('النتائج')) {
      return 'Results';
    }
    if (RegExp(r'^discussion').hasMatch(lower) || h.contains('المناقشة')) {
      return 'Discussion';
    }
    if (RegExp(r'^conclusions?').hasMatch(lower) ||
        h.contains('الخاتمة') ||
        h.contains('الاستنتاج')) {
      return 'Conclusion';
    }
    if (RegExp(r'^references?').hasMatch(lower) || h.contains('المراجع')) {
      return 'References';
    }
    return h[0].toUpperCase() + h.substring(1);
  }

  static List<String> indexMediaPool(
    Archive archive,
    String? Function(ArchiveFile file) fileToDataUri,
  ) {
    final out = <String>[];
    final files = archive.files
        .where((f) =>
            f.isFile &&
            f.name.replaceAll('\\', '/').toLowerCase().startsWith('word/media/'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final file in files) {
      final uri = fileToDataUri(file);
      if (uri != null && uri.isNotEmpty) out.add(uri);
    }
    return out;
  }

  static int? structureColumnIndex(List<String> headerRow) {
    for (var i = 0; i < headerRow.length; i++) {
      final h = headerRow[i].trim().toLowerCase();
      if (h == 'structure' ||
          h.contains('structure') ||
          h.contains('البنية') ||
          h.contains('تركيب')) {
        return i;
      }
    }
    return null;
  }

  static ({
    List<List<String>> rowCellImages,
    Set<String> usedUris,
  }) fillStructureColumnFromMediaPool({
    required List<List<String>> rows,
    required List<List<String>> rowCellImages,
    required List<String> mediaPool,
    required Set<String> alreadyUsed,
  }) {
    if (rows.isEmpty || mediaPool.isEmpty) {
      return (rowCellImages: rowCellImages, usedUris: alreadyUsed);
    }

    final structCol = structureColumnIndex(rows.first);
    if (structCol == null) {
      return (rowCellImages: rowCellImages, usedUris: alreadyUsed);
    }

    int uriBytes(String uri) {
      if (!uri.startsWith('data:')) return 0;
      final comma = uri.indexOf(',');
      if (comma < 0) return 0;
      try {
        return base64Decode(uri.substring(comma + 1)).length;
      } catch (_) {
        return 0;
      }
    }

    // Small structure icons first — leave large chromatogram PNGs for figure recovery.
    final pool = mediaPool.where((u) => !alreadyUsed.contains(u)).toList()
      ..sort((a, b) => uriBytes(a).compareTo(uriBytes(b)));
    var poolIdx = 0;
    final used = Set<String>.from(alreadyUsed);
    final filled = rowCellImages.map((row) => List<String>.from(row)).toList();

    for (var r = 1; r < rows.length; r++) {
      if (structCol >= rows[r].length) continue;
      while (filled.length <= r) {
        filled.add(List.filled(rows[r].length, ''));
      }
      while (filled[r].length < rows[r].length) {
        filled[r].add('');
      }
      if (filled[r][structCol].isNotEmpty) continue;
      if (poolIdx >= pool.length) break;
      filled[r][structCol] = pool[poolIdx];
      used.add(pool[poolIdx]);
      poolIdx++;
    }

    return (rowCellImages: filled, usedUris: used);
  }

  static String _attr(XmlElement el, String name) {
    return el.getAttribute(name) ??
        el.getAttribute('w:$name') ??
        el.getAttribute('o:$name') ??
        el.getAttribute('r:$name') ??
        '';
  }

  static String _toSubscriptUnicode(String input) {
    const map = {
      '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
      '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
      '٠': '₀', '١': '₁', '٢': '₂', '٣': '₃', '٤': '₄',
      '٥': '₅', '٦': '₆', '٧': '₇', '٨': '₈', '٩': '₉',
      '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
      'a': 'ₐ', 'e': 'ₑ', 'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ',
      'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ',
      'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ',
      'v': 'ᵥ', 'x': 'ₓ',
    };
    return input.split('').map((c) => map[c] ?? map[c.toLowerCase()] ?? c).join();
  }
}
