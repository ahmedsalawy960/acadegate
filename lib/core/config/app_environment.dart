/// بيئة التشغيل — استخدم `--dart-define=BETA=true` للنشر التجريبي الخاص.
class AppEnvironment {
  AppEnvironment._();

  static const isBeta = bool.fromEnvironment('BETA', defaultValue: false);

  static const betaLabelAr = 'نسخة تجريبية خاصة — غير منشورة للجمهور';
  static const betaLabelEn = 'Private beta — not public';
}
