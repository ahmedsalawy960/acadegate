import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 BibliographyEntry entry(String doi)=>CitationFormatter.buildBibliographyEntry(
  reference:PublishReference(type:ReferenceType.journal,id:'r1',authors:['A. Solver'],title:'Independent measured outcomes',container:'Journal of Tests',year:'2021',volume:'3',issue:'1',pages:'10-20',doi:doi),
  style:PublishCitationStyle.apa,index:1);
 test('bare doi prints once',(){
  expect(entry('10.1000/xyz123').plain,contains('https://doi.org/10.1000/xyz123'));
 });
 test('full url doi is not doubled',(){
  final t=entry('https://doi.org/10.1000/xyz123').plain;
  expect('https://doi.org/'.allMatches(t).length,1);
  expect(t,contains('https://doi.org/10.1000/xyz123'));
 });
 test('doi-prefix forms are normalized',(){
  expect('https://doi.org/'.allMatches(entry('doi:10.1000/xyz123').plain).length,1);
  expect('https://doi.org/'.allMatches(entry('doi.org/10.1000/xyz123').plain).length,1);
 });
 test('non-doi field text never becomes a doi link',(){
  for(final bad in [':','Drout','.URL:','18']){
   expect(entry(bad).plain, isNot(contains('doi.org/')));
  }
 });
}
