/// بيانات التواصل الرسمية الظاهرة في تذييل التطبيق وصفحة الدعم.
class AppContactInfo {
  AppContactInfo._();

  static const String brandName = 'AcadeGate';
  static const String supportEmail = 'acadegate@gmail.com';
  static const String copyrightYear = '2026';
  static const String privacyUrl = 'https://acadegate-new.web.app/privacy';
  static const String termsUrl = 'https://acadegate-new.web.app/terms';

  static const List<AppPhoneLine> phoneLines = <AppPhoneLine>[
    AppPhoneLine(
      labelAr: 'دعم',
      labelEn: 'Support',
      e164: '+201044339033',
      displayAr: '01044339033',
      displayEn: '01044339033',
    ),
  ];

  static String copyrightNotice(bool isAr) => isAr
      ? '© $copyrightYear $brandName. جميع الحقوق محفوظة.'
      : '© $copyrightYear $brandName. All rights reserved.';
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
