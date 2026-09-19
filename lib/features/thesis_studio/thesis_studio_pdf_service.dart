import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/locale/app_translate.dart';
import '../acadegate_publish/citation_formatter.dart';
import '../profile/academic_profile.dart';
import '../ai_advisor/grounded_work.dart';
import 'thesis_studio_branding.dart';
import 'thesis_studio_citations.dart';
import 'thesis_studio_models.dart';

class ThesisStudioPdfService {
  ThesisStudioPdfService._();

  static final ThesisStudioPdfService instance = ThesisStudioPdfService._();

  /// Keep each [pw.Text] shorter than one page (~785pt). Long chapters
  /// otherwise throw "Widget won't fit into the page".
  static const _maxCharsPerBlock = 1600;

  Future<Uint8List> buildBytes(
    ThesisDraft draft, {
    AcademicProfile? profile,
  }) async {
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();
    final rtl = draft.arabic;
    final arabic = rtl;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          margin: const pw.EdgeInsets.all(28),
        ),
        header: (_) => pw.Text(
          appTr(
            'أكاديجيت — استوديو الرسالة (مسودة مراجعة)',
            'AcadeGate — Thesis Studio (draft for review)',
          ),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.indigo900),
        ),
        footer: (ctx) => pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
        ),
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              ThesisStudioBranding.title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              draft.proposedTitle.isNotEmpty
                  ? draft.proposedTitle
                  : draft.goal.raw,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${draft.goal.degreeLabel} · ${draft.goal.institutionLabel}'
              '${draft.goal.fieldEn.isNotEmpty ? ' · ${draft.goal.fieldEn}' : ''}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            if (profile != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                [
                  if (profile.fullName.trim().isNotEmpty) profile.fullName,
                  if (profile.university.trim().isNotEmpty) profile.university,
                  if (profile.specialization.trim().isNotEmpty)
                    profile.specialization,
                ].join(' · '),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                border: pw.Border.all(color: PdfColors.amber200),
              ),
              child: pw.Text(
                ThesisStudioBranding.integrityBanner,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ];

          void heading(String title) {
            widgets.add(pw.SizedBox(height: 14));
            widgets.add(
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900,
                ),
              ),
            );
            widgets.add(pw.Divider(color: PdfColors.indigo200));
          }

          void para(String text, {double fontSize = 10}) {
            widgets.addAll(_flowingText(text, fontSize: fontSize));
          }

          heading(appTr('نوع الرسالة والهيكل', 'Thesis type and structure'));
          para('${draft.plan.kindLabel} · ${draft.plan.shapeLabel}');
          para(
            '${CitationFormatter.styleLabel(draft.plan.citationStyle)} · '
            '${draft.arabic ? appTr('مسودة عربية', 'Arabic draft') : appTr('مسودة إنجليزية', 'English draft')}',
          );

          heading(appTr('الملخص', 'Abstract'));
          para(ThesisStudioCitations.styledProse(draft.abstractText, draft));

          if (draft.researchQuestions.isNotEmpty) {
            heading(appTr('أسئلة البحث', 'Research questions'));
            for (final q in draft.researchQuestions) {
              para('• $q');
            }
          }

          heading(appTr('جدول المحتويات', 'Table of contents'));
          for (final ch in draft.chapters) {
            para(ch.title(arabic));
          }

          for (final ch in draft.chapters) {
            heading(ch.title(arabic));
            para(ThesisStudioCitations.styledProse(ch.body, draft));
          }

          heading(appTr('خريطة الأدبيات', 'Literature map'));
          if (draft.literatureMap.isEmpty) {
            para(
              appTr(
                'لا توجد دراسات DOI مؤكدة في هذه المسودة. لم تُختلق مصادر.',
                'No DOI-confirmed studies are in this draft. No sources were invented.',
              ),
            );
          } else {
            for (final row in draft.literatureMap) {
              para(
                '[${row.index}] ${row.work.authors} (${row.work.year ?? 'n.d.'}) ${row.work.title} — https://doi.org/${row.work.doi}',
              );
            }
          }

          heading(
            appTr(
              'المراجع (${CitationFormatter.styleLabel(draft.plan.citationStyle)})',
              'References (${CitationFormatter.styleLabel(draft.plan.citationStyle)})',
            ),
          );
          if (draft.literature.works.isEmpty) {
            para(
              appTr(
                'لا توجد دراسات DOI مؤكدة في هذه المسودة. لم تُختلق مصادر.',
                'No DOI-confirmed studies are in this draft. No sources were invented.',
              ),
            );
          } else {
            para(
              ThesisStudioCitations.bibliography(
                draft.literature.works,
                style: draft.plan.citationStyle,
              ),
              fontSize: 9,
            );
          }

          if (draft.note != null && draft.note!.trim().isNotEmpty) {
            heading(appTr('ملاحظة', 'Note'));
            para(draft.note!);
          }

          return widgets;
        },
      ),
    );
    return doc.save();
  }

  Future<void> printDraft(
    ThesisDraft draft, {
    AcademicProfile? profile,
  }) async {
    final bytes = await buildBytes(draft, profile: profile);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _fileName(draft),
    );
  }

  Future<void> shareDraft(
    ThesisDraft draft, {
    AcademicProfile? profile,
  }) async {
    final bytes = await buildBytes(draft, profile: profile);
    await Printing.sharePdf(bytes: bytes, filename: _fileName(draft));
  }

  Future<void> shareExcerpt({
    required ThesisDraft draft,
    required String heading,
    required String body,
    List<GroundedWork> works = const [],
  }) async {
    final bytes = await buildExcerptBytes(
      draft: draft,
      heading: heading,
      body: body,
      works: works,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: _excerptFileName(heading, 'pdf'),
    );
  }

  Future<Uint8List> buildExcerptBytes({
    required ThesisDraft draft,
    required String heading,
    required String body,
    List<GroundedWork> works = const [],
  }) async {
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();
    final rtl = draft.arabic;
    final doc = pw.Document();
    final prose = ThesisStudioCitations.styledProse(
      body,
      draft,
      works: works.isNotEmpty ? works : null,
    );
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          margin: const pw.EdgeInsets.all(28),
        ),
        header: (_) => pw.Text(
          appTr(
            'أكاديجيت — استوديو الرسالة (فقرة للمراجعة)',
            'AcadeGate — Thesis Studio (paragraph for review)',
          ),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.indigo900),
        ),
        footer: (ctx) => pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
        ),
        build: (_) {
          final widgets = <pw.Widget>[
            pw.Text(
              heading,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            ..._flowingText(prose, fontSize: 10),
          ];
          if (works.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 16));
            widgets.add(
              pw.Text(
                appTr('المراجع', 'References'),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            widgets.addAll(
              _flowingText(
                ThesisStudioCitations.bibliography(
                  works,
                  style: draft.plan.citationStyle,
                ),
                fontSize: 9,
              ),
            );
          }
          return widgets;
        },
      ),
    );
    return doc.save();
  }

  /// Split prose into page-safe [pw.Text] blocks for [pw.MultiPage].
  static List<pw.Widget> _flowingText(
    String text, {
    double fontSize = 10,
  }) {
    final chunks = _chunkText(text);
    if (chunks.isEmpty) return const [];
    return [
      for (final chunk in chunks)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(
            chunk,
            style: pw.TextStyle(fontSize: fontSize),
          ),
        ),
    ];
  }

  static List<String> _chunkText(String raw) {
    final text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return const [];
    if (text.length <= _maxCharsPerBlock) return [text];

    final out = <String>[];
    // Prefer paragraph breaks, then newlines, then sentences / spaces.
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final buffer = StringBuffer();

    void flush() {
      final s = buffer.toString().trim();
      if (s.isNotEmpty) out.add(s);
      buffer.clear();
    }

    void appendPiece(String piece) {
      final p = piece.trim();
      if (p.isEmpty) return;
      if (p.length > _maxCharsPerBlock) {
        flush();
        out.addAll(_hardSplit(p, _maxCharsPerBlock));
        return;
      }
      if (buffer.length + p.length + 2 > _maxCharsPerBlock) {
        flush();
      }
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(p);
    }

    for (final para in paragraphs) {
      final lines = para.split('\n');
      for (final line in lines) {
        appendPiece(line);
      }
      // Keep a blank-line break between original paragraphs when flushing.
      if (buffer.length > _maxCharsPerBlock ~/ 2) flush();
    }
    flush();
    return out;
  }

  static List<String> _hardSplit(String text, int maxChars) {
    final out = <String>[];
    var remaining = text.trim();
    while (remaining.length > maxChars) {
      var cut = remaining.lastIndexOf(RegExp(r'[\s\.\,\;\:\!\?]'), maxChars);
      if (cut < maxChars ~/ 3) cut = maxChars;
      out.add(remaining.substring(0, cut).trim());
      remaining = remaining.substring(cut).trim();
    }
    if (remaining.isNotEmpty) out.add(remaining);
    return out;
  }

  String _excerptFileName(String heading, String ext) {
    final base = heading.trim().isNotEmpty ? heading.trim() : 'paragraph';
    final safe =
        base.replaceAll(RegExp(r'[^\w\u0600-\u06FF\s-]'), '').replaceAll(' ', '_');
    return '${safe.isEmpty ? 'paragraph' : (safe.length > 40 ? safe.substring(0, 40) : safe)}.$ext';
  }

  String _fileName(ThesisDraft draft) {
    final base = draft.proposedTitle.trim().isNotEmpty
        ? draft.proposedTitle.trim()
        : (draft.goal.field.trim().isNotEmpty
            ? draft.goal.field.trim()
            : 'AcadeGate_Thesis_Studio');
    final safe =
        base.replaceAll(RegExp(r'[^\w\u0600-\u06FF\s-]'), '').replaceAll(' ', '_');
    return '${safe.length > 40 ? safe.substring(0, 40) : safe}.pdf';
  }
}
