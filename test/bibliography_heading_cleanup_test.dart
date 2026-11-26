import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
void main(){
 test('all-caps corporate author entry is recognized',(){
 const text='O estudo analisou práticas de diagnóstico em serviços de saúde mental.\n'
 'Referências\n'
 'AMERICAN PSYCHIATRIC ASSOCIATION. DSM-5 – Manual Diagnóstico e Estatístico de Transtornos Mentais. Porto Alegre: Artmed, 2014.\n'
 'MANTOAN, M. T. E. Inclusão escolar: O que é? Por quê? Como fazer? São Paulo: Moderna, 2015.\n'
 'VYGOTSKY, L. S. A formação social da mente. São Paulo: Martins Fontes, 2008.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,3);
 expect(refs.first.rawText,contains('AMERICAN PSYCHIATRIC ASSOCIATION'));
 expect(refs.first.rawText,contains('DSM-5'));
 });
 test('glued arabic heading prefix is stripped from the first entry',(){
 final text=['هدفت هذه الدراسة إلى تقويم فعالية النمذجة الرياضية في تنمية التفكير الإبداعي لدى التلاميذ.','املراجع: ',' -509 ) : 109 ( 28ة :مجلة كلية التربي .). برنامج مقترح قائم على املدخل البصري في تنمية التفكير الرياض ي لدى طلبة املرحلة االبتدائية2017إبراهيم، رشا. (','). واقع استخدام معلمي الرياضيات الستراتيجية التعليم املتمايز من وجهة نظرهم بمكتب تعليم العرضية2019والشمراني، صالح. ( إبراهيم، عطية','مجلة كلية التربية :  ). فعالية النمذجة الرياضية في تنمية القدرة على التفكير .اإلبداعي لدى التالميذ ذوي صعوبات تعلم الحساب2018جريش، منى. ('].join('\n');
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,3);
 expect(refs.first.rawText,isNot(contains('املراجع')));
 expect(refs.first.rawText,contains('إبراهيم، رشا'));
 });
 test('short first entry line after the heading is not eaten',(){
 const text='Some concluding body text about deconvolution and imaging methods.\n'
 'References: \n'
 '1. M. P. Rimmer and J. C. Wyant, Applied Optics 14 (1), 142-150 (1975). \n'
 '2. W. J. Bates, Proceedings of the Physical Society 59 (6), 940 (1947). \n'
 '3. J. Beverage, R. Shack and M. Descour, Journal of microscopy 205 (1), 61-75 (2002). \n'
 '4. L. Seifert, J. Liesener and H. J. Tiziani, Optics Communications 216 (4), 313-319 (2003).';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,4);
 expect(refs.first.rawText,contains('Rimmer'));
 });
}
