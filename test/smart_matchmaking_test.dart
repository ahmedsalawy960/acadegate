import 'package:acadegate/features/academic/academic_models.dart';
import 'package:acadegate/features/lab_import/nbsle_university_cities.dart';
import 'package:acadegate/features/matchmaking/smart_matchmaking_engine.dart';
import 'package:acadegate/features/profile/academic_profile.dart';
import 'package:acadegate/features/research_supply_chain/research_goal.dart';
import 'package:acadegate/features/research_supply_chain/research_supply_chain_engine.dart';
import 'package:flutter_test/flutter_test.dart';

AcademicProfile _scienceProfile() {
  return const AcademicProfile(
    fullName: 'باحث',
    university: 'جامعة الفيوم',
    degree: 'ماجستير',
    facultyCategory: 'Science',
    specialization: 'الكيمياء التحليلية',
    researchInterest: 'تكرير الزيوت',
    methodology: 'كمي',
    preferredLanguage: 'العربية',
    city: 'الفيوم',
    skills: ['HPLC', 'analytical chemistry'],
  );
}

AcademicLab _lab({
  required String name,
  String equipment = '',
  String description = '',
  String facultyId = 'Science',
  String university = 'جامعة الفيوم',
  String city = 'الفيوم',
}) {
  return AcademicLab(
    name: name,
    location: university,
    equipment: equipment,
    description: description,
    facultyId: facultyId,
    category: facultyId,
    university: university,
    city: city,
    acceptsExternalSamples: true,
    ratingAvg: 4.8,
  );
}

AcademicResearchIdea _idea({
  required String title,
  String details = '',
  String category = 'Science',
}) {
  return AcademicResearchIdea(
    title: title,
    provider: 'AcadeGate',
    details: details,
    category: category,
    degreeLevel: 'masters',
  );
}

void main() {
  test('analytical chemistry does not infer a computing store section', () {
    final ids = ResearchSupplyChainEngine.inferStoreCategoryIds([
      'analytical',
      'chemistry',
      'edible',
      'oil',
    ]);
    expect(ids, contains('chemicals'));
    expect(ids, isNot(contains('computing')));
  });

  test('standalone ai still maps to computing', () {
    final ids = ResearchSupplyChainEngine.inferStoreCategoryIds([
      'artificial',
      'intelligence',
      'machine',
    ]);
    expect(ids, contains('computing'));
  });

  test('cybersecurity and geology labs do not match an oil-analysis goal', () {
    final goal = ResearchGoalParser.parse(
      'أريد عمل ماجستير في الكيمياء التحليلية لتطوير مصنع زيوت',
    );
    final tokens = ResearchGoalParser.relevanceTokens(goal);
    final matches = SmartMatchmakingEngine.matchLabs(
      _scienceProfile(),
      [
        _lab(
          name: 'مختبر التحليل الآلي',
          equipment: 'HPLC GC-MS UV-Vis',
          description: 'analytical chemistry of edible oils',
        ),
        _lab(name: 'معمل الأمن السيبراني', description: 'network security'),
        _lab(name: 'معمل الجيولوجيا', description: 'rock thin sections'),
        _lab(name: 'معمل البيئة النباتية', description: 'plant ecology'),
      ],
      limit: 6,
      softFallback: false,
      requireTokens: tokens,
    );

    expect(matches, isNotEmpty);
    expect(matches.first.item.name, contains('التحليل'));
    expect(
      matches.map((m) => m.item.name).join(' '),
      isNot(contains('السيبراني')),
    );
    expect(
      matches.map((m) => m.item.name).join(' '),
      isNot(contains('الجيولوجيا')),
    );
    expect(matches.every((m) => m.score < 100 || m.item.name.contains('تحليل')), isTrue);
  });

  test('psychology and media ideas drop when the goal is analytical oil', () {
    final goal = ResearchGoalParser.parse(
      'أريد عمل ماجستير في الكيمياء التحليلية لتطوير مصنع زيوت',
    );
    final tokens = ResearchGoalParser.relevanceTokens(goal);
    final matches = SmartMatchmakingEngine.matchResearchIdeas(
      _scienceProfile(),
      [
        _idea(
          title: 'تحليل الأحماض الدهنية في الزيت المكرر بـ GC-MS',
          details: 'analytical chemistry of edible oil refining',
        ),
        _idea(title: 'فحص مبكر لاضطرابات القلق والاكتئاب لدى طلاب السنوات السريرية'),
        _idea(title: 'مصداقية الأخبار الصحية على المنصات الاجتماعية أثناء الأزمات'),
        _idea(title: 'تقييم مخزون الكربون في أشجار المانجروف على ساحل البحر الأحمر'),
      ],
      limit: 6,
      softFallback: false,
      requireTokens: tokens,
    );

    expect(matches, isNotEmpty);
    expect(matches.first.item.title, contains('الزيت'));
    expect(
      matches.map((m) => m.item.title).join(' '),
      isNot(contains('القلق')),
    );
    expect(
      matches.map((m) => m.item.title).join(' '),
      isNot(contains('الأخبار')),
    );
  });

  test('store product names must share a topic token', () {
    final tokens = ['analytical', 'chemistry', 'oil', 'hplc', 'reagent'];
    expect(
      SmartMatchmakingEngine.topicHitCount(
        'Ethanol 99.8% HPLC grade reagent',
        tokens,
      ),
      greaterThan(0),
    );
    expect(
      SmartMatchmakingEngine.topicHitCount(
        'in 1 Multifunction Precision Torx Screwdriver Set',
        tokens,
      ),
      0,
    );
    expect(
      SmartMatchmakingEngine.topicHitCount(
        'UrsaLeo UrsaCloud UltraLite Development Kit',
        tokens,
      ),
      0,
    );
  });

  test('masters plan names the field and a measurement method', () {
    final goal = ResearchGoalParser.parse(
      'أريد عمل ماجستير في الكيمياء التحليلية لتطوير مصنع زيوت',
    );
    final plan = DegreePlanEngine.build(goal);
    final blob = plan.map((s) => '${s.title} ${s.outcomes.join(' ')}').join(' ');
    expect(blob.toLowerCase(), contains('تحليل'));
    expect(
      blob.toLowerCase().contains('hplc') ||
          blob.toLowerCase().contains('gc') ||
          blob.contains('زيت'),
      isTrue,
    );
    expect(blob, isNot(contains('تثبيت الموضوع والمشرف')));
  });

  test('Fayoum English equals الفيوم for city ranking', () {
    expect(NbsleUniversityCities.isSameCity('Fayoum', 'الفيوم'), isTrue);
    expect(NbsleUniversityCities.isSameCity('Alexandria', 'الفيوم'), isFalse);
    expect(NbsleUniversityCities.cityQueryValues('الفيوم'), contains('Fayoum'));
  });

  test('on-topic labs in the researcher city come before other cities', () {
    final goal = ResearchGoalParser.parse(
      'أريد عمل ماجستير في الكيمياء التحليلية لتطوير مصنع زيوت',
    );
    final tokens = ResearchGoalParser.relevanceTokens(goal);
    final matches = SmartMatchmakingEngine.matchLabs(
      _scienceProfile(),
      [
        _lab(
          name: 'مختبر التحليل بالإسكندرية',
          equipment: 'HPLC GC-MS',
          description: 'analytical chemistry of edible oils',
          city: 'Alexandria',
          university: 'جامعة الإسكندرية',
        ),
        _lab(
          name: 'مختبر التحليل بالفيوم',
          equipment: 'HPLC UV-Vis',
          description: 'analytical chemistry of edible oils',
          city: 'Fayoum',
          university: 'جامعة الفيوم',
        ),
      ],
      softFallback: false,
      requireTokens: tokens,
      cityFirst: true,
      localLimit: 8,
      otherLimit: 6,
    );

    expect(matches, hasLength(2));
    expect(matches.first.item.name, contains('الفيوم'));
    expect(matches.last.item.name, contains('الإسكندرية'));
  });
}
