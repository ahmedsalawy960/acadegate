import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/locale/app_translate.dart';
import 'citation_formatter.dart';
import 'docx_share.dart';
import 'docx_scientific_extractor.dart';
import 'manuscript_image_session_cache.dart';
import 'journal_format_rules.dart';
import 'manuscript_citation_helper.dart';
import 'publish_models.dart';

class _DocxEmbeddedImage {
  final int relId;
  final String partName;
  final Uint8List bytes;
  final String contentType;

  const _DocxEmbeddedImage({
    required this.relId,
    required this.partName,
    required this.bytes,
    required this.contentType,
  });
}

class ManuscriptDocxExportService {
  ManuscriptDocxExportService._();

  static final ManuscriptDocxExportService instance =
      ManuscriptDocxExportService._();

  Future<void> shareFormattedDocx({
    required PublishManuscript manuscript,
    required JournalFormatRules rules,
  }) async {
    final bytes = await buildDocx(manuscript: manuscript, rules: rules);
    final name = _safeFileName(manuscript.title, rules.journalName);
    await shareDocxBytes(bytes: bytes, name: name);
  }

  Future<Uint8List> buildDocx({
    required PublishManuscript manuscript,
    required JournalFormatRules rules,
  }) async {
    final embeddedImages = <_DocxEmbeddedImage>[];
    final bodyXml = StringBuffer();
    final style = rules.citationStyle;

    if (manuscript.title.trim().isNotEmpty) {
      bodyXml.write(_paragraph(
        manuscript.title.trim(),
        rules: rules,
        bold: true,
        fontHalfPoints: rules.titleFontHalfPoints,
        align: 'center',
        spacingAfter: 240,
      ));
    }

    if (manuscript.abstractText.trim().isNotEmpty) {
      bodyXml.write(_paragraph(
        appTr('الملخص', 'Abstract'),
        rules: rules,
        bold: true,
        fontHalfPoints: rules.headingFontHalfPoints,
        spacingBefore: 120,
        spacingAfter: 60,
      ));
      bodyXml.write(_paragraph(
        _resolveBodyText(
          text: manuscript.abstractText.trim(),
          manuscript: manuscript,
          style: style,
          rules: rules,
        ),
        rules: rules,
        spacingAfter: 200,
      ));
    }

    final blocks = manuscript.bodyBlocks.isNotEmpty
        ? manuscript.bodyBlocks
        : PublishManuscript.blocksFromLegacyBody(manuscript.body);

    for (final block in blocks) {
      if (block.type == ManuscriptBlockType.heading &&
          block.text.trim() == manuscript.title.trim()) {
        continue;
      }
      bodyXml.write(await _blockXml(
        block,
        manuscript,
        rules,
        style,
        embeddedImages,
      ));
    }

    final bibRefs = ManuscriptCitationHelper.bibliographyReferences(
      manuscript,
      citedOnly: true,
    );
    if (bibRefs.isNotEmpty) {
      bodyXml.write(_paragraph(
        rules.referenceSectionTitle,
        rules: rules,
        bold: true,
        fontHalfPoints: rules.headingFontHalfPoints,
        spacingBefore: 240,
        spacingAfter: 120,
      ));
      final entries = CitationFormatter.buildBibliographyEntries(
        references: bibRefs,
        style: style,
        plainNumberList: rules.referenceListPlainNumber,
      );
      for (final entry in entries) {
        bodyXml.write(_bibliographyParagraph(entry, rules));
      }
    }

    bodyXml.write(_sectionProperties(rules));

    final documentXml = _documentXml(bodyXml.toString());
    final stylesXml = _stylesXml(rules);
    final contentTypesXml = _contentTypesXml(embeddedImages);
    final rootRelsXml = _rootRelsXml();
    final documentRelsXml = _documentRelsXml(embeddedImages);

    final archive = Archive()
      ..addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length,
          utf8.encode(contentTypesXml)))
      ..addFile(ArchiveFile(
          '_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)))
      ..addFile(ArchiveFile('word/document.xml', documentXml.length,
          utf8.encode(documentXml)))
      ..addFile(ArchiveFile('word/styles.xml', stylesXml.length,
          utf8.encode(stylesXml)))
      ..addFile(ArchiveFile('word/_rels/document.xml.rels',
          documentRelsXml.length, utf8.encode(documentRelsXml)));

    for (final img in embeddedImages) {
      archive.addFile(ArchiveFile(
        'word/${img.partName}',
        img.bytes.length,
        img.bytes,
      ));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<String> _blockXml(
    ManuscriptBlock block,
    PublishManuscript manuscript,
    JournalFormatRules rules,
    PublishCitationStyle style,
    List<_DocxEmbeddedImage> embeddedImages,
  ) async {
    return switch (block.type) {
      ManuscriptBlockType.heading => _paragraph(
          _resolveBodyText(
            text: block.text,
            manuscript: manuscript,
            style: style,
            rules: rules,
          ),
          rules: rules,
          bold: true,
          fontHalfPoints: rules.headingFontHalfPoints,
          spacingBefore: 160,
          spacingAfter: 80,
        ),
      ManuscriptBlockType.paragraph => _paragraph(
          _resolveBodyText(
            text: block.text,
            manuscript: manuscript,
            style: style,
            rules: rules,
          ),
          rules: rules,
          spacingAfter: 80,
        ),
      ManuscriptBlockType.equation => await _equationXml(
          block,
          rules,
          embeddedImages,
        ),
      ManuscriptBlockType.image => await _imageXml(block, rules, embeddedImages),
      ManuscriptBlockType.table => await _tableXml(
          block,
          manuscript,
          rules,
          embeddedImages,
        ),
    };
  }

  Future<String> _imageXml(
    ManuscriptBlock block,
    JournalFormatRules rules,
    List<_DocxEmbeddedImage> embeddedImages,
  ) async {
    final buffer = StringBuffer();
    final payload = await _loadImagePayload(block.imageUrl);
    if (payload != null) {
      final relId = embeddedImages.length + 2;
      final partName = 'media/export_img_$relId.${payload.ext}';
      embeddedImages.add(_DocxEmbeddedImage(
        relId: relId,
        partName: partName,
        bytes: payload.bytes,
        contentType: payload.mime,
      ));
      final size = _fitImageEmu(payload.bytes, maxWidthEmu: 5486400);
      buffer.write(_inlineImageParagraph(
        relId: relId,
        rules: rules,
        widthEmu: size.$1,
        heightEmu: size.$2,
      ));
    } else {
      buffer.write(_imagePlaceholder(block, rules));
    }

    final caption = block.caption?.trim() ?? '';
    if (caption.isNotEmpty) {
      buffer.write(_paragraph(
        caption,
        rules: rules,
        italic: true,
        align: 'center',
        spacingAfter: 120,
      ));
    }
    return buffer.toString();
  }

  String _inlineImageParagraph({
    required int relId,
    required JournalFormatRules rules,
    int widthEmu = 4572000,
    int heightEmu = 3429000,
  }) {
    final rId = 'rId$relId';
    return '''
<w:p>
  <w:pPr>
    <w:jc w:val="center"/>
    <w:spacing w:before="60" w:after="60" w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}"/>
  </w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0"
        xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="$widthEmu" cy="$heightEmu"/>
        <wp:docPr id="$relId" name="Picture $relId"/>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="Picture"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm><a:off x="0" y="0"/><a:ext cx="$widthEmu" cy="$heightEmu"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>''';
  }

  Future<({Uint8List bytes, String ext, String mime})?> _loadImagePayload(
    String? source,
  ) async {
    final url = source?.trim() ?? '';
    if (url.isEmpty) return null;
    if (url.startsWith('{{img:')) {
      final cached = ManuscriptImageSessionCache.instance.resolve(url);
      if (cached != null) return _loadImagePayload(cached);
      return null;
    }
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma < 0) return null;
      try {
        final header = url.substring(0, comma);
        final mime = header.replaceFirst('data:', '').split(';').first;
        final bytes = base64Decode(url.substring(comma + 1));
        if (bytes.isEmpty) return null;
        final ext = _imageExtensionFromMime(mime, bytes);
        return (bytes: bytes, ext: ext, mime: _mimeForExt(ext));
      } catch (_) {
        return null;
      }
    }
    if (!url.startsWith('http')) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        final ext = _imageExtension(bytes);
        return (bytes: bytes, ext: ext, mime: _mimeForExt(ext));
      }
    } catch (_) {}
    return null;
  }

  String _imageExtension(Uint8List bytes) {
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
    if (bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'gif';
    }
    return 'png';
  }

  String _mimeForExt(String ext) => switch (ext) {
        'jpeg' || 'jpg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'emf' => 'image/x-emf',
        'wmf' => 'image/x-wmf',
        _ => 'image/png',
      };

  String _imageExtensionFromMime(String mime, Uint8List bytes) {
    if (mime.contains('emf')) return 'emf';
    if (mime.contains('wmf')) return 'wmf';
    return _imageExtension(bytes);
  }

  String _imagePlaceholder(ManuscriptBlock block, JournalFormatRules rules) {
    final caption = block.caption?.trim() ?? '';
    final label = caption.isNotEmpty
        ? caption
        : appTr('[شكل — أعد إدراجه من الملف الأصلي]', '[Figure — re-insert from original]');
    return _paragraph(
      label,
      rules: rules,
      italic: true,
      align: 'center',
      spacingBefore: 120,
      spacingAfter: 120,
    );
  }

  Future<String> _tableXml(
    ManuscriptBlock block,
    PublishManuscript manuscript,
    JournalFormatRules rules,
    List<_DocxEmbeddedImage> embeddedImages,
  ) async {
    if (block.rows.isEmpty) return '';
    final rows = ManuscriptBlock.normalizedRows(block.rows);
    final cellImages = ManuscriptBlock.normalizedCellImages(
      block.rowCellImages,
      rows,
    );
    final colWidths = _tableColumnWidthsPct(rows, cellImages);
    final buffer = StringBuffer();
    buffer.write('<w:tbl>');
    buffer.write('''
<w:tblPr>
  <w:tblW w:w="5000" w:type="pct"/>
  <w:tblBorders>
    <w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
  </w:tblBorders>
</w:tblPr>''');
    for (var r = 0; r < rows.length; r++) {
      buffer.write('<w:tr>');
      for (var c = 0; c < rows[r].length; c++) {
        final colW = c < colWidths.length ? colWidths[c] : 500;
        buffer.write('''
<w:tc>
  <w:tcPr>
    <w:tcW w:w="$colW" w:type="pct"/>
    <w:vAlign w:val="center"/>
  </w:tcPr>''');
        final imgUrl = r < cellImages.length && c < cellImages[r].length
            ? cellImages[r][c]
            : '';
        if (imgUrl.isNotEmpty) {
          final payload = await _loadImagePayload(imgUrl);
          if (payload != null) {
            final relId = embeddedImages.length + 2;
            final partName = 'media/export_img_$relId.${payload.ext}';
            embeddedImages.add(_DocxEmbeddedImage(
              relId: relId,
              partName: partName,
              bytes: payload.bytes,
              contentType: payload.mime,
            ));
            final size = _fitImageEmu(
              payload.bytes,
              maxWidthEmu: (5486400 * colW / 5000).round().clamp(800000, 3200000),
              maxHeightEmu: 1800000,
            );
            buffer.write(_inlineImageParagraph(
              relId: relId,
              rules: rules,
              heightEmu: size.$2,
              widthEmu: size.$1,
            ));
          }
        }
        final cellText = DocxScientificExtractor.formatChemicalFormula(
          rows[r][c].trim(),
        );
        if (cellText.isNotEmpty) {
          buffer.write(_paragraph(
            _resolveBodyText(
              text: cellText,
              manuscript: manuscript,
              style: rules.citationStyle,
              rules: rules,
            ),
            rules: rules,
            bold: r == 0,
            spacingAfter: 0,
            inTable: true,
          ));
        }
        buffer.write('</w:tc>');
      }
      buffer.write('</w:tr>');
    }
    buffer.write('</w:tbl>');
    if (block.caption != null && block.caption!.trim().isNotEmpty) {
      buffer.write(_paragraph(
        block.caption!.trim(),
        rules: rules,
        italic: true,
        align: 'center',
        spacingAfter: 120,
      ));
    }
    return buffer.toString();
  }

  Future<String> _equationXml(
    ManuscriptBlock block,
    JournalFormatRules rules,
    List<_DocxEmbeddedImage> embeddedImages,
  ) async {
    final buffer = StringBuffer();
    if (block.ommlXml != null && block.ommlXml!.trim().isNotEmpty) {
      buffer.write(_ommlParagraph(block.ommlXml!, rules));
    } else {
      final payload = await _loadImagePayload(block.imageUrl);
      if (payload != null) {
        final relId = embeddedImages.length + 2;
        final partName = 'media/export_img_$relId.${payload.ext}';
        embeddedImages.add(_DocxEmbeddedImage(
          relId: relId,
          partName: partName,
          bytes: payload.bytes,
          contentType: payload.mime,
        ));
        buffer.write(_inlineImageParagraph(relId: relId, rules: rules));
      } else {
        buffer.write(_paragraph(
          DocxScientificExtractor.formatVariableSubscripts(block.text),
          rules: rules,
          fontFamily: 'Cambria Math',
          align: 'center',
          italic: true,
          spacingAfter: 120,
        ));
      }
    }
    return buffer.toString();
  }

  String _ommlParagraph(String ommlXml, JournalFormatRules rules) {
    final inner = _normalizeOmmlXml(ommlXml);
    if (inner.isEmpty) return '';
    return '''
<w:p>
  <w:pPr>
    <w:jc w:val="center"/>
    <w:spacing w:before="120" w:after="120" w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}"/>
  </w:pPr>
  $inner
</w:p>''';
  }

  String _normalizeOmmlXml(String ommlXml) {
    var xml = ommlXml.trim();
    if (xml.isEmpty) return '';

    const mathNs =
        'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"';
    if (!xml.contains('oMathPara')) {
      xml =
          '<m:oMathPara $mathNs><m:oMath $mathNs>$xml</m:oMath></m:oMathPara>';
    } else if (!xml.contains('xmlns:m=')) {
      xml = xml.replaceFirst(
        RegExp(r'^<\w*:?oMathPara\b'),
        '<m:oMathPara $mathNs',
      );
    }

    const mathTags =
        'oMath|oMathPara|r|t|f|num|den|e|sub|sup|sSub|sSup|sSubSup|rad|deg|p|acc|bar|box|borderBox|func|groupChr|limLow|limUpp|m|nary|phant|sPre|eqArr|d';
    xml = xml.replaceAllMapped(
      RegExp('</?(?!m:)($mathTags)(\\s|/?>)'),
      (m) {
        final raw = m.group(0)!;
        if (raw.startsWith('</')) {
          return '</m:${m.group(1)!}>';
        }
        final suffix = m.group(2)!;
        if (suffix.startsWith('/')) return '<m:${m.group(1)!}/>';
        return '<m:${m.group(1)!}${suffix == ' ' ? ' ' : '>'}';
      },
    );
    return xml;
  }

  String _bibliographyParagraph(
    BibliographyEntry entry,
    JournalFormatRules rules,
  ) {
    final runs = StringBuffer();
    for (final span in entry.spans) {
      runs.write(_run(
        span.text,
        rules: rules,
        italic: span.italic,
        fontHalfPoints: rules.bodyFontHalfPoints - 2,
      ));
    }
    return '''
<w:p>
  <w:pPr>
    <w:spacing w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}" w:after="60"/>
    <w:ind w:left="360" w:hanging="360"/>
  </w:pPr>
  $runs
</w:p>''';
  }

  String _paragraph(
    String text, {
    required JournalFormatRules rules,
    bool bold = false,
    bool italic = false,
    int? fontHalfPoints,
    String? fontFamily,
    String align = '',
    int spacingBefore = 0,
    int spacingAfter = 0,
    bool inTable = false,
  }) {
    if (text.trim().isEmpty) return '';
    final alignXml = align.isNotEmpty ? '<w:jc w:val="$align"/>' : '';
    final justify = rules.justifyBody && align.isEmpty && !inTable
        ? '<w:jc w:val="both"/>'
        : alignXml;
    final spacing = (spacingBefore > 0 || spacingAfter > 0)
        ? '<w:spacing w:before="$spacingBefore" w:after="$spacingAfter" w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}"/>'
        : '<w:spacing w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}"/>';

    return '''
<w:p>
  <w:pPr>
    $spacing
    $justify
  </w:pPr>
  ${_run(
    text,
    rules: rules,
    bold: bold,
    italic: italic,
    fontHalfPoints: fontHalfPoints ?? rules.bodyFontHalfPoints,
    fontFamily: fontFamily,
  )}
</w:p>''';
  }

  String _run(
    String text, {
    required JournalFormatRules rules,
    bool bold = false,
    bool italic = false,
    int? fontHalfPoints,
    String? fontFamily,
  }) {
    final font = fontFamily ?? rules.fontFamily;
    final size = fontHalfPoints ?? rules.bodyFontHalfPoints;
    final boldXml = bold ? '<w:b/>' : '';
    final italicXml = italic ? '<w:i/>' : '';
    final escaped = _escapeXml(text);
    final preserve = text.startsWith(' ') || text.endsWith(' ')
        ? ' xml:space="preserve"'
        : '';
    return '''
<w:r>
  <w:rPr>
    <w:rFonts w:ascii="$font" w:hAnsi="$font" w:cs="$font"/>
    <w:sz w:val="$size"/>
    <w:szCs w:val="$size"/>
    $boldXml
    $italicXml
  </w:rPr>
  <w:t$preserve>$escaped</w:t>
</w:r>''';
  }

  String _sectionProperties(JournalFormatRules rules) {
    return '''
<w:sectPr>
  <w:pgSz w:w="11906" w:h="16838"/>
  <w:pgMar w:top="${rules.marginTwips}" w:right="${rules.marginTwips}" w:bottom="${rules.marginTwips}" w:left="${rules.marginTwips}" w:header="720" w:footer="720" w:gutter="0"/>
</w:sectPr>''';
  }

  String _documentXml(String body) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
    $body
  </w:body>
</w:document>''';
  }

  String _stylesXml(JournalFormatRules rules) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="${rules.fontFamily}" w:hAnsi="${rules.fontFamily}"/>
        <w:sz w:val="${rules.bodyFontHalfPoints}"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}" w:after="80"/>
        ${rules.justifyBody ? '<w:jc w:val="both"/>' : ''}
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>''';
  }

  List<int> _tableColumnWidthsPct(
    List<List<String>> rows,
    List<List<String>> cellImages,
  ) {
    if (rows.isEmpty) return const [5000];
    final cols = rows.first.length;
    final weights = List<int>.filled(cols, 10);
    for (var c = 0; c < cols; c++) {
      var maxLen = 8;
      var hasImage = false;
      for (var r = 0; r < rows.length; r++) {
        if (c < rows[r].length && rows[r][c].length > maxLen) {
          maxLen = rows[r][c].length;
        }
        if (r < cellImages.length &&
            c < cellImages[r].length &&
            cellImages[r][c].isNotEmpty) {
          hasImage = true;
        }
      }
      weights[c] = hasImage ? maxLen + 80 : maxLen.clamp(8, 120);
    }
    final total = weights.fold<int>(0, (a, b) => a + b);
    return weights.map((w) => (w * 5000 / total).round()).toList();
  }

  (int, int) _fitImageEmu(
    Uint8List bytes, {
    int maxWidthEmu = 5486400,
    int maxHeightEmu = 4200000,
  }) {
    final px = _imagePixelSize(bytes);
    if (px == null) return (maxWidthEmu, (maxWidthEmu * 3 / 4).round());

    var wEmu = _pxToEmu(px.$1);
    var hEmu = _pxToEmu(px.$2);
    if (wEmu > maxWidthEmu) {
      hEmu = (hEmu * maxWidthEmu / wEmu).round();
      wEmu = maxWidthEmu;
    }
    if (hEmu > maxHeightEmu) {
      wEmu = (wEmu * maxHeightEmu / hEmu).round();
      hEmu = maxHeightEmu;
    }
    return (wEmu.clamp(200000, maxWidthEmu), hEmu.clamp(150000, maxHeightEmu));
  }

  int _pxToEmu(int px) => (px * 914400 / 96).round();

  (int, int)? _imagePixelSize(Uint8List bytes) {
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      final w = (bytes[16] << 24) |
          (bytes[17] << 16) |
          (bytes[18] << 8) |
          bytes[19];
      final h = (bytes[20] << 24) |
          (bytes[21] << 16) |
          (bytes[22] << 8) |
          bytes[23];
      if (w > 0 && h > 0) return (w, h);
    }
    if (bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      for (var i = 2; i < bytes.length - 8; i++) {
        if (bytes[i] == 0xFF &&
            (bytes[i + 1] == 0xC0 ||
                bytes[i + 1] == 0xC2 ||
                bytes[i + 1] == 0xC1)) {
          final h = (bytes[i + 5] << 8) | bytes[i + 6];
          final w = (bytes[i + 7] << 8) | bytes[i + 8];
          if (w > 0 && h > 0) return (w, h);
        }
      }
    }
    return null;
  }

  String _contentTypesXml(List<_DocxEmbeddedImage> images) {
    final overrides = StringBuffer('''
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>''');

    for (final img in images) {
      overrides.writeln(
        '  <Override PartName="/word/${img.partName}" ContentType="${img.contentType}"/>',
      );
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Default Extension="gif" ContentType="image/gif"/>
  <Default Extension="emf" ContentType="image/x-emf"/>
  <Default Extension="wmf" ContentType="image/x-wmf"/>
$overrides
</Types>''';
  }

  String _rootRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
  }

  String _documentRelsXml(List<_DocxEmbeddedImage> images) {
    final buffer = StringBuffer('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
''');
    for (final img in images) {
      buffer.writeln(
        '  <Relationship Id="rId${img.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="${img.partName}"/>',
      );
    }
    buffer.writeln('</Relationships>');
    return buffer.toString();
  }

  String _escapeXml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  bool _usesNumberedInText(JournalFormatRules rules) =>
      rules.usesNumberedInText;

  String _resolveBodyText({
    required String text,
    required PublishManuscript manuscript,
    required PublishCitationStyle style,
    required JournalFormatRules rules,
  }) {
    return ManuscriptCitationHelper.resolvePlainText(
      text: text,
      manuscript: manuscript,
      style: style,
      applyNumberedInText: _usesNumberedInText(rules),
    );
  }

  String _safeFileName(String title, String journal) {
    final base = title.trim().isNotEmpty ? title.trim() : 'manuscript';
    final journalPart = journal
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();
    final safe =
        base.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
    return '${safe}_${journalPart}_formatted.docx';
  }
}
