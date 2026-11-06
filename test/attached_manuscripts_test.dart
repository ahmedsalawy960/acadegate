import 'dart:convert';
import 'dart:io';

import 'package:acadegate/features/acadegate_publish/academic_text.dart';
import 'package:acadegate/features/acadegate_publish/docx_scientific_extractor.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Real Word files. Paths are the copies actually present in this workspace.
const _papers = <(String, String)>[
  ('اختبار/_attached_probe/flaxseed.docx', 'اخر تعديل/flaxseed[4796].docx'),
  (
    'اختبار/_attached_probe/soybean_2_4794.docx',
    'تعديل اخير/soybean 2[4794].docx',
  ),
  (
    'اختبار/_attached_probe/adsorption.docx',
    'adsorption of heavy metal[4795].docx',
  ),
  ('اختبار/_attached_probe/rapeseed.docx', 'تعديل اخير2/rapeseed.docx'),
  ('اختبار/_attached_probe/iraqi_bahth.docx', 'iraqi/البحث.docx'),
  (
    'اختبار/_attached_probe/ethiopia_clean.docx',
    'اثيوبيا/Clean Manuscript.docx',
  ),
  ('اختبار/_attached_probe/journal_tables.docx', 'Journal/Tables.docx'),
  ('اختبار/_attached_probe/journal_figures.docx', 'Journal/Figures.docx'),
  (
    'اختبار/_attached_probe/beni_suef_manuscript.docx',
    'بني سويف/manuscript.docx',
  ),
  (
    'اختبار/_attached_probe/college_main.docx',
    'مجلة الكلية/Main Manuscript file.docx',
  ),
  ('اختبار/_attached_probe/journal_title_page.docx', 'Journal/Title page.docx'),
  (
    'اختبار/_attached_probe/soy_hulls_applications.docx',
    'Applications using Soy Hulls Determination of some Heavy Metals in water samples.docx',
  ),
  ('اختبار/soybean 2.docx', 'اختبار/soybean 2.docx'),
  ('اختبار/الرساله3.docx', 'اختبار/الرساله3.docx'),
];

void main() {
  for (final paper in _papers) {
    test(
      paper.$2,
      () async {
        final file = File(paper.$1);
        expect(file.existsSync(), isTrue, reason: paper.$1);
        final bytes = file.readAsBytesSync();
        final source = ZipDecoder().decodeBytes(bytes);
        final document = source.findFile('word/document.xml');
        expect(document, isNotNull, reason: paper.$2);
        final sourceDoc = XmlDocument.parse(utf8.decode(document!.readBytes()!));
        final sourceTables = _count(sourceDoc, 'tbl');
        final sourceMath = _count(sourceDoc, 'oMath');
        final sourceBlips = _count(sourceDoc, 'blip') + _count(sourceDoc, 'imagedata');
        final anchors = _anchors(sourceDoc);

        final parsed = await ManuscriptDocumentParser.parseFile(
          bytes: bytes,
          filename: paper.$2,
        );
        final counts = <String, int>{};
        var cellImages = 0;
        for (final block in parsed.bodyBlocks) {
          counts[block.type.name] = (counts[block.type.name] ?? 0) + 1;
          for (final row in block.rowCellImages) {
            for (final cell in row) {
              if (cell.isNotEmpty) cellImages++;
            }
          }
        }
        final everywhere = _everywhere(parsed);
        final kept = anchors.where(everywhere.contains).toList();
        final missing = anchors.where((anchor) => !everywhere.contains(anchor)).toList();

        final exported = await ManuscriptDocxExportService.instance.buildDocx(
          manuscript: PublishManuscript(
            userId: 'u',
            title: 'Review',
            bodyBlocks: parsed.bodyBlocks,
            references: parsed.references,
          ),
          rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
        );
        final out = ZipDecoder().decodeBytes(exported);
        final outFile = out.findFile('word/document.xml');
        expect(outFile, isNotNull);
        final xmlBytes = outFile!.readBytes()!;
        expect(outFile.size, xmlBytes.length, reason: paper.$2);
        final xml = utf8.decode(xmlBytes);
        XmlDocument.parse(xml);

        // ignore: avoid_print
        print(
          'RESULT ${paper.$2} | blocks=$counts refs=${parsed.references.length} '
          'cellImages=$cellImages | sourceTables=$sourceTables '
          'sourceMath=$sourceMath sourcePictures=$sourceBlips | '
          'anchors=${kept.length}/${anchors.length}',
        );
        if (missing.isNotEmpty) {
          // ignore: avoid_print
          print('MISSING ${paper.$2} | ${missing.join(' || ')}');
        }

        expect(everywhere.trim().isNotEmpty || counts['table'] != null || counts['image'] != null, isTrue);
        if (sourceTables > 0) {
          expect(counts['table'] ?? 0, greaterThan(0), reason: paper.$2);
        }
        if (sourceBlips > 0) {
          expect((counts['image'] ?? 0) + cellImages, greaterThan(0), reason: paper.$2);
        }
        if (sourceMath > 0) {
          expect(counts['equation'] ?? 0, greaterThan(0), reason: paper.$2);
        }
        expect(kept.length, anchors.length, reason: '${paper.$2}: ${missing.join(' || ')}');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}

int _count(XmlDocument doc, String localName) {
  var n = 0;
  for (final node in doc.descendants.whereType<XmlElement>()) {
    if (node.localName == localName) n++;
  }
  return n;
}

String _everywhere(ManuscriptParseResult parsed) {
  final body = parsed.bodyBlocks.map((block) {
    final rows = block.rows.map((row) => row.join(' ')).join('\n');
    return '${block.text}\n${block.caption ?? ''}\n$rows';
  }).join('\n');
  final refs = parsed.references.map((ref) => ref.rawText).join('\n');
  return '$body\n$refs';
}

List<String> _anchors(XmlDocument doc) {
  final paragraphs = <String>[];
  for (final node in doc.descendants.whereType<XmlElement>()) {
    if (node.localName != 'p') continue;
    final buffer = StringBuffer();
    for (final child in node.descendants.whereType<XmlElement>()) {
      if (child.localName == 't') buffer.write(child.innerText);
    }
    final text = AcademicText.sanitize(
      DocxScientificExtractor.formatChemicalFormula(
        buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim(),
      ),
    );
    if (text.length < 28 || text.length > 160) continue;
    if (text.contains('[') || text.contains(']')) continue;
    if (RegExp(r'[A-Za-z]\d').hasMatch(text)) continue;
    paragraphs.add(text);
  }
  if (paragraphs.isEmpty) return const [];
  if (paragraphs.length == 1) return paragraphs;
  if (paragraphs.length == 2) return paragraphs;
  return [
    paragraphs.first,
    paragraphs[paragraphs.length ~/ 2],
    paragraphs.last,
  ];
}
