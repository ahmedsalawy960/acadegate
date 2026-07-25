import 'dart:math' as math;

import '../../core/locale/app_translate.dart';
import 'statistical_assumptions_models.dart';
import 'statistical_dataset.dart';
import 'statistical_math.dart';

class StatisticalDataAnalyzer {
  StatisticalDataAnalyzer._();

  static final StatisticalDataAnalyzer instance = StatisticalDataAnalyzer._();

  RealDataAnalysis analyze({
    required StatisticalDataset dataset,
    required ColumnMapping mapping,
    required StatisticalTestType testType,
    double alpha = 0.05,
  }) {
    final warnings = <String>[];
    final findings = <RealDataFinding>[];
    final summaries = <NumericColumnSummary>[];

    try {
      return switch (testType) {
        StatisticalTestType.independentTTest => _independentT(
            dataset,
            mapping,
            alpha,
            warnings,
            findings,
            summaries,
          ),
        StatisticalTestType.pairedTTest => _pairedT(
            dataset,
            mapping,
            alpha,
            warnings,
            findings,
            summaries,
          ),
        StatisticalTestType.oneWayAnova => _anova(
            dataset,
            mapping,
            alpha,
            warnings,
            findings,
            summaries,
          ),
        StatisticalTestType.pearsonCorrelation => _correlation(
            dataset,
            mapping,
            alpha,
            warnings,
            findings,
            summaries,
          ),
        StatisticalTestType.linearRegression => _regression(
            dataset,
            mapping,
            alpha,
            warnings,
            findings,
            summaries,
          ),
        StatisticalTestType.chiSquare => _chiSquare(
            dataset,
            mapping,
            alpha,
            warnings,
            findings,
            summaries,
          ),
      };
    } catch (e) {
      warnings.add('$e');
      return RealDataAnalysis(
        fromRealData: true,
        fileName: dataset.fileName,
        warnings: warnings,
      );
    }
  }

  RealDataAnalysis _independentT(
    StatisticalDataset dataset,
    ColumnMapping mapping,
    double alpha,
    List<String> warnings,
    List<RealDataFinding> findings,
    List<NumericColumnSummary> summaries,
  ) {
    final dep = mapping.dependentColumn;
    final grp = mapping.groupColumn;
    if (dep == null || grp == null) {
      throw Exception(
        appTr(
          'اختر عمود النتيجة وعمود المجموعة',
          'Select outcome and group columns',
        ),
      );
    }

    final groups = _numericByGroup(dataset, dep, grp);
    if (groups.length < 2) {
      throw Exception(
        appTr('يلزم مجموعتين على الأقل', 'At least two groups required'),
      );
    }

    final allValues = groups.values.expand((e) => e).toList();
    final norm = _normality(allValues, summaries, dep);
    final levene = StatisticalMath.leveneTest(groups);
    final homogeneityOk =
        levene == null || !levene.significantAt(alpha);

    if (levene != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'Levene (تجانس التباين)',
          labelEn: 'Levene (equal variances)',
          value: 'p = ${levene.pValue.toStringAsFixed(4)}',
          passed: homogeneityOk,
        ),
      );
    }

    final keys = groups.keys.toList()..sort();
    final tEqual = StatisticalMath.independentTTest(
      groups[keys[0]]!,
      groups[keys[1]]!,
      equalVariance: true,
    );
    final tWelch = StatisticalMath.independentTTest(
      groups[keys[0]]!,
      groups[keys[1]]!,
      equalVariance: false,
    );
    final main = homogeneityOk ? tEqual : tWelch;
    final effect = StatisticalMath.cohensD(groups[keys[0]]!, groups[keys[1]]!);

    if (main != null) {
      findings.add(
        RealDataFinding(
          labelAr: main.testName,
          labelEn: main.testName,
          value:
              't = ${main.statistic.toStringAsFixed(3)}, p = ${main.pValue.toStringAsFixed(4)}',
          passed: true,
        ),
      );
      findings.add(
        RealDataFinding(
          labelAr: "Cohen's d",
          labelEn: "Cohen's d",
          value: effect.toStringAsFixed(3),
          passed: true,
        ),
      );
    }

    for (final entry in groups.entries) {
      _summarizeColumn(summaries, '$dep (${entry.key})', entry.value);
    }

    return RealDataAnalysis(
      fromRealData: true,
      fileName: dataset.fileName,
      sampleSize: allValues.length,
      groupCount: groups.length,
      shapiroP: norm?.pValue,
      leveneP: levene?.pValue,
      observedEffectSize: effect,
      mainTestP: main?.pValue,
      mainTestName: main?.testName,
      homogeneityOk: homogeneityOk,
      normality: _normalityStatus(norm?.pValue, alpha),
      skewness: summaries.isNotEmpty ? summaries.first.skewness : null,
      kurtosis: summaries.isNotEmpty ? summaries.first.kurtosis : null,
      columnSummaries: summaries,
      findings: findings,
      warnings: warnings,
    );
  }

  RealDataAnalysis _pairedT(
    StatisticalDataset dataset,
    ColumnMapping mapping,
    double alpha,
    List<String> warnings,
    List<RealDataFinding> findings,
    List<NumericColumnSummary> summaries,
  ) {
    final aCol = mapping.dependentColumn;
    final bCol = mapping.secondNumericColumn;
    if (aCol == null || bCol == null) {
      throw Exception(
        appTr(
          'اختر العمودين المترابطين',
          'Select both paired columns',
        ),
      );
    }

    final pairs = _pairedNumeric(dataset, aCol, bCol);
    if (pairs.length < 3) {
      throw Exception(
        appTr(
          'يلزم 3 أزواج على الأقل',
          'At least 3 pairs required',
        ),
      );
    }

    final a = pairs.map((p) => p.$1).toList();
    final b = pairs.map((p) => p.$2).toList();
    final diffs = List<double>.generate(pairs.length, (i) => a[i] - b[i]);
    final diffMean = _mean(diffs);
    final diffStd = _sampleStd(diffs, diffMean);
    final effect = diffStd == 0 ? 0.0 : diffMean.abs() / diffStd;

    final norm = _normality(diffs, summaries, '$aCol − $bCol');
    final test = StatisticalMath.pairedTTest(a, b);

    if (test != null) {
      findings.add(
        RealDataFinding(
          labelAr: test.testName,
          labelEn: test.testName,
          value:
              't = ${test.statistic.toStringAsFixed(3)}, p = ${test.pValue.toStringAsFixed(4)}',
          passed: true,
        ),
      );
    }

    _summarizeColumn(summaries, aCol, a);
    _summarizeColumn(summaries, bCol, b);

    return RealDataAnalysis(
      fromRealData: true,
      fileName: dataset.fileName,
      sampleSize: pairs.length,
      shapiroP: norm?.pValue,
      observedEffectSize: effect,
      mainTestP: test?.pValue,
      mainTestName: test?.testName,
      normality: _normalityStatus(norm?.pValue, alpha),
      skewness: summaries.isNotEmpty ? summaries.first.skewness : null,
      kurtosis: summaries.isNotEmpty ? summaries.first.kurtosis : null,
      columnSummaries: summaries,
      findings: findings,
      warnings: warnings,
    );
  }

  RealDataAnalysis _anova(
    StatisticalDataset dataset,
    ColumnMapping mapping,
    double alpha,
    List<String> warnings,
    List<RealDataFinding> findings,
    List<NumericColumnSummary> summaries,
  ) {
    final dep = mapping.dependentColumn;
    final grp = mapping.groupColumn;
    if (dep == null || grp == null) {
      throw Exception(
        appTr(
          'اختر عمود النتيجة وعمود المجموعة',
          'Select outcome and group columns',
        ),
      );
    }

    final groups = _numericByGroup(dataset, dep, grp);
    if (groups.length < 2) {
      throw Exception(
        appTr('يلزم مجموعتين على الأقل', 'At least two groups required'),
      );
    }

    final allValues = groups.values.expand((e) => e).toList();
    final norm = _normality(allValues, summaries, dep);
    final levene = StatisticalMath.leveneTest(groups);
    final homogeneityOk =
        levene == null || !levene.significantAt(alpha);
    final anova = StatisticalMath.oneWayAnova(groups);
    final effect = math.sqrt(StatisticalMath.etaSquared(groups));

    if (levene != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'Levene',
          labelEn: 'Levene',
          value: 'p = ${levene.pValue.toStringAsFixed(4)}',
          passed: homogeneityOk,
        ),
      );
    }
    if (anova != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'ANOVA',
          labelEn: 'ANOVA',
          value:
              'F = ${anova.statistic.toStringAsFixed(3)}, p = ${anova.pValue.toStringAsFixed(4)}',
          passed: true,
        ),
      );
    }

    for (final entry in groups.entries) {
      _summarizeColumn(summaries, '$dep (${entry.key})', entry.value);
    }

    return RealDataAnalysis(
      fromRealData: true,
      fileName: dataset.fileName,
      sampleSize: allValues.length,
      groupCount: groups.length,
      shapiroP: norm?.pValue,
      leveneP: levene?.pValue,
      observedEffectSize: effect,
      mainTestP: anova?.pValue,
      mainTestName: anova?.testName,
      homogeneityOk: homogeneityOk,
      normality: _normalityStatus(norm?.pValue, alpha),
      columnSummaries: summaries,
      findings: findings,
      warnings: warnings,
    );
  }

  RealDataAnalysis _correlation(
    StatisticalDataset dataset,
    ColumnMapping mapping,
    double alpha,
    List<String> warnings,
    List<RealDataFinding> findings,
    List<NumericColumnSummary> summaries,
  ) {
    final xCol = mapping.dependentColumn;
    final yCol = mapping.secondNumericColumn;
    if (xCol == null || yCol == null) {
      throw Exception(
        appTr('اختر متغيرين رقميين', 'Select two numeric variables'),
      );
    }

    final pairs = _pairedNumeric(dataset, xCol, yCol);
    if (pairs.length < 3) {
      throw Exception(
        appTr('يلزم 3 صفوف على الأقل', 'At least 3 rows required'),
      );
    }

    final x = pairs.map((p) => p.$1).toList();
    final y = pairs.map((p) => p.$2).toList();
    final corr = StatisticalMath.pearsonCorrelation(x, y);
    final linearityOk = corr != null && corr.statistic.abs() >= 0.1;

    _summarizeColumn(summaries, xCol, x);
    _summarizeColumn(summaries, yCol, y);

    final normX = _normality(x, summaries, xCol);
    final normY = _normality(y, summaries, yCol);
    final worstP = _worstP(normX?.pValue, normY?.pValue);

    if (corr != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'Pearson r',
          labelEn: 'Pearson r',
          value:
              'r = ${corr.statistic.toStringAsFixed(3)}, p = ${corr.pValue.toStringAsFixed(4)}',
          passed: true,
        ),
      );
    }

    return RealDataAnalysis(
      fromRealData: true,
      fileName: dataset.fileName,
      sampleSize: pairs.length,
      shapiroP: worstP,
      observedEffectSize: corr?.statistic.abs(),
      mainTestP: corr?.pValue,
      mainTestName: corr?.testName,
      linearityOk: linearityOk,
      normality: _normalityStatus(worstP, alpha),
      columnSummaries: summaries,
      findings: findings,
      warnings: warnings,
    );
  }

  RealDataAnalysis _regression(
    StatisticalDataset dataset,
    ColumnMapping mapping,
    double alpha,
    List<String> warnings,
    List<RealDataFinding> findings,
    List<NumericColumnSummary> summaries,
  ) {
    final yCol = mapping.dependentColumn;
    final xCol = mapping.secondNumericColumn ?? mapping.groupColumn;
    if (yCol == null || xCol == null) {
      throw Exception(
        appTr(
          'اختر Y (تابع) و X (مستقل)',
          'Select dependent Y and predictor X',
        ),
      );
    }

    final pairs = _pairedNumeric(dataset, xCol, yCol);
    if (pairs.length < 3) {
      throw Exception(
        appTr('يلزم 3 صفوف على الأقل', 'At least 3 rows required'),
      );
    }

    final x = pairs.map((p) => p.$1).toList();
    final y = pairs.map((p) => p.$2).toList();
    final reg = StatisticalMath.simpleLinearRegression(x, y);
    final mx = _mean(x);
    final my = _mean(y);
    var ssX = 0.0;
    var ssXY = 0.0;
    for (var i = 0; i < x.length; i++) {
      ssX += (x[i] - mx) * (x[i] - mx);
      ssXY += (x[i] - mx) * (y[i] - my);
    }
    final slope = ssX == 0 ? 0 : ssXY / ssX;
    final intercept = my - slope * mx;
    final residuals = List<double>.generate(
      pairs.length,
      (i) => y[i] - (intercept + slope * x[i]),
    );
    final normRes = _normality(residuals, summaries, 'residuals');

    _summarizeColumn(summaries, xCol, x);
    _summarizeColumn(summaries, yCol, y);

    if (reg != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'R²',
          labelEn: 'R²',
          value: reg.r2.toStringAsFixed(3),
          passed: true,
        ),
      );
      if (reg.fTest != null) {
        findings.add(
          RealDataFinding(
            labelAr: reg.fTest!.testName,
            labelEn: reg.fTest!.testName,
            value: 'p = ${reg.fTest!.pValue.toStringAsFixed(4)}',
            passed: true,
          ),
        );
      }
    }

    return RealDataAnalysis(
      fromRealData: true,
      fileName: dataset.fileName,
      sampleSize: pairs.length,
      shapiroP: normRes?.pValue,
      observedEffectSize: reg != null ? math.sqrt(reg.r2) : null,
      mainTestP: reg?.fTest?.pValue,
      mainTestName: reg?.fTest?.testName,
      linearityOk: reg != null && reg.r2 >= 0.01,
      normality: _normalityStatus(normRes?.pValue, alpha),
      columnSummaries: summaries,
      findings: findings,
      warnings: warnings,
    );
  }

  RealDataAnalysis _chiSquare(
    StatisticalDataset dataset,
    ColumnMapping mapping,
    double alpha,
    List<String> warnings,
    List<RealDataFinding> findings,
    List<NumericColumnSummary> summaries,
  ) {
    final rowCol = mapping.groupColumn;
    final colCol = mapping.dependentColumn;
    if (rowCol == null || colCol == null) {
      throw Exception(
        appTr('اختر عمودين فئويين', 'Select two categorical columns'),
      );
    }

    final table = _contingencyTable(dataset, rowCol, colCol);
    final chi = StatisticalMath.chiSquareTest(table.counts);
    final minExpected = table.minExpected >= 5;

    if (chi != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'Chi-square',
          labelEn: 'Chi-square',
          value:
              'χ² = ${chi.statistic.toStringAsFixed(3)}, p = ${chi.pValue.toStringAsFixed(4)}',
          passed: true,
        ),
      );
      findings.add(
        RealDataFinding(
          labelAr: 'التكرارات المتوقعة',
          labelEn: 'Expected counts',
          value: appTr(
            'أدنى متوقع = ${table.minExpected.toStringAsFixed(1)}',
            'Min expected = ${table.minExpected.toStringAsFixed(1)}',
          ),
          passed: minExpected,
        ),
      );
    }

    return RealDataAnalysis(
      fromRealData: true,
      fileName: dataset.fileName,
      sampleSize: table.total,
      groupCount: table.rows,
      mainTestP: chi?.pValue,
      mainTestName: chi?.testName,
      homogeneityOk: minExpected,
      normality: NormalityStatus.normal,
      findings: findings,
      warnings: warnings,
    );
  }

  StatTestResult? _normality(
    List<double> values,
    List<NumericColumnSummary> summaries,
    String label,
  ) {
    final test = StatisticalMath.normalityTest(values);
    if (test != null && !summaries.any((s) => s.column == label)) {
      final stats = StatisticalMath.describe(values);
      summaries.add(
        NumericColumnSummary(
          column: label,
          n: stats.n,
          mean: stats.mean,
          std: stats.std,
          skewness: stats.skewness,
          kurtosis: stats.kurtosis,
          normalityP: test.pValue,
          normalityTestName: test.testName,
        ),
      );
    }
    return test;
  }

  void _summarizeColumn(
    List<NumericColumnSummary> summaries,
    String column,
    List<double> values,
  ) {
    if (summaries.any((s) => s.column == column)) return;
    final stats = StatisticalMath.describe(values);
    final test = StatisticalMath.normalityTest(values);
    summaries.add(
      NumericColumnSummary(
        column: column,
        n: stats.n,
        mean: stats.mean,
        std: stats.std,
        skewness: stats.skewness,
        kurtosis: stats.kurtosis,
        normalityP: test?.pValue,
        normalityTestName: test?.testName ?? '—',
      ),
    );
  }

  Map<String, List<double>> _numericByGroup(
    StatisticalDataset dataset,
    String valueColumn,
    String groupColumn,
  ) {
    final vIdx = dataset.headers.indexOf(valueColumn);
    final gIdx = dataset.headers.indexOf(groupColumn);
    final map = <String, List<double>>{};

    for (final row in dataset.rows) {
      if (vIdx >= row.length || gIdx >= row.length) continue;
      final raw = row[vIdx].trim().replaceAll(',', '.');
      final val = double.tryParse(raw);
      final group = row[gIdx].trim();
      if (val == null || group.isEmpty) continue;
      map.putIfAbsent(group, () => []).add(val);
    }
    return map;
  }

  List<(double, double)> _pairedNumeric(
    StatisticalDataset dataset,
    String colA,
    String colB,
  ) {
    final aIdx = dataset.headers.indexOf(colA);
    final bIdx = dataset.headers.indexOf(colB);
    final pairs = <(double, double)>[];

    for (final row in dataset.rows) {
      if (aIdx >= row.length || bIdx >= row.length) continue;
      final a = double.tryParse(row[aIdx].trim().replaceAll(',', '.'));
      final b = double.tryParse(row[bIdx].trim().replaceAll(',', '.'));
      if (a != null && b != null) pairs.add((a, b));
    }
    return pairs;
  }

  ({List<List<double>> counts, double minExpected, int total, int rows})
      _contingencyTable(
    StatisticalDataset dataset,
    String rowCol,
    String colCol,
  ) {
    final rIdx = dataset.headers.indexOf(rowCol);
    final cIdx = dataset.headers.indexOf(colCol);
    final rowKeys = <String>[];
    final colKeys = <String>[];
    final counts = <String, Map<String, double>>{};

    for (final row in dataset.rows) {
      if (rIdx >= row.length || cIdx >= row.length) continue;
      final r = row[rIdx].trim();
      final c = row[cIdx].trim();
      if (r.isEmpty || c.isEmpty) continue;
      if (!rowKeys.contains(r)) rowKeys.add(r);
      if (!colKeys.contains(c)) colKeys.add(c);
      counts.putIfAbsent(r, () => {});
      counts[r]![c] = (counts[r]![c] ?? 0) + 1;
    }

    final matrix = List.generate(
      rowKeys.length,
      (r) => List.generate(
        colKeys.length,
        (c) => counts[rowKeys[r]]?[colKeys[c]] ?? 0,
      ),
    );

    final rowSums = matrix.map((r) => r.fold(0.0, (a, b) => a + b)).toList();
    final total = rowSums.fold(0.0, (a, b) => a + b);
    final colSums = List<double>.generate(colKeys.length, (c) {
      var s = 0.0;
      for (final row in matrix) {
        s += row[c];
      }
      return s;
    });

    var minExpected = double.infinity;
    for (var r = 0; r < rowKeys.length; r++) {
      for (var c = 0; c < colKeys.length; c++) {
        final exp = rowSums[r] * colSums[c] / total;
        if (exp > 0 && exp < minExpected) minExpected = exp;
      }
    }
    if (minExpected.isInfinite) minExpected = 0;

    return (
      counts: matrix,
      minExpected: minExpected,
      total: total.toInt(),
      rows: rowKeys.length,
    );
  }

  NormalityStatus _normalityStatus(double? p, double alpha) {
    if (p == null) return NormalityStatus.unknown;
    if (p >= alpha) return NormalityStatus.normal;
    if (p >= alpha / 2) return NormalityStatus.questionable;
    return NormalityStatus.nonNormal;
  }

  double? _worstP(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  double _sampleStd(List<double> values, double mean) {
    if (values.length < 2) return 0;
    var sum = 0.0;
    for (final x in values) {
      final d = x - mean;
      sum += d * d;
    }
    return math.sqrt(sum / (values.length - 1));
  }

  double _mean(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
}
