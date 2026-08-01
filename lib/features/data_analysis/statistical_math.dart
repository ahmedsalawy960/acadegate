import 'dart:math' as math;

class StatTestResult {
  final double statistic;
  final double pValue;
  final String testName;

  const StatTestResult({
    required this.statistic,
    required this.pValue,
    required this.testName,
  });

  bool significantAt(double alpha) => pValue < alpha;
}

class DescriptiveStats {
  final int n;
  final double mean;
  final double std;
  final double skewness;
  final double kurtosis;

  const DescriptiveStats({
    required this.n,
    required this.mean,
    required this.std,
    required this.skewness,
    required this.kurtosis,
  });
}

class StatisticalMath {
  StatisticalMath._();

  static DescriptiveStats describe(List<double> values) {
    final n = values.length;
    if (n == 0) {
      return const DescriptiveStats(
        n: 0,
        mean: 0,
        std: 0,
        skewness: 0,
        kurtosis: 0,
      );
    }

    final mean = _mean(values);
    final std = _sampleStd(values, mean);
    return DescriptiveStats(
      n: n,
      mean: mean,
      std: std,
      skewness: _skewness(values, mean, std),
      kurtosis: _excessKurtosis(values, mean, std),
    );
  }

  static StatTestResult? normalityTest(List<double> values) {
    final n = values.length;
    if (n < 3) return null;
    if (n <= 5000) {
      return shapiroWilk(values);
    }
    return jarqueBera(values);
  }

  /// Shapiro-Wilk W test with Royston (1992) p-value approximation.
  static StatTestResult shapiroWilk(List<double> values) {
    final n = values.length;
    final sorted = List<double>.from(values)..sort();
    final mean = _mean(sorted);
    final ss = sorted.fold<double>(
      0,
      (sum, x) => sum + (x - mean) * (x - mean),
    );
    if (ss == 0) {
      return const StatTestResult(
        statistic: 1,
        pValue: 0,
        testName: 'Shapiro-Wilk',
      );
    }

    final weights = _shapiroWeights(n);
    var num = 0.0;
    for (var i = 0; i < n; i++) {
      num += weights[i] * sorted[i];
    }
    final w = (num * num) / ss;
    final p = _shapiroPValue(w, n);

    return StatTestResult(
      statistic: w.clamp(0.0, 1.0),
      pValue: p.clamp(0.0, 1.0),
      testName: 'Shapiro-Wilk',
    );
  }

  static StatTestResult jarqueBera(List<double> values) {
    final stats = describe(values);
    final n = stats.n.toDouble();
    final jb = n / 6 * (stats.skewness * stats.skewness +
        (stats.kurtosis * stats.kurtosis) / 4);
    final p = math.exp(-jb / 2);

    return StatTestResult(
      statistic: jb,
      pValue: p.clamp(0.0, 1.0),
      testName: 'Jarque-Bera',
    );
  }

  /// Brown-Forsythe Levene (median-based).
  static StatTestResult? leveneTest(Map<String, List<double>> groups) {
    final keys = groups.keys.where((k) => groups[k]!.length >= 2).toList();
    if (keys.length < 2) return null;

    final transformed = <String, List<double>>{};
    for (final key in keys) {
      final data = groups[key]!;
      final med = _median(data);
      transformed[key] = data.map((x) => (x - med).abs()).toList();
    }

    return oneWayAnova(transformed);
  }

  static StatTestResult? independentTTest(
    List<double> a,
    List<double> b, {
    bool equalVariance = false,
  }) {
    if (a.length < 2 || b.length < 2) return null;

    final meanA = _mean(a);
    final meanB = _mean(b);
    final varA = _variance(a, meanA);
    final varB = _variance(b, meanB);
    final nA = a.length;
    final nB = b.length;

    double t;
    double df;

    if (equalVariance) {
      final pooled =
          ((nA - 1) * varA + (nB - 1) * varB) / (nA + nB - 2);
      final se = math.sqrt(pooled * (1 / nA + 1 / nB));
      t = se == 0 ? 0 : (meanA - meanB) / se;
      df = (nA + nB - 2).toDouble();
    } else {
      final seA = varA / nA;
      final seB = varB / nB;
      final se = math.sqrt(seA + seB);
      t = se == 0 ? 0 : (meanA - meanB) / se;
      final num = math.pow(seA + seB, 2);
      final den = (math.pow(seA, 2) / (nA - 1)) + (math.pow(seB, 2) / (nB - 1));
      df = den == 0 ? 1 : num / den;
    }

    final p = 2 * (1 - _studentTCdf(t.abs(), df));
    return StatTestResult(
      statistic: t,
      pValue: p.clamp(0.0, 1.0),
      testName: equalVariance ? 'Student t-test' : 'Welch t-test',
    );
  }

  static StatTestResult? pairedTTest(List<double> a, List<double> b) {
    if (a.length != b.length || a.length < 2) return null;
    final diffs = List<double>.generate(a.length, (i) => a[i] - b[i]);
    final mean = _mean(diffs);
    final std = _sampleStd(diffs, mean);
    if (std == 0) {
      return StatTestResult(
        statistic: 0,
        pValue: mean == 0 ? 1 : 0,
        testName: 'Paired t-test',
      );
    }
    final t = mean / (std / math.sqrt(diffs.length));
    final df = (diffs.length - 1).toDouble();
    final p = 2 * (1 - _studentTCdf(t.abs(), df));
    return StatTestResult(
      statistic: t,
      pValue: p.clamp(0.0, 1.0),
      testName: 'Paired t-test',
    );
  }

  static StatTestResult? oneWayAnova(Map<String, List<double>> groups) {
    final valid = groups.entries.where((e) => e.value.isNotEmpty).toList();
    if (valid.length < 2) return null;

    final all = valid.expand((e) => e.value).toList();
    final grandMean = _mean(all);
    final k = valid.length;
    final n = all.length;

    var ssBetween = 0.0;
    var ssWithin = 0.0;
    for (final entry in valid) {
      final groupMean = _mean(entry.value);
      ssBetween += entry.value.length *
          (groupMean - grandMean) *
          (groupMean - grandMean);
      for (final x in entry.value) {
        ssWithin += (x - groupMean) * (x - groupMean);
      }
    }

    final dfBetween = k - 1;
    final dfWithin = n - k;
    if (dfWithin <= 0 || dfBetween <= 0) return null;

    final msBetween = ssBetween / dfBetween;
    final msWithin = ssWithin / dfWithin;
    if (msWithin == 0) {
      return StatTestResult(statistic: 0, pValue: 1, testName: 'One-way ANOVA');
    }

    final f = msBetween / msWithin;
    final p = 1 - _fCdf(f, dfBetween, dfWithin);
    return StatTestResult(
      statistic: f,
      pValue: p.clamp(0.0, 1.0),
      testName: 'One-way ANOVA',
    );
  }

  static StatTestResult? pearsonCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 3) return null;
    final mx = _mean(x);
    final my = _mean(y);
    var num = 0.0;
    var denX = 0.0;
    var denY = 0.0;
    for (var i = 0; i < x.length; i++) {
      final dx = x[i] - mx;
      final dy = y[i] - my;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }
    if (denX == 0 || denY == 0) return null;
    final r = num / math.sqrt(denX * denY);
    final t = r * math.sqrt((x.length - 2) / (1 - r * r));
    final df = (x.length - 2).toDouble();
    final p = 2 * (1 - _studentTCdf(t.abs(), df));
    return StatTestResult(
      statistic: r,
      pValue: p.clamp(0.0, 1.0),
      testName: 'Pearson correlation',
    );
  }

  /// Spearman rank correlation (Pearson on mid-ranks).
  static StatTestResult? spearmanCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 3) return null;
    final rx = _averageRanks(x);
    final ry = _averageRanks(y);
    final pearson = pearsonCorrelation(rx, ry);
    if (pearson == null) return null;
    return StatTestResult(
      statistic: pearson.statistic,
      pValue: pearson.pValue,
      testName: 'Spearman correlation',
    );
  }

  /// Mann–Whitney U (two-sided normal approximation with tie correction).
  static StatTestResult? mannWhitneyU(List<double> a, List<double> b) {
    if (a.length < 2 || b.length < 2) return null;
    final n1 = a.length;
    final n2 = b.length;
    final combined = <({double v, int g})>[
      ...a.map((v) => (v: v, g: 0)),
      ...b.map((v) => (v: v, g: 1)),
    ]..sort((x, y) => x.v.compareTo(y.v));

    final ranks = List<double>.filled(combined.length, 0);
    var i = 0;
    while (i < combined.length) {
      var j = i;
      while (j + 1 < combined.length && combined[j + 1].v == combined[i].v) {
        j++;
      }
      final avg = (i + j + 2) / 2.0; // 1-based mid-rank
      for (var k = i; k <= j; k++) {
        ranks[k] = avg;
      }
      i = j + 1;
    }

    var r1 = 0.0;
    for (var k = 0; k < combined.length; k++) {
      if (combined[k].g == 0) r1 += ranks[k];
    }
    final u1 = r1 - n1 * (n1 + 1) / 2;
    final u2 = n1 * n2 - u1;
    final u = math.min(u1, u2);
    final mu = n1 * n2 / 2.0;

    // Tie correction for variance
    final n = n1 + n2;
    var tieTerm = 0.0;
    i = 0;
    while (i < combined.length) {
      var j = i;
      while (j + 1 < combined.length && combined[j + 1].v == combined[i].v) {
        j++;
      }
      final t = j - i + 1;
      if (t > 1) {
        tieTerm += t * t * t - t;
      }
      i = j + 1;
    }
    final sigma2 = (n1 * n2 / 12.0) *
        ((n + 1) - tieTerm / (n * (n - 1)));
    if (sigma2 <= 0) {
      return StatTestResult(
        statistic: u,
        pValue: 1,
        testName: 'Mann-Whitney U',
      );
    }
    final z = (u - mu + 0.5) / math.sqrt(sigma2); // continuity correction
    final p = 2 * (1 - _normalCdf(z.abs()));
    return StatTestResult(
      statistic: u,
      pValue: p.clamp(0.0, 1.0),
      testName: 'Mann-Whitney U',
    );
  }

  /// Kruskal–Wallis H (chi-square approximation).
  static StatTestResult? kruskalWallis(Map<String, List<double>> groups) {
    final valid = groups.entries.where((e) => e.value.isNotEmpty).toList();
    if (valid.length < 2) return null;

    final tagged = <({double v, String g})>[];
    for (final e in valid) {
      for (final x in e.value) {
        tagged.add((v: x, g: e.key));
      }
    }
    tagged.sort((a, b) => a.v.compareTo(b.v));

    final ranks = List<double>.filled(tagged.length, 0);
    var i = 0;
    while (i < tagged.length) {
      var j = i;
      while (j + 1 < tagged.length && tagged[j + 1].v == tagged[i].v) {
        j++;
      }
      final avg = (i + j + 2) / 2.0;
      for (var k = i; k <= j; k++) {
        ranks[k] = avg;
      }
      i = j + 1;
    }

    final n = tagged.length;
    final rankSum = <String, double>{};
    final counts = <String, int>{};
    for (var k = 0; k < tagged.length; k++) {
      final g = tagged[k].g;
      rankSum[g] = (rankSum[g] ?? 0) + ranks[k];
      counts[g] = (counts[g] ?? 0) + 1;
    }

    var h = 0.0;
    for (final g in counts.keys) {
      final r = rankSum[g]!;
      final ni = counts[g]!;
      h += (r * r) / ni;
    }
    h = (12 / (n * (n + 1))) * h - 3 * (n + 1);

    // Tie correction
    var tieTerm = 0.0;
    i = 0;
    while (i < tagged.length) {
      var j = i;
      while (j + 1 < tagged.length && tagged[j + 1].v == tagged[i].v) {
        j++;
      }
      final t = j - i + 1;
      if (t > 1) {
        tieTerm += t * t * t - t;
      }
      i = j + 1;
    }
    if (tieTerm > 0) {
      final denom = 1 - tieTerm / (n * n * n - n);
      if (denom > 0) h /= denom;
    }

    final df = valid.length - 1;
    final p = 1 - _chi2Cdf(h, df);
    return StatTestResult(
      statistic: h,
      pValue: p.clamp(0.0, 1.0),
      testName: 'Kruskal-Wallis',
    );
  }

  /// Count outliers via Tukey IQR fences (1.5×IQR).
  static int outlierCountIqr(List<double> values) {
    if (values.length < 4) return 0;
    final sorted = List<double>.from(values)..sort();
    final q1 = _percentile(sorted, 0.25);
    final q3 = _percentile(sorted, 0.75);
    final iqr = q3 - q1;
    if (iqr == 0) return 0;
    final lo = q1 - 1.5 * iqr;
    final hi = q3 + 1.5 * iqr;
    return values.where((x) => x < lo || x > hi).length;
  }

  static List<double> _averageRanks(List<double> values) {
    final indexed = List.generate(values.length, (i) => (i: i, v: values[i]));
    indexed.sort((a, b) => a.v.compareTo(b.v));
    final ranks = List<double>.filled(values.length, 0);
    var i = 0;
    while (i < indexed.length) {
      var j = i;
      while (j + 1 < indexed.length && indexed[j + 1].v == indexed[i].v) {
        j++;
      }
      final avg = (i + j + 2) / 2.0;
      for (var k = i; k <= j; k++) {
        ranks[indexed[k].i] = avg;
      }
      i = j + 1;
    }
    return ranks;
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final pos = (sorted.length - 1) * p;
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    final w = pos - lo;
    return sorted[lo] * (1 - w) + sorted[hi] * w;
  }

  static ({double r2, StatTestResult? fTest})? simpleLinearRegression(
    List<double> x,
    List<double> y,
  ) {
    if (x.length != y.length || x.length < 3) return null;
    final corr = pearsonCorrelation(x, y);
    if (corr == null) return null;
    final r = corr.statistic;
    final r2 = r * r;
    final n = x.length;
    final f = (r2 / (1 - r2)) * (n - 2);
    final p = 1 - _fCdf(f, 1, n - 2);
    return (
      r2: r2,
      fTest: StatTestResult(
        statistic: f,
        pValue: p.clamp(0.0, 1.0),
        testName: 'Linear regression F',
      ),
    );
  }

  static StatTestResult? chiSquareTest(List<List<double>> table) {
    final rows = table.length;
    final cols = table.first.length;
    if (rows < 2 || cols < 2) return null;

    final rowSums = List<double>.generate(
      rows,
      (r) => table[r].fold(0.0, (a, b) => a + b),
    );
    final colSums = List<double>.generate(cols, (c) {
      var sum = 0.0;
      for (var r = 0; r < rows; r++) {
        sum += table[r][c];
      }
      return sum;
    });
    final total = rowSums.fold(0.0, (a, b) => a + b);
    if (total == 0) return null;

    var chi2 = 0.0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final expected = rowSums[r] * colSums[c] / total;
        if (expected == 0) continue;
        final diff = table[r][c] - expected;
        chi2 += diff * diff / expected;
      }
    }

    final df = (rows - 1) * (cols - 1);
    final p = 1 - _chi2Cdf(chi2, df);
    return StatTestResult(
      statistic: chi2,
      pValue: p.clamp(0.0, 1.0),
      testName: 'Chi-square',
    );
  }

  static double cohensD(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final meanA = _mean(a);
    final meanB = _mean(b);
    final varA = _variance(a, meanA);
    final varB = _variance(b, meanB);
    final nA = a.length;
    final nB = b.length;
    final pooled = ((nA - 1) * varA + (nB - 1) * varB) / (nA + nB - 2);
    if (pooled == 0) return 0;
    return (meanA - meanB).abs() / math.sqrt(pooled);
  }

  static double etaSquared(Map<String, List<double>> groups) {
    final all = groups.values.expand((e) => e).toList();
    if (all.isEmpty) return 0;
    final grand = _mean(all);
    var ssTotal = 0.0;
    var ssBetween = 0.0;
    for (final x in all) {
      ssTotal += (x - grand) * (x - grand);
    }
    for (final entry in groups.entries) {
      final gm = _mean(entry.value);
      ssBetween += entry.value.length * (gm - grand) * (gm - grand);
    }
    if (ssTotal == 0) return 0;
    return ssBetween / ssTotal;
  }

  static double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static double _variance(List<double> values, double mean) {
    if (values.length < 2) return 0;
    var sum = 0.0;
    for (final x in values) {
      final d = x - mean;
      sum += d * d;
    }
    return sum / (values.length - 1);
  }

  static double _sampleStd(List<double> values, double mean) {
    return math.sqrt(_variance(values, mean));
  }

  static double _skewness(List<double> values, double mean, double std) {
    if (values.length < 3 || std == 0) return 0;
    final n = values.length;
    var m3 = 0.0;
    for (final x in values) {
      m3 += math.pow((x - mean) / std, 3).toDouble();
    }
    return (n / ((n - 1) * (n - 2))) * m3;
  }

  static double _excessKurtosis(List<double> values, double mean, double std) {
    if (values.length < 4 || std == 0) return 0;
    final n = values.length;
    var m4 = 0.0;
    for (final x in values) {
      m4 += math.pow((x - mean) / std, 4).toDouble();
    }
    final term = (n * (n + 1)) / ((n - 1) * (n - 2) * (n - 3));
    final correction = (3 * (n - 1) * (n - 1)) / ((n - 2) * (n - 3));
    return term * m4 - correction;
  }

  static List<double> _shapiroWeights(int n) {
    final m = List<double>.generate(n, (i) {
      final p = (i + 1 - 0.375) / (n + 0.25);
      return _inverseNormalCdf(p);
    });
    final sumSq = m.fold<double>(0, (s, x) => s + x * x);
    final norm = math.sqrt(sumSq);
    return m.map((x) => x / norm).toList();
  }

  static double _shapiroPValue(double w, int n) {
    if (w >= 0.99) return 1;
    if (w <= 0.5) return 0.001;

    final ln1mW = math.log(1 - w);
    double mu;
    double sigma;
    if (n <= 11) {
      mu = -1.2725 + 1.0521 * math.log(n);
      sigma = 1.0308 - 0.26758 * math.log(n);
    } else if (n <= 50) {
      mu = -0.0030302 + 0.2626 * math.log(n);
      sigma = 0.91805 - 0.05175 * math.log(n);
    } else {
      mu = math.log(n) * 0.0038915 * math.log(n) -
          0.083751 * math.log(n) -
          0.0030302;
      sigma = math.exp(0.459 - 0.188 / math.log(n));
    }

    final z = (ln1mW - mu) / sigma;
    return 1 - _normalCdf(z);
  }

  static double _inverseNormalCdf(double p) {
    if (p <= 0) return -8;
    if (p >= 1) return 8;
    return _rationalApproxInverseNormal(p);
  }

  static double _rationalApproxInverseNormal(double p) {
    const a = [
      -3.969683028665376e1,
      2.209460984245205e2,
      -2.759285084469138e2,
      1.383577518672690e2,
      -3.066479961614258e1,
      2.506628277459239e0,
    ];
    const b = [
      -5.447609879822406e1,
      1.615858368580409e2,
      -1.556989775050459e2,
      6.680131188771972e1,
      -1.328068155288171e1,
    ];
    const c = [
      -7.784894002430293e-3,
      -3.223964580411365e-1,
      -2.400758277161838e0,
      -2.549732539343734e0,
      4.374664141464968e0,
      2.938163982698277e0,
    ];
    const d = [
      7.784695709041462e-3,
      3.224671290700398e-1,
      2.445134137142996e0,
      3.754408661907416e0,
    ];

    const pLow = 0.02425;
    const pHigh = 1 - pLow;

    double q;
    double r;

    if (p < pLow) {
      q = math.sqrt(-2 * math.log(p));
      return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
    if (p <= pHigh) {
      q = p - 0.5;
      r = q * q;
      return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r +
              a[5]) *
          q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    }
    q = math.sqrt(-2 * math.log(1 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
            c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }

  static double _normalCdf(double z) {
    return 0.5 * (1 + _erf(z / math.sqrt(2)));
  }

  static double _erf(double x) {
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p = 0.3275911;

    final sign = x < 0 ? -1.0 : 1.0;
    final ax = x.abs();
    final t = 1 / (1 + p * ax);
    final y = 1 -
        (((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t) *
            math.exp(-ax * ax);
    return sign * y;
  }

  static double _studentTCdf(double t, double df) {
    final x = df / (df + t * t);
    final a = df / 2;
    final b = 0.5;
    final ib = _regularizedIncompleteBeta(x, a, b);
    return t >= 0 ? 1 - ib / 2 : ib / 2;
  }

  static double _fCdf(double f, int d1, int d2) {
    if (f <= 0) return 0;
    final x = d2 / (d2 + d1 * f);
    return _regularizedIncompleteBeta(x, d2 / 2, d1 / 2);
  }

  static double _chi2Cdf(double x, int df) {
    if (x <= 0) return 0;
    return _regularizedIncompleteGamma(df / 2, x / 2);
  }

  static double _regularizedIncompleteBeta(
    double x,
    double a,
    double b,
  ) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    const maxIter = 200;
    const eps = 1e-10;

    final lnBeta =
        _lnGamma(a) + _lnGamma(b) - _lnGamma(a + b);
    final front = math.exp(a * math.log(x) + b * math.log(1 - x) - lnBeta) / a;

    var f = 1.0;
    var c = 1.0;
    var d = 0.0;

    for (var i = 0; i <= maxIter; i++) {
      final m = i ~/ 2;
      double numerator;
      if (i == 0) {
        numerator = 1;
      } else if (i.isOdd) {
        numerator = -(a + m) * (a + b + m) * x / ((a + 2 * m) * (a + 2 * m + 1));
      } else {
        numerator = m * (b - m) * x / ((a + 2 * m - 1) * (a + 2 * m));
      }

      d = 1 + numerator * d;
      if (d.abs() < eps) d = eps;
      d = 1 / d;

      c = 1 + numerator / c;
      if (c.abs() < eps) c = eps;

      final delta = c * d;
      f *= delta;
      if ((delta - 1).abs() < eps) break;
    }

    return front * (f - 1);
  }

  static double _regularizedIncompleteGamma(double a, double x) {
    if (x <= 0) return 0;
    if (x < a + 1) {
      return _gammaSeries(a, x);
    }
    return 1 - _gammaContinuedFraction(a, x);
  }

  static double _gammaSeries(double a, double x) {
    const maxIter = 200;
    const eps = 1e-10;
    var sum = 1 / a;
    var term = sum;
    for (var n = 1; n < maxIter; n++) {
      term *= x / (a + n);
      sum += term;
      if (term.abs() < eps * sum.abs()) break;
    }
    return sum * math.exp(-x + a * math.log(x) - _lnGamma(a));
  }

  static double _gammaContinuedFraction(double a, double x) {
    const maxIter = 200;
    const eps = 1e-10;
    var b = x + 1 - a;
    var c = 1 / 1e-30;
    var d = 1 / b;
    var h = d;
    for (var i = 1; i <= maxIter; i++) {
      final an = -i * (i - a);
      b += 2;
      d = an * d + b;
      if (d.abs() < eps) d = eps;
      c = b + an / c;
      if (c.abs() < eps) c = eps;
      d = 1 / d;
      final delta = d * c;
      h *= delta;
      if ((delta - 1).abs() < eps) break;
    }
    return math.exp(-x + a * math.log(x) - _lnGamma(a)) * h;
  }

  static double _lnGamma(double z) {
    const g = 7;
    const coef = [
      0.99999999999980993,
      676.5203681218851,
      -1259.1392167224028,
      771.32342877765313,
      -176.61502916214059,
      12.507343278686905,
      -0.13857109526572012,
      9.984369578019571e-6,
      1.5056327351493116e-7,
    ];
    if (z < 0.5) {
      return math.log(math.pi / math.sin(math.pi * z)) - _lnGamma(1 - z);
    }
    z -= 1;
    var x = coef[0];
    for (var i = 1; i < g + 2; i++) {
      x += coef[i] / (z + i);
    }
    final t = z + g + 0.5;
    return 0.5 * math.log(2 * math.pi) + (z + 0.5) * math.log(t) - t + math.log(x);
  }
}
