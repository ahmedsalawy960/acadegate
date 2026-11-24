import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/citation_linker.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main() {
 const refs=[
 PublishReference(id:'a',type:ReferenceType.journal,authors:['Alegria, C. A.'],title:'Identity and health care',year:'2011'),
 PublishReference(id:'b',type:ReferenceType.journal,authors:['Bauer, G. R.'],title:'Health care barriers',year:'2009'),
 PublishReference(id:'r',type:ReferenceType.journal,authors:['Roberts, T. K.','Fantz, C. R.'],title:'Barriers to care',year:'2014'),
 ];
 test('comma-separated three-work group preserves every cited work',(){
 final text=CitationLinker.linkTextWithRefs('Evidence (Alegria, 2011, Bauer et al., 2009, Roberts and Fantz, 2014).',refs);
 for(final id in ['a','b','r']){expect(text,contains('{{cite:$id}}'));}
 });
 test('semicolon-separated group still preserves every cited work',(){
 final text=CitationLinker.linkTextWithRefs('Evidence (Alegria, 2011; Bauer et al., 2009; Roberts and Fantz, 2014).',refs);
 for(final id in ['a','b','r']){expect(text,contains('{{cite:$id}}'));}
 });
 test('partly unresolved comma group stays intact instead of losing siblings',(){
 const text='Evidence (Alegria, 2011, Unknown et al., 2009, Roberts and Fantz, 2014).';
 expect(CitationLinker.linkTextWithRefs(text,refs),text);
 });
 test('partly unresolved semicolon group stays intact',(){
 const text='Evidence (Alegria, 2011; Unknown et al., 2009; Roberts and Fantz, 2014).';
 expect(CitationLinker.linkTextWithRefs(text,refs),text);
 });
 test('commas within author lists do not split a single work',(){
 final text=CitationLinker.linkTextWithRefs('Evidence (Roberts and Fantz, 2014).',refs);
 expect(text,'Evidence {{cite:r}}.');
 });
}
