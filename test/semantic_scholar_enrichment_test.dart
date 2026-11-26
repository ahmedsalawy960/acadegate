import 'package:acadegate/features/academic_integrity/semantic_scholar_client.dart';
import 'package:acadegate/features/ai_advisor/grounded_reference_service.dart';
import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Semantic Scholar enrichment parsing', () {
    test('parses tldr and citation count', () {
      final paper = SemanticScholarClient.paperFromMap({
        'title': 'Biochar for heavy metals',
        'year': 2023,
        'authors': [
          {'name': 'A. Ali'},
          {'name': 'B. Samy'},
        ],
        'externalIds': {'DOI': '10.1000/xyz123'},
        'venue': 'Journal of Cleaner Production',
        'abstract': 'Long abstract text.',
        'tldr': {'model': 'tldr@v2', 'text': 'Biochar removes heavy metals from water.'},
        'citationCount': 240,
      });
      expect(paper.tldr, 'Biochar removes heavy metals from water.');
      expect(paper.citationCount, 240);
      expect(paper.doi, '10.1000/xyz123');
    });

    test('tolerates missing tldr and citation count', () {
      final paper = SemanticScholarClient.paperFromMap({
        'title': 'Old paper',
        'abstract': 'x',
      });
      expect(paper.tldr, isEmpty);
      expect(paper.citationCount, isNull);
    });
  });

  group('mergeWorks keeps enrichment', () {
    test('fills tldr and citations from the incoming record', () {
      const existing = GroundedWork(
        title: 'Biochar for heavy metals',
        source: 'OpenAlex',
        doi: '10.1000/xyz123',
        year: 2023,
      );
      const incoming = GroundedWork(
        title: 'Biochar for heavy metals',
        source: 'Semantic Scholar',
        doi: '10.1000/xyz123',
        year: 2023,
        tldr: 'Biochar removes heavy metals from water.',
        citationCount: 240,
      );
      final merged = GroundedReferenceService.mergeWorks(existing, incoming);
      expect(merged.doi, '10.1000/xyz123');
      expect(merged.tldr, 'Biochar removes heavy metals from water.');
      expect(merged.citationCount, 240);
    });

    test('existing enrichment wins over a bare incoming record', () {
      const existing = GroundedWork(
        title: 'Biochar for heavy metals',
        source: 'Semantic Scholar',
        doi: '10.1000/xyz123',
        tldr: 'Existing summary.',
        citationCount: 12,
      );
      const incoming = GroundedWork(
        title: 'Biochar for heavy metals',
        source: 'Crossref',
        doi: '10.1000/xyz123',
      );
      final merged = GroundedReferenceService.mergeWorks(existing, incoming);
      expect(merged.tldr, 'Existing summary.');
      expect(merged.citationCount, 12);
    });
  });
}
