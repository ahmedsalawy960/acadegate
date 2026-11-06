import 'package:acadegate/features/acadegate_publish/citation_style_shapes.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_structure_advisor.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a specification line is an item, a section name stays a heading', () {
    expect(
      ManuscriptStructureAdvisor.isCatalogLine(
        'Magnetic stirrer ( ISOLAB Laborgeräte GmbH )',
      ),
      isTrue,
    );
    expect(
      ManuscriptStructureAdvisor.isCatalogLine(
        'Rotary evaporator complete with glass set 00, Cole Parmer, Stuart',
      ),
      isTrue,
    );
    expect(
      ManuscriptStructureAdvisor.isCatalogLine('Sample preparation'),
      isFalse,
    );
    expect(
      ManuscriptStructureAdvisor.isCatalogLine(
        'Soxhlet unit (Velp scientific 148/6).',
      ),
      isTrue,
    );
    expect(
      ManuscriptStructureAdvisor.isCatalogLine(
        'Headspace gas chromatography-mass spectrometry (HS-GC/MS)',
      ),
      isFalse,
    );
    expect(
      ManuscriptStructureAdvisor.isStableSectionLabel('Determination of Moisture Content'),
      isTrue,
    );

    final blocks = ManuscriptStructureAdvisor.demoteCatalogHeadings(const [
      ManuscriptBlock(
        id: 's',
        type: ManuscriptBlockType.heading,
        text: 'Equipments',
      ),
      ManuscriptBlock(
        id: 'a',
        type: ManuscriptBlockType.heading,
        text: 'Magnetic stirrer ( ISOLAB Laborgeräte GmbH )',
      ),
      ManuscriptBlock(
        id: 'b',
        type: ManuscriptBlockType.paragraph,
        text: 'Kjeldahl digestion and distillation equipment ("B.U.CHI" brand),',
      ),
      ManuscriptBlock(
        id: 'c',
        type: ManuscriptBlockType.heading,
        text: 'Sample preparation',
      ),
    ]);

    expect(blocks[0].type, ManuscriptBlockType.heading);
    expect(blocks[1].type, ManuscriptBlockType.paragraph);
    expect(blocks[1].text, 'Magnetic stirrer ( ISOLAB Laborgeräte GmbH )');
    expect(blocks[2].type, ManuscriptBlockType.paragraph);
    expect(blocks[3].type, ManuscriptBlockType.heading);

    final definitions = ManuscriptStructureAdvisor.demoteCatalogHeadings(const [
      ManuscriptBlock(
        id: 'h',
        type: ManuscriptBlockType.heading,
        text: 'Materials and methods',
      ),
      ManuscriptBlock(
        id: 'w',
        type: ManuscriptBlockType.heading,
        text: 'W2 = Final weight of crucible + Sample',
      ),
      ManuscriptBlock(
        id: 's',
        type: ManuscriptBlockType.heading,
        text: 'S = Sample titration reading B = Blank titration reading',
      ),
      ManuscriptBlock(
        id: 'n',
        type: ManuscriptBlockType.heading,
        text: 'N = Normality of HCl D = Dilution of the sample after digestion',
      ),
      ManuscriptBlock(
        id: 'set',
        type: ManuscriptBlockType.heading,
        text: 'Specifications in Headspace Mode',
      ),
      ManuscriptBlock(
        id: 'inc',
        type: ManuscriptBlockType.heading,
        text: 'Incubation Temperature (°C): 150 Incubation Time (s): 900',
      ),
      ManuscriptBlock(
        id: 'oven',
        type: ManuscriptBlockType.heading,
        text: 'Column oven Temperature: 80',
      ),
      ManuscriptBlock(
        id: 'prog',
        type: ManuscriptBlockType.heading,
        text: 'Oven Temperature Program:',
      ),
      ManuscriptBlock(
        id: 'row1',
        type: ManuscriptBlockType.heading,
        text: '- 80.0 1.00',
      ),
      ManuscriptBlock(
        id: 'row2',
        type: ManuscriptBlockType.heading,
        text: '5.00 210.0 25.00',
      ),
      ManuscriptBlock(
        id: 'prep',
        type: ManuscriptBlockType.heading,
        text: 'Sample preparation',
      ),
      ManuscriptBlock(
        id: 'prose',
        type: ManuscriptBlockType.paragraph,
        text: 'The dried material was ground and stored in a sealed container.',
      ),
    ]);
    expect(definitions[0].type, ManuscriptBlockType.heading);
    for (final block in definitions.sublist(1, 10)) {
      expect(block.type, ManuscriptBlockType.paragraph, reason: block.text);
    }
    expect(definitions[10].type, ManuscriptBlockType.heading);
    expect(
      CitationStyleShapes.looksLikeSectionHeading(
        'W2 = Final weight of crucible + Sample',
      ),
      isFalse,
    );
    expect(
      CitationStyleShapes.looksLikeSectionHeading('Sample preparation'),
      isTrue,
    );

    final reviewed = ManuscriptStructureAdvisor.applyReviewedLabels(
      const [
        ManuscriptBlock(
          id: 'spec',
          type: ManuscriptBlockType.heading,
          text: 'Specifications in Headspace Mode',
        ),
        ManuscriptBlock(
          id: 'inc',
          type: ManuscriptBlockType.heading,
          text: 'Incubation Temperature (°C): 150',
        ),
        ManuscriptBlock(
          id: 'intro',
          type: ManuscriptBlockType.heading,
          text: 'Introduction',
        ),
        ManuscriptBlock(
          id: 'eq',
          type: ManuscriptBlockType.heading,
          text: 'W2 = Final weight of crucible + Sample',
        ),
      ],
      const {
        0: 'paragraph',
        1: 'paragraph',
        2: 'heading',
        3: 'heading',
      },
    );
    expect(reviewed[0].type, ManuscriptBlockType.paragraph);
    expect(reviewed[1].type, ManuscriptBlockType.paragraph);
    expect(reviewed[2].type, ManuscriptBlockType.heading);
    expect(reviewed[3].type, ManuscriptBlockType.paragraph);
    expect(
      ManuscriptStructureAdvisor.readingTitle(
        title: 'Proximate',
        blocks: const [
          ManuscriptBlock(
            id: 't',
            type: ManuscriptBlockType.paragraph,
            text:
                'Comprehensive Analysis of Soybean Seeds using headspace gas chromatography-mass spectrometry and oil processing',
          ),
        ],
      ),
      startsWith('Comprehensive Analysis'),
    );
  });

  test('structure status says whether Gemini labeled the file', () {
    ManuscriptStructureAdvisor.lastSource = ManuscriptStructureLabelSource.model;
    ManuscriptStructureAdvisor.lastLabelCount = 12;
    ManuscriptStructureAdvisor.lastDetailCode = null;
    expect(
      ManuscriptStructureAdvisor.statusMessage(arabic: true),
      contains('راجع Gemini الملف وصنّف 12 سطراً'),
    );

    ManuscriptStructureAdvisor.lastSource =
        ManuscriptStructureLabelSource.localFallback;
    ManuscriptStructureAdvisor.lastLabelCount = 0;
    ManuscriptStructureAdvisor.lastDetailCode = 'empty';
    expect(
      ManuscriptStructureAdvisor.statusMessage(arabic: true),
      contains('لم يكتمل رد Gemini'),
    );
    expect(
      ManuscriptStructureAdvisor.statusMessage(arabic: true),
      contains('الرد لم يحتوِ تصنيفاً'),
    );

    expect(
      ManuscriptStructureAdvisor.detailForGeminiError(
        'gemini-2.5-pro: This model models/gemini-2.5-pro is no longer available to new users.',
      ),
      'retired',
    );
    expect(
      ManuscriptStructureAdvisor.detailForGeminiError(
        'gemini-3.1-pro-preview: انتهى رصيد Gemini API المرتبط بالمفتاح السحابي.',
      ),
      'quota',
    );
    ManuscriptStructureAdvisor.lastDetailCode = 'retired';
    expect(
      ManuscriptStructureAdvisor.statusMessage(arabic: true),
      contains('أوقفت نموذج Gemini'),
    );
  });

  test('a cut-off Gemini reply keeps the labels that finished', () {
    const raw = '''
{"labels":[
{"i":0,"role":"heading"},
{"i":1,"role":"paragraph"},
{"i":18,"role":"heading"}
''';
    expect(
      ManuscriptStructureAdvisor.parseModelLabels(raw, 40),
      {0: 'heading', 1: 'paragraph', 18: 'heading'},
    );
  });
}
