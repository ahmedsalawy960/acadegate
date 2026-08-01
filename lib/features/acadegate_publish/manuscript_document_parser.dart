import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../core/firebase/callable_http_client.dart';
import '../../core/locale/app_translate.dart';
import 'docx_scientific_extractor.dart';
import 'manuscript_image_session_cache.dart';
import 'manuscript_upload_service.dart';
import 'publish_models.dart';

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

class ManuscriptDocumentParser {
  ManuscriptDocumentParser._();

  /// Soft cap only — media (figures/tables/equations) is never dropped.
  static const maxImportedBlocks = 500;
  static const maxImportedReferences = 200;
  static const maxBlockTextLength = 120000;
  static const maxRawTextLength = 800;
  /// Skip tiny media (bullets / icon chrome) when recovering unused word/media files.
  static const minRecoveredMediaBytes = 2500;

  /// Firebase Storage upload listeners crash on Windows desktop (plugin threading).
  static bool get skipImportImageUpload =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Full cloud extract (text + images + tables) on all platforms.
  static bool get useLightCloudExtract => false;

  static Future<ManuscriptParseResult> parseFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    final lower = filename.toLowerCase();
    ManuscriptParseResult? cloudResult;

    try {
      cloudResult = await _parseViaCloud(bytes, filename);
    } catch (_) {
      // Fall through to local parsing for DOCX.
    }

    if (lower.endsWith('.docx')) {
      final text = _extractDocxText(bytes);
      final blocks = _extractDocxBlocks(bytes);
      if (text.trim().length < 40 && blocks.isEmpty) {
        if (cloudResult != null && cloudResult.fullText.trim().length >= 40) {
          return cloudResult;
        }
        throw Exception(appTr(
          'لم يُستخرج نص كافٍ من الملف',
          'Could not extract enough text from file',
        ));
      }
      final local = _resultFromText(text, blocks: blocks);
      if (cloudResult == null) return local;
      return _mergeParseResults(local: local, cloud: cloudResult);
    }

    if (cloudResult != null) {
      if (cloudResult.bodyBlocks.isNotEmpty ||
          cloudResult.references.isNotEmpty) {
        return cloudResult;
      }
      final refs = _parseReferences(cloudResult.fullText);
      if (refs.isNotEmpty) {
        return cloudResult.copyWith(references: refs);
      }
      return cloudResult;
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
    final cloudRefs = cloud.references;
    final localRefs = local.references;
    final bestRefs =
        cloudRefs.length >= localRefs.length ? cloudRefs : localRefs;

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

    return ManuscriptParseResult(
      fullText: bestText,
      bodyText: _bodyWithoutBibliography(bestText),
      references: bestRefs,
      bodyBlocks: _finalizeBodyBlocks(bestBlocks),
      images: local.images.isNotEmpty ? local.images : cloud.images,
    );
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
  }) async {
    if (filename.toLowerCase().endsWith('.docx')) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return parseFile(bytes: response.bodyBytes, filename: filename);
        }
      } catch (_) {
        // Fall through to cloud-only path.
      }
    }

    try {
      return await _parseViaCloudRequest(
        filename: filename,
        fileUrl: url,
      );
    } catch (cloudError) {
      if (!filename.toLowerCase().endsWith('.docx')) rethrow;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception(appTr(
          'تعذر تحميل الملف من التخزين',
          'Could not download file from storage',
        ));
      }
      return parseFile(bytes: response.bodyBytes, filename: filename);
    }
  }

  static bool _isMediaBlock(ManuscriptBlock block) =>
      block.type == ManuscriptBlockType.image ||
      block.type == ManuscriptBlockType.table ||
      block.type == ManuscriptBlockType.equation;

  static List<ManuscriptBlock> sanitizeImportedBlocks(List<ManuscriptBlock> blocks) {
    final trimmed = blocks.map((block) {
      if (block.text.length <= maxBlockTextLength) return block;
      return block.copyWith(text: block.text.substring(0, maxBlockTextLength));
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
      if (ref.rawText.length <= maxRawTextLength) return ref;
      return ref.copyWith(rawText: ref.rawText.substring(0, maxRawTextLength));
    }).toList();

    if (references.length <= maxImportedReferences) return capped;

    return [
      ...capped,
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

  static String _extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
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
        buffer.writeln(_textFromWordXml(xmlStr));
      } catch (_) {
        // Skip malformed XML parts.
      }
    }

    return buffer.toString().trim();
  }

  static String _textFromWordXml(String xmlStr) {
    final doc = XmlDocument.parse(xmlStr);
    final buffer = StringBuffer();

    void writeParagraphs(Iterable<XmlElement> paragraphs) {
      for (final paragraph in paragraphs) {
        _appendParagraphText(paragraph, buffer);
        buffer.writeln();
      }
    }

    writeParagraphs(doc.findAllElements('w:p'));
    for (final txbx in doc.findAllElements('w:txbxContent')) {
      writeParagraphs(txbx.findAllElements('w:p'));
    }

    return buffer.toString();
  }

  static void _appendParagraphText(XmlElement paragraph, StringBuffer buffer) {
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
    var vertAlign = '';
    for (final el in run.descendants.whereType<XmlElement>()) {
      if (el.localName == 'vertAlign') {
        vertAlign =
            (el.getAttribute('val') ?? el.getAttribute('w:val') ?? '').toLowerCase();
        break;
      }
    }
    // Only direct text nodes of this run (avoid nested run duplication).
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
    if (text.isEmpty) return;
    buffer.write(switch (vertAlign) {
      'subscript' => _toSubscriptUnicode(text),
      'superscript' => _toSuperscriptUnicode(text),
      _ => text,
    });
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
  }) {
    final blocks = <ManuscriptBlock>[];
    final textBuffer = StringBuffer();
    final hasEqField = DocxScientificExtractor.paragraphHasEquationField(element);

    void flushText() {
      final text = _cleanExtractedText(textBuffer.toString());
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

    void addVisualBlocks(XmlElement visualNode, {required bool asEquation}) {
      if (imageCount() >= maxLocalImages) return;
      for (final url in _extractAllEmbeddedImages(visualNode, archive, rels)) {
        if (imageCount() >= maxLocalImages) break;
        onVisualUsed(url);
        final id = nextId();
        _registerImageUri(id, url);
        blocks.add(ManuscriptBlock(
          id: id,
          type: asEquation
              ? ManuscriptBlockType.equation
              : ManuscriptBlockType.image,
          text: asEquation ? '' : '',
          imageUrl: url,
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
          _appendRunText(child, textBuffer);
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
          for (final branch in child.children.whereType<XmlElement>()) {
            if (branch.localName == 'Choice' ||
                branch.localName == 'Fallback') {
              walkNonMath(branch);
              break;
            }
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
    if (references.isEmpty && fullText.trim().isNotEmpty) {
      references = sanitizeImportedReferences(_parseReferences(fullText));
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

    return ManuscriptParseResult(
      fullText: fullText,
      bodyText: cleanBodyText.isNotEmpty ? cleanBodyText : bodyText,
      references: references,
      bodyBlocks: bodyBlocks,
      images: const [],
    );
  }

  static ManuscriptParseResult _resultFromText(
    String text, {
    List<ManuscriptBlock> blocks = const [],
  }) {
    final bodyText = _bodyWithoutBibliography(text);
    final bodyBlocks = blocks.isNotEmpty
        ? _finalizeBodyBlocks(blocks)
        : sanitizeImportedBlocks(_blocksFromPlainText(bodyText));
    return ManuscriptParseResult(
      fullText: text,
      bodyText: bodyText,
      references: _parseReferences(text),
      bodyBlocks: bodyBlocks,
    );
  }

  /// Merge Word paragraphs into readable sections; keep tables/figures separate.
  static List<ManuscriptBlock> _finalizeBodyBlocks(List<ManuscriptBlock> blocks) {
    if (blocks.isEmpty) return blocks;
    final structured = sanitizeImportedBlocks(
      mergeSectionParagraphs(structureImportedBlocks(blocks)),
    );
    _warmImageSessionCache(structured);
    return structured;
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

      if (_isMajorSectionHeading(t) ||
          (block.type == ManuscriptBlockType.heading &&
              _isMajorSectionHeading(block.text))) {
        cleaned.add(ManuscriptBlock(
          id: block.id.isNotEmpty ? block.id : nextId(),
          type: ManuscriptBlockType.heading,
          text: _normalizeKnownSectionHeading(t),
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
      if (_isMajorSectionHeading(t)) return false;
      if (_isTableCaption(t) || _isFigureCaption(t)) return false;
      if (DocxScientificExtractor.isEquationFragment(t)) return false;
      return true;
    }

    for (final block in cleaned) {
      if (block.type == ManuscriptBlockType.heading &&
          _isMajorSectionHeading(block.text)) {
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

  /// True for Abstract / Introduction / Experimental / Results / Discussion /
  /// Conclusion (and Arabic equivalents) — not method sub-titles.
  static bool _isMajorSectionHeading(String line) {
    final t = line.trim();
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
      r'النتائج|المناقشة|الخاتمة|الاستنتاجات?|المراجع|كلمات مفتاحية)\s*:?\s*$',
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
        return b.copyWith(rows: ManuscriptBlock.normalizedRows(b.rows));
      }
      return b;
    }).toList();

    final insertAt = out.length >= 3 ? 3 : out.length;
    out.insertAll(insertAt, media);
    return out;
  }

  static bool _referenceLooksValid(PublishReference ref) {
    final text =
        ref.rawText.trim().isNotEmpty ? ref.rawText.trim() : ref.title.trim();
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

  /// Academic layout: title/authors → abstract/keywords → body (+ tables/images).
  static List<ManuscriptBlock> structureImportedBlocks(
    List<ManuscriptBlock> blocks,
  ) {
    if (blocks.isEmpty) return blocks;
    return _structureAcademicPaper(
      _attachMediaCaptions(_expandEmbeddedSectionHeadings(blocks)),
    );
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
        if (t.contains('\n') &&
            RegExp(
              r'(Abstract|Introduction|Experimental|Methods|Results|Discussion)\b',
              caseSensitive: false,
            ).hasMatch(t)) {
          out.addAll(DocxScientificExtractor.splitTextBySectionHeadings(t, nextId));
          continue;
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
    final t = _blockPlainText(block).trim();
    return RegExp(r'^keywords?\b', caseSensitive: false).hasMatch(t);
  }

  static bool _isIntroductionBlock(ManuscriptBlock block) {
    final t = _blockPlainText(block).trim();
    return RegExp(
      r'^(?:\d+\.?\s*)?(Introduction|Background)\b',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static bool _isBibliographyBlock(ManuscriptBlock block) {
    final t = _blockPlainText(block).trim().toLowerCase();
    return t == 'references' ||
        t == 'bibliography' ||
        t == 'works cited' ||
        t.contains('المراجع') ||
        t.contains('قائمة المراجع');
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

  static int _findBibliographyIndex(List<ManuscriptBlock> blocks) {
    for (var i = 0; i < blocks.length; i++) {
      if (_isBibliographyBlock(blocks[i])) return i;
    }
    return blocks.length;
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
          if (_isMajorSectionHeading(t)) {
            emitHeading(_normalizeKnownSectionHeading(t));
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
                      _isMajorSectionHeading(part.text)) {
                    emitHeading(_normalizeKnownSectionHeading(part.text));
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
                  _isMajorSectionHeading(part.text)) {
                emitHeading(_normalizeKnownSectionHeading(part.text));
              } else if (!_isJunkTextFragment(part.text)) {
                emitParagraph(part.text);
              }
            }
          }
        case ManuscriptBlockType.equation:
          out.add(block);
        case ManuscriptBlockType.table:
          out.add(block.copyWith(
            rows: ManuscriptBlock.normalizedRows(block.rows),
          ));
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

  static bool _isTableCaption(String text) {
    final t = text.trim();
    return RegExp(r'^Table\s+\d+', caseSensitive: false).hasMatch(t) ||
        RegExp(r'^جدول\s*\d+').hasMatch(t);
  }

  static bool _isFigureCaption(String text) {
    final t = text.trim();
    return RegExp(r'^Figure\s+[\d٠-٩]+', caseSensitive: false).hasMatch(t) ||
        RegExp(r'^Fig(?:ure)?\.?\s*[\d٠-٩]+', caseSensitive: false).hasMatch(t) ||
        RegExp(r'^شكل(?:\s*رقم)?\s*[\d٠-٩]+').hasMatch(t) ||
        RegExp(r'^الصورة\s*[\d٠-٩]+').hasMatch(t);
  }

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
        final table = blocks[i + 1].copyWith(
          caption: block.text.trim(),
          rows: ManuscriptBlock.normalizedRows(blocks[i + 1].rows),
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
        out.add(block.copyWith(rows: ManuscriptBlock.normalizedRows(block.rows)));
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
        (file) {
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
        },
      );

      var inBibliography = false;
      for (final child in body.children.whereType<XmlElement>()) {
        final tag = child.localName;

        if (tag == 'p' && _isBibliographyParagraph(child)) {
          inBibliography = true;
          continue;
        }

        if (inBibliography && tag == 'p') {
          final plain = _paragraphPlainText(child).trim();
          if (_isAppendixHeading(plain)) {
            inBibliography = false;
          } else {
            final paraBlocks = _blocksFromDocxParagraph(
              child,
              archive: archive,
              rels: rels,
              nextId: nextId,
              onVisualUsed: onVisualUsed,
              imageCount: () => imageCount,
              maxLocalImages: maxLocalImages,
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
        if (inBibliography &&
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
      result = _recoverOrphanFigureImages(
        blocks: result,
        mediaPool: mediaPool,
        usedVisualUris: usedVisualUris,
        nextId: nextId,
      );
      result = _appendUnusedMediaAsFigures(
        blocks: result,
        mediaPool: mediaPool,
        usedVisualUris: usedVisualUris,
        nextId: nextId,
      );
      return result;
    } catch (_) {
      return const [];
    }
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

  /// Attach any remaining word/media assets not linked from document XML.
  static List<ManuscriptBlock> _appendUnusedMediaAsFigures({
    required List<ManuscriptBlock> blocks,
    required List<String> mediaPool,
    required Set<String> usedVisualUris,
    required String Function() nextId,
  }) {
    final unused = mediaPool.where((u) => !usedVisualUris.contains(u)).toList()
      ..sort(
        (a, b) => _dataUriByteLength(b).compareTo(_dataUriByteLength(a)),
      );
    if (unused.isEmpty) return blocks;

    final out = List<ManuscriptBlock>.from(blocks);
    var added = 0;
    for (final uri in unused) {
      if (_dataUriByteLength(uri) < minRecoveredMediaBytes) continue;
      usedVisualUris.add(uri);
      final id = nextId();
      _registerImageUri(id, uri);
      added++;
      out.add(ManuscriptBlock(
        id: id,
        type: ManuscriptBlockType.image,
        imageUrl: uri,
        caption: appTr(
          'شكل مستخرج من الملف ($added)',
          'Extracted figure from file ($added)',
        ),
      ));
    }
    return out;
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
  }) {
    final tag = element.localName;

    void addImagesFrom(XmlElement node) {
      if (imageCount() >= maxLocalImages) return;
      for (final imageData in _extractAllEmbeddedImages(node, archive, rels)) {
        if (imageCount() >= maxLocalImages) break;
        onVisualUsed(imageData);
        final id = nextId();
        _registerImageUri(id, imageData);
        blocks.add(ManuscriptBlock(
          id: id,
          type: ManuscriptBlockType.image,
          imageUrl: imageData,
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
        var cellImages = parsed.rowCellImages;
        for (final row in cellImages) {
          for (final url in row) {
            if (url.isNotEmpty) usedVisualUris.add(url);
          }
        }
        final filled = DocxScientificExtractor.fillStructureColumnFromMediaPool(
          rows: parsed.rows,
          rowCellImages: cellImages,
          mediaPool: mediaPool,
          alreadyUsed: usedVisualUris,
        );
        usedVisualUris.addAll(filled.usedUris);
        blocks.add(ManuscriptBlock(
          id: nextId(),
          type: ManuscriptBlockType.table,
          rows: parsed.rows,
          rowCellImages: filled.rowCellImages,
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
      // Prefer Choice, then Fallback.
      final choice = element.children.whereType<XmlElement>().where(
            (c) => c.localName == 'Choice' || c.localName == 'Fallback',
          );
      for (final branch in choice) {
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
          );
        }
        break;
      }
      return false;
    }

    // Nested containers (e.g. custom XML / content controls wrappers).
    if (tag == 'body' || tag == 'tc' || tag == 'txbxContent') {
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
        );
      }
    }
    return false;
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

    // DrawingML pictures.
    for (final embed in node.findAllElements('blip')) {
      addUri(_relationshipToDataUri(embed, archive, rels, idAttrs: const [
        'embed',
        'link',
      ]));
    }
    // VML pictures (older Word / ChemDraw / OLE preview).
    for (final img in node.findAllElements('imagedata')) {
      addUri(_relationshipToDataUri(img, archive, rels, idAttrs: const [
        'id',
        'href',
      ]));
    }
    // Any relationship id on nested elements (covers unusual ChemDraw embeds).
    for (final el in node.findAllElements('*')) {
      String? relId;
      for (final attr in el.attributes) {
        final local = attr.name.local.toLowerCase();
        if (local == 'embed' ||
            local == 'link' ||
            local == 'id' ||
            local == 'href') {
          if (attr.value.isNotEmpty) {
            relId = attr.value;
            break;
          }
        }
      }
      if (relId != null && rels.containsKey(relId)) {
        addUri(_dataUriFromRelId(relId, archive, rels));
      }
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
      relId ??= element.getAttribute(name) ?? element.getAttribute('r:$name');
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
    final text = _paragraphPlainText(paragraph).trim().toLowerCase();
    return text == 'references' ||
        text == 'bibliography' ||
        text == 'works cited' ||
        text.contains('المراجع') ||
        text.contains('قائمة المراجع');
  }

  static bool _isHeadingParagraph(XmlElement paragraph) {
    for (final style in paragraph.findAllElements('pStyle')) {
      final val = style.getAttribute('val') ?? style.getAttribute('w:val') ?? '';
      if (val.toLowerCase().contains('heading')) return true;
    }
    final text = _paragraphPlainText(paragraph).trim();
    return text.length < 80 && !text.endsWith('.') && text == text.toUpperCase();
  }

  static ({List<List<String>> rows, List<List<String>> rowCellImages})
      _parseDocxTableWithImages(
    XmlElement table,
    Archive archive,
    Map<String, String> rels,
  ) {
    final rows = <List<String>>[];
    final cellImages = <List<String>>[];

    for (final tr in table.children.whereType<XmlElement>()) {
      if (tr.localName != 'tr') continue;
      final rowTexts = <String>[];
      final rowImgs = <String>[];

      for (final tc in tr.children.whereType<XmlElement>()) {
        if (tc.localName != 'tc') continue;
        final cell = _parseTableCellContent(tc, archive, rels);
        rowTexts.add(cell.text);
        rowImgs.add(cell.imageUrl ?? '');
      }

      if (rowTexts.isNotEmpty) {
        rows.add(rowTexts);
        cellImages.add(rowImgs);
      }
    }

    final normalized = ManuscriptBlock.normalizedRows(rows);
    return (
      rows: normalized,
      rowCellImages: ManuscriptBlock.normalizedCellImages(cellImages, normalized),
    );
  }

  static ({String text, String? imageUrl}) _parseTableCellContent(
    XmlElement tc,
    Archive archive,
    Map<String, String> rels,
  ) {
    final buffer = StringBuffer();
    String? imageUrl;

    void pickImage(String? url) {
      if (url == null || url.isEmpty) return;
      imageUrl ??= url;
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
          for (final branch in node.children.whereType<XmlElement>()) {
            if (branch.localName == 'Choice' ||
                branch.localName == 'Fallback') {
              for (final inner in branch.children.whereType<XmlElement>()) {
                walkCell(inner);
              }
              return;
            }
          }
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

    return (text: _cleanExtractedText(buffer.toString()), imageUrl: imageUrl);
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

      if (url.isEmpty &&
          (block.imageUrl?.startsWith('data:') == true ||
              block.imageUrl?.startsWith('{{img:') == true)) {
        resolved.add(ManuscriptBlock(
          id: block.id,
          type: ManuscriptBlockType.paragraph,
          text: block.caption?.isNotEmpty == true
              ? '[${block.caption}]'
              : '[Figure]',
        ));
        continue;
      }

      resolved.add(block.copyWith(imageUrl: url.isEmpty ? block.imageUrl : url));
    }
    return resolved;
  }

  /// Firestore cannot store large base64 data URIs — strip before persistence on Windows.
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

    if (next.title.trim().isEmpty) {
      final title = _extractTitleFromBlocks(next.bodyBlocks);
      if (title != null && title.length > 10) {
        next = next.copyWith(title: title);
      } else if (parsed.bodyText.length > 20) {
        final extracted =
            DocxScientificExtractor.extractPaperTitle(parsed.bodyText);
        if (extracted != null && extracted.length > 10) {
          next = next.copyWith(title: extracted);
        }
      }
    }
    return next;
  }

  static String _bodyWithoutBibliography(String text) {
    final idx = _bibliographyStartIndex(text);
    if (idx == null) return text.trim();
    return text.substring(0, idx).trim();
  }

  static int? _bibliographyStartIndex(String text) {
    if (text.trim().isEmpty) return null;

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

  static bool _isBibliographyHeadingLine(String line) {
    final t = line.trim();
    if (t.isEmpty || t.length > 70) return false;
    if (RegExp(r'[.!?]').hasMatch(t) && t.split(RegExp(r'[.!?]')).length > 2) {
      return false;
    }

    return RegExp(
      r'^(References|Bibliography|Works Cited|Reference List|Literature Cited|REFERENCES)\s*\.?\s*$',
      caseSensitive: false,
    ).hasMatch(t) ||
        RegExp(r'^(المراجع|قائمة المراجع|المصادر)( والمصادر)?\s*\.?\s*$')
            .hasMatch(t);
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
    final section = _bibliographySection(fullText);
    if (section.isEmpty) {
      return _parseIeeeTailStrict(fullText);
    }

    final ieee = _parseIeee(section).where(_referenceLooksValid).toList();
    if (ieee.length >= 2) return ieee;

    final apa = _parseApa(section);
    if (apa.isNotEmpty) return apa;

    final numbered = _parseNumbered(section);
    if (numbered.isNotEmpty) return numbered;

    return _parseParagraphBlocks(section);
  }

  static List<PublishReference> _parseIeeeTailStrict(String fullText) {
    final tailStart = (fullText.length * 0.78).floor();
    final tail = fullText.substring(tailStart);
    final refs = _parseIeee(tail).where(_referenceLooksValid).toList();
    if (refs.length >= 3) return refs;
    return const [];
  }

  /// APA / author–year lines: Smith, J. (2020). Title...
  static List<PublishReference> _parseApa(String section) {
    final lines = section.split('\n');
    final merged = <String>[];
    var current = StringBuffer();

    bool startsReference(String line) {
      final t = line.trim();
      if (t.length < 20) return false;
      if (RegExp(r'^\[\d+\]').hasMatch(t)) return true;
      if (RegExp(r'^\d+[.)]\s').hasMatch(t)) return true;
      return RegExp(r'\(\d{4}[a-z]?\)').hasMatch(t) ||
          (RegExp(r'\b(19|20)\d{2}\b').hasMatch(t) && t.length > 35);
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (current.isNotEmpty) {
          merged.add(current.toString().trim());
          current = StringBuffer();
        }
        continue;
      }
      if (startsReference(line)) {
        if (current.isNotEmpty) merged.add(current.toString().trim());
        current = StringBuffer(line);
      } else if (current.isNotEmpty) {
        current.write(' ');
        current.write(line);
      }
    }
    if (current.isNotEmpty) merged.add(current.toString().trim());

    final refs = <PublishReference>[];
    var i = 0;
    for (final block in merged) {
      if (block.length < 25) continue;
      if (_looksLikeReference(block)) {
        refs.add(_blockToReference(block, id: 'ref_${++i}'));
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
      final block = m.group(2)?.trim() ?? '';
      if (block.length < 8 || !_looksLikeReference(block)) continue;
      refs.add(_blockToReference(block, id: 'ref_${m.group(1)}'));
    }
    return refs;
  }

  static List<PublishReference> _parseNumbered(String section) {
    final pattern = RegExp(
      r'(?<=\n|^)(\d+)[.)]\s+([\s\S]*?)(?=\n\d+[.)]\s|\n*$)',
      multiLine: true,
    );
    final refs = <PublishReference>[];
    for (final m in pattern.allMatches(section)) {
      final block = m.group(2)?.trim() ?? '';
      if (block.length < 15) continue;
      refs.add(_blockToReference(block, id: 'ref_${m.group(1)}'));
    }
    return refs;
  }

  static List<PublishReference> _parseParagraphBlocks(String section) {
    final blocks = section
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.length > 25)
        .toList();

    final refs = <PublishReference>[];
    var i = 0;
    for (final block in blocks) {
      if (_looksLikeReference(block)) {
        refs.add(_blockToReference(block, id: 'ref_${++i}'));
      }
    }
    return refs;
  }

  static bool _looksLikeReference(String block) {
    final t = block.trim();
    if (t.length < 20 || t.length > 2500) return false;

    if (RegExp(
      r'^(The|This|In |However|Moreover|Figure|Table|Results show|Conclusion|Abstract|GC-MS|Analysis|Method|Sample|Flaxseed|Therefore|These|It is|We |Our )',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }

    final hasYear = RegExp(r'\(\d{4}[a-z]?\)|,\s*(19|20)\d{2}\b|\b(19|20)\d{2}\b')
        .hasMatch(t);
    if (!hasYear) return false;

    if (RegExp(r'doi\.org|DOI:|vol\.|pp\.|Journal|Proceedings|\bet al\.',
            caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }

    return RegExp(r'^[A-Z][A-Za-z\-,\s\.]{2,80},\s*[A-Z\.]').hasMatch(t);
  }

  static PublishReference _blockToReference(String block, {required String id}) {
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(block);
    final year = yearMatch?.group(0) ?? '';

    final doiMatch = RegExp(
      r'(?:doi[:\s]*|https?://doi\.org/)([^\s,]+)',
      caseSensitive: false,
    ).firstMatch(block);
    final doi = doiMatch?.group(1)?.replaceAll(RegExp(r'[.)]$'), '') ?? '';

    var title = block;
    final quoted = RegExp(r'"([^"]+)"').firstMatch(block);
    if (quoted != null) {
      title = quoted.group(1) ?? title;
    } else if (block.contains('.')) {
      title = block.split('.').first.trim();
    }

    final authorsPart = yearMatch != null
        ? block.substring(0, yearMatch.start).trim()
        : block.split('.').first.trim();
    final authors = _parseAuthorList(authorsPart);

    return PublishReference(
      id: id,
      type: ReferenceType.journal,
      authors: authors,
      title: title.length > 300 ? title.substring(0, 300) : title,
      year: year,
      doi: doi,
      container: _guessContainer(block),
      rawText: block.trim(),
    );
  }

  static List<String> _parseAuthorList(String authorsPart) {
    final trimmed = authorsPart.trim();
    if (trimmed.isEmpty) return const [];

    final parts = trimmed.contains(';')
        ? trimmed.split(';')
        : trimmed.split(RegExp(r',|\band\b', caseSensitive: false));

    return parts
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty && a.length < 80)
        .take(8)
        .toList();
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
