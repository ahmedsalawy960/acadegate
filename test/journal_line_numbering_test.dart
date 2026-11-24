import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 test('explicit continuous line numbering reaches all export sections',()async{
 final extracted=JournalGuidelinesHeuristic.extract('''Author guidelines. The manuscript should be double-spaced.
Include page numbers and line numbers in the manuscript file. Use continuous line numbers (do not restart the numbering on each page).''',requireDistinctive:false)!;
 expect(extracted['continuousLineNumbers'],true);
 final rules=JournalFormatRules.fromExtracted(journalName:'QA',sourceUrl:'qa',extracted:extracted).copyWith(columnCount:2);
 final bytes=await ManuscriptDocxExportService.instance.buildDocx(manuscript:PublishManuscript(userId:'qa',title:'Line number test',bodyBlocks:[ManuscriptBlock(id:'a',type:ManuscriptBlockType.heading,text:'Introduction'),ManuscriptBlock(id:'b',type:ManuscriptBlockType.paragraph,text:'A scientific paragraph for line numbering.')]),rules:rules);
 final archive=ZipDecoder().decodeBytes(bytes);final xml=utf8.decode(archive.findFile('word/document.xml')!.content as List<int>);
 expect(RegExp(r'<w:lnNumType\b').allMatches(xml).length,RegExp(r'<w:sectPr>').allMatches(xml).length);
 expect(xml,contains('w:restart="continuous"'));
 final footer=utf8.decode(archive.findFile('word/footer1.xml')!.content as List<int>);expect(footer,contains('<w:suppressLineNumbers/>'));expect(xml,isNot(contains('w:restart="newPage"')));
 });
 test('unrequested line numbers are not added',()async{
 final bytes=await ManuscriptDocxExportService.instance.buildDocx(manuscript:PublishManuscript(userId:'qa',title:'Plain manuscript'),rules:JournalFormatRules.forStudentStyle(PublishCitationStyle.apa));
 final xml=utf8.decode(ZipDecoder().decodeBytes(bytes).findFile('word/document.xml')!.content as List<int>);expect(xml,isNot(contains('<w:lnNumType')));
 });
 test('supplement-only and optional line numbering do not enable main numbering',(){
 for(final text in ['The manuscript is double-spaced. Supplementary material must contain continuous line numbers.','The manuscript is double-spaced. Authors may use continuous line numbers.','The manuscript is double-spaced. Do not use continuous line numbers.']){
 final extracted=JournalGuidelinesHeuristic.extract(text,requireDistinctive:false)!;expect(extracted['continuousLineNumbers'],isNot(true));
 }
 });
}
