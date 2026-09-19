/// بيانات التواصل الرسمية الظاهرة في تذييل التطبيق وصفحة الدعم.
/// البيتا: البريد فقط — لا تضع أرقاماً وهمية قبل توفر خط دعم حقيقي.
class AppContactInfo {
  AppContactInfo._();

  static const String brandName = 'AcadeGate';
  static const String supportEmail = 'acadegate@gmail.com';
  static const String copyrightYear = '2026';
  static const String privacyUrl = 'https://acadegate-new.web.app/privacy';
  static const String termsUrl = 'https://acadegate-new.web.app/terms';

  /// خطوط الهاتف/واتساب — فارغة في البيتا حتى يتوفر رقم حقيقي.
  static const List<AppPhoneLine> phoneLines = <AppPhoneLine>[];

  static String copyrightNotice(bool isAr) => isAr
      ? '© $copyrightYear $brandName. جميع الحقوق محفوظة.'
      : '© $copyrightYear $brandName. All rights reserved.';

  static String betaSupportHint(bool isAr) => isAr
      ? 'للبيتا المغلقة: راسلنا على البريد أدناه — سنرد خلال يوم عمل.'
      : 'Closed beta: email us below — we reply within one business day.';
}

class AppPhoneLine {
  const AppPhoneLine({
    required this.labelAr,
    required this.labelEn,
    required this.e164,
    required this.displayAr,
    required this.displayEn,
  });

  final String labelAr;
  final String labelEn;
  final String e164;
  final String displayAr;
  final String displayEn;

  String label(bool isAr) => isAr ? labelAr : labelEn;
  String display(bool isAr) => isAr ? displayAr : displayEn;
}
