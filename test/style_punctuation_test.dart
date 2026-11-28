import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

String _render(PublishReference ref, PublishCitationStyle style) {
  final e = CitationFormatter.buildBibliographyEntry(
      reference: ref, style: style, index: 1);
  return e.spans.map((s) => s.text).join();
}

void main() {
  test('Chicago never doubles the period after a trailing-period author', () {
    const ref = PublishReference(
      id: 'a',
      type: ReferenceType.journal,
      authors: ['Smith, J. A.'],
      title: 'Plant growth under stress',
      container: 'Plant Science',
      year: '2020',
      volume: '12',
      pages: '1-10',
    );
    final out = _render(ref, PublishCitationStyle.chicago);
    expect(out, isNot(contains('..')));
    expect(out, contains('2020.'));
  });

  test('Harvard/Chicago journal with no tail has no dangling comma', () {
    const ref = PublishReference(
      id: 'b',
      type: ReferenceType.journal,
      authors: ['Doe, Jane'],
      title: 'A lone title',
      year: '2019',
    );
    final h = _render(ref, PublishCitationStyle.harvard);
    final c = _render(ref, PublishCitationStyle.chicago);
    expect(h, isNot(contains("',")));
    expect(h, isNot(contains('..')));
    expect(c, isNot(contains('..')));
    expect(c.trim().endsWith('."'), isTrue);
  });
}
