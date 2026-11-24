import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
void main(){
 test('font label list inherits artwork section scope',(){
 final r=JournalGuidelinesHeuristic.extract('''The manuscript is double-spaced.
## Figures and tables
Suggested style for figure labels:
- Font: Times New Roman
- 9pt font, 11pt leading is preferred.
## Main text
Use clear scientific language.''',requireDistinctive:false)!;
 expect(r['fontFamily'],isNull);expect(r['bodyFontSizePt'],isNull);
 });
 test('chemical atom labels never set body font',(){
 final r=JournalGuidelinesHeuristic.extract('''The manuscript is single-spaced.
## Preparing figures
### Chemical structures
Drawing settings: chain angle, 120 degrees.
Atom label settings: font, Arial; size, 8 pt''',requireDistinctive:false)!;
 expect(r['fontFamily'],isNull);expect(r['bodyFontSizePt'],isNull);
 });
 test('body section after artwork can set font',(){
 final r=JournalGuidelinesHeuristic.extract('''## Figures
Font: Arial, 8 pt.
## Manuscript formatting
The text must use Times New Roman font, 12 pt and double spacing.''',requireDistinctive:false)!;
 expect(r['fontFamily'],'Times New Roman');expect(r['bodyFontSizePt'],12);
 });
 test('unheaded explicit body font remains valid',(){
 final r=JournalGuidelinesHeuristic.extract('The manuscript must use Arial font at 11 pt and double spacing.',requireDistinctive:false)!;
 expect(r['fontFamily'],'Arial');expect(r['bodyFontSizePt'],11);
 });
}
