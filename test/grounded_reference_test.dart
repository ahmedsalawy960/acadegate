import 'package:acadegate/features/ai_advisor/advisor_agent.dart';
import 'package:acadegate/features/ai_advisor/advisor_query_parser.dart';
import 'package:acadegate/features/ai_advisor/advisor_router.dart';
import 'package:acadegate/features/ai_advisor/grounded_reference_service.dart';
import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:acadegate/features/ai_advisor/literature_relevance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DOI extract and normalize', () {
    test('strips doi.org URLs and trailing punctuation', () {
      expect(
        GroundedReferenceService.normalizeDoi(
          'https://doi.org/10.1038/NATURE12373.',
        ),
        '10.1038/nature12373',
      );
      expect(
        GroundedReferenceService.normalizeDoi(
          'https://dx.doi.org/10.1000/xyz123',
        ),
        '10.1000/xyz123',
      );
    });

    test('extracts DOIs from mixed text', () {
      const text =
          'See https://doi.org/10.1038/nature12373 and doi:10.1000/xyz123.';
      final dois = GroundedReferenceService.extractDois(text);
      expect(dois, contains('10.1038/nature12373'));
      expect(dois, contains('10.1000/xyz123'));
    });
  });

  group('topic vs paste', () {
    test('topicFromMessage keeps the subject of أعطني مراجع عن …', () {
      final topic = GroundedReferenceService.topicFromMessage(
        'أعطني مراجع عن adsorption of heavy metals on biochar',
      );
      expect(topic.toLowerCase(), contains('adsorption of heavy metals'));
      expect(topic.toLowerCase(), isNot(contains('مراجع')));
    });

    test('a topic request is not treated as a bibliography paste', () {
      expect(
        GroundedReferenceService.looksLikeBibliographyPaste(
          'أعطني مراجع عن adsorption of heavy metals on biochar',
        ),
        isFalse,
      );
    });

    test('a pasted DOI is treated as a bibliography to verify', () {
      expect(
        GroundedReferenceService.looksLikeBibliographyPaste(
          'تحقق من 10.1038/nature12373',
        ),
        isTrue,
      );
    });

    test('a year-list paste without DOI still looks like a bibliography', () {
      expect(
        GroundedReferenceService.looksLikeBibliographyPaste(
          'Smith, J. (2020). A long enough article title about methods and data.\n'
          'Brown, A. (2021). Another long enough article title about results and limits.',
        ),
        isTrue,
      );
    });
  });

  group('verified-only bibliography', () {
    test('apaLine always includes the real doi.org URL', () {
      const work = GroundedWork(
        title: 'Adsorption of metals',
        doi: '10.1016/example.2020.01.001',
        source: 'OpenAlex',
        year: 2020,
        authors: 'Lee, A.',
      );
      expect(work.apaLine, contains('https://doi.org/10.1016/example.2020.01.001'));
    });

    test('replyForCitations asks for a topic instead of inventing sources', () {
      final reply = GroundedReferenceService.instance.replyForCitations(
        const GroundedReferenceBundle(topic: ''),
        message: 'أعطني مراجع',
      );
      expect(reply.toLowerCase(), isNot(contains('smith')));
      expect(reply, contains('OpenAlex'));
    });

    test('empty search does not invent a DOI', () {
      final reply = GroundedReferenceService.instance.replyForCitations(
        const GroundedReferenceBundle(topic: 'adsorption of heavy metals'),
        message: 'أعطني مراجع عن adsorption of heavy metals',
      );
      expect(GroundedReferenceService.extractDois(reply), isEmpty);
      expect(reply.toLowerCase(), isNot(contains('smith')));
    });

    test('enforceVerifiedDois keeps known DOIs and strips invented ones', () async {
      const known = GroundedReferenceBundle(
        topic: 'nature',
        works: [
          GroundedWork(
            title: 'A real paper',
            doi: '10.1038/nature12373',
            source: 'OpenAlex',
            year: 2012,
            authors: 'X',
          ),
        ],
      );
      const text =
          'Real: 10.1038/nature12373. Fake: 10.9999/totally.fake.doi.2020';
      final cleaned = await GroundedReferenceService.instance.enforceVerifiedDois(
        text,
        known: known,
        lookup: (_) async => null,
      );
      expect(cleaned, contains('10.1038/nature12373'));
      expect(cleaned, isNot(contains('10.9999/totally.fake.doi.2020')));
    });
  });

  test('router sends مرجع requests to the citations agent', () {
    expect(
      AcademicQueryParser.parse(
        'أعطني مراجع عن adsorption of heavy metals on biochar',
      ).goal,
      AcademicQueryGoal.citations,
    );
    expect(
      AdvisorRouter.instance
          .route('أعطني مراجع عن adsorption of heavy metals on biochar')
          .primary,
      AdvisorAgentId.citations,
    );
  });

  test('relevance ranking follows each user’s topic, any discipline', () {
    const nano = GroundedWork(
      title: 'Green synthesis of zinc oxide nanomaterials',
      doi: '10.1000/nano.1',
      source: 'OpenAlex',
      year: 2021,
    );
    const verse = GroundedWork(
      title: 'Narrative discourse in the contemporary Arabic novel',
      doi: '10.1000/lit.1',
      source: 'OpenAlex',
      year: 2019,
    );
    const generic = GroundedWork(
      title: 'A general study of products and development',
      doi: '10.1000/gen.1',
      source: 'Crossref',
      year: 2024,
    );

    final nanoRanked = LiteratureRelevance.rank(
      works: const [nano, verse, generic],
      corePhrases: const ['nanomaterials'],
      strongTokens: const ['nanomaterials', 'zinc'],
      limit: 10,
    );
    expect(nanoRanked.map((w) => w.doi), contains('10.1000/nano.1'));
    expect(nanoRanked.map((w) => w.doi), isNot(contains('10.1000/lit.1')));

    final litRanked = LiteratureRelevance.rank(
      works: const [nano, verse, generic],
      corePhrases: const ['arabic novel', 'discourse'],
      strongTokens: const ['narrative', 'discourse', 'novel'],
      limit: 10,
    );
    expect(litRanked.map((w) => w.doi), contains('10.1000/lit.1'));
    expect(litRanked.map((w) => w.doi), isNot(contains('10.1000/nano.1')));
  });

  test('rejects opportunistic COVID and generic ML agriculture noise', () {
    const onTopic = GroundedWork(
      title: 'Domestication history of Brassica napus oilseed rape',
      doi: '10.1000/napus.1',
      source: 'OpenAlex',
      year: 2021,
      abstractText: 'Botanical origins and biochemical profile of Brassica napus.',
    );
    const covid = GroundedWork(
      title:
          'A global panel database of pandemic policies (Oxford COVID-19 Government Response Tracker)',
      doi: '10.1000/covid.1',
      source: 'OpenAlex',
      year: 2021,
    );
    const mlAg = GroundedWork(
      title: 'Machine Learning in Agriculture: A Comprehensive Updated Review',
      doi: '10.1000/ml.1',
      source: 'OpenAlex',
      year: 2021,
      abstractText: 'Survey of machine learning applications across crops.',
    );
    const method = GroundedWork(
      title:
          'Literature review as a research methodology: An overview and guidelines',
      doi: '10.1000/method.1',
      source: 'Crossref',
      year: 2019,
    );
    const spivak = GroundedWork(
      title: 'Three Women\'s Texts and a Critique of Imperialism',
      doi: '10.1000/spivak.1',
      source: 'OpenAlex',
      year: 1985,
      abstractText: 'Postcolonial literary criticism of women\'s texts.',
    );
    const tesol = GroundedWork(
      title:
          'Language, Context, and Text: Aspects of Language in a Social-Semiotic Perspective',
      doi: '10.1000/tesol.1',
      source: 'OpenAlex',
      year: 1987,
      journal: 'TESOL Quarterly',
    );

    final ranked = LiteratureRelevance.rank(
      works: const [onTopic, covid, mlAg, method, spivak, tesol],
      corePhrases: const ['brassica napus', 'domestication'],
      strongTokens: const ['brassica', 'napus', 'botanical'],
      requireCoreHit: true,
      requireTitleCoreHit: true,
      minScore: 5,
      commandText:
          'botanical origins and domestication of Brassica napus biochemical profile',
      limit: 10,
    );
    expect(ranked.map((w) => w.doi), ['10.1000/napus.1']);
    expect(
      LiteratureRelevance.isOpportunisticJunkWork(
        covid,
        'botanical origins Brassica napus',
      ),
      isTrue,
    );
    expect(
      LiteratureRelevance.isOpportunisticJunkWork(
        spivak,
        'botanical origins Brassica napus',
      ),
      isTrue,
    );
    expect(
      LiteratureRelevance.isOpportunisticJunkWork(
        tesol,
        'botanical origins Brassica napus',
      ),
      isTrue,
    );
  });
}
