/// اختبارات صعبة لاستوديو الأدوات البحثية (مسار 2).
/// تشغيل: dart run tool/research_tools_hard_test.dart
import 'package:acadegate/features/research_tools_studio/cronbach_engine.dart';
import 'package:acadegate/features/research_tools_studio/literary_instrument_models.dart';
import 'package:acadegate/features/research_tools_studio/survey_models.dart';

void main() {
  var failed = 0;
  failed += _section('Cronbach — حالة جيدة معروفة الشكل', _cronbachHealthy);
  failed += _section('Cronbach — بيانات ثابتة (يجب أن تفشل بأمان)', _cronbachConstant);
  failed += _section('Cronbach — عمود واحد (يجب رفض)', _cronbachOneItem);
  failed += _section('Cronbach — صف غير متساوٍ', _cronbachJagged);
  failed += _section('Cronbach — نص لصق صعب', _cronbachParseHard);
  failed += _section('مقابلة أدبية صعبة — ترميز/ملخص', _interviewHard);
  failed += _section('تحليل مضمون إعلامي صعب', _contentHard);
  failed += _section('مدونة آداب + حقوق', _corpusHard);
  failed += _section('استبانة تربية — قالب وملخص منهجية', _surveyHard);

  print('');
  if (failed == 0) {
    print('النتيجة النهائية: نجاح كل الاختبارات الصعبة.');
  } else {
    print('النتيجة النهائية: فشل $failed اختبار(ات).');
  }
}

int _section(String name, void Function() fn) {
  try {
    fn();
    print('صح — $name');
    return 0;
  } catch (e) {
    print('خطأ — $name');
    print('  $e');
    return 1;
  }
}

void _expect(bool cond, String msg) {
  if (!cond) throw StateError(msg);
}

void _cronbachHealthy() {
  // بيانات شبه متجانسة → α مرتفع نسبياً
  final m = <List<double>>[
    [5, 4, 5, 4, 5],
    [4, 4, 3, 4, 4],
    [5, 5, 5, 4, 5],
    [3, 3, 4, 3, 3],
    [4, 5, 4, 5, 4],
    [5, 4, 4, 5, 5],
    [2, 3, 2, 3, 2],
    [4, 4, 5, 4, 4],
  ];
  final r = CronbachEngine.compute(m);
  _expect(r.ok, 'يُفترض نجاح الحساب');
  _expect(r.nRespondents == 8 && r.kItems == 5, 'أبعاد المصفوفة');
  _expect(r.alpha > 0.7 && r.alpha <= 1.0, 'α المتوقع > 0.7، حصلنا ${r.alpha}');
}

void _cronbachConstant() {
  final m = <List<double>>[
    [3, 3, 3],
    [3, 3, 3],
    [3, 3, 3],
  ];
  final r = CronbachEngine.compute(m);
  _expect(!r.ok, 'الثبات على بيانات ثابتة يجب أن يُرفض');
  _expect(r.errorAr != null && r.errorAr!.isNotEmpty, 'رسالة خطأ عربية');
}

void _cronbachOneItem() {
  final r = CronbachEngine.compute(<List<double>>[
    [1],
    [2],
    [3],
  ]);
  _expect(!r.ok, 'بند واحد يجب رفضه');
}

void _cronbachJagged() {
  final parsed = CronbachEngine.parseMatrixText('1 2 3\n4 5');
  _expect(parsed.$2 != null, 'صف غير متساوٍ يجب أن يعطي خطأ parse');
}

void _cronbachParseHard() {
  const raw = '''
# تعليق يجب تجاهله
5,4,5,4,5
4;4;3;4;4
5	5	5	4	5
''';
  final parsed = CronbachEngine.parseMatrixText(raw);
  _expect(parsed.$2 == null, 'parse يجب أن ينجح: ${parsed.$2}');
  final r = CronbachEngine.compute(parsed.$1);
  _expect(r.ok && r.nRespondents == 3 && r.kItems == 5, 'أبعاد بعد اللصق');
}

void _interviewHard() {
  final p = InterviewProtocol(
    id: 'hard_iv',
    titleAr: 'تمثيلات المدينة في الرواية المصرية — مقابلات قرّاء ناقدين',
    researchQuestion:
        'كيف يبني القرّاء الناقدون صورة المدينة سردياً عبر ثلاث روايات لمحفوظ؟',
    participantProfile: '12 قارئاً ناقداً (ماجستير/دكتوراه أدب) بالقاهرة',
    durationMinutes: '70–90',
    ethicsNote: 'موافقة مستنيرة · إخفاء الهوية · عدم نشر مقتطفات دون إذن',
    questions: [
      InterviewQuestion(
        id: 'q1',
        text: 'صف لي أول انطباع شكّلته عن «المدينة» وأنت تقرأ زقاق المدق.',
        probeType: 'opening',
        followUp: 'أي مشهد بقي عالقاً؟',
      ),
      InterviewQuestion(
        id: 'q2',
        text:
            'كيف تميّز بين الفضاء الجغرافي والفضاء الرمزي للمدينة عند محفوظ؟',
        probeType: 'core',
        followUp: 'هل يتغيّر التمييز عبر الكرنك؟',
      ),
      InterviewQuestion(
        id: 'q3',
        text: 'أين يتعارض تأويلك مع قراءات نقدية سابقة؟',
        probeType: 'probe',
      ),
      InterviewQuestion(
        id: 'q4',
        text: 'ما الذي لم أسألك عنه ويغيّر خلاصتك؟',
        probeType: 'closing',
      ),
    ],
  );

  final encoded = p.encode();
  final back = InterviewProtocol.tryDecode(encoded);
  _expect(back != null, 'فشل فك الترميز');
  _expect(back!.questions.length == 4, 'عدد الأسئلة');
  final s = back.summary();
  _expect(s.contains('تمثيلات المدينة'), 'الملخص يفقد العنوان');
  _expect(s.contains('تعمّق') || s.contains('محوري'), 'أنواع الأسئلة في الملخص');
  _expect(s.contains('متابعة:'), 'أسئلة المتابعة');
}

void _contentHard() {
  final sheet = ContentAnalysisSheet(
    id: 'hard_ca',
    titleAr: 'ترميز خطاب التعليم في صحافة رقمية مصرية 2024–2025',
    researchQuestion: 'ما أطر تأطير أزمة التعليم في عيّنة مقالات؟',
    unitOfAnalysis: 'فقرة قيادية + عنوان',
    corpusDescription: '60 مقالاً من ثلاثة مواقع · عيّنة قصدية طبقية بالأسبوع',
    codes: [
      ContentCode(
        id: 'c1',
        label: 'إطار الأزمة',
        definition: 'تصوير التعليم كمشكلة نظامية حادّة',
        example: '«انهيار المنظومة»',
      ),
      ContentCode(
        id: 'c2',
        label: 'إطار الإصلاح التقني',
        definition: 'الحل يُقدَّم كتقنية/منصة دون تغيير هيكلي',
      ),
      ContentCode(
        id: 'c3',
        label: 'صوت المعلّم',
        definition: 'حضور المعلّم كفاعل أو غيابه',
      ),
    ],
  );
  final back = ContentAnalysisSheet.tryDecode(sheet.encode());
  _expect(back != null && back!.codes.length == 3, 'ترميز ورقة المضمون');
  final s = back!.summary();
  _expect(s.contains('إطار الأزمة') && s.contains('وحدة التحليل'), 'الملخص');
}

void _corpusHard() {
  final arts = CorpusDocumentCard(
    id: 'hard_arts',
    titleAr: 'مدونة سرد مدينة محفوظ',
    researchQuestion: 'كيف يُعاد تشكيل فضاء المدينة عبر ثلاث روايات؟',
    selectionCriteria: 'تمثيل زمني · تنوّع فضاء · طبعة محققة',
    ethicsCopyright: 'استشهاد + عدم إعادة نشر فصول كاملة',
    items: [
      CorpusItem(
        id: '1',
        title: 'زقاق المدق',
        source: 'دار الشروق',
        year: '2006',
        notes: 'فضاء شعبي مكتظ',
      ),
      CorpusItem(
        id: '2',
        title: 'أولاد حارتنا',
        source: 'دار الآداب',
        year: '2006',
        notes: 'رمزية الحارة',
      ),
      CorpusItem(
        id: '3',
        title: 'الكرنك',
        source: 'مكتبة مصر',
        year: '2006',
        notes: 'فضاء سياسي مشحون',
      ),
    ],
  );
  final artsBack = CorpusDocumentCard.tryDecode(arts.encode());
  _expect(artsBack != null && artsBack!.items.length == 3, 'مدونة الآداب');

  final law = CorpusDocumentCard.templateLaw();
  law.items.add(
    CorpusItem(
      id: 'l2',
      title: 'حكم محكمة النقض — مبدأ المواجهة في التحقيق',
      source: 'مجموعة أحكام النقض',
      year: '2019',
      notes: 'يربط بسؤال الضمانات الإجرائية',
    ),
  );
  final lawBack = CorpusDocumentCard.tryDecode(law.encode());
  _expect(lawBack != null && lawBack!.items.length >= 2, 'بطاقة الحقوق');
  _expect(lawBack!.summary().contains('قانونية'), 'ملخص الحقوق');
}

void _surveyHard() {
  final edu = SurveyInstrument.templateForTrack('education');
  _expect(edu.itemCount >= 4, 'قالب التربية ضعيف البنود');
  final summary = edu.summaryForMethodology();
  _expect(summary.contains('استبانة') && summary.contains('بُعد'), 'ملخص المنهجية');

  final artsTpl = SurveyInstrument.templateForTrack('arts');
  final round = SurveyInstrument.tryDecode(artsTpl.encode());
  _expect(round != null && round!.trackId == 'arts', 'قالب الآداب');
}
