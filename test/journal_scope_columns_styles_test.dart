import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/journal_guidelines_heuristic.dart';
void main(){
 test('figure width columns do not define manuscript layout',(){final r=JournalGuidelinesHeuristic.extract('The manuscript should be double-spaced. Figures can span one column (85 mm) or two columns (180 mm).',requireDistinctive:false)!;expect(r['columns'],isNull);});
 test('revised stage and latex column examples stay scoped',(){final r=JournalGuidelinesHeuristic.extract('''The manuscript should be double-spaced.
## Revised manuscripts
Format the manuscript file as single-column text.
## LaTeX
Equations spanning two columns
''',requireDistinctive:false)!;expect(r['columns'],isNull);});
 test('explicit manuscript columns are retained',(){for(final item in {'Prepare the manuscript in a two-column layout.':2,'The manuscript must use single-column text.':1}.entries){final r=JournalGuidelinesHeuristic.extract('${item.key} Double-spaced text.',requireDistinctive:false)!;expect(r['columns'],item.value);}});
 test('publisher alternative citation styles do not choose a sample journal name',(){final r=JournalGuidelinesHeuristic.extract("The manuscript should be double-spaced. Journals use one of two reference styles, either Harvard (author-date) or Vancouver (numbered). Reference example: Smith (2021). Chemistry. ACS Omega.",requireDistinctive:false)!;expect(r['citationStyle'],isNull);expect(r['citationStyleUnresolved'],true);expect(r['keyRequirements'],isNot(contains('ACS citation style')));});
}
