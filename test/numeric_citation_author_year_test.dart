import 'package:acadegate/features/acadegate_publish/in_text_citation_converter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

List<PublishReference> _refs() => const [
      PublishReference(
        id: 'r1',
        type: ReferenceType.journal,
        authors: ['Smith, J.'],
        title: 'First study of plants',
        container: 'Plant Science',
        year: '2019',
        importedNumber: 1,
        rawText: 'Smith, J. (2019). First study of plants. Plant Science.',
      ),
      PublishReference(
        id: 'r2',
        type: ReferenceType.journal,
        authors: ['Doe, A.'],
        title: 'Second study of soil',
        container: 'Soil Journal',
        year: '2020',
        importedNumber: 2,
        rawText: 'Doe, A. (2020). Second study of soil. Soil Journal.',
      ),
    ];

String _apa(String text) =>
    InTextCitationConverter.applyAuthorDateCitations(
      text: text,
      references: _refs(),
      targetStyle: PublishCitationStyle.apa,
    );

void main() {
  test('resolvable bracket glued to a word still converts', () {
    final out = _apa('as shown by features[1]and later work');
    expect(out, contains('Smith'));
    expect(out, isNot(contains('[1]')));
  });

  test('bracket with an unresolved number stays as written when glued', () {
    final out = _apa('see features[50]and more');
    expect(out, contains('[50]'));
  });

  test('ordinary spaced bracket still converts', () {
    final out = _apa('Prior work [2] agrees.');
    expect(out, contains('Doe'));
    expect(out, isNot(contains('[2]')));
  });
}
