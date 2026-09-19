import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/locale/app_translate.dart';
import 'citation_formatter.dart';
import 'citation_style_converter.dart';
import 'journal_format_rules.dart';
import 'manuscript_citation_helper.dart';
import 'manuscript_document_parser.dart';
import 'manuscript_upload_service.dart';
import 'publish_models.dart';

class ManuscriptExportService {
  ManuscriptExportService._();

  static final ManuscriptExportService instance = ManuscriptExportService._();

  Future<void> sharePdf(PublishManuscript manuscript) async {
    final bytes = await buildPdfBytes(manuscript);
    final name = _safeFileName(manuscript.title, 'pdf');
    await _shareBytes(bytes, name, 'application/pdf');
  }

  Future<void> shareWordHtml(PublishManuscript manuscript) async {
    final html = buildHtmlDocument(manuscript);
    final bytes = utf8.encode(html);
    final name = _safeFileName(manuscript.title, 'html');
    await _shareBytes(bytes, name, 'text/html');
  }

  Future<Uint8List> buildPdfBytes(PublishManuscript manuscript) async {
    manuscript = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: manuscript.effectiveStyle,
    );
    manuscript = manuscript.copyWith(
      bodyBlocks: ManuscriptDocumentParser.hydratePersistedImageUris(
        manuscript.bodyBlocks,
      ),
    );
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();
    final style = manuscript.effectiveStyle;
    final blockWidgets = await _pdfBlocks(manuscript, style, font);
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Text(
            manuscript.title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (manuscript.abstractText.trim().isNotEmpty &&
              !_bodyHasAbstract(manuscript)) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              appTr('الملخص', 'Abstract'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(manuscript.abstractText),
          ],
          pw.SizedBox(height: 16),
          ...blockWidgets,
          if (ManuscriptCitationHelper.bibliographyReferences(manuscript)
              .isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              appTr('المراجع', 'References'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              CitationFormatter.formatBibliography(
                references: ManuscriptCitationHelper.bibliographyReferences(
                  manuscript,
                ),
                style: style,
              ),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          if (manuscript.attachments.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              appTr('مرفقات', 'Attachments'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...manuscript.attachments.map(
              (a) => pw.Bullet(text: a.name),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  Future<List<pw.Widget>> _pdfBlocks(
    PublishManuscript manuscript,
    PublishCitationStyle style,
    pw.Font font,
  ) async {
    final widgets = <pw.Widget>[];
    for (final block in manuscript.bodyBlocks) {
      switch (block.type) {
        case ManuscriptBlockType.heading:
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
              child: pw.Text(
                ManuscriptCitationHelper.resolvePlainText(
                  text: block.text,
                  manuscript: manuscript,
                  style: style,
                  applyNumberedInText: CitationFormatter.isNumberedStyle(style),
                ),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
        case ManuscriptBlockType.paragraph:
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                ManuscriptCitationHelper.resolvePlainText(
                  text: block.text,
                  manuscript: manuscript,
                  style: style,
                  applyNumberedInText: CitationFormatter.isNumberedStyle(style),
                ),
              ),
            ),
          );
        case ManuscriptBlockType.equation:
          widgets.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                block.text,
                style: pw.TextStyle(font: pw.Font.courier(), fontSize: 11),
              ),
            ),
          );
        case ManuscriptBlockType.image:
          if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
            final img = await _loadPdfImage(block.imageUrl!);
            if (img != null) {
              widgets.add(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Image(img, height: 180, fit: pw.BoxFit.contain),
                    if (block.caption != null && block.caption!.isNotEmpty)
                      pw.Text(
                        block.caption!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              );
            }
          }
        case ManuscriptBlockType.table:
          if (block.rows.isNotEmpty) {
            widgets.add(
              pw.TableHelper.fromTextArray(
                data: block.rows,
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            );
            if (block.caption != null && block.caption!.isNotEmpty) {
              widgets.add(pw.Text(block.caption!, style: const pw.TextStyle(fontSize: 9)));
            }
          }
      }
    }
    return widgets;
  }

  Future<pw.MemoryImage?> _loadPdfImage(String url) async {
    try {
      var source = url.trim();
      if (source.isEmpty) return null;
      if (source.startsWith('{{img:')) {
        // Unhydrated placeholder — nothing to embed.
        return null;
      }
      if (source.startsWith('data:')) {
        final comma = source.indexOf(',');
        if (comma < 0) return null;
        final bytes = base64Decode(source.substring(comma + 1));
        if (bytes.isEmpty) return null;
        return pw.MemoryImage(bytes);
      }
      // Authenticated Storage download — raw http.get often returns 403.
      final bytes =
          await ManuscriptUploadService.instance.downloadBytesFromUrl(source);
      if (bytes != null && bytes.isNotEmpty) {
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}
    return null;
  }

  String buildHtmlDocument(PublishManuscript manuscript) {
    final style = manuscript.effectiveStyle;
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..writeln('<title>${_escapeHtml(manuscript.title)}</title>')
      ..writeln('<style>')
      ..writeln('body{font-family:"Times New Roman",serif;margin:2cm;line-height:1.6}')
      ..writeln('h1{font-size:18pt}h2{font-size:14pt}table{border-collapse:collapse;width:100%}')
      ..writeln('td,th{border:1px solid #333;padding:6px} .eq{font-family:monospace;background:#f5f5f5;padding:8px}')
      ..writeln('</style></head><body>')
      ..writeln('<h1>${_escapeHtml(manuscript.title)}</h1>');

    if (manuscript.abstractText.trim().isNotEmpty &&
        !_bodyHasAbstract(manuscript)) {
      buffer
        ..writeln('<h2>${appTr('الملخص', 'Abstract')}</h2>')
        ..writeln('<p>${_escapeHtml(manuscript.abstractText)}</p>');
    }

    for (final block in manuscript.bodyBlocks) {
      buffer.write(_htmlBlock(block, manuscript, style));
    }

    final bibRefs = ManuscriptCitationHelper.bibliographyReferences(
      manuscript,
    );
    if (bibRefs.isNotEmpty) {
      buffer
        ..writeln('<h2>${appTr('المراجع', 'References')}</h2><ol>')
        ..writeln(
          _escapeHtml(
            CitationFormatter.formatBibliography(
              references: bibRefs,
              style: style,
            ),
          ).replaceAll('\n', '</li><li>'),
        )
        ..writeln('</ol>');
    }

    if (manuscript.attachments.isNotEmpty) {
      buffer.writeln('<h2>${appTr('مرفقات', 'Attachments')}</h2><ul>');
      for (final a in manuscript.attachments) {
        buffer.writeln(
          '<li><a href="${_escapeHtml(a.url)}">${_escapeHtml(a.name)}</a></li>',
        );
      }
      buffer.writeln('</ul>');
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  String _htmlBlock(
    ManuscriptBlock block,
    PublishManuscript manuscript,
    PublishCitationStyle style,
  ) {
    final resolved = _escapeHtml(
      ManuscriptCitationHelper.resolvePlainText(
        text: block.text,
        manuscript: manuscript,
        style: style,
        applyNumberedInText: CitationFormatter.isNumberedStyle(style),
      ),
    );
    return switch (block.type) {
      ManuscriptBlockType.heading => '<h2>$resolved</h2>',
      ManuscriptBlockType.paragraph => '<p>$resolved</p>',
      ManuscriptBlockType.equation => '<div class="eq">${_escapeHtml(block.text)}</div>',
      ManuscriptBlockType.image =>
        '<figure><img src="${_escapeHtml(block.imageUrl ?? '')}" style="max-width:100%"/>'
        '${block.caption != null ? '<figcaption>${_escapeHtml(block.caption!)}</figcaption>' : ''}'
        '</figure>',
      ManuscriptBlockType.table => _htmlTable(block),
    };
  }

  String _htmlTable(ManuscriptBlock block) {
    if (block.rows.isEmpty) return '';
    final rows = ManuscriptBlock.normalizedRows(block.rows);
    final cellImages = ManuscriptBlock.normalizedCellImages(
      block.rowCellImages,
      rows,
    );
    final colSpans = ManuscriptBlock.normalizedIntGrid(block.colSpans, rows);
    final rowSpans = ManuscriptBlock.normalizedIntGrid(block.rowSpans, rows);
    final b = StringBuffer('<table>');
    for (var r = 0; r < rows.length; r++) {
      b.write('<tr>');
      for (var c = 0; c < rows[r].length; c++) {
        final colSpan =
            r < colSpans.length && c < colSpans[r].length ? colSpans[r][c] : 1;
        if (colSpan == 0) continue;
        final rowSpan =
            r < rowSpans.length && c < rowSpans[r].length ? rowSpans[r][c] : 1;
        if (rowSpan == 0) continue;
        final tag = r == 0 ? 'th' : 'td';
        final spanAttrs =
            '${colSpan > 1 ? ' colspan="$colSpan"' : ''}${rowSpan > 1 ? ' rowspan="$rowSpan"' : ''}';
        final img = r < cellImages.length && c < cellImages[r].length
            ? cellImages[r][c]
            : '';
        final inner = img.isNotEmpty
            ? '<img src="${_escapeHtml(img)}" style="max-width:100%;height:auto"/>'
                '${rows[r][c].trim().isEmpty ? '' : '<br>${_escapeHtml(rows[r][c])}'}'
            : _escapeHtml(rows[r][c]);
        b.write('<$tag$spanAttrs>$inner</$tag>');
      }
      b.write('</tr>');
    }
    b.write('</table>');
    if (block.caption != null && block.caption!.isNotEmpty) {
      b.write('<p><em>${_escapeHtml(block.caption!)}</em></p>');
    }
    return b.toString();
  }

  bool _bodyHasAbstract(PublishManuscript manuscript) {
    return manuscript.bodyBlocks.any(
      (b) =>
          b.type == ManuscriptBlockType.heading &&
          JournalSectionLayout.isAbstractHeading(b.text),
    );
  }

  String _escapeHtml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _safeFileName(String title, String ext) {
    final base = title.trim().isEmpty ? 'manuscript' : title.trim();
    final safe = base.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
    return '$safe.$ext';
  }

  Future<void> _shareBytes(List<int> bytes, String name, String mime) async {
    if (kIsWeb) {
      throw Exception(appTr(
        'التصدير متاح على Desktop/Mobile',
        'Export available on desktop/mobile',
      ));
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mime)], subject: name),
    );
  }
}
