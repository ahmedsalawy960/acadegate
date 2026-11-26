import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 test('more than500 body paragraphs remain in original order',(){
 final blocks=List.generate(700,(i)=>ManuscriptBlock(id:'p$i',type:ManuscriptBlockType.paragraph,text:'Scientific paragraph $i contains unique measurements and interpretation.'));
 final out=ManuscriptDocumentParser.sanitizeImportedBlocks(blocks);expect(out.length,700);expect(out.map((b)=>b.id),blocks.map((b)=>b.id));expect(out.last.text,contains('699'));
 });
 test('long body text is not clipped at character cap',(){
 final text='${List.filled(120001,'x').join()} preserved ending';final out=ManuscriptDocumentParser.sanitizeImportedBlocks([ManuscriptBlock(id:'a',type:ManuscriptBlockType.paragraph,text:text)]);expect(out.single.text,text);
 });
 test('more than200 reference works remain available',(){
 final refs=List.generate(240,(i)=>PublishReference(id:'r$i',type:ReferenceType.journal,authors:['Researcher$i, A.'],title:'Scientific study $i',year:'2020',rawText:'Researcher$i, A. (2020). Scientific study $i. Journal, 1, 1-5.'));
 final out=ManuscriptDocumentParser.sanitizeImportedReferences(refs);expect(out.length,240);expect(out.last.title,'Scientific study 239');
 });
 test('long raw reference content is not replaced with shortening notice',(){
 final raw='Smith, A. (2020). ${List.filled(20001,'x').join()} unique final DOI';final out=ManuscriptDocumentParser.sanitizeImportedReferences([PublishReference(id:'r',type:ReferenceType.journal,title:'Study',rawText:raw)]);expect(out.single.rawText,raw);
 });
}
