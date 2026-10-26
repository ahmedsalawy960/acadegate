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
}
