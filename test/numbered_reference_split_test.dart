import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
void main(){
 test('numbered reference fused to its predecessor is split apart',(){
 const text='Introduction\nSome body text with citations.\nReferences\n[35]Schuster,M.,&Paliwal,K.K.(1997).Bidirectionalrecurrentneural networks.IEEEtransactionsonSignalProcessing,45(11),2673-2681. [36]Wang,C.,Yang,H.,Bartz,C.,&Meinel,C.(2016,October).Image captioning with deep bidirectional LSTMs.InProceedingsoftheACMMultimedia.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,2);
 expect(refs[0].rawText,contains('Schuster'));
 expect(refs[0].rawText,isNot(contains('Wang,C.')));
 expect(refs[1].rawText,contains('Wang,C.'));
 });
 test('bracket number followed directly by an author still splits',(){
 const text='Introduction\nSome body text with citations.\nReferences\n[29]Kingma DP, Ba J.Adam:A method for stochastic optimization.arXivpreprintarXiv:1412.6980. [30]Baldi P, Sadowski PJ.Understanding dropout.In:Advances in neural information processing systems.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,2);
 expect(refs[0].rawText,contains('Kingma'));
 expect(refs[1].rawText,contains('Baldi'));
 });
 test('a well-formed numbered list is unchanged',(){
 const text='Introduction\nSome body text with citations.\nReferences\n[1] Smith, A. (2020). First work. Journal of Tests, 3(1), 10-20.\n[2] Jones, B. (2021). Second work. Journal of Examples, 4(2), 30-40.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,2);
 expect(refs[0].rawText,contains('First work'));
 expect(refs[1].rawText,contains('Second work'));
 });
 test('a bracket token without a preceding word break is not a split',(){
 const text='Introduction\nSome body text with citations.\nReferences\n[7] Chen, D. (2018). Reproducing the setup-of-[3]Kumar configuration with larger batches. Journal of Replications, 9(1), 1-9.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.single.rawText,contains('Reproducing'));
 });
}
