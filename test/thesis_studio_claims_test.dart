import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:acadegate/features/research_supply_chain/research_goal.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_claims.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_kind.dart';
import 'package:acadegate/features/thesis_studio/thesis_studio_models.dart';
import 'package:flutter_test/flutter_test.dart';

GroundedWork _work(
  String title, {
  String doi = '',
  int? year,
  String authors = '',
  String abstractText = '',
}) =>
    GroundedWork(
      title: title,
      source: 'acadegate',
      doi: doi,
      year: year,
      authors: authors,
      abstractText: abstractText,
      externalUrl: 'https://example.org/$title',
    );

ThesisDraft _draft({
  PublishCitationStyle style = PublishCitationStyle.ieee,
  List<GroundedWork> literature = const [],
  List<ThesisChapter> chapters = const [],
}) {
  final goal = const ResearchGoal(raw: 'test goal', field: 'chemistry');
  return ThesisDraft(
    goal: goal,
    plan: ThesisPlan(
      goal: goal,
      kind: ThesisKind.experimental,
      shape: ThesisShape.arabicEmpirical,
      arabic: false,
      citationStyle: style,
    ),
    literature: GroundedReferenceBundle(topic: 't', works: literature),
    chapters: chapters,
  );
}

ThesisParagraph _paragraph(List<GroundedWork> refs) => ThesisParagraph(
      id: 'p1',
      headingAr: 'ه',
      headingEn: 'H',
      references: refs,
    );

void main() {
  final refs = [
    _work(
      'Adsorption of dyes',
      doi: '10.1000/xyz1',
      year: 2021,
      authors: 'Smith, J.; Doe, A.',
      abstractText:
          'We study adsorption kinetics of textile dyes on activated carbon. '
          'Adsorption capacity reached 120 mg per gram of activated carbon. '
          'Unrelated closing remark about future work.',
    ),
    _work('Membrane filtration', year: 2019, authors: 'Lee, K.'),
    _work('Catalysis review', year: 2020, authors: 'Omar, S.'),
  ];

  test('sentences map markers to works, ranges expanded, order kept', () {
    final draft = _draft(literature: refs);
    final claims = ThesisClaimMapper.mapBody(
      body:
          'Dye removal improved significantly [1-2]. No citation here. '
          'Prior reviews disagree [3, 1].',
      draft: draft,
    );
    expect(claims.length, 3);
    expect(
      claims[0].sources.map((s) => s.marker).toList(),
      [1, 2],
    );
    expect(claims[0].cited, isTrue);
    expect(claims[0].sources[0].work!.title, 'Adsorption of dyes');
    expect(claims[0].sources[1].work!.title, 'Membrane filtration');
    expect(claims[1].hasMarkers, isFalse);
    expect(claims[1].cited, isFalse);
    expect(
      claims[2].sources.map((s) => s.marker).toList(),
      [3, 1],
    );
  });

  test('marker beyond the list resolves to unknownMarker, never a guess', () {
    final draft = _draft(literature: refs);
    final claims = ThesisClaimMapper.mapBody(
      body: 'A bold claim [9].',
      draft: draft,
    );
    final source = claims.single.sources.single;
    expect(source.work, isNull);
    expect(source.level, ClaimEvidenceLevel.unknownMarker);
    expect(claims.single.hasUnknown, isTrue);
    expect(claims.single.cited, isFalse);
  });

  test('paragraph-local harvest list wins over the global list', () {
    final paragraphRefs = [
      _work('Local harvest paper', year: 2022, authors: 'Nagy, R.'),
    ];
    final paragraph = _paragraph(paragraphRefs);
    final draft = _draft(
      literature: refs,
      chapters: [
        ThesisChapter(
          id: 'c1',
          titleAr: 'ف',
          titleEn: 'C',
          paragraphs: [paragraph],
        ),
      ],
    );
    final claims = ThesisClaimMapper.mapBody(
      body: 'Local claim [1].',
      draft: draft,
      paragraph: paragraph,
    );
    expect(claims.single.sources.single.work!.title, 'Local harvest paper');
  });

  test('abstract-backed source quotes the best-matching abstract sentence',
      () {
    final draft = _draft(literature: refs);
    final claims = ThesisClaimMapper.mapBody(
      body:
          'Activated carbon reached an adsorption capacity of 120 mg per gram [1].',
      draft: draft,
    );
    final source = claims.single.sources.single;
    expect(source.level, ClaimEvidenceLevel.abstractOnly);
    expect(
      source.quote,
      'Adsorption capacity reached 120 mg per gram of activated carbon.',
    );
  });

  test('no quote when the abstract shares no real content words', () {
    final draft = _draft(literature: refs);
    final claims = ThesisClaimMapper.mapBody(
      body: 'Quantum entanglement enables teleportation of states [1].',
      draft: draft,
    );
    expect(claims.single.sources.single.quote, isEmpty);
  });

  test('work without abstract is metadataOnly with no quote', () {
    final draft = _draft(literature: refs);
    final claims = ThesisClaimMapper.mapBody(
      body: 'Filtration removes particles [2].',
      draft: draft,
    );
    final source = claims.single.sources.single;
    expect(source.level, ClaimEvidenceLevel.metadataOnly);
    expect(source.quote, isEmpty);
  });

  test('numbered style keeps [n] in the display text', () {
    final draft = _draft(style: PublishCitationStyle.ieee, literature: refs);
    final claims = ThesisClaimMapper.mapBody(
      body: 'Dye removal improved [1].',
      draft: draft,
    );
    expect(claims.single.display, contains('[1]'));
  });

  test('author-date style renders (Surname, Year) in the display text', () {
    final draft = _draft(style: PublishCitationStyle.apa, literature: refs);
    final claims = ThesisClaimMapper.mapBody(
      body: 'Dye removal improved [1].',
      draft: draft,
    );
    expect(claims.single.display, contains('2021'));
    expect(claims.single.display, contains('Smith'));
    expect(claims.single.display, isNot(contains('[1]')));
    // Resolution still comes from the raw [n] marker.
    expect(claims.single.sources.single.work!.title, 'Adsorption of dyes');
  });

  test('markdown leftovers are stripped from the display, not the raw', () {
    final draft = _draft(literature: refs);
    final claims = ThesisClaimMapper.mapBody(
      body: '**Bold** claim with `code` [1].',
      draft: draft,
    );
    expect(claims.single.display, isNot(contains('**')));
    expect(claims.single.display, isNot(contains('`')));
    expect(claims.single.raw, contains('**'));
    expect(claims.single.cited, isTrue);
  });

  test('Arabic sentences split and resolve', () {
    final arabicRefs = [
      _work(
        'دراسة الامتزاز',
        year: 1444,
        authors: 'محمد أحمد',
        abstractText:
            'درست هذه الورقة حركية الامتزاز على الكربون المنشط. '
            'بلغت سعة الامتزاز قيمة عالية في كل التجارب المعملية.',
      ),
    ];
    final draft = _draft(literature: arabicRefs);
    final claims = ThesisClaimMapper.mapBody(
      body:
          'تحسّنت إزالة الصبغة بشكل واضح [1]. جملة ثانية بلا استشهاد.',
      draft: draft,
    );
    expect(claims.length, 2);
    expect(claims[0].cited, isTrue);
    expect(claims[0].sources.single.level, ClaimEvidenceLevel.abstractOnly);
    expect(claims[1].hasMarkers, isFalse);
  });
}
