import 'package:acadegate/features/viva_simulator/viva_committee.dart';
import 'package:acadegate/features/viva_simulator/viva_local_engine.dart';
import 'package:acadegate/features/viva_simulator/viva_models.dart';
import 'package:acadegate/features/viva_simulator/viva_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses extraction JSON wrapped in a markdown fence', () {
    const raw = '''
```json
{
  "title": "Adsorption of heavy metals on biochar",
  "summary": "This thesis studies adsorption kinetics of lead on rice-husk biochar using batch experiments and isotherm models.",
  "supervisorName": "",
  "researchQuestions": ["How does pH affect lead adsorption on rice-husk biochar?"],
  "vivaQuestions": [
    "Your thesis claims Langmuir fit better than Freundlich for lead — which residual plot supports that?"
  ],
  "issues": [
    {
      "kind": "gap",
      "quote": "n = 12 samples were collected",
      "comment": "Sample size is not justified against expected effect size."
    }
  ],
  "excerpt": "Lead adsorption increased from pH 3 to pH 6 then declined. The Langmuir model described equilibrium data better than Freundlich."
}
```
''';
    final result = VivaPdfService.instance.parseExtraction(raw, 'thesis.docx');
    expect(result.title, contains('biochar'));
    expect(result.extractedQuestions, isNotEmpty);
    expect(result.extractedQuestions.first, contains('Langmuir'));
    expect(result.issues, isNotEmpty);
    expect(result.issues.first.kind, 'gap');
    expect(result.supervisorFromThesis, isNull);
  });

  test('rejects invented supervisor names from the old committee lineup', () {
    const raw = '''
{
  "title": "A study of groundwater quality in Basra",
  "summary": "The work maps salinity and nitrate in twenty wells over two seasons using field kits and laboratory confirmation.",
  "supervisorName": "أ.د. نادية حسن",
  "vivaQuestions": ["How did seasonal sampling affect nitrate readings in the twenty wells?"],
  "issues": [],
  "excerpt": "Nitrate exceeded WHO limits in eight wells during the dry season."
}
''';
    final result = VivaPdfService.instance.parseExtraction(raw, 'thesis.pdf');
    expect(result.supervisorFromThesis, isNull);
    final names = VivaCommittee.lineup(supervisorFromThesis: result.supervisorFromThesis)
        .map((m) => '${m.nameAr} ${m.nameEn}')
        .join(' ');
    expect(names, isNot(contains('نادية')));
    expect(names, isNot(contains('كريم منصور')));
    expect(names, isNot(contains('Nadia Hassan')));
  });

  test('uses a printed supervisor name only when it looks real', () {
    const raw = '''
{
  "title": "Machine learning for diabetic retinopathy screening",
  "summary": "A convolutional network was trained on fundus images from three public datasets and compared with two ophthalmologists.",
  "supervisorName": "Prof. Ahmed Al-Khatib",
  "vivaQuestions": ["Why were three public datasets pooled without domain-shift correction?"],
  "excerpt": "Sensitivity reached 0.91 on the held-out set but dropped on images from a fourth clinic."
}
''';
    final result = VivaPdfService.instance.parseExtraction(raw, 'thesis.pdf');
    expect(result.supervisorFromThesis, 'Prof. Ahmed Al-Khatib');
    final supervisor = VivaCommittee.lineup(
      supervisorFromThesis: result.supervisorFromThesis,
    ).first;
    expect(supervisor.displayName, contains('Ahmed'));
  });

  test('local engine asks extracted thesis questions before generic banks', () {
    const config = VivaSessionConfig(
      thesisTitle: 'Adsorption of lead on rice-husk biochar',
      thesisSummary:
          'Batch experiments compared Langmuir and Freundlich fits for lead removal at pH 3 to 7.',
      degree: 'ماجستير',
      methodology: 'كمي',
      specialization: 'Environmental engineering',
      university: 'University of Basra',
      extractedQuestions: [
        'Your thesis claims Langmuir fit better than Freundlich for lead — which residual plot supports that?',
      ],
    );
    final member = VivaCommittee.lineup().first;
    final question = VivaLocalEngine.instance.askQuestion(
      config: config,
      member: member,
      questionIndex: 0,
      history: const [],
    );
    expect(question, contains('Langmuir'));
    expect(question, isNot(contains('المساهمة الأصلية')));
  });

  test('local engine turns a thesis issue into a discussion prompt', () {
    const issue = VivaThesisIssue(
      kind: 'inconsistency',
      quote: 'The abstract reports 95% removal',
      comment: 'Table 4 shows a mean of 71% at the same dose.',
    );
    const config = VivaSessionConfig(
      thesisTitle: 'Adsorption of lead on rice-husk biochar',
      thesisSummary:
          'Batch experiments compared Langmuir and Freundlich fits for lead removal at pH 3 to 7.',
      degree: 'ماجستير',
      methodology: 'كمي',
      specialization: 'Environmental engineering',
      university: 'University of Basra',
      issues: [issue],
    );
    final member = VivaCommittee.lineup().last;
    final question = VivaLocalEngine.instance.askQuestion(
      config: config,
      member: member,
      questionIndex: 0,
      history: const [],
    );
    expect(question, contains('71%'));
    expect(question.toLowerCase(), contains('inconsistency'));
  });

  test('derives viva questions from excerpt when JSON has none', () {
    const raw = '''
{
  "title": "Soybean oil refining at UCCMA",
  "summary": "The plant trial compared degumming temperature and bleaching earth dose against residual phosphorus and color.",
  "vivaQuestions": [],
  "excerpt": "Raising degumming temperature from 60 to 75 C reduced residual phosphorus. Bleaching earth at 1.2 percent improved color but increased oil loss. The economic model omitted spent-earth disposal cost."
}
''';
    final result = VivaPdfService.instance.parseExtraction(raw, 'thesis.docx');
    expect(result.extractedQuestions, isNotEmpty);
    expect(
      result.extractedQuestions.any((q) => q.contains('degumming') || q.contains('phosphorus')),
      isTrue,
    );
  });

  test('recovers issues from truncated JSON that cut off after vivaQuestions', () {
    const raw = '''
{
  "issues": [
    {"kind": "inconsistency", "quote": "abstract 95%", "comment": "Table 4 mean is 71%"},
    {"kind": "gap", "quote": "n = 12", "comment": "No power analysis"}
  ],
  "vivaQuestions": [
    "Why was n=12 chosen without a power analysis for the lead isotherms?"
  ],
  "title": "Lead adsorption",
  "excerpt": "Lead adsorption increased
''';
    final result = VivaPdfService.instance.parseExtraction(raw, 'thesis.docx');
    expect(result.issues.length, greaterThanOrEqualTo(2));
    expect(result.issues.any((i) => i.comment.contains('71%') || i.quote.contains('95%')), isTrue);
    expect(result.extractedQuestions, isNotEmpty);
    expect(
      result.extractedQuestions.any((q) => q.contains('power') || q.contains('71%') || q.contains('n=12') || q.contains('n = 12')),
      isTrue,
    );
  });

  test('accepts issues as a plain string list', () {
    const raw = '''
{
  "title": "Lead adsorption",
  "summary": "Batch experiments compared Langmuir and Freundlich fits for lead removal at pH 3 to 7 with a sample of twelve flasks.",
  "vivaQuestions": ["Which residual plot shows Langmuir is better than Freundlich for lead?"],
  "issues": [
    "The abstract reports 95% removal while Table 4 shows 71%.",
    "Sample size n=12 is not justified against effect size."
  ]
}
''';
    final result = VivaPdfService.instance.parseExtraction(raw, 'thesis.docx');
    expect(result.issues.length, 2);
    expect(result.issues.first.comment, contains('95%'));
  });

  test('drops shallow justify-this-point questions when issues exist', () {
    const raw = '''
{
  "title": "Lead adsorption",
  "summary": "Batch experiments compared Langmuir and Freundlich fits for lead removal at pH 3 to 7.",
  "vivaQuestions": [
    "في رسالتك ورد: «Lead adsorption increased». كيف تبرر هذه النقطة أمام اللجنة؟"
  ],
  "issues": [
    {"kind": "error", "quote": "p < 0.05", "comment": "No correction for six pairwise tests"}
  ]
}
''';
    final result = VivaPdfService.instance.parseExtraction(raw, 'thesis.docx');
    expect(result.issues, isNotEmpty);
    expect(
      result.extractedQuestions.every((q) => !q.contains('كيف تبرر هذه النقطة')),
      isTrue,
    );
    expect(result.extractedQuestions.any((q) => q.contains('pairwise') || q.contains('0.05')), isTrue);
  });

  test('session can start from extracted questions without a long summary', () {
    const config = VivaSessionConfig(
      thesisTitle: '',
      thesisSummary: 'قصير',
      degree: 'دكتوراه',
      methodology: 'كمي',
      specialization: 'كيمياء تحليلية',
      university: 'جامعة الأزهر',
      extractedQuestions: [
        'Why was n=12 chosen without a power analysis for the lead isotherms?',
      ],
    );
    expect(config.isValid, isTrue);
    expect(config.hasThesisMaterial, isTrue);
  });

  test('guesses title and supervisors from an Arabic cover page', () {
    const cover = '''
بسم الله الرحمن الرحيم
جامعة الأزهر
كلية العلوم
عنوان الرسالة
تقدير بعض المعادن الثقيلة في المياه الجوفية باستخدام التحليل الطيفي
إشراف
أ.د. محمد عبد الرحمن حسن
أ.د. فاطمة السيد علي
''';
    expect(
      VivaPdfService.guessTitleFromText(cover),
      contains('المعادن الثقيلة'),
    );
    final names = VivaPdfService.guessSupervisorsFromText(cover);
    expect(names, isNotEmpty);
    expect(names.any((n) => n.contains('محمد')), isTrue);
    expect(names.any((n) => n.contains('فاطمة')), isTrue);
  });

  test('applyCoverFallbacks fills title and supervisors when JSON omitted them', () {
    const cover = '''
عنوان الرسالة
تحليل طيفي للكافيين في المشروبات
المشرف الرئيسي: أ.د. خالد إبراهيم يوسف
''';
    final filled = VivaPdfService.applyCoverFallbacks(
      const VivaPdfExtractionResult(
        fileName: 'thesis.docx',
        title: 'thesis',
        summary: 'قصير',
        extractedQuestions: ['Which wavelength was used for caffeine?'],
      ),
      fileName: 'thesis.docx',
      coverText: cover,
    );
    expect(filled.title, contains('كافيين'));
    expect(filled.supervisorsFromThesis, isNotEmpty);
    expect(filled.supervisorFromThesis, contains('خالد'));
  });

  test('prioritizeThesisText keeps tail chapters instead of only the opening', () {
    final opening = 'TITLE PAGE AND ABSTRACT. ${'intro ' * 2000}';
    final methods = 'منهج الدراسة والعينة n=40 والاختبار t. ${'methods ' * 800}';
    final tail = 'النتائج والمناقشة والحدود. residual phosphorus declined.';
    final combined = '$opening$methods$tail';
    final sliced = VivaPdfService.prioritizeThesisText(combined, maxChars: 20000);
    expect(sliced.contains('النتائج والمناقشة'), isTrue);
    expect(sliced.contains('منهج الدراسة') || sliced.contains('methods'), isTrue);
  });
}
