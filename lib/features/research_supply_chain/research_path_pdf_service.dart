import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_service.dart';
import '../academic/academic_models.dart';
import '../lab_import/nbsle_university_cities.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../profile/academic_profile.dart';
import 'research_supply_chain_models.dart';

class ResearchPathPdfService {
  ResearchPathPdfService._();

  static final ResearchPathPdfService instance = ResearchPathPdfService._();

  Future<Uint8List> buildBytes(
    ResearchSupplyBundle bundle, {
    AcademicProfile? profile,
  }) async {
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();
    final rtl = !LocaleService.instance.isEnglish;
    final city = profile?.city.trim() ?? '';
    final localLabs = bundle.labs
        .where(
          (m) =>
              NbsleUniversityCities.isSameCity(m.item.city, city) ||
              NbsleUniversityCities.isSameCity(m.item.location, city),
        )
        .toList();
    final otherLabs = bundle.labs
        .where(
          (m) =>
              !NbsleUniversityCities.isSameCity(m.item.city, city) &&
              !NbsleUniversityCities.isSameCity(m.item.location, city),
        )
        .toList();
    final localProducts = bundle.products
        .where((p) => NbsleUniversityCities.isSameCity(p.city, city))
        .toList();
    final otherProducts = bundle.products
        .where((p) => !NbsleUniversityCities.isSameCity(p.city, city))
        .toList();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          margin: const pw.EdgeInsets.all(28),
        ),
        header: (_) => pw.Text(
          appTr('أكاديجيت — مسار البحث الذكي', 'AcadeGate — Smart Research Path'),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.teal800),
        ),
        footer: (ctx) => pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
        ),
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              appTr('مسار البحث الذكي', 'Smart Research Path'),
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              bundle.topic,
              style: const pw.TextStyle(fontSize: 13),
            ),
            if (profile != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                [
                  if (profile.fullName.trim().isNotEmpty) profile.fullName,
                  if (profile.university.trim().isNotEmpty) profile.university,
                  if (city.isNotEmpty) city,
                ].join(' · '),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
            if (bundle.goal != null) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                '${bundle.goal!.degreeLabel} · ${bundle.goal!.institutionLabel}'
                '${bundle.goal!.fieldEn.isNotEmpty ? ' · ${bundle.goal!.fieldEn}' : ''}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ];

          void heading(String title) {
            widgets.add(pw.SizedBox(height: 14));
            widgets.add(
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
                ),
              ),
            );
            widgets.add(pw.Divider(color: PdfColors.teal200));
          }

          void line(String text) {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
              ),
            );
          }

          if (bundle.chainSummary.isNotEmpty) {
            heading(appTr('ملخص الحزمة', 'Bundle summary'));
            for (final row in bundle.chainSummary) {
              line(row);
            }
          }

          if (bundle.degreePlan.isNotEmpty) {
            heading(appTr('الخطة الفصلية', 'Semester plan'));
            for (final stage in bundle.degreePlan) {
              line('${stage.period} — ${stage.title}');
              for (final o in stage.outcomes) {
                line('  • $o');
              }
              for (final a in stage.platformActions) {
                line('  → $a');
              }
            }
          }

          final insight = bundle.aiInsight;
          if (insight != null &&
              (insight.analysis.trim().isNotEmpty ||
                  insight.researchPlan.trim().isNotEmpty)) {
            heading(appTr('تحليل الذكاء الاصطناعي', 'AI analysis'));
            if (insight.analysis.trim().isNotEmpty) {
              line(insight.analysis);
            }
            if (insight.researchPlan.trim().isNotEmpty) {
              widgets.add(pw.SizedBox(height: 6));
              line(insight.researchPlan);
            }
            if (insight.nextStep != null && insight.nextStep!.trim().isNotEmpty) {
              line('${appTr('الخطوة التالية', 'Next step')}: ${insight.nextStep}');
            }
          }

          if (bundle.ideas.isNotEmpty) {
            heading(appTr('أفكار بحثية', 'Research ideas'));
            for (final m in bundle.ideas) {
              line('${m.item.title} (${m.score}%)');
            }
          }

          if (bundle.supervisors.isNotEmpty) {
            heading(appTr('مشرفون', 'Supervisors'));
            for (final m in bundle.supervisors) {
              line(
                '${m.item.name} — ${m.item.speciality} · ${m.item.university} (${m.score}%)',
              );
            }
          }

          heading(appTr('مختبرات', 'Labs'));
          if (city.isNotEmpty && localLabs.isNotEmpty) {
            line(appTr('في مدينتك ($city)', 'In your city ($city)'));
            for (final m in localLabs) {
              line(_labLine(m));
            }
          }
          if (otherLabs.isNotEmpty) {
            line(appTr('مدن أخرى', 'Other cities'));
            for (final m in otherLabs) {
              line(_labLine(m));
            }
          }
          if (bundle.labs.isEmpty) {
            line(appTr('لا مختبر مطابق لنقطة البحث', 'No lab matches the research point'));
          }

          heading(appTr('متجر — مواد وأدوات', 'Store — supplies'));
          if (city.isNotEmpty && localProducts.isNotEmpty) {
            line(appTr('في مدينتك ($city)', 'In your city ($city)'));
            for (final p in localProducts) {
              line(_productLine(p));
            }
          }
          if (otherProducts.isNotEmpty) {
            line(appTr('مدن أخرى', 'Other cities'));
            for (final p in otherProducts) {
              line(_productLine(p));
            }
          }
          if (bundle.products.isEmpty) {
            line(appTr('لا مادة مطابقة لنقطة البحث', 'No store item matches the research point'));
          }

          if (bundle.literature.isNotEmpty) {
            heading(appTr('دراسات مؤكدة', 'Confirmed studies'));
            for (var i = 0; i < bundle.literature.length; i++) {
              final w = bundle.literature[i];
              final doi = w.doi.trim();
              line(
                '${i + 1}. ${w.title}${w.year != null ? ' (${w.year})' : ''}'
                '${doi.isNotEmpty ? ' — $doi' : ''}',
              );
            }
          }

          if (bundle.institutionalNotes.isNotEmpty) {
            heading(appTr('الأثر المؤسسي', 'Institutional impact'));
            for (final n in bundle.institutionalNotes) {
              line('• $n');
            }
          }

          return widgets;
        },
      ),
    );
    return doc.save();
  }

  String _labLine(MatchResult<AcademicLab> match) {
    final lab = match.item;
    final city = lab.city.isNotEmpty ? lab.city : lab.location;
    final equip = lab.equipment.trim();
    final hint = lab.equipmentNameHints.take(3).join(', ');
    final tools = equip.isNotEmpty ? equip : hint;
    return '${lab.name} — $city · ${lab.university}'
        '${tools.isNotEmpty ? ' · $tools' : ''} (${match.score}%)';
  }

  String _productLine(SupplyChainProduct p) {
    final city = p.city.toString().trim();
    return '${p.name} — ${p.price} ${appTr('ج.م', 'EGP')}'
        ' · ${p.category}'
        '${city.isNotEmpty ? ' · $city' : ''} (${p.score}%)';
  }

  Future<void> printBundle(
    ResearchSupplyBundle bundle, {
    AcademicProfile? profile,
  }) async {
    final bytes = await buildBytes(bundle, profile: profile);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _fileName(bundle),
    );
  }

  Future<void> shareBundle(
    ResearchSupplyBundle bundle, {
    AcademicProfile? profile,
  }) async {
    final bytes = await buildBytes(bundle, profile: profile);
    await Printing.sharePdf(bytes: bytes, filename: _fileName(bundle));
  }

  String _fileName(ResearchSupplyBundle bundle) {
    final base = bundle.topic.trim().isEmpty
        ? 'AcadeGate_Research_Path'
        : bundle.topic.trim();
    final safe = base.replaceAll(RegExp(r'[^\w\u0600-\u06FF\s-]'), '').replaceAll(' ', '_');
    return '${safe.length > 40 ? safe.substring(0, 40) : safe}.pdf';
  }
}
