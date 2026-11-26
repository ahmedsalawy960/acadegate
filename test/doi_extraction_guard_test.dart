import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
void main(){
 test('a real doi after a doi prefix is kept',(){
 final ref=CitationFormatter.parseBibliographicLine('Smith AB, Jones CD. A controlled study of health outcomes. Testing Medicine. 2014;12(3):45-52. doi:10.1000/2020.123');
 expect(ref,isNotNull);expect(ref!.doi,'10.1000/2020.123');
 });
 test('a full doi url is kept in bare form',(){
 final ref=CitationFormatter.parseBibliographicLine('Smith AB, Jones CD. A controlled study of health outcomes. Testing Medicine. 2014;12(3):45-52. https://doi.org/10.1000/2020.123');
 expect(ref,isNotNull);expect(ref!.doi,'10.1000/2020.123');
 });
 test('an author block after a dangling doi prefix is not a doi',(){
 final ref=CitationFormatter.parseBibliographicLine('Drout,M.R.,Massey,P.,&Meynet,G. 2012,ApJ,750,97, doi:Drout.M.R..Massey.P..Meynet.G..');
 if(ref!=null) expect(ref.doi,isEmpty);
 });
 test('a dangling doi prefix at line end is not a doi',(){
 final ref=CitationFormatter.parseBibliographicLine('Aadland,E.,Massey,P.,Neugent,K.F.,&Drout,M.R.2018,AJ,156,294, doi:');
 if(ref!=null) expect(ref.doi,isEmpty);
 });
}
