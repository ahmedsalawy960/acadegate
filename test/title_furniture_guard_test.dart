import 'package:acadegate/features/acadegate_publish/docx_title_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repeated title prefix with colon collapses to one copy', () {
    expect(DocxTitleReader.collapseTitleEcho('The silent influence:The silent influence:'),
        'The silent influence');
  });

  test('glued repeated title collapses', () {
    expect(
        DocxTitleReader.collapseTitleEcho(
            'Needs assessment of theNeeds assessment of the'),
        'Needs assessment of the');
  });

  test('a normal title and a title with a legitimate subtitle are untouched', () {
    const a = 'Deep learning for plant disease detection: a systematic review';
    expect(DocxTitleReader.collapseTitleEcho(a), a);
    const b = 'Study of data and Study design';
    expect(DocxTitleReader.collapseTitleEcho(b), b);
  });

  test('dangling et al. is rejected, a normal title is not', () {
    expect(DocxTitleReader.hasDanglingEtAl('Smith J, Jones K, et al.'), isTrue);
    expect(DocxTitleReader.hasDanglingEtAl('Effects of drugs on et al interactions in rats'), isFalse);
  });
}
