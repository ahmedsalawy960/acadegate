import '../../core/locale/app_translate.dart';

/// Thesis Studio — one-tap grounded thesis draft.
class ThesisStudioBranding {
  ThesisStudioBranding._();

  static const brand = 0xFF1A237E;

  static String get title => appTr('استوديو الرسالة', 'Thesis Studio');

  static String get shortTitle => appTr('استوديو الرسالة', 'Thesis Studio');

  static String get tagline => appTr(
        'اكتب هدفك، ابنِ الهيكل الفارغ، ثم ولّد كل فقرة بأمرها ومراجعها',
        'Write your goal, build the empty outline, then generate each paragraph with its own command and sources',
      );

  static String get description => appTr(
        'التخطيط حسب نوع الرسالة يبقى أسفل الهدف. كل فقرة تُولَّد وحدها من أمر تكتبه تحتها، مع أداة تجلب دراسات ورسائل ذات DOI من الفهارس العالمية. تصدير PDF وWord وLaTeX/BibTeX. المسودة للمراجعة وليست نسخة تسليم، ولا نلتف على كاشفات الانتحال.',
        'Thesis-type controls stay under your goal. Each paragraph is generated from the command you type beneath it, with a tool that fetches DOI-confirmed papers and theses from global indexes. Export PDF, Word, and LaTeX/BibTeX. A draft to verify — not a submission copy, and not plagiarism-detector evasion.',
      );

  static String get buildButton => appTr(
        'ابنِ هيكل الفقرات الفارغة',
        'Build the empty paragraph outline',
      );

  static String get integrityBanner => appTr(
        'لا نكتب الرسالة دفعة واحدة. كل فقرة تُولَّد من أمرها ومن مراجع ذلك الأمر فقط. النتائج المعملية تبقى جداول فارغة. لا نختلق مصادر ولا نلتف على كاشفات الانتحال.',
        'We do not write the thesis in one shot. Each paragraph is generated from its own command and that command’s sources. Lab results stay empty tables. We do not invent sources or evade plagiarism detectors.',
      );
}
