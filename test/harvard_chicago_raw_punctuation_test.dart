import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

String _render(String raw, PublishCitationStyle style) {
  final ref = PublishReference(
    id: 'x',
    type: ReferenceType.journal,
    title: raw, // no title boundary, so the entry stays raw source text
    rawText: raw,
  );
  return CitationFormatter.buildBibliographyEntry(
          reference: ref, style: style, index: 1)
      .spans
      .map((s) => s.text)
      .join();
}

void main() {
  const raw = 'Smith, J. (2019). A long enough title about plants. Plant Sci 3(2), 1-9.';

  test('Chicago moves the raw year out of parentheses', () {
    expect(_render(raw, PublishCitationStyle.chicago),
        startsWith('Smith, J. 2019. A long enough title'));
  });

  test('Harvard keeps the year parenthetical without the full stop', () {
    expect(_render(raw, PublishCitationStyle.harvard),
        startsWith('Smith, J. (2019) A long enough title'));
  });

  test('APA and unmatched shapes stay exactly as written', () {
    expect(_render(raw, PublishCitationStyle.apa), raw);
    const odd = 'Smith J, 2019 - something without a parenthesized year here.';
    expect(_render(odd, PublishCitationStyle.chicago), odd);
    expect(_render(odd, PublishCitationStyle.harvard), odd);
  });
}
