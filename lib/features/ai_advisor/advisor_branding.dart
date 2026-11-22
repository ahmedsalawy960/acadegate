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
    s = s.replaceAll(RegExp(r'https?://\S+'), '');
    s = s.replaceAll(RegExp(r'\bAPI\b'), '');

    // Collapse repeated brand: "AcadeGate / AcadeGate" → "AcadeGate"
    s = s.replaceAll(
      RegExp('(?:$name\\s*[·/,+|و&]+\\s*)+$name', caseSensitive: false),
      name,
    );
    s = s.replaceAll(RegExp('$name(?:\\s*/\\s*$name)+', caseSensitive: false), name);

    return s;
  }

  static const planMarker = '[[plan]]';

  static String get planLimitReached => appTr(
        '$planMarker انتهى حد باقتك الحالية. يمكنك تفعيل اشتراك، أو تعديل الباقة، أو طلب زيادة الحد.',
        '$planMarker Your current plan limit is used up. Activate a subscription, adjust the plan, or ask to raise the limit.',
      );

  static String get _generic => appTr(
        'تعذر إكمال الرد الآن. حاول مرة أخرى.',
        'Could not finish the reply. Please try again.',
      );

  /// Any failure shown to a researcher: no vendor, model, key, or link.
  static String friendlyFailure(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return _generic;
    final lower = s.toLowerCase();
    if (s.contains('الحد اليومي') ||
        s.contains('حد باقتك') ||
        s.contains('رصيد هذا الشهر') ||
        s.contains('حد اليوم') ||
        lower.contains('daily') ||
        RegExp(r'quota|رصيد|429|resource.?exhausted', caseSensitive: false)
            .hasMatch(s)) {
      return planLimitReached;
    }
    if (s.contains('سجّل الدخول') ||
        s.contains('تسجيل الدخول') ||
        lower.contains('sign in')) {
      return publicize(s);
    }
    if (RegExp(
      r'gemini|api\s*key|aistudio|googleapis|exception|cloud function|http',
      caseSensitive: false,
    ).hasMatch(s)) {
      return _generic;
    }
    return publicize(s);
  }
}
