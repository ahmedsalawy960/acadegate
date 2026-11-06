import '../../core/locale/app_translate.dart';

/// اسم المساعد والعلامة كما يظهر للمستخدم — غيّره من هنا فقط.
/// لا نعرض أسماء نماذج أو فهارس خارجية (Gemini / Scholar / OpenAlex …) في الواجهة.
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

  /// اسم محرك التوليد كما يظهر للمستخدم (بدل اسم النموذج).
  static String get engineLabel => name;

  /// فهرس المراجع كما يظهر للمستخدم.
  static String get indexLabel => name;

  /// لا تُعرض معرّفات النماذج الخام في الواجهة.
  static String? publicModelLabel(String? modelUsed) {
    if (modelUsed == null || modelUsed.trim().isEmpty) return null;
    return engineLabel;
  }

  /// يستبدل أسماء الأدوات والنماذج في أي نص يظهر للمستخدم.
  static String publicize(String? raw) {
    if (raw == null) return '';
    var s = raw;
    if (s.trim().isEmpty) return s;

    s = s.replaceAllMapped(
      RegExp(r'gemini-[\w.\-]+', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(
        r'\bGemini(?:\s*[\d.]+)?(?:\s*Pro)?(?:\s*Flash)?(?:\s*Lite)?\b',
        caseSensitive: false,
      ),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bGoogle\s*Scholar\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bSemantic\s*Scholar\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bOpenAlex\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bCrossref\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bEurope\s*PMC\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bConsensus\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bSerpAPI\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bChatGPT\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bGPT-?\d(?:\.\d)?\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'\bGoogle\s*AI\s*Studio\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'مفتاح\s*Gemini', caseSensitive: false),
      (_) => appTr('تسجيل الدخول إلى AcadeGate', 'AcadeGate sign-in'),
    );
    s = s.replaceAllMapped(
      RegExp(r'Gemini\s*key', caseSensitive: false),
      (_) => 'AcadeGate sign-in',
    );
    s = s.replaceAllMapped(
      RegExp(r'\bCloud Function\b', caseSensitive: false),
      (_) => name,
    );
    s = s.replaceAllMapped(
      RegExp(r'geminiAdvisor', caseSensitive: false),
      (_) => name,
    );

    // Collapse repeated brand: "AcadeGate / AcadeGate" → "AcadeGate"
    s = s.replaceAll(
      RegExp('(?:$name\\s*[·/,+|و&]+\\s*)+$name', caseSensitive: false),
      name,
    );
    s = s.replaceAll(RegExp('$name(?:\\s*/\\s*$name)+', caseSensitive: false), name);

    return s;
  }
}
