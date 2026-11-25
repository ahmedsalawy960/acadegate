import 'package:acadegate/features/academic_integrity/europe_pmc_client.dart';
import 'package:acadegate/features/academic_integrity/unpaywall_client.dart';
import 'package:acadegate/features/ai_advisor/assistant/assistant_tools.dart';
import 'package:flutter_test/flutter_test.dart';

const _jats = '''
<article><body>
<sec><title>Introduction</title>
<p>Biochar is used for water treatment.</p>
<table-wrap><table><tr><td>not prose</td></tr></table></table-wrap>
</sec>
<sec><title>Results</title>
<p>Removal reached 92% at pH 7.</p>
</sec>
</body>
<back><ref-list><ref>some reference</ref></ref-list></back>
</article>
''';

void main() {
  group('JATS full-text flattening', () {
    test('keeps section titles and paragraphs, drops tables and references', () {
      final text = EuropePmcClient.jatsBodyText(_jats);
      expect(text, contains('Introduction'));
      expect(text, contains('Biochar is used for water treatment.'));
      expect(text, contains('Removal reached 92% at pH 7.'));
      expect(text, isNot(contains('not prose')));
      expect(text, isNot(contains('some reference')));
    });

    test('returns empty for non-JATS input', () {
      expect(EuropePmcClient.jatsBodyText('not xml at all'), isEmpty);
    });
  });

  group('Unpaywall parsing', () {
    test('reads the best open-access location', () {
      final oa = UnpaywallClient.locationFromMap({
        'is_oa': true,
        'best_oa_location': {
          'url_for_pdf': 'https://example.org/paper.pdf',
          'url': 'https://example.org/paper',
        },
      });
      expect(oa.isOa, isTrue);
      expect(oa.bestUrl, 'https://example.org/paper.pdf');
    });

    test('closed papers give no location', () {
      final oa = UnpaywallClient.locationFromMap({'is_oa': false});
      expect(oa.bestUrl, isEmpty);
    });
  });

  group('read_paper_text tool', () {
    test('is declared and has neutral labels', () {
      final names =
          AssistantToolbox.declarations.map((d) => d['name'] as String).toList();
      expect(names, contains('read_paper_text'));
      expect(AssistantToolbox.statusLabel('read_paper_text').isNotEmpty, isTrue);
    });

    test('returns capped full text when the index has it', () async {
      final box = AssistantToolbox(
        fullTextForDoi: (doi) async => 'A' * 9000,
        oaLocationForDoi: (doi) async => const OaLocation(),
      );
      final out = await box.execute('read_paper_text', {'doi': '10.1000/x'});
      expect((out['full_text'] as String).length, 6001); // 6000 + ellipsis
      expect(out['truncated'], isTrue);
    });

    test('falls back to the open-access link, then to a plain note', () async {
      final withLink = AssistantToolbox(
        fullTextForDoi: (doi) async => '',
        oaLocationForDoi: (doi) async =>
            const OaLocation(isOa: true, landingUrl: 'https://example.org/p'),
      );
      final link = await withLink.execute('read_paper_text', {'doi': '10.1000/x'});
      expect(link['open_access_url'], 'https://example.org/p');

      final none = AssistantToolbox(
        fullTextForDoi: (doi) async => '',
        oaLocationForDoi: (doi) async => const OaLocation(),
      );
      final note = await none.execute('read_paper_text', {'doi': '10.1000/x'});
      expect('${note['note']}', contains('No open-access full text'));
    });

    test('rejects a bad DOI without calling the indexes', () async {
      var called = false;
      final box = AssistantToolbox(
        fullTextForDoi: (doi) async {
          called = true;
          return '';
        },
      );
      final out = await box.execute('read_paper_text', {'doi': 'abc'});
      expect(out['error'], 'doi too short');
      expect(called, isFalse);
    });
  });
}
