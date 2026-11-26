import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
void main(){
 const corruptFront='183–\n &\nداد إـع\n &\nباحثات بقسم دراسات الطفولة مسار صعوبات التعلم في الطفولة المبكرة \nكلية علوم اإلنسان والتصاميم، جامعة الملك عبد العزيز\nأستاذ مشارك بقسم دراسات الطفولة \nيـــ ل ه واقعـ ق الـل التطبيـابـل مقـ ام ـم الشـام التعلي جهينة الحكمي &رزان النعمان &سهام مشوف\nباحثات بقسم دراسات الطفولة';
 const cleanFront='أثر التدريس باستخدام النمذجة الرياضية والتعليم المتمايز في تنمية التفكير الرياضي في مبحث الرياضيات لدى طلاب الصف الأساسي\nملخص الدراسة\nهدفت هذه الدراسة إلى قياس أثر التدريس باستخدام النمذجة الرياضية والتعليم المتمايز في تنمية التفكير الرياضي لدى طلاب الصفوف الأساسية في لواء المزار الجنوبي';
 test('detector fires on decomposed arabic front matter',(){
  expect(ManuscriptDocumentParser.hasDecomposedArabicFrontMatter(corruptFront),isTrue);
 });
 test('detector stays quiet on clean arabic and on latin text',(){
  expect(ManuscriptDocumentParser.hasDecomposedArabicFrontMatter(cleanFront),isFalse);
  expect(ManuscriptDocumentParser.hasDecomposedArabicFrontMatter('A study of measured outcomes in classroom settings with several groups of students over two semesters'),isFalse);
 });
 test('corrupt front matter leaves the imported title empty',()async{
  final parsed=ManuscriptParseResult(sourceTitle:'Juhainah Alhakami & Rzan Alnoman & Seham Mashuf &',fullText:corruptFront,bodyText:corruptFront,references:const []);
  final applied=await ManuscriptDocumentParser.applyParseResult(manuscript:const PublishManuscript(userId:'t',title:''),parsed:parsed,replaceReferences:true,replaceBody:true);
  expect(applied.title,'');
 });
 test('corrupt front matter never overwrites a user-entered title',()async{
  final parsed=ManuscriptParseResult(sourceTitle:'Juhainah Alhakami & Rzan Alnoman & Seham Mashuf &',fullText:corruptFront,bodyText:corruptFront,references:const []);
  final applied=await ManuscriptDocumentParser.applyParseResult(manuscript:const PublishManuscript(userId:'t',title:'My study of classroom outcomes'),parsed:parsed,replaceReferences:true,replaceBody:true);
  expect(applied.title,'My study of classroom outcomes');
 });
 test('clean arabic source title still imports',()async{
  const title='أثر التدريس باستخدام النمذجة الرياضية والتعليم المتمايز في تنمية التفكير الرياضي';
  final parsed=ManuscriptParseResult(sourceTitle:title,fullText:cleanFront,bodyText:cleanFront,references:const []);
  final applied=await ManuscriptDocumentParser.applyParseResult(manuscript:const PublishManuscript(userId:'t',title:''),parsed:parsed,replaceReferences:true,replaceBody:true);
  expect(applied.title,title);
 });
}
