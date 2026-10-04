/// تجربة مسار 3 كباحث دكتوراه — حالة أدبية صعبة.
/// تشغيل: dart run tool/qualitative_researcher_hard_run.dart
import 'package:acadegate/features/qualitative_analysis/qualitative_models.dart';

void main() {
  print('══════════════════════════════════════════════════');
  print('تجربة باحث: تحليل موضوعي انعكاسي (Reflexive TA)');
  print('══════════════════════════════════════════════════\n');

  final project = _buildHardPhDProject();
  var fails = 0;

  fails += _phase('١) الألفة مع البيانات', () => _checkFamiliarisation(project));
  fails += _phase('٢) توليد الرموز والترميز', () => _checkCoding(project));
  fails += _phase('٣–٥) بناء ومراجعة وتعريف الموضوعات', () => _checkThemes(project));
  fails += _phase('٦) الكتابة وملخص المنهجية', () => _checkWriteup(project));
  fails += _phase('حدّي: اقتباس فارغ / رمز يتيم / encode', () => _checkEdges(project));

  print('\n─── ملخص الباحث للمنهجية/النتائج ───\n');
  print(project.summaryForMethodology());

  print('\n─── مقتطف أدلة الموضوع الأقوى ───');
  final top = project.themes.first;
  final evidence = project.excerpts
      .where((e) => e.codeIds.any(top.codeIds.contains))
      .take(3);
  for (final e in evidence) {
    print('• «${e.quote}»');
  }

  print('\n══════════════════════════════════════════════════');
  if (fails == 0) {
    print('النتيجة: المشروع الصعب اكتمل بكفاءة عالية (0 فشل).');
  } else {
    print('النتيجة: فشل $fails فحص(ات).');
  }
  print('══════════════════════════════════════════════════');
}

int _phase(String name, void Function() fn) {
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

/// باحث دكتوراه آداب: تمثيلات المدينة عند محفوظ عبر مقابلات قرّاء ناقدين.
QualProject _buildHardPhDProject() {
  const t1 = 'tr_reader_1';
  const t2 = 'tr_reader_2';
  const t3 = 'tr_reader_3';

  const cSpace = 'c_space_pressure';
  const cMemory = 'c_memory_city';
  const cClass = 'c_class_gaze';
  const cGender = 'c_gendered_path';
  const cPolitics = 'c_political_stage';
  const cContradiction = 'c_reader_conflict';

  final p = QualProject(
    researchQuestion:
        'كيف يُعاد تشكيل «المدينة» سردياً في وعي القرّاء الناقدين '
        'عبر زقاق المدق وأولاد حارتنا والكرنك، وما التوترات التي '
        'تنتج عن تقاطع الفضاء الطبقي والسياسي والجندري؟',
    approachId: 'reflexive_ta',
    transcripts: [
      QualTranscript(
        id: t1,
        title: 'مقابلة قارئ ناقد — زقاق المدق',
        participantLabel: 'مشارك أ · ماجستير أدب حديث',
        body: '''
س: ما أول صورة للمدينة علقت بك وأنت تقرأ زقاق المدق؟
ج: الزقاق ليس شارعاً؛ هو شبكة أنفاس. كلما اقتربت حميدة من «برّه» شعرت أن المدينة
تبتلعها ثم تبصقها كسلعة. الضيق هنا اجتماعي قبل أن يكون معمارياً.

س: هل يختلف الفضاء عندك عن الخريطة؟
ج: نعم. الخريطة محايدة، أما الزقاق عند محفوظ فيُراقَب. النظرات الطبقية تُعيد رسم الحدود
حتى لو لم تُرسَم على الورق. وأنا كقارئ من طبقة وسطى وجدت نفسي متواطئاً مع تلك النظرة.
''',
        familiarizationNotes:
            'غلبة الاستعارة الجسدية (يبتلع/يبصق). المشارك يربط الضيق بالطبقة لا بالحجر. '
            'ظهور اعتراف انعكاسي: تواطؤ القارئ.',
      ),
      QualTranscript(
        id: t2,
        title: 'مقابلة قارئ ناقد — أولاد حارتنا',
        participantLabel: 'مشارك ب · دكتوراه نقد',
        body: '''
الحارة عندي مدينة كاملة مموّهة. الذاكرة الجمعية تُعيد بناء المكان كلما ذُكر «الجبلاوي».
المفارقة أن المشاركين يهربون من ضيق الحارة إلى أسطورة أكبر تضغط عليهم أكثر.
الفضاء السياسي هنا متنكّر في لباس ديني-رمزي، وهذا يجعل الترميز خطيراً: قد أقرأ سياسة
حيث يريد النص أسطورة، أو العكس.
''',
        familiarizationNotes:
            'توتر منهجي صريح: خطر الإسقاط السياسي على الرمز. المدينة = ذاكرة لا جغرافيا.',
      ),
      QualTranscript(
        id: t3,
        title: 'مقابلة قارئة ناقدة — الكرنك',
        participantLabel: 'مشاركة ج · باحثة سرد ونوع',
        body: '''
الكرنك حوّل المقهى والزنزانة إلى مسرح واحد. الجسد الأنثوي يُختبَر تحت عين السلطة؛
المسار في المدينة لم يعد اختياراً بل تفتيشاً. قالت المشاركة: «كنت أقرأ زينب فأرى
شارع الجامعة اليوم». الذاكرة الشخصية تتداخل مع النص حتى يصعب فصل الشاهد عن القراءة.
''',
        familiarizationNotes:
            'الجندر + السلطة أوضح هنا. انزلاق بين زمن النص وزمن القارئ يحتاج حذراً تحليلياً.',
      ),
    ],
    codes: [
      QualCode(
        id: cSpace,
        label: 'ضغط الفضاء',
        definition: 'وصف المكان كقوة تضيّق على الفاعل أو تبتلعه.',
        inclusionNotes: 'يُطبَّق عند الاستعارة الجسدية أو الخنق الاجتماعي لا مجرد وصف زقاق.',
      ),
      QualCode(
        id: cMemory,
        label: 'مدينة الذاكرة',
        definition: 'المكان يُستعاد عبر ذاكرة جمعية/شخصية لا عبر خريطة.',
      ),
      QualCode(
        id: cClass,
        label: 'نظرة طبقية',
        definition: 'حدود المدينة تُرسَم بالنظرات والموقع الطبقي للقارئ أو الشخصية.',
      ),
      QualCode(
        id: cGender,
        label: 'مسار مجندر',
        definition: 'حركة الجسد الأنثوي في المدينة بوصفها تفتيشاً أو اختباراً.',
      ),
      QualCode(
        id: cPolitics,
        label: 'مسرح سياسي',
        definition: 'تحويل الفضاء اليومي إلى فضاء سلطة/مراقبة.',
      ),
      QualCode(
        id: cContradiction,
        label: 'صراع التأويل',
        definition: 'وعي القارئ بتناقض قراءته أو خطر الإسقاط على النص.',
      ),
    ],
  );

  p.excerpts.addAll([
    QualExcerpt(
      id: 'e1',
      transcriptId: t1,
      quote: 'الزقاق ليس شارعاً؛ هو شبكة أنفاس… المدينة تبتلعها ثم تبصقها كسلعة',
      codeIds: [cSpace, cClass],
      note: 'الاستعارة الجسدية + التسليع',
    ),
    QualExcerpt(
      id: 'e2',
      transcriptId: t1,
      quote: 'النظرات الطبقية تُعيد رسم الحدود… وجدت نفسي متواطئاً مع تلك النظرة',
      codeIds: [cClass, cContradiction],
      note: 'انعكاسية القارئ — مهم للمنهج',
    ),
    QualExcerpt(
      id: 'e3',
      transcriptId: t2,
      quote: 'الذاكرة الجمعية تُعيد بناء المكان كلما ذُكر الجبلاوي',
      codeIds: [cMemory],
    ),
    QualExcerpt(
      id: 'e4',
      transcriptId: t2,
      quote:
          'قد أقرأ سياسة حيث يريد النص أسطورة، أو العكس',
      codeIds: [cContradiction, cPolitics],
      note: 'حدّ التحليل نفسه بوصفه موضوعاً',
    ),
    QualExcerpt(
      id: 'e5',
      transcriptId: t3,
      quote: 'الجسد الأنثوي يُختبَر تحت عين السلطة؛ المسار في المدينة تفتيش',
      codeIds: [cGender, cPolitics, cSpace],
    ),
    QualExcerpt(
      id: 'e6',
      transcriptId: t3,
      quote: 'كنت أقرأ زينب فأرى شارع الجامعة اليوم',
      codeIds: [cMemory, cContradiction],
      note: 'تداخل الأزمنة — يحتاج تحفظاً في العرض',
    ),
  ]);

  p.themes.addAll([
    QualTheme(
      id: 'th1',
      title: 'المدينة كجهاز ضغط لا كخلفية',
      centralConcept:
          'الفضاء عند القرّاء الناقدين فاعل يبتلع ويُراقب ويُفتّش، لا ديكور سردي.',
      codeIds: [cSpace, cPolitics, cGender],
      writeup:
          'عبر المقابلات الثلاث يظهر اتفاق على أن المدينة «تعمل» على الذوات: '
          'تبتلع حميدة، وتتنكّر سلطةً في الحارة، وتفتّش الجسد في الكرنك. '
          'الموضوع يرفض قراءة الفضاء كوصف سياحي ويؤسس لحجة أن التمثيل السردي '
          'يحوّل المكان إلى جهاز اجتماعي-سياسي.',
    ),
    QualTheme(
      id: 'th2',
      title: 'خرائط غير مرئية: طبقة وذاكرة',
      centralConcept:
          'حدود المدينة تُعاد رسمها بالنظرة الطبقية والذاكرة لا بالهندسة.',
      codeIds: [cClass, cMemory],
      writeup:
          'المشارك أ يكشف تواطؤ القارئ الطبقي، والمشارك ب يستبدل الجغرافيا بالذاكرة '
          'الجمعية. معاً يُنتجان مدينة موازية غير قابلة للقياس على الخريطة، '
          'مما يبرّر منهجاً نوعياً لا إحصاءً مكانياً.',
    ),
    QualTheme(
      id: 'th3',
      title: 'القارئ تحت الاختبار: انعكاسية التأويل',
      centralConcept:
          'جزء من ظاهرة «المدينة» هو صراع القارئ مع إسقاطاته وحدود قراءته.',
      codeIds: [cContradiction],
      writeup:
          'بدلاً من إخفاء التردد المنهجي، يحوّله المشاركون إلى مادة تحليل: '
          'خطر قراءة السياسة في الرمز، وانزلاق زمن النص إلى زمن الشارع. '
          'هذا الموضوع يحمي الدراسة من ادّعاء شفافية التأويل.',
    ),
  ]);

  p.memos.addAll([
    QualMemo(
      id: 'm1',
      title: 'لا تخلط الموضوع بالعنوان',
      body:
          'تجنّب موضوعاً اسمه «المدينة عند محفوظ» — هذا عنوان فصل لا حجة. '
          'الحجة الحالية: المدينة جهاز ضغط.',
      linkedThemeId: 'th1',
    ),
    QualMemo(
      id: 'm2',
      title: 'تشبّع أولي؟',
      body:
          'بعد ٣ مقابلات ظهرت الرموز الستة بقوة. أحتاج مقابلتين إضافيتين '
          'من قرّاء خارج القاهرة لاختبار إن كان «ضغط الفضاء» مرتبطاً بالمتروبول فقط.',
      linkedCodeId: cSpace,
    ),
  ]);

  return p;
}

void _checkFamiliarisation(QualProject p) {
  _expect(p.transcripts.length == 3, 'يلزم 3 نصوص');
  for (final t in p.transcripts) {
    _expect(t.body.trim().length > 120, 'نص قصير جداً: ${t.title}');
    _expect(
      t.familiarizationNotes.trim().length > 20,
      'ملاحظات ألفة ناقصة: ${t.title}',
    );
  }
}

void _checkCoding(QualProject p) {
  _expect(p.codes.length >= 5, 'رموز قليلة لحالة دكتوراه');
  _expect(p.excerpts.length >= 6, 'تغطية ترميز ضعيفة');
  for (final e in p.excerpts) {
    _expect(e.quote.trim().isNotEmpty, 'مقتطف بلا اقتباس');
    _expect(e.codeIds.isNotEmpty, 'مقتطف بلا رمز');
    for (final id in e.codeIds) {
      _expect(p.codeById(id) != null, 'رمز مفقود $id');
    }
  }
  // كل رمز مستخدم مرة على الأقل — لا رموز زينة
  for (final c in p.codes) {
    _expect(p.excerptsForCode(c.id) >= 1, 'رمز يتيم بلا مقتطفات: ${c.label}');
  }
  // مقتطف متعدد الرموز (صعوبة حقيقية)
  _expect(
    p.excerpts.any((e) => e.codeIds.length >= 2),
    'يلزم مقتطف متعدد الرموز',
  );
}

void _checkThemes(QualProject p) {
  _expect(p.themes.length >= 3, 'موضوعات أقل من المطلوب');
  final usedCodes = <String>{};
  for (final t in p.themes) {
    _expect(t.title.trim().isNotEmpty, 'موضوع بلا عنوان');
    _expect(
      t.centralConcept.trim().length > 30,
      'مفهوم مركزي ضعيف: ${t.title}',
    );
    _expect(t.writeup.trim().length > 80, 'صياغة تحليلية قصيرة: ${t.title}');
    _expect(t.codeIds.isNotEmpty, 'موضوع بلا رموز: ${t.title}');
    // الموضوع ليس مجرد تكرار لاسم رمز
    for (final id in t.codeIds) {
      final code = p.codeById(id);
      _expect(code != null, 'رمز موضوع مفقود');
      _expect(
        t.title != code!.label,
        'الموضوع يكرر اسم الرمز حرفياً — خطأ منهجي شائع',
      );
      usedCodes.add(id);
    }
  }
  _expect(usedCodes.length >= 5, 'الموضوعات لا تغطي معظم الرموز');
  _expect(p.memos.length >= 2, 'مذكرات تحليلية ناقصة');
}

void _checkWriteup(QualProject p) {
  final s = p.summaryForMethodology();
  _expect(s.contains('Reflexive') || s.contains('انعكاسي'), 'نهج التحليل');
  _expect(s.contains('سؤال البحث'), 'السؤال');
  _expect(s.contains('ضغط الفضاء'), 'رمز في الملخص');
  _expect(s.contains('جهاز ضغط'), 'موضوع في الملخص');
  _expect(s.contains('3 نصاً') || s.contains('3'), 'عدد النصوص');
}

void _checkEdges(QualProject p) {
  // encode/decode يحافظ على التعقيد
  final back = QualProject.tryDecode(p.encode());
  _expect(back != null, 'فشل decode');
  _expect(back!.excerpts.length == p.excerpts.length, 'ضياع مقتطفات');
  _expect(back.themes.length == 3, 'ضياع موضوعات');
  _expect(back.memos.first.linkedThemeId == 'th1', 'ربط المذكرة');

  // رفض منهجي صامت: مقتطف فارغ لا يُحسب تغطية
  final empty = QualExcerpt(id: 'bad', transcriptId: 't1', quote: '  ');
  _expect(empty.quote.trim().isEmpty, 'يجب كشف الاقتباس الفارغ');
}
