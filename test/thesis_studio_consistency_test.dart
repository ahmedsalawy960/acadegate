import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:acadegate/features/research_supply_chain/research_goal.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_consistency.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_kind.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_models.dart';
import 'package:flutter_test/flutter_test.dart';

ThesisDraft _draft({
  List<String> questions = const [],
  List<String> methods = const [],
  List<ThesisChapter> chapters = const [],
}) {
  final goal = ResearchGoal(
    raw: 'Improving dye removal from textile wastewater',
    field: 'chemistry',
    methods: methods,
  );
  return ThesisDraft(
    goal: goal,
    plan: ThesisPlan(
      goal: goal,
      kind: ThesisKind.experimental,
      shape: ThesisShape.englishExperimentalMerged,
      arabic: false,
    ),
    literature: const GroundedReferenceBundle(topic: ''),
    researchQuestions: questions,
    chapters: chapters,
  );
}

ThesisChapter _chapter(
  String id, {
  ThesisChapterDepth depth = ThesisChapterDepth.full,
  String body = '',
  String titleEn = '',
}) =>
    ThesisChapter(
      id: id,
      titleAr: id,
      titleEn: titleEn.isEmpty ? id : titleEn,
      body: body,
      depth: depth,
    );

void main() {
  test('question with method keyword and answering chapter is aligned', () {
    final draft = _draft(
      questions: [
        'Can activated carbon adsorption improve dye removal capacity?',
      ],
      methods: ['adsorption'],
      chapters: [
        _chapter('intro', body: 'General background on water pollution.'),
        _chapter(
          'results_discussion',
          body:
              'Activated carbon adsorption improved dye removal capacity '
              'across all experimental runs and conditions measured here.',
        ),
      ],
    );
    final matrix = ThesisConsistency.analyze(draft);
    expect(matrix.rows.single.verdict, ConsistencyVerdict.aligned);
    expect(matrix.rows.single.hasMethod, isTrue);
    expect(matrix.rows.single.methodEvidence, 'adsorption');
    expect(matrix.rows.single.answeringChapterId, 'results_discussion');
    expect(matrix.alignedCount, 1);
    expect(matrix.unansweredCount, 0);
    expect(matrix.chaptersHaveProse, isTrue);
  });

  test('the key case: a question with no way to answer it is flagged', () {
    final draft = _draft(
      questions: [
        'Can activated carbon adsorption improve dye removal capacity?',
        'What is the socioeconomic history of medieval trade routes?',
      ],
      methods: ['adsorption'],
      chapters: [
        _chapter(
          'results_discussion',
          body:
              'Activated carbon adsorption improved dye removal capacity '
              'across all experimental runs and conditions measured here.',
        ),
      ],
    );
    final matrix = ThesisConsistency.analyze(draft);
    expect(matrix.rows[0].verdict, ConsistencyVerdict.aligned);
    expect(matrix.rows[1].verdict, ConsistencyVerdict.unanswered);
    expect(matrix.unansweredCount, 1);
  });

  test('method chapter prose counts as a method pathway', () {
    final draft = _draft(
      questions: ['Does membrane filtration reduce turbidity levels?'],
      chapters: [
        _chapter(
          'experimental',
          depth: ThesisChapterDepth.protocol,
          body:
              'Membrane filtration units were operated at constant pressure '
              'and turbidity levels were recorded before and after.',
        ),
        _chapter(
          'results',
          body:
              'Membrane filtration reduced turbidity levels by half in '
              'every measured trial condition.',
        ),
      ],
    );
    final matrix = ThesisConsistency.analyze(draft);
    final row = matrix.rows.single;
    expect(row.hasMethod, isTrue);
    expect(row.verdict, ConsistencyVerdict.aligned);
    expect(row.answeringChapterId, 'results');
  });

  test('answered in prose but without a method pathway is noClearMethod', () {
    final draft = _draft(
      questions: ['Does membrane filtration reduce turbidity levels?'],
      chapters: [
        _chapter(
          'results',
          body:
              'Membrane filtration reduced turbidity levels by half in '
              'every measured trial condition.',
        ),
      ],
    );
    final matrix = ThesisConsistency.analyze(draft);
    expect(matrix.rows.single.verdict, ConsistencyVerdict.noClearMethod);
  });

  test('empty chapters: matrix reports prose absence instead of red rows',
      () {
    final draft = _draft(
      questions: ['Does membrane filtration reduce turbidity levels?'],
      methods: ['filtration'],
      chapters: [
        _chapter('results', body: ''),
        _chapter('discussion', body: ''),
      ],
    );
    final matrix = ThesisConsistency.analyze(draft);
    expect(matrix.chaptersHaveProse, isFalse);
    expect(
      matrix.rows.single.verdict,
      ConsistencyVerdict.noAnsweringChapter,
    );
  });

  test('Arabic question tokens match Arabic chapter prose', () {
    final goal = const ResearchGoal(
      raw: 'تحسين إزالة الصبغة من مياه الصرف',
      field: 'كيمياء',
      methods: ['امتزاز'],
    );
    final draft = ThesisDraft(
      goal: goal,
      plan: ThesisPlan(
        goal: goal,
        kind: ThesisKind.experimental,
        shape: ThesisShape.arabicEmpirical,
        arabic: true,
      ),
      literature: const GroundedReferenceBundle(topic: ''),
      researchQuestions: const [
        'هل يحسّن الامتزاز على الكربون سعة إزالة الصبغة؟',
      ],
      chapters: [
        ThesisChapter(
          id: 'results_discussion',
          titleAr: 'النتائج والمناقشة',
          titleEn: 'Results',
          body:
              'أظهرت النتائج أن الامتزاز على الكربون المنشط حسّن سعة إزالة '
              'الصبغة في جميع التجارب المعملية المقاسة.',
        ),
      ],
    );
    final matrix = ThesisConsistency.analyze(draft);
    expect(matrix.rows.single.verdict, ConsistencyVerdict.aligned);
    expect(matrix.rows.single.methodEvidence, 'امتزاز');
  });

  test('problem statement comes from the goal', () {
    final draft = _draft(questions: const []);
    final matrix = ThesisConsistency.analyze(draft);
    expect(matrix.problem, contains('dye removal'));
    expect(matrix.rows, isEmpty);
  });
}
