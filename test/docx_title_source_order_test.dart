import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/docx_title_reader.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

String p(String t, {int size = 0, bool bold = false}) =>
    '<w:p><w:r><w:rPr>${size > 0 ? '<w:sz w:val="$size"/>' : ''}${bold ? '<w:b/>' : ''}</w:rPr><w:t>${XmlText(t).toXmlString()}</w:t></w:r></w:p>';
Uint8List doc(String body) {
  final b = utf8.encode(
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>',
  );
  return Uint8List.fromList(
    ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('word/document.xml', b.length, b)),
    ),
  );
}

Future<PublishManuscript> apply(Uint8List b, {String title = ''}) async =>
    ManuscriptDocumentParser.applyParseResult(
      manuscript: PublishManuscript(userId: 'qa', title: title),
      parsed: await ManuscriptDocumentParser.parseFile(
        bytes: b,
        filename: 'source.docx',
      ),
      replaceBody: true,
      replaceReferences: true,
    );
void main() {
  test('later compact byline cannot gain bonus over a split title', () {
    const t = 'IndependentCoordinatedFeatureLearning SeparateManifoldAlignment';
    expect(DocxTitleReader.read(doc(p('IndependentCoordinatedFeatureLearning', size: 32) +
      p('SeparateManifoldAlignment', size: 32) +
      p('AliceBakera,BrianColeb,andDanaWestc', size: 24) +
      p('aResearchCenter,City,USA;bUniversityofScience,City,USA', size: 20) +
      p('Abstract'))), t);
  });
  test('prominent short three-word title beats abstract prose', () {
    expect(DocxTitleReader.read(doc(p('Local Motion Effects', size: 40) +
      p('Abstract Mean values describe independent observations', size: 24))),
      'Local Motion Effects');
  });
  test('compact non-English and observatory affiliations are not titles', () {
    const t = 'Independent measurements of galactic stellar populations';
    expect(DocxTitleReader.read(doc(p(t, size: 30) +
      p('Istituto di Scienza, City, Country', size: 24) +
      p('ExampleObservatory,1400MainRoad,City,USA', size: 24) +
      p('Abstract'))), t);
  });
  test('PDF compact camel-case title survives beside compact affiliation', () {
    const t = 'IndependentStudyOfGalacticMeasurements';
    expect(DocxTitleReader.read(doc(p('DraftversionMay12,2020 TypesetusingLATEXmodernstyle', size: 20) +
      p(t, size: 24) + p('1DepartmentofPhysics,ExampleUniversity,USA', size: 20) + p('Abstract'))), t);
  });
  test('publisher identifiers do not hide an unsized title', () {
    const t = 'Independent evidence for coordinated plant treatment pathways';
    expect(DocxTitleReader.read(doc(p('Print ISSN: 1234-5678 | Online ISSN: 5678-1234', size: 18) +
      p(t) + p('Alice Baker', size: 20) + p('Abstract'))), t);
  });
  test('draft typesetting metadata is not a title', () {
    const t = 'Independent measurements of galactic stellar populations';
    expect(DocxTitleReader.read(doc(p('DraftversionMay12,2020 TypesetusingLATEXmodernstyle', size: 20) +
      p(t, size: 24) + p('Abstract'))), t);
  });
  test('Cyrillic affiliation words use Unicode boundaries', () {
    const t = 'Независимые наблюдения за историей научных измерений';
    expect(DocxTitleReader.read(doc(p(t, size: 36) +
      p('аспирант кафедры истории древнего мира', size: 28) + p('Abstract'))), t);
  });
  test('explicit typography beats an unmarked comma separated byline', () {
    const t = 'Independent observations of coordinated treatment pathways';
    expect(DocxTitleReader.read(doc(p(t, size: 32) +
      p('Alice Baker, Brian Cole, Dana West, and Eva North') +
      p('Department of Research, Example University') + p('Abstract'))), t);
  });
  test('credentials do not outweigh an earlier scientific title', () {
    const t = 'Independent scientific observations of material transport';
    expect(DocxTitleReader.read(doc(p(t, size: 24) +
      p('Wissenschaftliche Beobachtungen des Materialtransports', size: 24) +
      p('Alice Baker', size: 24) +
      p('Research Scholar, English Professor, Specialist in Genetics', size: 24) +
      p('Abstract'))), t);
  });

  test('source title final capitals are not silently removed as a name', () async {
    const t = 'Independent Deep Learning for Image Classification';
    final manuscript = await apply(doc(p(t, size: 32) + p('Abstract')));
    expect(manuscript.title, t);
    final output = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: manuscript,
      rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
    );
    final xml = XmlDocument.parse(utf8.decode(ZipDecoder().decodeBytes(output)
        .findFile('word/document.xml')!.content as List<int>));
    expect(xml.findAllElements('w:t').first.innerText, t);
  });
  test('inherited paragraph style makes source title stronger than a byline', () async {
    const t = 'Independent coordinated materials for more efficient agriculture';
    final body = '<w:p><w:pPr><w:pStyle w:val="CustomTitle"/></w:pPr>'
        '<w:r><w:t>$t</w:t></w:r></w:p>'
        '${p('Alice Baker,a Brian Cole,b Dana West,c and Eva North,a,*')}${p('Abstract')}';
    final original = ZipDecoder().decodeBytes(doc(body));
    final styleXml = utf8.encode('<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:style w:styleId="BaseDisplay"><w:rPr><w:sz w:val="42"/></w:rPr></w:style>'
        '<w:style w:styleId="CustomTitle"><w:name w:val="Custom Title"/>'
        '<w:basedOn w:val="BaseDisplay"/></w:style></w:styles>');
    original.addFile(ArchiveFile('word/styles.xml', styleXml.length, styleXml));
    expect((await apply(Uint8List.fromList(ZipEncoder().encode(original)))).title, t);
  });
  test('licensing prose before a prominent title is not promoted', () {
    const t = 'Independent Attention Across Many Scientific Tasks';
    expect(DocxTitleReader.read(doc(p('Provided proper attribution, reuse is permitted for scholarly works.') +
        p(t, size: 34) + p('Abstract'))), t);
  });

  const title =
      'Measuring coastal nutrient transport with independent observations';
  test('earlier paragraph title beats later body heading', () async {
    final b = doc(
      p(title) +
          p('Running head: Nutrient transport') +
          p('ABSTRACT') +
          p('Independent observations describe the study in detail.') +
          p('Data collection and signal analysis', bold: true),
    );
    expect((await apply(b)).title, title);
  });
  test('explicit user title is never overwritten', () async {
    expect(
      (await apply(
        doc(p(title) + p('ABSTRACT')),
        title: 'My chosen manuscript title',
      )).title,
      'My chosen manuscript title',
    );
  });
  test('split prominent title joins before author line', () {
    expect(
      DocxTitleReader.read(
        doc(
          p('Measuring coastal nutrient transport', size: 36) +
              p('with independent observations', size: 36) +
              p('Alice Baker1, Brian Cole2 and Dana West3', size: 20) +
              p('Abstract'),
        ),
      ),
      title,
    );
  });
  test('metadata sidebar between title lines does not become title', () {
    expect(
      DocxTitleReader.read(
        doc(
          p('Measuring coastal nutrient transport', size: 36) +
              p('EDITED BY Example University', size: 14) +
              p('with independent observations', size: 36) +
              p('Abstract'),
        ),
      ),
      title,
    );
  });
  test('running head is not a title candidate', () {
    expect(
      DocxTitleReader.read(
        doc(
          p(title) +
              p('Running head: A misleading secondary heading', size: 40) +
              p('Abstract'),
        ),
      ),
      title,
    );
  });
  test('only title prefix is removed from mixed export paragraph', () async {
    final bytes = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: const PublishManuscript(
        userId: 'qa',
        title: title,
        bodyBlocks: [
          ManuscriptBlock(
            id: 'mixed',
            type: ManuscriptBlockType.paragraph,
            text:
                '$title\nAlice Baker, Brian Cole and Dana West\nDepartment of Ecology, Example University',
          ),
        ],
      ),
      rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
    );
    final x = XmlDocument.parse(
      utf8.decode(
        ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content
            as List<int>,
      ),
    );
    final t = x.findAllElements('w:t').map((e) => e.innerText).join(' ');
    expect(t, contains('Alice Baker, Brian Cole and Dana West'));
    expect(t, contains('Department of Ecology, Example University'));
    expect(title.allMatches(t).length, 1);
  });
  test('body-only document does not promote a later heading', () {
    expect(
      DocxTitleReader.read(
        doc(
          p('Introduction') +
              p(
                'A large subsection that describes independent measurements',
                size: 48,
              ),
        ),
      ),
      isNull,
    );
  });
  test('title does not need an Abstract boundary', () {
    expect(
      DocxTitleReader.read(
        doc(
          p(title, size: 28) +
              p('Introduction') +
              p('Later scientific measurements and observations', size: 50),
        ),
      ),
      title,
    );
  });
  test('standalone numeric measurements remain valid title content', () {
    const t = 'Comparing 25 independent coastal nutrient measurements';
    expect(DocxTitleReader.read(doc(p(t, size: 36) + p('Abstract'))), t);
  });
  test('an Introduction to a subject can be a legitimate title', () {
    const t = 'Introduction to reproducible ecological field measurement';
    expect(DocxTitleReader.read(doc(p(t, size: 36) + p('Abstract'))), t);
  });
  test('a caption is never selected as the manuscript title', () {
    expect(
      DocxTitleReader.read(
        doc(
          p('Table 2. Independent observations from coastal sites', size: 42) +
              p('References'),
        ),
      ),
      isNull,
    );
  });
  test('malformed or non-Word bytes return no title', () {
    expect(DocxTitleReader.read(Uint8List.fromList([1, 2, 3])), isNull);
  });
  test('split source title is emitted once and later body text survives', () async {
    final b = doc(
      p('Measuring coastal nutrient transport', size: 36) +
          p('with independent observations', size: 36) +
          p('Alice Baker1, Brian Cole2 and Dana West3', size: 20) +
          p('Abstract') +
          p(
            'The observations remain unchanged and scientifically meaningful.',
          ) +
          p('Introduction') +
          p(
            'Measuring coastal nutrient transport with independent observations is the study objective.',
          ),
    );
    final m = await apply(b);
    final bytes = await ManuscriptDocxExportService.instance.buildDocx(
      manuscript: m,
      rules: JournalFormatRules.forStudentStyle(PublishCitationStyle.apa),
    );
    final x = XmlDocument.parse(
      utf8.decode(
        ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content
            as List<int>,
      ),
    );
    final t = x.findAllElements('w:t').map((e) => e.innerText).join(' ');
    expect(t, contains('Alice Baker'));
    expect(
      t,
      contains(
        'Measuring coastal nutrient transport with independent observations is the study objective.',
      ),
    );
    expect(t, contains('scientifically meaningful.'));
  });
}
