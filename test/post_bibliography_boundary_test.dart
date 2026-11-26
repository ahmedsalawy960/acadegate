import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
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
 for(final heading in ['Acknowledgments','Acknowledgements','Funding','Ethical Approval','Ethics statement','Author contributions','CONTRIBUCIÓN DE LA AUTORÍA:','Contribuciones de los autores','Financiamiento','Declaración de conflicto de intereses','الشكر والتقدير','مساهمات المؤلفين']){
 test('post-reference declaration stops harvest and stays in body: $heading',(){
 final tail='$heading\n1. Conceptualización: A. Researcher\nSmith, C. (2024). Declared support, not a bibliography entry.\n';
 final refs=ManuscriptDocumentParser.parseReferencesFromText('$lead$tail');
 expect(refs.length,2);expect(refs.last.rawText,isNot(contains(heading)));
 final blocks=ManuscriptDocumentParser.structureImportedBlocks([
 ManuscriptBlock(id:'bib',type:ManuscriptBlockType.heading,text:'References'),
 ManuscriptBlock(id:'ref',type:ManuscriptBlockType.paragraph,text:'Smith, A. (2020). A scientific investigation of plants. Plant Research, 2, 12-20.'),
 ManuscriptBlock(id:'tail',type:ManuscriptBlockType.paragraph,text:heading),
 ManuscriptBlock(id:'declaration',type:ManuscriptBlockType.paragraph,text:'1. Conceptualización: A. Researcher'),
 ManuscriptBlock(id:'support',type:ManuscriptBlockType.paragraph,text:'Smith, C. (2024). Declared support, not a bibliography entry.'),
 ]);
 expect(blocks.map((b)=>b.id),containsAll(['tail','declaration','support']));
 expect(blocks.any((b)=>b.id=='ref'),false);
 });}
 test('declaration words in a reference title or organization do not end harvest',(){
 final refs=ManuscriptDocumentParser.parseReferencesFromText('$lead'
 'Funding Research Council. (2022). Ethics statement and author contributions in science. Research Press.\n'
 'Acknowledgments in Research. (2023). A valid organizational report. Science Press.\n');
 expect(refs.length,4);expect(refs.last.rawText,contains('Acknowledgments in Research'));
 });

 for(final bibHeading in ['References','Referencias']){
 test('DOCX $bibHeading keeps declaration headings and numbered contribution prose',()async{
 const r1='Smith, A. (2020). A scientific investigation of plants. Plant Research, 2, 12-20.';
 const r2='Jones, B. (2021). A second scientific investigation. Science, 3, 30-40.';
 final paragraphs=['Introduction','Important original scientific conclusion and body text.',bibHeading,r1,r2,
 bibHeading=='References'?'Acknowledgments':'CONTRIBUCIÓN DE LA AUTORÍA:',
 '1. Conceptualización: A. Researcher','Funding','This research received no external funding.',
 'Ethical Approval','Participants provided written informed consent.'];
 // ignore: prefer_interpolation_to_compose_strings
 final xml='<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'
 +paragraphs.map((p)=>'<w:p><w:r><w:t>$p</w:t></w:r></w:p>').join()+'</w:body></w:document>';
 final bytes=utf8.encode(xml);final archive=Archive()..addFile(ArchiveFile('word/document.xml',bytes.length,bytes));
 final parsed=await ManuscriptDocumentParser.parseFile(bytes:Uint8List.fromList(ZipEncoder().encode(archive)),filename:'qa.docx');
 expect(parsed.references.length,2);expect(parsed.references.last.rawText,isNot(contains('Conceptualización')));
 final body=parsed.bodyBlocks.map((b)=>b.text).join('\n');
 expect(body,contains(paragraphs[5]));expect(body,contains('1. Conceptualización: A. Researcher'));
 expect(body,contains('Funding'));expect(body,contains('Ethical Approval'));
 expect(body,contains('Participants provided written informed consent.'));
 expect(body,isNot(contains('A second scientific investigation')));
 });}

}
