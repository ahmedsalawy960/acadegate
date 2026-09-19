import '../../core/locale/app_translate.dart';
import '../ai_advisor/grounded_work.dart';
import 'thesis_studio_models.dart';

class ThesisLiteratureMapper {
  ThesisLiteratureMapper._();

  static List<LiteratureMapRow> fromBundle(GroundedReferenceBundle bundle) {
    return [
      for (var i = 0; i < bundle.works.length; i++)
        LiteratureMapRow(
          index: i + 1,
          work: bundle.works[i],
          focus: _focus(bundle.works[i]),
          notes: _notes(bundle.works[i]),
        ),
    ];
  }

  static String comparisonTable(List<LiteratureMapRow> rows, {required bool arabic}) {
    if (rows.isEmpty) {
      return appTr(
        'لا يوجد جدول مقارنة بعد — لم تُؤكَّد دراسات DOI.',
        'No comparison table yet — no DOI-confirmed studies.',
      );
    }
    final buffer = StringBuffer(
      arabic
          ? 'جدول مقارنة الأدبيات (من بيانات مؤكدة فقط؛ الفرض والعينة تُستخرج من النص الأصلي):\n'
          : 'Literature comparison (confirmed metadata only; hypotheses and sample size come from the original text):\n',
    );
    for (final row in rows) {
      final w = row.work;
      buffer.writeln(
        '[${row.index}] ${w.authors.isEmpty ? '—' : w.authors} | ${w.year ?? 'n.d.'} | ${w.title}'
        '${w.journal == null || w.journal!.isEmpty ? '' : ' | ${w.journal}'} | https://doi.org/${w.doi}',
      );
      if (row.focus.isNotEmpty) buffer.writeln('   ${row.focus}');
      if (row.notes.isNotEmpty) buffer.writeln('   ${row.notes}');
    }
    return buffer.toString();
  }

  static String _focus(GroundedWork work) {
    final title = work.title.trim();
    if (title.isEmpty) return '';
    return appTr('التركيز الظاهر من العنوان: $title', 'Focus as stated in the title: $title');
  }

  static String _notes(GroundedWork work) {
    final abs = work.abstractText.trim();
    if (abs.length >= 40) {
      final cut = abs.length > 280 ? '${abs.substring(0, 280)}…' : abs;
      return appTr('من الملخص المؤكد: $cut', 'From the confirmed abstract: $cut');
    }
    return appTr(
      'الفرضية، حجم العينة، والنتائج الإحصائية تُراجع من النص الكامل عبر DOI — لم تُختلق هنا.',
      'Hypothesis, sample size, and statistics must be read from the full text via the DOI — none were invented here.',
    );
  }
}
