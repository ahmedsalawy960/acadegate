import 'dart:math' as math;

/// نتيجة حساب معامل ألفا كرونباخ.
class CronbachResult {
  final int nRespondents;
  final int kItems;
  final double alpha;
  final String interpretationAr;
  final String interpretationEn;
  final String? errorAr;
  final String? errorEn;

  const CronbachResult({
    required this.nRespondents,
    required this.kItems,
    required this.alpha,
    required this.interpretationAr,
    required this.interpretationEn,
    this.errorAr,
    this.errorEn,
  });

  bool get ok => errorAr == null && !alpha.isNaN;
}

/// محرك ألفا كرونباخ — حساب محلي بدون إنترنت.
class CronbachEngine {
  CronbachEngine._();

  /// [matrix]: صفوف = مستجيبون، أعمدة = بنود. قيم عددية (مثلاً Likert 1–5).
  static CronbachResult compute(List<List<double>> matrix) {
    if (matrix.isEmpty) {
      return const CronbachResult(
        nRespondents: 0,
        kItems: 0,
        alpha: double.nan,
        interpretationAr: '',
        interpretationEn: '',
        errorAr: 'لا توجد بيانات.',
        errorEn: 'No data.',
      );
    }
    final n = matrix.length;
    final k = matrix.first.length;
    if (k < 2) {
      return CronbachResult(
        nRespondents: n,
        kItems: k,
        alpha: double.nan,
        interpretationAr: '',
        interpretationEn: '',
        errorAr: 'يلزم بندان على الأقل.',
        errorEn: 'At least two items are required.',
      );
    }
    for (final row in matrix) {
      if (row.length != k) {
        return CronbachResult(
          nRespondents: n,
          kItems: k,
          alpha: double.nan,
          interpretationAr: '',
          interpretationEn: '',
          errorAr: 'عدد البنود غير متساوٍ بين الصفوف.',
          errorEn: 'Unequal number of items across rows.',
        );
      }
    }
    if (n < 2) {
      return CronbachResult(
        nRespondents: n,
        kItems: k,
        alpha: double.nan,
        interpretationAr: '',
        interpretationEn: '',
        errorAr: 'يلزم مستجيبان على الأقل لحساب التباين.',
        errorEn: 'At least two respondents are required.',
      );
    }

    final itemVars = <double>[];
    for (var j = 0; j < k; j++) {
      final col = [for (final row in matrix) row[j]];
      itemVars.add(_variance(col));
    }
    final totals = [
      for (final row in matrix) row.fold<double>(0, (a, b) => a + b),
    ];
    final totalVar = _variance(totals);
    if (totalVar <= 0) {
      return CronbachResult(
        nRespondents: n,
        kItems: k,
        alpha: double.nan,
        interpretationAr: '',
        interpretationEn: '',
        errorAr: 'تباين الدرجة الكلية صفر — البيانات ثابتة.',
        errorEn: 'Total-score variance is zero — data are constant.',
      );
    }

    final sumItemVar = itemVars.fold<double>(0, (a, b) => a + b);
    final alpha = (k / (k - 1)) * (1 - (sumItemVar / totalVar));
    return CronbachResult(
      nRespondents: n,
      kItems: k,
      alpha: alpha,
      interpretationAr: _interpAr(alpha),
      interpretationEn: _interpEn(alpha),
    );
  }

  /// يحلّل نصاً: كل سطر مستجيب، والقيم مفصولة بفاصلة أو مسافة أو تبويب.
  static (List<List<double>> matrix, String? errorAr, String? errorEn)
      parseMatrixText(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isEmpty) {
      return (
        const [],
        'الصق درجات البنود: سطر لكل مستجيب.',
        'Paste item scores: one respondent per line.',
      );
    }
    final matrix = <List<double>>[];
    int? width;
    for (final line in lines) {
      final parts = line
          .split(RegExp(r'[,;\t ]+'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      final row = <double>[];
      for (final p in parts) {
        final v = double.tryParse(p.replaceAll(',', '.'));
        if (v == null) {
          return (
            const [],
            'قيمة غير رقمية: $p',
            'Non-numeric value: $p',
          );
        }
        row.add(v);
      }
      width ??= row.length;
      if (row.length != width) {
        return (
          const [],
          'عدد البنود يختلف بين الأسطر.',
          'Item count differs across lines.',
        );
      }
      matrix.add(row);
    }
    return (matrix, null, null);
  }

  static double _variance(List<double> xs) {
    if (xs.length < 2) return 0;
    final mean = xs.fold<double>(0, (a, b) => a + b) / xs.length;
    var sumSq = 0.0;
    for (final x in xs) {
      final d = x - mean;
      sumSq += d * d;
    }
    // عينة (n-1) كما في معظم برامج الإحصاء التربوية.
    return sumSq / (xs.length - 1);
  }

  static String _interpAr(double a) {
    if (a.isNaN || a.isInfinite) return 'غير قابل للتفسير';
    if (a < 0.5) return 'ضعيف جداً — راجع صياغة البنود أو الأبعاد.';
    if (a < 0.6) return 'ضعيف — يحتاج تحسين البنود.';
    if (a < 0.7) return 'مقبول بحذر في الدراسات الاستطلاعية.';
    if (a < 0.8) return 'مقبول / جيد لمعظم الدراسات التربوية.';
    if (a < 0.9) return 'جيد جداً.';
    if (a <= 1.0 + 1e-9) return 'ممتاز — راقب التكرار الزائد بين البنود.';
    return 'قيمة خارج النطاق المعتاد — راجع البيانات.';
  }

  static String _interpEn(double a) {
    if (a.isNaN || a.isInfinite) return 'Not interpretable';
    if (a < 0.5) return 'Very poor — revise items/dimensions.';
    if (a < 0.6) return 'Poor — items need improvement.';
    if (a < 0.7) return 'Questionable — ok only for early pilots.';
    if (a < 0.8) return 'Acceptable / good for many education studies.';
    if (a < 0.9) return 'Good.';
    if (a <= 1.0 + 1e-9) return 'Excellent — watch for redundant items.';
    return 'Unusual value — check the data.';
  }

  /// للتحقق السريع في الاختبارات.
  static double roundAlpha(double a, [int digits = 3]) {
    if (a.isNaN) return a;
    final m = math.pow(10, digits).toDouble();
    return (a * m).round() / m;
  }
}
