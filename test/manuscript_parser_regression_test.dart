import 'dart:convert';
import 'dart:typed_data';

import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_upload_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1×1 PNG. Present only when a test embeds a picture, so unused media is not
/// injected into documents that have no drawing.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _imageRels = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId8" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
</Relationships>
''';

const _drawing = '''
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
''';

const _sampleTable = '''
<w:tbl>
  <w:tr>
    <w:tc><w:p><w:r><w:t>Nutrient</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>Value</w:t></w:r></w:p></w:tc>
  </w:tr>
  <w:tr>
    <w:tc><w:p><w:r><w:t>Protein</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>22</w:t></w:r></w:p></w:tc>
  </w:tr>
</w:tbl>
''';

const _referenceLine =
    '[1] M. Aider and C. Barbana, Canola proteins, Food Chem., vol. 22, pp. 21-39, 2011.';

void main() {
  test('docx paragraphs keep document order', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_orderBody),
      filename: 'order.docx',
    );
    final text = _visibleText(parsed);
    expect(
      text.indexOf('Thermal Adsorption Kinetics'),
      greaterThanOrEqualTo(0),
    );
    expect(
      text.indexOf('Thermal Adsorption Kinetics'),
      lessThan(text.indexOf('Author One')),
    );
    expect(text.indexOf('Author One'), lessThan(text.indexOf('Abstract')));
    expect(
      text.indexOf('Abstract'),
      lessThan(text.indexOf('Capacity decreased')),
    );
  });

  test('docx title-page authors stay out of the reference list', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_authorBody),
      filename: 'authors.docx',
    );
    final body = _visibleText(parsed);
    expect(body, contains('Khaled Elgendy'));
    expect(body, contains('Chemistry Department'));
    expect(parsed.references.any((r) => r.rawText.contains('Khaled')), isFalse);
    expect(
      parsed.references.any((r) => r.rawText.contains('Chemistry Department')),
      isFalse,
    );
    expect(parsed.references.any((r) => r.rawText.contains('Aider')), isTrue);
  });

  test('docx keeps the printed Background heading', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_backgroundBody),
      filename: 'background.docx',
    );
    final headings = parsed.bodyBlocks
        .where((b) => b.type == ManuscriptBlockType.heading)
        .map((b) => b.text.trim())
        .toList();
    expect(headings, contains('Background'));
    expect(headings, contains('Effect of pH'));
    expect(headings, isNot(contains('Introduction')));
  });

  test('docx floats stay where the file put them', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_floatBody, embedImage: true),
      filename: 'floats.docx',
    );
    final blocks = parsed.bodyBlocks;
    final imageAt = blocks.indexWhere(
      (b) => b.type == ManuscriptBlockType.image,
    );
    final titleAt = blocks.indexWhere(
      (b) => b.text.contains('Thermal Adsorption Kinetics'),
    );
    final conclusionAt = blocks.indexWhere(
      (b) =>
          b.type == ManuscriptBlockType.heading &&
          b.text.trim() == 'Conclusion',
    );
    final tableAt = blocks.indexWhere(
      (b) => b.type == ManuscriptBlockType.table,
    );
    expect(imageAt, greaterThanOrEqualTo(0));
    expect(titleAt, greaterThan(imageAt));
    expect(conclusionAt, greaterThan(titleAt));
    expect(tableAt, greaterThan(conclusionAt));
  });

  test('docx captions stay attached beside their media', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_captionBody, embedImage: true),
      filename: 'captions.docx',
    );
    final blocks = parsed.bodyBlocks;
    final imageAt = blocks.indexWhere(
      (b) => b.type == ManuscriptBlockType.image,
    );
    final tableAt = blocks.indexWhere(
      (b) => b.type == ManuscriptBlockType.table,
    );
    final resultsAt = blocks.indexWhere(
      (b) =>
          b.type == ManuscriptBlockType.heading && b.text.trim() == 'Results',
    );
    expect(imageAt, greaterThanOrEqualTo(0));
    expect(tableAt, greaterThan(imageAt));
    expect(resultsAt, greaterThan(tableAt));
    expect(blocks[tableAt].caption ?? '', contains('Table 1'));
    final besideFigure = [
      blocks[imageAt].caption ?? '',
      if (imageAt > 0) blocks[imageAt - 1].text,
      if (imageAt + 1 < blocks.length) blocks[imageAt + 1].text,
    ].join('\n');
    expect(besideFigure, contains('Figure 1'));
    final afterResults = blocks.skip(resultsAt + 1).map(_blockLabel).join('\n');
    expect(afterResults, isNot(contains('Figure 1')));
    expect(afterResults, isNot(contains('Table 1')));
  });

  test(
    'docx Table 1 and Table 10 keep captions and surrounding order',
    () async {
      final parsed = await ManuscriptDocumentParser.parseFile(
        bytes: _docx(_numberedTablesBody),
        filename: 'tables.docx',
      );
      final blocks = parsed.bodyBlocks;
      final beforeAt = blocks.indexWhere(
        (b) => b.text.contains('Samples were dried'),
      );
      final betweenAt = blocks.indexWhere(
        (b) => b.text.contains('Ash remained below'),
      );
      final afterAt = blocks.indexWhere(
        (b) => b.text.contains('does not replace the first'),
      );
      final tables = blocks
          .where((b) => b.type == ManuscriptBlockType.table)
          .toList();
      expect(tables, hasLength(2));
      expect(tables[0].caption ?? '', contains('Table 1'));
      expect(tables[1].caption ?? '', contains('Table 10'));
      expect(tables[0].caption ?? '', isNot(contains('Table 10')));
      final table1At = blocks.indexWhere(
        (b) => b.type == ManuscriptBlockType.table,
      );
      final table10At = blocks.lastIndexWhere(
        (b) => b.type == ManuscriptBlockType.table,
      );
      expect(beforeAt, greaterThanOrEqualTo(0));
      expect(beforeAt, lessThan(table1At));
      expect(betweenAt, greaterThan(table1At));
      expect(betweenAt, lessThan(table10At));
      expect(afterAt, greaterThan(table10At));
    },
  );

  test('docx Figure 1 stays the caption of its image', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_figureBody, embedImage: true),
      filename: 'figure.docx',
    );
    final image = parsed.bodyBlocks.firstWhere(
      (b) => b.type == ManuscriptBlockType.image,
    );
    expect(image.caption ?? '', contains('Figure 1'));
    expect(
      parsed.bodyBlocks.where(
        (b) =>
            b.type == ManuscriptBlockType.heading &&
            b.text.contains('Figure 1'),
      ),
      isEmpty,
    );
  });

  test('docx multiline table caption stays one caption', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_multilineCaptionBody),
      filename: 'multiline.docx',
    );
    final table = parsed.bodyBlocks.firstWhere(
      (b) => b.type == ManuscriptBlockType.table,
    );
    expect(table.caption ?? '', contains('Table 1'));
    expect(table.caption ?? '', contains('rapeseed meal samples'));
    final resultsAt = parsed.bodyBlocks.indexWhere(
      (b) =>
          b.type == ManuscriptBlockType.heading && b.text.trim() == 'Results',
    );
    final afterAt = parsed.bodyBlocks.indexWhere(
      (b) => b.text.contains('Capacity decreased'),
    );
    final tableAt = parsed.bodyBlocks.indexOf(table);
    expect(resultsAt, greaterThan(tableAt));
    expect(afterAt, greaterThan(resultsAt));
  });

  test('docx body sentence mentioning Table 1 stays body text', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_bodyMentionBody),
      filename: 'mention.docx',
    );
    final sentence = parsed.bodyBlocks.firstWhere(
      (b) => b.text.contains('The Table 1 values'),
    );
    expect(sentence.type, ManuscriptBlockType.paragraph);
    final table = parsed.bodyBlocks.firstWhere(
      (b) => b.type == ManuscriptBlockType.table,
    );
    expect(table.caption ?? '', contains('Table 1. Proximate composition'));
    expect(table.caption ?? '', isNot(contains('The Table 1 values')));
    expect(
      parsed.bodyBlocks.indexOf(sentence),
      lessThan(parsed.bodyBlocks.indexOf(table)),
    );
  });

  test(
    'docx Background Results and Discussion stay section headings',
    () async {
      final parsed = await ManuscriptDocumentParser.parseFile(
        bytes: _docx(_sectionHeadingsBody),
        filename: 'sections.docx',
      );
      final headings = parsed.bodyBlocks
          .where((b) => b.type == ManuscriptBlockType.heading)
          .map((b) => b.text.trim())
          .toList();
      expect(headings, contains('Background'));
      expect(headings, contains('Results'));
      expect(headings, contains('Discussion'));
    },
  );

  test('docx OMML subscript becomes an equation block', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _docx(_ommlBody),
      filename: 'omml.docx',
    );
    final equation = parsed.bodyBlocks.where(
      (b) => b.type == ManuscriptBlockType.equation,
    );
    expect(equation, isNotEmpty);
    final block = equation.first;
    expect(block.text, contains('Cₑ'));
    expect(block.ommlXml ?? '', contains('oMath'));
  });

  test('successful docx parseFile ignores allowCloud', () async {
    final bytes = _docx(_orderBody);
    final local = await ManuscriptDocumentParser.parseFile(
      bytes: bytes,
      filename: 'order.docx',
      allowCloud: false,
    );
    final cloudFlag = await ManuscriptDocumentParser.parseFile(
      bytes: bytes,
      filename: 'order.docx',
      allowCloud: true,
    );
    expect(_signature(cloudFlag), _signature(local));
  });

  test('parseFromUrl reads cached local bytes', () async {
    final bytes = _docx(_orderBody);
    const manuscriptId = 'regression-parser-local-cache';
    const filename = 'regression-order.docx';
    ManuscriptFileBytesCache.store(manuscriptId, filename, bytes);
    final fromFile = await ManuscriptDocumentParser.parseFile(
      bytes: bytes,
      filename: filename,
      allowCloud: false,
    );
    final fromUrl = await ManuscriptDocumentParser.parseFromUrl(
      url: 'https://invalid.local/not-a-bucket/regression-order.docx',
      filename: filename,
      manuscriptId: manuscriptId,
    );
    expect(_signature(fromUrl), _signature(fromFile));
  });
}

const _orderBody = '''
<w:p><w:r><w:t>Thermal Adsorption Kinetics of a Prepared Material</w:t></w:r></w:p>
<w:p><w:r><w:t>Author One, Author Two</w:t></w:r></w:p>
<w:p><w:r><w:t>Abstract</w:t></w:r></w:p>
<w:p><w:r><w:t>This work reports adsorption of metal ions onto a treated biomass surface.</w:t></w:r></w:p>
<w:p><w:r><w:t>Results</w:t></w:r></w:p>
<w:p><w:r><w:t>Capacity decreased as treatment temperature increased during the trials.</w:t></w:r></w:p>
''';

const _authorBody =
    '''
<w:p><w:r><w:t>Rapeseed protein composition in edible oil</w:t></w:r></w:p>
<w:p><w:r><w:t>Khaled Elgendy, Mounir Zaky, and Ahmed Salawy Mohammed</w:t></w:r></w:p>
<w:p><w:r><w:t>Chemistry Department, Faculty of Science, Zagazig University, Egypt</w:t></w:r></w:p>
<w:p><w:r><w:t>Abstract</w:t></w:r></w:p>
<w:p><w:r><w:t>Oilseed summary of rapeseed composition for the regression fixture.</w:t></w:r></w:p>
<w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
<w:p><w:r><w:t>The crop produces oil in the studied samples.</w:t></w:r></w:p>
<w:p><w:r><w:t>References</w:t></w:r></w:p>
<w:p><w:r><w:t>$_referenceLine</w:t></w:r></w:p>
''';

const _backgroundBody = '''
<w:p><w:r><w:t>Background</w:t></w:r></w:p>
<w:p><w:r><w:t>Heavy metals contaminate water sources across the studied region.</w:t></w:r></w:p>
<w:p><w:r><w:t>Effect of pH</w:t></w:r></w:p>
<w:p><w:r><w:t>Surface charge changes with pH during the adsorption experiments.</w:t></w:r></w:p>
<w:p><w:r><w:t>Results</w:t></w:r></w:p>
<w:p><w:r><w:t>Capacity decreased as treatment temperature increased in the trials.</w:t></w:r></w:p>
''';

final String _floatBody =
    '''
$_drawing
<w:p><w:r><w:t>Thermal Adsorption Kinetics of a Prepared Material: A Study on Isotherms</w:t></w:r></w:p>
<w:p><w:r><w:t>Abstract</w:t></w:r></w:p>
<w:p><w:r><w:t>This work reports adsorption of metal ions onto a treated biomass surface.</w:t></w:r></w:p>
<w:p><w:r><w:t>Conclusion</w:t></w:r></w:p>
<w:p><w:r><w:t>The crop is useful for nutrition studies in this sample.</w:t></w:r></w:p>
$_sampleTable
<w:p><w:r><w:t>References</w:t></w:r></w:p>
<w:p><w:r><w:t>$_referenceLine</w:t></w:r></w:p>
''';

final String _captionBody =
    '''
<w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
<w:p><w:r><w:t>The study investigates adsorption of compounds onto the prepared surface using standard methods.</w:t></w:r></w:p>
$_drawing
<w:p><w:r><w:t>Figure 1. FTIR spectrum of the prepared adsorbent.</w:t></w:r></w:p>
<w:p><w:r><w:t>Table 1. Proximate composition of rapeseed</w:t></w:r></w:p>
$_sampleTable
<w:p><w:r><w:t>Results</w:t></w:r></w:p>
<w:p><w:r><w:t>Capacity decreased as treatment temperature increased during the trials.</w:t></w:r></w:p>
''';

const _numberedTablesBody =
    '''
<w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
<w:p><w:r><w:t>Samples were dried before the proximate measurements.</w:t></w:r></w:p>
<w:p><w:r><w:t>Table 1. Proximate composition of rapeseed</w:t></w:r></w:p>
$_sampleTable
<w:p><w:r><w:t>Ash remained below the reporting limit in this batch.</w:t></w:r></w:p>
<w:p><w:r><w:t>Table 10. Trace elements in the sample</w:t></w:r></w:p>
<w:tbl>
  <w:tr>
    <w:tc><w:p><w:r><w:t>Element</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>Iron</w:t></w:r></w:p></w:tc>
  </w:tr>
</w:tbl>
<w:p><w:r><w:t>The later table does not replace the first composition table.</w:t></w:r></w:p>
''';

final String _figureBody =
    '''
<w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
<w:p><w:r><w:t>The study investigates adsorption of compounds onto the prepared surface using standard methods.</w:t></w:r></w:p>
$_drawing
<w:p><w:r><w:t>Figure 1. FTIR spectrum of the prepared adsorbent.</w:t></w:r></w:p>
<w:p><w:r><w:t>Results</w:t></w:r></w:p>
<w:p><w:r><w:t>Capacity decreased as treatment temperature increased during the trials.</w:t></w:r></w:p>
''';

const _multilineCaptionBody =
    '''
<w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
<w:p><w:r><w:t>The study investigates adsorption of compounds onto the prepared surface using standard methods.</w:t></w:r></w:p>
<w:p>
  <w:r><w:t>Table 1. Proximate composition</w:t></w:r>
  <w:r><w:br/></w:r>
  <w:r><w:t>of rapeseed meal samples</w:t></w:r>
</w:p>
$_sampleTable
<w:p><w:r><w:t>Results</w:t></w:r></w:p>
<w:p><w:r><w:t>Capacity decreased as treatment temperature increased during the trials.</w:t></w:r></w:p>
''';

const _bodyMentionBody =
    '''
<w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
<w:p><w:r><w:t>The Table 1 values are shown below for the prepared samples.</w:t></w:r></w:p>
<w:p><w:r><w:t>Table 1. Proximate composition of rapeseed</w:t></w:r></w:p>
$_sampleTable
<w:p><w:r><w:t>Results</w:t></w:r></w:p>
<w:p><w:r><w:t>Capacity decreased as treatment temperature increased during the trials.</w:t></w:r></w:p>
''';

const _sectionHeadingsBody = '''
<w:p><w:r><w:t>Background</w:t></w:r></w:p>
<w:p><w:r><w:t>Heavy metals contaminate water sources across the studied region.</w:t></w:r></w:p>
<w:p><w:r><w:t>Results</w:t></w:r></w:p>
<w:p><w:r><w:t>Capacity decreased as treatment temperature increased in the trials.</w:t></w:r></w:p>
<w:p><w:r><w:t>Discussion</w:t></w:r></w:p>
<w:p><w:r><w:t>The pattern agrees with the adsorption measurements in this study.</w:t></w:r></w:p>
''';

const _ommlBody = '''
<w:p><w:r><w:t>Introduction</w:t></w:r></w:p>
<w:p><w:r><w:t>The equilibrium concentration is defined by the following expression for the sample.</w:t></w:r></w:p>
<w:p>
  <m:oMath>
    <m:sSub>
      <m:e><m:r><m:t>C</m:t></m:r></m:e>
      <m:sub><m:r><m:t>e</m:t></m:r></m:sub>
    </m:sSub>
  </m:oMath>
</w:p>
''';

String _visibleText(ManuscriptParseResult parsed) =>
    parsed.bodyBlocks.map(_blockLabel).join('\n');

String _blockLabel(ManuscriptBlock block) {
  final caption = block.caption ?? '';
  if (caption.isEmpty) return block.text;
  return '${block.text}\n$caption';
}

String _signature(ManuscriptParseResult parsed) {
  final blocks = parsed.bodyBlocks
      .map(
        (b) =>
            '${b.type.name}|${b.text.trim()}|${b.caption ?? ''}|${b.rows.map((r) => r.join(',')).join(';')}',
      )
      .join('\n');
  final refs = parsed.references.map((r) => r.rawText.trim()).join('\n');
  return '$blocks\n---\n$refs';
}

Uint8List _docx(String body, {bool embedImage = false}) {
  final documentXml =
      '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">
  <w:body>
    $body
  </w:body>
</w:document>
''';
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'word/document.xml',
        documentXml.length,
        utf8.encode(documentXml),
      ),
    );
  if (embedImage) {
    archive
      ..addFile(ArchiveFile('word/media/image1.png', _png.length, _png))
      ..addFile(
        ArchiveFile(
          'word/_rels/document.xml.rels',
          _imageRels.length,
          utf8.encode(_imageRels),
        ),
      );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
