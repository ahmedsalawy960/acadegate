import 'package:acadegate/features/academic_integrity/citation_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = CitationParser.instance;

  test('splits one APA reference per line without [1] numbers', () {
    const raw = '''
Zhang, W., Xu, S., Wang, Z., Yang, R., and Lu, R. (2009). Demucilaging and dehulling flaxseed with a wet process. LWT - Food Science and Technology, 42, 1-8.
Zhang, Z. S., Wang, L. J., Li, D., Jiao, S. S., Chen, X. D., and Mao, Z. H. (2008). Ultrasound-assisted extraction of oil from flaxseed. European Food Research, 227, 1-8.
Zhao, P., Shen, Y., Ge, S., and Yoshikawa, K. (2014). Energy recycling from sewage sludge. Applied Energy, 130, 1-10.
Zohary, D., Hopf, M., and Weiss, E. (2012). Domestication of Plants in the Old World. Oxford University Press.
''';
    final parsed = parser.parse(raw);
    expect(parsed.length, 4);
    expect(parsed[0].yearGuess, 2009);
    expect(parsed[1].yearGuess, 2008);
    expect(parsed[2].rawText, contains('Zhao'));
    expect(parsed[3].rawText, contains('Zohary'));
    expect(parsed.every((c) => c.rawText.contains('Zhang') && c.rawText.contains('Zohary')), isFalse);
  });

  test('splits dashed APA rows that used to be glued into one card', () {
    const raw = '''
- Abdelhamid, M. I. (1998). First canola paper. Journal of Oils, 1, 1-10.
- Abidi, S. L., List, G. R., and Rennick, K. A. (1999). Effect of genetic modification on the distribution of minor constituents in canola oil. JAOCS, 76, 1-8.
- Adolphe, J. L. (2010). Third flax paper. Journal, 2, 3-4.
''';
    final parsed = parser.parse(raw);
    expect(parsed.length, 3);
    expect(parsed[0].rawText, contains('Abdelhamid'));
    expect(parsed[0].rawText, isNot(contains('Abidi')));
    expect(parsed[1].titleGuess.toLowerCase(), contains('genetic modification'));
    expect(parsed[2].rawText, contains('Adolphe'));
  });

  test('splits APA works glued into one paragraph', () {
    const raw =
        'Abdelhamid, M. I. (1998). First canola paper. Journal of Oils, 1, 1-10. '
        'Abidi, S. L., List, G. R., and Rennick, K. A. (1999). Effect of genetic '
        'modification on the distribution of minor constituents in canola oil. JAOCS, 76, 1-8. '
        'Adolphe, J. L. (2010). Third flax paper. Journal, 2, 3-4.';
    final parsed = parser.parse(raw);
    expect(parsed.length, 3);
    expect(parsed.map((c) => c.yearGuess).toList(), [1998, 1999, 2010]);
  });

  test('keeps wrapped author line with year on the next line as one work', () {
    const raw = '''
Zhang, W., Xu, S., Wang, Z., Yang, R.,
and Lu, R. (2009). Demucilaging and dehulling flaxseed with a wet process. LWT, 42, 1-8.
Zhao, P., Shen, Y., Ge, S., and Yoshikawa, K. (2014). Energy recycling from sewage sludge. Applied Energy, 130, 1-10.
''';
    final parsed = parser.parse(raw);
    expect(parsed.length, 2);
    expect(parsed[0].rawText, contains('Demucilaging'));
    expect(parsed[0].yearGuess, 2009);
    expect(parsed[1].rawText, contains('Zhao'));
  });
}
