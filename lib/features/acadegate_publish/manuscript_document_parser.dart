import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../core/firebase/callable_http_client.dart';
import '../../core/locale/app_translate.dart';
import 'academic_text.dart';
import 'bibliography_cite_aligner.dart';
import 'citation_cues.dart';
import 'citation_formatter.dart';
import 'citation_linker.dart';
import 'citation_style_shapes.dart';
import 'docx_list_numbering.dart';
import 'docx_scientific_extractor.dart';
import 'manuscript_image_session_cache.dart';
import 'manuscript_upload_service.dart';
import 'publish_models.dart';
import 'scholarly_layout.dart';
import 'table_grid.dart';

class ImportedDocumentImage {
  final int index;
  final String contentType;
  final Uint8List bytes;

  const ImportedDocumentImage({
    required this.index,
    required this.contentType,
    required this.bytes,
  });
}

enum _CiteImportRegion { frontMatter, body, bibliography }

class ManuscriptDocumentParser {
  ManuscriptDocumentParser._();

  /// Soft cap only — media (figures/tables/equations) is never dropped.
  static const maxImportedBlocks = 500;
  static const maxImportedReferences = 200;
  static const maxBlockTextLength = 120000;
  static const maxRawTextLength = 800;

  /// Keep imported pictures as data URIs for the same-session Word export.
  /// Firestore cannot store them — [stripDataUrisForPersistence] runs on save.
  /// Uploading first then re-fetching with raw `http.get` returns 403 / CORS 0
  /// and the formatted DOCX is written with no figures.
  static bool get skipImportImageUpload => true;

  /// Full cloud extract (text + images + tables) on all platforms.
  static bool get useLightCloudExtract => false;

  static Future<ManuscriptParseResult> parseFile({
    required Uint8List bytes,
    required String filename,
    bool allowCloud = false,
  }) async {
    final lower = filename.toLowerCase();

    if (lower.endsWith('.docx')) {
      final text = _extractDocxText(bytes);
      final blocks = _extractDocxBlocks(bytes);
      if (text.trim().length >= 40 || blocks.isNotEmpty) {
        return _resultFromText(text, blocks: blocks);
      }
    }

    ManuscriptParseResult? cloudResult;
    if (allowCloud) {
      try {
        cloudResult = await _parseViaCloud(bytes, filename);
      } catch (_) {}
    }

    if (lower.endsWith('.docx')) {
      if (cloudResult != null && cloudResult.fullText.trim().length >= 40) {
        return cloudResult;
      }
      throw Exception(appTr(
        'لم يُستخرج نص كافٍ من الملف',
        'Could not extract enough text from file',
      ));
    }

    if (cloudResult != null) {
      final text = cloudResult.fullText;
      final fromFile = _parseReferences(text);
      final refs = _preferBibliographyRefs(
        fileRefs: fromFile,
        localRefs: const [],
        cloudRefs: cloudResult.references,
        fullText: text,
      );
      return _linkedParseResult(cloudResult.copyWith(references: refs));
    }

    throw Exception(appTr(
      'تعذر استخراج النص — جرّب DOCX أو PDF نصي',
      'Could not extract text — try DOCX or text-based PDF',
    ));
  }

  /// DOCX body always comes from local XML (images, equations, subscripts).
  /// Cloud is used only for references and as a last-resort body fallback.
  static ManuscriptParseResult _mergeParseResults({
    required ManuscriptParseResult local,
    required ManuscriptParseResult cloud,
  }) {
    final bestTextForRefs = local.fullText.length >= cloud.fullText.length
        ? local.fullText
        : cloud.fullText;
    final fromFile = _parseReferences(bestTextForRefs);
    final bestRefs = _preferBibliographyRefs(
      fileRefs: fromFile,
      localRefs: local.references,
      cloudRefs: cloud.references,
      fullText: bestTextForRefs,
    );

    // Prefer local blocks — cloud/mammoth flattens formulas and drops many figures.
    List<ManuscriptBlock> bestBlocks;
    if (local.bodyBlocks.isNotEmpty) {
      bestBlocks = _enrichLocalImagesFromCloud(
        local.bodyBlocks,
        cloud.bodyBlocks,
      );
    } else if (cloud.bodyBlocks.isNotEmpty) {
      bestBlocks = cloud.bodyBlocks;
    } else {
      bestBlocks = _blocksFromPlainText(
        _bodyWithoutBibliography(
          local.fullText.isNotEmpty ? local.fullText : cloud.fullText,
        ),
      );
    }

    final bestText = local.fullText.length >= cloud.fullText.length
        ? local.fullText
        : cloud.fullText;

    return _linkedParseResult(ManuscriptParseResult(
      fullText: bestText,
      bodyText: _bodyWithoutBibliography(bestText),
      references: bestRefs,
      bodyBlocks: _finalizeBodyBlocks(bestBlocks),
      images: local.images.isNotEmpty ? local.images : cloud.images,
    ));
  }

  /// If local image upload later fails, keep any cloud http URLs in the same order.
  static List<ManuscriptBlock> _enrichLocalImagesFromCloud(
    List<ManuscriptBlock> local,
    List<ManuscriptBlock> cloud,
  ) {
    final cloudImages = cloud
        .where((b) =>
            b.type == ManuscriptBlockType.image &&
            (b.imageUrl?.startsWith('http') ?? false))
        .toList();
    if (cloudImages.isEmpty) return local;

    var cloudIdx = 0;
    return local.map((block) {
      if (block.type != ManuscriptBlockType.image) return block;
      final url = block.imageUrl ?? '';
      if (url.startsWith('http')) return block;
      if (cloudIdx >= cloudImages.length) return block;
      final cloudImg = cloudImages[cloudIdx++];
      // Prefer local data URI (uploaded client-side); only fill empty slots.
      if (url.isEmpty || url == '{{img:skipped}}') {
        return block.copyWith(imageUrl: cloudImg.imageUrl);
      }
      return block;
    }).toList();
  }

  static Future<ManuscriptParseResult> parseFromUrl({
    required String url,
    required String filename,
    String? manuscriptId,
  }) async {
    final bytes = await ManuscriptUploadService.instance.downloadDocumentBytes(
      url: url,
      manuscriptId: manuscriptId,
      filename: filename,
    );
    if (bytes != null && bytes.isNotEmpty) {
      return parseFile(
        bytes: bytes,
        filename: filename,
        allowCloud: false,
      );
    }

    throw Exception(appTr(
      'تعذر قراءة الملف من الجهاز — أعد رفع DOCX. الاستخراج السحابي معطّل لأنه يخلط المؤلفين بالمراجع',
      'Could not read the file on this device — upload the DOCX again. Cloud extract is disabled because it treats authors as references',
    ));
  }

  static bool _isMediaBlock(ManuscriptBlock block) =>
      block.type == ManuscriptBlockType.image ||
      block.type == ManuscriptBlockType.table ||
      block.type == ManuscriptBlockType.equation;

  static List<ManuscriptBlock> sanitizeImportedBlocks(List<ManuscriptBlock> blocks) {
    final trimmed = blocks.map((block) {
      final text = AcademicText.sanitize(block.text);
      final clipped = text.length <= maxBlockTextLength
          ? text
          : text.substring(0, maxBlockTextLength);
      final rows = block.rows
          .map((row) => row.map(AcademicText.sanitize).toList())
          .toList();
      return block.copyWith(text: clipped, rows: rows);
    }).toList();

    if (trimmed.length <= maxImportedBlocks) return trimmed;

    // Never drop images/tables/equations — only trim excess paragraphs.
    final mediaCount = trimmed.where(_isMediaBlock).length;
    final maxTextBlocks =
        (maxImportedBlocks - mediaCount).clamp(10, maxImportedBlocks);
    final out = <ManuscriptBlock>[];
    var textKept = 0;
    var omitted = 0;
    for (final block in trimmed) {
      if (_isMediaBlock(block)) {
        out.add(block);
        continue;
      }
      if (textKept < maxTextBlocks) {
        out.add(block);
        textKept++;
      } else {
        omitted++;
      }
    }
    if (omitted > 0) {
      out.add(ManuscriptBlock(
        id: 'import_truncated_${DateTime.now().millisecondsSinceEpoch}',
        type: ManuscriptBlockType.paragraph,
        text: appTr(
          '… تم اختصار $omitted فقرة نصية — الجداول والصور والمعادلات محفوظة',
          '… $omitted text paragraphs omitted — tables, figures and equations kept',
        ),
      ));
    }
    return out;
  }

  static List<PublishReference> sanitizeImportedReferences(
    List<PublishReference> references,
  ) {
    final capped = references.take(maxImportedReferences).map((ref) {
      final raw = AcademicText.sanitize(ref.rawText);
      final clipped = raw.length <= maxRawTextLength
          ? raw
          : raw.substring(0, maxRawTextLength);
      return ref.copyWith(
        rawText: clipped,
        year: AcademicText.westernDigits(ref.year),
        volume: AcademicText.westernDigits(ref.volume),
        issue: AcademicText.westernDigits(ref.issue),
        pages: AcademicText.westernDigits(ref.pages),
        doi: AcademicText.fixDoiCommas(AcademicText.westernDigits(ref.doi)),
      );
    }).toList();

    final stamped = stampImportedNumbers(capped);
    if (references.length <= maxImportedReferences) return stamped;

    return [
      ...stamped,
      PublishReference(
        id: 'ref_truncated_${DateTime.now().millisecondsSinceEpoch}',
        type: ReferenceType.journal,
        title: appTr(
          '… ${references.length - maxImportedReferences} مراجع إضافية',
          '… ${references.length - maxImportedReferences} more references',
        ),
        rawText: appTr(
          '… ${references.length - maxImportedReferences} مراجع إضافية — راجع الملف الأصلي',
          '… ${references.length - maxImportedReferences} more references — see original file',
        ),
      ),
    ];
  }

  /// Keep printed [n] / "n." from the imported file. Fill gaps only for
  /// unnumbered rows so later items never shift down to [1].
  ///
  /// A second `1.` after the real 1,2,3… run is a Word list restart, not item 1.
  static List<PublishReference> stampImportedNumbers(
    List<PublishReference> references,
  ) {
    if (references.isEmpty) return references;
    final printed = [
      for (final r in references)
        r.importedNumber ?? PublishReference.numberFromImportedLine(r.rawText),
    ];
    var trueOne = -1;
    for (var i = 0; i < printed.length; i++) {
      if (printed[i] != 1) continue;
      int? nextPrinted;
      for (var j = i + 1; j < printed.length; j++) {
        if (printed[j] == null) continue;
        nextPrinted = printed[j];
        break;
      }
      if (nextPrinted == 2) {
        trueOne = i;
        break;
      }
      if (trueOne < 0) trueOne = i;
    }

    final assigned = List<int?>.filled(references.length, null);
    final used = <int>{};
    var maxSeen = 0;
    for (var i = 0; i < references.length; i++) {
      final n = printed[i];
      if (n == null || n < 1) continue;
      if (n == 1 && trueOne >= 0 && i != trueOne) continue;
      if (used.contains(n) && n <= maxSeen) continue;
      if (!used.add(n)) continue;
      assigned[i] = n;
      if (n > maxSeen) maxSeen = n;
    }
    var next = 1;
    for (var i = 0; i < references.length; i++) {
      if (assigned[i] != null) continue;
      var prev = 0;
      for (var j = i - 1; j >= 0; j--) {
        if (assigned[j] != null) {
          prev = assigned[j]!;
          break;
        }
      }
      next = prev + 1;
      while (used.contains(next)) {
        next++;
      }
      assigned[i] = next;
      used.add(next);
    }
    return [
      for (var i = 0; i < references.length; i++)
        references[i].copyWith(
          importedNumber: assigned[i],
          id: 'ref_${assigned[i]}',
        ),
    ];
  }

  static String _extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final numbering = DocxListNumbering.fromArchive(archive);
    final buffer = StringBuffer();

    const xmlPaths = [
      'word/document.xml',
      'word/footnotes.xml',
      'word/endnotes.xml',
    ];

    for (final path in xmlPaths) {
      final entry = archive.findFile(path);
      if (entry == null) continue;
      try {
        final content = entry.content as List<int>;
        final xmlStr = utf8.decode(content);
        buffer.writeln(_textFromWordXml(xmlStr, numbering: numbering));
      } catch (_) {
        // Skip malformed XML parts.
      }
    }

    return buffer.toString().trim();
  }

  static String _textFromWordXml(
    String xmlStr, {
    DocxListNumbering? numbering,
  }) {
    final doc = XmlDocument.parse(xmlStr);
    final buffer = StringBuffer();

    void writeParagraphs(Iterable<XmlElement> paragraphs) {
      for (final paragraph in paragraphs) {
        _appendParagraphText(paragraph, buffer, numbering: numbering);
        buffer.writeln();
      }
    }

    writeParagraphs(doc.findAllElements('w:p'));
    return buffer.toString();
  }

  static void _appendParagraphText(
    XmlElement paragraph,
    StringBuffer buffer, {
    DocxListNumbering? numbering,
  }) {
    final label = numbering?.consume(paragraph);
    if (label != null) {
      final existing = StringBuffer();
      _walkTextNodes(paragraph, existing);
      final text = existing.toString().trimLeft();
      if (!RegExp(r'^\d{1,3}[.)]').hasMatch(text)) {
        buffer.write(label);
      }
    }
    _walkTextNodes(paragraph, buffer);
  }

  /// Walk nested Word XML (bookmarks, smart tags, hyperlinks) in order.
  static void _walkTextNodes(XmlElement element, StringBuffer buffer) {
    for (final child in element.children.whereType<XmlElement>()) {
      final tag = child.localName;
      if (tag == 'r') {
        _appendRunText(child, buffer);
      } else if (tag == 'oMath' || tag == 'oMathPara') {
        final math = _ommlPlainText(child);
        if (math.isNotEmpty) buffer.write(math);
      } else if (tag == 'tab') {
        buffer.write('\t');
      } else if (tag == 'br' || tag == 'cr') {
        buffer.write('\n');
      } else if (tag == 'drawing' ||
          tag == 'pict' ||
          tag == 'object' ||
          tag == 'blip' ||
          tag == 'imagedata') {
        // Binary / drawing content — not text.
      } else {
        _walkTextNodes(child, buffer);
      }
    }
  }

  static void _appendRunText(XmlElement run, StringBuffer buffer) {
    final text = _runVisibleText(run);
    if (text.isNotEmpty) buffer.write(text);
  }

  static String _runVisibleText(XmlElement run) {
    var vertAlign = '';
    for (final el in run.descendants.whereType<XmlElement>()) {
      if (el.localName == 'vertAlign') {
        vertAlign =
            (el.getAttribute('val') ?? el.getAttribute('w:val') ?? '').toLowerCase();
        break;
      }
    }
    final textParts = <String>[];
    for (final child in run.children.whereType<XmlElement>()) {
      if (child.localName == 't') {
        textParts.add(child.innerText);
      } else if (child.localName == 'tab') {
        textParts.add('\t');
      } else if (child.localName == 'br' || child.localName == 'cr') {
        textParts.add('\n');
      } else if (child.localName == 'sym') {
        final char = child.getAttribute('char') ?? child.getAttribute('w:char');
        if (char != null && char.isNotEmpty) {
          final code = int.tryParse(char, radix: 16);
          if (code != null) textParts.add(String.fromCharCode(code));
        }
      } else if (child.localName == 'oMath' || child.localName == 'oMathPara') {
        textParts.add(_ommlPlainText(child));
      }
    }
    final text = textParts.join();
    if (text.isEmpty) return '';
    return switch (vertAlign) {
      'subscript' => _toSubscriptUnicode(text),
      'superscript' => _toSuperscriptUnicode(text),
      _ => text,
    };
  }

  static bool _runIsBold(XmlElement run) {
    XmlElement? rPr;
    for (final child in run.children.whereType<XmlElement>()) {
      if (child.localName == 'rPr') {
        rPr = child;
        break;
      }
    }
    if (rPr == null) return false;
    var bold = false;
    for (final el in rPr.children.whereType<XmlElement>()) {
      if (el.localName != 'b' && el.localName != 'bCs') continue;
      final val =
          (el.getAttribute('val') ?? el.getAttribute('w:val') ?? '').toLowerCase();
      if (val == '0' || val == 'false' || val == 'off') return false;
      bold = true;
    }
    return bold;
  }

  static bool _runIsSuperscript(XmlElement run) {
    for (final el in run.descendants.whereType<XmlElement>()) {
      if (el.localName == 'vertAlign') {
        final val =
            (el.getAttribute('val') ?? el.getAttribute('w:val') ?? '').toLowerCase();
        return val == 'superscript';
      }
    }
    return false;
  }

  static String? _lastOutputChar(String text) {
    for (var i = text.length - 1; i >= 0; i--) {
      final c = text[i];
      if (c.trim().isEmpty) continue;
      return c;
    }
    return null;
  }

  static String _ommlPlainText(XmlElement math) {
    final buffer = StringBuffer();
    for (final node in math.descendants) {
      if (node is! XmlElement) continue;
      if (node.localName == 't') {
        buffer.write(node.innerText);
      } else if (node.localName == 'sSub') {
        // a_b → aᵇ style: collect later via children walk in order
      }
    }
    // Prefer structured OMML: base + sub/sup
    final structured = _ommlStructured(math);
    if (structured.isNotEmpty) return structured;
    return buffer.toString().trim();
  }

  static String _ommlStructured(XmlElement math) {
    final buffer = StringBuffer();
    void walk(XmlElement el) {
      for (final child in el.children.whereType<XmlElement>()) {
        final tag = child.localName;
        if (tag == 't') {
          buffer.write(child.innerText);
        } else if (tag == 'sSub') {
          final e = _ommlChildText(child, 'e');
          final sub = _ommlChildText(child, 'sub');
          buffer.write(e);
          buffer.write(_toSubscriptUnicode(sub));
        } else if (tag == 'sSup') {
          final e = _ommlChildText(child, 'e');
          final sup = _ommlChildText(child, 'sup');
          buffer.write(e);
          buffer.write(_toSuperscriptUnicode(sup));
        } else if (tag == 'sSubSup') {
          final e = _ommlChildText(child, 'e');
          final sub = _ommlChildText(child, 'sub');
          final sup = _ommlChildText(child, 'sup');
          buffer.write(e);
          buffer.write(_toSubscriptUnicode(sub));
          buffer.write(_toSuperscriptUnicode(sup));
        } else if (tag == 'f') {
          final num = _ommlChildText(child, 'num');
          final den = _ommlChildText(child, 'den');
          buffer.write('\\frac{');
          buffer.write(num);
          buffer.write('}{');
          buffer.write(den);
          buffer.write('}');
        } else if (tag == 'r') {
          walk(child);
        } else if (tag == 'e') {
          walk(child);
        } else if (tag == 'num' || tag == 'den' || tag == 'sub' || tag == 'sup') {
          walk(child);
        } else if (tag == 'rad') {
          final deg = _ommlChildText(child, 'deg');
          final e = _ommlChildText(child, 'e');
          buffer.write(deg.isEmpty ? '√($e)' : 'root($deg)($e)');
        } else {
          walk(child);
        }
      }
    }
    walk(math);
    return buffer.toString().trim();
  }

  static String _ommlChildText(XmlElement parent, String localName) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.localName == localName) {
        return _ommlStructured(child).isNotEmpty
            ? _ommlStructured(child)
            : child.descendants
                .whereType<XmlElement>()
                .where((e) => e.localName == 't')
                .map((e) => e.innerText)
                .join();
      }
    }
    return '';
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

  static String _cleanExtractedText(String text) {
    return DocxScientificExtractor.cleanScientificText(text);
  }

  /// Public helper for UI preview of table formulas.
  static String formatChemicalFormulaForDisplay(String text) =>
      DocxScientificExtractor.formatChemicalFormula(text.trim());

  static String _toSuperscriptUnicode(String input) {
    const map = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
      '+': '⁺', '-': '⁻',
      'n': 'ⁿ', 'i': 'ⁱ',
    };
    return input.split('').map((c) => map[c] ?? c).join();
  }

  static String _serializeOmml(XmlElement math) {
    if (math.localName == 'oMathPara') {
      return math.toXmlString(pretty: false);
    }
    return '<m:oMathPara xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">'
        '${math.toXmlString(pretty: false)}'
        '</m:oMathPara>';
  }

  static ManuscriptBlock _equationBlock({
    required String Function() nextId,
    required XmlElement math,
  }) {
    final text = _ommlPlainText(math);
    return ManuscriptBlock(
      id: nextId(),
      type: ManuscriptBlockType.equation,
      text: text,
      ommlXml: _serializeOmml(math),
    );
  }

  /// Split a Word paragraph into text + equation/image blocks in document order.
  static List<ManuscriptBlock> _blocksFromDocxParagraph(
    XmlElement element, {
    required Archive archive,
    required Map<String, String> rels,
    required String Function() nextId,
    required void Function(String uri) onVisualUsed,
    required int Function() imageCount,
    required int maxLocalImages,
    _CiteImportRegion region = _CiteImportRegion.body,
  }) {
    final blocks = <ManuscriptBlock>[];
    final textBuffer = StringBuffer();
    final boldBuf = StringBuffer();
    final hasEqField = DocxScientificExtractor.paragraphHasEquationField(element);
    final inBody = region == _CiteImportRegion.body;
    final wrapCites = region != _CiteImportRegion.bibliography;
    final citeDigitBuf = StringBuffer();
    var collectingBracket = false;
    final bracketInner = StringBuffer();

    void flushCiteDigits() {
      final n = citeDigitBuf.toString();
      citeDigitBuf.clear();
      if (n.isEmpty) return;
      final before = textBuffer.toString();
      if (CitationLinker.looksLikeMathExponent(n, before) ||
          CitationLinker.looksLikeMathExponent(n, '$before${boldBuf.toString()}')) {
        textBuffer.write(CitationLinker.toSuperscriptDigits(n));
        return;
      }
      textBuffer.write(
        wrapCites
            ? CitationLinker.applyHintWrap(
                n,
                inBody: inBody,
                before: '$before${boldBuf.toString()}',
              )
            : n,
      );
    }

    void flushBoldHint() {
      flushCiteDigits();
      final t = boldBuf.toString();
      boldBuf.clear();
      if (t.isEmpty) return;
      textBuffer.write(
        wrapCites
            ? CitationLinker.applyHintWrap(
                t,
                inBody: inBody,
                before: textBuffer.toString(),
              )
            : t,
      );
    }

    void closeBracketCite() {
      final inner = CitationLinker.asciiDigits(bracketInner.toString())
          .replaceAll(RegExp(r'[^0-9,;–\-]+'), '');
      bracketInner.clear();
      collectingBracket = false;
      textBuffer.write('[$inner]');
    }

    void flushText() {
      if (collectingBracket) {
        textBuffer.write('[${bracketInner.toString()}');
        bracketInner.clear();
        collectingBracket = false;
      }
      flushBoldHint();
      var text = _cleanExtractedText(textBuffer.toString());
      text = CitationLinker.normalizeNumberedCiteDigits(text);
      textBuffer.clear();
      if (text.isEmpty) return;
      if (DocxScientificExtractor.isEquationPlaceholder(text)) return;
      blocks.add(ManuscriptBlock(
        id: nextId(),
        type: _isHeadingParagraph(element)
            ? ManuscriptBlockType.heading
            : ManuscriptBlockType.paragraph,
        text: text,
      ));
    }

    void appendFormattedRun(String raw, XmlElement run) {
      if (raw.isEmpty) return;
      final ascii = CitationLinker.asciiDigits(raw);
      final isCiteDigitRun = wrapCites &&
          inBody &&
          RegExp(r'^\d{1,3}$').hasMatch(ascii) &&
          (_runIsSuperscript(run) || _runIsBold(run));
      if (isCiteDigitRun) {
        final before = '${textBuffer.toString()}${boldBuf.toString()}';
        if (CitationLinker.looksLikeMathExponent(ascii, before)) {
          flushBoldHint();
          textBuffer.write(
            RegExp(r'[⁰¹²³⁴⁵⁶⁷⁸⁹⁻]').hasMatch(raw)
                ? raw
                : CitationLinker.toSuperscriptDigits(ascii),
          );
          return;
        }
        if (boldBuf.isNotEmpty) {
          final t = boldBuf.toString();
          boldBuf.clear();
          textBuffer.write(
            wrapCites
                ? CitationLinker.applyHintWrap(
                    t,
                    inBody: inBody,
                    before: textBuffer.toString(),
                  )
                : t,
          );
        }
        citeDigitBuf.write(ascii);
        return;
      }
      if (_runIsSuperscript(run)) {
        final last =
            _lastOutputChar('${textBuffer.toString()}${boldBuf.toString()}');
        final afterLetter =
            last != null && RegExp(r"[A-Za-z\u0600-\u06FF*,]").hasMatch(last);
        if (region == _CiteImportRegion.frontMatter && afterLetter) {
          flushBoldHint();
          textBuffer.write(raw);
          return;
        }
        if (wrapCites) {
          flushBoldHint();
          textBuffer.write(
            CitationLinker.applyHintWrap(
              raw,
              inBody: inBody,
              before: textBuffer.toString(),
            ),
          );
          return;
        }
      }
      if (_runIsBold(run)) {
        if (_isHeadingParagraph(element) ||
            CitationStyleShapes.looksLikeSectionHeading(raw)) {
          flushBoldHint();
          textBuffer.write(raw);
          return;
        }
        flushCiteDigits();
        boldBuf.write(raw);
        return;
      }
      flushBoldHint();
      textBuffer.write(raw);
    }

    void appendBodyRun(XmlElement run) {
      final raw = _runVisibleText(run);
      if (raw.isEmpty) return;
      final ascii = CitationLinker.asciiDigits(raw);
      if (wrapCites && inBody && (collectingBracket || ascii.contains('['))) {
        final chars = ascii.split('');
        var start = 0;
        for (var k = 0; k < chars.length; k++) {
          final c = chars[k];
          if (!collectingBracket) {
            if (c == '[') {
              if (k > start) {
                appendFormattedRun(chars.sublist(start, k).join(), run);
              }
              flushBoldHint();
              collectingBracket = true;
              bracketInner.clear();
              start = k + 1;
            }
          } else if (c == ']') {
            closeBracketCite();
            start = k + 1;
          } else {
            bracketInner.write(c);
          }
        }
        if (!collectingBracket && start < chars.length) {
          appendFormattedRun(chars.sublist(start).join(), run);
        }
        return;
      }
      appendFormattedRun(raw, run);
    }

    void addVisualBlocks(XmlElement visualNode, {required bool asEquation}) {
      if (imageCount() >= maxLocalImages) return;
      for (final url in _extractAllEmbeddedImages(visualNode, archive, rels)) {
        if (imageCount() >= maxLocalImages) break;
        onVisualUsed(url);
        final id = nextId();
        _registerImageUri(id, url);
        final extent = _drawingExtentEmu(visualNode);
        blocks.add(ManuscriptBlock(
          id: id,
          type: asEquation
              ? ManuscriptBlockType.equation
              : ManuscriptBlockType.image,
          text: asEquation ? '' : '',
          imageUrl: url,
          imageWidthEmu: extent?.$1,
          imageHeightEmu: extent?.$2,
        ));
      }
    }

    void walkNonMath(XmlElement el) {
      for (final child in el.children.whereType<XmlElement>()) {
        final tag = child.localName;
        if (tag == 'oMath' || tag == 'oMathPara') {
          flushText();
          final eqText = _ommlPlainText(child);
          if (eqText.isNotEmpty) {
            blocks.add(_equationBlock(nextId: nextId, math: child));
          }
          continue;
        }
        if (tag == 'r') {
          appendBodyRun(child);
          walkNonMath(child);
          continue;
        }
        if (tag == 'tab') {
          textBuffer.write('\t');
          continue;
        }
        if (tag == 'br' || tag == 'cr') {
          textBuffer.write('\n');
          continue;
        }
        if (tag == 'instrText' || tag == 'fldChar' || tag == 'delText') {
          continue;
        }
        if (tag == 'fldSimple') {
          final instr = child.getAttribute('instr') ??
              child.getAttribute('w:instr') ??
              '';
          if (instr.toLowerCase().contains('eq')) continue;
          walkNonMath(child);
          continue;
        }
        if (tag == 'drawing' || tag == 'pict' || tag == 'object') {
          flushText();
          addVisualBlocks(
            child,
            asEquation: hasEqField ||
                tag == 'object' &&
                    DocxScientificExtractor.isOleScientificObject(child),
          );
          // Shape / text-box prose nested inside DrawingML / VML.
          for (final shapeText in _extractShapeTextBoxes(child)) {
            if (shapeText.isEmpty) continue;
            blocks.add(ManuscriptBlock(
              id: nextId(),
              type: ManuscriptBlockType.paragraph,
              text: shapeText,
            ));
          }
          continue;
        }
        if (tag == 'AlternateContent') {
          var sawImage = false;
          XmlElement? fallback;
          for (final branch in child.children.whereType<XmlElement>()) {
            if (branch.localName == 'Fallback') {
              fallback = branch;
              continue;
            }
            if (branch.localName != 'Choice') continue;
            walkNonMath(branch);
            sawImage = true;
          }
          if (fallback != null) {
            // Always collect VML rasters; Choice may be OLE-only.
            walkNonMath(fallback);
          } else if (!sawImage) {
            walkNonMath(child);
          }
          continue;
        }
        if (tag == 'blip' || tag == 'imagedata') {
          flushText();
          addVisualBlocks(child, asEquation: hasEqField);
          continue;
        }
        walkNonMath(child);
      }
    }

    walkNonMath(element);
    flushText();

    // Fallback: OMML present but walker missed it (nested wrappers).
    if (!blocks.any((b) => b.type == ManuscriptBlockType.equation)) {
      for (final math in element.findAllElements('oMathPara')) {
        final eqText = _ommlPlainText(math);
        if (eqText.isNotEmpty) {
          blocks.add(_equationBlock(nextId: nextId, math: math));
        }
      }
      if (!blocks.any((b) => b.type == ManuscriptBlockType.equation)) {
        for (final math in element.findAllElements('oMath')) {
          final parent = math.parent;
          if (parent is XmlElement && parent.localName == 'oMathPara') continue;
          final eqText = _ommlPlainText(math);
          if (eqText.isNotEmpty) {
            blocks.add(_equationBlock(nextId: nextId, math: math));
          }
        }
      }
    }

    return blocks;
  }

  static Future<ManuscriptParseResult> _parseViaCloud(
    Uint8List bytes,
    String filename,
  ) =>
      _parseViaCloudRequest(
        filename: filename,
        base64: base64Encode(bytes),
      );

  static Future<ManuscriptParseResult> _parseViaCloudRequest({
    required String filename,
    String? base64,
    String? fileUrl,
  }) async {
    final data = <String, dynamic>{'filename': filename};
    if (useLightCloudExtract) {
      data['referencesOnly'] = true;
    }
    if (fileUrl != null && fileUrl.isNotEmpty) {
      data['fileUrl'] = fileUrl;
    } else if (base64 != null && base64.isNotEmpty) {
      data['base64'] = base64;
    } else {
      throw Exception(appTr(
        'بيانات الملف غير صالحة',
        'Invalid file payload',
      ));
    }

    final result = await CallableHttpClient.call(
      name: 'publishExtractReferencesHttp',
      data: data,
      timeout: const Duration(minutes: 3),
    );

    final bodyText = result['bodyText']?.toString() ?? '';
    final fullText = result['fullText']?.toString() ??
        result['text']?.toString() ??
        bodyText;
    final cleanBodyText = _bodyWithoutBibliography(fullText);

    final refsRaw = result['references'];
    final refsList = refsRaw is List ? refsRaw : const [];

    if (cleanBodyText.trim().length < 40 &&
        refsList.isEmpty &&
        (result['bodyBlocks'] is! List || (result['bodyBlocks'] as List).isEmpty)) {
      throw Exception(appTr(
        'لم يُستخرج نص كافٍ — جرّب PDF نصي أو DOCX',
        'Not enough text — try text PDF or DOCX',
      ));
    }

    var references = sanitizeImportedReferences(
      refsList
          .whereType<Map>()
          .map((e) => PublishReference.fromMap(Map<String, dynamic>.from(e)))
          .toList()
          .where(_referenceLooksValid)
          .toList(),
    );
    if (fullText.trim().isNotEmpty) {
      final fromFile = _parseReferences(fullText);
      references = sanitizeImportedReferences(
        _preferBibliographyRefs(
          fileRefs: fromFile,
          localRefs: references,
          cloudRefs: const [],
          fullText: fullText,
        ),
      );
    }

    List<ManuscriptBlock> mediaBlocks = [];
    final blocksRaw = result['bodyBlocks'];
    if (blocksRaw is List) {
      mediaBlocks = blocksRaw
          .whereType<Map>()
          .map((e) => ManuscriptBlock.fromMap(Map<String, dynamic>.from(e)))
          .where((b) =>
              b.type == ManuscriptBlockType.table ||
              b.type == ManuscriptBlockType.image ||
              b.type == ManuscriptBlockType.equation)
          .toList();
    }

    List<ManuscriptBlock> bodyBlocks;
    if (blocksRaw is List && blocksRaw.isNotEmpty) {
      bodyBlocks = blocksRaw
          .whereType<Map>()
          .map((e) => ManuscriptBlock.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      bodyBlocks = _finalizeBodyBlocks(bodyBlocks);
    } else {
      bodyBlocks = sanitizeImportedBlocks(
        _buildAcademicLayout(
          cleanBodyText.isNotEmpty ? cleanBodyText : bodyText,
          mediaBlocks: mediaBlocks,
        ),
      );
    }

    return _linkedParseResult(ManuscriptParseResult(
      fullText: fullText,
      bodyText: cleanBodyText.isNotEmpty ? cleanBodyText : bodyText,
      references: references,
      bodyBlocks: bodyBlocks,
      images: const [],
    ));
  }

  static ManuscriptParseResult _linkedParseResult(ManuscriptParseResult parsed) {
    final extracted = _extractBibliographyFromBody(parsed.bodyBlocks);
    var refs = parsed.references;
    if (extracted.harvested.isNotEmpty) {
      refs = _mergeHarvestedBibliography(refs, extracted.harvested);
    } else {
      refs = sanitizeImportedReferences(refs);
    }
    final bibSection = _bibliographySection(parsed.fullText);
    refs = BibliographyCiteAligner.complete(
      bodyText: _bodyWithoutBibliography(parsed.fullText),
      bibliographyText:
          bibSection.isNotEmpty ? bibSection : _likelyBibliographyTail(parsed.fullText),
      parsed: refs,
    );
    refs = sanitizeImportedReferences(refs);
    final bodyBlob = extracted.blocks.map((b) => b.text).join('\n');
    final numberedPaper = RegExp(r'\[\d{1,3}\]').hasMatch(bodyBlob);
    final linked = CitationLinker.linkParsed(
      references: refs,
      bodyBlocks: extracted.blocks,
      numbersOnly: numberedPaper,
    );
    return parsed.copyWith(
      references: linked.references,
      bodyBlocks: linked.bodyBlocks,
    );
  }

  static List<PublishReference> _mergeHarvestedBibliography(
    List<PublishReference> parsed,
    List<String> harvested,
  ) {
    if (harvested.isEmpty) return parsed;
    final extra = <PublishReference>[];
    var i = 0;
    for (final line in harvested) {
      if (parsed.any((r) => _sameBibliographicWork(r, line))) continue;
      extra.add(_blockToReference(line, id: 'body_ref_${++i}', rawText: line));
    }
    if (extra.isEmpty) return parsed;
    final parsedNums = {
      for (final r in parsed)
        if ((r.importedNumber ??
                PublishReference.numberFromImportedLine(r.rawText)) !=
            null)
          r.importedNumber ??
              PublishReference.numberFromImportedLine(r.rawText)!,
    };
    final extrasNumbered = extra
        .where(
          (r) =>
              (r.importedNumber ??
                  PublishReference.numberFromImportedLine(r.rawText)) !=
              null,
        )
        .length;
    final parsedIsWeak =
        parsedNums.length < 3 && parsed.length < extra.length;
    final extrasComplete = extra
        .where((r) => _bibliographyRowLooksComplete(r.rawText))
        .length;
    final parsedHasPrintedOne = parsedNums.contains(1);
    final extrasAreRealList = extrasNumbered >= 3 && extra.length > parsed.length;
    final extrasLookLikeBib = extra.length >= 3 &&
        extra.every((r) => r.rawText.trim().length >= 40);
    // Unnumbered ACS/APA rows harvested from the body before a later
    // "References" heading must stay in front — they are the real [1]… list.
    if (!parsedHasPrintedOne &&
        extrasComplete >= 3 &&
        extra.length >= parsed.length) {
      return sanitizeImportedReferences([...extra, ...parsed]);
    }
    if (parsedIsWeak && (extrasAreRealList || extrasLookLikeBib)) {
      return sanitizeImportedReferences([...extra, ...parsed]);
    }
    return sanitizeImportedReferences([...parsed, ...extra]);
  }

  static bool _sameBibliographicWork(PublishReference ref, String line) {
    String stripNum(String s) => s
        .replaceFirst(RegExp(r'^\[\d{1,3}\]\s*'), '')
        .replaceFirst(RegExp(r'^\d{1,3}[.)]\s+'), '');
    final a = stripNum(
      AcademicText.westernDigits(
        (ref.rawText.trim().isNotEmpty ? ref.rawText : ref.title).toLowerCase(),
      ),
    );
    final b = stripNum(AcademicText.westernDigits(line.toLowerCase()));
    final doiA = RegExp(r'10\.\d{4,}/\S+').firstMatch(a)?.group(0);
    final doiB = RegExp(r'10\.\d{4,}/\S+').firstMatch(b)?.group(0);
    if (doiA != null && doiB != null) {
      return doiA.replaceAll(RegExp(r'[.,;]+$'), '') ==
          doiB.replaceAll(RegExp(r'[.,;]+$'), '');
    }
    final year = ref.year.trim();
    final last = ref.authors.isNotEmpty
        ? ref.authors.first.split(',').first.trim().toLowerCase()
        : '';
    if (year.length >= 4 && last.length >= 4) {
      return b.contains(year) && b.contains(last);
    }
    if (a.length >= 40 && b.contains(a.substring(0, 40))) return true;
    return false;
  }

  @visibleForTesting
  static ManuscriptParseResult parsePlainTextForTest(String text) =>
      _resultFromText(text);

  static List<PublishReference> parseReferencesFromText(String fullText) =>
      _parseReferences(fullText);

  static ManuscriptParseResult _resultFromText(
    String text, {
    List<ManuscriptBlock> blocks = const [],
  }) {
    final bodyText = _bodyWithoutBibliography(text);
    final bodyBlocks = _finalizeBodyBlocks(
      blocks.isNotEmpty ? blocks : _blocksFromPlainText(bodyText),
    );
    return _linkedParseResult(ManuscriptParseResult(
      fullText: text,
      bodyText: bodyText,
      references: _parseReferences(text),
      bodyBlocks: bodyBlocks,
    ));
  }

  static bool blocksHaveBodyProse(List<ManuscriptBlock> blocks) =>
      _proseCharCount(blocks) >= 120;

  static int _proseCharCount(List<ManuscriptBlock> blocks) {
    var n = 0;
    for (final b in blocks) {
      if (b.type != ManuscriptBlockType.paragraph &&
          b.type != ManuscriptBlockType.heading) {
        continue;
      }
      final t = b.text.trim();
      if (t.isEmpty) continue;
      if (ScholarlyLayout.isFloatCaption(t) ||
          _isFigureCaption(t) ||
          _isTableCaption(t)) {
        continue;
      }
      n += t.length;
    }
    return n;
  }

  /// Keep the file's own headings and block order. Do not remap Abstract /
  /// Background / Introduction, and do not move figures to a guessed section.
  static List<ManuscriptBlock> _finalizeBodyBlocks(List<ManuscriptBlock> blocks) {
    if (blocks.isEmpty) return blocks;
    final structured = sanitizeImportedBlocks(
      mergeSectionParagraphs(structureImportedBlocks(blocks)),
    );
    final repaired = _pairTableCaptions(
      _mergeContinuedTables(_extractInlineCaptions(structured)),
    );
    _warmImageSessionCache(repaired);
    return repaired;
  }

  /// Split a glued "Fig. 1 …" line out of a paragraph. Does not move blocks.
  static List<ManuscriptBlock> restoreJournalReadingOrder(
    List<ManuscriptBlock> blocks,
  ) {
    return _extractInlineCaptions(blocks);
  }

  /// Collapse text between major section headings into large section bodies.
  /// Drops junk fragments (lone "2 )", "3") and repairs broken line joins.
  static List<ManuscriptBlock> mergeSectionParagraphs(
    List<ManuscriptBlock> blocks,
  ) {
    if (blocks.isEmpty) return blocks;

    var idCounter = 0;
    String nextId() =>
        'merged_${DateTime.now().millisecondsSinceEpoch}_${idCounter++}';

    final cleaned = <ManuscriptBlock>[];
    for (final block in blocks) {
      if (block.type != ManuscriptBlockType.paragraph &&
          block.type != ManuscriptBlockType.heading) {
        cleaned.add(block);
        continue;
      }
      final t = block.text.trim();
      if (t.isEmpty) continue;
      if (_isJunkTextFragment(t)) continue;

      if (_isPrintedHeading(t) ||
          (block.type == ManuscriptBlockType.heading &&
              !_isJunkTextFragment(block.text))) {
        cleaned.add(ManuscriptBlock(
          id: block.id.isNotEmpty ? block.id : nextId(),
          type: ManuscriptBlockType.heading,
          text: t,
        ));
        continue;
      }

      // Soft sub-headings ("Preparation of …:") stay as paragraph text.
      cleaned.add(ManuscriptBlock(
        id: block.id.isNotEmpty ? block.id : nextId(),
        type: ManuscriptBlockType.paragraph,
        text: t,
      ));
    }

    if (cleaned.length < 2) return cleaned;

    final out = <ManuscriptBlock>[];
    final pending = StringBuffer();

    void flushPending() {
      var text = pending.toString().trim();
      pending.clear();
      if (text.isEmpty) return;
      text = _repairBrokenJoins(text);
      out.add(ManuscriptBlock(
        id: nextId(),
        type: ManuscriptBlockType.paragraph,
        text: text,
      ));
    }

    bool isMergeable(ManuscriptBlock b) {
      if (b.type != ManuscriptBlockType.paragraph) return false;
      final t = b.text.trim();
      if (t.isEmpty || _isJunkTextFragment(t)) return false;
      if (_isPrintedHeading(t)) return false;
      if (ScholarlyLayout.isFloatCaption(t)) return false;
      if (DocxScientificExtractor.isEquationFragment(t)) return false;
      if (_isStandaloneBibliographyEntry(t)) return false;
      if (_splitStandaloneBibliographyEntries(t).length >= 2) return false;
      return true;
    }

    for (final block in cleaned) {
      if (block.type == ManuscriptBlockType.heading &&
          _isPrintedHeading(block.text)) {
        flushPending();
        out.add(block);
        continue;
      }

      if (!isMergeable(block)) {
        flushPending();
        out.add(block);
        continue;
      }

      final t = block.text.trim();
      if (pending.isEmpty) {
        pending.write(t);
      } else if (_scriptsConflict(pending.toString(), t)) {
        flushPending();
        pending.write(t);
      } else if (_looksLikeContinuation(t)) {
        // ".up to 1 L" / mid-sentence fragment → glue without blank line
        final prev = pending.toString();
        if (t.startsWith('.') || t.startsWith(',')) {
          pending
            ..clear()
            ..write(prev.trimRight())
            ..write(t);
        } else if (!prev.endsWith(' ') && !prev.endsWith('\n')) {
          pending.write(' ');
          pending.write(t);
        } else {
          pending.write(t);
        }
      } else {
        pending.write('\n\n');
        pending.write(t);
      }
    }
    flushPending();
    return out;
  }

  /// Pull "Table N" / "Figure N" lines out of a merged section paragraph.
  static List<ManuscriptBlock> _extractInlineCaptions(
    List<ManuscriptBlock> blocks,
  ) {
    final out = <ManuscriptBlock>[];
    final captionRe = RegExp(
      r'(?:^|\n)\s*[\u200e\u200f\u202a-\u202e.]*'
      r'((?:Table|Figure|Fig\.?|Scheme|Chart|Plate|شكل|جدول)\.?\s*[\d٠-٩]+[^\n]*)',
      caseSensitive: false,
    );
    for (final block in blocks) {
      if (block.type != ManuscriptBlockType.paragraph) {
        out.add(block);
        continue;
      }
      final matches = captionRe.allMatches(block.text).toList();
      if (matches.isEmpty) {
        out.add(block);
        continue;
      }
      var cursor = 0;
      var part = 0;
      for (final m in matches) {
        final before = block.text.substring(cursor, m.start).trim();
        if (before.isNotEmpty) {
          out.add(ManuscriptBlock(
            id: '${block.id}_p$part',
            type: ManuscriptBlockType.paragraph,
            text: before,
            imageUrl: block.imageUrl,
          ));
          part++;
        }
        out.add(ManuscriptBlock(
          id: '${block.id}_cap${part++}',
          type: ManuscriptBlockType.paragraph,
          text: m.group(1)!.trim(),
        ));
        cursor = m.end;
      }
      final after = block.text.substring(cursor).trim();
      if (after.isNotEmpty) {
        out.add(ManuscriptBlock(
          id: '${block.id}_p$part',
          type: ManuscriptBlockType.paragraph,
          text: after,
          imageUrl: block.imageUrl,
        ));
      }
    }
    return out;
  }

  /// Word often splits one table into consecutive tbl elements.
  static List<ManuscriptBlock> _mergeContinuedTables(
    List<ManuscriptBlock> blocks,
  ) {
    if (blocks.length < 2) return blocks;
    final out = <ManuscriptBlock>[];
    for (final block in blocks) {
      if (block.type == ManuscriptBlockType.table &&
          out.isNotEmpty &&
          out.last.type == ManuscriptBlockType.table) {
        final prev = out.last;
        if (prev.rows.isNotEmpty &&
            block.rows.isNotEmpty &&
            prev.rows.first.length == block.rows.first.length) {
          var start = 0;
          if (_sameTableRow(prev.rows.first, block.rows.first)) start = 1;
          out[out.length - 1] = prev.copyWith(
            rows: [...prev.rows, ...block.rows.sublist(start)],
            rowCellImages: [
              ...prev.rowCellImages,
              if (start < block.rowCellImages.length)
                ...block.rowCellImages.sublist(start),
            ],
            caption: prev.caption ?? block.caption,
          );
          continue;
        }
      }
      out.add(block);
    }
    return out;
  }

  static bool _sameTableRow(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].trim().toLowerCase() != b[i].trim().toLowerCase()) return false;
    }
    return true;
  }

  /// Pair "Table N" captions with the following tables, even if several
  /// captions were stacked (Word floating-table order).
  static List<ManuscriptBlock> _pairTableCaptions(
    List<ManuscriptBlock> blocks,
  ) {
    final pending = <String>[];
    final out = <ManuscriptBlock>[];
    for (final block in blocks) {
      if ((block.type == ManuscriptBlockType.paragraph ||
              block.type == ManuscriptBlockType.heading) &&
          _isTableCaption(block.text) &&
          block.type != ManuscriptBlockType.heading) {
        pending.add(block.text.trim());
        continue;
      }
      if (block.type == ManuscriptBlockType.table) {
        if (pending.isNotEmpty) {
          out.add(block.copyWith(caption: pending.removeAt(0)));
        } else {
          out.add(block);
        }
        continue;
      }
      if (block.type == ManuscriptBlockType.heading) {
        for (final caption in pending) {
          out.add(ManuscriptBlock(
            id: '${block.id}_cap',
            type: ManuscriptBlockType.paragraph,
            text: caption,
          ));
        }
        pending.clear();
      }
      out.add(block);
    }
    for (var i = 0; i < pending.length; i++) {
      out.add(ManuscriptBlock(
        id: 'table_cap_$i',
        type: ManuscriptBlockType.paragraph,
        text: pending[i],
      ));
    }
    return out;
  }

  /// Floating Word tables/figures often land after Conclusion in document.xml.
  static List<ManuscriptBlock> _relocateDisplacedResults(
    List<ManuscriptBlock> blocks,
  ) {
    if (blocks.length < 4) return blocks;
    final conclusionAt = _headingIndex(blocks, {
      'conclusion',
      'conclusions',
      'الخاتمة',
      'الاستنتاجات',
      'الاستنتاج',
    });
    if (conclusionAt == null) return blocks;

    final move = <ManuscriptBlock>[];
    final keep = <ManuscriptBlock>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i <= conclusionAt) {
        keep.add(blocks[i]);
        continue;
      }
      if (_isBibliographyHeadingBlock(blocks[i]) ||
          _looksLikeReference(blocks[i].text)) {
        keep.add(blocks[i]);
        continue;
      }
      if (_looksLikeDisplacedResults(blocks[i])) {
        move.add(blocks[i]);
      } else {
        keep.add(blocks[i]);
      }
    }
    if (move.isEmpty) return blocks;

    final out = <ManuscriptBlock>[];
    var inserted = false;
    for (final block in keep) {
      if (!inserted && _isHeadingNamed(block, {
        'conclusion',
        'conclusions',
        'الخاتمة',
        'الاستنتاجات',
        'الاستنتاج',
      })) {
        out.addAll(move);
        inserted = true;
      }
      out.add(block);
    }
    if (!inserted) out.addAll(move);
    return out;
  }

  /// IMRaD: figures/tables never sit on the title page (any journal / any file).
  /// Word often emits floating drawings before the title in document.xml.
  static List<ManuscriptBlock> _relocateFrontMatterFloats(
    List<ManuscriptBlock> blocks,
  ) {
    if (blocks.length < 2) return blocks;
    var start = _articleStartIndex(blocks);
    if (start <= 0) {
      start = 0;
      while (start < blocks.length &&
          (blocks[start].text.trim().isEmpty || _isFloatBlock(blocks[start]))) {
        start++;
      }
      if (start <= 0 || start >= blocks.length) return blocks;
    }

    final floats = <ManuscriptBlock>[];
    final rest = <ManuscriptBlock>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i < start && _isFloatBlock(blocks[i])) {
        floats.add(blocks[i]);
      } else {
        rest.add(blocks[i]);
      }
    }
    if (floats.isEmpty) return blocks;

    var insertAt = _floatInsertIndex(rest);
    if (insertAt < 0 || insertAt > rest.length) insertAt = rest.length;
    return [
      ...rest.sublist(0, insertAt),
      ...floats,
      ...rest.sublist(insertAt),
    ];
  }

  static bool _isFloatBlock(ManuscriptBlock block) {
    if (block.type == ManuscriptBlockType.image ||
        block.type == ManuscriptBlockType.table) {
      return true;
    }
    if (block.type == ManuscriptBlockType.equation &&
        (block.imageUrl ?? '').isNotEmpty &&
        (block.ommlXml == null || block.ommlXml!.trim().isEmpty)) {
      return true;
    }
    final t = ScholarlyLayout.classificationLead(block.text);
    return t.isNotEmpty && ScholarlyLayout.isFloatCaption(t);
  }

  static int _articleStartIndex(List<ManuscriptBlock> blocks) {
    final abstractAt = _findAbstractIndex(blocks);
    final limit = abstractAt ?? blocks.length;
    for (var i = 0; i < limit; i++) {
      final t = blocks[i].text.trim();
      if (t.isEmpty || _isFloatBlock(blocks[i])) continue;
      if (ScholarlyLayout.isArticleTitle(t) ||
          DocxScientificExtractor.isPaperTitle(t)) {
        return i;
      }
      if (ScholarlyLayout.isAuthorByline(t)) return i;
    }
    return abstractAt ?? 0;
  }

  static int _floatInsertIndex(List<ManuscriptBlock> blocks) {
    for (final names in [
      {'results', 'results and discussion', 'النتائج'},
      {'experimental', 'materials and methods', 'methods', 'التجريبي', 'المواد والطرق'},
      {'discussion', 'المناقشة'},
    ]) {
      final i = _headingIndex(blocks, names);
      if (i != null) return i + 1;
    }
    return _findBibliographyIndex(blocks);
  }

  static bool _looksLikeDisplacedResults(ManuscriptBlock block) {
    if (block.type == ManuscriptBlockType.table ||
        block.type == ManuscriptBlockType.image) {
      return true;
    }
    final t = block.text.trim();
    if (t.isEmpty) return false;
    if (_isTableCaption(t) || _isFigureCaption(t)) return true;
    if (RegExp(
      r'\b(?:Table|Figure|Fig\.?)\s+\d+',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    return false;
  }

  static int? _headingIndex(List<ManuscriptBlock> blocks, Set<String> names) {
    for (var i = 0; i < blocks.length; i++) {
      if (_isHeadingNamed(blocks[i], names)) return i;
    }
    return null;
  }

  static bool _isHeadingNamed(ManuscriptBlock block, Set<String> names) {
    if (block.type != ManuscriptBlockType.heading &&
        !_isMajorSectionHeading(block.text)) {
      return false;
    }
    final t = _normalizeKnownSectionHeading(block.text).trim().toLowerCase();
    return names.contains(t);
  }

  static bool _isBibliographyHeadingBlock(ManuscriptBlock block) {
    final t = _normalizeKnownSectionHeading(block.text).trim().toLowerCase();
    return t == 'references' || t.contains('المراجع');
  }

  /// Heading as printed in the file (any label), plus Word heading style.
  static bool _isPrintedHeading(String line) {
    final t = AcademicText.stripBidi(line).trim();
    if (t.isEmpty) return false;
    if (_isFigureCaption(t) || _isTableCaption(t)) return false;
    if (_isMajorSectionHeading(t)) return true;
    return CitationStyleShapes.looksLikeSectionHeading(t);
  }

  /// True for Abstract / Introduction / Experimental / Results / Discussion /
  /// Conclusion (and Arabic equivalents) — not method sub-titles.
  static bool _isMajorSectionHeading(String line) {
    final t = AcademicText.stripBidi(line).trim();
    if (t.isEmpty || t.length > 90) return false;
    // Reject if it looks like a full sentence (many words after the label).
    final wordCount = t.split(RegExp(r'\s+')).length;
    if (wordCount > 8) return false;

    final lower = t.toLowerCase();
    if (RegExp(
      r'^(?:\d+\.?\s*)?(abstract|introduction|background|experimental|'
      r'materials(\s+and\s+methods)?|methods?|results?|discussion|'
      r'conclusions?|references?|acknowledgments?|keywords?)\s*:?\s*$',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    if (RegExp(
      r'^(الملخص|المقدمة|الخلفية|التجريبي|المنهجية?|المواد والطرق|المواد|'
      r'النتائج|المناقشة|الخاتمة|الاستنتاجات?|المراجع|'
      r'كلمات مفتاحية|الكلمات المفتاحية|الكلمات الدالة)\s*:?\s*$',
    ).hasMatch(t)) {
      return true;
    }
    // "1. Introduction" / "3. Results and discussion"
    if (RegExp(
      r'^\d+\.?\s+(Abstract|Introduction|Background|Experimental|Methods|'
      r'Materials|Results|Discussion|Conclusion)',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    // ALL-CAPS short section labels only
    if (t.length < 40 &&
        t == t.toUpperCase() &&
        RegExp(
          r'^(ABSTRACT|INTRODUCTION|EXPERIMENTAL|METHODS|RESULTS|DISCUSSION|'
          r'CONCLUSION|REFERENCES|KEYWORDS)\b',
        ).hasMatch(t)) {
      return true;
    }
    // Avoid treating "Calculation of Antioxidant Activity:" as a major heading
    if (lower.contains('calculation') ||
        lower.contains('preparation') ||
        lower.contains('determination') ||
        lower.startsWith('table ') ||
        lower.startsWith('figure ')) {
      return false;
    }
    return false;
  }

  static bool _isJunkTextFragment(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    // Lone digits / list markers: "2 )", "3", "1.", "(a)"
    if (RegExp(r'^[\d٠-٩]+[\s.)\]]*$').hasMatch(t)) return true;
    if (RegExp(r'^\(?[a-zA-Z]\)?[\s.)]*$').hasMatch(t) && t.length <= 4) {
      return true;
    }
    if (t.length <= 2 && !RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(t)) {
      return true;
    }
    return false;
  }

  static bool _looksLikeContinuation(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (ScholarlyLayout.isFloatCaption(t) ||
        ScholarlyLayout.isFrontMatterLine(t)) {
      return false;
    }
    if (t.startsWith('.') || t.startsWith(',') || t.startsWith(';')) {
      return true;
    }
    // Starts lowercase → likely broken mid-sentence from Word
    final first = t[0];
    if (first.toLowerCase() == first &&
        RegExp(r'[a-z\u0600-\u06FF]').hasMatch(first)) {
      return true;
    }
    return false;
  }

  static int _letterCount(String text, RegExp re) => re.allMatches(text).length;

  /// English Abstract and Arabic الملخص must stay separate sections.
  static bool _scriptsConflict(String a, String b) {
    final arA = _letterCount(a, RegExp(r'[\u0600-\u06FF]'));
    final laA = _letterCount(a, RegExp(r'[A-Za-z]'));
    final arB = _letterCount(b, RegExp(r'[\u0600-\u06FF]'));
    final laB = _letterCount(b, RegExp(r'[A-Za-z]'));
    if (arA < 8 || arB < 8) return false;
    if (laA < 8 && laB < 8) return false;
    return (arA > laA) != (arB > laB);
  }

  static String _repairBrokenJoins(String text) {
    return text
        // "made\n.up to" / "made .up to"
        .replaceAllMapped(
          RegExp(r'(\w)\s*\n+\s*\.(\w)'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'(\w)\s+\.(\w)'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _normalizeKnownSectionHeading(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s*:+\s*$'), '');
    final lower = t.toLowerCase();
    if (RegExp(r'^(?:\d+\.?\s*)?abstract\b').hasMatch(lower) ||
        t.contains('الملخص')) {
      return 'Abstract';
    }
    if (RegExp(r'^(?:\d+\.?\s*)?(introduction|background)\b').hasMatch(lower) ||
        t.contains('المقدمة') ||
        t.contains('الخلفية')) {
      return 'Introduction';
    }
    if (RegExp(
          r'^(?:\d+\.?\s*)?(experimental|materials(\s+and\s+methods)?|methods?)\b',
        ).hasMatch(lower) ||
        t.contains('التجريبي') ||
        t.contains('المنهج') ||
        t.contains('المواد')) {
      return 'Experimental';
    }
    if (RegExp(r'^(?:\d+\.?\s*)?results?\b').hasMatch(lower) ||
        t.contains('النتائج')) {
      return 'Results';
    }
    if (RegExp(r'^(?:\d+\.?\s*)?discussion\b').hasMatch(lower) ||
        t.contains('المناقشة')) {
      return 'Discussion';
    }
    if (RegExp(r'^(?:\d+\.?\s*)?conclusions?\b').hasMatch(lower) ||
        t.contains('الخاتمة') ||
        t.contains('الاستنتاج')) {
      return 'Conclusion';
    }
    if (RegExp(r'^keywords?\b').hasMatch(lower)) return 'Keywords';
    if (RegExp(r'^references?\b').hasMatch(lower) || t.contains('المراجع')) {
      return 'References';
    }
    return t;
  }

  static void _warmImageSessionCache(List<ManuscriptBlock> blocks) {
    for (final block in blocks) {
      final url = block.imageUrl ?? '';
      if (url.startsWith('data:')) {
        _registerImageUri(block.id, url);
      }
      if (block.type == ManuscriptBlockType.table &&
          block.rowCellImages.isNotEmpty) {
        for (var r = 0; r < block.rowCellImages.length; r++) {
          for (var c = 0; c < block.rowCellImages[r].length; c++) {
            final cell = block.rowCellImages[r][c];
            if (cell.startsWith('data:')) {
              _registerImageUri('${block.id}_r${r}_c$c', cell);
            }
          }
        }
      }
    }
  }

  static List<ManuscriptBlock> _buildAcademicLayout(
    String bodyText, {
    List<ManuscriptBlock> mediaBlocks = const [],
  }) {
    final zones = _blocksFromPlainText(bodyText);
    if (mediaBlocks.isEmpty) return zones;

    final out = List<ManuscriptBlock>.from(zones);
    final media = mediaBlocks.map((b) {
      if (b.type == ManuscriptBlockType.table) {
        return ManuscriptBlock.normalizeTableLayout(b);
      }
      return b;
    }).toList();

    out.addAll(media);
    return out;
  }

  static bool _referenceLooksValid(PublishReference ref) {
    final text =
        ref.rawText.trim().isNotEmpty ? ref.rawText.trim() : ref.title.trim();
    if (RegExp(r'^\[\d+\]').hasMatch(text) && text.length >= 12) return true;
    if (RegExp(r'^\d+[.)]\s').hasMatch(text) && text.length >= 16) return true;
    return text.length >= 20 && _looksLikeReference(text);
  }

  static List<ManuscriptBlock> _blocksFromPlainText(String text) {
    if (text.trim().isEmpty) return const [];

    var idCounter = 0;
    String nextId() => 'txt_${DateTime.now().millisecondsSinceEpoch}_${idCounter++}';

    final mainText = text.trim();

    final abstractMatch = RegExp(
      r'(?:^|\n)\s*Abstract\s*:?\s*',
      caseSensitive: false,
    ).firstMatch(mainText);
    if (abstractMatch == null) {
      return [
        ManuscriptBlock(
          id: nextId(),
          type: ManuscriptBlockType.paragraph,
          text: mainText,
        ),
      ];
    }

    final titleAuthors = mainText.substring(0, abstractMatch.start).trim();
    final abstractEnd = _abstractZoneEnd(mainText, abstractMatch.start);
    final abstractKeywords =
        mainText.substring(abstractMatch.start, abstractEnd).trim();
    final bodyText = mainText.substring(abstractEnd).trim();

    final blocks = <ManuscriptBlock>[];
    if (titleAuthors.isNotEmpty) {
      blocks.add(ManuscriptBlock(
        id: nextId(),
        type: ManuscriptBlockType.paragraph,
        text: titleAuthors,
      ));
    }
    if (abstractKeywords.isNotEmpty) {
      blocks.add(ManuscriptBlock(
        id: nextId(),
        type: ManuscriptBlockType.paragraph,
        text: abstractKeywords,
      ));
    }
    if (bodyText.isNotEmpty) {
      blocks.add(ManuscriptBlock(
        id: nextId(),
        type: ManuscriptBlockType.paragraph,
        text: bodyText,
      ));
    }
    return blocks;
  }

  static int _abstractZoneEnd(String text, int abstractStart) {
    final afterAbstract = text.substring(abstractStart);

    final introMatch = RegExp(
      r'(?:^|\n)\s*(?:\d+\.?\s*)?(Introduction|Background|INTRODUCTION)\b',
      caseSensitive: false,
    ).firstMatch(afterAbstract);
    if (introMatch != null) {
      return abstractStart + introMatch.start;
    }

    final kwMatch = RegExp(
      r'(?:^|\n)\s*Keywords?\s*:?',
      caseSensitive: false,
    ).firstMatch(afterAbstract);
    if (kwMatch != null) {
      final tail = afterAbstract.substring(kwMatch.end);
      final nextSection = RegExp(
        r'(?:^|\n)\s*(?:\d+\.?\s+\w|Introduction|INTRODUCTION|Background|Materials|Methods|Results|Discussion)',
        caseSensitive: false,
      ).firstMatch(tail);
      if (nextSection != null) {
        return abstractStart + kwMatch.end + nextSection.start;
      }
      final paraEnd = RegExp(r'\n\s*\n').firstMatch(tail);
      if (paraEnd != null) {
        return abstractStart + kwMatch.end + paraEnd.end;
      }
      return abstractStart + kwMatch.end + tail.length;
    }

    final numberedStart = RegExp(
      r'(?:^|\n)\s*(?:1[\.\)]\s+\w|\d+\.?\s+(?:Materials|Methods|Results))',
      caseSensitive: false,
    ).firstMatch(afterAbstract);
    if (numberedStart != null) {
      return abstractStart + numberedStart.start;
    }

    return abstractStart + afterAbstract.length;
  }

  /// Keep the imported block sequence. Only peel bibliography lines off the end.
  static List<ManuscriptBlock> structureImportedBlocks(
    List<ManuscriptBlock> blocks,
  ) {
    if (blocks.isEmpty) return blocks;
    final expanded = _expandEmbeddedSectionHeadings(blocks);
    final attached = _attachMediaCaptions(expanded);
    final bibIdx = _bibliographyHeadingIndex(attached);
    if (bibIdx == null) return attached;

    final heading = attached[bibIdx];
    return [
      ...attached.sublist(0, bibIdx),
      heading,
      ..._keepPostBibliographyContent(attached.sublist(bibIdx + 1)),
    ];
  }

  static List<ManuscriptBlock> _expandEmbeddedSectionHeadings(
    List<ManuscriptBlock> blocks,
  ) {
    var idCounter = 0;
    String nextId() => 'sec_${DateTime.now().millisecondsSinceEpoch}_${idCounter++}';

    final out = <ManuscriptBlock>[];
    for (final block in blocks) {
      if (block.type == ManuscriptBlockType.paragraph) {
        final t = block.text.trim();
        if (t.contains('\n')) {
          final lines = t.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
          if (lines.any(_isPrintedHeading)) {
            for (final line in lines) {
              out.add(ManuscriptBlock(
                id: nextId(),
                type: _isPrintedHeading(line)
                    ? ManuscriptBlockType.heading
                    : ManuscriptBlockType.paragraph,
                text: line,
              ));
            }
            continue;
          }
        }
      }
      out.add(block);
    }
    return out;
  }

  static String _blockPlainText(ManuscriptBlock block) {
    return switch (block.type) {
      ManuscriptBlockType.paragraph ||
      ManuscriptBlockType.heading ||
      ManuscriptBlockType.equation =>
        block.text,
      ManuscriptBlockType.table => block.caption ?? '',
      ManuscriptBlockType.image => block.caption ?? '',
    };
  }

  static bool _isAbstractBlock(ManuscriptBlock block) {
    final t = _blockPlainText(block).trim();
    return RegExp(r'^abstract\b', caseSensitive: false).hasMatch(t) ||
        t.toLowerCase() == 'abstract' ||
        RegExp(r'^الملخص\b').hasMatch(t);
  }

  static bool _isKeywordsBlock(ManuscriptBlock block) {
    final t = AcademicText.stripBidi(_blockPlainText(block)).trim();
    return RegExp(r'^keywords?\b', caseSensitive: false).hasMatch(t) ||
        RegExp(r'^(?:الكلمات(?:\s+المفتاحية|\s+الدالة)?|كلمات مفتاحية)\b')
            .hasMatch(t);
  }

  static bool _isIntroductionBlock(ManuscriptBlock block) {
    final t = _blockPlainText(block).trim();
    return RegExp(
      r'^(?:\d+\.?\s*)?(Introduction|Background)\b',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static bool _isBibliographyBlock(ManuscriptBlock block) {
    return _isBibliographyHeadingLine(_blockPlainText(block));
  }

  /// Only a printed References heading — not a run of official-method lines.
  static int? _bibliographyHeadingIndex(List<ManuscriptBlock> blocks) {
    int? headingAt;
    for (var i = 0; i < blocks.length; i++) {
      if (_isBibliographyBlock(blocks[i])) headingAt = i;
    }
    return headingAt;
  }

  /// Last IMRaD heading — bibliography harvest must not start before this.
  static int? _lastImradHeadingIndex(List<ManuscriptBlock> blocks) {
    int? last;
    for (var i = 0; i < blocks.length; i++) {
      final t = AcademicText.stripBidi(blocks[i].text).trim();
      if (!_isMajorSectionHeading(t)) continue;
      if (_isAbstractBlock(blocks[i]) ||
          _isKeywordsBlock(blocks[i]) ||
          _isBibliographyHeadingLine(t)) {
        continue;
      }
      last = i;
    }
    return last;
  }

  static int _findBibliographyIndex(List<ManuscriptBlock> blocks) {
    int? headingAt;
    for (var i = 0; i < blocks.length; i++) {
      if (_isBibliographyBlock(blocks[i])) headingAt = i;
    }
    if (headingAt != null) return headingAt;
    return _lastBibliographyRunIndex(blocks) ?? blocks.length;
  }

  /// Last run of bibliographic paragraphs — the end-of-file list, not [n] in Methods.
  static int? _lastBibliographyRunIndex(List<ManuscriptBlock> blocks) {
    if (blocks.length < 3) return null;
    final from = (blocks.length * 0.22).floor();
    var runStart = -1;
    var runLen = 0;
    int? lastStart;
    for (var i = from; i < blocks.length; i++) {
      final block = blocks[i];
      final t = block.text.trim();
      final isBib = block.type == ManuscriptBlockType.paragraph &&
          (_isStandaloneBibliographyEntry(t) ||
              CitationLinker.looksLikeBibliographyLine(t) ||
              _splitStandaloneBibliographyEntries(t).length >= 2);
      if (isBib) {
        if (runStart < 0) runStart = i;
        final pieces = _splitStandaloneBibliographyEntries(t);
        runLen += pieces.length >= 2 ? pieces.length : 1;
      } else if (block.type == ManuscriptBlockType.heading &&
          _isBibliographyHeadingLine(t)) {
        if (runLen >= 3) lastStart = runStart;
        break;
      } else if (block.type != ManuscriptBlockType.paragraph || t.isNotEmpty) {
        if (runLen >= 3) lastStart = runStart;
        runStart = -1;
        runLen = 0;
      }
    }
    if (runLen >= 3) lastStart = runStart;
    return lastStart;
  }

  static int? _findAbstractIndex(List<ManuscriptBlock> blocks) {
    for (var i = 0; i < blocks.length; i++) {
      if (_isAbstractBlock(blocks[i])) return i;
      final t = blocks[i].text.trim();
      if (RegExp(r'^abstract\b', caseSensitive: false).hasMatch(t)) return i;
      if (RegExp(r'^الملخص\b').hasMatch(t)) return i;
    }
    return null;
  }

  static int? _findIntroductionIndex(List<ManuscriptBlock> blocks, int from) {
    for (var i = from; i < blocks.length; i++) {
      if (_isIntroductionBlock(blocks[i])) return i;
      final t = blocks[i].text.trim();
      if (RegExp(r'^1[\.\)]\s+\w').hasMatch(t) && t.length < 100) return i;
      if (i > from &&
          _isSectionHeading(t) &&
          !_isKeywordsBlock(blocks[i]) &&
          !_isAbstractBlock(blocks[i])) {
        return i;
      }
    }
    return null;
  }

  static List<ManuscriptBlock> _structureTitlePageBlocks(
    List<ManuscriptBlock> blocks,
    String Function() nextId,
  ) {
    final out = <ManuscriptBlock>[];

    for (final block in blocks) {
      switch (block.type) {
        case ManuscriptBlockType.equation:
          out.add(block);
        case ManuscriptBlockType.image:
          out.add(block);
        case ManuscriptBlockType.paragraph:
        case ManuscriptBlockType.heading:
          final segments =
              DocxScientificExtractor.decomposeTitlePageText(block.text);
          if (segments.isEmpty) {
            final t = block.text.trim();
            if (t.isNotEmpty &&
                !DocxScientificExtractor.isEquationFragment(t)) {
              out.add(ManuscriptBlock(
                id: nextId(),
                type: ManuscriptBlockType.paragraph,
                text: t,
              ));
            }
            break;
          }
          for (final seg in segments) {
            if (seg.text.trim().isEmpty) continue;
            switch (seg.kind) {
              case TitlePageSegmentKind.equation:
                out.add(ManuscriptBlock(
                  id: nextId(),
                  type: ManuscriptBlockType.equation,
                  text: DocxScientificExtractor.cleanScientificText(seg.text),
                  imageUrl: block.imageUrl,
                ));
              case TitlePageSegmentKind.title:
                out.add(ManuscriptBlock(
                  id: nextId(),
                  type: ManuscriptBlockType.heading,
                  text: seg.text.trim(),
                ));
              case TitlePageSegmentKind.authors:
                out.add(ManuscriptBlock(
                  id: nextId(),
                  type: ManuscriptBlockType.paragraph,
                  text: seg.text.trim(),
                ));
              case TitlePageSegmentKind.body:
                if (!DocxScientificExtractor.isEquationFragment(seg.text)) {
                  out.add(ManuscriptBlock(
                    id: nextId(),
                    type: ManuscriptBlockType.paragraph,
                    text: seg.text.trim(),
                  ));
                }
            }
          }
        case ManuscriptBlockType.table:
          out.add(block);
      }
    }
    return out;
  }

  static String? _extractTitleFromBlocks(List<ManuscriptBlock> blocks) {
    for (final block in blocks) {
      if (block.type == ManuscriptBlockType.heading) {
        final t = block.text.trim();
        if (DocxScientificExtractor.isPaperTitle(t)) return t;
      }
    }
    for (final block in blocks) {
      final t = block.text.trim();
      if (DocxScientificExtractor.isPaperTitle(t)) return t;
      final extracted = DocxScientificExtractor.extractPaperTitle(t);
      if (extracted != null) return extracted;
    }
    return null;
  }

  static List<ManuscriptBlock> _structureBodyWithMedia(
    List<ManuscriptBlock> blocks,
    String Function() nextId,
  ) {
    if (blocks.isEmpty) return const [];

    final out = <ManuscriptBlock>[];

    void emitHeading(String text) {
      out.add(ManuscriptBlock(
        id: nextId(),
        type: ManuscriptBlockType.heading,
        text: text,
      ));
    }

    void emitParagraph(String text) {
      final t = text.trim();
      if (t.isEmpty) return;
      out.add(ManuscriptBlock(
        id: nextId(),
        type: ManuscriptBlockType.paragraph,
        text: t,
      ));
    }

    for (final block in blocks) {
      switch (block.type) {
        case ManuscriptBlockType.heading:
          final t = block.text.trim();
          if (t.isNotEmpty) emitHeading(t);
        case ManuscriptBlockType.paragraph:
          final t = block.text.trim();
          if (t.isEmpty || _isJunkTextFragment(t)) break;
          if (_isPrintedHeading(t)) {
            emitHeading(t);
          } else if (DocxScientificExtractor.needsScientificSplit(t)) {
            for (final seg
                in DocxScientificExtractor.splitRunOnScientificParagraph(t)) {
              if (seg.isEquation) {
                out.add(ManuscriptBlock(
                  id: nextId(),
                  type: ManuscriptBlockType.equation,
                  text: seg.text,
                ));
              } else {
                for (final part in DocxScientificExtractor.splitTextBySectionHeadings(
                  seg.text,
                  nextId,
                )) {
                  if (part.type == ManuscriptBlockType.heading &&
                      _isPrintedHeading(part.text)) {
                    emitHeading(part.text.trim());
                  } else if (!_isJunkTextFragment(part.text)) {
                    emitParagraph(part.text);
                  }
                }
              }
            }
          } else {
            for (final part in DocxScientificExtractor.splitTextBySectionHeadings(
              t,
              nextId,
            )) {
              if (part.type == ManuscriptBlockType.heading &&
                  _isPrintedHeading(part.text)) {
                emitHeading(part.text.trim());
              } else if (!_isJunkTextFragment(part.text)) {
                emitParagraph(part.text);
              }
            }
          }
        case ManuscriptBlockType.equation:
          out.add(block);
        case ManuscriptBlockType.table:
          out.add(ManuscriptBlock.normalizeTableLayout(block));
        case ManuscriptBlockType.image:
          out.add(block);
      }
    }
    return out;
  }

  static int _abstractBlockZoneEnd(List<ManuscriptBlock> blocks, int abstractIdx) {
    for (var i = abstractIdx + 1; i < blocks.length; i++) {
      if (_isKeywordsBlock(blocks[i])) {
        return (i + 1).clamp(abstractIdx + 1, blocks.length);
      }
    }
    return (abstractIdx + 1).clamp(abstractIdx + 1, blocks.length);
  }

  static List<ManuscriptBlock> _structureAcademicPaper(List<ManuscriptBlock> blocks) {
    var idCounter = 0;
    String nextId() => 'paper_${DateTime.now().millisecondsSinceEpoch}_${idCounter++}';

    final bibIdx = _findBibliographyIndex(blocks);
    final content = blocks.sublist(0, bibIdx);
    // Keep figures/tables/equations/appendices that appear after References.
    final afterBibliography = bibIdx < blocks.length
        ? _keepPostBibliographyContent(blocks.sublist(bibIdx + 1))
        : const <ManuscriptBlock>[];
    if (content.isEmpty) {
      return [...blocks, ...afterBibliography];
    }

    final abstractIdx = _findAbstractIndex(content);
    if (abstractIdx == null) {
      return [
        ..._structureBodyWithMedia(content, nextId),
        ...afterBibliography,
      ];
    }

    final introIdx = _findIntroductionIndex(content, abstractIdx + 1);
    final bodyStart = introIdx ?? _abstractBlockZoneEnd(content, abstractIdx);

    final titlePageBlocks = _structureTitlePageBlocks(
      content.sublist(0, abstractIdx),
      nextId,
    );
    final abstractKeywords = _structureSectionZone(
      content.sublist(abstractIdx, bodyStart),
      nextId,
    );
    final bodyBlocks = bodyStart < content.length
        ? _structureBodyWithMedia(content.sublist(bodyStart), nextId)
        : const <ManuscriptBlock>[];

    final result = <ManuscriptBlock>[];
    result.addAll(titlePageBlocks);
    result.addAll(abstractKeywords);
    result.addAll(bodyBlocks);
    result.addAll(afterBibliography);

    return result.isEmpty ? content : result;
  }

  /// After the References heading: keep media + appendix prose; drop bib lines.
  static List<ManuscriptBlock> _keepPostBibliographyContent(
    List<ManuscriptBlock> blocks,
  ) {
    final out = <ManuscriptBlock>[];
    for (final block in blocks) {
      if (_isMediaBlock(block)) {
        out.add(block);
        continue;
      }
      if (_isBibliographyBlock(block)) continue;
      final t = block.text.trim();
      if (t.isEmpty) continue;
      if (_isBibliographyHeadingLine(t)) continue;
      if (_isStandaloneBibliographyEntry(t)) continue;
      if (_splitStandaloneBibliographyEntries(t).length >= 2) continue;
      if (_looksLikeReference(t)) continue;
      if (_isAppendixHeading(t) ||
          block.type == ManuscriptBlockType.heading ||
          t.length >= 25) {
        out.add(block);
      }
    }
    return out;
  }

  static bool _isAppendixHeading(String text) {
    final t = text.trim();
    if (t.length > 90) return false;
    return RegExp(
      r'^(?:\d+\.?\s*)?(Appendix|Supplementary|Supporting Information|'
      r'ملحق|الملاحق|مواد تكميلية)\b',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static bool _isBodyStartHeading(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 120) return false;
    return RegExp(
      r'^(?:\d+\.?\s*)?(Abstract|Introduction|Background|Experimental|'
      r'Materials|Methods|Results|Discussion|الملخص|المقدمة)\b',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static List<ManuscriptBlock> _structureSectionZone(
    List<ManuscriptBlock> blocks,
    String Function() nextId,
  ) {
    final out = <ManuscriptBlock>[];
    for (final block in blocks) {
      switch (block.type) {
        case ManuscriptBlockType.heading:
          out.add(block);
        case ManuscriptBlockType.paragraph:
          out.addAll(
            DocxScientificExtractor.splitTextBySectionHeadings(
              block.text,
              nextId,
            ),
          );
        case ManuscriptBlockType.equation:
        case ManuscriptBlockType.table:
        case ManuscriptBlockType.image:
          out.add(block);
      }
    }
    return out;
  }

  static bool _isSectionHeading(String line) {
    return _isMajorSectionHeading(line);
  }

  static bool _isTableCaption(String text) =>
      ScholarlyLayout.isTableCaption(text);

  static bool _isFigureCaption(String text) =>
      ScholarlyLayout.isFigureCaption(text);

  static int _dataUriByteLength(String uri) {
    if (!uri.startsWith('data:')) return 0;
    final comma = uri.indexOf(',');
    if (comma < 0) return 0;
    try {
      return base64Decode(uri.substring(comma + 1)).length;
    } catch (_) {
      return 0;
    }
  }

  static void _registerImageUri(String blockId, String uri) {
    if (blockId.isNotEmpty && uri.startsWith('data:')) {
      ManuscriptImageSessionCache.instance.register(blockId, uri);
    }
  }

  /// OLE previews (chromatograms) were mis-tagged as equations when they carry imageUrl only.
  static List<ManuscriptBlock> _reclassifyImageEquations(
    List<ManuscriptBlock> blocks,
  ) {
    return blocks.map((block) {
      if (block.type != ManuscriptBlockType.equation) return block;
      if (block.ommlXml != null && block.ommlXml!.trim().isNotEmpty) {
        return block;
      }
      final text = block.text.trim();
      if (text.isNotEmpty &&
          !DocxScientificExtractor.isEquationPlaceholder(text)) {
        return block;
      }
      final url = block.imageUrl ?? '';
      if (url.startsWith('data:') || url.startsWith('http')) {
        return block.copyWith(type: ManuscriptBlockType.image);
      }
      return block;
    }).toList();
  }

  /// Link orphan "Figure N" captions to unused large images from word/media (chromatograms).
  static List<ManuscriptBlock> _recoverOrphanFigureImages({
    required List<ManuscriptBlock> blocks,
    required List<String> mediaPool,
    required Set<String> usedVisualUris,
    required String Function() nextId,
  }) {
    bool hasFigureMedia(ManuscriptBlock b) {
      if (b.type == ManuscriptBlockType.image) {
        return (b.imageUrl?.isNotEmpty ?? false);
      }
      if (b.type == ManuscriptBlockType.equation) {
        final url = b.imageUrl ?? '';
        return url.startsWith('data:') || url.startsWith('http');
      }
      return false;
    }

    final unused = mediaPool.where((u) => !usedVisualUris.contains(u)).toList()
      ..sort(
        (a, b) => _dataUriByteLength(b).compareTo(_dataUriByteLength(a)),
      );
    if (unused.isEmpty) return blocks;

    final out = List<ManuscriptBlock>.from(blocks);
    var poolIdx = 0;

    for (var i = 0; i < out.length; i++) {
      final block = out[i];
      if (block.type != ManuscriptBlockType.paragraph ||
          !_isFigureCaption(block.text)) {
        continue;
      }
      if (i > 0 && hasFigureMedia(out[i - 1])) continue;
      if (i + 1 < out.length && hasFigureMedia(out[i + 1])) continue;
      if (poolIdx >= unused.length) break;

      final uri = unused[poolIdx++];
      usedVisualUris.add(uri);
      final id = nextId();
      _registerImageUri(id, uri);
      out[i] = ManuscriptBlock(
        id: id,
        type: ManuscriptBlockType.image,
        imageUrl: uri,
        caption: block.text.trim(),
      );
    }
    return out;
  }

  static List<ManuscriptBlock> _attachMediaCaptions(
    List<ManuscriptBlock> blocks,
  ) {
    final out = <ManuscriptBlock>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      // Table caption before table
      if (block.type == ManuscriptBlockType.paragraph &&
          i + 1 < blocks.length &&
          blocks[i + 1].type == ManuscriptBlockType.table &&
          _isTableCaption(block.text)) {
        final table = ManuscriptBlock.normalizeTableLayout(
          blocks[i + 1].copyWith(caption: block.text.trim()),
        );
        out.add(table);
        i++;
        continue;
      }

      // Figure caption before image (or picture-like equation)
      if (block.type == ManuscriptBlockType.paragraph &&
          i + 1 < blocks.length &&
          _isFigureCaption(block.text)) {
        final next = blocks[i + 1];
        if (next.type == ManuscriptBlockType.image ||
            (next.type == ManuscriptBlockType.equation &&
                (next.imageUrl?.isNotEmpty ?? false))) {
          final media = next.type == ManuscriptBlockType.image
              ? next
              : next.copyWith(type: ManuscriptBlockType.image);
          out.add(media.copyWith(caption: block.text.trim()));
          i++;
          continue;
        }
      }

      // Figure caption after image (or picture-like equation)
      if (i + 1 < blocks.length &&
          blocks[i + 1].type == ManuscriptBlockType.paragraph &&
          _isFigureCaption(blocks[i + 1].text)) {
        if (block.type == ManuscriptBlockType.image) {
          out.add(block.copyWith(caption: blocks[i + 1].text.trim()));
          i++;
          continue;
        }
        if (block.type == ManuscriptBlockType.equation &&
            (block.imageUrl?.isNotEmpty ?? false)) {
          out.add(block.copyWith(
            type: ManuscriptBlockType.image,
            caption: blocks[i + 1].text.trim(),
          ));
          i++;
          continue;
        }
      }

      if (block.type == ManuscriptBlockType.table) {
        out.add(ManuscriptBlock.normalizeTableLayout(block));
      } else {
        out.add(block);
      }
    }
    return out;
  }

  static List<ManuscriptBlock> _extractDocxBlocks(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) return const [];

    try {
      final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      var bodies = doc.findAllElements('body').toList();
      if (bodies.isEmpty) {
        bodies = doc.findAllElements('w:body').toList();
      }
      if (bodies.isEmpty) return const [];
      final body = bodies.first;

      final rels = _loadDocxRels(archive);
      final blocks = <ManuscriptBlock>[];
      var idCounter = 0;
      var imageCount = 0;
      const maxLocalImages = ManuscriptUploadService.maxImportImagesPerBatch;
      final usedVisualUris = <String>{};
      String nextId() => 'docx_${DateTime.now().millisecondsSinceEpoch}_${idCounter++}';

      void onVisualUsed(String uri) {
        usedVisualUris.add(uri);
        imageCount++;
      }

      final mediaPool = DocxScientificExtractor.indexMediaPool(
        archive,
        _dataUriFromMediaFile,
      );

      var region = _CiteImportRegion.frontMatter;
      for (final child in body.children.whereType<XmlElement>()) {
        final tag = child.localName;

        if (tag == 'p') {
          final plain = _paragraphPlainText(child).trim();
          if (_isBibliographyParagraph(child) ||
              _isBibliographyHeadingLine(plain)) {
            region = _CiteImportRegion.bibliography;
            continue;
          }
          if (region == _CiteImportRegion.frontMatter &&
              _isBodyStartHeading(plain)) {
            region = _CiteImportRegion.body;
          }
        }

        if (region == _CiteImportRegion.bibliography && tag == 'p') {
          final plain = _paragraphPlainText(child).trim();
          if (_isAppendixHeading(plain)) {
            region = _CiteImportRegion.body;
          } else {
            final paraBlocks = _blocksFromDocxParagraph(
              child,
              archive: archive,
              rels: rels,
              nextId: nextId,
              onVisualUsed: onVisualUsed,
              imageCount: () => imageCount,
              maxLocalImages: maxLocalImages,
              region: _CiteImportRegion.bibliography,
            );
            blocks.addAll(paraBlocks.where(_isMediaBlock));
            if (_isFigureCaption(plain) ||
                _isTableCaption(plain) ||
                (plain.isNotEmpty &&
                    !_looksLikeReference(plain) &&
                    plain.length >= 25)) {
              blocks.add(ManuscriptBlock(
                id: nextId(),
                type: (_isHeadingParagraph(child) || _isAppendixHeading(plain))
                    ? ManuscriptBlockType.heading
                    : ManuscriptBlockType.paragraph,
                text: plain,
              ));
            }
            continue;
          }
        }

        // After References: still keep tables/drawings/equations.
        if (region == _CiteImportRegion.bibliography &&
            tag != 'tbl' &&
            tag != 'drawing' &&
            tag != 'pict' &&
            tag != 'object' &&
            tag != 'oMath' &&
            tag != 'oMathPara' &&
            tag != 'sdt' &&
            tag != 'AlternateContent' &&
            tag != 'p') {
          continue;
        }

        _appendDocxElement(
          child,
          archive: archive,
          rels: rels,
          blocks: blocks,
          nextId: nextId,
          imageCount: () => imageCount,
          onVisualUsed: onVisualUsed,
          maxLocalImages: maxLocalImages,
          usedVisualUris: usedVisualUris,
          mediaPool: mediaPool,
          region: region,
        );
      }

      _appendNotesFromPart(
        archive,
        partPath: 'word/footnotes.xml',
        noteLocalName: 'footnote',
        labelAr: 'حاشية',
        labelEn: 'Footnote',
        blocks: blocks,
        nextId: nextId,
        rels: rels,
        imageCount: () => imageCount,
        onVisualUsed: onVisualUsed,
        maxLocalImages: maxLocalImages,
        usedVisualUris: usedVisualUris,
        mediaPool: mediaPool,
      );
      _appendNotesFromPart(
        archive,
        partPath: 'word/endnotes.xml',
        noteLocalName: 'endnote',
        labelAr: 'تعليق ختامي',
        labelEn: 'Endnote',
        blocks: blocks,
        nextId: nextId,
        rels: rels,
        imageCount: () => imageCount,
        onVisualUsed: onVisualUsed,
        maxLocalImages: maxLocalImages,
        usedVisualUris: usedVisualUris,
        mediaPool: mediaPool,
      );

      var result = _reclassifyImageEquations(blocks);
      result = _fillEmptyTableDrawings(
        blocks: result,
        mediaPool: mediaPool,
        usedVisualUris: usedVisualUris,
      );
      result = _recoverOrphanFigureImages(
        blocks: result,
        mediaPool: mediaPool,
        usedVisualUris: usedVisualUris,
        nextId: nextId,
      );
      // Do not dump leftover word/media at the end — that pulled figures
      // out of tables and stacked them before References.
      return result;
    } catch (_) {
      return const [];
    }
  }

  static String? _dataUriFromMediaFile(ArchiveFile file) {
    final name = file.name.replaceAll('\\', '/').toLowerCase();
    if (!_isRenderableImageTarget(name)) return null;
    final bytes = Uint8List.fromList(file.content as List<int>);
    if (bytes.isEmpty) return null;
    var ext = file.name.split('.').last.toLowerCase();
    if (ext == 'emz' || ext == 'wmz') {
      try {
        final decoded = Uint8List.fromList(GZipDecoder().decodeBytes(bytes));
        ext = ext == 'emz' ? 'emf' : 'wmf';
        return _bytesToDataUri(decoded, extHint: ext);
      } catch (_) {
        return null;
      }
    }
    return _bytesToDataUri(bytes, extHint: ext);
  }

  static Map<String, String> _loadDocxRels(Archive archive) {
    final rels = <String, String>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      if (!name.contains('_rels/') || !name.endsWith('.rels')) continue;
      try {
        final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));
        for (final rel in doc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id == null || target == null || target.isEmpty) continue;
          rels.putIfAbsent(id, () => target);
        }
      } catch (_) {}
    }
    // Primary document rels override duplicates last (prefer document.xml.rels).
    final docRels = archive.findFile('word/_rels/document.xml.rels');
    if (docRels != null) {
      try {
        final doc = XmlDocument.parse(utf8.decode(docRels.content as List<int>));
        for (final rel in doc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null) rels[id] = target;
        }
      } catch (_) {}
    }
    return rels;
  }

  /// Plain text inside Word shapes / text boxes (w:txbxContent).
  static List<String> _extractShapeTextBoxes(XmlElement node) {
    final out = <String>[];
    for (final txbx in node.findAllElements('txbxContent')) {
      final buffer = StringBuffer();
      for (final child in txbx.children.whereType<XmlElement>()) {
        if (child.localName != 'p') continue;
        final part = _paragraphPlainText(child).trim();
        if (part.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(part);
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) out.add(text);
    }
    return out;
  }

  static void _appendNotesFromPart(
    Archive archive, {
    required String partPath,
    required String noteLocalName,
    required String labelAr,
    required String labelEn,
    required List<ManuscriptBlock> blocks,
    required String Function() nextId,
    required Map<String, String> rels,
    required int Function() imageCount,
    required void Function(String uri) onVisualUsed,
    required int maxLocalImages,
    required Set<String> usedVisualUris,
    required List<String> mediaPool,
  }) {
    final entry = archive.findFile(partPath);
    if (entry == null) return;
    try {
      final doc = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      var noteIndex = 0;
      for (final note in doc.findAllElements(noteLocalName)) {
        final type = note.getAttribute('type') ??
            note.getAttribute('w:type') ??
            '';
        if (type == 'separator' || type == 'continuationSeparator') continue;
        noteIndex++;
        for (final child in note.children.whereType<XmlElement>()) {
          if (child.localName == 'p') {
            final text = _paragraphPlainText(child).trim();
            final media = _blocksFromDocxParagraph(
              child,
              archive: archive,
              rels: rels,
              nextId: nextId,
              onVisualUsed: onVisualUsed,
              imageCount: imageCount,
              maxLocalImages: maxLocalImages,
            ).where(_isMediaBlock);
            blocks.addAll(media);
            if (text.isNotEmpty) {
              blocks.add(ManuscriptBlock(
                id: nextId(),
                type: ManuscriptBlockType.paragraph,
                text: appTr(
                  '[$labelAr $noteIndex] $text',
                  '[$labelEn $noteIndex] $text',
                ),
              ));
            }
          } else {
            _appendDocxElement(
              child,
              archive: archive,
              rels: rels,
              blocks: blocks,
              nextId: nextId,
              imageCount: imageCount,
              onVisualUsed: onVisualUsed,
              maxLocalImages: maxLocalImages,
              usedVisualUris: usedVisualUris,
              mediaPool: mediaPool,
            );
          }
        }
      }
    } catch (_) {
      // Malformed notes part — ignore.
    }
  }

  static bool _appendDocxElement(
    XmlElement element, {
    required Archive archive,
    required Map<String, String> rels,
    required List<ManuscriptBlock> blocks,
    required String Function() nextId,
    required int Function() imageCount,
    required void Function(String uri) onVisualUsed,
    required int maxLocalImages,
    required Set<String> usedVisualUris,
    required List<String> mediaPool,
    _CiteImportRegion region = _CiteImportRegion.body,
  }) {
    final tag = element.localName;

    void addImagesFrom(XmlElement node) {
      if (imageCount() >= maxLocalImages) return;
      for (final imageData in _extractAllEmbeddedImages(node, archive, rels)) {
        if (imageCount() >= maxLocalImages) break;
        onVisualUsed(imageData);
        final id = nextId();
        _registerImageUri(id, imageData);
        final extent = _drawingExtentEmu(element);
        blocks.add(ManuscriptBlock(
          id: id,
          type: ManuscriptBlockType.image,
          imageUrl: imageData,
          imageWidthEmu: extent?.$1,
          imageHeightEmu: extent?.$2,
        ));
      }
    }

    if (tag == 'p') {
      final paragraphBlocks = _blocksFromDocxParagraph(
        element,
        archive: archive,
        rels: rels,
        nextId: nextId,
        onVisualUsed: onVisualUsed,
        imageCount: imageCount,
        maxLocalImages: maxLocalImages,
        region: region,
      );
      if (paragraphBlocks.isNotEmpty) {
        blocks.addAll(paragraphBlocks);
        return false;
      }

      final text = _paragraphPlainText(element).trim();
      if (text.isNotEmpty &&
          !DocxScientificExtractor.isEquationPlaceholder(text)) {
        blocks.add(ManuscriptBlock(
          id: nextId(),
          type: _isHeadingParagraph(element)
              ? ManuscriptBlockType.heading
              : ManuscriptBlockType.paragraph,
          text: text,
        ));
      }
      return false;
    }

    if (tag == 'tbl') {
      final parsed = _parseDocxTableWithImages(element, archive, rels);
      if (parsed.rows.isNotEmpty) {
        for (final row in parsed.rowCellImages) {
          for (final url in row) {
            if (url.isNotEmpty) usedVisualUris.add(url);
          }
        }
        blocks.add(ManuscriptBlock(
          id: nextId(),
          type: ManuscriptBlockType.table,
          rows: parsed.rows,
          rowCellImages: parsed.rowCellImages,
          colSpans: parsed.colSpans,
          rowSpans: parsed.rowSpans,
          columnWidthsPct: parsed.columnWidthsPct,
        ));
      }
      return false;
    }

    if (tag == 'oMathPara' || tag == 'oMath') {
      final eq = _ommlPlainText(element);
      if (eq.isNotEmpty) {
        blocks.add(_equationBlock(nextId: nextId, math: element));
      }
      return false;
    }

    if (tag == 'sdt') {
      for (final content in element.findAllElements('sdtContent')) {
        for (final inner in content.children.whereType<XmlElement>()) {
          if (_appendDocxElement(
            inner,
            archive: archive,
            rels: rels,
            blocks: blocks,
            nextId: nextId,
            imageCount: imageCount,
            onVisualUsed: onVisualUsed,
            maxLocalImages: maxLocalImages,
            usedVisualUris: usedVisualUris,
            mediaPool: mediaPool,
            region: region,
          )) {
            return true;
          }
        }
      }
      return false;
    }

    // Floating drawings / shapes / OLE previews.
    if (tag == 'drawing' || tag == 'pict' || tag == 'object') {
      addImagesFrom(element);
      for (final shapeText in _extractShapeTextBoxes(element)) {
        blocks.add(ManuscriptBlock(
          id: nextId(),
          type: ManuscriptBlockType.paragraph,
          text: shapeText,
        ));
      }
      return false;
    }

    if (tag == 'AlternateContent') {
      // Choice may be a live OLE drawing with no raster. Fall back to VML.
      final beforeImages = imageCount();
      XmlElement? fallback;
      for (final branch in element.children.whereType<XmlElement>()) {
        if (branch.localName == 'Fallback') {
          fallback = branch;
          continue;
        }
        if (branch.localName != 'Choice') continue;
        for (final inner in branch.children.whereType<XmlElement>()) {
          _appendDocxElement(
            inner,
            archive: archive,
            rels: rels,
            blocks: blocks,
            nextId: nextId,
            imageCount: imageCount,
            onVisualUsed: onVisualUsed,
            maxLocalImages: maxLocalImages,
            usedVisualUris: usedVisualUris,
            mediaPool: mediaPool,
            region: region,
          );
        }
      }
      if (imageCount() == beforeImages && fallback != null) {
        for (final inner in fallback.children.whereType<XmlElement>()) {
          _appendDocxElement(
            inner,
            archive: archive,
            rels: rels,
            blocks: blocks,
            nextId: nextId,
            imageCount: imageCount,
            onVisualUsed: onVisualUsed,
            maxLocalImages: maxLocalImages,
            usedVisualUris: usedVisualUris,
            mediaPool: mediaPool,
            region: region,
          );
        }
      }
      if (imageCount() == beforeImages) {
        addImagesFrom(element);
      }
      return false;
    }

    // Nested containers (content controls, track changes, custom XML).
    if (tag == 'body' ||
        tag == 'tc' ||
        tag == 'txbxContent' ||
        tag == 'customXml' ||
        tag == 'ins' ||
        tag == 'smartTag' ||
        tag == 'dir' ||
        tag == 'bdo' ||
        tag == 'moveFrom' ||
        tag == 'moveTo' ||
        tag == 'sdtContent') {
      for (final inner in element.children.whereType<XmlElement>()) {
        _appendDocxElement(
          inner,
          archive: archive,
          rels: rels,
          blocks: blocks,
          nextId: nextId,
          imageCount: imageCount,
          onVisualUsed: onVisualUsed,
          maxLocalImages: maxLocalImages,
          usedVisualUris: usedVisualUris,
          mediaPool: mediaPool,
          region: region,
        );
      }
      return false;
    }
    // Unknown wrapper that still holds paragraphs / tables.
    final wrapsBlocks = element.children.whereType<XmlElement>().any((c) {
      final n = c.localName;
      return n == 'p' ||
          n == 'tbl' ||
          n == 'sdt' ||
          n == 'customXml' ||
          n == 'ins';
    });
    if (wrapsBlocks) {
      for (final inner in element.children.whereType<XmlElement>()) {
        _appendDocxElement(
          inner,
          archive: archive,
          rels: rels,
          blocks: blocks,
          nextId: nextId,
          imageCount: imageCount,
          onVisualUsed: onVisualUsed,
          maxLocalImages: maxLocalImages,
          usedVisualUris: usedVisualUris,
          mediaPool: mediaPool,
          region: region,
        );
      }
    }
    return false;
  }

  static Iterable<XmlElement> _descendantsNamed(XmlNode node, String localName) {
    return node.descendants
        .whereType<XmlElement>()
        .where((el) => el.localName == localName);
  }

  static List<String> _extractAllEmbeddedImages(
    XmlElement node,
    Archive archive,
    Map<String, String> rels,
  ) {
    final urls = <String>[];
    final seen = <String>{};

    void addUri(String? uri) {
      if (uri != null && seen.add(uri)) urls.add(uri);
    }

    // localName: a:blip / v:imagedata — findAllElements('blip') misses prefixes.
    for (final embed in _descendantsNamed(node, 'blip')) {
      addUri(_relationshipToDataUri(embed, archive, rels, idAttrs: const [
        'embed',
        'link',
      ]));
    }
    for (final img in _descendantsNamed(node, 'imagedata')) {
      addUri(_relationshipToDataUri(img, archive, rels, idAttrs: const [
        'id',
        'href',
        'relid',
      ]));
    }
    for (final fill in _descendantsNamed(node, 'fill')) {
      addUri(_relationshipToDataUri(fill, archive, rels, idAttrs: const [
        'id',
        'href',
        'relid',
      ]));
    }
    return urls;
  }

  static String? _dataUriFromRelId(
    String relId,
    Archive archive,
    Map<String, String> rels,
  ) {
    final target = rels[relId];
    if (target == null || target.isEmpty) return null;
    if (target.startsWith('http://') || target.startsWith('https://')) {
      return target;
    }
    if (!_isRenderableImageTarget(target)) return null;
    final media = _findMediaFile(archive, target);
    if (media == null) return null;
    var bytes = Uint8List.fromList(media.content as List<int>);
    if (bytes.isEmpty) return null;
    var ext = media.name.split('.').last.toLowerCase();
    if (ext == 'emz' || ext == 'wmz') {
      try {
        bytes = Uint8List.fromList(GZipDecoder().decodeBytes(bytes));
        ext = ext == 'emz' ? 'emf' : 'wmf';
      } catch (_) {
        return null;
      }
    }
    return _bytesToDataUri(bytes, extHint: ext);
  }

  static bool _isRenderableImageTarget(String target) {
    final t = target.replaceAll('\\', '/').toLowerCase();
    if (t.contains('/embeddings/') ||
        t.contains('oleobject') ||
        t.endsWith('.bin') ||
        t.endsWith('.cdx') ||
        t.endsWith('.cdxml') ||
        t.endsWith('.mol')) {
      return false;
    }
    return t.contains('/media/') ||
        RegExp(r'\.(png|jpe?g|gif|bmp|wdp|tiff?|emf|wmf|emz|wmz|svg)$')
            .hasMatch(t);
  }

  static String? _bytesToDataUri(Uint8List? bytes, {String? extHint}) {
    if (bytes == null || bytes.isEmpty) return null;
    final ext = extHint ?? _guessImageExt(bytes);
    final mime = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'tif' || 'tiff' => 'image/tiff',
      'emf' => 'image/x-emf',
      'wmf' => 'image/x-wmf',
      _ => 'image/png',
    };
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static String _guessImageExt(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x01 &&
        bytes[1] == 0x00 &&
        bytes[2] == 0x00 &&
        bytes[3] == 0x00) {
      return 'emf';
    }
    return 'png';
  }

  static String? _relationshipToDataUri(
    XmlElement element,
    Archive archive,
    Map<String, String> rels, {
    required List<String> idAttrs,
  }) {
    String? relId;
    for (final attr in element.attributes) {
      final local = attr.name.local.toLowerCase();
      if (idAttrs.contains(local)) {
        relId = attr.value;
        break;
      }
    }
    for (final name in idAttrs) {
      relId ??= element.getAttribute(name) ??
          element.getAttribute('r:$name') ??
          element.getAttribute('o:$name');
    }
    if (relId == null || relId.isEmpty) return null;
    return _dataUriFromRelId(relId, archive, rels);
  }

  static ArchiveFile? _findMediaFile(Archive archive, String target) {
    var t = target.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final candidates = <String>{
      t,
      if (!t.startsWith('word/')) 'word/$t',
      if (t.startsWith('../')) 'word/${t.replaceFirst(RegExp(r'^(\.\./)+'), '')}',
      if (t.startsWith('media/')) 'word/$t',
    };
    for (final path in candidates) {
      final file = archive.findFile(path);
      if (file != null) return file;
    }
    final fileName = t.split('/').last.toLowerCase();
    for (final file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith('/$fileName')) {
        return file;
      }
    }
    return null;
  }

  static String _paragraphPlainText(XmlElement paragraph) {
    final buffer = StringBuffer();
    _appendParagraphText(paragraph, buffer);
    return _cleanExtractedText(buffer.toString());
  }

  static bool _isBibliographyParagraph(XmlElement paragraph) {
    return _isBibliographyHeadingLine(_paragraphPlainText(paragraph).trim());
  }

  static bool _isHeadingParagraph(XmlElement paragraph) {
    for (final style in paragraph.findAllElements('pStyle')) {
      final val = style.getAttribute('val') ?? style.getAttribute('w:val') ?? '';
      if (val.toLowerCase().contains('heading')) return true;
    }
    final text = _paragraphPlainText(paragraph).trim();
    if (CitationStyleShapes.looksLikeSectionHeading(text)) return true;
    return text.length < 80 && !text.endsWith('.') && text == text.toUpperCase();
  }

  static ({
    List<List<String>> rows,
    List<List<String>> rowCellImages,
    List<List<int>> colSpans,
    List<List<int>> rowSpans,
    List<int> columnWidthsPct,
  }) _parseDocxTableWithImages(
    XmlElement table,
    Archive archive,
    Map<String, String> rels,
  ) {
    final gridCols = <int>[];
    for (final grid in table.children.whereType<XmlElement>()) {
      if (grid.localName != 'tblGrid') continue;
      for (final col in grid.children.whereType<XmlElement>()) {
        if (col.localName != 'gridCol') continue;
        final w = int.tryParse(
              col.getAttribute('w') ?? col.getAttribute('w:w') ?? '',
            ) ??
            0;
        gridCols.add(w <= 0 ? 1 : w);
      }
    }

    final sourceRows = <List<WordTableCell>>[];
    for (final tr in table.children.whereType<XmlElement>()) {
      if (tr.localName != 'tr') continue;
      final rowCells = <WordTableCell>[];
      for (final tc in tr.children.whereType<XmlElement>()) {
        if (tc.localName != 'tc') continue;
        final cell = _parseTableCellContent(tc, archive, rels);
        rowCells.add(WordTableCell(
          text: cell.text,
          imageUrl: cell.imageUrl ?? '',
          colSpan: _tcPrInt(tc, 'gridSpan', fallback: 1).clamp(1, 64),
          vMergeContinue: _tcVMergeContinue(tc),
          gridBefore: _tcPrInt(tc, 'gridBefore'),
          gridAfter: _tcPrInt(tc, 'gridAfter'),
        ));
      }
      if (rowCells.isNotEmpty) sourceRows.add(rowCells);
    }

    final grid = TableGrid.fromWordRows(
      sourceRows,
      gridColumnCount: gridCols.length,
      gridColTwips: gridCols,
    );
    return (
      rows: grid.rows,
      rowCellImages: grid.rowCellImages,
      colSpans: grid.colSpans,
      rowSpans: grid.rowSpans,
      columnWidthsPct: grid.columnWidthsPct,
    );
  }

  static XmlElement? _directChild(XmlElement parent, String name) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.localName == name) return child;
    }
    return null;
  }

  static int _tcPrInt(XmlElement tc, String name, {int fallback = 0}) {
    final tcPr = _directChild(tc, 'tcPr');
    if (tcPr == null) return fallback;
    final el = _directChild(tcPr, name);
    if (el == null) return fallback;
    final raw = el.getAttribute('val') ?? el.getAttribute('w:val');
    if (raw == null || raw.isEmpty) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  static bool _tcVMergeContinue(XmlElement tc) {
    final tcPr = _directChild(tc, 'tcPr');
    if (tcPr == null) return false;
    final el = _directChild(tcPr, 'vMerge');
    if (el == null) return false;
    final val =
        (el.getAttribute('val') ?? el.getAttribute('w:val') ?? '').toLowerCase();
    return val != 'restart';
  }

  static (int, int)? _drawingExtentEmu(XmlElement node) {
    for (final el in node.findAllElements('extent')) {
      final cx = int.tryParse(el.getAttribute('cx') ?? '');
      final cy = int.tryParse(el.getAttribute('cy') ?? '');
      if (cx != null && cy != null && cx > 0 && cy > 0) {
        return (cx, cy);
      }
    }
    return null;
  }

  static ({String text, String? imageUrl}) _parseTableCellContent(
    XmlElement tc,
    Archive archive,
    Map<String, String> rels,
  ) {
    final buffer = StringBuffer();
    final foundImages = <String>[];

    void pickImage(String? url) {
      if (url == null || url.isEmpty) return;
      if (!foundImages.contains(url)) foundImages.add(url);
    }

    void walkCell(XmlElement node) {
      final tag = node.localName;
      if (tag == 'object' ||
          tag == 'drawing' ||
          tag == 'pict' ||
          tag == 'AlternateContent') {
        for (final url in _extractAllEmbeddedImages(node, archive, rels)) {
          pickImage(url);
        }
        if (tag == 'AlternateContent') {
          XmlElement? fallback;
          for (final branch in node.children.whereType<XmlElement>()) {
            if (branch.localName == 'Fallback') {
              fallback = branch;
              continue;
            }
            if (branch.localName != 'Choice') continue;
            for (final inner in branch.children.whereType<XmlElement>()) {
              walkCell(inner);
            }
          }
          if (foundImages.isEmpty && fallback != null) {
            for (final inner in fallback.children.whereType<XmlElement>()) {
              walkCell(inner);
            }
          }
          return;
        }
        for (final child in node.children.whereType<XmlElement>()) {
          walkCell(child);
        }
        return;
      }
      if (tag == 'p') {
        for (final url in _extractAllEmbeddedImages(node, archive, rels)) {
          pickImage(url);
        }
        final part = _paragraphPlainText(node).trim();
        if (part.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(part);
        }
        return;
      }
      if (tag == 'tbl') {
        final nested = _parseDocxTableWithImages(node, archive, rels);
        for (final row in nested.rows) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(row.join(' | '));
        }
        for (final row in nested.rowCellImages) {
          for (final url in row) {
            if (url.isNotEmpty) pickImage(url);
          }
        }
        return;
      }
      for (final url in _extractAllEmbeddedImages(node, archive, rels)) {
        pickImage(url);
      }
      for (final child in node.children.whereType<XmlElement>()) {
        walkCell(child);
      }
    }

    for (final child in tc.children.whereType<XmlElement>()) {
      if (child.localName == 'tcPr') continue;
      walkCell(child);
    }

    for (final url in _extractAllEmbeddedImages(tc, archive, rels)) {
      pickImage(url);
    }

    return (
      text: _cleanExtractedText(buffer.toString()),
      imageUrl: _preferDisplayableImage(foundImages),
    );
  }

  static String? _preferDisplayableImage(List<String> urls) {
    if (urls.isEmpty) return null;
    int rank(String url) {
      final u = url.toLowerCase();
      if (u.contains('image/png') ||
          u.contains('image/jpeg') ||
          u.contains('image/jpg') ||
          u.contains('image/gif') ||
          u.contains('image/webp')) {
        return 0;
      }
      if (u.contains('image/bmp') || u.contains('image/tiff')) return 1;
      if (u.contains('image/x-emf') || u.contains('image/x-wmf')) return 2;
      return 3;
    }

    final sorted = List<String>.from(urls)..sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted.first;
  }

  /// Put leftover word/media into empty Structure / drawing columns.
  static List<ManuscriptBlock> _fillEmptyTableDrawings({
    required List<ManuscriptBlock> blocks,
    required List<String> mediaPool,
    required Set<String> usedVisualUris,
  }) {
    final unused = mediaPool.where((u) => !usedVisualUris.contains(u)).toList();
    if (unused.isEmpty) return blocks;

    var poolIdx = 0;
    final out = <ManuscriptBlock>[];
    for (final block in blocks) {
      if (block.type != ManuscriptBlockType.table ||
          block.rows.length < 2 ||
          poolIdx >= unused.length) {
        out.add(block);
        continue;
      }
      final rows = block.rows;
      final images = ManuscriptBlock.normalizedCellImages(
        block.rowCellImages,
        rows,
      );
      final drawingCols = _drawingColumnIndexes(rows, images);
      if (drawingCols.isEmpty) {
        out.add(block);
        continue;
      }

      var changed = false;
      final nextImages = [for (final row in images) List<String>.from(row)];
      for (var r = 1; r < rows.length && poolIdx < unused.length; r++) {
        for (final c in drawingCols) {
          if (c >= rows[r].length || c >= nextImages[r].length) continue;
          if (nextImages[r][c].isNotEmpty) continue;
          if (rows[r][c].trim().isNotEmpty) continue;
          final uri = unused[poolIdx++];
          usedVisualUris.add(uri);
          _registerImageUri('${block.id}_r${r}_c$c', uri);
          nextImages[r][c] = uri;
          changed = true;
        }
      }
      out.add(changed ? block.copyWith(rowCellImages: nextImages) : block);
    }
    return out;
  }

  static List<int> _drawingColumnIndexes(
    List<List<String>> rows,
    List<List<String>> images,
  ) {
    if (rows.isEmpty) return const [];
    final header = rows.first;
    final cols = <int>[];
    for (var c = 0; c < header.length; c++) {
      if (_isStructureColumnHeader(header[c])) cols.add(c);
    }
    if (cols.isNotEmpty) return cols;

    for (var c = 0; c < header.length; c++) {
      if (c == 0) continue;
      var body = 0;
      var emptyText = 0;
      var hasImage = 0;
      for (var r = 1; r < rows.length; r++) {
        if (c >= rows[r].length) continue;
        body++;
        if (rows[r][c].trim().isEmpty) emptyText++;
        if (r < images.length &&
            c < images[r].length &&
            images[r][c].isNotEmpty) {
          hasImage++;
        }
      }
      if (body >= 3 &&
          hasImage == 0 &&
          emptyText >= (body * 0.7).ceil()) {
        cols.add(c);
      }
    }
    return cols;
  }

  static bool _isStructureColumnHeader(String raw) {
    final t = AcademicText.stripBidi(raw).trim().toLowerCase();
    if (t.isEmpty) return false;
    if (RegExp(
      r'molecular\s*formula|chemical\s*formula|formulae|الصيغة الجزيئية|الصيغة الكيميائية',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    return RegExp(
      r'^structure\b|structural\s*formula|chemical\s*structure|'
      r'compound\s*structure|\bchemdraw\b|^compound$|^drawing$|'
      r'^الهيكل|^التركيب(?: الجزيئي| البنائي)?$|^المركب$|^الصيغة البنائية',
      caseSensitive: false,
    ).hasMatch(t);
  }

  /// Upload embedded/data-uri images and replace placeholders with Storage URLs.
  /// Cloud extraction already uploads images — this handles local DOCX fallback only.
  static Future<List<ManuscriptBlock>> resolveImportedBlocks({
    required List<ManuscriptBlock> blocks,
    required List<ImportedDocumentImage> images,
    required String manuscriptId,
  }) async {
    // Windows: keep inline data URIs — uploading dozens of images crashes the app.
    if (skipImportImageUpload) return blocks;

    final needsUpload = blocks.any((b) {
      if (b.type == ManuscriptBlockType.image) {
        final url = b.imageUrl ?? '';
        if (url.startsWith('http')) return false;
        return url.startsWith('data:') || url.startsWith('{{img:');
      }
      if (b.type == ManuscriptBlockType.table && b.rowCellImages.isNotEmpty) {
        return b.rowCellImages.any(
          (row) => row.any(
            (url) =>
                url.startsWith('data:') ||
                url.startsWith('{{img:') ||
                (url.isNotEmpty && !url.startsWith('http')),
          ),
        );
      }
      return false;
    });
    if (!needsUpload && images.isEmpty) return blocks;

    final imageUrls = <int, String>{};
    var uploaded = 0;
    var tableCellUploaded = 0;
    const maxUploads = ManuscriptUploadService.maxImportImagesPerBatch;
    const maxTableCellUploads =
        ManuscriptUploadService.maxTableCellImagesPerBatch;

    for (final img in images) {
      if (uploaded >= maxUploads) break;
      try {
        final ext = img.contentType.split('/').last;
        final url = await ManuscriptUploadService.instance.uploadBytes(
          manuscriptId: manuscriptId,
          bytes: img.bytes,
          fileName: 'import_img_${img.index}.$ext',
          contentType: img.contentType,
        );
        imageUrls[img.index] = url;
        uploaded++;
      } catch (_) {
        // Skip failed image — keep text content.
      }
    }

    final resolved = <ManuscriptBlock>[];
    for (final block in blocks) {
      if (block.type == ManuscriptBlockType.table &&
          block.rowCellImages.isNotEmpty) {
        final uploadedCells = <List<String>>[];
        for (final row in block.rowCellImages) {
          final outRow = <String>[];
          for (final url in row) {
            outRow.add(await _resolveImageUrl(
              url: url,
              manuscriptId: manuscriptId,
              imageUrls: imageUrls,
              uploaded: () => tableCellUploaded,
              onUploaded: () => tableCellUploaded++,
              maxUploads: maxTableCellUploads,
            ));
          }
          uploadedCells.add(outRow);
        }
        resolved.add(block.copyWith(rowCellImages: uploadedCells));
        continue;
      }

      if (block.type != ManuscriptBlockType.image) {
        resolved.add(block);
        continue;
      }
      var url = block.imageUrl ?? '';
      if (url.startsWith('http')) {
        resolved.add(block);
        continue;
      }

      url = await _resolveImageUrl(
        url: url,
        manuscriptId: manuscriptId,
        imageUrls: imageUrls,
        uploaded: () => uploaded,
        onUploaded: () => uploaded++,
        maxUploads: maxUploads,
      );

      if (url.startsWith('http') &&
          (block.imageUrl?.startsWith('data:') == true)) {
        ManuscriptImageSessionCache.instance.register(url, block.imageUrl!);
        ManuscriptImageSessionCache.instance.register(block.id, block.imageUrl!);
      }

      // Never demote a figure to "[Figure]" text — keep the data URI so export
      // can still embed it when Storage upload / CORS fails.
      resolved.add(block.copyWith(
        imageUrl: url.isEmpty ? block.imageUrl : url,
      ));
    }
    return resolved;
  }

  /// Firestore cannot store large base64 data URIs — strip before persistence.
  static List<ManuscriptBlock> stripDataUrisForPersistence(
    List<ManuscriptBlock> blocks,
  ) {
    String stripUrl(String url, String cacheKey) {
      if (url.startsWith('data:')) {
        ManuscriptImageSessionCache.instance.register(cacheKey, url);
        return '{{img:$cacheKey}}';
      }
      return url;
    }

    return blocks.map((block) {
      if (block.type == ManuscriptBlockType.image) {
        final url = block.imageUrl ?? '';
        if (url.startsWith('data:')) {
          return block.copyWith(imageUrl: stripUrl(url, block.id));
        }
      }
      if (block.type == ManuscriptBlockType.equation) {
        final url = block.imageUrl ?? '';
        if (url.startsWith('data:')) {
          return block.copyWith(imageUrl: stripUrl(url, block.id));
        }
      }
      if (block.type == ManuscriptBlockType.table &&
          block.rowCellImages.isNotEmpty) {
        final stripped = <List<String>>[];
        for (var r = 0; r < block.rowCellImages.length; r++) {
          final row = block.rowCellImages[r];
          stripped.add([
            for (var c = 0; c < row.length; c++)
              row[c].isEmpty
                  ? ''
                  : stripUrl(row[c], '${block.id}_r${r}_c$c'),
          ]);
        }
        return block.copyWith(rowCellImages: stripped);
      }
      return block;
    }).toList();
  }

  /// Restore data URIs from the session cache so Word export still has pictures
  /// after Firestore persistence replaced them with `{{img:…}}`.
  static List<ManuscriptBlock> hydratePersistedImageUris(
    List<ManuscriptBlock> blocks,
  ) {
    String hydrate(String url) {
      if (url.isEmpty || url.startsWith('data:')) return url;
      return ManuscriptImageSessionCache.instance.resolve(url) ?? url;
    }

    return blocks.map((block) {
      if (block.type == ManuscriptBlockType.image ||
          block.type == ManuscriptBlockType.equation) {
        final url = block.imageUrl ?? '';
        if (url.isEmpty) return block;
        return block.copyWith(imageUrl: hydrate(url));
      }
      if (block.type == ManuscriptBlockType.table &&
          block.rowCellImages.isNotEmpty) {
        return block.copyWith(
          rowCellImages: [
            for (final row in block.rowCellImages)
              [for (final cell in row) hydrate(cell)],
          ],
        );
      }
      return block;
    }).toList();
  }

  static Future<String> _resolveImageUrl({
    required String url,
    required String manuscriptId,
    required Map<int, String> imageUrls,
    required int Function() uploaded,
    required VoidCallback onUploaded,
    required int maxUploads,
  }) async {
    if (url.isEmpty || url.startsWith('http')) return url;

    if (url.startsWith('{{img:')) {
      final cached = ManuscriptImageSessionCache.instance.resolve(url);
      if (cached != null) {
        url = cached;
      } else {
        final placeholder = RegExp(r'^\{\{img:(\d+)\}\}$').firstMatch(url);
        if (placeholder != null) {
          final idx = int.tryParse(placeholder.group(1) ?? '') ?? -1;
          return imageUrls[idx] ?? '';
        }
        return '';
      }
    }

    final legacyPlaceholder = RegExp(r'^\{\{img:(\d+)\}\}$').firstMatch(url);
    if (legacyPlaceholder != null) {
      final idx = int.tryParse(legacyPlaceholder.group(1) ?? '') ?? -1;
      return imageUrls[idx] ?? '';
    }

    if (!url.startsWith('data:')) return url;
    if (uploaded() >= maxUploads) return url;

    try {
      final comma = url.indexOf(',');
      final header = url.substring(0, comma);
      final mime = header.replaceFirst('data:', '').split(';').first;
      final bytes = base64Decode(url.substring(comma + 1));
      if (bytes.length > ManuscriptUploadService.maxImageBytes) return url;
      var ext = mime.split('/').last;
      if (ext == 'x-emf') ext = 'emf';
      if (ext == 'x-wmf') ext = 'wmf';
      final uploadedUrl = await ManuscriptUploadService.instance.uploadBytes(
        manuscriptId: manuscriptId,
        bytes: bytes,
        fileName: 'import_img_${DateTime.now().millisecondsSinceEpoch}.$ext',
        contentType: mime,
      );
      onUploaded();
      return uploadedUrl;
    } catch (_) {
      return url;
    }
  }

  /// Apply parsed content to manuscript (references + structured body).
  static Future<PublishManuscript> applyParseResult({
    required PublishManuscript manuscript,
    required ManuscriptParseResult parsed,
    bool replaceReferences = false,
    bool replaceBody = true,
  }) async {
    var next = manuscript;
    if (parsed.references.isNotEmpty) {
      next = next.copyWith(
        references: sanitizeImportedReferences(
          replaceReferences
              ? parsed.references
              : [...next.references, ...parsed.references],
        ),
      );
    }

    if (replaceBody || next.bodyBlocks.isEmpty) {
      var blocks = parsed.bodyBlocks;
      final needsClientImageUpload = blocks.any((b) {
        if (b.type == ManuscriptBlockType.image) {
          final url = b.imageUrl ?? '';
          return !url.startsWith('http');
        }
        if (b.type == ManuscriptBlockType.table && b.rowCellImages.isNotEmpty) {
          return b.rowCellImages.any(
            (row) => row.any((url) => url.isNotEmpty && !url.startsWith('http')),
          );
        }
        return false;
      });
      if (blocks.isNotEmpty &&
          manuscript.id != null &&
          (needsClientImageUpload || parsed.images.isNotEmpty)) {
        blocks = await resolveImportedBlocks(
          blocks: blocks,
          images: parsed.images,
          manuscriptId: manuscript.id!,
        );
      }
      if (blocks.isNotEmpty) {
        next = next.copyWith(
          bodyBlocks: sanitizeImportedBlocks(mergeSectionParagraphs(blocks)),
        );
      } else if (parsed.bodyText.trim().length > 80) {
        next = next.copyWith(
          bodyBlocks: sanitizeImportedBlocks(
            mergeSectionParagraphs(
              _buildAcademicLayout(parsed.bodyText),
            ),
          ),
        );
      }
    }

    if (next.title.trim().isNotEmpty) {
      next = next.copyWith(
        title: AcademicText.stripTrailingAuthorFromTitle(
          AcademicText.sanitize(next.title),
        ),
      );
    } else {
      final title = _extractTitleFromBlocks(next.bodyBlocks);
      if (title != null && title.length > 10) {
        next = next.copyWith(
          title: AcademicText.stripTrailingAuthorFromTitle(
            AcademicText.sanitize(title),
          ),
        );
      } else if (parsed.bodyText.length > 20) {
        final extracted =
            DocxScientificExtractor.extractPaperTitle(parsed.bodyText);
        if (extracted != null && extracted.length > 10) {
          next = next.copyWith(
            title: AcademicText.stripTrailingAuthorFromTitle(
              AcademicText.sanitize(extracted),
            ),
          );
        }
      }
    }
    return CitationLinker.linkManuscript(next);
  }

  static String _bodyWithoutBibliography(String text) {
    final idx = _bibliographyStartIndex(text);
    if (idx == null) return text.trim();
    return text.substring(0, idx).trim();
  }

  static int? _bibliographyStartIndex(String text) {
    if (text.trim().isEmpty) return null;

    final heading = RegExp(
      r'(?:^|\n)\s*(?:\d+\.?\s*)?(References?|Bibliography|Works Cited|'
      r'Reference List|Literature Cited|REFERENCES|المراجع|قائمة المراجع|'
      r'المصادر)\s*:?\s*(?:\n|$)',
      caseSensitive: false,
    );
    int? lastInBody;
    for (final m in heading.allMatches(text)) {
      if (m.start >= text.length * 0.28) lastInBody = m.start;
      lastInBody ??= m.start;
    }
    if (lastInBody != null) return lastInBody;
    final runAt = _bibliographyRunStartInText(text);
    if (runAt != null) return runAt;

    final minPos = text.length > 4000 ? (text.length * 0.42).floor() : 0;
    var charPos = 0;
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      final lineStart = charPos;
      charPos += rawLine.length + 1;
      if (lineStart < minPos) continue;
      if (_isBibliographyHeadingLine(line)) return lineStart;
    }
    return null;
  }

  /// Last run of bibliographic lines in the file (the printed list, not Methods).
  static int? _bibliographyRunStartInText(String text) {
    if (text.length < 200) return null;
    final minPos = text.length > 4000 ? (text.length * 0.22).floor() : 0;
    var charPos = 0;
    var runChar = -1;
    var runLen = 0;
    int? lastRun;
    for (final rawLine in text.split('\n')) {
      final lineStart = charPos;
      charPos += rawLine.length + 1;
      if (lineStart < minPos) continue;
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (_isBibliographyHeadingLine(line)) {
        if (runLen >= 3) lastRun = runChar;
        return lastRun ?? (runLen >= 3 ? runChar : lineStart);
      }
      final isBib = PublishReference.numberFromImportedLine(line) != null ||
          _isStandaloneBibliographyEntry(line) ||
          (line.length >= 40 && _looksLikeReference(line));
      if (isBib) {
        if (runChar < 0) runChar = lineStart;
        runLen++;
      } else if (runLen >= 3) {
        lastRun = runChar;
        runChar = -1;
        runLen = 0;
      } else {
        runChar = -1;
        runLen = 0;
      }
    }
    if (runLen >= 3) lastRun = runChar;
    return lastRun;
  }

  static bool _isBibliographyHeadingLine(String line) {
    var t = AcademicText.westernDigits(line)
        .replaceAll(RegExp(r'[\u00A0\u2000-\u200D\uFEFF]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (t.isEmpty || t.length > 80) return false;
    t = t.replaceFirst(RegExp(r'^[^\w\u0600-\u06FF]+'), '');
    t = t.replaceFirst(RegExp(r'[^\w\u0600-\u06FF]+$'), '');
    if (RegExp(r'[.!?]').hasMatch(t) && t.split(RegExp(r'[.!?]')).length > 2) {
      return false;
    }
    final letters = t.replaceAll(RegExp(r'[^A-Za-z\u0600-\u06FF]'), '');
    if (letters.toLowerCase() == 'references' ||
        letters.toLowerCase() == 'bibliography') {
      return true;
    }

    return RegExp(
      r'^(?:\d+\.?\s*)?(References?|Bibliography|Works Cited|Reference List|'
      r'Literature Cited|REFERENCES)\s*:?\.?\s*$',
      caseSensitive: false,
    ).hasMatch(t) ||
        RegExp(r'^(?:\d+\.?\s*)?(المراجع|قائمة المراجع|المصادر)( والمصادر)?\s*:?\.?\s*$')
            .hasMatch(t);
  }

  /// Prefer the real end-of-file bibliography over title-page authors
  /// that the cloud extractor sometimes returns as "references".
  static List<PublishReference> _preferBibliographyRefs({
    required List<PublishReference> fileRefs,
    required List<PublishReference> localRefs,
    required List<PublishReference> cloudRefs,
    required String fullText,
  }) {
    final cleanedFile = fileRefs.where(_referenceLooksValid).toList();
    final cleanedLocal = localRefs.where(_referenceLooksValid).toList();
    final cleanedCloud = cloudRefs.where(_referenceLooksValid).toList();
    final body = _bodyWithoutBibliography(fullText);
    List<PublishReference> best = const [];
    var bestScore = -1;
    for (final candidate in [cleanedFile, cleanedLocal, cleanedCloud]) {
      if (candidate.isEmpty) continue;
      final score = _bibliographyMatchScore(candidate, body);
      final longer = candidate.length > best.length;
      if (score > bestScore ||
          (score == bestScore && longer) ||
          (longer && candidate.length >= best.length + 3 && score >= bestScore - 1)) {
        best = candidate;
        bestScore = score;
      }
    }
    if (best.isNotEmpty) return best;
    if (cleanedFile.isNotEmpty) return cleanedFile;
    if (cleanedLocal.isNotEmpty) return cleanedLocal;
    return cleanedCloud;
  }

  static int _bibliographyMatchScore(
    List<PublishReference> refs,
    String body,
  ) {
    if (refs.isEmpty || body.isEmpty) return 0;
    var hits = 0;
    for (final ref in refs) {
      final year = AcademicText.westernDigits(ref.year.trim());
      if (!RegExp(r'^(?:19|20)\d{2}$').hasMatch(year)) continue;
      final names = <String>[
        for (final a in ref.authors)
          if (a.trim().length >= 3) a.trim().split(RegExp(r'[,\s]+')).first,
      ];
      if (names.isEmpty && ref.rawText.isNotEmpty) {
        final lead = RegExp(r'^\[?\d*\]?\s*([A-Z][A-Za-z\-]{2,})')
            .firstMatch(ref.rawText);
        if (lead != null) names.add(lead.group(1)!);
      }
      for (final name in names) {
        if (name.length < 3) continue;
        if (RegExp(
          '\\b${RegExp.escape(name)}\\b[^.]{0,60}$year',
          caseSensitive: false,
        ).hasMatch(body)) {
          hits++;
          break;
        }
      }
    }
    return hits;
  }

  static String _bibliographySection(String text) {
    final idx = _bibliographyStartIndex(text);
    if (idx == null) return '';
    var section = text.substring(idx);
    final nl = section.indexOf('\n');
    if (nl > 0 && nl < 80) {
      section = section.substring(nl + 1);
    }
    return section.trim();
  }

  static List<PublishReference> _parseReferences(String fullText) {
    var section = _bibliographySection(fullText);
    if (section.isEmpty) {
      section = _likelyBibliographyTail(fullText);
    }
    final source = section.isEmpty ? fullText : section;
    final body = _bodyWithoutBibliography(fullText);
    final cites = InTextCiteKeys.fromBody(body);
    final numbered = _parseNumbered(source, cites);
    final harvested = _harvestNumberedBibliographyLines(fullText);
    final mixed = section.isEmpty
        ? const <PublishReference>[]
        : _parseMixedBibliography(section);
    final ieee = (section.isEmpty
            ? _parseIeeeTailStrict(fullText)
            : _parseIeee(section))
        .where(_ieeeEntryIsBibliography)
        .toList();
    final apa = section.isEmpty
        ? const <PublishReference>[]
        : _parseApa(section);
    final paragraphs = section.isEmpty
        ? const <PublishReference>[]
        : _parseParagraphBlocks(section);
    final chosen = _chooseBibliographyParse(
      [numbered, harvested, mixed, apa, paragraphs, ieee],
      cites,
    );
    return BibliographyCiteAligner.complete(
      bodyText: body,
      bibliographyText: source,
      parsed: chosen,
      keys: cites,
    );
  }

  /// Walk every line of the file. Keep `n. Author` / `[n] Author` only —
  /// never an in-text `[n]` sitting in a sentence.
  static List<PublishReference> _harvestNumberedBibliographyLines(String text) {
    final byNum = <int, PublishReference>{};
    for (final line in _explodeBibliographyPieces(text)) {
      if (!_isBibliographicNumberedLine(line)) continue;
      final n = PublishReference.numberFromImportedLine(line);
      if (n == null || n < 1 || n > 500) continue;
      final ref = _blockToReference(
        line,
        id: 'ref_$n',
        rawText: line,
        importedNumber: n,
      );
      final prev = byNum[n];
      if (prev == null) {
        byNum[n] = ref;
      } else if (!_hasBibliographyAuthorLead(prev.rawText) &&
          _bibliographyLineQuality(line) > _bibliographyLineQuality(prev.rawText)) {
        byNum[n] = ref;
      }
    }
    final keys = byNum.keys.toList()..sort();
    return [for (final k in keys) byNum[k]!];
  }

  static bool _isBibliographicNumberedLine(String line) {
    final t = line.trim();
    if (t.length < 28) return false;
    if (PublishReference.numberFromImportedLine(t) == null) return false;
    final after = t.replaceFirst(
      RegExp(r'^(?:\[\d{1,3}\]|\d{1,3}[.)])\s*'),
      '',
    );
    if (CitationCues.sentenceLeadLine.hasMatch(after)) {
      return false;
    }
    if (_hasBibliographyAuthorLead(t) || _looksLikeNewBibliographyEntry(after)) {
      return true;
    }
    // Numbered bibliography line whose author is unusual (org, unicode, editor).
    return t.length >= 40 && RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t);
  }

  static int _bibliographyLineQuality(String line) {
    var s = 0;
    if (_hasBibliographyAuthorLead(line)) s += 6;
    if (RegExp(r';\s*[A-Z]').hasMatch(line)) s += 3;
    if (RegExp(r'doi', caseSensitive: false).hasMatch(line)) s += 3;
    if (RegExp(r'\b(?:vol\.|pp?\.|ed\.)', caseSensitive: false).hasMatch(line)) {
      s += 2;
    }
    if (RegExp(
      r'\b(was|were|using|measured|technique|according to)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      s -= 5;
    }
    if (RegExp(r'\bet al\.?', caseSensitive: false).hasMatch(line) &&
        !_hasBibliographyAuthorLead(line)) {
      s -= 4;
    }
    return s;
  }

  static List<String> _explodeBibliographyPieces(
    String text, [
    InTextCiteKeys? cites,
  ]) {
    final out = <String>[];
    for (final raw in text.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (CitationCues.isRunningMatterLine(line)) continue;
      final parts = line.split(
        RegExp(
          '(?<=\\S)\\s+(?=\\[\\d{1,3}\\]\\s+)|'
          '(?<=\\S)\\s+(?=\\d{1,3}[.)]\\s+(?:${CitationCues.standardsOrg}|'
          r'[A-Z][A-Za-z\-]{2,}(?:\s+[A-Z][A-Za-z\-]{2,}){0,2},\s*[A-Z]))',
        ),
      );
      for (final part in parts) {
        final p = part.trim();
        if (p.isEmpty) continue;
        out.addAll(BibliographyCiteAligner.splitByCitedWorks(p, cites));
      }
    }
    return out;
  }

  static bool _ieeeEntryIsBibliography(PublishReference ref) {
    final t = ref.rawText.trim();
    if (t.length < 28) return false;
    if (CitationCues.isRunningMatterLine(t)) return false;
    if (RegExp(r'^\[\d{1,3}\]\s*(https?://|doi\b)', caseSensitive: false)
        .hasMatch(t)) {
      return false;
    }
    return _isBibliographicNumberedLine(t);
  }

  static bool _bibliographyRowLooksComplete(String raw) {
    final t = raw.trim();
    if (t.length < 25 || CitationCues.isRunningMatterLine(t)) return false;
    if (RegExp(r'^\((?:19|20)\d{2}[a-z]?\)').hasMatch(t)) return false;
    if (RegExp(r'^[&,]').hasMatch(t)) return false;
    if (!_hasBibYear(t)) return false;
    return _hasBibliographyAuthorLead(t) ||
        PublishReference.numberFromImportedLine(t) != null ||
        CitationCues.standardsOrgLead.hasMatch(t);
  }

  static List<PublishReference> _chooseBibliographyParse(
    List<List<PublishReference>> candidates, [
    InTextCiteKeys? cites,
  ]) {
    List<PublishReference> best = const [];
    var bestScore = -1;
    for (final c in candidates) {
      if (c.isEmpty) continue;
      final nums = <int>{
        for (final r in c)
          if ((r.importedNumber ??
                  PublishReference.numberFromImportedLine(r.rawText)) !=
              null)
            r.importedNumber ??
                PublishReference.numberFromImportedLine(r.rawText)!,
      };
      var sequential = 0;
      for (var i = 1; i <= nums.length + 8; i++) {
        if (!nums.contains(i)) break;
        sequential++;
      }
      final maxNum = nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b);
      final coverage =
          cites == null ? 0 : BibliographyCiteAligner.coverage(c, cites);
      var wellFormed = 0;
      for (final r in c) {
        if (_bibliographyRowLooksComplete(
          r.rawText.trim().isNotEmpty ? r.rawText : r.title,
        )) {
          wellFormed++;
        }
      }
      // Complete author+year rows beat a longer list of wrap fragments.
      final score = coverage * 50000 +
          wellFormed * 20000 +
          c.length * 100 +
          sequential * 100 +
          maxNum;
      if (score > bestScore) {
        best = c;
        bestScore = score;
      }
    }
    return best;
  }

  static List<PublishReference> _parseMixedBibliography(String section) {
    final pieces = _splitStandaloneBibliographyEntries(section);
    final refs = <PublishReference>[];
    var i = 0;
    for (final piece in pieces) {
      final t = piece.trim();
      if (t.length < 25) continue;
      if (_isBibliographyHeadingLine(t)) continue;
      final printed = PublishReference.numberFromImportedLine(t);
      if (printed == null && !_isBibliographySectionEntry(t)) {
        continue;
      }
      refs.add(_blockToReference(
        t,
        id: 'ref_${printed ?? ++i}',
        rawText: t,
        importedNumber: printed,
      ));
    }
    return refs;
  }

  static String _likelyBibliographyTail(String text) {
    if (text.length < 240) return '';
    final start = (text.length * 0.52).floor();
    final tail = text.substring(start);
    final parenYears =
        RegExp(r'\((?:19|20)\d{2}[a-z]?\)').allMatches(tail).length;
    final acsYears = RegExp(r';\s*(?:19|20)\d{2}\b').allMatches(tail).length;
    final doiHits = RegExp(r'doi\.org', caseSensitive: false).allMatches(tail).length;
    return (parenYears >= 3 || acsYears >= 3 || doiHits >= 3) ? tail : '';
  }

  static List<PublishReference> _parseIeeeTailStrict(String fullText) {
    final tailStart = (fullText.length * 0.78).floor();
    final tail = fullText.substring(tailStart);
    final refs = _parseIeee(tail).where(_referenceLooksValid).toList();
    if (refs.length >= 3) return refs;
    return const [];
  }

  /// APA / author–year lines: Author, A. (Year). Title...
  /// PDF/Word often wraps authors onto one line and `(Year). Title` onto the next.
  /// Those two lines are one work — never start a new row at the year.
  static List<PublishReference> _parseApa(String section) {
    final merged = <String>[];
    var current = StringBuffer();

    bool looksLikeStart(String line) {
      final t = line.trim();
      if (t.length < 8 || CitationCues.isRunningMatterLine(t)) return false;
      if (RegExp(r'^\[\d+\]').hasMatch(t)) return true;
      if (RegExp(r'^\d+[.)]\s').hasMatch(t)) return true;
      if (RegExp(r'^\((?:19|20)\d{2}[a-z]?\)').hasMatch(t)) return false;
      if (_hasBibliographyAuthorLead(t) ||
          CitationCues.looksLikeAuthorListFragment(t)) {
        return true;
      }
      return RegExp(r'\(\d{4}[a-z]?\)').hasMatch(t) ||
          (RegExp(r'\b(19|20)\d{2}\b').hasMatch(t) && t.length > 35);
    }

    void flush() {
      final t = current.toString().trim();
      if (t.isNotEmpty) merged.add(t);
      current = StringBuffer();
    }

    for (final raw in section.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (current.isNotEmpty && _hasBibYear(current.toString())) flush();
        continue;
      }
      if (CitationCues.isRunningMatterLine(line)) continue;
      if (current.isEmpty) {
        if (looksLikeStart(line) ||
            CitationCues.looksLikeAuthorListFragment(line) ||
            _hasBibliographyAuthorLead(line)) {
          current.write(line);
        }
        continue;
      }
      if (CitationCues.bibliographyLineContinues(current.toString(), line)) {
        current.write(' ');
        current.write(line);
        continue;
      }
      if (looksLikeStart(line) && _hasBibYear(current.toString())) {
        flush();
        current.write(line);
        continue;
      }
      current.write(' ');
      current.write(line);
    }
    if (current.isNotEmpty) flush();

    final refs = <PublishReference>[];
    var i = 0;
    for (final block in merged) {
      if (block.length < 25) continue;
      if (CitationCues.isRunningMatterLine(block)) continue;
      if (_isBibliographySectionEntry(block)) {
        final printed = PublishReference.numberFromImportedLine(block);
        refs.add(_blockToReference(
          block,
          id: 'ref_${printed ?? ++i}',
          importedNumber: printed,
        ));
      }
    }
    return refs;
  }

  static List<PublishReference> _parseIeee(String section) {
    final pattern = RegExp(
      r'(?:^|\n)\[(\d+)\]\s*([\s\S]*?)(?=(?:^|\n)\[\d+\]|$)',
      multiLine: true,
    );
    final refs = <PublishReference>[];
    for (final m in pattern.allMatches(section)) {
      final n = m.group(1)!;
      final block = m.group(2)?.trim() ?? '';
      if (block.isEmpty) continue;
      refs.add(_blockToReference(
        block,
        id: 'ref_$n',
        rawText: '[$n] $block',
        importedNumber: int.tryParse(n),
      ));
    }
    refs.sort((a, b) {
      final na = a.importedNumber ??
          int.tryParse(
            RegExp(r'^\[(\d+)\]').firstMatch(a.rawText)?.group(1) ?? '',
          ) ??
          0;
      final nb = b.importedNumber ??
          int.tryParse(
            RegExp(r'^\[(\d+)\]').firstMatch(b.rawText)?.group(1) ?? '',
          ) ??
          0;
      return na.compareTo(nb);
    });
    return refs;
  }

  static List<PublishReference> _parseNumbered(
    String section, [
    InTextCiteKeys? cites,
  ]) {
    final chunks = <({int? number, StringBuffer text})>[];
    for (final line in _explodeBibliographyPieces(section, cites)) {
      if (_isBibliographyHeadingLine(line)) continue;
      if (CitationCues.isRunningMatterLine(line)) continue;
      final n = PublishReference.numberFromImportedLine(line);
      final startAuthor = n == null &&
          chunks.isEmpty &&
          (_hasBibliographyAuthorLead(line) ||
              CitationCues.looksLikeAuthorListFragment(line));
      if (n != null ||
          startAuthor ||
          (chunks.isNotEmpty &&
              _shouldStartNewBibliographyEntry(
                chunks.last.text.toString(),
                line,
                cites,
              ))) {
        chunks.add((number: n, text: StringBuffer(line)));
        continue;
      }
      if (chunks.isEmpty) continue;
      chunks.last.text.write(' ');
      chunks.last.text.write(line);
    }
    final refs = <PublishReference>[];
    for (final chunk in chunks) {
      final t = chunk.text.toString().trim();
      if (t.length < 15) continue;
      final printed = chunk.number ??
          PublishReference.numberFromImportedLine(t);
      refs.add(_blockToReference(
        t,
        id: 'ref_${printed ?? refs.length + 1}',
        rawText: t,
        importedNumber: printed,
      ));
    }
    return refs;
  }

  static bool _looksLikeNewBibliographyEntry(String line) {
    if (PublishReference.numberFromImportedLine(line) != null) return true;
    if (CitationCues.standardsOrgLead.hasMatch(line)) {
      return true;
    }
    return RegExp(
      r"^[\p{Lu}][\p{L}'\-]{1,}"
      r"(?:\s+[\p{Lu}][\p{L}'\-]{1,}){0,3},\s*[\p{Lu}]",
      unicode: true,
    ).hasMatch(line);
  }

  static bool _shouldStartNewBibliographyEntry(
    String previous,
    String line, [
    InTextCiteKeys? cites,
  ]) {
    final lower = line.toLowerCase();
    if (lower.startsWith('http') || lower.startsWith('doi')) return false;
    if (CitationCues.isRunningMatterLine(line)) return false;
    if (CitationCues.bibliographyLineContinues(previous, line)) {
      return false;
    }
    if (cites != null && cites.lineStartsNewCitedWork(previous, line)) {
      return true;
    }
    if (_looksLikeNewBibliographyEntry(line) ||
        _hasBibliographyAuthorLead(line)) {
      return true;
    }
    // Previous item already ended (has a year). Next long line is the next work,
    // even if the author spelling is unusual (unicode, two-part names, orgs).
    if (_hasBibYear(previous) &&
        _hasBibYear(line) &&
        line.length >= 35 &&
        RegExp(r'^[\p{Lu}]', unicode: true).hasMatch(line)) {
      return true;
    }
    return false;
  }

  static bool _hasBibYear(String text) =>
      RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(text);

  static List<PublishReference> _parseParagraphBlocks(String section) {
    final blocks = section
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.length > 25)
        .toList();

    final refs = <PublishReference>[];
    var i = 0;
    for (final block in blocks) {
      if (_isBibliographySectionEntry(block)) {
        final printed = PublishReference.numberFromImportedLine(block);
        refs.add(_blockToReference(
          block,
          id: 'ref_${printed ?? ++i}',
          importedNumber: printed,
        ));
      }
    }
    return refs;
  }

  /// After a References heading, keep the line even if Word dropped its number.
  static bool _isBibliographySectionEntry(String raw) {
    final t = AcademicText.westernDigits(raw.trim());
    if (t.length < 25 || t.length > 4000) return false;
    if (_isBibliographyHeadingLine(t) || _isMajorSectionHeading(t)) {
      return false;
    }
    if (CitationCues.isRunningMatterLine(t)) return false;
    if (_isTableCaption(t) || _isFigureCaption(t)) return false;
    if (DocxScientificExtractor.isFrontMatterAuthorText(t)) return false;
    return RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t);
  }

  static bool _looksLikeReference(String block) {
    if (_isStandaloneBibliographyEntry(block)) return true;
    final t = block.trim();
    if (t.length < 20 || t.length > 2500) return false;
    if (RegExp(r'^\[\d+\]').hasMatch(t) &&
        RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t)) {
      return _hasBibliographyAuthorLead(t);
    }
    if (DocxScientificExtractor.isFrontMatterAuthorText(t)) return false;
    if (RegExp(
      r'corresponding author|e-?mail|@|\(\+\s*\d{2}',
      caseSensitive: false,
    ).hasMatch(t) &&
        !RegExp(r'doi\b|vol\.|pp\.|journal', caseSensitive: false).hasMatch(t)) {
      return false;
    }

    if (CitationCues.sentenceLeadLine.hasMatch(t)) {
      return false;
    }

    final hasYear = RegExp(r'\(\d{4}[a-z]?\)|,\s*(19|20)\d{2}\b|\b(19|20)\d{2}\b')
        .hasMatch(t);
    if (!hasYear) return false;

    if (RegExp(
      CitationCues.bibliographicVenue,
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }

    return _hasBibliographyAuthorLead(t) ||
        RegExp(
          r"^[A-Z][A-Za-z\-,\s\.]{2,80},\s*[A-Z\.]",
        ).hasMatch(t);
  }

  /// Full bibliographic line (not an in-text cite inside a sentence).
  static bool _isStandaloneBibliographyEntry(String raw) {
    final t = AcademicText.westernDigits(raw.trim());
    if (t.length < 40 || t.length > 2500) return false;
    if (DocxScientificExtractor.isFrontMatterAuthorText(t)) return false;
    if (_isBibliographyHeadingLine(t) || _isMajorSectionHeading(t)) {
      return false;
    }
    if (_isTableCaption(t) || _isFigureCaption(t)) return false;
    if (RegExp(r'\(\d{4}[a-z]?\)\s+[a-z]').hasMatch(t)) return false;
    if (CitationCues.sentenceLeadLine.hasMatch(t)) {
      return false;
    }
    if (!RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(t)) return false;
    if (!_hasBibliographyAuthorLead(t)) return false;
    return RegExp(
          CitationCues.bibliographicVenue,
          caseSensitive: false,
        ).hasMatch(t) ||
        RegExp(r';\s*[\p{Lu}][\p{L}\-]+,', unicode: true).hasMatch(t) ||
        RegExp(r'\(\d{4}[a-z]?\)\.').hasMatch(t);
  }

  static bool _hasBibliographyAuthorLead(String t) {
    final s = t.trim();
    if (CitationCues.standardsOrgLead.hasMatch(s)) {
      return true;
    }
    if (RegExp(
      r'^(?:\[\d{1,3}\]\s+|\d{1,3}[.)]\s+)?'
      r'(?:[A-Z]\.\s+)+[A-Z]',
    ).hasMatch(s)) {
      return true;
    }
    if (RegExp(
      r'^(?:\[\d{1,3}\]\s+|\d{1,3}[.)]\s+)?'
      r'[A-Z]{2,10}\.\s+[A-Z]',
    ).hasMatch(s)) {
      return true;
    }
    return RegExp(
      r'^(?:\[\d{1,3}\]\s+|\d{1,3}[.)]\s+)?'
      r"[\p{Lu}][\p{L}\p{M}'’.\-]*(?:\s+[\p{L}\p{M}'’.\-]+)?"
      r"(?:\s+[\p{Lu}][\p{L}\p{M}'’.\-]{1,}){0,3},\s*[\p{Lu}]",
      unicode: true,
    ).hasMatch(s);
  }

  static List<String> _splitStandaloneBibliographyEntries(String text) {
    final t = AcademicText.westernDigits(text.trim())
        .replaceAllMapped(RegExp(r':\s*\n+\s*'), (_) => ': ')
        .replaceAllMapped(RegExp(r'\n+\s*(https?://)'), (m) => ' ${m[1]}');
    if (t.length < 50) return [t];

    final raw = t.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    final lines = <String>[];
    for (final line in raw) {
      if (CitationCues.isRunningMatterLine(line)) continue;
      if (lines.isEmpty) {
        lines.add(line);
        continue;
      }
      final prev = lines.last;
      final prevHasYear = RegExp(r'\b(?:19|20)\d{2}\b').hasMatch(prev);
      if (CitationCues.bibliographyLineContinues(prev, line) ||
          line.startsWith('http') ||
          (!prevHasYear &&
              (prev.endsWith(':') ||
                  prev.endsWith(',') ||
                  prev.endsWith('&') ||
                  prev.endsWith(';')))) {
        lines[lines.length - 1] = '$prev $line';
      } else {
        lines.add(line);
      }
    }

    if (lines.isEmpty) return const [];
    if (lines.length >= 2) return lines;

    // One wrapped paragraph: cut after a year/DOI when the next token is a new author.
    final blob = lines.single;
    final author = RegExp(
      '(?:\\[\\d{1,3}\\]\\s+|\\d{1,3}[.)]\\s+)?'
      '(?:(?:${CitationCues.standardsOrg})\\b|'
      r"[A-Z]{2,10}\.\s+[A-Z]|"
      r"[A-Z][A-Za-z'\-]{2,}(?:\s+[A-Z][A-Za-z'\-]+){0,2},\s*[A-Z])",
      caseSensitive: false,
    );
    final starts = <int>[];
    for (final m in author.allMatches(blob)) {
      if (m.start == 0) {
        starts.add(0);
        continue;
      }
      final before = blob.substring((m.start - 120).clamp(0, m.start), m.start);
      if (before.trimRight().endsWith(';')) continue;
      if (before.trimRight().endsWith('(') ||
          before.trimRight().endsWith(':')) {
        continue;
      }
      if (RegExp(r'\(\s*$').hasMatch(before)) continue;
      final endedPrev = RegExp(r'\b(?:19|20)\d{2}\.?\s*$').hasMatch(before) ||
          RegExp(r'doi\.org/\S+\s*$', caseSensitive: false).hasMatch(before) ||
          RegExp(r'https?://\S+\s*$').hasMatch(before);
      if (!endedPrev) continue;
      final rest = blob.substring(m.start);
      final probe = rest.length > 280 ? rest.substring(0, 280) : rest;
      if (_isStandaloneBibliographyEntry(probe) ||
          _isBibliographySectionEntry(probe)) {
        starts.add(m.start);
      }
    }
    if (starts.length < 2) return [blob];
    final cuts = starts.first == 0 ? starts : [0, ...starts];
    final ends = [...cuts.skip(1), blob.length];
    return [
      for (var i = 0; i < cuts.length; i++)
        blob.substring(cuts[i], ends[i]).trim(),
    ].where((s) => s.isNotEmpty).toList();
  }

  /// Drop full bibliography lines that leaked into the paper body.
  /// Only harvest after a real References heading — never steal Experimental.
  static ({List<ManuscriptBlock> blocks, List<String> harvested})
      _extractBibliographyFromBody(List<ManuscriptBlock> blocks) {
    final out = <ManuscriptBlock>[];
    final harvested = <String>[];
    final bibAt = _bibliographyHeadingIndex(blocks);
    final trailingAt = _lastBibliographyRunIndex(blocks);
    final afterImrad = _lastImradHeadingIndex(blocks);
    int? harvestFrom = bibAt;
    if (trailingAt != null &&
        (afterImrad == null || trailingAt > afterImrad)) {
      if (harvestFrom == null || trailingAt < harvestFrom) {
        harvestFrom = trailingAt;
      }
    }
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final afterBib = harvestFrom != null && i >= harvestFrom;
      if (!afterBib) {
        if (block.type == ManuscriptBlockType.heading &&
            _isBibliographyHeadingLine(block.text)) {
          continue;
        }
        out.add(block);
        continue;
      }
      if (block.type != ManuscriptBlockType.paragraph) {
        if (block.type == ManuscriptBlockType.heading &&
            _isBibliographyHeadingLine(block.text)) {
          continue;
        }
        if (block.type == ManuscriptBlockType.heading &&
            (_isStandaloneBibliographyEntry(block.text) ||
                CitationLinker.looksLikeBibliographyLine(block.text))) {
          harvested.add(block.text.trim());
          continue;
        }
        out.add(block);
        continue;
      }
      final t = block.text.trim();
      if (t.isEmpty) continue;
      if (_isBibliographyHeadingLine(t)) continue;

      final pieces = _splitStandaloneBibliographyEntries(t);
      if (pieces.length >= 2) {
        final kept = <String>[];
        var harvestedHere = 0;
        for (final piece in pieces) {
          if (_isStandaloneBibliographyEntry(piece) ||
              CitationLinker.looksLikeBibliographyLine(piece)) {
            harvested.add(piece);
            harvestedHere++;
          } else {
            kept.add(piece);
          }
        }
        if (harvestedHere > 0) {
          if (kept.isNotEmpty) {
            out.add(block.copyWith(text: kept.join('\n\n')));
          }
          continue;
        }
      }
      if (_isStandaloneBibliographyEntry(t) ||
          (t.length >= 40 && CitationLinker.looksLikeBibliographyLine(t))) {
        harvested.add(t);
        continue;
      }
      out.add(block);
    }
    return (blocks: out, harvested: harvested);
  }

  static PublishReference _blockToReference(
    String block, {
    required String id,
    String? rawText,
    int? importedNumber,
  }) {
    final storedRaw = (rawText ?? block).trim();
    final n = importedNumber ??
        PublishReference.numberFromImportedLine(storedRaw);
    final parsed = CitationFormatter.parseBibliographicLine(storedRaw);
    if (parsed != null) {
      return parsed.copyWith(id: id, rawText: storedRaw, importedNumber: n);
    }

    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(block);
    final year = yearMatch?.group(0) ?? '';

    final doiMatch = RegExp(
      r'(?:doi[:\s]*|https?://doi\.org/)([^\s,]+)',
      caseSensitive: false,
    ).firstMatch(block);
    final doi = doiMatch?.group(1)?.replaceAll(RegExp(r'[.)]$'), '') ?? '';

    var title = '';
    final quoted = RegExp(r'"([^"]+)"').firstMatch(block) ??
        RegExp(r'“([^”]+)”').firstMatch(block);
    if (quoted != null) {
      title = quoted.group(1) ?? '';
    } else if (yearMatch != null) {
      final afterYear = block.substring(yearMatch.end).replaceFirst(
            RegExp(r'^[.)\s]+'),
            '',
          );
      title = afterYear.split('.').first.trim();
    } else if (block.contains('.')) {
      title = block.split('.').skip(1).take(1).join().trim();
      if (title.isEmpty) title = block.split('.').first.trim();
    }
    if (title.isEmpty) title = block.trim();

    final authorsPart = quoted != null
        ? block.substring(0, quoted.start).trim()
        : (yearMatch != null
            ? block.substring(0, yearMatch.start).trim()
            : block.split('.').first.trim());
    final authors = _parseAuthorList(authorsPart);

    final vol = RegExp(r'\bvol\.?\s*(\d+)', caseSensitive: false)
            .firstMatch(block)
            ?.group(1) ??
        '';
    final issue = RegExp(r'\bno\.?\s*(\d+)', caseSensitive: false)
            .firstMatch(block)
            ?.group(1) ??
        RegExp(r'\((\d{1,4})\)').firstMatch(block)?.group(1) ??
        '';
    final pages = RegExp(
          r'\bpp?\.?\s*(\d+\s*[-–]\s*\d+)',
          caseSensitive: false,
        ).firstMatch(block)?.group(1)?.replaceAll(' ', '') ??
        '';

    return PublishReference(
      id: id,
      type: ReferenceType.journal,
      authors: authors,
      title: title.length > 300 ? title.substring(0, 300) : title,
      year: year,
      doi: doi,
      volume: vol,
      issue: issue,
      pages: pages,
      container: _guessContainer(block),
      importedNumber: n,
      rawText: storedRaw,
    );
  }

  static List<String> _parseAuthorList(String authorsPart) {
    final acsNames = RegExp(r"([A-Z][a-z][A-Za-z'\-]*),\s*((?:[A-Z]\.\s*)+)")
        .allMatches(authorsPart)
        .map((m) => '${m.group(1)!.trim()}, ${m.group(2)!.trim()}')
        .where((a) => a.length >= 4)
        .toList();
    if (authorsPart.contains(';') && acsNames.isNotEmpty) {
      return acsNames.take(12).toList();
    }

    final vancouver = CitationFormatter.parseVancouverCompactAuthors(
      authorsPart,
    );
    if (vancouver.length >= 2) return vancouver.take(12).toList();

    final ieee = RegExp(r"(?:[A-Z]\.\s*)+[A-Z][A-Za-z'\-]{2,}")
        .allMatches(authorsPart)
        .map((m) => m.group(0)!.trim())
        .where((a) => a.length >= 3 && a.length < 80)
        .toList();
    if (ieee.isNotEmpty) return ieee.take(12).toList();

    if (acsNames.isNotEmpty) return acsNames.take(12).toList();
    return const [];
  }

  static String _guessContainer(String block) {
    final journal = RegExp(
      r'(?:in|,\s*)([A-Z][^,.\n]{4,80}(?:Journal|Review|Letters|Science|Research)[^,.\n]*)',
    ).firstMatch(block);
    return journal?.group(1)?.trim() ?? '';
  }
}

class ManuscriptParseResult {
  final String fullText;
  final String bodyText;
  final List<PublishReference> references;
  final List<ManuscriptBlock> bodyBlocks;
  final List<ImportedDocumentImage> images;

  const ManuscriptParseResult({
    required this.fullText,
    required this.bodyText,
    required this.references,
    this.bodyBlocks = const [],
    this.images = const [],
  });

  ManuscriptParseResult copyWith({
    List<PublishReference>? references,
    List<ManuscriptBlock>? bodyBlocks,
  }) {
    return ManuscriptParseResult(
      fullText: fullText,
      bodyText: bodyText,
      references: references ?? this.references,
      bodyBlocks: bodyBlocks ?? this.bodyBlocks,
      images: images,
    );
  }
}
