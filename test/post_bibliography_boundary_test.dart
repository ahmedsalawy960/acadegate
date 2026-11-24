import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 const lead='Introduction\nEvidence supports this study (Smith, 2020).\nReferences\nSmith, A. (2020). A scientific investigation of plants. Plant Research, 2, 12-20.\nJones, B. (2021). A second scientific investigation. Science, 3, 30-40.\n';
 for(final heading in ['Supplementary Materials','APPENDICES','Tables','Figure legends']){
 test('reference harvest ends before $heading',(){
 final refs=ManuscriptDocumentParser.parseReferencesFromText('$lead$heading\nA separate procedure was developed in 2022 to measure plants.\nBrown, C. (2023). This is a supplementary example, not the main bibliography.\n');
 expect(refs.length,2);expect(refs.last.rawText,isNot(contains(heading)));expect(refs.any((r)=>r.rawText.contains('supplementary example')),false);
 });}
 test('supplementary bibliographic examples remain body blocks',(){
 final blocks=ManuscriptDocumentParser.structureImportedBlocks([
 ManuscriptBlock(id:'a',type:ManuscriptBlockType.paragraph,text:'Main scientific text.'),
 ManuscriptBlock(id:'b',type:ManuscriptBlockType.heading,text:'References'),
 ManuscriptBlock(id:'c',type:ManuscriptBlockType.paragraph,text:'Smith, A. (2020). A scientific investigation of plants. Plant Research, 2, 12-20.'),
 ManuscriptBlock(id:'d',type:ManuscriptBlockType.heading,text:'Supplementary Materials'),
 ManuscriptBlock(id:'e',type:ManuscriptBlockType.paragraph,text:'Brown, C. (2023). This is a supplementary example, not the main bibliography.'),
 ]);
 expect(blocks.any((b)=>b.id=='c'),false);expect(blocks.any((b)=>b.id=='d'),true);expect(blocks.any((b)=>b.id=='e'),true);
 });
 test('a paper title beginning Appendix is not a section boundary',(){
 final refs=ManuscriptDocumentParser.parseReferencesFromText('${lead}Appendix Research Group. (2022). A valid organizational report. Plant Press.');
 expect(refs.length,3);expect(refs.last.rawText,contains('Appendix Research Group'));
 });
}
