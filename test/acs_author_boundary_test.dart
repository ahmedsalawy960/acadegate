import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
void main(){
 test('and-separated surname-initial authors end before book title',(){
 final r=CitationFormatter.parseBibliographicLine('Werpy, T. and Petersen, G., Top Value Added Chemicals from Biomass. NREL, Ed. National Renewable Energy Laboratory: Golden, CO (US), 2004; Vol. 1.');
 expect(r,isNotNull);expect(r!.authors,['Werpy, T.','Petersen, G.']);expect(r.title,startsWith('Top Value Added Chemicals'));expect(r.year,'2004');
 });
 test('semicolon authors do not consume title when final initials followed by comma',(){
 final r=CitationFormatter.parseBibliographicLine('Bozell, J. J.; Petersen, G. R., Technology development for the production of biobased products. Green Chem 2010, 12 (4), 539-554.');
 expect(r,isNotNull);expect(r!.authors,['Bozell, J. J.','Petersen, G. R.']);expect(r.title,startsWith('Technology development'));expect(r.title,isNot(contains('Petersen')));
 });
 test('title beginning with And is not another author',(){
 final r=CitationFormatter.parseBibliographicLine('Smith, A.; Jones, B. And then there were plants. Plant Science 2020, 1, 12-20.');
 expect(r,isNotNull);expect(r!.authors,['Smith, A.','Jones, B.']);expect(r.title,startsWith('And then'));
 });
}
