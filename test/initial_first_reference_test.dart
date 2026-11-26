import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 test('unquoted initial-first journal reference separates all authors and title',(){
 final r=CitationFormatter.parseBibliographicLine('[1] M. Boyle, C. Sichel, P. Fernández-Ibáñez, G.B. Arias-Quiroz, M. Iriarte-Puña, A. Mercado, E. Ubomba-Jaswa, K.G. McGuigan, Bactericidal effect of solar water disinfection under real sunlight conditions, Appl Env. Microbiol. 74 (2008) 2997–3001. https://doi.org/10.1128/AEM.02415-07.');
 expect(r,isNotNull);expect(r!.authors.length,8);expect(r.authors.first,'Boyle, M.');expect(r.authors.last,'McGuigan, K. G.');expect(r.title,'Bactericidal effect of solar water disinfection under real sunlight conditions');expect(r.container,'Appl Env. Microbiol.');expect(r.year,'2008');expect(r.volume,'74');expect(r.pages,'2997–3001');expect(r.doi,'10.1128/AEM.02415-07');
 });
 test('multipart surnames and title commas remain intact without pages',(){
 final r=CitationFormatter.parseBibliographicLine('S. Giannakis, A.I. Merino Gamo, E. Darakas, A. Escalas-Cañellas, C. Pulgarin, Monitoring the post-irradiation E. coli survival patterns: Implications, analysis and handling, Chem. Eng. J. 253 (2014). https://doi.org/10.1016/j.cej.2014.05.092.');
 expect(r,isNotNull);expect(r!.authors[1],'Merino Gamo, A. I.');expect(r.title,'Monitoring the post-irradiation E. coli survival patterns: Implications, analysis and handling');expect(r.container,'Chem. Eng. J.');expect(r.year,'2014');expect(r.pages,isEmpty);
 final entry=CitationFormatter.buildBibliographyEntry(reference:r.copyWith(rawText:'S. Giannakis, A.I. Merino Gamo, E. Darakas, A. Escalas-Cañellas, C. Pulgarin, Monitoring the post-irradiation E. coli survival patterns: Implications, analysis and handling, Chem. Eng. J. 253 (2014). https://doi.org/10.1016/j.cej.2014.05.092.'),style:PublishCitationStyle.apa,index:1).plain;
 expect(entry,contains('Monitoring the post-irradiation'));expect(entry,contains('Merino Gamo'));expect(entry,contains('253'));
 });
 test('a year inside the title is not publication year',(){
 final r=CitationFormatter.parseBibliographicLine('A. Smith, B. Jones, Changes since 1998 in regional plants, Plant Science 12 (2019) 1-8.');
 expect(r,isNotNull);expect(r!.year,'2019');expect(r.title,'Changes since 1998 in regional plants');
 });
}
