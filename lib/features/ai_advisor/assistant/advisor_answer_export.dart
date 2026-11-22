import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/locale/locale_extensions.dart';
import '../advisor_message.dart';

/// Copy or save one assistant reply as Word, PDF, or plain text.
class AdvisorAnswerExport {
  AdvisorAnswerExport._();

  static String plain(String raw) =>
      raw.replaceAll('**', '').replaceAll('```', '').trim();

  static Future<void> copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: plain(text)));
    if (!context.mounted) return;
    _snack(context, context.t('تم النسخ', 'Copied'));
  }

  static Future<void> save(
    BuildContext context,
    AdvisorMessage message, {
    required String format,
  }) async {
    final body = plain(message.content);
    if (body.isEmpty) return;
    final stamp = message.createdAt.toLocal();
    final name = 'AcadeGate_${_stamp(stamp)}.$format';
    final dialogTitle = context.t('حفظ الرد', 'Save reply');
    final savedText = context.t('تم حفظ الملف', 'File saved');
    final failedText = context.t('تعذر حفظ الملف', 'Could not save the file');
    try {
      final Uint8List bytes;
      switch (format) {
        case 'docx':
          bytes = _docx(body, stamp);
        case 'pdf':
          bytes = await _pdf(body, stamp);
        default:
          bytes = Uint8List.fromList(utf8.encode(body));
      }
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: name,
        type: FileType.custom,
        allowedExtensions: [format],
        bytes: bytes,
      );
      if (!context.mounted) return;
      if (saved != null) _snack(context, savedText);
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, failedText);
    }
  }

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  static String _stamp(DateTime t) =>
      '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}_'
      '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}';

  static Future<Uint8List> _pdf(String body, DateTime when) async {
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    final arabic = RegExp('[\u0600-\u06FF]').hasMatch(body);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: bold),
          textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          margin: const pw.EdgeInsets.all(32),
        ),
        header: (_) => pw.Text(
          'AcadeGate  ·  ${_clock(when)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        build: (_) => [
          pw.Text(
            body,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static String _clock(DateTime t) =>
      '${t.day}/${t.month}/${t.year}  ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static Uint8List _docx(String body, DateTime when) {
    final arabic = RegExp('[\u0600-\u06FF]').hasMatch(body);
    final align = arabic ? 'right' : 'left';
    final bidi = arabic ? '<w:bidi/>' : '';
    final rtl = arabic ? '<w:rtl/>' : '';
    String run(String text, {bool bold = false}) =>
        '<w:r><w:rPr>${bold ? '<w:b/>' : ''}$rtl</w:rPr>'
        '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r>';
    String para(String text, {bool bold = false}) =>
        '<w:p><w:pPr><w:jc w:val="$align"/>$bidi</w:pPr>${run(text, bold: bold)}</w:p>';

    final xml = StringBuffer()
      ..write(para('AcadeGate', bold: true))
      ..write(para(_clock(when)));
    for (final line in body.split('\n')) {
      xml.write(para(line.isEmpty ? ' ' : line));
    }

    final document = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>$xml<w:sectPr>
    <w:pgSz w:w="11906" w:h="16838"/>
    <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
  </w:sectPr></w:body>
</w:document>''';
    const types = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    ArchiveFile file(String name, String content) {
      final bytes = utf8.encode(content);
      return ArchiveFile(name, bytes.length, bytes);
    }

    final archive = Archive()
      ..addFile(file('[Content_Types].xml', types))
      ..addFile(file('_rels/.rels', rels))
      ..addFile(file('word/document.xml', document));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _esc(String t) => t
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
