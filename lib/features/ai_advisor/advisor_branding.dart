import '../../core/locale/app_translate.dart';

/// اسم المساعد الذكي كما يظهر للمستخدم — غيّره من هنا فقط.
class AdvisorBranding {
  AdvisorBranding._();

  static const name = 'AcadeGate';

  static String get cloudBadge =>
      appTr('المساعد الأكاديمي', 'Academic Assistant');
  static String get integrityTitle =>
      appTr('سلامة أكاديمية AcadeGate', 'AcadeGate Integrity');

  static String get assistantTitle =>
      appTr('المساعد الأكاديمي', 'Academic Assistant');
  static String get localBadge => appTr('أساسي', 'Basic');
  static String get poweredBy => appTr('', '');
}
