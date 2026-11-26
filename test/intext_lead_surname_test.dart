import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 test('whole-line reference with a word from inside the line as author uses the source lead name',(){
  const raw='[14]Lambert,A. The branching process with logistic growth, Ann. Appl.Probab.,15, no. 2, 1506-1535, (2005).';
  const r=PublishReference(type:ReferenceType.journal,id:'ref14',authors:['A. The'],title:raw,year:'2005',rawText:raw);
  final text=CitationFormatter.formatInText(reference:r,style:PublishCitationStyle.apa,index:14);
  expect(text,'(Lambert, 2005)');
 });
 test('whole-line reference with a correct lead author keeps the full author list',(){
  const raw='[18]Wang,J.,Yang,Y.,Mao,J.,Huang,Z.,Huang,C.,&Xu,W.(2016). Cnn-rnn: A unified framework for multi-label image classification. CVPR 2016.';
  const r=PublishReference(type:ReferenceType.journal,id:'ref18',authors:['J. Wang','Y. Yang','J. Mao','Z. Huang','C. Huang','W. Xu'],title:raw,year:'2016',rawText:raw);
  final text=CitationFormatter.formatInText(reference:r,style:PublishCitationStyle.apa,index:18);
  expect(text,'(Wang et al., 2016)');
 });
 test('structured reference with a real title keeps its parsed authors',(){
  const raw='Lambert, A. (2005). The branching process with logistic growth. Annals of Applied Probability, 15(2), 1506-1535.';
  const r=PublishReference(type:ReferenceType.journal,id:'ref1',authors:['A. Lambert'],title:'The branching process with logistic growth',year:'2005',rawText:raw);
  final text=CitationFormatter.formatInText(reference:r,style:PublishCitationStyle.apa,index:1);
  expect(text,'(Lambert, 2005)');
 });
 test('publisher or journal words are not used as in-text surnames',(){
  const raw='Greechie, R.J.: Orthogonal lattices admitting no states. J. Combin. Theory 10, 119-132 (1971)';
  const r=PublishReference(type:ReferenceType.journal,id:'ref2',authors:['Combin'],title:raw,year:'1971',rawText:raw);
  final text=CitationFormatter.formatInText(reference:r,style:PublishCitationStyle.apa,index:2);
  expect(text,'(Greechie, 1971)');
 });
}
