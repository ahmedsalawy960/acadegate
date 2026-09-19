import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_extract_service.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pasted author-guide text is applied for any journal name', () async {
    const text = '''
Author Guidelines
Title should be types in bold upper case letters and at the center.
Sections and sub-sections should not be numbered.
The manuscript must contain an abstract that does not exceed 200 words.
KEY WORDS: 4-6 main words contained in the Title and Abstract.
Short running title is necessary, not exceeding 80 characters including spaces.
Reference numbers in the text should appear sequentially in square brackets [ ]
and listed in the References section as 1., 2., 3., without [ ].
The total number of references should not exceed 50.
Do not use et al. Include names of all the authors.
The widths of Tables and Figures should not exceed 5 inches (12.5 cm).
The total number of Schemes, Tables and Figures should not exceed 10.
''';
    final extracted = JournalGuidelinesHeuristic.extract(
      text,
      requireDistinctive: false,
    );
    expect(extracted, isNotNull);
    final rules = JournalFormatRules.fromExtracted(
      journalName: 'Any Journal of Chemistry',
      publisher: 'Some Publisher',
      sourceUrl: 'pasted_by_user',
      extracted: extracted!,
    );
    expect(rules.extractedFromGuide, isTrue);
    expect(rules.titleUppercase, isTrue);
    expect(rules.headingNumbered, isFalse);
    expect(rules.abstractMaxWords, 200);
    expect(rules.maxReferences, 50);
    expect(rules.maxFiguresAndTables, 10);
    expect(rules.referenceListPlainNumber, isTrue);
  });

  test('failed paste stays local and does not wait on journal-site fetch', () async {
    final result = await JournalGuidelinesExtractService.instance.extract(
      journalName: 'Any Journal of Chemistry',
      guidelinesText: 'hello hello hello hello hello',
    );
    expect(result.success, isFalse);
    expect(result.reason, 'paste_unparsed');
  });

  test('heuristic reads pasted guide sentences without a distinctive cutoff', () {
    const text = '''
Author Guidelines
Title should be types in bold upper case letters and at the center.
Sections and sub-sections should not be numbered.
The manuscript must contain an abstract that does not exceed 200 words.
KEY WORDS: 4-6 main words contained in the Title and Abstract.
Short running title is necessary, not exceeding 80 characters including spaces.
Reference numbers in the text should appear sequentially in square brackets [ ]
and listed in the References section as 1., 2., 3., without [ ].
The total number of references should not exceed 50.
Do not use et al. Include names of all the authors.
JOURNAL: Gashaw, W.; Yohannes, W.; Chandravanshi, B.S.; Getachew N. Levels of
heavy metals. Bull. Chem. Soc. Ethiop. 2024, 38, 1521-1531.
The widths of Tables and Figures should not exceed 5 inches (12.5 cm).
The total number of Schemes, Tables and Figures should not exceed 10.
Legends should be typed below the Figures.
''';
    final extracted = JournalGuidelinesHeuristic.extract(
      text,
      requireDistinctive: false,
    );
    expect(extracted, isNotNull);
    expect(extracted!['found'], isTrue);
    expect(extracted['titleUppercase'], isTrue);
    expect(extracted['headingNumbered'], isFalse);
    expect(extracted['abstractMaxWords'], 200);
    expect(extracted['keywordsMin'], 4);
    expect(extracted['keywordsMax'], 6);
    expect(extracted['runningTitleMaxChars'], 80);
    expect(extracted['maxReferences'], 50);
    expect(extracted['maxFiguresAndTables'], 10);
    expect(extracted['figureMaxWidthCm'], 12.5);
    expect(extracted['noEtAlInReferences'], isTrue);
    expect(extracted['citationStyle'], 'ieee');
    expect(extracted['referenceListPlainNumber'], isTrue);
  });
}
