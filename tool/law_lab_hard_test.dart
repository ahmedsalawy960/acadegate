/// اختبار مسار 4 — مختبر القانون بحالة صعبة.
/// تشغيل: dart run tool/law_lab_hard_test.dart
import 'package:acadegate/features/law_lab/law_lab_models.dart';

void main() {
  var failed = 0;
  failed += _sec('قالب', () {
    final p = LawProject.template();
    _expect(p.issues.length >= 3 && p.authorities.length >= 2, 'قالب ضعيف');
  });
  failed += _sec('سيناريو حماية البيانات والذكاء الاصطناعي', _hardAiLaw);
  failed += _sec('encode/decode', () {
    final p = _project();
    final back = LawProject.tryDecode(p.encode());
    _expect(back != null && back!.links.length == p.links.length, 'round-trip');
  });

  print(failed == 0
      ? '\nالنتيجة: نجاح اختبارات مختبر القانون.'
      : '\nالنتيجة: فشل $failed.');
}

int _sec(String n, void Function() fn) {
  try {
    fn();
    print('صح — $n');
    return 0;
  } catch (e) {
    print('خطأ — $n\n  $e');
    return 1;
  }
}

void _expect(bool c, String m) {
  if (!c) throw StateError(m);
}

LawProject _project() {
  const iss1 = 'i1';
  const iss2 = 'i2';
  const iss3 = 'i3';
  const auConst = 'a_const';
  const auLaw = 'a_law151';
  const auCase = 'a_case';
  const auDoctrine = 'a_doc';

  return LawProject(
    researchQuestion:
        'ما ضمانات الشفافية والطعن إزاء قرارات إدارية تعتمد أنظمة ذكاء اصطناعي '
        'في ضوء الدستور وقانون حماية البيانات 151 لسنة 2020؟',
    fieldAr: 'قانون إداري / تقنية معلومات',
    issues: [
      LawIssue(id: iss1, title: 'الإطار الدستوري للخصوصية والمحاسبة'),
      LawIssue(id: iss2, title: 'التزامات المتحكم بموجب قانون 151/2020'),
      LawIssue(id: iss3, title: 'سبل الطعن الإداري والقضائي على القرار الآلي'),
    ],
    authorities: [
      LawAuthority(
        id: auConst,
        kind: 'constitution',
        title: 'دستور 2014',
        citation: 'المادتان 57 و68',
        year: '2014',
        status: 'in_force',
        keyProvision: 'حرمة الحياة الخاصة · الحق في المعلومات',
      ),
      LawAuthority(
        id: auLaw,
        kind: 'statute',
        title: 'قانون حماية البيانات الشخصية',
        citation: 'القانون 151 لسنة 2020',
        year: '2020',
        status: 'in_force',
        keyProvision: 'حقوق المعني · التزامات المتحكم/المعالج',
      ),
      LawAuthority(
        id: auCase,
        kind: 'judgment',
        title: 'حكم إداري — رقابة على قرارات مؤتمتة (مسودة إسناد)',
        citation: 'يُستبدل بحكم منشور بعد التحقق',
        year: '—',
        status: 'unknown',
        keyProvision: 'لا تعتمد قبل التحقق من المجموعة الرسمية',
      ),
      LawAuthority(
        id: auDoctrine,
        kind: 'doctrine',
        title: 'شروح قانون إداري وتقنية',
        citation: 'مرجع فقهي معتمد',
        year: '2023',
        status: 'in_force',
      ),
    ],
    briefs: [
      LawCaseBrief(
        id: 'b1',
        court: 'المحكمة الإدارية العليا',
        caseRef: 'يُستكمل بعد التوثيق',
        year: '—',
        issue: 'مدى خضوع القرار الإداري المعتمد على خوارزمية لرقابة المشروعية',
        holding: 'مسودة — لا تستخدم في الرسالة قبل الاستناد الرسمي',
        ratio: 'المبدأ يُستخرج بعد قراءة الحكم كاملاً',
        relevance: 'يربط بفرع سبل الطعن',
      ),
    ],
    links: [
      LawArgumentLink(
        id: 'l1',
        issueId: iss1,
        authorityId: auConst,
        role: 'supports',
        note: 'أساس دستوري للخصوصية والمحاسبة',
      ),
      LawArgumentLink(
        id: 'l2',
        issueId: iss2,
        authorityId: auLaw,
        role: 'supports',
      ),
      LawArgumentLink(
        id: 'l3',
        issueId: iss3,
        authorityId: auCase,
        role: 'limits',
        note: 'سند قضائي بحالة غير مؤكد — يُستبدل',
      ),
      LawArgumentLink(
        id: 'l4',
        issueId: iss2,
        authorityId: auDoctrine,
        role: 'supports',
      ),
    ],
    comparisons: [
      LawCompareRow(
        id: 'c1',
        issueLabel: 'حق التفسير/القابلية للشرح في القرار الآلي',
        egyptRule: 'قانون 151 يركز على حقوق المعني دون نص صريح مفصل للـ AI explainability',
        foreignSystem: 'الاتحاد الأوروبي (AI Act / GDPR)',
        foreignRule: 'التزامات شفافية وشرح أوسع للأنظمة عالية المخاطر',
        note: 'فجوة محتملة تبرّر مقترح ضمانات تشريعية مصرية',
      ),
    ],
  );
}

void _hardAiLaw() {
  final p = _project();
  _expect(p.issues.length == 3, 'فروع');
  _expect(p.authorities.any((a) => a.kind == 'constitution'), 'دستور');
  _expect(p.authorities.any((a) => a.status == 'unknown'), 'حالة غير مؤكد موجودة');
  _expect(p.links.length >= 4, 'روابط استدلال');
  _expect(
    p.links.any((l) => l.role == 'limits'),
    'يلزم رابط يقيّد لا يؤيد فقط',
  );
  for (final iss in p.issues) {
    _expect(p.linksForIssue(iss.id) >= 1, 'فرع بلا سند: ${iss.title}');
  }
  final s = p.summaryForMethodology();
  _expect(s.contains('151') && s.contains('دستور'), 'الملخص');
  _expect(s.contains('مقارنة تشريعية'), 'المقارنة في الملخص');
}
