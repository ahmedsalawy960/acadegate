import 'package:acadegate/features/academic_integrity/csl_formatting_service.dart';
import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:flutter_test/flutter_test.dart';

GroundedWork _work({
  String title = 'Drip irrigation and soybean yield',
  String doi = '10.2134/agronj1994.00021962008600050009x',
  int? year = 2011,
  String authors = 'Weaver, D B; R Rodriguez-Kabana',
  String? journal = 'Journal of Nematology',
  String externalUrl = '',
}) {
  return GroundedWork(
    title: title,
    source: 'Crossref',
    doi: doi,
    year: year,
    authors: authors,
    journal: journal,
    externalUrl: externalUrl,
  );
}

void main() {
  tearDown(() {
    CslFormattingService.debugFormat = null;
  });

  group('CslFormattingService.toCslJson', () {
    test('maps doi, year, journal and comma-split authors', () {
      final json = CslFormattingService.toCslJson(_work());
      expect(json['id'], '10.2134/agronj1994.00021962008600050009x');
      expect(json['type'], 'article-journal');
      expect(json['DOI'], '10.2134/agronj1994.00021962008600050009x');
      expect(json['issued'], {
        'date-parts': [
          [2011],
        ],
      });
      expect(json['container-title'], 'Journal of Nematology');
      expect(json['URL'], startsWith('https://doi.org/'));
      final authors = (json['author'] as List).cast<Map<String, dynamic>>();
      expect(authors[0], {'family': 'Weaver', 'given': 'D B'});
      expect(authors[1], {'literal': 'R Rodriguez-Kabana'});
    });

    test('works without doi use the merge key and skip DOI/URL', () {
      final json = CslFormattingService.toCslJson(_work(doi: '', year: null));
      expect(json['id'], startsWith('t:'));
      expect(json.containsKey('DOI'), isFalse);
      expect(json.containsKey('issued'), isFalse);
      expect(json.containsKey('URL'), isFalse);
    });

    test('splits authors on semicolons, "and" and Arabic separators', () {
      final json = CslFormattingService.toCslJson(
        _work(authors: 'Ali Ahmed and Mona Said؛Sara Omar'),
      );
      final authors = (json['author'] as List).cast<Map<String, dynamic>>();
      expect(authors, hasLength(3));
      expect(authors[0], {'literal': 'Ali Ahmed'});
      expect(authors[2], {'literal': 'Sara Omar'});
    });

    test('omits the author array when there are no authors', () {
      final json = CslFormattingService.toCslJson(_work(authors: ''));
      expect(json.containsKey('author'), isFalse);
    });
  });

  group('CslFormattingService.formatBibliography', () {
    test('maps works to CSL-JSON and returns entry texts', () async {
      String? seenStyle;
      String? seenLocale;
      List<Map<String, dynamic>>? seenItems;
      CslFormattingService.debugFormat = ({
        required style,
        required items,
        locale,
      }) async {
        seenStyle = style;
        seenLocale = locale;
        seenItems = items;
        return ['Weaver, D B. (2011). Drip irrigation.'];
      };
      final lines = await CslFormattingService.instance.formatBibliography(
        style: 'apa',
        works: [_work()],
        locale: 'en',
      );
      expect(lines, hasLength(1));
      expect(seenStyle, 'apa');
      expect(seenLocale, 'en');
      expect(seenItems, hasLength(1));
      expect(seenItems!.single['title'], 'Drip irrigation and soybean yield');
    });

    test('empty works list still passes through the seam', () async {
      CslFormattingService.debugFormat = ({
        required style,
        required items,
        locale,
      }) async {
        expect(items, isEmpty);
        return const [];
      };
      final lines = await CslFormattingService.instance.formatBibliography(
        style: 'apa',
        works: const [],
      );
      expect(lines, isEmpty);
    });
  });

  group('supportedStyles', () {
    test('stays in sync with the function bundle (12 styles)', () {
      expect(CslFormattingService.supportedStyles, hasLength(12));
      expect(CslFormattingService.supportedStyles.keys, contains('apa'));
      expect(
        CslFormattingService.supportedStyles.keys,
        contains('elsevier-vancouver'),
      );
    });
  });
}
