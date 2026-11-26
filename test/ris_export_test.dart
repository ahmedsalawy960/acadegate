import 'package:acadegate/features/ai_advisor/grounded_work.dart';
import 'package:acadegate/features/ai_advisor/ris_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RisExport', () {
    test('emits a complete RIS record per work', () {
      final ris = RisExport.forWorks(const [
        GroundedWork(
          title: 'Biochar for water treatment',
          source: 'OpenAlex',
          doi: '10.1000/xyz123',
          year: 2023,
          authors: 'Ali, Ahmed, Samy, Mona',
          journal: 'Journal of Cleaner Production',
          abstractText: 'A study\nwith lines.',
        ),
      ]);
      expect(ris, contains('TY  - JOUR'));
      expect(ris, contains('TI  - Biochar for water treatment'));
      expect(ris, contains('AU  - Ali'));
      expect(ris, contains('AU  - Ahmed'));
      expect(ris, contains('AU  - Samy'));
      expect(ris, contains('AU  - Mona'));
      expect(ris, contains('PY  - 2023'));
      expect(ris, contains('JO  - Journal of Cleaner Production'));
      expect(ris, contains('AB  - A study with lines.'));
      expect(ris, contains('DO  - 10.1000/xyz123'));
      expect(ris, contains('UR  - https://doi.org/10.1000/xyz123'));
      expect(ris.trimRight().endsWith('ER  -'), isTrue);
    });

    test('skips absent fields and invalid DOIs', () {
      final ris = RisExport.forWorks(const [
        GroundedWork(title: 'Bare work', source: 'OpenAlex'),
      ]);
      expect(ris, contains('TI  - Bare work'));
      expect(ris, isNot(contains('DO  -')));
      expect(ris, isNot(contains('PY  -')));
      expect(ris, isNot(contains('JO  -')));
      expect(ris, isNot(contains('UR  -')));
    });

    test('empty input yields empty output', () {
      expect(RisExport.forWorks(const []), isEmpty);
    });
  });
}
