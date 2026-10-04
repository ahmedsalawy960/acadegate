import '../../core/locale/app_translate.dart';

class LawLabBranding {
  LawLabBranding._();

  static const brand = 0xFF0D47A1;

  static String get title =>
      appTr('مختبر القانون (الأسانيد)', 'Law Lab (Authorities)');

  static String get tagline => appTr(
        'بديل «المختبر» لباحث الحقوق: فرّع المسألة، سجّل التشريع والأحكام والفقه، '
        'ابنِ سلسلة استدلال، وقارن تشريعياً — دون أجهزة أو عينات.',
        'The “lab” alternative for law researchers: map the issue, log statutes, '
        'cases and doctrine, build an argument chain, and compare laws — no lab gear.',
      );

  static String get integrityNote => appTr(
        'الأداة تنظّم بحثك ولا تستبدل الرجوع للنص الرسمي أو مجموعة الأحكام. '
        'بعد الملء: صدّر PDF أو انقل الملخص لكاشف المنهجية / استوديو الرسالة. '
        'تحقّق دائماً من سريان النص قبل الاعتماد.',
        'This tool organises your research; it does not replace official texts. '
        'After filling: export PDF or send the summary to methodology check / Thesis Studio. '
        'Always verify currency before citing.',
      );
}
