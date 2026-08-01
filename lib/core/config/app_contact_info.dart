/// بيانات التواصل الرسمية الظاهرة في تذييل التطبيق وصفحة الدعم.
/// حدّث الأرقام والبريد قبل الإطلاق العام.
class AppContactInfo {
  AppContactInfo._();

  static const String brandName = 'AcadeGate';
  static const String supportEmail = 'support@acadegate.com';
  static const String copyrightYear = '2026';

  /// خطوط الدعم (قابلة للاتصال عبر الهاتف / واتساب).
  static const List<AppPhoneLine> phoneLines = [
    AppPhoneLine(
      labelAr: 'الدعم الفني',
      labelEn: 'Technical support',
      e164: '+201000000001',
      displayAr: '0100 000 0001',
      displayEn: '+20 100 000 0001',
    ),
    AppPhoneLine(
      labelAr: 'خدمة العملاء',
      labelEn: 'Customer service',
      e164: '+201000000002',
      displayAr: '0100 000 0002',
      displayEn: '+20 100 000 0002',
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
