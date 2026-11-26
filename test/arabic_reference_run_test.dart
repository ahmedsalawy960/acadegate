import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
void main(){
 test('decomposed arabic heading and page furniture keep the full bibliography',(){
 const text='Introduction\nThe study measured several classroom outcomes over two semesters with three groups of students.\n'
 'املراجع:\n'
 'الكفاوين & بني دومي تنمية التفكير الرياضي في مبحث الرياضيات لدى طلاب الصف الرابع األساسي 2018 مجلة كلية التربية\n'
 '102\n'
 'أحمد، سمية. (2019). أثر استخدام النمذجة الرياضية في تنمية مهارات التفكير الناقد. مجلة الجامعة اإلسالمية للدراسات التربوية\n'
 '105\n'
 'Nazzal, H. (2019). Athar Astiratijiat Altaelim Almutamayiz Fi Altahsil Ladaa Talibat. Journal of Educational Studies, 28(5), 929-946.\n'
 'Pape, S. (2013). Developing Mathematical Thinking and self-Regulated Learning. Journal for Research, 44(2), 100-130.\n'
 'Tretter, T. (2010). The Effectiveness of Systematic approach for Enhancing Deep Mathematical Thinking. Journal of Science, 9(1), 1-15.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,5);
 expect(refs.first.rawText,contains('الكفاوين'));
 expect(refs.last.rawText,contains('Tretter'));
 });
 test('clean numbered bibliography is unchanged',(){
 const text='Introduction\nSome body text with citations.\nReferences\n[1] Smith, A. (2020). First work. Journal of Tests, 3(1), 10-20.\n[2] Jones, B. (2021). Second work. Journal of Examples, 4(2), 30-40.\n[3] Lee, C. (2019). Third work. Journal of Samples, 2(3), 5-9.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,3);
 expect(refs[0].rawText,contains('First work'));
 expect(refs[2].rawText,contains('Third work'));
 });
 test('short body list with years does not become a bibliography',(){
 const text='Introduction\nThe project ran in three phases.\nPhase one started in 2019 with planning.\nPhase two continued in 2020 with building.\nPhase three closed in 2021 with review.\nConclusion\nThe phases completed on time and within the planned budget for the year.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs,isEmpty);
 });
}
