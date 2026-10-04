/// تجربة مسار 4 كباحث دكتوراه حقوق — حالة صعبة.
/// تشغيل: dart run tool/law_lab_researcher_hard_run.dart
import 'package:acadegate/features/law_lab/law_lab_models.dart';

void main() {
  print('══════════════════════════════════════════════════');
  print('تجربة باحث حقوق: مختبر الأسانيد القانونية');
  print('══════════════════════════════════════════════════\n');

  final p = _buildHardPhdProject();
  var fails = 0;

  fails += _phase('١) تفريع المسألة', () => _checkIssues(p));
  fails += _phase('٢) سجل الأسانيد وتدرجها', () => _checkAuthorities(p));
  fails += _phase('٣) بطاقة الحكم', () => _checkBriefs(p));
  fails += _phase('٤) سلسلة الاستدلال', () => _checkLinks(p));
  fails += _phase('٥) المقارنة التشريعية', () => _checkCompare(p));
  fails += _phase('٦) الملخص + الحفظ', () => _checkSummary(p));

  print('\n─── ملخص الباحث (منهجية / فصل قانوني) ───\n');
  print(p.summaryForMethodology());

  print('\n─── سلسلة استدلال مختصرة ───');
  for (final link in p.links) {
    final iss = p.issueById(link.issueId)?.title ?? link.issueId;
    final au = p.authorityById(link.authorityId);
    final label = au == null ? link.authorityId : '[${au.kindAr}] ${au.title}';
    print('• $iss ← ${link.roleAr} — $label');
  }

  print('\n══════════════════════════════════════════════════');
  print(
    fails == 0
        ? 'النتيجة: المشروع القانوني الصعب اكتمل (0 فشل).'
        : 'النتيجة: فشل $fails فحص(ات).',
  );
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

/// باحث دكتوراه: قرارات إدارية تعتمد ذكاءً اصطناعياً وحماية البيانات.
LawProject _buildHardPhdProject() {
  const iConst = 'iss_const';
  const iDuties = 'iss_duties';
  const iRemedy = 'iss_remedy';
  const iGap = 'iss_gap';

  const aConst = 'au_const';
  const a151 = 'au_151';
  const aAdmin = 'au_admin_proc';
  const aCass = 'au_cass';
  const aDoc = 'au_doctrine';
  const aSoft = 'au_soft';

  return LawProject(
    researchQuestion:
        'إلى أي حد يوفّر النظام القانوني المصري ضمانات الشفافية والطعن '
        'إزاء القرارات الإدارية المعتمدة على أنظمة ذكاء اصطناعي، '
        'في ضوء الدستور وقانون حماية البيانات الشخصية 151 لسنة 2020 '
        'والمعايير المقارنة؟',
    fieldAr: 'قانون إداري · تقنية معلومات · حماية بيانات',
    issues: [
      LawIssue(
        id: iConst,
        title: 'الأساس الدستوري للخصوصية والمحاسبة الإدارية',
        notes: 'مواد الدستور ذات الصلة + مبدأ المشروعية',
      ),
      LawIssue(
        id: iDuties,
        title: 'التزامات المتحكم/المعالج عند الأتمتة الإدارية',
        notes: 'قانون 151 — حقوق المعني وحدود المعالجة',
      ),
      LawIssue(
        id: iRemedy,
        title: 'سبل الطعن على القرار الإداري «الآلي»',
        notes: 'إلغاء · تعويض · إجراءات مجلس الدولة',
      ),
      LawIssue(
        id: iGap,
        title: 'الفجوة إزاء قابلية الشرح والرقابة البشرية',
        notes: 'هل يكفي الإطار الحالي أم تلزم ضمانات تشريعية إضافية؟',
      ),
    ],
    authorities: [
      LawAuthority(
        id: aConst,
        kind: 'constitution',
        title: 'دستور جمهورية مصر العربية',
        citation: 'المادتان 57 و68',
        year: '2014',
        status: 'in_force',
        keyProvision: 'حرمة الحياة الخاصة · الحق في المعرفة/المعلومات',
      ),
      LawAuthority(
        id: a151,
        kind: 'statute',
        title: 'قانون حماية البيانات الشخصية',
        citation: 'القانون رقم 151 لسنة 2020',
        year: '2020',
        status: 'in_force',
        keyProvision:
            'حقوق المعني بالبيانات · التزامات المتحكم والمعالج · '
            'شروط المعالجة المشروعة',
      ),
      LawAuthority(
        id: aAdmin,
        kind: 'statute',
        title: 'إطار الطعن الإداري (مجلس الدولة / قضاء إداري)',
        citation: 'قانون مجلس الدولة والقواعد الإجرائية ذات الصلة',
        year: '',
        status: 'in_force',
        keyProvision: 'اختصاص نظر قرارات إدارية نهائية والرقابة على المشروعية',
      ),
      LawAuthority(
        id: aCass,
        kind: 'judgment',
        title: 'مبدأ رقابي على قرارات إدارية (يُستكمل بإسناد منشور)',
        citation: 'مجموعة أحكام — يُستبدل بمرجع رسمي بعد التحقق',
        year: '—',
        status: 'unknown',
        keyProvision:
            'مسودة مبدأ: خضوع القرار الإداري لرقابة المشروعية ولو استند لتقنية',
        notes: 'لا يُدرج في المسودة النهائية بحالة «غير مؤكد»',
      ),
      LawAuthority(
        id: aDoc,
        kind: 'doctrine',
        title: 'فقه القانون الإداري وحماية البيانات',
        citation: 'شروح معتمدة + دراسات مقارنة',
        year: '2022–2025',
        status: 'in_force',
        keyProvision: 'تفسير التزامات الشفافية والمحاسبة في البيئة الرقمية',
      ),
      LawAuthority(
        id: aSoft,
        kind: 'soft',
        title: 'مبادئ إرشادية لحوكمة الذكاء الاصطناعي في القطاع العام',
        citation: 'وثائق سياسات / أدلة إرشادية',
        year: '2023+',
        status: 'unknown',
        keyProvision: 'إرشاد غير ملزم — لا يقوم مقام التشريع',
        notes: 'يُستخدم للاستئناس فقط',
      ),
    ],
    briefs: [
      LawCaseBrief(
        id: 'br1',
        court: 'المحكمة الإدارية العليا',
        caseRef: 'يُستكمل بعد التوثيق من المجموعة الرسمية',
        year: '—',
        facts: 'قرار إداري يستند إلى معالجة آلية لبيانات أصحاب الشأن',
        issue: 'هل تُقبل رقابة المشروعية على القرار ولو كان «تقنياً»؟',
        holding: 'مسودة — لا تُعتمد قبل الإسناد الرسمي الكامل',
        ratio: 'المبدأ يُستخرج بعد قراءة الحكم كاملاً لا من ملخص ثانوي',
        relevance: 'يربط بفرع سبل الطعن وبشرط عدم الاعتماد على حالة غير مؤكد',
      ),
    ],
    links: [
      LawArgumentLink(
        id: 'lk1',
        issueId: iConst,
        authorityId: aConst,
        role: 'supports',
        note: 'يرسي الأساس الدستوري للخصوصية والمحاسبة',
      ),
      LawArgumentLink(
        id: 'lk2',
        issueId: iDuties,
        authorityId: a151,
        role: 'supports',
        note: 'المرجع التشريعي المركزي لالتزامات المعالجة',
      ),
      LawArgumentLink(
        id: 'lk3',
        issueId: iDuties,
        authorityId: aDoc,
        role: 'supports',
        note: 'يفسّر التطبيق على الأتمتة الإدارية',
      ),
      LawArgumentLink(
        id: 'lk4',
        issueId: iRemedy,
        authorityId: aAdmin,
        role: 'supports',
        note: 'قناة الطعن الأساسية',
      ),
      LawArgumentLink(
        id: 'lk5',
        issueId: iRemedy,
        authorityId: aCass,
        role: 'limits',
        note: 'سند قضائي غير مؤكد — يقيّد قوة الحجة حتى التوثيق',
      ),
      LawArgumentLink(
        id: 'lk6',
        issueId: iGap,
        authorityId: aSoft,
        role: 'distinguishes',
        note: 'يميّز الإرشاد غير الملزم عن الالتزام التشريعي',
      ),
      LawArgumentLink(
        id: 'lk7',
        issueId: iGap,
        authorityId: a151,
        role: 'limits',
        note: 'القانون لا يفصّل صراحةً قابلية شرح أنظمة AI عالية المخاطر',
      ),
    ],
    comparisons: [
      LawCompareRow(
        id: 'cm1',
        issueLabel: 'حق المعني في فهم أساس القرار الآلي (explainability)',
        egyptRule:
            'قانون 151 يقر حقوقاً للمعني دون إطار تفصيلي مخصص لأنظمة AI إدارية',
        foreignSystem: 'الاتحاد الأوروبي (GDPR / AI Act)',
        foreignRule:
            'التزامات شفافية أوسع وقيود على الأنظمة عالية المخاطر مع رقابة بشرية',
        note: 'فجوة وظيفية تبرّر مقترح ضمانات تشريعية مصرية دون نسخ أعمى',
      ),
      LawCompareRow(
        id: 'cm2',
        issueLabel: 'الطعن على القرار الإداري المؤتمت',
        egyptRule: 'رقابة قضاء إداري على المشروعية وفق الإطار العام',
        foreignSystem: 'فرنسا (قضاء إداري + ضمانات رقمية)',
        foreignRule: 'تطويرات أحدث حول القرار الإداري الخوارزمي',
        note: 'المقارنة وظيفية: حماية المخاطب لا محاكاة نصية',
      ),
    ],
  );
}

void _checkIssues(LawProject p) {
  _expect(p.issues.length >= 4, 'فروع قليلة لدكتوراه');
  for (final i in p.issues) {
    _expect(i.title.trim().length > 15, 'فرع عام جداً: ${i.title}');
  }
}

void _checkAuthorities(LawProject p) {
  _expect(p.authorities.length >= 5, 'أسانيد قليلة');
  _expect(p.authorities.any((a) => a.kind == 'constitution'), 'ينقص الدستور');
  _expect(p.authorities.any((a) => a.kind == 'statute'), 'ينقص تشريع');
  _expect(p.authorities.any((a) => a.kind == 'doctrine'), 'ينقص فقه');
  // الباحث الواعي يرصد سنداً غير مؤكد ولا يخفيه
  _expect(
    p.authorities.any((a) => a.status == 'unknown'),
    'يلزم إظهار سند بحالة غير مؤكد (نزاهة منهجية)',
  );
  // التدرج: وجود أنواع متعددة
  final kinds = p.authorities.map((a) => a.kind).toSet();
  _expect(kinds.length >= 4, 'تنوّع أنواع الأسانيد ضعيف');
}

void _checkBriefs(LawProject p) {
  _expect(p.briefs.isNotEmpty, 'لا بطاقة حكم');
  final b = p.briefs.first;
  _expect(b.issue.trim().isNotEmpty && b.holding.trim().isNotEmpty, 'بطاقة ناقصة');
  _expect(b.relevance.trim().isNotEmpty, 'صلة البحث ناقصة');
}

void _checkLinks(LawProject p) {
  _expect(p.links.length >= 6, 'سلسلة استدلال ضعيفة');
  for (final iss in p.issues) {
    _expect(p.linksForIssue(iss.id) >= 1, 'فرع بلا سند: ${iss.title}');
  }
  _expect(p.links.any((l) => l.role == 'supports'), 'ينقص رابط يؤيّد');
  _expect(p.links.any((l) => l.role == 'limits'), 'ينقص رابط يقيّد');
  _expect(p.links.any((l) => l.role == 'distinguishes'), 'ينقص رابط يميّز');
  // لا تعتمد المسودة النهائية على unknown كـ supports وحيد
  for (final l in p.links.where((l) => l.role == 'supports')) {
    final a = p.authorityById(l.authorityId);
    _expect(a != null, 'سند مفقود');
    if (a!.status == 'unknown') {
      throw StateError('لا يجوز أن يكون سند غير مؤكد هو الداعم الوحيد/المباشر دون تحفظ');
    }
  }
}

void _checkCompare(LawProject p) {
  _expect(p.comparisons.length >= 2, 'مقارنة ضعيفة');
  for (final c in p.comparisons) {
    _expect(c.egyptRule.trim().isNotEmpty, 'صف مصر فارغ');
    _expect(c.foreignRule.trim().isNotEmpty, 'صف أجنبي فارغ');
    _expect(c.note.trim().length > 20, 'ملاحظة المقارنة ضعيفة');
  }
}

void _checkSummary(LawProject p) {
  final s = p.summaryForMethodology();
  _expect(s.contains('151') && s.contains('دستور'), 'الملخص يفقد مصادر أساسية');
  _expect(s.contains('مقارنة تشريعية'), 'الملخص بلا مقارنة');
  final back = LawProject.tryDecode(p.encode());
  _expect(back != null && back!.links.length == p.links.length, 'encode');
}
