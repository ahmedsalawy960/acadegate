import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
void main(){
 test('table minimum and graphical abstract fonts are not body rules',(){
 const guide='''The manuscript should be double-spaced.
All table columns should have headings. For larger tables, smaller fonts (no smaller than 8 pt.) may be used.
Written text in a graphical abstract should be clear. It is recommended to use fonts such as Times, Arial, Courier, Helvetica, Ubuntu, and Calibri.''';
 final rules=JournalGuidelinesHeuristic.extract(guide,requireDistinctive:false)!;
 expect(rules['bodyFontSizePt'],isNull);expect(rules['fontFamily'],isNull);
 });
 test('explicit body fonts survive a preceding table exception',(){
 const guide='''For table text use a font no smaller than 8 pt.
The manuscript must use Times New Roman font at 12 pt and be double-spaced.''';
 final rules=JournalGuidelinesHeuristic.extract(guide,requireDistinctive:false)!;
 expect(rules['bodyFontSizePt'],12);expect(rules['fontFamily'],'Times New Roman');
 });
 test('a list of recommended families is not a compulsory Arial body font',(){
 const guide='''The manuscript should be double-spaced.
It is recommended to use fonts such as Times, Arial, Courier, Helvetica, Ubuntu, and Calibri.''';
 final rules=JournalGuidelinesHeuristic.extract(guide,requireDistinctive:false)!;
 expect(rules['fontFamily'],isNull);
 });
}
