import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
void main(){
 test('APA year and full title take precedence over a quoted word and DOI year',(){
 final ref=CitationFormatter.parseBibliographicLine("Mithöfer, D., Roshetko, J. M., Donovan, J. A., Nathalie, E., Robiglio, V., Wau, D., … Blare, T. (2017). Unpacking “sustainable” cocoa: do sustainability standards, development projects and policies address producer concerns in Indonesia, Cameroon and Peru?. International Journal of Biodiversity Science, Ecosystem Services & Management, 13(1), 444–469. https://doi.org/10.1080/21513732.2018.1432691");
 expect(ref,isNotNull);
 expect(ref!.year,'2017');
 expect(ref.authors.first,'Mithöfer, D.');
 expect(ref.title,startsWith('Unpacking'));
 expect(ref.title,contains('Cameroon and Peru?'));
 expect(ref.container,startsWith('International Journal'));
 });
 test('genuine IEEE title quotes still parse',(){
 final ref=CitationFormatter.parseBibliographicLine('A. Smith and B. Jones, "A study of citation quality", Test Journal, vol. 8, pp. 10-20, 2017. https://doi.org/10.1000/2018.123');
 expect(ref,isNotNull);expect(ref!.year,'2017');expect(ref.authors.first,contains('Smith'));
 });
}
