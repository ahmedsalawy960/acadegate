import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
Uint8List source({bool math=true,bool quote=true,bool preview=true,bool gap=false}) {
 final xml='''<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body><w:p><w:r><w:t>Introduction to the chemical study and its scientific measurements.</w:t></w:r></w:p><w:p><w:r><w:t>Scientific experiment includes </w:t></w:r>${math?'<m:oMath><m:r><m:t>NO2</m:t></m:r></m:oMath>':''}${gap?'<w:r><w:t> unrelated prose intervenes </w:t></w:r>':''}${quote?'<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> QUOTE </w:instrText></w:r>':''}<w:r><w:pict><v:shape ${preview?'equationxml="&lt;"':''} style="width:20pt;height:12pt"><v:imagedata r:id="rId1"/></v:shape></w:pict></w:r>${quote?'<w:r><w:fldChar w:fldCharType="end"/></w:r>':''}<w:r><w:t> in water and the following scientific observations.</w:t></w:r></w:p></w:body></w:document>''';
 final a=Archive();void add(String n,List<int>b)=>a.addFile(ArchiveFile(n,b.length,b));add('word/document.xml',utf8.encode(xml));add('word/_rels/document.xml.rels',utf8.encode('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/></Relationships>'));add('word/media/image1.png',base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlWQAAAAASUVORK5CYII='));return Uint8List.fromList(ZipEncoder().encode(a));
}
void main(){
 test('OMML plus explicit QUOTE equation preview is one equation not duplicate image',()async{final p=await ManuscriptDocumentParser.parseFile(bytes:source(),filename:'qa.docx');expect(p.bodyBlocks.where((b)=>b.type==ManuscriptBlockType.equation).length,1);expect(p.bodyBlocks.where((b)=>b.type==ManuscriptBlockType.image),isEmpty);expect(p.bodyBlocks.map((b)=>b.text).join(' '),contains('following scientific observations'));});
 test('intervening prose prevents association with earlier math',()async{final p=await ManuscriptDocumentParser.parseFile(bytes:source(gap:true),filename:'qa.docx');expect(p.bodyBlocks.where((b)=>b.type==ManuscriptBlockType.image).length,1);});
 test('standalone preview without live math stays available',()async{final p=await ManuscriptDocumentParser.parseFile(bytes:source(math:false),filename:'qa.docx');expect(p.bodyBlocks.any((b)=>b.type==ManuscriptBlockType.image||b.type==ManuscriptBlockType.equation),true);});
 test('unrelated drawing after math is never removed',()async{final p=await ManuscriptDocumentParser.parseFile(bytes:source(quote:false,preview:false),filename:'qa.docx');expect(p.bodyBlocks.where((b)=>b.type==ManuscriptBlockType.image).length,1);});
}
