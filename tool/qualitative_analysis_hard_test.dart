/// اختبار سريع لمسار 3 — التحليل النوعي.
/// تشغيل: dart run tool/qualitative_analysis_hard_test.dart
import 'package:acadegate/features/qualitative_analysis/qualitative_models.dart';

void main() {
  var failed = 0;
  failed += _sec('قالب المشروع', _template);
  failed += _sec('ترميز/فك ترميز', _roundTrip);
  failed += _sec('سيناريو أدبي صعب — مدينة محفوظ', _hardLiterary);
  failed += _sec('ملخص المنهجية', _summary);

  print('');
  print(failed == 0
      ? 'النتيجة: نجاح كل اختبارات التحليل النوعي.'
      : 'النتيجة: فشل $failed اختبار(ات).');
}

int _sec(String name, void Function() fn) {
  try {
    fn();
    print('صح — $name');
    return 0;
  } catch (e) {
    print('خطأ — $name\n  $e');
    return 1;
  }
}

void _expect(bool c, String m) {
  if (!c) throw StateError(m);
}

void _template() {
  final p = QualProject.template();
  _expect(p.transcripts.isNotEmpty && p.codes.length >= 2, 'قالب ضعيف');
  _expect(p.approachId == 'reflexive_ta', 'النهج الافتراضي');
}

void _roundTrip() {
  final p = QualProject.template();
  p.excerpts.add(
    QualExcerpt(
      id: 'ex1',
      transcriptId: p.transcripts.first.id,
      quote: 'شعرت أن المدينة تضيق',
      codeIds: [p.codes.first.id],
    ),
  );
  final back = QualProject.tryDecode(p.encode());
  _expect(back != null, 'فشل decode');
  _expect(back!.excerpts.length == 1, 'المقتطفات');
  _expect(back.excerptsForCode(p.codes.first.id) == 1, 'عدّ المقتطفات');
}

void _hardLiterary() {
  final p = QualProject(
    researchQuestion:
        'كيف يبني القرّاء الناقدون صورة المدينة سردياً عبر ثلاث روايات لمحفوظ؟',
    approachId: 'reflexive_ta',
    transcripts: [
      QualTranscript(
        id: 't1',
        title: 'مقابلة قارئ ناقد ١',
        participantLabel: 'دكتوراه أدب',
        body:
            'زقاق المدق يقدّم المدينة كشبكة علاقات خانقة… '
            'أما الكرنك فيحوّل الفضاء إلى مسرح سياسي مشحون.',
        familiarizationNotes: 'توتر بين الشعبي والسياسي ظاهر من الجملة الأولى.',
      ),
    ],
    codes: [
      QualCode(id: 'c1', label: 'فضاء خانق', definition: 'ضيق مكاني/اجتماعي'),
      QualCode(id: 'c2', label: 'فضاء سياسي', definition: 'مكان مشحون بالسلطة'),
    ],
  );
  p.excerpts.addAll([
    QualExcerpt(
      id: 'e1',
      transcriptId: 't1',
      quote: 'المدينة كشبكة علاقات خانقة',
      codeIds: ['c1'],
    ),
    QualExcerpt(
      id: 'e2',
      transcriptId: 't1',
      quote: 'الفضاء إلى مسرح سياسي مشحون',
      codeIds: ['c2'],
    ),
  ]);
  p.themes.add(
    QualTheme(
      id: 'th1',
      title: 'المدينة كاختبار للذات',
      centralConcept:
          'الفضاء عند محفوظ ليس خلفية بل قوة تشكّل هوية القارئ الناقد',
      codeIds: ['c1', 'c2'],
      writeup:
          'يجمع المشاركون بين ضيق الزقاق وشحن الكرنك ليقرأوا المدينة '
          'بوصفها امتحاناً مستمراً للذات الاجتماعية والسياسية.',
    ),
  );
  p.memos.add(
    QualMemo(
      id: 'm1',
      title: 'حدود التأويل',
      body: 'احذر تحويل كل فضاء إلى رمز سياسي دون دليل نصي.',
      linkedThemeId: 'th1',
    ),
  );

  final s = p.summaryForMethodology();
  _expect(s.contains('سؤال البحث') && s.contains('محفوظ'), 'السؤال');
  _expect(s.contains('فضاء خانق') && s.contains('المدينة كاختبار'), 'الرموز/الموضوع');
  _expect(p.excerptsForCode('c1') == 1 && p.excerptsForCode('c2') == 1, 'العد');
  _expect(QualPhase.all.length == 6, 'ست مراحل');
}

void _summary() {
  final p = QualProject.template();
  final s = p.summaryForMethodology();
  _expect(s.contains('تحليل نوعي') && s.contains('دفتر الرموز'), 'صيغة الملخص');
}
