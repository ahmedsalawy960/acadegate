import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
void main(){
 test('wrapped bibliography and page furniture stay out of the body',(){
 const text='The study examined how teachers diagnose student errors in algebra classrooms across three schools.\n'
 'Each lesson was recorded and coded against a validated observation rubric over one full semester.\n'
 '\n'
 'Ball, D., Hill, H., & Schilling, S. (2008). Unpacking Pedagogical Content Knowledge:\n'
 'Conceptualizing and Measuring Teachers Topic-Specific Knowledge of Students. Journal for\n'
 'Research in Mathematics Education, 39(4), 372-400.\n'
 '78\n'
 'Atkinson, R., Derry, S., Renkl, A., & Wortham, D.\n'
 '(2000). Learning from examples: Instructional principles.\n'
 'Luo, Z., & Peng, A. (2009). A Framework for Examining Mathematics Teacher Knowledge. Journal of Math Education, 10(3), 1-15.\n'
 'Radatz, H. (1979). Error Analysis in Mathematics Education. Journal for Research, 2(3), 163-172.\n'
 'Cheng, F. (2012). Error Analysis in Mathematics. Mathematics Education, 10(3), 20-35.';
 final parsed=ManuscriptDocumentParser.parsePlainTextForTest(text);
 expect(parsed.references.length,greaterThanOrEqualTo(3));
 expect(parsed.references.last.rawText,contains('Cheng, F.'));
 expect(parsed.bodyText,isNot(contains('Ball, D.')));
 expect(parsed.bodyText,isNot(contains('Atkinson, R.')));
 expect(parsed.bodyText,contains('observation rubric'));
 });
 test('portuguese references heading is recognized',(){
 const text='O estudo analisou a inclusão escolar de estudantes com transtornos do neurodesenvolvimento em escolas públicas.\n'
 'Referências\n'
 'MANTOAN, M. T. E. Inclusão escolar: O que é? Por quê? Como fazer? São Paulo: Moderna, 2015.\n'
 'PLETSCH, M. D. Educação Inclusiva e Atendimento Educacional Especializado. Rio de Janeiro: Wak, 2010.\n'
 'VYGOTSKY, L. S. A formação social da mente. São Paulo: Martins Fontes, 2008.';
 final refs=ManuscriptDocumentParser.parseReferencesFromText(text);
 expect(refs.length,3);
 expect(refs.first.rawText,contains('MANTOAN'));
 });
 test('body prose with citations does not absorb into a bibliography',(){
 const text='The project ran in three phases across two years of fieldwork with monthly interviews.\n'
 'In the first cohort of students, growth was steady during the autumn term of 2019.\n'
 'A larger sample confirmed the same pattern during the following spring of 2020.\n'
 'The final report summarized both waves of data collection and their limitations.';
 final parsed=ManuscriptDocumentParser.parsePlainTextForTest(text);
 expect(parsed.references,isEmpty);
 expect(parsed.bodyText,contains('growth was steady during the autumn term'));
 expect(parsed.bodyText,contains('limitations'));
 });
}
