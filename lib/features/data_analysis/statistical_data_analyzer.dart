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

    _addDatasetHealthWarnings(dataset, warnings);

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

  void _addDatasetHealthWarnings(
    StatisticalDataset dataset,
    List<String> warnings,
  ) {
    if (dataset.columnCount > 2) {
      warnings.add(
        appTr(
          'الجدول يحتوي ${dataset.columnCount} أعمدة — اختر الأعمدة المناسبة للتحليل (ليس عمودين فقط)',
          'Table has ${dataset.columnCount} columns — map the ones needed for analysis (not limited to 2)',
        ),
      );
    }
    if (dataset.missingRate > 0.05) {
      final pct = (dataset.missingRate * 100).toStringAsFixed(1);
      warnings.add(
        appTr(
          'قيم ناقصة ≈ $pct% من الخلايا — الصفوف الناقصة تُستبعد تلقائياً',
          'Missing ≈ $pct% of cells — incomplete rows are dropped automatically',
        ),
      );
    }
    if (dataset.rowCount < 10) {
      warnings.add(
        appTr(
          'حجم العينة صغير (n=${dataset.rowCount}) — فسّر النتائج بحذر',
          'Small sample (n=${dataset.rowCount}) — interpret cautiously',
        ),
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

    // >2 groups: t-test is invalid — run ANOVA + Kruskal instead and warn.
    if (groups.length > 2) {
      warnings.add(
        appTr(
          'عمود المجموعة فيه ${groups.length} مستويات — اختبار t للمستقلتين يقارن مجموعتين فقط. تم تشغيل ANOVA + Kruskal-Wallis بدلاً منه.',
          'Group column has ${groups.length} levels — independent t-test needs exactly 2. Running ANOVA + Kruskal-Wallis instead.',
        ),
      );
      return _anova(
        dataset,
        mapping,
        alpha,
        warnings,
        findings,
        summaries,
      );
    }

    final allValues = groups.values.expand((e) => e).toList();
    _warnOutliers(dep, allValues, warnings);

    final keys = groups.keys.toList()..sort();
    final g0 = groups[keys[0]]!;
    final g1 = groups[keys[1]]!;

    for (final entry in groups.entries) {
      if (entry.value.length < 3) {
        warnings.add(
          appTr(
            'المجموعة «${entry.key}» صغيرة (n=${entry.value.length})',
            'Group «${entry.key}» is small (n=${entry.value.length})',
          ),
        );
      }
      _summarizeColumn(summaries, '$dep (${entry.key})', entry.value);
    }

    final norm0 = StatisticalMath.normalityTest(g0);
    final norm1 = StatisticalMath.normalityTest(g1);
    final worstNormP = _worstP(norm0?.pValue, norm1?.pValue);
    final normality = _normalityStatus(worstNormP, alpha);

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

    final tEqual = StatisticalMath.independentTTest(
      g0,
      g1,
      equalVariance: true,
    );
    final tWelch = StatisticalMath.independentTTest(
      g0,
      g1,
      equalVariance: false,
    );
    final main = homogeneityOk ? tEqual : tWelch;
    final effect = StatisticalMath.cohensD(g0, g1);

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

    final mw = StatisticalMath.mannWhitneyU(g0, g1);
    if (mw != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'Mann-Whitney U (بديل لا بارامتري)',
          labelEn: 'Mann-Whitney U (nonparametric)',
          value:
              'U = ${mw.statistic.toStringAsFixed(1)}, p = ${mw.pValue.toStringAsFixed(4)}',
          passed: true,
        ),
      );
      if (normality == NormalityStatus.nonNormal) {
        warnings.add(
          appTr(
            'التوزيع غير طبيعي — اعتمد Mann-Whitney أكثر من اختبار t',
            'Non-normal distribution — prefer Mann-Whitney over t-test',
          ),
        );
      }
    }

    return RealDataAnalysis(
      fromRealData: true,
      fileName: dataset.fileName,
      sampleSize: allValues.length,
      groupCount: groups.length,
      shapiroP: worstNormP,
      leveneP: levene?.pValue,
      observedEffectSize: effect,
      mainTestP: main?.pValue,
      mainTestName: main?.testName,
      homogeneityOk: homogeneityOk,
      normality: normality,
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

    final dropped = dataset.rowCount - pairs.length;
    if (dropped > 0) {
      warnings.add(
        appTr(
          'تم استبعاد $dropped صفاً ناقصاً من الأزواج',
          'Dropped $dropped incomplete paired rows',
        ),
      );
    }

    final a = pairs.map((p) => p.$1).toList();
    final b = pairs.map((p) => p.$2).toList();
    final diffs = List<double>.generate(pairs.length, (i) => a[i] - b[i]);
    final diffMean = _mean(diffs);
    final diffStd = _sampleStd(diffs, diffMean);
    final effect = diffStd == 0 ? 0.0 : diffMean.abs() / diffStd;

    _warnOutliers('$aCol − $bCol', diffs, warnings);
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

    if (_normalityStatus(norm?.pValue, alpha) == NormalityStatus.nonNormal) {
      warnings.add(
        appTr(
          'فروقات غير طبيعية — فكّر في Wilcoxon signed-rank (خارج المعالج حالياً)',
          'Non-normal differences — consider Wilcoxon signed-rank (not in wizard yet)',
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

    if (groups.length == 2) {
      warnings.add(
        appTr(
          'مجموعتان فقط — يمكنك استخدام اختبار t أيضاً؛ ANOVA يعطي نتيجة مكافئة',
          'Only 2 groups — t-test is also valid; ANOVA is equivalent here',
        ),
      );
    }

    final allValues = groups.values.expand((e) => e).toList();
    _warnOutliers(dep, allValues, warnings);

    for (final entry in groups.entries) {
      if (entry.value.length < 3) {
        warnings.add(
          appTr(
            'المجموعة «${entry.key}» صغيرة (n=${entry.value.length})',
            'Group «${entry.key}» is small (n=${entry.value.length})',
          ),
        );
      }
      _summarizeColumn(summaries, '$dep (${entry.key})', entry.value);
    }

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

    final kw = StatisticalMath.kruskalWallis(groups);
    if (kw != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'Kruskal-Wallis (بديل لا بارامتري)',
          labelEn: 'Kruskal-Wallis (nonparametric)',
          value:
              'H = ${kw.statistic.toStringAsFixed(3)}, p = ${kw.pValue.toStringAsFixed(4)}',
          passed: true,
        ),
      );
      if (_normalityStatus(norm?.pValue, alpha) == NormalityStatus.nonNormal ||
          !homogeneityOk) {
        warnings.add(
          appTr(
            'عند انتهاك الطبيعية/التجانس — اعتمد Kruskal-Wallis أكثر من ANOVA',
            'If normality/homogeneity fails — prefer Kruskal-Wallis over ANOVA',
          ),
        );
      }
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
    if (xCol == yCol) {
      throw Exception(
        appTr('اختر عمودين مختلفين', 'Select two different columns'),
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
    final spearman = StatisticalMath.spearmanCorrelation(x, y);
    final linearityOk = corr != null && corr.statistic.abs() >= 0.1;

    _summarizeColumn(summaries, xCol, x);
    _summarizeColumn(summaries, yCol, y);
    _warnOutliers(xCol, x, warnings);
    _warnOutliers(yCol, y, warnings);

    final normX = StatisticalMath.normalityTest(x);
    final normY = StatisticalMath.normalityTest(y);
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
    if (spearman != null) {
      findings.add(
        RealDataFinding(
          labelAr: 'Spearman ρ (بديل رتبه)',
          labelEn: 'Spearman ρ (rank-based)',
          value:
              'ρ = ${spearman.statistic.toStringAsFixed(3)}, p = ${spearman.pValue.toStringAsFixed(4)}',
          passed: true,
        ),
      );
      if (_normalityStatus(worstP, alpha) == NormalityStatus.nonNormal) {
        warnings.add(
          appTr(
            'توزيع غير طبيعي — اعتمد Spearman أكثر من Pearson',
            'Non-normal — prefer Spearman over Pearson',
          ),
        );
      }
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
    _warnOutliers('residuals', residuals, warnings);

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
      findings.add(
        RealDataFinding(
          labelAr: 'الميل / القاطع',
          labelEn: 'Slope / intercept',
          value:
              'β = ${slope.toStringAsFixed(4)}, a = ${intercept.toStringAsFixed(4)}',
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
    if (rowCol == colCol) {
      throw Exception(
        appTr('اختر عمودين مختلفين', 'Select two different columns'),
      );
    }

    final table = _contingencyTable(dataset, rowCol, colCol);
    if (table.rows < 2 || table.cols < 2) {
      throw Exception(
        appTr(
          'يلزم مستويين على الأقل في كل متغير فئوي',
          'Need at least 2 levels in each categorical variable',
        ),
      );
    }

    final chi = StatisticalMath.chiSquareTest(table.counts);
    final minExpected = table.minExpected >= 5;
    if (!minExpected) {
      warnings.add(
        appTr(
          'تكرارات متوقعة منخفضة (<5) — فكّر في Exact Fisher أو دمج فئات',
          'Low expected counts (<5) — consider Fisher exact or merging categories',
        ),
      );
    }

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
      // Cramér's V
      final k = math.min(table.rows, table.cols);
      if (k > 1 && table.total > 0) {
        final v = math.sqrt(chi.statistic / (table.total * (k - 1)));
        findings.add(
          RealDataFinding(
            labelAr: "Cramér's V",
            labelEn: "Cramér's V",
            value: v.toStringAsFixed(3),
            passed: true,
          ),
        );
      }
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

  void _warnOutliers(
    String label,
    List<double> values,
    List<String> warnings,
  ) {
    final n = StatisticalMath.outlierCountIqr(values);
    if (n <= 0) return;
    warnings.add(
      appTr(
        'قيم شاذة محتملة في «$label»: $n (طريقة IQR)',
        'Possible outliers in «$label»: $n (IQR rule)',
      ),
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
      final val = StatisticalDataset.parseNumber(row[vIdx]);
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
      final a = StatisticalDataset.parseNumber(row[aIdx]);
      final b = StatisticalDataset.parseNumber(row[bIdx]);
      if (a != null && b != null) pairs.add((a, b));
    }
    return pairs;
  }

  ({
    List<List<double>> counts,
    double minExpected,
    int total,
    int rows,
    int cols,
  }) _contingencyTable(
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
      cols: colKeys.length,
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
