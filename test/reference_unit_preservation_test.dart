import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/bibliography_cite_aligner.dart';
void main(){
 test('a cited name inside a URL is not a new reference',(){
 final keys=InTextCiteKeys.fromBody('Evidence (Jembrana, 2021).');
 const ref='County Office. (2021). County policy. Retrieved from https://jdih.jembrana.go.id/policy';
 expect(BibliographyCiteAligner.splitByCitedWorks(ref,keys),[ref]);
 });
 test('a named website with undated publication is retained',(){
 const text='Introduction\nWebsite evidence supports this project.\nReferences\nInsight Alpha. (n.d.). INSIGHT ALPHA. Retrieved January 22, 2023, from insightalpha.com website: https://insightalpha.com/news_test.php?cid=82&sid=72&nid=211';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,1);expect(refs.single.rawText,contains('Insight Alpha'));
 });
 test('same-year suffixed works stay separate',(){
 const text='Introduction\nTwo research works support this project.\nReferences\nMAY, C., FINCH, T. & BALLINI, L. 2011a. Evaluating complex interventions. BMC Health Serv Res, 11.\nMAY, C., FINCH, T., BALLINI, L. & RAPLEY, T. 2011b. Evaluating different interventions. BMC Health Services Research, 11, 245-255.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,2);expect(refs[0].rawText,isNot(contains('2011b')));expect(refs[1].rawText,contains('2011b'));
 });
}
