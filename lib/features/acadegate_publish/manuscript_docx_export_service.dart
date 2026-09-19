import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import 'academic_text.dart';
import 'citation_formatter.dart';
import 'citation_linker.dart';
import 'citation_style_converter.dart';
import 'docx_share.dart';
import 'docx_scientific_extractor.dart';
import 'manuscript_image_session_cache.dart';
import 'journal_format_rules.dart';
import 'manuscript_citation_helper.dart';
import 'manuscript_document_parser.dart';
import 'manuscript_upload_service.dart';
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

  /// Builds and shares the formatted DOCX.
  /// Returns `(saved: false)` if the user cancelled the save dialog.
  Future<({bool saved, int imageCount})> shareFormattedDocx({
    required PublishManuscript manuscript,
    required JournalFormatRules rules,
    Uint8List? sourceDocxBytes,
  }) async {
    final bytes = await buildDocx(
      manuscript: manuscript,
      rules: rules,
      sourceDocxBytes: sourceDocxBytes,
    );
    final name = _safeFileName(manuscript.title, rules.journalName);
    final saved = await shareDocxBytes(bytes: bytes, name: name);
    return (saved: saved, imageCount: countEmbeddedMedia(bytes));
  }

  Future<Uint8List> buildDocx({
    required PublishManuscript manuscript,
    required JournalFormatRules rules,
    Uint8List? sourceDocxBytes,
  }) async {
    final embeddedImages = <_DocxEmbeddedImage>[];
    final bodyXml = StringBuffer();
    final style = rules.citationStyle;
    manuscript = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: style,
    );
    manuscript = manuscript.copyWith(
      bodyBlocks: ManuscriptDocumentParser.hydratePersistedImageUris(
        manuscript.bodyBlocks,
      ),
    );
    final cleanTitle = AcademicText.stripTrailingAuthorFromTitle(
      AcademicText.sanitize(manuscript.title.trim()),
    );

    if (cleanTitle.isNotEmpty) {
      final titleText =
          rules.titleUppercase ? cleanTitle.toUpperCase() : cleanTitle;
      bodyXml.write(_paragraph(
        titleText,
        rules: rules,
        bold: true,
        fontHalfPoints: rules.titleFontHalfPoints,
        align: rules.titleAlign == 'left' ? 'left' : 'center',
        spacingAfter: 240,
      ));
    }

    final rawBlocks = manuscript.bodyBlocks.isNotEmpty
        ? manuscript.bodyBlocks
        : PublishManuscript.blocksFromLegacyBody(manuscript.body);
    final bodyHasEnglishAbstract = rawBlocks.any(
      (b) =>
          b.type == ManuscriptBlockType.heading &&
          JournalSectionLayout.isEnglishAbstractHeading(b.text),
    );
    final bodyHasArabicAbstract = rawBlocks.any(
      (b) =>
          b.type == ManuscriptBlockType.heading &&
          JournalSectionLayout.isArabicAbstractHeading(b.text),
    );

    // Body is the source of truth. Never invent a second Abstract that
    // swallows الملخص, and never label English text الملخص.
    if (manuscript.abstractText.trim().isNotEmpty &&
        !bodyHasEnglishAbstract &&
        !bodyHasArabicAbstract) {
      final abs = manuscript.abstractText.trim();
      bodyXml.write(_paragraph(
        _abstractHeadingFor(abs),
        rules: rules,
        bold: true,
        fontHalfPoints: rules.headingFontHalfPoints,
        spacingBefore: 120,
        spacingAfter: 60,
      ));
      bodyXml.write(_paragraph(
        _resolveBodyText(
          text: abs,
          manuscript: manuscript,
          style: style,
          rules: rules,
        ),
        rules: rules,
        spacingAfter: 80,
      ));
      final maxWords = rules.abstractMaxWords;
      if (maxWords != null) {
        final words = abs.split(RegExp(r'\s+')).length;
        if (words > maxWords) {
          bodyXml.write(_paragraph(
            appTr(
              'ملاحظة: الملخص $words كلمة — حد المجلة $maxWords كلمة.',
              'Note: abstract is $words words; journal limit is $maxWords.',
            ),
            rules: rules,
            italic: true,
            fontHalfPoints: rules.bodyFontHalfPoints - 2,
            spacingAfter: 200,
          ));
        }
      }
    }

    if (rules.columnCount > 1) {
      bodyXml.write(_continuousSectionBreak(rules, columns: 1));
    }

    final blocks = JournalSectionLayout.prepareExportBlocks(
      blocks: rawBlocks,
      sectionOrder: const [],
      dropAbstractSection: false,
    );

    var headingNumber = 0;
    var wideSection = false;
    for (final block in blocks) {
      final blockText = AcademicText.sanitize(block.text.trim());
      if (block.type == ManuscriptBlockType.heading &&
          (blockText == cleanTitle ||
              (cleanTitle.length > 20 && blockText.startsWith(cleanTitle)))) {
        continue;
      }
      if (block.type == ManuscriptBlockType.paragraph &&
          cleanTitle.length > 20 &&
          blockText.startsWith(cleanTitle)) {
        continue;
      }

      final needsWide = block.type == ManuscriptBlockType.table ||
          block.type == ManuscriptBlockType.image;
      if (rules.columnCount > 1 && needsWide && !wideSection) {
        bodyXml.write(_continuousSectionBreak(rules, columns: 1));
        wideSection = true;
      } else if (rules.columnCount > 1 && !needsWide && wideSection) {
        bodyXml.write(_continuousSectionBreak(rules, columns: 2));
        wideSection = false;
      }

      final exportBlock = block.type == ManuscriptBlockType.heading
          ? block.copyWith(
              text: _formatHeadingText(
                blockText,
                rules: rules,
                number: ++headingNumber,
              ),
            )
          : block;
      if (block.type == ManuscriptBlockType.heading &&
          (JournalSectionLayout.isAbstractHeading(block.text) ||
              JournalSectionLayout.isReferencesHeading(block.text) ||
              JournalSectionLayout.isHeading(block.text, const ['Keywords']))) {
        headingNumber--;
      }
      bodyXml.write(await _blockXml(
        exportBlock,
        manuscript,
        rules,
        style,
        embeddedImages,
      ));
    }

    if (rules.columnCount > 1 && wideSection) {
      bodyXml.write(_continuousSectionBreak(rules, columns: 2));
    }

    if (sourceDocxBytes != null && sourceDocxBytes.isNotEmpty) {
      await _appendUnclaimedSourceMedia(
        sourceDocxBytes: sourceDocxBytes,
        embeddedImages: embeddedImages,
        bodyXml: bodyXml,
        rules: rules,
      );
    }

    final bibRefs = ManuscriptCitationHelper.bibliographyReferences(
      manuscript,
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

    bodyXml.write(_sectionProperties(rules, columns: rules.columnCount));

    final documentXml = _documentXml(bodyXml.toString());
    final stylesXml = _stylesXml(rules);
    final contentTypesXml = _contentTypesXml(embeddedImages, rules);
    final rootRelsXml = _rootRelsXml();
    final documentRelsXml = _documentRelsXml(embeddedImages, rules);

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
    if (rules.runningHeader) {
      final headerXml = _headerXml(
        rules,
        runningTitle: cleanTitle,
      );
      archive.addFile(ArchiveFile(
          'word/header1.xml', headerXml.length, utf8.encode(headerXml)));
    }
    if (rules.pageNumbers) {
      final footerXml = _footerXml(rules);
      archive.addFile(ArchiveFile(
          'word/footer1.xml', footerXml.length, utf8.encode(footerXml)));
    }

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
      ManuscriptBlockType.paragraph => () {
          final front = DocxScientificExtractor.isFrontMatterAuthorText(block.text);
          return _paragraph(
            front
                ? AcademicText.sanitize(CitationLinker.stripHints(block.text))
                : _resolveBodyText(
                    text: block.text,
                    manuscript: manuscript,
                    style: style,
                    rules: rules,
                  ),
            rules: rules,
            align: front ? 'center' : '',
            spacingAfter: 80,
            firstLineIndent: !front,
          );
        }(),
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
      final relId = embeddedImages.length + 10;
      final partName = 'media/export_img_$relId.${payload.ext}';
      embeddedImages.add(_DocxEmbeddedImage(
        relId: relId,
        partName: partName,
        bytes: payload.bytes,
        contentType: payload.mime,
      ));
      final size = (block.imageWidthEmu != null &&
              block.imageHeightEmu != null &&
              block.imageWidthEmu! > 0 &&
              block.imageHeightEmu! > 0)
          ? _fitEmuSize(
              block.imageWidthEmu!,
              block.imageHeightEmu!,
              maxWidthEmu: 5486400,
            )
          : _fitImageEmu(payload.bytes, maxWidthEmu: 5486400);
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
    var url = source?.trim() ?? '';
    if (url.isEmpty) return null;

    final cached = ManuscriptImageSessionCache.instance.resolve(url);
    if (cached != null && cached != url) {
      url = cached;
    }

    if (url.startsWith('{{img:')) {
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
      final bytes =
          await ManuscriptUploadService.instance.downloadBytesFromUrl(url);
      if (bytes != null && bytes.isNotEmpty) {
        final ext = _imageExtension(bytes);
        return (bytes: bytes, ext: ext, mime: _mimeForExt(ext));
      }
    } catch (_) {}
    return null;
  }

  /// Copy rasters still sitting in the original DOCX zip when parse/export
  /// missed them (namespaced blips, unused word/media, session-cache miss).
  Future<void> _appendUnclaimedSourceMedia({
    required Uint8List sourceDocxBytes,
    required List<_DocxEmbeddedImage> embeddedImages,
    required StringBuffer bodyXml,
    required JournalFormatRules rules,
  }) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(sourceDocxBytes);
    } catch (_) {
      return;
    }

    final already = <String>{
      for (final img in embeddedImages) _mediaFingerprint(img.bytes),
    };
    final minBytes = embeddedImages.isEmpty ? 32 : 2500;

    final files = archive.files
        .where((f) => f.isFile)
        .where((f) {
          final name = f.name.replaceAll('\\', '/').toLowerCase();
          return name.startsWith('word/media/') &&
              _isCopyableSourceMedia(name);
        })
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final file in files) {
      var bytes = Uint8List.fromList(file.content as List<int>);
      if (bytes.length < minBytes) continue;
      var ext = file.name.split('.').last.toLowerCase();
      if (ext == 'emz' || ext == 'wmz') {
        try {
          bytes = Uint8List.fromList(GZipDecoder().decodeBytes(bytes));
          ext = ext == 'emz' ? 'emf' : 'wmf';
        } catch (_) {
          continue;
        }
      }
      if (bytes.length < minBytes) continue;
      final fingerprint = _mediaFingerprint(bytes);
      if (!already.add(fingerprint)) continue;

      final relId = embeddedImages.length + 10;
      final partName = 'media/source_img_$relId.$ext';
      embeddedImages.add(_DocxEmbeddedImage(
        relId: relId,
        partName: partName,
        bytes: bytes,
        contentType: _mimeForExt(ext),
      ));
      final size = _fitImageEmu(bytes, maxWidthEmu: 5486400);
      bodyXml.write(_inlineImageParagraph(
        relId: relId,
        rules: rules,
        widthEmu: size.$1,
        heightEmu: size.$2,
      ));
    }
  }

  bool _isCopyableSourceMedia(String path) {
    if (path.contains('/embeddings/') ||
        path.contains('oleobject') ||
        path.endsWith('.bin') ||
        path.endsWith('.cdx') ||
        path.endsWith('.cdxml') ||
        path.endsWith('.mol')) {
      return false;
    }
    return RegExp(
      r'\.(png|jpe?g|gif|bmp|wdp|tiff?|emf|wmf|emz|wmz|webp|svg)$',
    ).hasMatch(path);
  }

  String _mediaFingerprint(Uint8List bytes) {
    final n = bytes.length;
    final head = bytes.take(16).join(',');
    final tail = n > 24 ? bytes.sublist(n - 8).join(',') : '';
    return '$n|$head|$tail';
  }

  static int countEmbeddedMedia(Uint8List docxBytes) {
    try {
      return ZipDecoder()
          .decodeBytes(docxBytes)
          .files
          .where((f) {
            final name = f.name.replaceAll('\\', '/').toLowerCase();
            return f.isFile && name.contains('word/media/');
          })
          .length;
    } catch (_) {
      return 0;
    }
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
    if (bytes.length >= 4 &&
        bytes[0] == 0x01 &&
        bytes[1] == 0x00 &&
        bytes[2] == 0x00 &&
        bytes[3] == 0x00) {
      return 'emf';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0xD7 &&
        bytes[1] == 0xCD &&
        bytes[2] == 0xC6 &&
        bytes[3] == 0x9A) {
      return 'wmf';
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
    final colSpans = ManuscriptBlock.normalizedIntGrid(block.colSpans, rows);
    final rowSpans = ManuscriptBlock.normalizedIntGrid(block.rowSpans, rows);
    final colWidths = block.columnWidthsPct.length == rows.first.length
        ? block.columnWidthsPct
        : _tableColumnWidthsPct(rows, cellImages);
    final buffer = StringBuffer();
    buffer.write('<w:tbl>');
    buffer.write('''
<w:tblPr>
  <w:tblW w:w="5000" w:type="pct"/>
  <w:tblLayout w:type="fixed"/>
  <w:tblBorders>
    <w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
  </w:tblBorders>
</w:tblPr>''');
    buffer.write('<w:tblGrid>');
    for (final w in colWidths) {
      final twips = (w * 9360 / 5000).round().clamp(200, 9000);
      buffer.write('<w:gridCol w:w="$twips"/>');
    }
    buffer.write('</w:tblGrid>');
    for (var r = 0; r < rows.length; r++) {
      buffer.write('<w:tr>');
      for (var c = 0; c < rows[r].length; c++) {
        final colSpan = r < colSpans.length && c < colSpans[r].length
            ? colSpans[r][c]
            : 1;
        if (colSpan == 0) continue;

        final rowSpan = r < rowSpans.length && c < rowSpans[r].length
            ? rowSpans[r][c]
            : 1;
        var colW = c < colWidths.length ? colWidths[c] : 500;
        if (colSpan > 1) {
          var spanW = 0;
          for (var i = 0; i < colSpan && c + i < colWidths.length; i++) {
            spanW += colWidths[c + i];
          }
          if (spanW > 0) colW = spanW;
        }

        final mergeXml = rowSpan == 0
            ? '<w:vMerge/>'
            : (rowSpan > 1 ? '<w:vMerge w:val="restart"/>' : '');
        final spanXml =
            colSpan > 1 ? '<w:gridSpan w:val="$colSpan"/>' : '';

        buffer.write('''
<w:tc>
  <w:tcPr>
    <w:tcW w:w="$colW" w:type="pct"/>
    $spanXml
    $mergeXml
    <w:vAlign w:val="center"/>
  </w:tcPr>''');
        final imgUrl = r < cellImages.length && c < cellImages[r].length
            ? cellImages[r][c]
            : '';
        var wroteParagraph = false;
        if (imgUrl.isNotEmpty && rowSpan != 0) {
          final payload = await _loadImagePayload(imgUrl);
          if (payload != null) {
            final relId = embeddedImages.length + 10;
            final partName = 'media/export_img_$relId.${payload.ext}';
            embeddedImages.add(_DocxEmbeddedImage(
              relId: relId,
              partName: partName,
              bytes: payload.bytes,
              contentType: payload.mime,
            ));
            final size = _fitImageEmu(
              payload.bytes,
              maxWidthEmu: (5486400 * colW / 5000).round().clamp(800000, 4800000),
              maxHeightEmu: 3200000,
            );
            buffer.write(_inlineImageParagraph(
              relId: relId,
              rules: rules,
              heightEmu: size.$2,
              widthEmu: size.$1,
            ));
            wroteParagraph = true;
          }
        }
        final cellText = AcademicText.sanitize(rows[r][c].trim());
        final formula = RegExp(r'[A-Z][a-z]?\d').hasMatch(cellText)
            ? DocxScientificExtractor.formatChemicalFormula(cellText)
            : cellText;
        if (formula.isNotEmpty && rowSpan != 0) {
          buffer.write(_paragraph(
            formula,
            rules: rules,
            bold: r == 0,
            spacingAfter: 0,
            inTable: true,
          ));
          wroteParagraph = true;
        }
        if (!wroteParagraph) {
          buffer.write('<w:p/>');
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
        final relId = embeddedImages.length + 10;
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
    final hanging = CitationFormatter.isNumberedStyle(rules.citationStyle)
        ? 360
        : 720;
    return '''
<w:p>
  <w:pPr>
    <w:spacing w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}" w:after="60"/>
    <w:ind w:left="$hanging" w:hanging="$hanging"/>
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
    bool firstLineIndent = false,
  }) {
    if (text.trim().isEmpty) return '';
    final alignXml = align.isNotEmpty ? '<w:jc w:val="$align"/>' : '';
    final justify = rules.justifyBody && align.isEmpty && !inTable
        ? '<w:jc w:val="both"/>'
        : alignXml;
    final spacing = inTable
        ? '<w:spacing w:before="40" w:after="40" w:line="240" w:lineRule="auto"/>'
        : (spacingBefore > 0 || spacingAfter > 0)
            ? '<w:spacing w:before="$spacingBefore" w:after="$spacingAfter" w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}"/>'
            : '<w:spacing w:line="${rules.lineSpacingExactTwips}" w:lineRule="${rules.lineSpacingRule}"/>';
    final indent = firstLineIndent && rules.firstLineIndentTwips > 0
        ? '<w:ind w:firstLine="${rules.firstLineIndentTwips}"/>'
        : '';

    return '''
<w:p>
  <w:pPr>
    $spacing
    $justify
    $indent
  </w:pPr>
  ${_citationRuns(
    text,
    rules: rules,
    bold: bold,
    italic: italic,
    fontHalfPoints: fontHalfPoints ?? rules.bodyFontHalfPoints,
    fontFamily: fontFamily,
  )}
</w:p>''';
  }

  String _citationRuns(
    String text, {
    required JournalFormatRules rules,
    bool bold = false,
    bool italic = false,
    int? fontHalfPoints,
    String? fontFamily,
  }) {
    if (bold || italic) {
      return _run(
        text,
        rules: rules,
        bold: bold,
        italic: italic,
        fontHalfPoints: fontHalfPoints,
        fontFamily: fontFamily,
      );
    }
    final matches = RegExp(r'\[\d{1,3}(?:,\d{1,3})*\]').allMatches(text).toList();
    if (matches.isEmpty) {
      return _run(
        text,
        rules: rules,
        fontHalfPoints: fontHalfPoints,
        fontFamily: fontFamily,
      );
    }
    final buffer = StringBuffer();
    var i = 0;
    for (final m in matches) {
      if (m.start > i) {
        buffer.write(
          _run(
            text.substring(i, m.start),
            rules: rules,
            fontHalfPoints: fontHalfPoints,
            fontFamily: fontFamily,
          ),
        );
      }
      buffer.write(
        _run(
          m.group(0)!,
          rules: rules,
          bold: true,
          fontHalfPoints: fontHalfPoints,
          fontFamily: fontFamily,
        ),
      );
      i = m.end;
    }
    if (i < text.length) {
      buffer.write(
        _run(
          text.substring(i),
          rules: rules,
          fontHalfPoints: fontHalfPoints,
          fontFamily: fontFamily,
        ),
      );
    }
    return buffer.toString();
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
    final escaped = _escapeXml(AcademicText.sanitize(text));
    final preserve = text.startsWith(' ') || text.endsWith(' ')
        ? ' xml:space="preserve"'
        : '';
    return '''
<w:r>
  <w:rPr>
    <w:rFonts w:ascii="$font" w:hAnsi="$font" w:eastAsia="$font" w:cs="$font"/>
    <w:sz w:val="$size"/>
    <w:szCs w:val="$size"/>
    <w:lang w:val="en-US" w:eastAsia="en-US" w:bidi="en-US"/>
    $boldXml
    $italicXml
  </w:rPr>
  <w:t$preserve>$escaped</w:t>
</w:r>''';
  }

  String _abstractHeadingFor(String text) {
    final arabic = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
    final latin = RegExp(r'[A-Za-z]').allMatches(text).length;
    return arabic > latin ? 'الملخص' : 'Abstract';
  }

  String _formatHeadingText(
    String raw, {
    required JournalFormatRules rules,
    required int number,
  }) {
    var text = AcademicText.westernDigits(raw.trim());
    final isMajor = JournalSectionLayout.isHeading(text, const [
          'Abstract',
          'Introduction',
          'Experimental',
          'Methods',
          'Results',
          'Discussion',
          'Conclusion',
          'References',
          'Keywords',
          'الملخص',
        ]) ||
        JournalSectionLayout.isArabicAbstractHeading(text) ||
        JournalSectionLayout.isHeading(text, const ['الكلمات المفتاحية']);
    if (!isMajor) return text;
    if (JournalSectionLayout.isAbstractHeading(text) ||
        JournalSectionLayout.isReferencesHeading(text) ||
        JournalSectionLayout.isHeading(text, const ['Keywords'])) {
      return rules.headingUppercase ? text.toUpperCase() : text;
    }
    if (rules.headingUppercase) text = text.toUpperCase();
    if (rules.headingNumbered && !RegExp(r'^\d+[.)]').hasMatch(text)) {
      text = '$number. $text';
    }
    return text;
  }

  String _paperSizeXml(JournalFormatRules rules) {
    if (rules.paperSize == 'letter') {
      return '<w:pgSz w:w="12240" w:h="15840"/>';
    }
    return '<w:pgSz w:w="11906" w:h="16838"/>';
  }

  String _pageMarXml(JournalFormatRules rules) =>
      '<w:pgMar w:top="${rules.marginTwips}" w:right="${rules.marginTwips}" w:bottom="${rules.marginTwips}" w:left="${rules.marginTwips}" w:header="720" w:footer="720" w:gutter="0"/>';

  String _headerFooterRefs(JournalFormatRules rules) {
    final parts = <String>[];
    if (rules.runningHeader) {
      parts.add('<w:headerReference w:type="default" r:id="rId2"/>');
    }
    if (rules.pageNumbers) {
      parts.add('<w:footerReference w:type="default" r:id="rId3"/>');
    }
    return parts.join();
  }

  String _continuousSectionBreak(JournalFormatRules rules, {required int columns}) {
    return '''
<w:p>
  <w:pPr>
    <w:sectPr>
      ${_headerFooterRefs(rules)}
      ${_paperSizeXml(rules)}
      ${_pageMarXml(rules)}
      <w:cols w:num="$columns" w:space="720"/>
      <w:type w:val="continuous"/>
    </w:sectPr>
  </w:pPr>
</w:p>''';
  }

  String _sectionProperties(JournalFormatRules rules, {int columns = 1}) {
    return '''
<w:sectPr>
  ${_headerFooterRefs(rules)}
  ${_paperSizeXml(rules)}
  ${_pageMarXml(rules)}
  <w:cols w:num="$columns" w:space="720"/>
</w:sectPr>''';
  }

  String _headerXml(JournalFormatRules rules, {String runningTitle = ''}) {
    var label = runningTitle.trim().isNotEmpty
        ? runningTitle.trim()
        : (rules.journalName.trim().isNotEmpty
            ? rules.journalName.trim()
            : 'Manuscript');
    final maxChars = rules.runningTitleMaxChars;
    if (maxChars != null && maxChars > 0 && label.length > maxChars) {
      label = label.substring(0, maxChars).trimRight();
    }
    if (rules.titleUppercase) label = label.toUpperCase();
    final name = _escapeXml(label);
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr>
      <w:jc w:val="center"/>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:rFonts w:ascii="${rules.fontFamily}" w:hAnsi="${rules.fontFamily}"/>
        <w:sz w:val="${rules.bodyFontHalfPoints - 4}"/>
        <w:i/>
      </w:rPr>
      <w:t>$name</w:t>
    </w:r>
  </w:p>
</w:hdr>''';
  }

  String _footerXml(JournalFormatRules rules) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr>
      <w:jc w:val="center"/>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:rFonts w:ascii="${rules.fontFamily}" w:hAnsi="${rules.fontFamily}"/>
        <w:sz w:val="${rules.bodyFontHalfPoints - 4}"/>
      </w:rPr>
      <w:fldChar w:fldCharType="begin"/>
    </w:r>
    <w:r>
      <w:instrText xml:space="preserve"> PAGE </w:instrText>
    </w:r>
    <w:r>
      <w:fldChar w:fldCharType="end"/>
    </w:r>
  </w:p>
</w:ftr>''';
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

  (int, int) _fitEmuSize(
    int widthEmu,
    int heightEmu, {
    int maxWidthEmu = 5486400,
    int maxHeightEmu = 4200000,
  }) {
    var wEmu = widthEmu;
    var hEmu = heightEmu;
    if (wEmu <= 0 || hEmu <= 0) {
      return (maxWidthEmu, (maxWidthEmu * 3 / 4).round());
    }
    if (wEmu > maxWidthEmu) {
      hEmu = (hEmu * maxWidthEmu / wEmu).round();
      wEmu = maxWidthEmu;
    }
    if (hEmu > maxHeightEmu) {
      wEmu = (wEmu * maxHeightEmu / hEmu).round();
      hEmu = maxHeightEmu;
    }
    return (
      wEmu.clamp(200000, maxWidthEmu),
      hEmu.clamp(150000, maxHeightEmu),
    );
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

  String _contentTypesXml(
    List<_DocxEmbeddedImage> images,
    JournalFormatRules rules,
  ) {
    final overrides = StringBuffer('''
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>''');
    if (rules.runningHeader) {
      overrides.writeln(
        '  <Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>',
      );
    }
    if (rules.pageNumbers) {
      overrides.writeln(
        '  <Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>',
      );
    }

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

  String _documentRelsXml(
    List<_DocxEmbeddedImage> images,
    JournalFormatRules rules,
  ) {
    final buffer = StringBuffer('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
''');
    if (rules.runningHeader) {
      buffer.writeln(
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>',
      );
    }
    if (rules.pageNumbers) {
      buffer.writeln(
        '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>',
      );
    }
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
    return AcademicText.sanitize(
      ManuscriptCitationHelper.resolvePlainText(
        text: text,
        manuscript: manuscript,
        style: style,
        applyNumberedInText: _usesNumberedInText(rules),
      ),
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
