import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unreferenced explanatory prose does not become a bibliography', () {
    const text = 'Supplementary Information\nAppendix A\n'
        'The equilibrium is obtained by setting the differential equations to zero.\n'
        'Here, I examine the effects of intraspecific variation in the coefficients. '
        'First, without variation between genotypes, the equilibrium does not exist.\n'
        'For analytical simplicity, I consider a special case where predation rates '
        'of two predators are the same.\nFirst, I obtain mean fitness\n'
        'By multiplying both sides of the above equation, I obtain the final result.';
    final parsed = ManuscriptDocumentParser.parsePlainTextForTest(text);
    expect(parsed.references, isEmpty);
    expect(parsed.bodyText, contains('Here, I examine'));
    expect(parsed.bodyText, contains('First, I obtain mean fitness'));
  });
  test('an explicit bibliography still preserves an undated reference', () {
    final refs = ManuscriptDocumentParser.parseReferencesFromText(
      'Introduction\nA sample study with a numbered source [1].\n'
      'References\n[1] Smith, A. A technical handbook without a publication date.',
    );
    expect(refs, hasLength(1));
    expect(refs.single.rawText, contains('technical handbook'));
  });
  test('a numbered bibliographic entry without a heading is still recovered', () {
    final refs = ManuscriptDocumentParser.parseReferencesFromText(
      'Introduction\nA sample study uses a real citation [1].\n'
      '[1] Smith, A. A measured result. Journal of Testing 2020, 5, 10-20.',
    );
    expect(refs, hasLength(1));
    expect(refs.single.rawText, contains('Smith'));
  });
}
