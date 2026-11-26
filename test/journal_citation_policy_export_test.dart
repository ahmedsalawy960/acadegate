import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){test('optional named style cannot cause automatic formatted DOCX',()async{
 final e=JournalGuidelinesHeuristic.extract('Manuscript must be double-spaced. References may be in any style. We suggest APA style as the closest match.',requireDistinctive:false)!;
 final r=JournalFormatRules.fromExtracted(journalName:'QA',sourceUrl:'qa',extracted:e);
 final m=PublishManuscript(userId:'qa',title:'Source title',body:'Original scientific text [1].',references:const[PublishReference(id:'r',type:ReferenceType.journal,title:'Original work',rawText:'Smith A. Original work. Science. 2020;2:1-4.')]);
 await expectLater(ManuscriptDocxExportService.instance.buildDocx(manuscript:m,rules:r),throwsStateError);
 final chosen=r.withCitationStyle(PublishCitationStyle.vancouver);final bytes=await ManuscriptDocxExportService.instance.buildDocx(manuscript:m,rules:chosen);expect(bytes.length,greaterThan(1000));expect(m.references.single.rawText,'Smith A. Original work. Science. 2020;2:1-4.');
});}
