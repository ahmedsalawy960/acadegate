import 'package:acadegate/features/research_supply_chain/research_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a master’s goal in a field for a factory', () {
    final goal = ResearchGoalParser.parse(
      'أريد عمل ماجستير في الكيمياء التحليلية لتطوير مصنع زيوت',
    );

    expect(goal.track, ResearchDegreeTrack.masters);
    expect(goal.institution, InstitutionTarget.factory);
    expect(goal.field.toLowerCase(), contains('الكيمياء التحليلية'));
    expect(goal.years, 2);
  });

  test('parses an English PhD goal', () {
    final goal = ResearchGoalParser.parse(
      'I want a PhD in nanomaterials for a ministry',
    );

    expect(goal.track, ResearchDegreeTrack.phd);
    expect(goal.institution, InstitutionTarget.ministry);
    expect(goal.field.toLowerCase(), contains('nanomaterials'));
    expect(goal.years, 3);
  });

  test('off-topic English titles are rejected against the field tokens', () {
    final goal = ResearchGoalParser.applyLocalEnglish(
      const ResearchGoal(
        raw: 'ماجستير في الكيمياء التحليلية',
        field: 'الكيمياء التحليلية',
      ),
    );
    final tokens = ResearchGoalParser.relevanceTokens(goal);
    expect(goal.fieldEn.toLowerCase(), contains('analytical'));
    expect(
      ResearchGoalParser.titleMatchesTopic(
        'Fatty acid profile of refined soybean oil by GC-MS',
        ['analytical', 'chemistry', 'oil', 'gc-ms'],
      ),
      isTrue,
    );
    expect(
      ResearchGoalParser.titleMatchesTopic(
        'A randomized trial of soccer training in teenagers',
        tokens,
      ),
      isFalse,
    );
  });

  test('multi-sentence goal keeps every sentence and a short field', () {
    final goal = ResearchGoalParser.parse(
      'أريد ماجستير في الكيمياء التحليلية لتكرير زيوت الطعام. '
      'أقارن HPLC وGC-MS لتقدير الأحماض الدهنية. '
      'العينات من ثلاثة خطوط تكرير صناعي.',
    );
    expect(goal.raw, contains('HPLC'));
    expect(goal.raw, contains('ثلاثة خطوط'));
    expect(goal.field.toLowerCase(), contains('الكيمياء التحليلية'));
    expect(goal.field.contains('ثلاثة خطوط'), isFalse);
    expect(ResearchGoalParser.looksLikePastedManuscript(goal.raw), isFalse);
    final tokens = ResearchGoalParser.relevanceTokens(goal).join(' ').toLowerCase();
    expect(tokens, contains('hplc'));
    expect(tokens, contains('gc'));
  });

  test('search queries follow the user’s field, not a hardcoded crop', () {
    final nano = ResearchGoalParser.parse(
      'I want a PhD in nanomaterials for a ministry',
    );
    final queries = ResearchGoalParser.scientificSearchQueries(nano);
    expect(queries.join(' ').toLowerCase(), contains('nanomaterials'));
    expect(queries.join(' ').toLowerCase(), isNot(contains('soybean')));
    expect(queries.join(' ').toLowerCase(), isNot(contains('flaxseed')));

    final poetry = ResearchGoalParser.parse('ماجستير في نقد الرواية العربية المعاصرة');
    final poetryQ = ResearchGoalParser.scientificSearchQueries(
      poetry,
      includeNativeField: true,
    ).join(' ');
    expect(poetryQ.toLowerCase(), isNot(contains('hplc')));
    expect(poetryQ.toLowerCase(), isNot(contains('oilseed')));
  });

  test('masters plan has four semesters and cites the 15-study rule', () {
    final goal = ResearchGoalParser.parse('ماجستير في adsorption');
    final plan = DegreePlanEngine.build(goal);

    expect(plan, hasLength(4));
    expect(plan.first.outcomes.join(' '), contains('15'));
    expect(
      DegreePlanEngine.institutionalNotes(goal),
      isNotEmpty,
    );
  });
}
