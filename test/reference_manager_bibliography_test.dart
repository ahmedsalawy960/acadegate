import 'package:acadegate/features/acadegate_publish/citation_formatter.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
Uint8List source(String field,{bool inlineProse=false,bool nestedField=false}){
 final rows=['Alpha, A. (2020). A scientific environmental study. Science, 2, 1-3.','Beta, B. (2021). A second environmental study. Ecology, 3, 4-6.','Gamma, C. (2022). A third environmental study. Research, 4, 7-9.','European Commission (EC) (2019). An environmental institutional report. Publications Office.','Delta, D. (2020). A scientific environmental study. Science, 2, 1-3.','Epsilon, E. (2021). A second environmental study. Ecology, 3, 4-6.','Zeta, F. (2022). A third environmental study. Research, 4, 7-9.'];
 // ignore: prefer_interpolation_to_compose_strings
 final xml='<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Introduction</w:t></w:r></w:p><w:p><w:r><w:t>Scientific body text describes measurements and ecological observations with author and date citations.</w:t></w:r></w:p>'+[for(var i=0;i<rows.length;i++)'<w:p>${i==0&&inlineProse?'<w:r><w:t>Important final scientific conclusion before the field.</w:t></w:r>':''}${i==0?'<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText>$field</w:instrText></w:r>':''}${nestedField&&i==1?'<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK </w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>':''}<w:r><w:t>${rows[i]}</w:t></w:r>${i==rows.length-1?'<w:r><w:fldChar w:fldCharType="end"/></w:r>':''}${i==rows.length-1&&inlineProse?'<w:r><w:t>Important trailing scientific note after the field.</w:t></w:r>':''}</w:p>'].join()+'<w:p><w:r><w:t>Supplementary Materials</w:t></w:r></w:p><w:p><w:r><w:t>A separate scientific procedure remains outside the reference field.</w:t></w:r></w:p></w:body></w:document>';
 final bytes=utf8.encode(xml);return Uint8List.fromList(ZipEncoder().encode(Archive()..addFile(ArchiveFile('word/document.xml',bytes.length,bytes))));
}
void main(){formattingTests();
 test('field removal keeps same-paragraph prose and handles nested fields',()async{
 final p=await ManuscriptDocumentParser.parseFile(bytes:source('ADDIN Mendeley Bibliography CSL_BIBLIOGRAPHY',inlineProse:true,nestedField:true),filename:'qa.docx');
 final body=p.bodyBlocks.map((b)=>b.text).join(' ');
 expect(body,contains('Important final scientific conclusion'));expect(body,contains('Important trailing scientific note'));expect(body,isNot(contains('Beta,')));expect(body,isNot(contains('Zeta,')));
 });
 for(final field in ['ADDIN Mendeley Bibliography CSL_BIBLIOGRAPHY','ADDIN ZOTERO_BIBL { }']){test('headingless $field keeps first bibliography rows',()async{final p=await ManuscriptDocumentParser.parseFile(bytes:source(field),filename:'qa.docx');expect(p.references.length,7);expect(p.references.first.rawText,startsWith('Alpha,'));expect(p.references.last.rawText,startsWith('Zeta,'));expect(p.bodyText,contains('Scientific body text'));expect(p.bodyBlocks.map((b)=>b.text).join(' '),isNot(contains('Alpha,')));expect(p.bodyBlocks.map((b)=>b.text).join(' '),contains('separate scientific procedure'));});}}

// Source fallback is intentional until this Harvard grammar is supported.
void formattingTests(){
 test('Harvard quote and abbreviated author list preserve the original work',(){
 const raw='Boobis, A. et al. (2011) ‘Critical analysis of chemical mixtures’, Critical Reviews in Toxicology, pp. 369–383. doi: 10.3109/10408444.2010.543655.';
 for(final style in [PublishCitationStyle.apa,PublishCitationStyle.ieee]){
 final out=CitationFormatter.buildBibliographyEntry(reference:const PublishReference(id:'r',type:ReferenceType.journal,title:'',rawText:raw),style:style,index:1).plain;
 expect(out,style==PublishCitationStyle.ieee?'[1] $raw':raw);
 }
 });
}
