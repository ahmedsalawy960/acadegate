import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 test('whole-line fallback title cannot certify an unrelated author',(){
  const raw='41. Brown, M. G. Rank comparison methods. Studies Press, London (1975).';
  const r=PublishReference(type:ReferenceType.journal,id:'ref41',authors:['M. G. Rank'],title:raw,year:'1975',rawText:raw);
  for(final style in PublishCitationStyle.values){
   final text=CitationFormatter.buildBibliographyEntry(reference:r,style:style,index:41).plain;
   expect(text,contains('Brown, M. G. Rank comparison methods'));
   expect(text, isNot(contains('Rank, M. G.')));
   expect('1975'.allMatches(text).length,1);
   expect('Brown'.allMatches(text).length,1);
  }
 });
 test('accented source author mismatch falls back without losing source words',(){
  const raw='Schröder, A., Green, B. Improving regional systems. Example Publisher, London (2023).';
  const r=PublishReference(type:ReferenceType.journal,id:'ref1',authors:['B. Improving'],title:raw,year:'2023',rawText:raw);
  final text=CitationFormatter.buildBibliographyEntry(reference:r,style:PublishCitationStyle.apa,index:1).plain;
  expect(text,raw);
 });
 test('explicit corrected structured title is outside the whole-line guard',(){
  const raw='Brown, A. A complete study. Example Publisher (2020).';
  const r=PublishReference(type:ReferenceType.journal,id:'ref1',authors:['Brown, A.'],title:'An explicit corrected title',year:'2021',rawText:raw);
  final text=CitationFormatter.buildBibliographyEntry(reference:r,style:PublishCitationStyle.apa,index:1).plain;
  expect(text,contains('An explicit corrected title'));
 });
 test('references without raw source still use their structured metadata',(){
  const r=PublishReference(type:ReferenceType.journal,id:'ref1',authors:['Brown, A.'],title:'Independent observations of regional systems',year:'2021');
  final text=CitationFormatter.buildBibliographyEntry(reference:r,style:PublishCitationStyle.apa,index:1).plain;
  expect(text,contains('Brown'));
  expect(text,contains('(2021)'));
 });
 test('whole-line with a correct first author still falls back without duplication',(){
  const raw='Vicente-Serrano, S. M., Beguería, S., López-Moreno, J. I. A multiscalar drought index sensitive to global warming: The SPEI. Journal of Climate 23(7):1696-1718 (2010).';
  const r=PublishReference(type:ReferenceType.journal,id:'ref9',authors:['S. M. Vicente-Serrano','S. Beguería','J. I. López-Moreno'],title:raw,year:'2010',rawText:raw);
  final text=CitationFormatter.buildBibliographyEntry(reference:r,style:PublishCitationStyle.apa,index:9).plain;
  expect(text,contains('A multiscalar drought index'));
  expect('Vicente-Serrano'.allMatches(text).length,1);
  expect('2010'.allMatches(text).length,1);
 });
 test('numbered style keeps its index once and preserves numeric source metadata',(){
  const raw='[7] Kendall, M. G. A new measure of rank correlation. Biometrika 30(1-2):81-93 (1938).';
  const r=PublishReference(type:ReferenceType.journal,id:'ref7',authors:['M. G. Kendall'],title:raw,year:'1938',rawText:raw);
  for(final style in PublishCitationStyle.values.where(CitationFormatter.isNumberedStyle)){
   final text=CitationFormatter.buildBibliographyEntry(reference:r,style:style,index:7).plain;
   expect('7'.allMatches(text).length,greaterThanOrEqualTo(1));
   expect(text,contains('81-93'));
   expect(text,contains('Biometrika 30(1-2)'));
   expect('Kendall'.allMatches(text).length,1);
   expect('1938'.allMatches(text).length,1);
   expect(text, isNot(contains('[7] [7]')));
  }
 });
}
