import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _ref = PublishReference(
  id: 'v',
  type: ReferenceType.journal,
  authors: ['Smith, John A.', 'Jones, C. D.'],
  title: 'Plant growth under stress',
  container: 'Plant Sci',
  year: '2020',
  volume: '12',
  issue: '3',
  pages: '45-50',
);

String _v(PublishReference r, {bool plain = false, int i = 1}) =>
    CitationFormatter.buildBibliographyEntry(
      reference: r,
      style: PublishCitationStyle.vancouver,
      index: i,
      plainNumberList: plain,
    ).plain;

void main() {
  test('Vancouver journal entry uses its own punctuation', () {
    expect(_v(_ref),
        '1. Smith JA, Jones CD. Plant growth under stress. Plant Sci. 2020;12(3):45-50.');
  });

  test('Vancouver always numbers 1. 2. 3., never IEEE brackets', () {
    expect(_v(_ref, i: 7), startsWith('7. '));
    expect(_v(_ref, plain: false), isNot(contains('[')));
  });

  test('more than six authors are cut with et al', () {
    final many = PublishReference(
      id: 'm',
      type: ReferenceType.journal,
      authors: [for (final n in 'ABCDEFGH'.split('')) '${n}ay, $n.'],
      title: 'Many authors',
      container: 'J Test',
      year: '2021',
    );
    expect(_v(many), contains('et al.'));
    expect(_v(many), isNot(contains('Hay')));
  });

  test('numbered list policy keeps Vancouver plain', () {
    final e = CitationFormatter.applyListNumberPolicy(
      CitationFormatter.buildBibliographyEntry(
          reference: _ref, style: PublishCitationStyle.vancouver, index: 2),
      style: PublishCitationStyle.vancouver,
      index: 2,
    );
    expect(e.plain, startsWith('2. Smith'));
  });
}
