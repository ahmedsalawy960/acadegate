import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:acadegate/features/acadegate_publish/docx_title_reader.dart';

String p(String text, int size) =>
    '<w:p><w:r><w:rPr><w:sz w:val="$size"/></w:rPr><w:t>${XmlText(text).toXmlString()}</w:t></w:r></w:p>';
Uint8List doc(String body) {
  final b = utf8.encode(
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>',
  );
  return Uint8List.fromList(
    ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('word/document.xml', b.length, b)),
    ),
  );
}

void main() {
  test('Arabic journal strip cannot outweigh a scientific title', () {
    const t = 'تقنيات مستقلة لدراسة التحولات التعليمية في المدارس';
    expect(
      DocxTitleReader.read(
        doc(
          p('المجلّة الدّوليّة للبحث والتطوير التربوي', 48) +
              p(t, 32) +
              p('د. سليم أحمد مصطفى', 30) +
              p('ملخص البحث', 28),
        ),
      ),
      t,
    );
  });
  test('Arabic issue strip and byline cannot outweigh a title', () {
    const t = 'أثر الذكاء الاصطناعي في تنمية مهارات التعليم';
    expect(
      DocxTitleReader.read(
        doc(
          p(')، لسنة2025 ( ، العدد4 مجلة أبحاث كلية التربية ، المجلد19', 24) +
              p(t, 40) +
              p('قسم تقنيات التعليم، كلية التربية، جامعة مستقلة', 28) +
              p('ملخص البحث: النص يوضح الأسلوب المستخدم في الدراسة.', 24),
        ),
      ),
      t,
    );
  });
  test('stretched Arabic abstract heading stops scanning', () {
    expect(
      DocxTitleReader.read(
        doc(
          p('د/ سالم مصطفى & د/ فؤاد أحمد', 30) +
              p('ملخــــــــــص الدراسة تتناول أساليب مختلفة للتعليم', 28) +
              p('هذه فقرة طويلة من الملخص لا يجب اختيارها عنوانا للبحث', 40),
        ),
      ),
      isNull,
    );
  });
  test('small split title needs grammatical continuation cue', () {
    const t =
        'Evidence of Learning Strategies in the First Three Grades in Independent School Districts';
    expect(
      DocxTitleReader.read(
        doc(
          p('Evidence of Learning Strategies in the First', 24) +
              p('Three Grades in Independent School Districts', 24) +
              p('Abstract', 20),
        ),
      ),
      t,
    );
  });
  test('Arabic journal as scientific topic is not rejected everywhere', () {
    const t = 'دور المجلات العلمية في نشر البحوث التربوية الحديثة';
    expect(DocxTitleReader.read(doc(p(t, 36) + p('الملخص', 24))), t);
  });
  test('distinct title size separates an attached affiliation', () {
    const t = 'منهج مستقل لقياس أثر التقنية في التعليم';
    final body =
        '<w:p><w:r><w:rPr><w:sz w:val="34"/></w:rPr><w:t>$t</w:t></w:r><w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t>د. سامي أحمد، قسم تقنيات التعليم، كلية التربية، جامعة مستقلة</w:t></w:r></w:p>';
    expect(DocxTitleReader.read(doc(body + p('الملخص', 24))), t);
  });
}
