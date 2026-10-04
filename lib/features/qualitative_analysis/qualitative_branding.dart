import '../../core/locale/app_translate.dart';

class QualitativeBranding {
  QualitativeBranding._();

  static const brand = 0xFF00695C;

  static String get title =>
      appTr('استوديو التحليل النوعي', 'Qualitative Analysis Studio');

  static String get tagline => appTr(
        'من نص المقابلة إلى الرموز فالموضوعات: مسار عملي للتحليل الموضوعي '
        '(Braun & Clarke) مع مذكرات وتحليلية وملخص للمنهجية.',
        'From transcript to codes to themes: a practical reflexive thematic '
        'analysis path (Braun & Clarke) with memos and a methods summary.',
      );

  static String get integrityNote => appTr(
        'الأداة تنظّم عملك ولا تستبدل فهمك للبيانات. لا تعتمد على اقتباسات '
        'مختلقة — انسخ من نصوصك فقط. التحليل النهائي يراجعه المشرف.',
        'This tool organises your work; it does not replace your reading of the data. '
        'Do not invent quotes — paste from your transcripts only. Final analysis '
        'should be reviewed with your supervisor.',
      );
}
