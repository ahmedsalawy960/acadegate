import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
void main(){
 test('Vancouver title year is not publication year or title boundary',(){
 final ref=CitationFormatter.parseBibliographicLine('Taunton JE, Ryan MB, Clement DB, et al. A retrospective case-control analysis of 2002 running injuries. Br J Sports Med. 2002;36(2):95-102.');
 expect(ref,isNotNull);expect(ref!.authors.first,'Taunton JE');expect(ref.authors.length,3);expect(ref.title,'A retrospective case-control analysis of 2002 running injuries');expect(ref.year,'2002');expect(ref.container,'Br J Sports Med');expect(ref.volume,'36');expect(ref.pages,'95-102');
 });
 test('Vancouver publication year can differ from year inside title',(){
 final ref=CitationFormatter.parseBibliographicLine('Messier SP, Davis SE, Curl WW, Lowert RB, Pack RJ. Follow-up of 1988 runners. Med Sci Sports Exerc. 1991;23:1008-1015.');
 expect(ref,isNotNull);expect(ref!.title,'Follow-up of 1988 runners');expect(ref.year,'1991');expect(ref.authors.first,'Messier SP');
 });
 test('DOI after Vancouver reference does not become publication year',(){
 final ref=CitationFormatter.parseBibliographicLine('Smith AB, Jones CD. A controlled study of health outcomes. Testing Medicine. 2014;12(3):45-52. https://doi.org/10.1000/2020.123');
 expect(ref,isNotNull);expect(ref!.year,'2014');expect(ref.title,'A controlled study of health outcomes');expect(ref.doi,'10.1000/2020.123');
 });
 test('Unicode surname and issue-only source preserve author and title',(){
 final ref=CitationFormatter.parseBibliographicLine('O’Connor KM, Hamill J. Does Running on a cambered road predispose a runner to injury? J Appl Biomech. 2002;(18):3-14.');
 expect(ref,isNotNull);expect(ref!.authors.first,'O’Connor KM');expect(ref.title,startsWith('Does Running'));expect(ref.issue,'18');expect(ref.volume,isEmpty);
 });
}
