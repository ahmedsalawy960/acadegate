import '../../core/locale/app_translate.dart';

class ResearchToolsBranding {
  ResearchToolsBranding._();

  static const brand = 0xFF6A1B9A;

  static String get title =>
      appTr('استوديو الأدوات البحثية', 'Research Tools Studio');

  static String get tagline => appTr(
        'أدوات كمية (استبانة وثبات) وأدوات نوعية/نصية (مقابلة · مضمون · مدونة) '
        'حسب مسار كليتك الأدبية أو التربوية',
        'Quantitative tools (survey & reliability) and qualitative/textual tools '
        '(interview · content analysis · corpus) by your humanities track',
      );

  static String get integrityNote => appTr(
        'هذه أدوات بناء وجمع (استبانة/مقابلة/ترميز مسبق) — ليست مكان التحليل بعد التفريغ. '
        'بعد جمع البيانات استخدم مرحلة «التحليل النوعي» في البوابة.',
        'These are design/collection tools (survey/interview/pre-coding) — not post-transcript analysis. '
        'After data collection use the Qualitative Analysis stage in the portal.',
      );
}
