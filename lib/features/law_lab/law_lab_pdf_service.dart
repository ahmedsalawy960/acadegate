import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_service.dart';
import 'law_lab_models.dart';

class LawLabPdfService {
  LawLabPdfService._();
  static final LawLabPdfService instance = LawLabPdfService._();

  Future<Uint8List> buildBytes(LawProject project) async {
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();
    final rtl = !LocaleService.instance.isEnglish;

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
            'أكاديجيت — مختبر القانون (ملف الأسانيد)',
            'AcadeGate — Law Lab (authorities file)',
          ),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue900),
        ),
        footer: (ctx) => pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
        ),
        build: (_) {
          final w = <pw.Widget>[
            pw.Text(
              appTr('ملف الأسانيد القانونية', 'Legal authorities dossier'),
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (project.researchQuestion.trim().isNotEmpty)
              pw.Text(
                '${appTr('سؤال البحث', 'Research question')}: ${project.researchQuestion}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            if (project.fieldAr.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                '${appTr('الحقل', 'Field')}: ${project.fieldAr}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
            pw.SizedBox(height: 4),
            pw.Text(
              appTr(
                '${project.issues.length} فرع · ${project.authorities.length} سند · '
                '${project.briefs.length} حكم · ${project.links.length} رابط · '
                '${project.comparisons.length} مقارنة',
                '${project.issues.length} issues · ${project.authorities.length} authorities · '
                '${project.briefs.length} briefs · ${project.links.length} links · '
                '${project.comparisons.length} comparisons',
              ),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ];

          void heading(String title) {
            w.add(pw.SizedBox(height: 14));
            w.add(
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            );
            w.add(pw.Divider(color: PdfColors.blue200));
          }

          void line(String text) {
            w.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
              ),
            );
          }

          if (project.issues.isNotEmpty) {
            heading(appTr('خريطة المسألة', 'Issue map'));
            for (var i = 0; i < project.issues.length; i++) {
              final iss = project.issues[i];
              line('${i + 1}. ${iss.title}');
              if (iss.notes.trim().isNotEmpty) line('   ${iss.notes}');
            }
          }

          if (project.authorities.isNotEmpty) {
            heading(appTr('سجل الأسانيد', 'Authorities ledger'));
            for (var i = 0; i < project.authorities.length; i++) {
              final a = project.authorities[i];
              line(
                '${i + 1}. [${a.kindAr}] ${a.title}'
                '${a.citation.isEmpty ? '' : ' — ${a.citation}'}'
                '${a.year.isEmpty ? '' : ' (${a.year})'}'
                ' · ${a.statusAr}',
              );
              if (a.keyProvision.trim().isNotEmpty) {
                line('   ${a.keyProvision}');
              }
              if (a.notes.trim().isNotEmpty) line('   ${a.notes}');
            }
          }

          if (project.briefs.isNotEmpty) {
            heading(appTr('بطاقات الأحكام', 'Case briefs'));
            for (var i = 0; i < project.briefs.length; i++) {
              final b = project.briefs[i];
              line(
                '${i + 1}. ${b.court} ${b.caseRef}'
                '${b.year.isEmpty ? '' : ' (${b.year})'}',
              );
              if (b.issue.isNotEmpty) {
                line('   ${appTr('المسألة', 'Issue')}: ${b.issue}');
              }
              if (b.holding.isNotEmpty) {
                line('   ${appTr('المنطوق', 'Holding')}: ${b.holding}');
              }
              if (b.ratio.isNotEmpty) {
                line('   ${appTr('العلة', 'Ratio')}: ${b.ratio}');
              }
              if (b.relevance.isNotEmpty) {
                line('   ${appTr('الصلة', 'Relevance')}: ${b.relevance}');
              }
            }
          }

          if (project.links.isNotEmpty) {
            heading(appTr('سلسلة الاستدلال', 'Argument chain'));
            for (final link in project.links) {
              final iss = project.issueById(link.issueId)?.title ?? link.issueId;
              final au = project.authorityById(link.authorityId);
              final auLabel = au == null
                  ? link.authorityId
                  : '[${au.kindAr}] ${au.title}';
              line('• $iss ← ${link.roleAr} — $auLabel');
              if (link.note.trim().isNotEmpty) line('   ${link.note}');
            }
          }

          if (project.comparisons.isNotEmpty) {
            heading(appTr('مقارنة تشريعية', 'Comparative matrix'));
            for (var i = 0; i < project.comparisons.length; i++) {
              final c = project.comparisons[i];
              line('${i + 1}. ${c.issueLabel}');
              line('   ${appTr('مصر', 'Egypt')}: ${c.egyptRule}');
              line(
                '   ${c.foreignSystem}: ${c.foreignRule}',
              );
              if (c.note.trim().isNotEmpty) line('   ${c.note}');
            }
          }

          w.add(pw.SizedBox(height: 16));
          w.add(
            pw.Text(
              appTr(
                'تنبيه: تحقّق من سريان النصوص والأسانيد من مصادرها الرسمية قبل الاعتماد في الرسالة.',
                'Note: verify currency of texts and authorities from official sources before relying on them in the thesis.',
              ),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          );

          return w;
        },
      ),
    );
    return doc.save();
  }

  Future<void> share(LawProject project) async {
    final bytes = await buildBytes(project);
    await Printing.sharePdf(bytes: bytes, filename: _fileName(project));
  }

  Future<void> printLayout(LawProject project) async {
    final bytes = await buildBytes(project);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _fileName(project),
    );
  }

  String _fileName(LawProject project) {
    final base = project.researchQuestion.trim().isEmpty
        ? 'AcadeGate_Law_Authorities'
        : project.researchQuestion.trim();
    final safe = base
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final clipped = safe.length > 40 ? safe.substring(0, 40) : safe;
    return '$clipped.pdf';
  }
}
