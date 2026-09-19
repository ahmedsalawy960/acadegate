import 'dart:convert';
import 'dart:typed_data';

import 'package:acadegate/features/acadegate_publish/docx_scientific_extractor.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الملخص stays a heading and is not renamed Abstract', () {
    var i = 0;
    final blocks = DocxScientificExtractor.splitTextBySectionHeadings(
      'Abstract\n'
      'English summary of the work is written here in Latin letters.\n'
      'الملخص\n'
      'هذا ملخص عربي مستقل عن النص الإنجليزي ويجب أن يبقى قسماً منفصلاً.\n'
      'Introduction\n'
      'The study investigates adsorption.',
      () => 'id_${i++}',
    );
    final headings = blocks
        .where((b) => b.type == ManuscriptBlockType.heading)
        .map((b) => b.text)
        .toList();
    expect(headings, contains('Abstract'));
    expect(headings, contains('الملخص'));
    expect(headings.where((h) => h == 'Abstract').length, 1);
  });

  test('Arabic abstract is not merged under English Abstract', () {
    final merged = ManuscriptDocumentParser.mergeSectionParagraphs([
      const ManuscriptBlock(
        id: 'h1',
        type: ManuscriptBlockType.heading,
        text: 'Abstract',
      ),
      const ManuscriptBlock(
        id: 'p1',
        type: ManuscriptBlockType.paragraph,
        text:
            'Proximate analysis of soybean meal was carried out using standard methods.',
      ),
      const ManuscriptBlock(
        id: 'h2',
        type: ManuscriptBlockType.heading,
        text: 'الملخص',
      ),
      const ManuscriptBlock(
        id: 'p2',
        type: ManuscriptBlockType.paragraph,
        text:
            'تم إجراء التحليل التقريبي لكسب فول الصويا باستخدام الطرق القياسية المعتمدة.',
      ),
    ]);
    expect(
      merged.map((b) => b.text),
      containsAll(['Abstract', 'الملخص']),
    );
    expect(
      merged.any(
        (b) =>
            b.type == ManuscriptBlockType.paragraph &&
            b.text.contains('Proximate') &&
            b.text.contains('تم إجراء'),
      ),
      isFalse,
    );
  });

  test('export keeps الملخص and Experimental when dropping English Abstract', () {
    final exported = JournalSectionLayout.prepareExportBlocks(
      blocks: const [
        ManuscriptBlock(
          id: 'h1',
          type: ManuscriptBlockType.heading,
          text: 'Abstract',
        ),
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text: 'English abstract text about proximate composition.',
        ),
        ManuscriptBlock(
          id: 'h2',
          type: ManuscriptBlockType.heading,
          text: 'الملخص',
        ),
        ManuscriptBlock(
          id: 'p2',
          type: ManuscriptBlockType.paragraph,
          text: 'الملخص العربي للنسب التقريبية للبحث.',
        ),
        ManuscriptBlock(
          id: 'h3',
          type: ManuscriptBlockType.heading,
          text: 'Experimental',
        ),
        ManuscriptBlock(
          id: 'p3',
          type: ManuscriptBlockType.paragraph,
          text: 'Samples were dried at 105 C for moisture determination.',
        ),
      ],
      sectionOrder: const ['Introduction', 'Experimental', 'Results'],
      dropAbstractSection: true,
    );
    final texts = exported.map((b) => b.text).toList();
    expect(texts, contains('الملخص'));
    expect(texts, contains('الملخص العربي للنسب التقريبية للبحث.'));
    expect(texts, contains('Experimental'));
    expect(
      texts,
      contains('Samples were dried at 105 C for moisture determination.'),
    );
  });

  test('a citation-like sentence does not delete the rest of Experimental', () {
    final exported = JournalSectionLayout.prepareExportBlocks(
      blocks: const [
        ManuscriptBlock(
          id: 'h1',
          type: ManuscriptBlockType.heading,
          text: 'Experimental',
        ),
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text:
              'Smith, A. (2019). The reagents were purchased from Sigma and used without further purification in all assays.',
        ),
        ManuscriptBlock(
          id: 'p2',
          type: ManuscriptBlockType.paragraph,
          text:
              'Moisture, ash, protein, fat and fiber were determined by AOAC methods.',
        ),
        ManuscriptBlock(
          id: 't1',
          type: ManuscriptBlockType.table,
          rows: [
            ['Compound', 'Structure'],
            ['A', ''],
          ],
          rowCellImages: [
            ['', ''],
            ['', 'data:image/png;base64,AAA'],
          ],
        ),
      ],
      sectionOrder: const ['Experimental', 'Results'],
      dropAbstractSection: true,
    );
    expect(
      exported.any((b) => b.text.contains('Moisture, ash, protein')),
      isTrue,
    );
    expect(
      exported.any((b) => b.type == ManuscriptBlockType.table),
      isTrue,
    );
  });

  test('plain-text import keeps Arabic الملخص and later Experimental', () {
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest('''
Abstract
Proximate composition of the samples was determined according to AOAC.
الملخص
تم تقدير التركيب التقريبي للعينات وفقا للطرق القياسية المعتمدة في هذا البحث العلمي.
Experimental
Moisture content was measured after drying the samples overnight.
Results
Protein content increased after treatment.
References
1. Smith, J. (2015). Article title. Journal, 1, 1-8.
''');
    final headings = parsed.bodyBlocks
        .where((b) => b.type == ManuscriptBlockType.heading)
        .map((b) => b.text.trim())
        .toList();
    expect(headings, contains('Abstract'));
    expect(headings, contains('الملخص'));
    expect(headings, contains('Experimental'));
    expect(
      parsed.bodyBlocks.any((b) => b.text.contains('Moisture content')),
      isTrue,
    );
    expect(
      parsed.bodyBlocks.any(
        (b) => b.text.contains('Proximate') && b.text.contains('تم تقدير'),
      ),
      isFalse,
    );
  });

  test('stripped Firestore placeholders hydrate back for Word export', () {
    const dataUri =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final stripped = ManuscriptDocumentParser.stripDataUrisForPersistence([
      const ManuscriptBlock(
        id: 'fig1',
        type: ManuscriptBlockType.image,
        imageUrl: dataUri,
      ),
    ]);
    expect(stripped.single.imageUrl, startsWith('{{img:'));
    final hydrated =
        ManuscriptDocumentParser.hydratePersistedImageUris(stripped);
    expect(hydrated.single.imageUrl, dataUri);
  });

  test('journal Word export embeds figure and table-cell pictures', () async {
    const dataUri =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final bytes = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: const PublishManuscript(
        userId: 'u',
        title: 'Proximate analysis',
        bodyBlocks: [
          ManuscriptBlock(
            id: 'fig1',
            type: ManuscriptBlockType.image,
            imageUrl: dataUri,
            caption: 'Figure 1. Compound A',
          ),
          ManuscriptBlock(
            id: 'tbl1',
            type: ManuscriptBlockType.table,
            rows: [
              ['Compound', 'Structure'],
              ['A', ''],
            ],
            rowCellImages: [
              ['', ''],
              ['', dataUri],
            ],
          ),
        ],
      ),
      rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.ieee),
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final media = archive.files.where((f) {
      final name = f.name.replaceAll('\\', '/');
      return name.contains('word/media/');
    }).toList();
    expect(media.length, greaterThanOrEqualTo(2));
    final document = utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );
    expect(document, contains('a:blip'));
  });

  test('namespaced a:blip in DOCX becomes an image block', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final bytes = _minimalDocx(
      documentXml: '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
    <w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
    <w:p>
      <w:r>
        <w:drawing>
          <wp:inline>
            <a:graphic>
              <a:graphicData>
                <pic:pic>
                  <pic:blipFill>
                    <a:blip r:embed="rId8"/>
                  </pic:blipFill>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>
    <w:p><w:r><w:t>The study investigates adsorption of compounds onto the prepared surface.</w:t></w:r></w:p>
  </w:body>
</w:document>''',
      png: png,
      relsXml: '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId8" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
</Relationships>''',
    );
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: bytes,
      filename: 'paper.docx',
    );
    expect(
      parsed.bodyBlocks.any((b) => b.type == ManuscriptBlockType.image),
      isTrue,
    );
  });

  test('journal export copies word/media from the original DOCX', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final source = _minimalDocx(
      documentXml: '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
    <w:p><w:r><w:t>The study investigates adsorption of compounds onto the prepared surface.</w:t></w:r></w:p>
  </w:body>
</w:document>''',
      png: png,
    );
    final exported = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: const PublishManuscript(
        userId: 'u',
        title: 'Proximate analysis',
        bodyBlocks: [
          ManuscriptBlock(
            id: 'p1',
            type: ManuscriptBlockType.paragraph,
            text: 'Results of the proximate analysis are reported below.',
          ),
        ],
      ),
      rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.ieee),
      sourceDocxBytes: source,
    );
    expect(
      ManuscriptDocxExportService.countEmbeddedMedia(exported),
      greaterThanOrEqualTo(1),
    );
  });

  test('table Structure cell keeps a namespaced a:blip picture', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final bytes = _minimalDocx(
      documentXml: '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
    <w:p><w:r><w:t>Introduction to the GC-MS analysis of rapeseed oil samples.</w:t></w:r></w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Peak</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Structure</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Heptanal</w:t></w:r></w:p></w:tc>
        <w:tc>
          <w:p>
            <w:r>
              <w:drawing>
                <wp:inline>
                  <a:graphic>
                    <a:graphicData>
                      <pic:pic>
                        <pic:blipFill>
                          <a:blip r:embed="rId8"/>
                        </pic:blipFill>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:inline>
              </w:drawing>
            </w:r>
          </w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
    <w:p><w:r><w:t>Experimental</w:t></w:r></w:p>
    <w:p><w:r><w:t>Moisture was determined by AOAC methods for soybean meal samples.</w:t></w:r></w:p>
  </w:body>
</w:document>''',
      png: png,
      relsXml: '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId8" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
</Relationships>''',
    );
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: bytes,
      filename: 'gcms.docx',
    );
    final tableIdx = parsed.bodyBlocks.indexWhere(
      (b) => b.type == ManuscriptBlockType.table,
    );
    expect(tableIdx, greaterThanOrEqualTo(0));
    final table = parsed.bodyBlocks[tableIdx];
    expect(table.rows.first, contains('Structure'));
    expect(
      table.rowCellImages.any((row) => row.any((u) => u.startsWith('data:'))),
      isTrue,
    );
    expect(
      parsed.bodyBlocks.sublist(tableIdx + 1).where(
            (b) => b.type == ManuscriptBlockType.image,
          ),
      isEmpty,
      reason: 'Structure drawings must stay in the table, not after the body',
    );
    expect(
      parsed.bodyBlocks.any(
        (b) =>
            (b.type == ManuscriptBlockType.paragraph ||
                b.type == ManuscriptBlockType.heading) &&
            b.text.contains('Introduction'),
      ),
      isTrue,
    );
    expect(
      parsed.bodyBlocks.any((b) => b.text.contains('AOAC methods')),
      isTrue,
    );
    expect(
      parsed.bodyBlocks.any(
        (b) =>
            b.type != ManuscriptBlockType.table && b.text.contains('Heptanal'),
      ),
      isFalse,
      reason: 'Table cells must not be flattened into body paragraphs',
    );
  });

  test('unused word/media fills an empty Structure column', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final bytes = _minimalDocx(
      documentXml: '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Introduction to the GC-MS analysis of rapeseed oil samples.</w:t></w:r></w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Peak</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Structure</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Heptanal</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>''',
      png: png,
    );
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: bytes,
      filename: 'gcms.docx',
    );
    final table = parsed.bodyBlocks.firstWhere(
      (b) => b.type == ManuscriptBlockType.table,
    );
    expect(
      table.rowCellImages.any((row) => row.any((u) => u.startsWith('data:'))),
      isTrue,
    );
    expect(
      parsed.bodyBlocks.where((b) => b.type == ManuscriptBlockType.image),
      isEmpty,
      reason: 'Do not dump unused media as figures before References',
    );
  });

  test('table-cell data URIs survive strip then hydrate', () {
    const dataUri =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final stripped = ManuscriptDocumentParser.stripDataUrisForPersistence([
      const ManuscriptBlock(
        id: 'tbl1',
        type: ManuscriptBlockType.table,
        rows: [
          ['Peak', 'Structure'],
          ['1', ''],
        ],
        rowCellImages: [
          ['', ''],
          ['', dataUri],
        ],
      ),
    ]);
    expect(stripped.single.rowCellImages[1][1], startsWith('{{img:'));
    final hydrated =
        ManuscriptDocumentParser.hydratePersistedImageUris(stripped);
    expect(hydrated.single.rowCellImages[1][1], dataUri);
  });

  test('customXml wrappers keep headings and paragraphs, not a media dump', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final bytes = _minimalDocx(
      documentXml: '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:customXml>
      <w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
      <w:p><w:r><w:t>The study investigates adsorption of compounds onto the prepared surface using standard laboratory methods.</w:t></w:r></w:p>
      <w:p><w:r><w:t>Experimental</w:t></w:r></w:p>
      <w:p><w:r><w:t>Moisture, ash, protein, fat and fiber were determined by AOAC methods for all samples.</w:t></w:r></w:p>
    </w:customXml>
  </w:body>
</w:document>''',
      png: png,
    );
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: bytes,
      filename: 'paper.docx',
    );
    expect(
      parsed.bodyBlocks.any(
        (b) =>
            b.type == ManuscriptBlockType.heading && b.text.contains('Introduction'),
      ),
      isTrue,
    );
    expect(
      parsed.bodyBlocks.any((b) => b.text.contains('Moisture, ash, protein')),
      isTrue,
    );
    expect(
      parsed.bodyBlocks.where((b) => b.type == ManuscriptBlockType.image),
      isEmpty,
    );
  });

  test('a sentence mentioning المراجع is not treated as the bibliography heading', () {
    expect(
      ManuscriptDocumentParser.parsePlainTextForTest(
        'Introduction\n'
        'تم ذكر المراجع في المقدمة قبل عرض النتائج التجريبية للبحث الحالي.\n'
        'Experimental\n'
        'Samples were dried at 105 C for moisture determination of soybean meal.\n'
        'References\n'
        '[1] Smith, A. Test journal 2020, 10, 1-8.\n',
      ).bodyBlocks.any((b) => b.text.contains('النتائج التجريبية')),
      isTrue,
    );
  });
}

Uint8List _minimalDocx({
  required String documentXml,
  required List<int> png,
  String? relsXml,
}) {
  final archive = Archive()
    ..addFile(ArchiveFile(
      'word/document.xml',
      documentXml.length,
      utf8.encode(documentXml),
    ))
    ..addFile(ArchiveFile('word/media/image1.png', png.length, png));
  if (relsXml != null) {
    archive.addFile(ArchiveFile(
      'word/_rels/document.xml.rels',
      relsXml.length,
      utf8.encode(relsXml),
    ));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
