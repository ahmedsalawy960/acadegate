import 'dart:io';
import 'dart:math' as math;

import 'package:acadegate/features/acadegate_publish/bibliography_match.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/citation_linker.dart';
import 'package:acadegate/features/acadegate_publish/docx_scientific_extractor.dart';
import 'package:acadegate/features/acadegate_publish/citation_style_converter.dart';
import 'package:acadegate/features/acadegate_publish/citation_style_shapes.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_citation_helper.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:acadegate/features/acadegate_publish/scholarly_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bold body numbers are citations, bibliography lines are not', () {
    expect(CitationLinker.looksLikeCitationHint('1', inBody: true), isTrue);
    expect(CitationLinker.looksLikeCitationHint('1', inBody: false), isFalse);
    expect(CitationLinker.looksLikeCitationHint('[12]', inBody: true), isTrue);
    expect(
      CitationLinker.looksLikeBibliographyLine(
        'Matheis, K.; Granvogl, M. Quantitation of 3-MCPD. '
        'J. Agric. Food Chem. 2017, 65, 1234-1240.',
      ),
      isTrue,
    );
    expect(
      CitationLinker.applyHintWrap('1', inBody: true),
      contains(CitationLinker.hintOpen),
    );
  });

  test('title-page authors and affiliation [1] are not citations', () {
    const byline =
        'Khaled Elgendy ¹*, Mounir Zaky ¹, and Ahmed Salawy Mohammed ¹ '
        '[1]Chemistry Department, Faculty of Science, Zagazig University, '
        'Zagazig, Egypt. ; (+20 01005169453)';
    expect(DocxScientificExtractor.isFrontMatterAuthorText(byline), isTrue);
    expect(
      DocxScientificExtractor.looksLikeAffiliationBracket(byline, byline.indexOf('[')),
      isTrue,
    );
    expect(
      DocxScientificExtractor.isFrontMatterAuthorText(
        'Corresponding author: elgendykh64@hotmail.com*',
      ),
      isTrue,
    );

    final refs = [
      const PublishReference(
        id: 'ref_1',
        type: ReferenceType.journal,
        authors: ['Daun, J. K.'],
        title: 'Canola',
        year: '2011',
        rawText: 'Daun, J. K., Eskin, N. A., & Hickling, D. (2011). Canola.',
      ),
    ];
    final linked = CitationLinker.linkTextWithRefs(byline, refs);
    expect(linked, isNot(contains('{{cite:')));
    expect(linked, contains('[1]Chemistry Department'));
  });

  test('Introduction author-year groups link against the bibliography', () {
    final refs = [
      const PublishReference(
        id: 'daun',
        type: ReferenceType.journal,
        authors: ['Daun, J. K.', 'Eskin, N. A.', 'Hickling, D.'],
        title: 'Canola',
        year: '2011',
        rawText: 'Daun, J. K., Eskin, N. A., and Hickling, D. (2011). Canola.',
      ),
      const PublishReference(
        id: 'carrer',
        type: ReferenceType.journal,
        authors: ['Carrer, P.', 'Pouzet, A.'],
        title: 'Rapeseed',
        year: '2014',
        rawText: 'Carrer, P., & Pouzet, A. (2014). Rapeseed market.',
      ),
      const PublishReference(
        id: 'haar',
        type: ReferenceType.journal,
        authors: ['Von Der Haar, D.'],
        title: 'Protein',
        year: '2014',
        rawText: 'Von Der Haar, D. et al. (2014). Protein.',
      ),
      const PublishReference(
        id: 'rodrigues',
        type: ReferenceType.journal,
        authors: ['Rodrigues, I. M.'],
        title: 'Oil',
        year: '2012',
        rawText: 'Rodrigues, I. M. (2012). Oil.',
      ),
      const PublishReference(
        id: 'mupondwa',
        type: ReferenceType.journal,
        authors: ['Mupondwa, E.', 'Li, X.', 'Wanasundara, J.'],
        title: 'Canola protein',
        year: '2018',
        rawText: 'Mupondwa, E., Li, X., and Wanasundara, J. (2018). Protein.',
      ),
      const PublishReference(
        id: 'ccc',
        type: ReferenceType.web,
        authors: ['CCC'],
        title: 'Canola Council',
        year: '2015',
        rawText: 'CCC. (2015). Canola Council of Canada.',
      ),
      const PublishReference(
        id: 'shahidi',
        type: ReferenceType.book,
        authors: ['Shahidi, F.'],
        title: 'Canola and rapeseed',
        year: '1990',
        rawText: 'Shahidi, F. (Ed.). (1990). Canola and rapeseed.',
      ),
      const PublishReference(
        id: 'aider',
        type: ReferenceType.journal,
        authors: ['Aider, M.', 'Barbana, C.'],
        title: 'Isolates',
        year: '2011',
        rawText: 'Aider, M., and Barbana, C. (2011). Isolates.',
      ),
      const PublishReference(
        id: 'wana',
        type: ReferenceType.journal,
        authors: ['Wanasundara, J. P. D.'],
        title: 'Proteins',
        year: '2016',
        rawText: 'Wanasundara, Janitha P.D., et al. (2016). Proteins.',
      ),
    ];

    final intro =
        'amount of oil (Daun, J. K., Eskin, N.A., and Hickling, D. (2011). '
        'enhances its appeal (Carrer and Pouzet 2014; Von Der Haar et al. 2014; '
        'Rodrigues et al. 2012; Mupondwa, Li, and Wanasundara 2018). '
        'rely on canola (Rodrigues et al. 2012; CCC 2015; Wanasundara et al. 2016) '
        'consumption (Shahidi, F. Ed. 1990; Aider, M. and Barbana, C., 2011; '
        'Wanasundara, Janitha PD, et al 2016).';

    final linked = CitationLinker.linkTextWithRefs(intro, refs);
    expect(linked, contains('{{cite:daun}}'));
    expect(linked, contains('{{cite:carrer}}'));
    expect(linked, contains('{{cite:haar}}'));
    expect(linked, contains('{{cite:rodrigues}}'));
    expect(linked, contains('{{cite:mupondwa}}'));
    expect(linked, contains('{{cite:ccc}}'));
    expect(linked, contains('{{cite:shahidi}}'));
    expect(linked, contains('{{cite:aider}}'));
    expect(linked, contains('{{cite:wana}}'));
    expect(linked, isNot(contains('Carrer and Pouzet 2014')));
    expect(linked, isNot(contains('Daun, J. K.')));
    expect(linked, isNot(contains('Hickling')));
  });

  test('bold semicolon group is four references, numbered separately', () {
    const group =
        '(Carrer and Pouzet 2014; Von Der Haar et al. 2014; '
        'Rodrigues et al. 2012; Mupondwa, Li, and Wanasundara 2018)';
    expect(CitationLinker.looksLikeCitationHint(group, inBody: true), isTrue);
    final wrapped = CitationLinker.applyHintWrap(group, inBody: true);
    expect(wrapped, contains(CitationLinker.hintOpen));

    final refs = [
      const PublishReference(
        id: 'carrer',
        type: ReferenceType.journal,
        authors: ['Carrer, P.', 'Pouzet, A.'],
        title: 'Rapeseed',
        year: '2014',
        rawText: 'Carrer, P., & Pouzet, A. (2014). Rapeseed market.',
      ),
      const PublishReference(
        id: 'haar',
        type: ReferenceType.journal,
        authors: ['Von Der Haar, D.'],
        title: 'Protein',
        year: '2014',
        rawText: 'Von Der Haar, D. et al. (2014). Protein.',
      ),
      const PublishReference(
        id: 'rodrigues',
        type: ReferenceType.journal,
        authors: ['Rodrigues, I. M.'],
        title: 'Oil',
        year: '2012',
        rawText: 'Rodrigues, I. M. (2012). Oil.',
      ),
      const PublishReference(
        id: 'mupondwa',
        type: ReferenceType.journal,
        authors: ['Mupondwa, E.', 'Li, X.', 'Wanasundara, J.'],
        title: 'Canola protein',
        year: '2018',
        rawText: 'Mupondwa, E., Li, X., and Wanasundara, J. (2018). Protein.',
      ),
    ];
    final linked = CitationLinker.linkTextWithRefs(
      'enhances its appeal $wrapped.',
      refs,
    );
    expect(linked, contains('{{cite:carrer}}'));
    expect(linked, contains('{{cite:haar}}'));
    expect(linked, contains('{{cite:rodrigues}}'));
    expect(linked, contains('{{cite:mupondwa}}'));
    expect(RegExp(r'\{\{cite:').allMatches(linked).length, 4);

    final ieee = ManuscriptCitationHelper.resolvePlainText(
      text: linked,
      manuscript: PublishManuscript(
        userId: 'u',
        title: 't',
        body: linked,
        references: refs,
        citationStyle: PublishCitationStyle.ieee,
      ),
      style: PublishCitationStyle.ieee,
    );
    expect(ieee, contains('[1,2,3,4]'));
    expect(ieee, isNot(contains('Carrer and Pouzet')));
  });

  test('IEEE conversion uses Introduction cites, never title-page authors', () {
    final manuscript = PublishManuscript(
      id: 'ms',
      userId: 'u',
      title: 'Rapeseed',
      abstractText: 'Oilseed crop.',
      body:
          'Khaled Elgendy ¹*, Mounir Zaky ¹, and Ahmed Salawy Mohammed ¹ '
          '[1]Chemistry Department, Faculty of Science, Zagazig University.\n\n'
          'amount of oil (Daun, J. K., Eskin, N.A., and Hickling, D. (2011). '
          'enhances its appeal (Carrer and Pouzet 2014; Von Der Haar et al. 2014).',
      bodyBlocks: [
        const ManuscriptBlock(
          id: 'authors',
          type: ManuscriptBlockType.paragraph,
          text:
              'Khaled Elgendy ¹*, Mounir Zaky ¹, and Ahmed Salawy Mohammed ¹ '
              '[1]Chemistry Department, Faculty of Science, Zagazig University, '
              'Zagazig, Egypt.',
        ),
        const ManuscriptBlock(
          id: 'intro',
          type: ManuscriptBlockType.heading,
          text: 'Introduction',
        ),
        const ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text:
              'amount of oil (Daun, J. K., Eskin, N.A., and Hickling, D. (2011). '
              'enhances its appeal (Carrer and Pouzet 2014; Von Der Haar et al. 2014).',
        ),
      ],
      references: const [
        PublishReference(
          id: 'daun',
          type: ReferenceType.journal,
          authors: ['Daun, J. K.', 'Eskin, N. A.', 'Hickling, D.'],
          title: 'Canola',
          year: '2011',
          rawText: 'Daun, J. K., Eskin, N. A., and Hickling, D. (2011). Canola.',
        ),
        PublishReference(
          id: 'carrer',
          type: ReferenceType.journal,
          authors: ['Carrer, P.', 'Pouzet, A.'],
          title: 'Rapeseed',
          year: '2014',
          rawText: 'Carrer, P., & Pouzet, A. (2014). Rapeseed market.',
        ),
        PublishReference(
          id: 'haar',
          type: ReferenceType.journal,
          authors: ['Von Der Haar, D.'],
          title: 'Protein',
          year: '2014',
          rawText: 'Von Der Haar, D. et al. (2014). Protein.',
        ),
      ],
      citationStyle: PublishCitationStyle.apa,
    );

    final ieee = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.ieee,
    );
    final intro = ieee.bodyBlocks.firstWhere((b) => b.id == 'p1').text;
    expect(intro, contains('[1]'));
    expect(intro, contains('[2'));
    expect(intro, isNot(contains('{{cite:')));
    expect(intro, isNot(contains('Daun, J. K.')));
    expect(
      ieee.bodyBlocks.firstWhere((b) => b.id == 'authors').text,
      contains('[1]Chemistry Department'),
    );
    expect(
      ieee.bodyBlocks.firstWhere((b) => b.id == 'authors').text,
      isNot(contains('{{cite:')),
    );
    expect(ieee.references.map((r) => r.id).toList(), ['daun', 'carrer', 'haar']);
  });

  test('bibliography at file end wins over title-page authors', () {
    const paper = '''
Khaled Elgendy ¹*, Mounir Zaky ¹
[1]Chemistry Department, Faculty of Science, Zagazig University, Egypt.
Corresponding author: elgendykh64@hotmail.com*
Abstract
Oilseed summary.
Introduction
The crop produces oil (Daun, J. K., Eskin, N.A., and Hickling, D. 2011).
This enhances its appeal (Carrer and Pouzet 2014; Von Der Haar et al. 2014).
5. References
Daun, J. K., Eskin, N. A., and Hickling, D. (2011). Canola: chemistry, production, processing and utilization. AOCS Press.
Carrer, P., and Pouzet, A. (2014). Rapeseed market, worldwide and in Europe. OCL, 21(1), D102.
Von Der Haar, D., Muller, K., and Bader, S. (2014). Rapeseed proteins for food. European Food Research and Technology, 239, 1-10.
''';
    final refs = ManuscriptDocumentParser.parseReferencesFromText(paper);
    expect(refs.length, greaterThanOrEqualTo(3));
    expect(refs.any((r) => r.rawText.contains('Daun')), isTrue);
    expect(refs.any((r) => r.rawText.contains('Carrer')), isTrue);
    expect(refs.any((r) => r.rawText.contains('Khaled')), isFalse);
    expect(refs.any((r) => r.rawText.contains('Chemistry Department')), isFalse);
  });

  test('imported file matches Introduction names to the end-of-file References',
      () {
    const paper = '''
Khaled Elgendy ¹*, Mounir Zaky ¹, and Ahmed Salawy Mohammed ¹
[1]Chemistry Department, Faculty of Science, Zagazig University, Zagazig, Egypt.
Corresponding author: elgendykh64@hotmail.com*

Abstract
Rapeseed is an oilseed crop used for edible oil.

Introduction
The crop produces a large amount of oil (Daun, J. K., Eskin, N.A., and Hickling, D. (2011).
This enhances its appeal (Carrer and Pouzet 2014; Von Der Haar et al. 2014; Rodrigues et al. 2012; Mupondwa, Li, and Wanasundara 2018).
Many processors primarily rely on canola (Rodrigues et al. 2012; CCC 2015; Wanasundara et al. 2016).
It is suited for human consumption (Shahidi, F. Ed. 1990; Aider, M. and Barbana, C., 2011; Wanasundara, Janitha PD, et al 2016).

References
Daun, J. K., Eskin, N. A., and Hickling, D. (2011). Canola: chemistry, production, processing and utilization. AOCS Press.
Carrer, P., and Pouzet, A. (2014). Rapeseed market, worldwide and in Europe. OCL, 21(1), D102.
Von Der Haar, D., Muller, K., and Bader, S. (2014). Rapeseed proteins for food. European Food Research and Technology, 239, 1-10.
Rodrigues, I. M., Coelho, J. F., and Carvalho, M. G. (2012). Isolation and valorisation of vegetable proteins. Food Research International, 47, 1-12.
Mupondwa, E., Li, X., and Wanasundara, J. (2018). Integrated processing of canola. Journal of the American Oil Chemists Society, 95, 1-15.
CCC. (2015). Canola Council of Canada annual report. Winnipeg.
Shahidi, F. (Ed.). (1990). Canola and rapeseed: production, chemistry, nutrition. Van Nostrand.
Aider, M., and Barbana, C. (2011). Canola proteins: composition and isolation. Trends in Food Science and Technology, 22, 21-39.
Wanasundara, Janitha P.D., McIntosh, T., and Perera, S. (2016). Canola/rapeseed protein. Journal of the American Oil Chemists Society, 93, 1-20.
''';

    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    expect(parsed.references.length, greaterThanOrEqualTo(8));
    expect(
      parsed.references.any((r) => r.rawText.contains('Daun')),
      isTrue,
    );
    expect(
      parsed.references.any((r) => r.rawText.contains('Chemistry Department')),
      isFalse,
    );
    expect(
      parsed.references.any((r) => r.rawText.contains('Khaled Elgendy')),
      isFalse,
    );

    final ieee = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Rapeseed',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      style: PublishCitationStyle.ieee,
    );
    final body = ieee.bodyBlocks.map((b) => b.text).join('\n');
    expect(body, contains('['));
    expect(body, isNot(contains('Carrer and Pouzet 2014')));
    expect(body, contains('[1]Chemistry Department'));
    expect(
      ieee.references.where((r) => r.rawText.contains('Daun')).length,
      1,
    );
  });

  test('introduction sentences are not title-page author blocks', () {
    expect(
      DocxScientificExtractor.isFrontMatterAuthorText(
        'According to Matheis and Granvogl, the oil was refined using the method.',
      ),
      isFalse,
    );
    expect(
      DocxScientificExtractor.isFrontMatterAuthorText(
        'K. Matheis, M. Granvogl¹, University of Hohenheim',
      ),
      isTrue,
    );
  });

  test('ACS bibliography is rebuilt into APA instead of copied raw', () {
    const raw =
        '[12] Matheis, K.; Granvogl, M. Quantitation of 3-MCPD. '
        'J. Agric. Food Chem. 2017, 65, 1234-1240.';
    final parsed = CitationFormatter.parseBibliographicLine(raw);
    expect(parsed, isNotNull);
    expect(parsed!.authors.first, contains('Matheis'));
    expect(parsed.year, '2017');
    expect(parsed.title.toLowerCase(), contains('quantitation'));

    final entry = CitationFormatter.buildBibliographyEntry(
      reference: parsed.copyWith(id: 'ref_12', rawText: raw),
      style: PublishCitationStyle.apa,
      index: 1,
    );
    expect(entry.plain, contains('Matheis'));
    expect(entry.plain, contains('(2017)'));
    expect(entry.plain, isNot(contains('[12]')));
  });

  test('APA in-text with initials links to bibliography', () {
    final refs = [
      const PublishReference(
        id: 'ref_1',
        type: ReferenceType.journal,
        authors: ['Matheis, K.', 'Granvogl, M.'],
        title: 'Characterization of key odorants',
        year: '2016',
        rawText:
            'Matheis, K., Granvogl, M. (2016). Characterization of key odorants. J. Agric. Food Chem.',
      ),
    ];
    final linked = CitationLinker.linkTextWithRefs(
      'alcohols (Matheis, K., & Granvogl, M. 2016).',
      refs,
    );
    expect(linked, contains('{{cite:ref_1}}'));
    expect(linked, isNot(contains('Matheis, K., & Granvogl')));
  });

  test('homepage text is not treated as this journal author guide', () {
    const homepage =
        'Welcome to our journal. Read the latest manuscript news. '
        'Abstract submissions are open. Times New Roman is a font on this site. '
        'See [1] for an example homepage widget. Microsoft Word files are common.';
    expect(JournalGuidelinesHeuristic.extract(homepage), isNull);
  });

  test('guide sample line infers Vancouver numbered list', () {
    final inferred = JournalFormatRules.inferCitationFromExamples(
      referenceExample:
          '1. Matheis, K.; Granvogl, M. Quantitation of 3-MCPD. '
          'J. Agric. Food Chem. 2017, 65, 1234-1240.',
      inTextExample: '[1]',
    );
    expect(inferred, isNotNull);
    expect(inferred!.style, PublishCitationStyle.vancouver);
    expect(inferred.plainNumber, isTrue);
  });

  test('guide sample line is extracted instead of generic homepage rules', () {
    const guide =
        'Instructions for authors. Manuscripts must be single-spaced. '
        'References should appear as follows: '
        '1. Matheis, K.; Granvogl, M. Quantitation of 3-MCPD. '
        'J. Agric. Food Chem. 2017, 65, 1234-1240. '
        'Use numbered in-text citations [1].';
    final extracted = JournalGuidelinesHeuristic.extract(guide);
    expect(extracted, isNotNull);
    expect(extracted!['referenceExample']?.toString(), contains('Matheis'));
    expect(extracted['lineSpacing'], 1.0);
  });

  test('bold headings are not citations, bold author names are', () {
    expect(CitationStyleShapes.looksLikeSectionHeading('Introduction'), isTrue);
    expect(CitationStyleShapes.looksLikeSectionHeading('2. Experimental'), isTrue);
    expect(CitationLinker.looksLikeCitationHint('Introduction', inBody: true), isFalse);
    expect(CitationLinker.applyHintWrap('Introduction', inBody: true), 'Introduction');
    expect(
      CitationLinker.looksLikeCitationHint('Aider and Kelebek, 2012', inBody: true),
      isTrue,
    );
    expect(
      CitationLinker.looksLikeCitationHint('(Aider & Kelebek, 2012)', inBody: true),
      isTrue,
    );
    expect(CitationLinker.looksLikeCitationHint('Aider', inBody: true), isTrue);
  });

  test('IEEE author already in F. Last form is not reversed', () {
    final entry = CitationFormatter.buildBibliographyEntry(
      reference: const PublishReference(
        id: 'r1',
        type: ReferenceType.journal,
        authors: ['M. Aider', 'H. Kelebek', 'C. Barbana'],
        title: 'Protein isolates from rapeseed',
        container: 'J. Food Sci.',
        year: '2012',
        volume: '22',
        issue: '2',
        pages: '94-99',
        rawText:
            'M. Aider, H. Kelebek, and C. Barbana, "Protein isolates from rapeseed," '
            'J. Food Sci., vol. 22, no. 2, pp. 94-99, 2012.',
      ),
      style: PublishCitationStyle.ieee,
      index: 1,
    );
    expect(entry.plain, startsWith('[1] M. Aider'));
    expect(entry.plain, contains('H. Kelebek'));
    expect(entry.plain, contains('C. Barbana'));
    expect(entry.plain, isNot(contains('.M. Aider')));
    expect(entry.plain, isNot(contains('(, vol')));
    expect(entry.plain, contains('J. Food Sci'));
  });

  test('bold author name links to the matching bibliography entry', () {
    final refs = [
      const PublishReference(
        id: 'ref_1',
        type: ReferenceType.journal,
        authors: ['Aider, M.', 'Kelebek, H.'],
        title: 'Protein isolates',
        year: '2012',
        rawText: 'Aider, M., & Kelebek, H. (2012). Protein isolates.',
      ),
    ];
    final linked = CitationLinker.linkTextWithRefs(
      'the isolate ${CitationLinker.hintOpen}Aider and Kelebek${CitationLinker.hintClose} was used.',
      refs,
    );
    expect(linked, contains('{{cite:ref_1}}'));
    expect(linked, isNot(contains('Aider and Kelebek')));
  });

  test('IEEE numbers follow imported bibliography order, not first appearance', () {
    const aider = PublishReference(
      id: 'ref_aider',
      type: ReferenceType.journal,
      authors: ['Aider, M.'],
      title: 'Protein isolates from rapeseed',
      year: '2012',
      importedNumber: 2,
      rawText: 'Aider, M. (2012). Protein isolates from rapeseed. J. Food Sci.',
    );
    const kelebek = PublishReference(
      id: 'ref_kelebek',
      type: ReferenceType.journal,
      authors: ['Kelebek, H.'],
      title: 'Volatile compounds of olive oil',
      year: '2014',
      importedNumber: 1,
      rawText: 'Kelebek, H. (2014). Volatile compounds of olive oil. Food Chem.',
    );
    const manuscript = PublishManuscript(
      userId: 'u',
      title: 'Paper',
      body: 'Oils (Aider, 2012) then later (Kelebek, 2014).',
      bodyBlocks: [
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text: 'Oils (Aider, 2012) then later (Kelebek, 2014).',
        ),
      ],
      references: [kelebek, aider],
      citationStyle: PublishCitationStyle.apa,
    );

    final ieee = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.ieee,
    );
    expect(ieee.references.first.id, 'ref_kelebek');
    expect(ieee.references[1].id, 'ref_aider');

    final body = ManuscriptCitationHelper.resolvePlainText(
      text: ieee.bodyBlocks.first.text,
      manuscript: ieee,
      style: PublishCitationStyle.ieee,
      applyNumberedInText: true,
    );
    expect(body, contains('[1]'));
    expect(body, contains('[2]'));
    expect(body, isNot(contains('Aider, 2012')));
    expect(body, isNot(contains('Kelebek, 2014')));
    // Imported list: Kelebek=[1], Aider=[2]. Text cites Aider first.
    expect(body, contains('Oils [2] then later [1]'));

    final bib = CitationFormatter.formatBibliography(
      references: ieee.references,
      style: PublishCitationStyle.ieee,
    );
    expect(bib, startsWith('[1]'));
    expect(bib.indexOf('Kelebek'), lessThan(bib.indexOf('Aider')));
  });

  test('IEEE numbers become APA author-year and A-Z bibliography', () {
    const aider = PublishReference(
      id: 'ref_1',
      type: ReferenceType.journal,
      authors: ['Aider, M.'],
      title: 'Protein isolates from rapeseed',
      year: '2012',
      importedNumber: 1,
      rawText:
          '[1] M. Aider, "Protein isolates from rapeseed," J. Food Sci., 2012.',
    );
    const kelebek = PublishReference(
      id: 'ref_2',
      type: ReferenceType.journal,
      authors: ['Kelebek, H.'],
      title: 'Volatile compounds of olive oil',
      year: '2014',
      importedNumber: 2,
      rawText:
          '[2] H. Kelebek, "Volatile compounds of olive oil," Food Chem., 2014.',
    );
    const manuscript = PublishManuscript(
      userId: 'u',
      title: 'Paper',
      body: 'Oils [2] then earlier work [1].',
      bodyBlocks: [
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text: 'Oils [2] then earlier work [1].',
        ),
      ],
      references: [aider, kelebek],
      citationStyle: PublishCitationStyle.ieee,
    );

    final apa = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.apa,
    );
    expect(apa.references.first.authors.first, contains('Aider'));

    final body = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(body, contains('(Kelebek, 2014)'));
    expect(body, contains('(Aider, 2012)'));
    expect(body, isNot(contains('[1]')));
    expect(body, isNot(contains('[2]')));
    expect(body, contains('Oils (Kelebek, 2014) then earlier work (Aider, 2012)'));
  });

  test('in-text [n] stays the same bibliography n; APA uses that same work', () {
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest('''
Introduction
Oils [3] and earlier work [1] then Daun [2].
References
[1] F. Shahidi, "Canola and rapeseed: production, chemistry, nutrition," Van Nostrand, 1990.
[2] J. K. Daun, "Canola," AOCS Press, 2011.
[3] M. Aider and C. Barbana, "Canola proteins: composition and isolation," Food Chem., vol. 22, pp. 21-39, 2011.
''');
    expect(parsed.references.length, 3);
    expect(parsed.references[0].importedNumber, 1);
    expect(parsed.references[1].importedNumber, 2);
    expect(parsed.references[2].importedNumber, 3);
    expect(parsed.references[0].rawText.toLowerCase(), contains('shahidi'));
    expect(parsed.references[2].rawText.toLowerCase(), contains('aider'));

    final manuscript = PublishManuscript(
      userId: 'u',
      title: 'Paper',
      bodyBlocks: parsed.bodyBlocks,
      references: parsed.references,
    );

    final ieee = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.ieee,
    );
    final ieeeBody = ManuscriptCitationHelper.resolvePlainText(
      text: ieee.bodyBlocks.map((b) => b.text).join('\n'),
      manuscript: ieee,
      style: PublishCitationStyle.ieee,
    );
    expect(ieeeBody, contains('Oils [3] and earlier work [1] then Daun [2]'));
    final ieeeBib = CitationFormatter.formatBibliography(
      references: ieee.references,
      style: PublishCitationStyle.ieee,
    );
    expect(ieeeBib, contains('[1]'));
    expect(ieeeBib, contains('[2]'));
    expect(ieeeBib, contains('[3]'));
    expect(ieeeBib.indexOf('Shahidi'), lessThan(ieeeBib.indexOf('Daun')));
    expect(ieeeBib.indexOf('Daun'), lessThan(ieeeBib.indexOf('Aider')));
    expect(
      RegExp(r'\[1\].*Shahidi', dotAll: true).hasMatch(ieeeBib),
      isTrue,
    );
    expect(
      RegExp(r'\[3\].*Aider', dotAll: true).hasMatch(ieeeBib),
      isTrue,
    );

    final apa = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.apa,
    );
    final apaBody = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.map((b) => b.text).join('\n'),
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(apaBody, contains('(Aider'));
    expect(apaBody, contains('(Shahidi'));
    expect(apaBody, contains('(Daun'));
    expect(apaBody, contains('Oils (Aider'));
    expect(apaBody, contains('earlier work (Shahidi'));
    expect(apaBody, contains('then Daun (Daun'));
    expect(apaBody, isNot(contains('[1]')));
    expect(apaBody, isNot(contains('[2]')));
    expect(apaBody, isNot(contains('[3]')));
    // A-Z must not decide who [3] is. File list: [1] Shahidi [2] Daun [3] Aider.
    expect(apa.references[0].rawText.toLowerCase(), contains('shahidi'));
    expect(apa.references[2].rawText.toLowerCase(), contains('aider'));
    expect(apaBody, isNot(contains('Oils (Shahidi')));
  });

  test('IEEE keeps original [3] even if items 1-2 are missing from the list', () {
    const aider = PublishReference(
      id: 'ref_3',
      type: ReferenceType.journal,
      authors: ['Aider, M.'],
      title: 'Canola proteins: composition and isolation',
      year: '2011',
      importedNumber: 3,
      rawText:
          '[3] M. Aider and C. Barbana, "Canola proteins: composition and isolation," Food Chem., 2011.',
    );
    const manuscript = PublishManuscript(
      userId: 'u',
      title: 'Paper',
      body: 'See [3].',
      bodyBlocks: [
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text: 'See [3].',
        ),
      ],
      references: [aider],
      citationStyle: PublishCitationStyle.ieee,
    );

    final ieee = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.ieee,
    );
    final body = ManuscriptCitationHelper.resolvePlainText(
      text: ieee.bodyBlocks.first.text,
      manuscript: ieee,
      style: PublishCitationStyle.ieee,
    );
    expect(body, contains('See [3]'));
    expect(body, isNot(contains('See [1]')));
    final bib = CitationFormatter.formatBibliography(
      references: ieee.references,
      style: PublishCitationStyle.ieee,
    );
    expect(bib, startsWith('[3]'));

    final apa = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.apa,
    );
    final apaBody = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(apaBody, contains('(Aider, 2011)'));
    expect(apaBody, isNot(contains('[3]')));
  });

  test('Lawson et al. (2010) [14] stays bibliography 14, never becomes [1]', () {
    const smith = PublishReference(
      id: 'ref_1',
      type: ReferenceType.journal,
      authors: ['Smith, J.'],
      title: 'Other work',
      year: '2001',
      importedNumber: 1,
      rawText: '[1] J. Smith, "Other work," Food Chem., 2001.',
    );
    const lawson = PublishReference(
      id: 'ref_14',
      type: ReferenceType.journal,
      authors: ['Lawson, K.', 'Jones, P.', 'Lee, S.'],
      title: 'Headspace GC/MS of soybean',
      year: '2010',
      importedNumber: 14,
      rawText:
          '[14] K. Lawson, P. Jones, and S. Lee, "Headspace GC/MS of soybean," '
          'J. Am. Oil Chem. Soc., 2010.',
    );
    const manuscript = PublishManuscript(
      userId: 'u',
      title: 'Soybean',
      body:
          'divided into two parts, utilizing the Lawson et al. (2010) technique [14]. '
          'The remainder was heated to 60°C for 3.5 hours [14].',
      bodyBlocks: [
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text:
              'divided into two parts, utilizing the Lawson et al. (2010) technique [14]. '
              'The remainder was heated to 60°C for 3.5 hours [14].',
        ),
      ],
      references: [smith, lawson],
      citationStyle: PublishCitationStyle.ieee,
    );

    final ieee = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.ieee,
    );
    final ieeeBody = ManuscriptCitationHelper.resolvePlainText(
      text: ieee.bodyBlocks.first.text,
      manuscript: ieee,
      style: PublishCitationStyle.ieee,
    );
    expect(ieeeBody, contains('[14]'));
    expect(ieeeBody, contains('3.5 hours [14]'));
    expect(ieeeBody, isNot(contains('Lawson et al. (2010)')));
    expect(ieeeBody, isNot(contains('technique [1]')));
    expect(ieeeBody, isNot(contains('hours [1]')));
    expect(ieeeBody, isNot(contains('Smith')));

    final apa = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.apa,
    );
    final apaBody = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(apaBody, contains('Lawson et al. (2010)'));
    expect(apaBody, isNot(contains('[14]')));
    expect(apaBody, isNot(contains('[1]')));
    expect(apaBody, isNot(contains('Smith')));
    expect(apaBody, isNot(contains('technique (Smith')));
    expect(apaBody, isNot(contains('Boncan')));
    expect(apaBody, isNot(contains('Luthria')));
  });

  test('IEEE replaces Author (Year) [n] with bibliography n', () {
    const wrigley = PublishReference(
      id: 'ref_1',
      type: ReferenceType.book,
      authors: ['Wrigley, C.', 'Corke, H.', 'Walker, C. E.'],
      title: 'Encyclopedia of Grain Science',
      year: '2004',
      importedNumber: 1,
      rawText:
          '1. Wrigley, C.; Corke, H.; Walker, C.E. Encyclopedia of Grain Science. 2004.',
    );
    const decoy = PublishReference(
      id: 'ref_41',
      type: ReferenceType.journal,
      authors: ['Corke, H.'],
      title: 'Unrelated later work',
      year: '2004',
      importedNumber: 41,
      rawText: '41. Corke, H. Unrelated later work. 2004.',
    );
    const text =
        'According to Corke, Walker, and Wrigley (2004) [1] the remaining portion comprises.';
    final manuscript = PublishManuscript(
      userId: 'u',
      title: 'Soybean',
      body: text,
      bodyBlocks: [
        const ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text: text,
        ),
      ],
      references: [wrigley, decoy],
      citationStyle: PublishCitationStyle.ieee,
    );
    final ieee = ManuscriptCitationHelper.resolvePlainText(
      text: text,
      manuscript: manuscript,
      style: PublishCitationStyle.ieee,
    );
    expect(ieee, contains('[1]'));
    expect(ieee, isNot(contains('Corke, Walker, and Wrigley (2004)')));
    expect(ieee, isNot(contains('[41]')));
  });

  test('does not put Boncan or Luthria next to Lawson et al. (2010) [14]', () {
    const luthria = PublishReference(
      id: 'ref_3',
      type: ReferenceType.journal,
      authors: ['Luthria, D. L.'],
      title: 'Oil extraction',
      year: '2007',
      importedNumber: 3,
      rawText: '3. Luthria, D. L. Oil extraction. 2007.',
    );
    const boncan = PublishReference(
      id: 'ref_20',
      type: ReferenceType.journal,
      authors: ['Boncan, D. A. T.'],
      title: 'Terpenes in plants',
      year: '2020',
      importedNumber: 20,
      rawText: '20. Boncan, D. A. T. Terpenes in plants. 2020.',
    );
    const lawson = PublishReference(
      id: 'ref_14',
      type: ReferenceType.journal,
      authors: ['Lawson, O.', 'Oyewumi, A.'],
      title: 'Evaluation of the parameters affecting the solvent',
      year: '2010',
      importedNumber: 14,
      rawText:
          '14. Lawson, O.; Oyewumi, A. Evaluation of the parameters affecting '
          'the solvent. ARPN J. Eng. Appl. Sci. 2010, 5(10), 51-55.',
    );
    const manuscript = PublishManuscript(
      userId: 'u',
      title: 'Soybean',
      bodyBlocks: [
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text:
              'utilizing the Lawson et al. (2010) technique [14]. '
              'heated to 60°C for 3.5 hours [14].',
        ),
        ManuscriptBlock(
          id: 'p2',
          type: ManuscriptBlockType.paragraph,
          text:
              'According to Corke, Walker, and Wrigley (2004) [3] the remaining portion comprises.',
        ),
      ],
      references: [luthria, boncan, lawson],
    );

    final apa = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.apa,
    );
    final sample = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    final intro = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks[1].text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(sample, contains('Lawson et al. (2010)'));
    expect(sample, isNot(contains('Boncan')));
    expect(sample, isNot(contains('Luthria')));
    expect(intro, contains('Corke'));
    expect(intro, contains('2004'));
    expect(intro, contains('Luthria'), reason: '[3] is bibliography item 3');
  });

  test('split superscript [1⁴] still means bibliography 14', () {
    const smith = PublishReference(
      id: 'ref_1',
      type: ReferenceType.journal,
      authors: ['Smith, J.'],
      title: 'Other work',
      year: '2001',
      importedNumber: 1,
      rawText: '[1] J. Smith, "Other work," Food Chem., 2001.',
    );
    const lawson = PublishReference(
      id: 'ref_14',
      type: ReferenceType.journal,
      authors: ['Lawson, K.'],
      title: 'Headspace GC/MS of soybean',
      year: '2010',
      importedNumber: 14,
      rawText: '[14] K. Lawson, "Headspace GC/MS of soybean," JAOCS, 2010.',
    );
    final linked = CitationLinker.linkTextWithRefs(
      'technique [1⁴] and also ${CitationLinker.hintOpen}1${CitationLinker.hintClose}${CitationLinker.hintOpen}4${CitationLinker.hintClose}.',
      [smith, lawson],
    );
    expect(linked, contains('{{cite:ref_14}}'));
    expect(linked, isNot(contains('{{cite:ref_1}}')));
  });

  test('[14] is Lawson not Luthria; [16] is not Selvarani of [6]', () {
    const luthria = PublishReference(
      id: 'ref_3',
      type: ReferenceType.journal,
      authors: ['Luthria, D. L.'],
      title: 'Oil extraction',
      year: '2007',
      importedNumber: 3,
      rawText: '3. Luthria, D. L. Oil extraction. J. Am. Oil Chem. Soc. 2007, 84, 1-8.',
    );
    const selvarani = PublishReference(
      id: 'ref_6',
      type: ReferenceType.journal,
      authors: ['Selvarani, M.'],
      title: 'Carbohydrate assay',
      year: '2025',
      importedNumber: 6,
      rawText: '[6] M. Selvarani, "Carbohydrate assay," Food Chem., 2025.',
    );
    const lawson = PublishReference(
      id: 'ref_14',
      type: ReferenceType.journal,
      authors: ['Lawson, O.', 'Oyewumi, A.', 'Ologunagba, F.', 'Ojomo, A. O.'],
      title: 'Evaluation of the parameters affecting the solvent',
      year: '2010',
      importedNumber: 14,
      rawText:
          '14. Lawson, O.; Oyewumi, A.; Ologunagba, F.; Ojomo, A.O. '
          'Evaluation of the parameters affecting the solvent. '
          'ARPN J. Eng. Appl. Sci. 2010, 5(10), 51-55.',
    );
    const carbs = PublishReference(
      id: 'ref_16',
      type: ReferenceType.journal,
      authors: ['Nielsen, S. S.'],
      title: 'Determination of carbohydrates',
      year: '2010',
      importedNumber: 16,
      rawText:
          '[16] S. S. Nielsen, "Determination of carbohydrates," Food Analysis, 2010.',
    );
    const manuscript = PublishManuscript(
      userId: 'u',
      title: 'Soybean',
      bodyBlocks: [
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text:
              'utilizing the Lawson et al. (2010) technique [14]. '
              'heated to 60°C for 3.5 hours [14].',
        ),
        ManuscriptBlock(
          id: 'p2',
          type: ManuscriptBlockType.paragraph,
          text: 'Determination of Carbohydrates [16]',
        ),
      ],
      references: [luthria, selvarani, lawson, carbs],
    );

    final apa = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.apa,
    );
    final sample = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    final heading = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks[1].text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(sample, contains('Lawson et al. (2010)'));
    expect(sample, isNot(contains('Luthria')));
    expect(heading, contains('Nielsen'));
    expect(heading, isNot(contains('Selvarani')));

    final split = CitationLinker.linkTextWithRefs(
      'technique [1${CitationLinker.hintOpen}4${CitationLinker.hintClose}] '
      'and Carbohydrates [1${CitationLinker.hintOpen}6${CitationLinker.hintClose}]',
      [luthria, selvarani, lawson, carbs],
    );
    expect(split, contains('{{cite:ref_14}}'));
    expect(split, contains('{{cite:ref_16}}'));
    expect(split, isNot(contains('{{cite:ref_3}}')));
    expect(split, isNot(contains('{{cite:ref_6}}')));
  });

  test('APA A-Z list does not turn [14] into original item 3 Luthria', () {
    const luthria = PublishReference(
      id: 'ref_3',
      type: ReferenceType.journal,
      authors: ['Luthria, D. L.'],
      title: 'Oil extraction methods',
      year: '2007',
      importedNumber: 3,
      rawText:
          '3. Luthria, D.L. Oil extraction methods. J. Am. Oil Chem. Soc. 2007, 84, 1-8.',
    );
    const lawson = PublishReference(
      id: 'ref_14',
      type: ReferenceType.journal,
      authors: ['Lawson, O.', 'Oyewumi, A.'],
      title: 'Evaluation of the parameters affecting the solvent',
      year: '2010',
      importedNumber: 14,
      rawText:
          '14. Lawson, O.; Oyewumi, A. Evaluation of the parameters affecting '
          'the solvent. ARPN J. Eng. Appl. Sci. 2010, 5(10), 51-55.',
    );
    const zebra = PublishReference(
      id: 'ref_1',
      type: ReferenceType.journal,
      authors: ['Zebra, A.'],
      title: 'First alphabetically last in file',
      year: '2000',
      importedNumber: 1,
      rawText: '1. Zebra, A. First alphabetically last in file. 2000.',
    );
    const manuscript = PublishManuscript(
      userId: 'u',
      title: 'Soybean',
      bodyBlocks: [
        ManuscriptBlock(
          id: 'p1',
          type: ManuscriptBlockType.paragraph,
          text: 'utilizing the Lawson et al. (2010) technique [14].',
        ),
      ],
      // Already A–Z: Luthria, Lawson, Zebra — [14] must still be Lawson.
      references: [luthria, lawson, zebra],
      citationStyle: PublishCitationStyle.apa,
    );

    final apa = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.apa,
    );
    final body = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(body, contains('Lawson'));
    expect(body, isNot(contains('Luthria')));
    expect(body, isNot(contains('Zebra')));
  });

  test('soybean Introduction cites the same works as the end list', () {
    final refs = ManuscriptDocumentParser.stampImportedNumbers([
      const PublishReference(
        id: 'corke',
        type: ReferenceType.book,
        authors: ['Corke, H.', 'Walker, C. E.', 'Wrigley, C.'],
        title: 'Encyclopedia of Grain Science',
        year: '2004',
        importedNumber: 1,
        rawText: '1. Corke, H.; Walker, C.E.; Wrigley, C. Encyclopedia of Grain Science. 2004.',
      ),
      const PublishReference(
        id: 'lee',
        type: ReferenceType.journal,
        authors: ['Lee, J.', 'Kim, S.', 'Park, H.'],
        title: 'Soybean nitrogen fixation',
        year: '2008',
        importedNumber: 2,
        rawText: '2. Lee, J.; Kim, S.; Park, H. Soybean nitrogen fixation. 2008.',
      ),
      const PublishReference(
        id: 'luthria',
        type: ReferenceType.journal,
        authors: ['Luthria, D. L.'],
        title: 'Oil extraction',
        year: '2007',
        importedNumber: 3,
        rawText: '3. Luthria, D. L. Oil extraction. J. Am. Oil Chem. Soc. 2007, 84, 1-8.',
      ),
      const PublishReference(
        id: 'mohammed',
        type: ReferenceType.journal,
        authors: ['Mohammed, A.', 'Hassan, B.'],
        title: 'Soybean bioactives',
        year: '2024',
        importedNumber: 4,
        rawText: '4. Mohammed, A.; Hassan, B. Soybean bioactives. 2024.',
      ),
      const PublishReference(
        id: 'marshall1996',
        type: ReferenceType.journal,
        authors: ['Marshall, W. E.', 'Johns, M. M.'],
        title: 'Agricultural by-products as metal adsorbents',
        year: '1996',
        importedNumber: 5,
        rawText:
            '5. Marshall, W.E.; Johns, M.M. Agricultural by-products as metal adsorbents. 1996.',
      ),
      const PublishReference(
        id: 'selvarani',
        type: ReferenceType.journal,
        authors: ['Selvarani, V.', 'Kumar, P.', 'Devi, R.'],
        title: 'Soybean protein',
        year: '2025',
        importedNumber: 6,
        rawText: '6. Selvarani, V.; Kumar, P.; Devi, R. Soybean protein. 2025.',
      ),
      const PublishReference(
        id: 'proctor',
        type: ReferenceType.journal,
        authors: ['Proctor, A.', 'Gnanasambandam, R.'],
        title: 'Soy hull carbon as an adsorbent',
        year: '1997',
        importedNumber: 7,
        rawText:
            '7. Proctor, A.; Gnanasambandam, R. Soy hull carbon as an adsorbent. 1997.',
      ),
      const PublishReference(
        id: 'gnana1998',
        type: ReferenceType.journal,
        authors: ['Gnanasambandam, R.', 'Proctor, A.', 'Mathias, K.'],
        title: 'Alkaline-activated rice husk',
        year: '1998',
        importedNumber: 8,
        rawText:
            '8. Gnanasambandam, R.; Proctor, A.; Mathias, K. Alkaline-activated rice husk. 1998.',
      ),
      const PublishReference(
        id: 'johns1994',
        type: ReferenceType.journal,
        authors: ['Johns, M. M.', 'Marshall, W. E.'],
        title: 'A unique method for bleaching oil',
        year: '1994',
        importedNumber: 9,
        rawText:
            '9. Johns, M.M.; Marshall, W.E. A unique method for bleaching oil. 1994.',
      ),
      const PublishReference(
        id: 'aoac2005',
        type: ReferenceType.book,
        authors: ['AOAC'],
        title: 'Official Methods of Analysis',
        year: '2005',
        importedNumber: 10,
        rawText: '10. AOAC. Official Methods of Analysis. 18th ed. 2005.',
      ),
      const PublishReference(
        id: 'aoac1989',
        type: ReferenceType.book,
        authors: ['AOAC'],
        title: 'Official Methods of Analysis',
        year: '1989',
        importedNumber: 11,
        rawText: '11. AOAC. Official Methods of Analysis. 15th ed. 1989.',
      ),
      const PublishReference(
        id: 'pulliainen',
        type: ReferenceType.journal,
        authors: ['Pulliainen, T.', 'Wallin, H.'],
        title: 'Reduction of FFA',
        year: '1996',
        importedNumber: 12,
        rawText: '12. Pulliainen, T.; Wallin, H. Reduction of FFA. 1996.',
      ),
      const PublishReference(
        id: 'lawson',
        type: ReferenceType.journal,
        authors: ['Lawson, O.', 'Oyewumi, A.', 'Ologunagba, F.', 'Ojomo, A. O.'],
        title: 'Parameters affecting soybean oil refining',
        year: '2010',
        importedNumber: 14,
        rawText:
            '14. Lawson, O.; Oyewumi, A.; Ologunagba, F.; Ojomo, A.O. '
            'Evaluation of the parameters affecting soybean oil refining. '
            'ARPN J. Eng. Appl. Sci. 2010.',
      ),
      const PublishReference(
        id: 'boncan',
        type: ReferenceType.journal,
        authors: ['Boncan, D. A. T.'],
        title: 'Terpenes in plants',
        year: '2020',
        importedNumber: 20,
        rawText: '20. Boncan, D. A. T. Terpenes in plants. 2020.',
      ),
    ]);
    final match = BibliographyMatch(refs);
    expect(match.byNumber(14)!.authors.first, contains('Lawson'));
    expect(match.byNumber(3)!.authors.first, contains('Luthria'));
    expect(match.byAuthorYear('Lawson et al.', '2010')!.importedNumber, 14);
    expect(match.byAuthorYear('Marshall & Johns', '1996')!.importedNumber, 5);
    expect(match.byAuthorYear('Johns & Marshall', '1994')!.importedNumber, 9);
    expect(match.byAuthorYear('Official', '2005')!.importedNumber, 10);
    expect(match.byAuthorYear('Official', '1989')!.importedNumber, 11);
    expect(match.byAuthorYear('Corke, Walker, and Wrigley', '2004')!.importedNumber, 1);
    expect(match.byAuthorYear('Lee et al.', '2008')!.importedNumber, 2);
    expect(
      match.byAuthorYear('Lawson et al.', '2010')!.authors.first,
      isNot(contains('Luthria')),
    );
    expect(
      match.byAuthorYear('Lawson et al.', '2010')!.authors.first,
      isNot(contains('Boncan')),
    );

    const intro =
        'According to Corke, Walker, and Wrigley (2004) soybeans supply oil. '
        'They are used in varnishes and paints (Lee et al., 2008). '
        'They fix nitrogen (Lee et al., 2008). '
        'Bioactive compounds are reported (Selvarani et al., 2025; Mohammed et al., 2024). '
        'Metal adsorbents were studied (Marshall & Johns, 1996). '
        'According to recent studies (Johns & Marshall, 1994) rice hulls work. '
        'Commercial bleaching uses adsorbents (Proctor & Gnanasambandam, 1997). '
        'Alkaline-Activated Rice Husk (Gnanasambandam et al., 1998) is effective. '
        'Soy hull carbon (Lawson et al., 2010) was compared. '
        'One-time metal adsorbents (Official, 2005) are used. '
        'Johns, M.M., and W.E. Marshall (1994)a unique method was described. '
        'Bleaching of oil (Official, 1989) reduced color. '
        'The reduction of FFA (Pulliainen & Wallin, 1996) was measured.';

    final manuscript = PublishManuscript(
      id: 'soy-intro',
      userId: 't',
      title: 'Soybean',
      body: intro,
      bodyBlocks: [
        const ManuscriptBlock(id: 'b1', type: ManuscriptBlockType.paragraph, text: intro),
      ],
      references: refs,
      citationStyle: PublishCitationStyle.ieee,
    );

    final ieee = ManuscriptCitationHelper.resolvePlainText(
      text: intro,
      manuscript: manuscript,
      style: PublishCitationStyle.ieee,
    );
    expect(ieee, contains('[1]'), reason: 'Corke 2004 is list item 1');
    expect(ieee, contains('[2]'), reason: 'Lee 2008 is list item 2');
    expect(ieee, contains('[6,4]'), reason: 'Selvarani 2025 then Mohammed 2024');
    expect(ieee, contains('[5]'), reason: 'Marshall & Johns 1996');
    expect(ieee, contains('[9]'), reason: 'Johns & Marshall 1994');
    expect(ieee, contains('[7]'), reason: 'Proctor 1997');
    expect(ieee, contains('[8]'), reason: 'Gnanasambandam 1998');
    expect(ieee, contains('[14]'), reason: 'Lawson 2010 is list item 14');
    expect(ieee, contains('[10]'), reason: 'Official/AOAC 2005');
    expect(ieee, contains('[11]'), reason: 'Official/AOAC 1989');
    expect(ieee, contains('[12]'), reason: 'Pulliainen 1996');
    expect(ieee, isNot(contains('[3]')), reason: 'Luthria must not replace any intro cite');
    expect(ieee, isNot(contains('[20]')), reason: 'Boncan must not replace Lawson');

    final apa = ManuscriptCitationHelper.resolvePlainText(
      text: intro,
      manuscript: manuscript.copyWith(citationStyle: PublishCitationStyle.apa),
      style: PublishCitationStyle.apa,
    );
    expect(apa, contains('Corke'));
    expect(apa, contains('Lee'));
    expect(apa, contains('Lawson'));
    expect(apa, contains('Selvarani'));
    expect(apa, contains('Mohammed'));
    expect(apa, contains('Marshall'));
    expect(apa, contains('Johns'));
    expect(apa, contains('Proctor'));
    expect(apa, contains('Gnanasambandam'));
    expect(apa, contains('Pulliainen'));
    expect(apa.toLowerCase(), anyOf(contains('official'), contains('aoac')));
    expect(apa, isNot(contains('Luthria')));
    expect(apa, isNot(contains('Boncan')));
  });

  test('soybean Word list keeps all 50 numbered references in file order', () {
    const refs = r'''
1.	Wrigley, C.; Corke, H.; Walker, C.E. (Eds.). Encyclopedia of Grain Science, 1st ed.; Academic Press: Oxford, UK, 2004; Vol. 2, pp. 125-131.
2.	Gupta, S.K. Editor. Technological Innovations in Major World Oil Crops, Volume 1: Breeding, 1st ed., Springer: New York, USA; 2011; p 274. https://doi.org/10.1007/978-1-4614-0356-2
3.	Luthria, D.L.; Biswas, R.; Natarajan, S. Comparison of extraction solvents and techniques used for the assay of isoflavones from soybean. Food Chem. 2007, 105(1), 325-333. https://doi.org/10.1016/j.foodchem.2006.11.047
4.	Lee, S.J.; Kim, J.J.; Moon, H.I.; Ahn, J.K.; Chun, S.C.; Jung, W.S.; Chung, I.M. Analysis of isoflavones and phenolic compounds in Korean soybean (Glycine max (L.) Merrill) seeds of different seed weights. J. Agric. Food Chem. 2008, 56(8), 2751-2758. https://doi.org/10.1021/jf073153f
5.	Lim, T.K. Edible Medicinal and Non-Medicinal Plants, 1st ed., Springer: Dordrecht, Netherlands; 2012; Vol. 1, pp. 285-292. https://doi.org/10.1007/978-94-017-9511-1
6.	Selvarani, S.R.; Sundareswaran, S.; Manonmani, V.; Manivannan, N.; Gomathi, V.; Raja, K. The Impact of Volatile Organic Compounds on Assessing Soybean Seed Quality during Storage. Legume Res.-Int. J. 2025, 1, 8.
7.	Erickson, D.R. Editor. Practical Handbook of Soybean Processing and Utilization, 1st ed.; Elsevier: Amsterdam, Netherlands; 2015; pp. 203-217.
8.	Mohammed, J.G.; Azeez, O.S.; Uthman, H.; Aboje, A.A.; Afolabi, A. Kinetic and equilibrium studies of bleaching used palm olein oil using alkaline-activated rice husk. Egypt. J. Pet. 2024, 33(4), 9. https://doi.org/10.62593/2090-2468.1056
9.	Proctor, A.; Harris, C.D. Soy hull carbon as an adsorbent of minor crude soy oil components. J. Am. Oil Chem. Soc. 1996, 73, 527-529. https://doi.org/10.1007/BF02523931
10.	Marshall, W.E.; Johns, M.M. Agricultural by-products as metal adsorbents: sorption properties and resistance to mechanical abrasion. J. Chem. Technol. Biotechnol. 1996, 66(2), 192-198. https://doi.org/10.1002/(SICI)1097-4660(199606)66:2<192::AID-JCTB489>3.0.CO;2-C
11.	Johns, M.M.; Marshall, W.E. Metal adsorption using granular activated carbons from agricultural byproducts. In I & EC Special Symposium of the American Chemical Society, Atlanta, USA; 1994.
12.	Proctor, A.; Gnanasambandam, R. Soy hull carbon as adsorbents of crude soy oil components: Effect of carbonization time. J. Am. Oil Chem. Soc. 1997, 74, 1549-1552. https://doi.org/10.1007/s11746-997-0075-3
13.	Gnanasambandam, R.; Mathias, M.; Proctor, A. Structure and performance of soy hull carbon adsorbents as affected by pyrolysis temperature. J. Am. Oil Chem. Soc. 1998, 75, 615-621. https://doi.org/10.1007/s11746-998-0074-z
14.	Lawson, O.; Oyewumi, A.; Ologunagba, F.; Ojomo, A.O. Evaluation of the parameters affecting the solvent. ARPN J. Eng. Appl. Sci. 2010, 5(10), 51-55.
15.	AOAC. Official Methods of Analysis of the Association of Official Analytical Chemists International, 18th ed.; AOAC International: Gaithersburg, USA, 2005.
16.	Raghuramulu, N.; Madhavan, N.K.; Kalyanasundaram, S. A Manual of Laboratory Techniques; National Institute of Nutrition, Indian Council of Medical Research: Hyderabad, India, 2003; pp. 56-58.
17.	AOCS. Official Methods and Recommended Practices of the American Oil Chemists Society; American Oil Chemists Society: Champaign, USA, 1998.
18.	AOCS. Official Method AOCS Cd 8-53. Peroxide Value, In Official Methods and Recommended Practices of the American Oil Chemists Society, American Oil Chemists Society: Champaign, USA; 1989.
19.	Pulliainen, T.K.; Wallin, H.C. Determination of total phosphorus in foods by colorimetry: Summary of NMKL collaborative study. J. AOAC Int. 1996, 79(6), 1408-1410. https://doi.org/10.1093/jaoac/77.6.1557
20.	Boncan, D.A.T.; Tsang, S.S.; Li, C.; Lee, I.H.; Lam, H.M.; Chan, T.F.; Hui, J.H. Terpenes and terpenoids in plants: Interactions with environment and insects. Int. J. Mol. Sci. 2020, 21(19), 7382. https://doi.org/10.3390/ijms21197382
21.	Marei, G.I.K.; Rasoul, M.A.A.; Abdelgaleil, S.A. Comparative antifungal activities and biochemical effects of monoterpenes on plant pathogenic fungi. Pest. Biochem. Physiol. 2012, 103(1), 56-6. https://doi.org/10.1016/j.pestbp.2012.03.004
22.	Marei, G.I.; Rabea, E.I.; Badawy, M.E.I. In vitro antimicrobial and antioxidant activities of monoterpenes against some food-borne pathogens. J. Plant Prot. Pathol. 2019, 10(1), 87-94. https://dx.doi.org/10.21608/jppp.2019.40594
23.	Cutillas, A.B.; Carrasco, A.; Martinez-Gutierrez, R.; Tomas, V.; Tudela, J. Rosmarinus officinalis L. essential oils from Spain. Plant Biosyst. 2018, 152(6), 1282-1292. https://doi.org/10.1080/11263504.2018.1445129
24.	Fazmiya, M.J.A.; Sultana, A.; Rahman, K.; Heyat, M.B.B.; Sumbul, A.; Akhtar, F.; Appiah, S.C.Y. Current insights on Cinnamomum camphora Linn. Oxid. Med. Cell. Longev. 2022, 2022(1), 9354555. https://doi.org/10.1155/2022/9354555
25.	Quintans-Junior, L.; Moreira, J.C.; Pasquali, M.A.; Rabie, S.M.; Pires, A.S.; Schroder, R.; Gelain, D.P. Antinociceptive activity of monoterpenes. Int. Scholarly Res. Not. 2013, 2013(1), 45953. https://doi.org/10.1155/2013/459530
26.	Mishra, C.M.; Khalid, M.A.; Tripathi, D.T.; Mahdi, A.A. Comparative anti-diabetic study of three phytochemicals. Int. J. Biomed. Adv. Res. 2018.
27.	Eddin, L.B.; Jha, N.K.; Meeran, M.N.; Kesari, K.K.; Beiram, R.; Ojha, S. Neuroprotective potential of limonene. Molecules 2021, 26(15), 4535. https://doi.org/10.3390/molecules26154535
28.	Falk Filipsson, A.; Bard, J.; Karlsson, S. Limonene, 1st ed., World Health Organization: Geneva, Switzerland; 1998.
29.	Hirota, R.; Roger, N.N.; Nakamura, H.; Song, H.S.; Sawamura, M.; Suganuma, N. Anti-inflammatory effects of limonene from yuzu. J. Food Sci. 2010, 75(3), H87-H92. https://doi.org/10.1111/j.1750-3841.2010.01541.x
30.	Roberto, D.; Micucci, P.; Sebastian, T.; Graciela, F.; Anesini, C. Antioxidant activity of limonene. Basic Clin. Pharmacol. Toxicol. 2010, 106(1), 38-44. https://doi.org/10.1111/j.1742-7843.2009.00467.x
31.	Sell, C.; Sell, C.S. Editor. The Chemistry of Fragrances, 2nd ed., Royal Society of Chemistry: United Kingdom; 2006. DOI: 10.1039/9781847552441
32.	Burdock, G.A. Fenaroli Handbook of Flavor Ingredients, 6th ed., CRC Press: Boca Raton, FL, USA; 2016. https://doi.org/10.1201/9781439847503
33.	Carey, F.A.; Sundberg, R.J. Advanced Organic Chemistry: Part B, 5th ed., Springer US: New York, USA; 2007; Vol. 3. https://doi.org/10.1007/978-0-387-71481-3
34.	Kim, Y.S. Discrimination of cultivated regions of soybeans based on volatile metabolite profiles. Molecules 2020, 25(3), 763. https://doi.org/10.3390/molecules25030763
35.	Gonzalez-Dominguez, M.; Lopez-Guillen, G.; Cruz-Lopez, L. Volatiles from soybean flowers attract the Mexican soybean weevil. Appl. Entomol. Zool. 2024, 59, 1-11. https://doi.org/10.1007/s13355-023-00857-2
36.	Sacchetti, P.; Rossi, E.; Bellini, L.; Vernieri, P.; Cioni, P. L.; Flamini, G. Volatile organic compounds emitted by bottlebrush species. Arthropod-Plant Interact. 2015, 9, 393-403. https://doi.org/10.1007/s11829-015-9382-z
37.	Krober, O. A.; Cartter, J. L. Quantitative interrelations of protein and nonprotein constituents of soybeans. Crop Sci. 1962, 2, 171-172. https://doi.org/10.2135/cropsci1962.0011183X000200020028x
38.	Devi, U.; Mohini, K.; Kharwal, N. Proximate analysis of promising soybean genotypes developed in Himachal Pradesh. Indian J. Agric. Biochem. 2024, 37(1), 54-57. DOI: 10.5958/0974-4479.2024.00007.3
39.	Kowmudi, G.; Rashmi, V.; Anoop, K.; Krishnaveni, N.; Naveen, S. Proximate values and elemental analysis in wheat and soybean. Glob. J. Environ. Sci. Manag. 2023, 9(3), 531-544. https://doi.org/10.22034/gjesm.2023.03.11
40.	Bradley, R.L. Moisture and total solids analysis. In Food Analysis, Springer: Boston, MA, USA; 2010,85, 85-104. https://doi.org/10.1007/978-1-4419-1478-1_6
41.	Van Eys, J.E.; Offner, A.; Bach, A. Manual of Quality Analyses for Soybean Products in the Feed Industry, American Soybean Association: USA; 2004.
42.	Banerjee, J.; Shrivastava, M.K.; Singh, Y.; Amrate, P.K. Estimation of genetic divergence and proximate composition in advanced breeding lines of soybean. Environ. Ecol. 2023, 41(3C), 1960-1968. https://doi.org/10.60151/envec/VYWE5744
43.	Medic, J.; Atkinson, C.; Hurburgh, C.R. Current knowledge in soybean composition. J. Am. Oil Chem. Soc. 2014, 91, 363-384. https://doi.org/10.1007/s11746-013-2407-9
44.	Pries, R.; Jeschke, S.; Leichtle, A.; Bruchhage, K.L. Modes of action of 1,8-cineol in infections and inflammation. Metabolites 2023, 13(6), 751. https://doi.org/10.3390/metabo13060751
45.	Pandur, E.; Major, B.; Rak, T.; Sipos, K.; Csutak, A.; Horvath, G. Linalool and geraniol defend neurons from oxidative stress. Antioxidants 2024, 13(8), 91. https://doi.org/10.3390/antiox13080917
46.	Jaradat, N.; Al-Maharik, N. Fingerprinting of Stachys viticina Boiss. essential oil. Molecules 2019, 24(21), 3880. https://doi.org/10.3390/molecules24213880
47.	Lorio, R.; Celenza, G.; Petricca, S. Multi-target effects of beta-caryophyllene and carnosic acid. Antioxidants 2022, 11(6), 1199. https://doi.org/10.3390/antiox11061199
48.	Chandra, M.; Prakash, O.; Kumar, R.; Bachheti, R.K.; Bhushan, B.; Kumar, M.; Pant, A.K. beta-Selinene-rich essential oils from Callicarpa macrophylla. Medicines 2017, 4(3), 52. https://doi.org/10.3390/medicines4030052
49.	Proctor, A.; Palaniappan, S. Soy oil lutein adsorption by rice hull ash. J. Am. Oil Chem. Soc. 1989, 66(11), 1618-1621. https://doi.org/10.1007/BF02636188
50.	Leon, L.; Radovic, R. L. Interfacial chemistry and electrochemistry of carbon surfaces. In Chemistry and Physics of Carbon, Vol. 24; Thrower, P.A. (Ed.); Marcel Dekker, Inc.: New York, 1994; pp. 213-310.
''';
    const intro =
        'According to Corke, Walker, and Wrigley (2004) soybeans supply oil. '
        'They are used in varnishes and paints (Lee et al., 2008). '
        'They fix nitrogen (Lee et al., 2008). '
        'Bioactive compounds are reported (Selvarani et al., 2025; Mohammed et al., 2024). '
        'Metal adsorbents were studied (Marshall & Johns, 1996). '
        'According to recent studies (Johns & Marshall, 1994) rice hulls work. '
        'Commercial bleaching uses adsorbents (Proctor & Gnanasambandam, 1997). '
        'Alkaline-Activated Rice Husk (Gnanasambandam et al., 1998) is effective. '
        'Soy hull carbon (Lawson et al., 2010) was compared. '
        'One-time metal adsorbents (Official, 2005) are used. '
        'Johns, M.M., and W.E. Marshall (1994) a unique method was described. '
        'Bleaching of oil (Official, 1989) reduced color. '
        'The reduction of FFA (Pulliainen & Wallin, 1996) was measured. '
        'Methods used a published protocol [14] and carbohydrates [16].';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(
      'Introduction\n$intro\nReferences\n$refs',
    );
    expect(parsed.references.length, 50, reason: 'every printed 1–50 must be kept');
    expect(parsed.references.first.rawText, contains('Wrigley'));
    expect(parsed.references[3].rawText, contains('Lee'));
    expect(parsed.references[13].rawText, contains('Lawson'));
    expect(parsed.references[36].rawText, contains('Krober'));
    expect(parsed.references[37].rawText, contains('Devi'));
    expect(parsed.references.last.rawText, contains('Leon'));
    expect(
      parsed.references.map((r) => r.importedNumber).toSet(),
      containsAll([1, 14, 37, 38, 50]),
    );

    final ieee = ManuscriptCitationHelper.resolvePlainText(
      text: intro,
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Soybean',
        body: intro,
        references: parsed.references,
        citationStyle: PublishCitationStyle.ieee,
      ),
      style: PublishCitationStyle.ieee,
    );
    expect(ieee, contains('[1]'), reason: 'Corke/Wrigley 2004 is item 1');
    expect(ieee, contains('[4]'), reason: 'Lee 2008 is item 4, not 2');
    expect(ieee, contains('[6,8]'), reason: 'Selvarani 6 then Mohammed 8');
    expect(ieee, contains('[10]'));
    expect(ieee, contains('[11]'));
    expect(ieee, contains('[12]'));
    expect(ieee, contains('[13]'));
    expect(ieee, contains('[14]'));
    expect(ieee, contains('[15]'), reason: 'Official 2005 is AOAC item 15');
    expect(ieee, contains('[16]'));
    expect(ieee, contains('[18]'), reason: 'Official 1989 is AOCS item 18');
    expect(ieee, contains('[19]'));
    expect(ieee, isNot(contains('[3]')), reason: 'Luthria is 3 and is not cited here');
    expect(ieee, isNot(contains('[20]')), reason: 'Boncan is 20 and is not cited here');
  });

  test('keeps items 38-50 when Word numbering stops at 37', () {
    final numbered = [
      for (var i = 1; i <= 37; i++)
        '$i. ${String.fromCharCode(65 + (i % 26))}'
            '${String.fromCharCode(65 + ((i ~/ 26) % 26))}aa, A. '
            'Dummy soybean methods title $i. J. Test. ${1980 + i}, 1, 1-2. '
            'https://doi.org/10.1000/test$i',
    ].join('\n');
    const rest = '''
Devi, U.; Mohini, K.; Kharwal, N. Proximate analysis of soybean genotypes. Indian J. Agric. Biochem. 2024, 37(1), 54-57.
Kowmudi, G.; Rashmi, V. Proximate values in wheat and soybean. Glob. J. Environ. Sci. Manag. 2023, 9(3), 531-544.
Bradley, R.L. Moisture and total solids analysis. In Food Analysis, Springer: Boston, 2010.
Van Eys, J.E.; Offner, A.; Bach, A. Manual of Quality Analyses for Soybean Products, American Soybean Association: USA; 2004.
Banerjee, J.; Shrivastava, M.K. Estimation of genetic divergence in soybean. Environ. Ecol. 2023, 41(3C), 1960-1968.
Medic, J.; Atkinson, C.; Hurburgh, C.R. Current knowledge in soybean composition. J. Am. Oil Chem. Soc. 2014, 91, 363-384.
Pries, R.; Jeschke, S. Modes of action of cineol. Metabolites 2023, 13(6), 751.
Pandur, E.; Major, B. Linalool and geraniol defend neurons. Antioxidants 2024, 13(8), 91.
Jaradat, N.; Al-Maharik, N. Fingerprinting of Stachys viticina oil. Molecules 2019, 24(21), 3880.
Lorio, R.; Celenza, G.; Petricca, S. Multi-target effects of caryophyllene. Antioxidants 2022, 11(6), 1199.
Chandra, M.; Prakash, O. Selinene-rich essential oils. Medicines 2017, 4(3), 52.
Proctor, A.; Palaniappan, S. Soy oil lutein adsorption by rice hull ash. J. Am. Oil Chem. Soc. 1989, 66(11), 1618-1621.
Leon, L.; Radovic, R. L. Interfacial chemistry of carbon surfaces. In Chemistry and Physics of Carbon, Vol. 24; Marcel Dekker: New York, 1994; pp. 213-310.
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(
      'Introduction\nSoybean oil is useful.\nReferences\n$numbered\n$rest',
    );
    expect(parsed.references.length, 50);
    expect(parsed.references[36].rawText, contains('Dummy soybean methods title 37'));
    expect(parsed.references[37].rawText, contains('Devi'));
    expect(parsed.references.last.rawText, contains('Leon'));
  });

  test('in-text [1]-[37] are not the bibliography when the file lists 1-50', () {
    final cites = [
      for (var i = 1; i <= 37; i++)
        'The sample was measured using a published method [$i].',
    ].join(' ');
    final list = [
      for (var i = 1; i <= 50; i++)
        '$i. ${String.fromCharCode(65 + (i % 26))}'
            'zz, A. End-of-file soybean reference $i. J. Test. ${1970 + i}, 1, 1-2.',
    ].join('\n');
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(
      'Introduction\n$cites\nReferences\n$list',
    );
    expect(parsed.references.length, 50);
    expect(parsed.references.first.rawText, contains('End-of-file soybean reference 1'));
    expect(parsed.references.last.rawText, contains('End-of-file soybean reference 50'));
    expect(parsed.references.any((r) => r.rawText.contains('The sample was measured')), isFalse);
    expect(parsed.references[36].importedNumber, 37);
    expect(parsed.references.last.importedNumber, 50);
  });

  test('keeps hard bibliography rows from the start, middle, and end', () {
    const paper = '''
Introduction
Soybeans were studied (Wrigley et al., 2004). Oil was extracted (Luthria et al., 2007).
Official methods were used (Official, 2005) and compared (Official, 1989).
Volatiles were profiled (Gonzalez-Dominguez et al., 2024).
Feed quality was checked (Van Eys et al., 2004). Carbon surfaces were reviewed (Leon and Radovic, 1994).
References
1. Wrigley, C.; Corke, H.; Walker, C.E. (Eds.). Encyclopedia of Grain Science, 1st ed.; Academic Press: Oxford, UK, 2004.
2. Gupta, S.K. Editor. Technological Innovations in Major World Oil Crops, Springer: New York, USA; 2011.
3. Luthria, D.L.; Biswas, R.; Natarajan, S. Comparison of extraction solvents. Food Chem. 2007, 105(1), 325-333.
Falk Filipsson, A.; Bard, J.; Karlsson, S. Limonene, 1st ed., World Health Organization: Geneva, Switzerland; 1998.
15. AOAC. Official Methods of Analysis of the Association of Official Analytical Chemists International, 18th ed.; AOAC International: Gaithersburg, USA, 2005.
18. AOCS. Official Method AOCS Cd 8-53. Peroxide Value, In Official Methods and Recommended Practices; Champaign, USA; 1989.
Gonzalez-Dominguez, M.; Lopez-Guillen, G.; Cruz-Lopez, L. Volatiles from soybean flowers. Appl. Entomol. Zool. 2024, 59, 1-11.
Van Eys, J.E.; Offner, A.; Bach, A. Manual of Quality Analyses for Soybean Products in the Feed Industry, American Soybean Association: USA; 2004.
Bradley, R.L. Moisture and total solids analysis. In Food Analysis, Springer: Boston, MA, USA; 2010, 85-104.
50. Leon, L.; Radovic, R. L. Interfacial chemistry and electrochemistry of carbon surfaces. In Chemistry and Physics of Carbon, Vol. 24; Marcel Dekker, Inc.: New York, 1994; pp. 213-310.
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    final blob = parsed.references.map((r) => r.rawText).join('\n');
    expect(blob, contains('Wrigley'));
    expect(blob, contains('Gupta'));
    expect(blob, contains('Luthria'));
    expect(blob, contains('Filipsson'));
    expect(blob, contains('AOAC'));
    expect(blob, contains('Cd 8-53'));
    expect(blob, contains('Gonzalez-Dominguez'));
    expect(blob, contains('Van Eys'));
    expect(blob, contains('Bradley'));
    expect(blob, contains('Leon'));
    expect(parsed.references.length, greaterThanOrEqualTo(10));
    expect(
      parsed.references.where((r) => r.rawText.contains('Wrigley')).length,
      1,
    );
    expect(
      parsed.references.where((r) => r.rawText.contains('Leon')).length,
      1,
    );
  });

  test('in-text names and numbers recover the matching end-list works', () {
    const paper = '''
Introduction
Oil was extracted (Luthria et al., 2007). Volatiles were profiled (González-Domínguez et al., 2024).
Feed quality was checked (Van Eys et al., 2004). The same numbered list is cited as [14] and [35].
Methods used [3] and [50] from the printed list.
References
1. Wrigley, C.; Corke, H.; Walker, C.E. (Eds.). Encyclopedia of Grain Science, 2004.
3. Luthria, D.L.; Biswas, R.; Natarajan, S. Comparison of extraction solvents. Food Chem. 2007, 105(1), 325-333. González-Domínguez, M.; López-Guillén, G.; Cruz-López, L. Volatiles from soybean flowers. Appl. Entomol. Zool. 2024, 59, 1-11.
14. Lawson, T.; Grygier, A.; Czubinski, J. A technique. Food Chem. 2010, 120, 1-8.
Van Eys, J.E.; Offner, A.; Bach, A. Manual of Quality Analyses for Soybean Products in the Feed Industry, American Soybean Association: USA; 2004.
35. Gonzalez-Dominguez, M.; Lopez-Guillen, G. Duplicate title should not steal 35 if 3 already split. J. Dummy. 2011, 1, 1-2.
50. Leon, L.; Radovic, R. L. Interfacial chemistry and electrochemistry of carbon surfaces. 1994; pp. 213-310.
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    final blob = parsed.references.map((r) => r.rawText).join('\n---\n');
    expect(blob, contains('Luthria'));
    expect(blob, contains('González-Domínguez'));
    expect(blob, contains('Van Eys'));
    expect(blob, contains('Lawson'));
    expect(blob, contains('Leon'));
    expect(
      parsed.references.where((r) => r.rawText.contains('Luthria')).length,
      1,
    );
    expect(
      parsed.references.any((r) =>
          r.rawText.contains('González-Domínguez') &&
          !r.rawText.contains('Luthria')),
      isTrue,
      reason: 'González must be its own list row, not glued onto Luthria',
    );
    final match = BibliographyMatch(parsed.references);
    expect(match.byAuthorYear('Luthria', '2007')?.importedNumber, 3);
    expect(match.byNumber(14)?.rawText, contains('Lawson'));
    expect(match.byNumber(50)?.rawText, contains('Leon'));
    expect(match.byAuthorYear('Van Eys', '2004'), isNotNull);
    expect(match.byAuthorYear('González-Domínguez', '2024'), isNotNull);

    final linked = CitationLinker.linkTextWithRefs(
      'extracted (Luthria et al., 2007) and [14] and (Van Eys et al., 2004).',
      parsed.references,
    );
    final ieee = ManuscriptCitationHelper.resolvePlainText(
      text: linked,
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Soybean',
        body: linked,
        references: parsed.references,
        citationStyle: PublishCitationStyle.ieee,
      ),
      style: PublishCitationStyle.ieee,
    );
    expect(ieee, contains('[3]'), reason: 'Luthria 2007 is list item 3');
    expect(ieee, contains('[14]'), reason: '[14] is Lawson');
    expect(ieee, contains('[15]'), reason: 'Van Eys is the unnumbered row after 14');
  });

  test('wraps author-year cites that include initials', () {
    final wrapped = CitationLinker.wrapInnerCitationPatterns(
      'alcohols (Matheis, K., & Granvogl, M. 2016) were quantified.',
    );
    expect(wrapped, contains(CitationLinker.hintOpen));
    expect(wrapped, contains('Matheis, K.'));
  });

  test('IEEE list keeps APA authors instead of quoting leftover names', () {
    const aiderRaw =
        'Aider, M., and Barbana, C. (2011). Canola proteins: composition '
        'and isolation. Trends in Food Science and Technology, 22(1), 21-39. '
        'doi: 10.1016/j.tifs.2010.11.002.';
    const shahidiRaw =
        'Shahidi, F. (Ed.). (1990). Canola and rapeseed: production, '
        'chemistry, nutrition. Van Nostrand.';
    const alhomodiRaw =
        'Alhomodi, A. F., Zavadil, A., Berhow, M., Gibbons, W. R., and '
        'Karki, B. (2021). Protein from canola. Food and Bioproducts '
        'Processing, 127, 256-264. doi: 10.1016/j.fbp.2021.01.008.';

    for (final raw in [aiderRaw, shahidiRaw, alhomodiRaw]) {
      final parsed = CitationFormatter.parseBibliographicLine(raw);
      expect(parsed, isNotNull, reason: raw);
      final entry = CitationFormatter.buildBibliographyEntry(
        reference: parsed!.copyWith(id: 'r', rawText: raw),
        style: PublishCitationStyle.ieee,
        index: 1,
      );
      expect(entry.plain, startsWith('[1] '));
      expect(entry.plain, isNot(contains('", ')));
      expect(entry.plain, isNot(contains('(,')));
      expect(entry.plain, isNot(contains('no. 1990')));
      expect(entry.plain, isNot(contains('no. 2021')));
      expect(entry.plain, isNot(contains('no. 2011')));
    }

    final aider = CitationFormatter.buildBibliographyEntry(
      reference: CitationFormatter.parseBibliographicLine(aiderRaw)!
          .copyWith(id: 'aider', rawText: aiderRaw),
      style: PublishCitationStyle.ieee,
      index: 1,
    );
    expect(aider.plain.toLowerCase(), contains('aider'));
    expect(aider.plain.toLowerCase(), contains('barbana'));
    expect(aider.plain.toLowerCase(), contains('canola proteins'));
  });

  test('affiliation Egypt[1] at end of university line is not a citation', () {
    const affiliation =
        '.Chemistry Department, Faculty of Science, Zagazig University, '
        'Zagazig, Egypt[1]';
    expect(
      DocxScientificExtractor.isFrontMatterAuthorText(affiliation),
      isTrue,
    );
    expect(
      DocxScientificExtractor.looksLikeAffiliationBracket(
        affiliation,
        affiliation.indexOf('['),
      ),
      isTrue,
    );

    final linked = CitationLinker.linkTextWithRefs(
      affiliation,
      const [
        PublishReference(
          id: 'ref_1',
          type: ReferenceType.journal,
          authors: ['Aider, M.'],
          title: 'Canola',
          year: '2011',
          rawText: 'Aider, M. (2011). Canola.',
        ),
      ],
    );
    expect(linked, contains('Egypt[1]'));
    expect(linked, isNot(contains('{{cite:')));
  });

  test('semicolon group including Wanasundara Janitha is fully replaced', () {
    final refs = [
      const PublishReference(
        id: 'shahidi',
        type: ReferenceType.book,
        authors: ['Shahidi, F.'],
        title: 'Canola and rapeseed',
        year: '1990',
        rawText: 'Shahidi, F. (Ed.). (1990). Canola and rapeseed.',
      ),
      const PublishReference(
        id: 'aider',
        type: ReferenceType.journal,
        authors: ['Aider, M.', 'Barbana, C.'],
        title: 'Canola proteins',
        year: '2011',
        rawText: 'Aider, M., and Barbana, C. (2011). Canola proteins.',
      ),
      const PublishReference(
        id: 'wana',
        type: ReferenceType.journal,
        authors: ['Wanasundara, Janitha P.D.', 'McIntosh, T.', 'Perera, S.'],
        title: 'Canola/rapeseed protein',
        year: '2016',
        rawText:
            'Wanasundara, Janitha P.D., McIntosh, T., and Perera, S. (2016). '
            'Canola/rapeseed protein.',
      ),
    ];
    const sentence =
        'It is suited for human consumption (Shahidi, F. Ed. 1990; '
        'Aider, M. and Barbana, C., 2011; Wanasundara, Janitha PD, et al 2016).';
    final linked = CitationLinker.linkTextWithRefs(sentence, refs);
    expect(linked, contains('{{cite:shahidi}}'));
    expect(linked, contains('{{cite:aider}}'));
    expect(linked, contains('{{cite:wana}}'));
    expect(linked, isNot(contains('Wanasundara, Janitha')));
    expect(linked, isNot(contains('2016)')));

    final ieee = ManuscriptCitationHelper.resolvePlainText(
      text: linked,
      manuscript: PublishManuscript(
        userId: 'u',
        title: 't',
        body: linked,
        references: refs,
        citationStyle: PublishCitationStyle.ieee,
      ),
      style: PublishCitationStyle.ieee,
    );
    expect(ieee, contains('['));
    expect(ieee, isNot(contains('Wanasundara')));
    expect(ieee, isNot(contains('[2, 1] Wanasundara')));
  });

  test('Introduction APA groups become IEEE numbers, authors stay authors', () {
    const paper = '''
Khaled Elgendy ¹*, Mounir Zaky ¹, and Ahmed Salawy Mohammed ¹
.Chemistry Department, Faculty of Science, Zagazig University, Zagazig, Egypt[1]
Corresponding author: elgendykh64@hotmail.com ; (+20 01005169453)*

Introduction
The crop produces a large amount of oil (Daun, J. K., Eskin, N.A., and Hickling, D. 2011).
This enhances its appeal (Carrer and Pouzet 2014; Von Der Haar et al. 2014; Rodrigues et al. 2012; Mupondwa, Li, and Wanasundara 2018).
Many processors primarily rely on canola (Rodrigues et al. 2012; CCC 2015; Wanasundara et al. 2016).
It is suited for human consumption (Shahidi, F. Ed. 1990; Aider, M. and Barbana, C., 2011; Wanasundara, Janitha PD, et al 2016).

References
Daun, J. K., Eskin, N. A., and Hickling, D. (2011). Canola: chemistry, production, processing and utilization. AOCS Press.
Carrer, P., and Pouzet, A. (2014). Rapeseed market, worldwide and in Europe. OCL, 21(1), D102.
Von Der Haar, D., Muller, K., and Bader, S. (2014). Rapeseed proteins for food. European Food Research and Technology, 239, 1-10.
Rodrigues, I. M., Coelho, J. F., and Carvalho, M. G. (2012). Isolation and valorisation of vegetable proteins. Food Research International, 47, 1-12.
Mupondwa, E., Li, X., and Wanasundara, J. (2018). Integrated processing of canola. Journal of the American Oil Chemists Society, 95, 1-15.
CCC. (2015). Canola Council of Canada annual report. Winnipeg.
Shahidi, F. (Ed.). (1990). Canola and rapeseed: production, chemistry, nutrition. Van Nostrand.
Aider, M., and Barbana, C. (2011). Canola proteins: composition and isolation. Trends in Food Science and Technology, 22, 21-39.
Wanasundara, Janitha P.D., McIntosh, T., and Perera, S. (2016). Canola/rapeseed protein. Journal of the American Oil Chemists Society, 93, 1-20.
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    expect(parsed.references.any((r) => r.rawText.contains('Khaled')), isFalse);
    expect(parsed.references.any((r) => r.rawText.contains('Egypt')), isFalse);

    final ieee = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Rapeseed',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      style: PublishCitationStyle.ieee,
    );
    final body = ieee.bodyBlocks.map((b) => b.text).join('\n');
    expect(body, isNot(contains('Daun, J. K.')));
    expect(body, isNot(contains('Carrer and Pouzet 2014')));
    expect(body, isNot(contains('Wanasundara, Janitha')));
    expect(body, contains('Egypt[1]'));

    final preview = ManuscriptCitationHelper.resolvePlainText(
      text: ieee.bodyBlocks.map((b) => b.text).join('\n'),
      manuscript: ieee,
      style: PublishCitationStyle.ieee,
    );
    expect(preview, isNot(contains('Daun, J. K.')));
    expect(preview, isNot(contains('Wanasundara, Janitha')));

    final bib = CitationFormatter.formatBibliography(
      references: ieee.references,
      style: PublishCitationStyle.ieee,
    );
    expect(bib, isNot(contains('", Barbana')));
    expect(bib, isNot(contains('no. 1990')));
    expect(bib, isNot(contains('(,')));
  });

  test('title page authors stay authors even when mixed with the paper title', () {
    const titlePage =
        'Comprehensive Volatile Profile and Proximate Composition Analysis '
        'of Rapeseed using Headspace Gas Chromatography-Mass Spectrometry '
        'Khaled Elgendy ¹*, Mounir Zaky ¹, and Ahmed Salawy Mohammed ¹ '
        '.Chemistry Department, Faculty of Science, Zagazig University, '
        'Zagazig, Egypt[1] '
        'Corresponding author: elgendykh64@hotmail.com ; (+20 01005169453)*';
    expect(DocxScientificExtractor.isFrontMatterAuthorText(titlePage), isTrue);

    final refs = [
      const PublishReference(
        id: 'ref_1',
        type: ReferenceType.journal,
        authors: ['Aider, M.', 'Barbana, C.'],
        title: 'Canola proteins',
        year: '2011',
        rawText: '[1] Aider, M. (2011). Canola proteins.',
      ),
    ];
    final ieee = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Rapeseed',
        bodyBlocks: [
          ManuscriptBlock(
            id: 'title',
            type: ManuscriptBlockType.paragraph,
            text: titlePage,
          ),
          ManuscriptBlock(
            id: 'abs',
            type: ManuscriptBlockType.heading,
            text: 'Abstract',
          ),
          ManuscriptBlock(
            id: 'intro',
            type: ManuscriptBlockType.heading,
            text: 'Introduction',
          ),
          ManuscriptBlock(
            id: 'p1',
            type: ManuscriptBlockType.paragraph,
            text: 'The crop produces oil (Aider, M. and Barbana, C., 2011).',
          ),
        ],
        references: refs,
      ),
      style: PublishCitationStyle.ieee,
    );
    final title = ieee.bodyBlocks.firstWhere((b) => b.id == 'title').text;
    expect(title, contains('Egypt[1]'));
    expect(title, contains('Khaled Elgendy'));
    expect(title, isNot(contains('{{cite:')));
    expect(ieee.references.any((r) => r.rawText.contains('Khaled')), isFalse);
    expect(
      ieee.bodyBlocks.firstWhere((b) => b.id == 'p1').text,
      contains('[1]'),
    );
    expect(
      ieee.bodyBlocks.firstWhere((b) => b.id == 'p1').text,
      isNot(contains('Aider, M.')),
    );
  });

  test('Daun cite and leftover Wanasundara after [6, 1] both link', () {
    final refs = [
      const PublishReference(
        id: 'daun',
        type: ReferenceType.book,
        authors: ['Daun, J. K.', 'Eskin, N. A.', 'Hickling, D.'],
        title: 'Canola',
        year: '2011',
        rawText: 'Daun, J. K., Eskin, N. A., and Hickling, D. (2011). Canola.',
      ),
      const PublishReference(
        id: 'aider',
        type: ReferenceType.journal,
        authors: ['Aider, M.', 'Barbana, C.'],
        title: 'Canola proteins',
        year: '2011',
        rawText: 'Aider, M., and Barbana, C. (2011). Canola proteins.',
      ),
      const PublishReference(
        id: 'wana',
        type: ReferenceType.journal,
        authors: ['Wanasundara, Janitha P.D.'],
        title: 'Canola/rapeseed protein',
        year: '2016',
        rawText: 'Wanasundara, Janitha P.D. (2016). Canola/rapeseed protein.',
      ),
    ];
    const body =
        'The crop produces a large amount of oil (Daun, J. K., Eskin, N.A., '
        'and Hickling, D. 2011). '
        'It is suited for human consumption [6, 1] Wanasundara, Janitha PD, '
        'et al 2016).';
    final linked = CitationLinker.linkTextWithRefs(body, refs);
    expect(linked, contains('{{cite:daun}}'));
    expect(linked, contains('{{cite:wana}}'));
    expect(linked, isNot(contains('Daun, J. K.')));
    expect(linked, isNot(contains('Wanasundara, Janitha')));
  });

  test('same author and year keeps both works and still links each cite', () {
    final refs = [
      const PublishReference(
        id: 'wana_a',
        type: ReferenceType.journal,
        authors: ['Wanasundara, J. P. D.'],
        title: 'Canola/rapeseed protein: future opportunities',
        year: '2016',
        rawText:
            'Wanasundara, J. P. D. (2016). Canola/rapeseed protein: future '
            'opportunities. JAOCS, 93, 1-20.',
      ),
      const PublishReference(
        id: 'wana_b',
        type: ReferenceType.journal,
        authors: ['Wanasundara, Janitha P.D.', 'McIntosh, T.', 'Perera, S.'],
        title: 'Proteins from canola/rapeseed',
        year: '2016',
        rawText:
            'Wanasundara, Janitha P.D., McIntosh, T., and Perera, S. (2016). '
            'Proteins from canola/rapeseed. JAOCS, 93, 21-40.',
      ),
    ];
    final linked = CitationLinker.linkTextWithRefs(
      'First (Wanasundara et al. 2016) then later '
      '(Wanasundara, Janitha PD, McIntosh, T. 2016).',
      refs,
    );
    expect(linked, contains('{{cite:wana_a}}'));
    expect(linked, contains('{{cite:wana_b}}'));
    expect(linked, isNot(contains('Wanasundara et al')));

    final samePaperTwice = CitationLinker.dedupe([
      refs[0],
      refs[0].copyWith(
        id: 'wana_dup',
        rawText: 'Wanasundara, J. P. D. (2016). Canola/rapeseed protein: future '
            'opportunities. Journal of the American Oil Chemists Society.',
      ),
    ]);
    expect(samePaperTwice.length, 1);
  });

  test('IEEE [1] stays the first bibliography entry when converting to APA', () {
    const paper = '''
Introduction
The crop produces oil [1]. Later work used proteins [2] and a journal study [3].
References
[1] F. Shahidi, Canola and rapeseed: production, chemistry, nutrition. Van Nostrand, 1990.
[2] J. K. Daun, N. A. Eskin, and D. Hickling, Canola: chemistry, production, processing and utilization. AOCS Press, 2011.
[3] M. Aider and C. Barbana, "Canola proteins: composition and isolation," Trends in Food Science and Technology, vol. 22, pp. 21-39, 2011.
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    expect(parsed.references.length, greaterThanOrEqualTo(3));
    expect(parsed.references.first.rawText, contains('Shahidi'));
    expect(parsed.references[1].rawText, contains('Daun'));
    expect(parsed.references[2].rawText, contains('Aider'));

    final apa = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Rapeseed',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      style: PublishCitationStyle.apa,
    );
    final body = apa.bodyBlocks.map((b) => b.text).join('\n');
    final preview = ManuscriptCitationHelper.resolvePlainText(
      text: body,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(body, contains('Shahidi'));
    expect(preview, contains('Shahidi'));
    expect(preview, contains('1990'));
    expect(
      preview,
      startsWith('Introduction\nThe crop produces oil (Shahidi, 1990)'),
    );
    expect(preview, contains('(Aider & Barbana, 2011)'));
    expect(
      preview.indexOf('Shahidi'),
      lessThan(preview.indexOf('Aider')),
    );
  });

  test('tables stay after Conclusion when that is the file order', () {
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest('''
Introduction
Rapeseed is an oilseed crop.
Results
Protein content reached 22%.
Conclusion
The crop is useful for nutrition.
Table 1. Proximate composition of rapeseed
References
[1] M. Aider and C. Barbana, "Canola proteins," Food Chem., vol. 22, pp. 21-39, 2011.
''');
    final labels = parsed.bodyBlocks
        .map((b) => b.type == ManuscriptBlockType.heading
            ? b.text
            : (b.caption ?? b.text))
        .toList();
    final conclusionAt = labels.indexWhere((t) => t == 'Conclusion');
    final tableAt = labels.indexWhere(
      (t) => t.toLowerCase().contains('table 1'),
    );
    expect(conclusionAt, greaterThan(0));
    expect(tableAt, greaterThan(0));
    expect(tableAt, greaterThan(conclusionAt));
  });

  test('ACS bibliography lines are removed from the body and kept in the list', () {
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest('''
Abstract
Soybean composition is reviewed.
Introduction
Limonene occurs in plants (Falk Filipsson et al., 1998).
Protein and oil are related (Krober and Cartter, 1962).
Conclusion
Soybean remains an important crop.
Falk Filipsson, A.; Bard, J.; Karlsson, S. Limonene, 1st ed., World Health Organization: Geneva, Switzerland; 1998
Burdock, G.A. Fenaroli's Handbook of Flavor Ingredients, 6th ed., CRC Press: Boca Raton, FL, USA; 2016. https://doi.org/10.1201/9780429089947
Carey, F.A.; Sundberg, R.J. Advanced Organic Chemistry, 5th ed., Springer: New York, NY, USA; 2007
Krober, O. A.; Cartter, J. L. Quantitative interrelations of protein and nonprotein constituents of soybeans. Crop Sci. 1962, 2, 171-172. https://doi.org/10.2135/cropsci1962.0011183X000200020028x
Bradley, R.L. Moisture and Total Solids Analysis. In Food Analysis; Springer: Boston, MA, USA, 2010. https://doi.org/10.1007/978-1-4419-1478-1_6
Medic, J.; Atkinson, C.; Hurburgh, C.R. Current Knowledge in Soybean Composition. J. Am. Oil Chem. Soc. 2014, 91, 363-370. https://doi.org/10.1007/s11746-013-2407-9
Proctor, A.; Palaniappan, S. Soy oil lutein isomerization. J. Am. Oil Chem. Soc. 1989, 66, 121-124. https://doi.org/10.1007/BF02661805
References
Banerjee, J., Shrivastava, M.K., Singh, Y., & Amrate, P.K. (2023). Estimation of genetic divergence in soybean. Environ. Ecol. 41, 1-8. https://doi.org/10.53550/EEC.2023.v41i01.001
Boncan, D.A.T., Tsang, S.S., Li, C., Lee, I.H., Lam, H.M., Chan, T.F., & Hui, J.H. (2020). Terpenes and terpenoids in plants. Int. J. Mol. Sci. 21, 7382. https://doi.org/10.3390/ijms21197382
''');
    final body = parsed.bodyBlocks.map((b) => b.text).join('\n');
    expect(body, isNot(contains('World Health Organization')));
    expect(body, isNot(contains("Fenaroli's Handbook")));
    expect(body, isNot(contains('Advanced Organic Chemistry')));
    expect(body, isNot(contains('Current Knowledge in Soybean')));
    expect(body, isNot(contains('Estimation of genetic divergence')));
    expect(body, contains('Limonene occurs in plants'));
    expect(parsed.references.length, greaterThanOrEqualTo(9));
    expect(parsed.references.first.rawText, contains('Filipsson'));
    expect(parsed.references[3].rawText, contains('Krober'));
    expect(parsed.references.last.rawText, contains('Boncan'));
    expect(
      parsed.references.any((r) => r.rawText.contains('Banerjee')),
      isTrue,
    );

    final ieee = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Soybean',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      style: PublishCitationStyle.ieee,
    );
    expect(ieee.references.length, parsed.references.length);
    expect(ieee.references.first.rawText, contains('Filipsson'));
    final preview = ManuscriptCitationHelper.resolvePlainText(
      text: ieee.bodyBlocks.map((b) => b.text).join('\n'),
      manuscript: ieee,
      style: PublishCitationStyle.ieee,
    );
    expect(preview, contains('[1]'));
    expect(preview, contains('[4]'));
    expect(preview, isNot(contains('Falk Filipsson et al')));
    expect(
      preview,
      contains('Limonene occurs in plants [1]'),
    );
    expect(preview, contains('Protein and oil are related [4]'));
  });

  test('REFERENCES heading and AOAC/AOCS manuals stay in the bibliography', () {
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest('''
Abstract
Soybean oil was analyzed.
Introduction
Official methods were used (AOAC, 2005).
Conclusion
The methods are reliable.
Conflicts of interest
The authors have no conflicts of interest
AOAC. Official Methods of Analysis of the Association of Official Analytical Chemists International, 18th ed.; AOAC International: Gaithersburg, USA, 2005
AOCS. Official Methods and Recommended Practices of the American Oil Chemists Society, American Oil Chemists Society: Champaign, USA, 1998
AOCS. Official Method AOCS Cd 8-53. Peroxide Value, In Official Methods and Recommended Practices of the American Oil Chemists Society, American Oil Chemists Society: Champaign, USA; 1989
REFERENCES
1. Wrigley, C.; Corke, H.; Walker, C.E. (Eds.). Encyclopedia of Grain Science. Elsevier: Oxford, UK, 2004.
2. Gupta, S.K. Technological Innovations in Major World Oil Crops. Springer: New York, 2011. https://doi.org/10.1007/978-1-4614-0827-7
3. Luthria, D.L.; Biswas, R.; Natarajan, S. Comparison of extraction solvents for isoflavones. Food Chem. 2007, 105, 325-333. https://doi.org/10.1016/j.foodchem.2006.11.047
''');
    final body = parsed.bodyBlocks.map((b) => b.text).join('\n');
    expect(body.toLowerCase(), contains('conflicts of interest'));
    expect(body, contains('The authors have no conflicts of interest'));
    expect(body, isNot(contains('Gaithersburg')));
    expect(body, isNot(contains('Cd 8-53')));
    expect(body, isNot(contains('Encyclopedia of Grain Science')));
    expect(
      parsed.references.any((r) => r.rawText.contains('AOAC')),
      isTrue,
    );
    expect(
      parsed.references.where((r) => r.rawText.contains('AOCS')).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      parsed.references.any((r) => r.rawText.contains('Wrigley')),
      isTrue,
    );
  });

  test('file order is kept: captions stay where the file put them', () {
    expect(
      ScholarlyLayout.isFloatCaption(
        '.Fig. 1 FTIR spectrum of the prepared adsorbent.',
      ),
      isTrue,
    );
    expect(
      ScholarlyLayout.isArticleTitle(
        '.Fig. 1 FTIR spectrum of the prepared adsorbent.',
      ),
      isFalse,
    );
    expect(
      ScholarlyLayout.isArticleTitle(
        'Thermal Adsorption Kinetics of a Prepared Material: A Study on Isotherms',
      ),
      isTrue,
    );
    expect(
      ScholarlyLayout.isAuthorByline(
        'Author One¹*, Author Two1, and Author Three1',
      ),
      isTrue,
    );
    expect(
      ScholarlyLayout.isAffiliationLine(
        '1Department of Chemistry, Faculty of Science, Example University',
      ),
      isTrue,
    );

    final laidOut = ManuscriptDocumentParser.restoreJournalReadingOrder([
      const ManuscriptBlock(
        id: 'fig',
        type: ManuscriptBlockType.paragraph,
        text: '.Fig. 1 FTIR spectrum of the prepared adsorbent.',
      ),
      const ManuscriptBlock(
        id: 'title',
        type: ManuscriptBlockType.heading,
        text:
            'Thermal Adsorption Kinetics of a Prepared Material: A Study on Isotherms',
      ),
      const ManuscriptBlock(
        id: 'authors',
        type: ManuscriptBlockType.paragraph,
        text: 'Author One¹*, Author Two1, and Author Three1',
      ),
      const ManuscriptBlock(
        id: 'aff',
        type: ManuscriptBlockType.paragraph,
        text: '1Department of Chemistry, Faculty of Science, Example University',
      ),
      const ManuscriptBlock(
        id: 'abs_h',
        type: ManuscriptBlockType.heading,
        text: 'Abstract',
      ),
      const ManuscriptBlock(
        id: 'abs',
        type: ManuscriptBlockType.paragraph,
        text: 'This work reports adsorption of metal ions onto a treated biomass.',
      ),
      const ManuscriptBlock(
        id: 'intro_h',
        type: ManuscriptBlockType.heading,
        text: 'Introduction',
      ),
      const ManuscriptBlock(
        id: 'intro',
        type: ManuscriptBlockType.paragraph,
        text:
            'The contamination of water sources by heavy metals poses a concern (Smith, 2015).',
      ),
      const ManuscriptBlock(
        id: 'res_h',
        type: ManuscriptBlockType.heading,
        text: 'Results',
      ),
      const ManuscriptBlock(
        id: 'res',
        type: ManuscriptBlockType.paragraph,
        text: 'Capacity decreased as treatment temperature increased.',
      ),
      const ManuscriptBlock(
        id: 'ref_h',
        type: ManuscriptBlockType.heading,
        text: 'References',
      ),
    ]);
    final texts = laidOut.map((b) => b.text).toList();
    final figAt = texts.indexWhere(ScholarlyLayout.isFloatCaption);
    final titleAt = texts.indexWhere(ScholarlyLayout.isArticleTitle);
    expect(figAt, greaterThanOrEqualTo(0));
    expect(titleAt, greaterThanOrEqualTo(0));
    expect(figAt, lessThan(titleAt));
  });

  test('file order: caption glued onto the title is split and kept in place', () {
    final merged = ManuscriptDocumentParser.mergeSectionParagraphs([
      const ManuscriptBlock(
        id: 'a',
        type: ManuscriptBlockType.paragraph,
        text: '.Fig. 1 FTIR spectrum of the prepared adsorbent loaded with metals.',
      ),
      const ManuscriptBlock(
        id: 'b',
        type: ManuscriptBlockType.paragraph,
        text:
            'Thermal Adsorption Kinetics of a Prepared Material: A Study on Isotherms',
      ),
      const ManuscriptBlock(
        id: 'c',
        type: ManuscriptBlockType.heading,
        text: 'Results',
      ),
      const ManuscriptBlock(
        id: 'd',
        type: ManuscriptBlockType.paragraph,
        text: 'Adsorption followed the Langmuir model.',
      ),
    ]);
    final laidOut = ManuscriptDocumentParser.restoreJournalReadingOrder(merged);
    final texts = laidOut.map((b) => b.text).toList();
    expect(texts.where(ScholarlyLayout.isFloatCaption), isNotEmpty);
    final figAt = texts.indexWhere(ScholarlyLayout.isFloatCaption);
    final titleAt = texts.indexWhere(ScholarlyLayout.isArticleTitle);
    expect(titleAt, greaterThanOrEqualTo(0));
    expect(figAt, lessThan(titleAt));
  });

  test('APA in-text never prints a year-only parenthesis when names exist', () {
    const ref = PublishReference(
      id: 'ref_1',
      type: ReferenceType.journal,
      authors: [],
      title: 'Article title',
      year: '2015',
      rawText: 'Smith, J. (2015). Article title. Journal of Example, 1, 1-8.',
    );
    final formatted = CitationFormatter.formatInText(
      reference: ref,
      style: PublishCitationStyle.apa,
      index: 1,
    );
    expect(formatted, isNot(equals('(2015)')));
    expect(formatted, contains('Smith'));
    expect(formatted, contains('2015'));
  });

  test('section titles stay as printed, including Background and Effect of pH', () {
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest('''
Background
Heavy metals contaminate water sources.
Effect of pH
Surface charge changes with pH.
Instruments
A spectrometer was used.
References
1. Smith, J. (2015). Article title. Journal, 1, 1-8.
''');
    final headings = parsed.bodyBlocks
        .where((b) => b.type == ManuscriptBlockType.heading)
        .map((b) => b.text.trim())
        .toList();
    expect(headings, contains('Background'));
    expect(headings, isNot(contains('Introduction')));
    expect(headings, contains('Effect of pH'));
  });

  test('two-letter tokens are not used as author surnames in IEEE or APA', () {
    const ref = PublishReference(
      id: 'ref_4',
      type: ReferenceType.journal,
      authors: ['LB, R. A.', 'LM, C. M.', 'AM, F. J.'],
      title: 'Adsorption of metal ions onto treated biomass',
      year: '2018',
      volume: '20',
      pages: '633-642',
      rawText:
          'Dotto, G. L., Lima, E. C., & Pinto, I. A. (2018). '
          'Adsorption of metal ions onto treated biomass. '
          'Braz J Poult Sci, 20, 633-642. https://doi.org/10.1590/example',
    );
    final ieee = CitationFormatter.buildBibliographyEntry(
      reference: ref,
      style: PublishCitationStyle.ieee,
      index: 4,
    );
    expect(ieee.plain, isNot(contains('R. A. LB')));
    expect(ieee.plain, isNot(contains('LB, R')));
    expect(ieee.plain, contains('Dotto'));
    final apa = CitationFormatter.formatInText(
      reference: ref,
      style: PublishCitationStyle.apa,
      index: 4,
    );
    expect(apa, isNot(contains('(LB')));
    expect(apa, contains('Dotto'));
  });

  test('Vancouver compact initials keep the family name in APA in-text', () {
    const ref = PublishReference(
      id: 'ref_6',
      type: ReferenceType.journal,
      authors: ['Jia L', 'Chen E', 'Su H', 'Tan T'],
      title: 'Adsorption of Pb(II)',
      year: '2011',
      rawText: 'Jia L, Chen E, Su H, Tan T (2011) Adsorption of Pb(II). J Hazard Mater.',
    );
    final apa = CitationFormatter.formatInText(
      reference: ref,
      style: PublishCitationStyle.apa,
      index: 6,
    );
    expect(apa, contains('Jia'));
    expect(apa, isNot(contains('(L ')));
    expect(apa, isNot(contains('(L et')));
    final ieee = CitationFormatter.buildBibliographyEntry(
      reference: ref,
      style: PublishCitationStyle.ieee,
      index: 6,
    );
    expect(ieee.plain, contains('Jia'));
    expect(ieee.plain, isNot(contains('R. A. LB')));
  });

  test('superscript powers are not turned into (Service, 2017)', () {
    const service = PublishReference(
      id: 'ref_2',
      type: ReferenceType.journal,
      authors: ['Service, R.'],
      title: 'Other work',
      year: '2017',
      importedNumber: 2,
      rawText: '[2] R. Service, "Other work," Science, 2017.',
    );
    expect(
      CitationLinker.looksLikeMathExponent('2', 'mol'),
      isTrue,
    );
    expect(
      CitationLinker.looksLikeMathExponent('2', 'R'),
      isTrue,
    );
    expect(
      CitationLinker.applyHintWrap('2', inBody: true, before: 'mol'),
      '²',
    );
    final linked = CitationLinker.linkTextWithRefs(
      'The constant is mol${CitationLinker.hintOpen}2${CitationLinker.hintClose}/'
      'kJ${CitationLinker.hintOpen}2${CitationLinker.hintClose} and R² values.',
      [service],
    );
    expect(linked, contains('mol²'));
    expect(linked, contains('kJ²'));
    expect(linked, contains('R²'));
    expect(linked, isNot(contains('{{cite:')));
    expect(linked, isNot(contains('Service')));
  });

  test('Discussion [33]-[36] stay in the paragraph after APA conversion', () {
    PublishReference item(int n, String name) => PublishReference(
          id: 'ref_$n',
          type: ReferenceType.journal,
          authors: ['$name, A.'],
          title: 'Paper $n',
          year: '${2000 + n}',
          importedNumber: n,
          rawText: '[$n] $name, A. (20${n.toString().padLeft(2, '0')}). Paper $n.',
        );
    final refs = [
      item(33, 'Ali'),
      item(34, 'Bakr'),
      item(35, 'Chen'),
      item(36, 'Diaz'),
    ];
    const text =
        'Heavy metals contaminate water sources [33]. '
        'The world is full of Fe, Mn, Pb, and Hg [34,35]. '
        'Thermal activation was reported [36].';
    final manuscript = PublishManuscript(
      userId: 'u',
      title: 'Hulls',
      body: text,
      bodyBlocks: [
        const ManuscriptBlock(
          id: 'd1',
          type: ManuscriptBlockType.paragraph,
          text: text,
        ),
      ],
      references: refs,
    );
    final apa = CitationStyleConverter.apply(
      manuscript: manuscript,
      style: PublishCitationStyle.apa,
    );
    final preview = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(preview, contains('Ali'));
    expect(preview, contains('Bakr'));
    expect(preview, contains('Chen'));
    expect(preview, contains('Diaz'));
    expect(preview, isNot(contains('[33]')));
  });

  test('equation (4) and equation [4] are not bibliography citations', () {
    const ref = PublishReference(
      id: 'ref_4',
      type: ReferenceType.journal,
      authors: ['Wartelle, L.'],
      title: 'Binding',
      year: '2000',
      importedNumber: 4,
      rawText: '[4] L. Wartelle, "Binding," J. Hazard. Mater., 2000.',
    );
    final linked = CitationLinker.linkTextWithRefs(
      'Removal efficiencies, computed using equation (4), are presented. '
      'This model is expressed as equation [4].',
      [ref],
    );
    expect(linked, contains('equation (4)'));
    expect(linked, contains('equation [4]'));
    expect(linked, isNot(contains('{{cite:')));

    final blocks = CitationLinker.linkParsed(
      references: [ref],
      bodyBlocks: [
        const ManuscriptBlock(
          id: 'eq',
          type: ManuscriptBlockType.equation,
          text: r'q_e=\frac{RT}{b_t}ln(A_tC_e)',
        ),
        const ManuscriptBlock(
          id: 'num',
          type: ManuscriptBlockType.paragraph,
          text: '(4)',
        ),
      ],
    ).bodyBlocks;
    expect(blocks.last.text, '(4)');
    expect(blocks.last.text, isNot(contains('{{cite:')));
  });

  test('APA restyle keeps original Vancouver works in the same text places', () {
    const paper = '''
Introduction
Heavy metals were removed [6]. Equilibrium followed the isotherm [4].
Discussion
Activation was reported [33].
References
[4] Dotto GL, Lima EC, Pinto IA (2018) Adsorption of metal ions onto treated biomass. Braz J Poult Sci, 20, 633-642.
[6] Jia L, Chen E, Su H, Tan T (2011) Adsorption of Pb(II). J Hazard Mater.
[33] Ali A (2010) Water contamination review. Environ Sci.
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    expect(parsed.references.length, 3);
    final apa = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Hulls',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      style: PublishCitationStyle.apa,
    );
    final bib = CitationFormatter.formatBibliography(
      references: apa.references,
      style: PublishCitationStyle.apa,
    );
    expect(bib, contains('Jia'));
    expect(bib, contains('Dotto'));
    expect(bib, contains('Ali'));
    expect(bib, contains('Adsorption of Pb(II)'));
    expect(bib, isNot(contains('R. A. LB')));
    final body = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.map((b) => b.text).join('\n'),
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(body, contains('removed (Jia'));
    expect(body, contains('isotherm (Dotto'));
    expect(body, contains('reported (Ali'));
    expect(body.indexOf('Jia'), lessThan(body.indexOf('Dotto')));
    expect(body, isNot(contains('[6]')));
    expect(body, isNot(contains('[33]')));
  });

  test('APA replaces [n] with the author of imported bibliography item n', () {
    const paper = '''
Introduction
Soybeans (Glycine max) are among the most important crops in the world. They contain 36% protein and 20% fat. According to Corke, Walker, and Wrigley (2004) [1], the remaining portion comprises carbohydrates. They are used in plastics, cosmetics, inks, varnishes, and paints [2]. They can fix nitrogen biologically [2]. According to multiple studies [3,4], soybean has a large number of bioactive compounds. Researchers have noted therapeutic effects of soy and its bioactive compounds [5]. Mass spectrometry-headspace gas chromatography (HS-GC/MS) examination of volatile chemicals is needed.
References
1. Wrigley, C.; Corke, H.; Walker, C.E. (Eds.). Encyclopedia of Grain Science, 1st ed.; Academic Press: Oxford, UK, 2004; Vol. 2, pp. 125-131.
2. Gupta, S.K. Editor. Technological Innovations in Major World Oil Crops, Volume 1: Breeding, 1st ed., Springer: New York, USA; 2011; p 274. https://doi.org/10.1007/978-1-4614-0356-2
3. Luthria, D.L.; Biswas, R.; Natarajan, S. Comparison of extraction solvents and techniques used for the assay of isoflavones from soybean. Food Chem. 2007, 105(1), 325-333. https://doi.org/10.1016/j.foodchem.2006.11.047
4. Lee, S.J.; Kim, J.J.; Moon, H.I.; Ahn, J.K.; Chun, S.C.; Jung, W.S.; Chung, I.M. Analysis of isoflavones and phenolic compounds in Korean soybean (Glycine max (L.) Merrill) seeds of different seed weights. J. Agric. Food Chem. 2008, 56(8), 2751-2758. https://doi.org/10.1021/jf073153f
5. Lim, T.K. Edible Medicinal and Non-Medicinal Plants, 1st ed., Springer: Dordrecht, Netherlands; 2012; Vol. 1, pp. 285-292. https://doi.org/10.1007/978-94-017-9511-1
6. Selvarani, S.R.; Sundareswaran, S.; Manonmani, V.; Manivannan, N.; Gomathi, V.; Raja, K. The Impact of Volatile Organic Compounds on Assessing Soybean Seed Quality during Storage. Legume Res.-Int. J. 2025, 1, 8.
7. Erickson, D.R. Editor. Practical Handbook of Soybean Processing and Utilization, 1st ed.; Elsevier: Amsterdam, Netherlands; 2015; pp. 203-217.
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    expect(parsed.references.map((r) => r.importedNumber).toList(), [1, 2, 3, 4, 5, 6, 7]);
    expect(parsed.references[1].rawText, contains('Gupta'));
    expect(parsed.references[2].rawText, contains('Luthria'));
    expect(parsed.references[3].rawText, contains('Lee'));
    expect(parsed.references[4].rawText, contains('Lim'));

    final apa = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Soybean',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      style: PublishCitationStyle.apa,
    );
    final body = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.map((b) => b.text).join('\n'),
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(body, contains('Corke, Walker, and Wrigley (2004)'));
    expect(body, contains('(Gupta, 2011)'));
    expect(body, contains('Luthria'));
    expect(body, contains('2007'));
    expect(body, contains('Lee'));
    expect(body, contains('2008'));
    expect(body, contains('(Lim, 2012)'));
    expect(body, isNot(contains('[1]')));
    expect(body, isNot(contains('[2]')));
    expect(body, isNot(contains('[3,4]')));
    expect(body, isNot(contains('[5]')));
    expect(body, isNot(contains('Selvarani')), reason: '[n] must not jump to a later list item');
    expect(body, isNot(contains('Mohammed')));
    expect(body.indexOf('Gupta'), lessThan(body.indexOf('Luthria')));
    expect(body.indexOf('Luthria'), lessThan(body.indexOf('Lim')));
  });

  test('canola [1] stays Daun and [7] stays Shahidi after APA', () {
    const paper = '''
Introduction
Rapeseed produces a large amount of oil [1]. The amino acid profile enhances its appeal [2,3,4,5]. Many industries rely on canola [4,6]. The oil is well-suited for human consumption [7,8,6].
References
[1] Daun, J. K., Eskin, M. N., Hickling, D. (Eds.). Canola: chemistry, production, processing, and utilization. Elsevier, 2015.
[2] Carré, P., Pouzet, A. Rapeseed market, worldwide and in Europe. Ocl 2014, 21(1). https://doi.org/10.1051/ocl/2013054
[3] Von Der Haar, D., Müller, K., Bader-Mittermaier, S., Eisner, P. Rapeseed proteins – Production methods and possible application range. Ocl 2014, 21(1). https://doi.org/10.1051/ocl/2013038
[4] Rodrigues, I. M., Coelho, J. F., Carvalho, M. G. V. Isolation and valorisation of vegetable proteins from oilseed by-products. Journal of Food Engineering 2012, 109(3). https://doi.org/10.1016/j.jfoodeng.2011.10.027
[5] Mupondwa, E., Li, X., Wanasundara, J. P. D. Technoeconomic prospects for commercialization of Brassica plant proteins. Journal of the American Oil Chemists Society 2018, 95(8):903-22.
[6] Wanasundara, J. P., McIntosh, T. C., Perera, S. P., Withana-Gamage, T. S., Mitra, P. Canola/rapeseed protein-functionality. OCL 2016, 23(4). https://doi.org/10.1051/ocl/2016028
[7] Shahidi, F. (Ed.). Canola and rapeseed: production, chemistry, nutrition, and processing technology. Springer, 1990.
[8] Aider, M., Barbana, C. Canola proteins: composition, extraction, functional properties. Trends in Food Science and Technology 2011, 22(1). https://doi.org/10.1016/j.tifs.2010.11.002
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    expect(parsed.references.first.rawText, contains('Daun'));
    expect(parsed.references.first.importedNumber, 1);
    expect(
      parsed.references.firstWhere((r) => r.importedNumber == 7).rawText,
      contains('Shahidi'),
    );

    final apa = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Canola',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      style: PublishCitationStyle.apa,
    );
    final body = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.map((b) => b.text).join('\n'),
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(body, contains('oil (Daun'));
    expect(body, contains('2015'));
    expect(body, contains('consumption (Shahidi'));
    expect(body, contains('1990'));
    expect(body, isNot(contains('oil (Shahidi')));
    expect(body, isNot(contains('[1]')));
    expect(body, isNot(contains('[7]')));
    final bib = CitationFormatter.formatBibliography(
      references: apa.references,
      style: PublishCitationStyle.apa,
    );
    expect(bib.indexOf('Daun'), lessThan(bib.indexOf('Shahidi')));
    expect(bib, isNot(contains('https://doi. ,')));
  });

  test('Word list restart 1. Shahidi does not steal bibliography [1]', () {
    final refs = ManuscriptDocumentParser.stampImportedNumbers([
      const PublishReference(
        id: 'a',
        type: ReferenceType.book,
        authors: ['Daun, J. K.'],
        title: 'Canola',
        year: '2015',
        importedNumber: 1,
        rawText: '[1] Daun, J. K. Canola. Elsevier, 2015.',
      ),
      const PublishReference(
        id: 'b',
        type: ReferenceType.journal,
        authors: ['Pouzet, A.'],
        title: 'Rapeseed market',
        year: '2014',
        importedNumber: 2,
        rawText: '[2] Pouzet, A. Rapeseed market. Ocl 2014.',
      ),
      const PublishReference(
        id: 'c',
        type: ReferenceType.journal,
        authors: ['Haar, D.'],
        title: 'Rapeseed proteins',
        year: '2014',
        importedNumber: 3,
        rawText: '[3] Haar, D. Rapeseed proteins. Ocl 2014.',
      ),
      const PublishReference(
        id: 'd',
        type: ReferenceType.journal,
        authors: ['Rodrigues, I. M.'],
        title: 'Vegetable proteins',
        year: '2012',
        importedNumber: 4,
        rawText: '[4] Rodrigues, I. M. Vegetable proteins. 2012.',
      ),
      const PublishReference(
        id: 'e',
        type: ReferenceType.journal,
        authors: ['Mupondwa, E.'],
        title: 'Brassica proteins',
        year: '2018',
        importedNumber: 5,
        rawText: '[5] Mupondwa, E. Brassica proteins. 2018.',
      ),
      const PublishReference(
        id: 'f',
        type: ReferenceType.journal,
        authors: ['Wanasundara, J. P.'],
        title: 'Canola protein',
        year: '2016',
        importedNumber: 6,
        rawText: '[6] Wanasundara, J. P. Canola protein. 2016.',
      ),
      const PublishReference(
        id: 'g',
        type: ReferenceType.book,
        authors: ['Shahidi, F.'],
        title: 'Canola and rapeseed',
        year: '1990',
        importedNumber: 1,
        rawText: '1. Shahidi, F. (Ed.). Canola and rapeseed. Springer, 1990.',
      ),
      const PublishReference(
        id: 'h',
        type: ReferenceType.journal,
        authors: ['Aider, M.'],
        title: 'Canola proteins',
        year: '2011',
        importedNumber: 8,
        rawText: '[8] Aider, M. Canola proteins. 2011.',
      ),
    ]);
    expect(refs.first.importedNumber, 1);
    expect(refs.first.rawText, contains('Daun'));
    expect(refs.firstWhere((r) => r.importedNumber == 7).rawText, contains('Shahidi'));
    expect(refs.where((r) => r.importedNumber == 1).length, 1);

    final apa = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Canola',
        bodyBlocks: const [
          ManuscriptBlock(
            id: 'p1',
            type: ManuscriptBlockType.paragraph,
            text: 'The crop produces oil [1]. It is suited for consumption [7,8,6].',
          ),
        ],
        references: refs,
      ),
      style: PublishCitationStyle.apa,
    );
    final body = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(body, contains('oil (Daun'));
    expect(body, contains('consumption (Shahidi'));
    expect(body, isNot(contains('oil (Shahidi')));
  });

  test('APA turns [n] into bibliography n and drops leftover numbers after names', () {
    const text =
        'Moisture spoiling increases with its moisture content [13]. '
        'Values are in the range reported by Pixton, S. W., and Warburton, S. 1977 [14] '
        'and higher than the 5 % reported by El-Agaimy, Magdi A., et al. 2005[15]. '
        'Ash aligned with Alhomodi et al. 2021 [16]respectively, '
        'and lower than values documented by Housseinpour, Reza, et al.2010 [17] '
        'and Carré, Patrick, et al. 2016 [18] respectively.';
    const refs = [
      PublishReference(
        id: 'ref_13',
        type: ReferenceType.journal,
        authors: ['Bradley, R. L.'],
        title: 'Moisture and total solids',
        year: '2010',
        importedNumber: 13,
        rawText: '[13] Bradley, R. L. Moisture and total solids. 2010.',
      ),
      PublishReference(
        id: 'ref_14',
        type: ReferenceType.journal,
        authors: ['Pixton, S. W.', 'Warburton, S.'],
        title: 'Moisture content determination',
        year: '1977',
        importedNumber: 14,
        rawText: '[14] Pixton, S. W., Warburton, S. Moisture content. 1977.',
      ),
      PublishReference(
        id: 'ref_15',
        type: ReferenceType.journal,
        authors: ['El-Agaimy, M. A.'],
        title: 'Rapeseed composition',
        year: '2005',
        importedNumber: 15,
        rawText: '[15] El-Agaimy, Magdi A. Rapeseed composition. 2005.',
      ),
      PublishReference(
        id: 'ref_16',
        type: ReferenceType.journal,
        authors: ['Alhomodi, A.'],
        title: 'Ash content',
        year: '2021',
        importedNumber: 16,
        rawText: '[16] Alhomodi, A. Ash content. 2021.',
      ),
      PublishReference(
        id: 'ref_17',
        type: ReferenceType.journal,
        authors: ['Housseinpour, R.'],
        title: 'Oilseeds',
        year: '2010',
        importedNumber: 17,
        rawText: '[17] Housseinpour, Reza. Oilseeds. 2010.',
      ),
      PublishReference(
        id: 'ref_18',
        type: ReferenceType.journal,
        authors: ['Carré, P.'],
        title: 'Rapeseed proteins',
        year: '2016',
        importedNumber: 18,
        rawText: '[18] Carré, Patrick. Rapeseed proteins. 2016.',
      ),
      PublishReference(
        id: 'ref_1',
        type: ReferenceType.book,
        authors: ['Shahidi, F.'],
        title: 'Canola and rapeseed',
        year: '1990',
        importedNumber: 1,
        rawText: '[1] Shahidi, F. Canola and rapeseed. 1990.',
      ),
    ];
    final apa = CitationStyleConverter.apply(
      manuscript: const PublishManuscript(
        userId: 'u',
        title: 'Proximate',
        bodyBlocks: [
          ManuscriptBlock(
            id: 'p1',
            type: ManuscriptBlockType.paragraph,
            text: text,
          ),
        ],
        references: refs,
      ),
      style: PublishCitationStyle.apa,
    );
    final body = ManuscriptCitationHelper.resolvePlainText(
      text: apa.bodyBlocks.first.text,
      manuscript: apa,
      style: PublishCitationStyle.apa,
    );
    expect(body, contains('content (Bradley, 2010)'));
    expect(body, contains('Pixton'));
    expect(body, contains('1977'));
    expect(body, contains('El-Agaimy'));
    expect(body, contains('2005'));
    expect(body, contains('Alhomodi'));
    expect(body, contains('Housseinpour'));
    expect(body, contains('Carré'));
    expect(body, isNot(contains('[13]')));
    expect(body, isNot(contains('[14]')));
    expect(body, isNot(contains('[15]')));
    expect(body, isNot(contains('[16]')));
    expect(body, isNot(contains('[17]')));
    expect(body, isNot(contains('[18]')));
    expect(body, isNot(contains('Shahidi')), reason: '[13] must not become item 1');
    expect(body, contains('2021 respectively'));
    expect(body, isNot(contains(']respectively')));
  });

  test('wrapped APA bibliography keeps authors; wrap fragments do not steal numbers', () {
    const paper = '''
Introduction
According to Da ̨browsk (2001), adsorption occurs.
According to Ademiluyi and Nze (2016), bamboo carbon works.
Ayash, Elnasr and Soliman (2019) removed iron.
Islam et al. (2021) described Langmuir kinetics.
Prasat et al. (2014) compared agricultural wastes.
Yousef, Qiblawey and El-Naas (2020) reviewed produced water.
Musah et al. (2018a) fitted isotherms. Later work (Musah et al., 2018b) followed.

References
Ademiluyi,  F.  T.  &  Nze,  J.  C.  (2016).  Sorption
characteristics  for  multiple  adsorptions.
Ayash,M. A. A., Elnasr, T. A. S. & Soliman, M. H.
(2019).  Removing  Iron  Ions  Contaminants
from  Groundwater.
Da ̨browsk, A. (2001). Adsorption from theory to
practice. Advances in Colloid and Interface
Science, 93,135-224.
Islam,  A., Chowdhury,  M.  A.,  Mozumder,  S.  I.  &
Uddin,   T.   (2021).   Langmuir   adsorption
kinetics  in  liquid  media.
Musah, M., Yisa, J., Suleiman, M. A. T., Mann, A.
& Shaba,  E.Y.  (2018)a.  Study  of  isotherm
models.

CaJoST  M. Musah et al.
CaJoST, 2022, 1, 20-26 © 2022 Faculty of Science, Sokoto State University, Sokoto.|26

Musah,  M.,  Yisa,  J.,  Suleiman,  M.  A.  T.,  Mann,
A.,   Shaba,   E.Y. & Aliyu,   A.   (2018)b.
kinetics   and   isotherms   studies.
Prasat,   R.   R.,   Muthirulan,   P.   &   Kannan,   N.
(2014).     Agricultural     wastes     as     low
adsorbents.
Yousef,   R.,   Qiblawey,   H.   &   El-Naas,   M.   H.
(2020).   Adsorption    as   a   process   for
produced water.
''';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(paper);
    final rows = parsed.references
        .map((r) {
          final raw = r.rawText.trim().isNotEmpty ? r.rawText : r.title;
          return '${r.importedNumber}:${raw.substring(0, math.min(70, raw.length))}';
        })
        .join('\n');

    expect(parsed.references.length, 8, reason: rows);
    expect(parsed.references[0].rawText, contains('Ademiluyi'));
    expect(parsed.references[1].rawText, contains('Ayash'));
    expect(parsed.references[1].rawText, isNot(startsWith('(2019)')));
    expect(parsed.references[2].rawText, contains('browsk'));
    expect(parsed.references[3].rawText, contains('Islam'));
    expect(parsed.references[3].rawText, isNot(startsWith('Uddin')));
    expect(parsed.references[4].rawText, contains('Musah'));
    expect(parsed.references[4].rawText, contains('2018)a'));
    expect(parsed.references[5].rawText, contains('2018)b'));
    expect(parsed.references[6].rawText, contains('Prasat'));
    expect(parsed.references[6].rawText, isNot(startsWith('(2014)')));
    expect(parsed.references[7].rawText, contains('Yousef'));
    expect(parsed.references[7].rawText, isNot(startsWith('(2020)')));
    expect(
      parsed.references.every((r) => !r.rawText.contains('CaJoST, 2022')),
      isTrue,
      reason: rows,
    );

    final ieee = CitationStyleConverter.apply(
      manuscript: PublishManuscript(
        userId: 'u',
        title: 'Adsorption',
        bodyBlocks: parsed.bodyBlocks,
        references: parsed.references,
      ),
      style: PublishCitationStyle.ieee,
    );
    final body = ManuscriptCitationHelper.resolvePlainText(
      text: ieee.bodyBlocks.map((b) => b.text).join('\n'),
      manuscript: ieee,
      style: PublishCitationStyle.ieee,
    );
    expect(body, contains('[1]'));
    expect(body, isNot(contains('Ademiluyi and Nze (2016)')));
    expect(body, contains('[2]'));
    expect(body, isNot(contains('Ayash, Elnasr and Soliman (2019)')));
    expect(body, contains('[4]'));
    expect(body, isNot(contains('Islam et al. (2021)')));
    expect(body, contains('[7]'));
    expect(body, isNot(contains('Prasat et al. (2014)')));
    expect(body, contains('[8]'));
    expect(body, isNot(contains('Da ̨browsk [2]')), reason: body);
    expect(body, isNot(contains('[1] Removing')), reason: body);
  });

  test('adsorption PDF bibliography keeps every original work in file order', () {
    final file = File('tmp_pdf_extract.txt');
    if (!file.existsSync()) {
      return;
    }
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(
      file.readAsStringSync(),
    );
    final rows = parsed.references
        .map((r) {
          final raw = r.rawText.trim().isNotEmpty ? r.rawText : r.title;
          final clip =
              raw.substring(0, math.min(90, raw.length)).replaceAll('\n', ' ');
          return '${r.importedNumber} | ${r.year} | $clip';
        })
        .join('\n');
    final joined = parsed.references.map((r) => r.rawText).join('\n');
    expect(parsed.references.length, 23, reason: rows);
    expect(parsed.references[0].rawText, contains('Ademiluyi'));
    expect(parsed.references[1].rawText, contains('Ayash'));
    expect(parsed.references[2].rawText, contains('browsk'));
    expect(joined, contains('Islam'));
    expect(joined, contains('Javadian'));
    expect(joined, contains('Musah'));
    expect(joined, anyOf(contains('2018)a'), contains('2018a')));
    expect(joined, anyOf(contains('2018)b'), contains('2018b')));
    expect(joined, contains('Prasat'));
    expect(joined, contains('Sampranpiboon'));
    expect(joined, contains('Yousef'));
    expect(joined, isNot(contains('CaJoST, 2022')));
    expect(parsed.references.last.rawText, contains('Yousef'));
  });
}
