import 'dart:math' as math;

import '../../core/locale/app_translate.dart';
import 'statistical_assumptions_models.dart';
import 'statistical_report_enrichment.dart';

class StatisticalAssumptionsEngine {
  StatisticalAssumptionsEngine._();

  static final StatisticalAssumptionsEngine instance =
      StatisticalAssumptionsEngine._();

  StatisticalAssumptionsReport analyze(
    StatisticalAssumptionsInput input, {
    RealDataAnalysis? realData,
  }) {
    final resolvedNormality = _resolveNormality(input);
    var enriched = input.copyWith(normality: resolvedNormality);

    if (realData != null && realData.fromRealData) {
      enriched = enriched.copyWith(
        effectSize: realData.observedEffectSize ?? enriched.effectSize,
        fromRealData: true,
      );
    }

    final assumptions = _checkAssumptions(enriched, realData: realData);
    final power = _estimatePower(enriched);
    final tests = _recommendTests(enriched, assumptions);
    final tips = _buildTips(enriched, assumptions, power, realData: realData);
    final code = _buildCode(enriched, tests.recommended);
    final methodology = StatisticalReportEnrichment.buildMethodology(
      input: enriched,
      recommendedAr: tests.recommended,
      recommendedEn: tests.recommendedEn,
      alternativeAr: tests.alternative,
      alternativeEn: tests.alternativeEn,
      assumptions: assumptions,
      power: power,
      realData: realData,
    );
    final decisionTree = StatisticalReportEnrichment.buildDecisionTree(
      input: enriched,
      assumptions: assumptions,
      recommendedAr: tests.recommended,
      recommendedEn: tests.recommendedEn,
      alternativeAr: tests.alternative,
      alternativeEn: tests.alternativeEn,
      realData: realData,
    );

    return StatisticalAssumptionsReport(
      input: enriched,
      assumptions: assumptions,
      power: power,
      recommendedTest: tests.recommended,
      recommendedTestEn: tests.recommendedEn,
      alternativeTest: tests.alternative,
      alternativeTestEn: tests.alternativeEn,
      tips: tips.ar,
      tipsEn: tips.en,
      codeSnippets: code,
      advisorPrompt: _advisorPrompt(enriched, assumptions, power, tests, realData),
      methodology: methodology,
      decisionTree: decisionTree,
      realData: realData,
    );
  }

  NormalityStatus _resolveNormality(StatisticalAssumptionsInput input) {
    if (input.shapiroP != null) {
      if (input.shapiroP! >= 0.05) return NormalityStatus.normal;
      if (input.shapiroP! >= 0.01) return NormalityStatus.questionable;
      return NormalityStatus.nonNormal;
    }

    final skew = input.skewness;
    final kurt = input.kurtosis;
    if (skew != null || kurt != null) {
      final skewBad = skew != null && skew.abs() > 1.0;
      final kurtBad = kurt != null && kurt.abs() > 2.0;
      if (skewBad || kurtBad) {
        return skewBad && kurtBad
            ? NormalityStatus.nonNormal
            : NormalityStatus.questionable;
      }
      return NormalityStatus.normal;
    }

    return input.normality;
  }

  List<AssumptionCheck> _checkAssumptions(
    StatisticalAssumptionsInput input, {
    RealDataAnalysis? realData,
  }) {
    final checks = <AssumptionCheck>[];

    checks.add(_normalityCheck(input, realData: realData));

    if (input.testType == StatisticalTestType.independentTTest ||
        input.testType == StatisticalTestType.oneWayAnova) {
      checks.add(
        AssumptionCheck(
          title: 'تجانس التباين',
          titleEn: 'Homogeneity of variance',
          passed: input.homogeneityOk,
          advice: input.homogeneityOk
              ? 'التباين متقارب بين المجموعات — مناسب للاختبار البارامتري.'
              : 'استخدم اختبار Levene في SPSS/R. إن رُفضت الفرضية، '
                  'فضّل Welch t-test أو Games-Howell للمقارنات البعدية.',
          adviceEn: input.homogeneityOk
              ? 'Variance is similar across groups — suitable for parametric tests.'
              : 'Run Levene’s test in SPSS/R. If violated, prefer Welch t-test '
                  'or Games-Howell for post-hoc comparisons.',
        ),
      );
    }

    if (input.testType == StatisticalTestType.pearsonCorrelation ||
        input.testType == StatisticalTestType.linearRegression) {
      checks.add(
        AssumptionCheck(
          title: 'الخطية',
          titleEn: 'Linearity',
          passed: input.linearityOk,
          advice: input.linearityOk
              ? 'العلاقة تبدو خطية — رسم scatterplot للتأكيد.'
              : 'جرّب تحويلاً لوغاريتمياً أو Spearman/انحدار متعدد الحدود.',
          adviceEn: input.linearityOk
              ? 'Relationship appears linear — confirm with a scatterplot.'
              : 'Try a log transform or Spearman / polynomial regression.',
        ),
      );
    }

    if (input.testType == StatisticalTestType.chiSquare) {
      final minExpected = input.effectiveGroupSize >= 5;
      checks.add(
        AssumptionCheck(
          title: 'التكرارات المتوقعة',
          titleEn: 'Expected frequencies',
          passed: minExpected,
          advice: minExpected
              ? 'حجم العينة يبدو كافياً لمعظم الخلايا.'
              : 'إذا كانت خلايا < 5، استخدم Fisher’s exact أو دمج الفئات.',
          adviceEn: minExpected
              ? 'Sample size looks adequate for most cells.'
              : 'If cells < 5, use Fisher’s exact test or merge categories.',
        ),
      );
    }

    checks.add(
      AssumptionCheck(
        title: 'استقلالية الملاحظات',
        titleEn: 'Independence of observations',
        passed: input.independenceOk,
        advice: input.independenceOk
            ? 'تأكد أن كل مشارك/قياس مستقل (لا تكرار مرتبط).'
            : 'إن كانت الملاحظات مترابطة، استخدم نماذج مختلطة أو اختبارات مترابطة.',
        adviceEn: input.independenceOk
            ? 'Ensure each participant/measurement is independent.'
            : 'If observations are related, use mixed models or paired tests.',
      ),
    );

    return checks;
  }

  AssumptionCheck _normalityCheck(
    StatisticalAssumptionsInput input, {
    RealDataAnalysis? realData,
  }) {
    final n = input.sampleSize;
    final status = input.normality;

    final passed = status == NormalityStatus.normal ||
        (status == NormalityStatus.questionable && n >= 30);

    String advice;
    String adviceEn;

    if (realData?.shapiroP != null) {
      final p = realData!.shapiroP!.toStringAsFixed(4);
      final testName = realData.columnSummaries.isNotEmpty
          ? realData.columnSummaries.first.normalityTestName
          : 'Shapiro-Wilk';
      advice = 'من بياناتك: $testName p=$p، انحراف=${input.skewness?.toStringAsFixed(2) ?? "—"}.';
      adviceEn =
          'From your data: $testName p=$p, skew=${input.skewness?.toStringAsFixed(2) ?? "—"}.';
    } else {
      switch (status) {
      case NormalityStatus.normal:
        advice = 'التوزيع طبيعي — الاختبار البارامتري مناسب.';
        adviceEn = 'Distribution is normal — parametric test is appropriate.';
      case NormalityStatus.questionable:
        advice = n >= 30
            ? 'مع n≥30 قد يكون الاختبار البارامتري مقبولاً (CLT)، '
                'لكن راجع الرسم البياني والقيم الشاذة.'
            : 'مع عينة صغيرة، فضّل اختباراً لا بارامترياً أو تحويل البيانات.';
        adviceEn = n >= 30
            ? 'With n≥30 parametric tests may be acceptable (CLT), '
                'but review plots and outliers.'
            : 'With a small sample, prefer a non-parametric test or transform data.';
      case NormalityStatus.nonNormal:
        advice = 'استخدم Mann-Whitney / Wilcoxon / Kruskal-Wallis أو Spearman '
            'حسب نوع التحليل، أو حوّل البيانات (log/Box-Cox).';
        adviceEn = 'Use Mann-Whitney / Wilcoxon / Kruskal-Wallis or Spearman '
            'as appropriate, or transform data (log/Box-Cox).';
      case NormalityStatus.unknown:
        advice = 'شغّل Shapiro-Wilk (n<5000) أو راجع Q-Q plot و skewness/kurtosis '
            'قبل اختيار الاختبار.';
        adviceEn = 'Run Shapiro-Wilk (n<5000) or review Q-Q plot and '
            'skewness/kurtosis before choosing a test.';
      }
    }

    return AssumptionCheck(
      title: 'التطبيع / التوزيع الطبيعي',
      titleEn: 'Normality',
      passed: passed,
      advice: advice,
      adviceEn: adviceEn,
    );
  }

  PowerEstimate _estimatePower(StatisticalAssumptionsInput input) {
    final effect = input.effectSize ?? _defaultEffectSize(input.testType);
    final zAlpha = _zForAlpha(input.alpha);
    final zBeta = _zForPower(input.desiredPower);

    int recommended;
    String interpretation;
    String interpretationEn;

    switch (input.testType) {
      case StatisticalTestType.independentTTest:
        recommended = _nPerGroupForTTest(effect, zAlpha, zBeta);
        interpretation =
            'لحجم أثر d=${effect.toStringAsFixed(2)} وقوة ${(input.desiredPower * 100).toInt()}% '
            'تحتاج تقريباً $recommended في كل مجموعة (إجمالي ${recommended * 2}).';
        interpretationEn =
            'For effect size d=${effect.toStringAsFixed(2)} and '
            '${(input.desiredPower * 100).toInt()}% power you need about '
            '$recommended per group (${recommended * 2} total).';
      case StatisticalTestType.pairedTTest:
        recommended = _nPerGroupForTTest(effect, zAlpha, zBeta);
        interpretation =
            'للعينات المترابطة مع d=${effect.toStringAsFixed(2)} '
            'يُقترح n≈$recommended زوجاً.';
        interpretationEn =
            'For paired samples with d=${effect.toStringAsFixed(2)}, '
            'target n≈$recommended pairs.';
      case StatisticalTestType.oneWayAnova:
        recommended = _nPerGroupForAnova(
          effect,
          input.effectiveGroupCount,
          zAlpha,
          zBeta,
        );
        interpretation =
            'لتحليل تباين بـ${input.effectiveGroupCount} مجموعات وف=${effect.toStringAsFixed(2)} '
            'يُقترح ≈$recommended لكل مجموعة.';
        interpretationEn =
            'For ANOVA with ${input.effectiveGroupCount} groups and '
            'f=${effect.toStringAsFixed(2)}, target ≈$recommended per group.';
      case StatisticalTestType.pearsonCorrelation:
        recommended = _nForCorrelation(effect, zAlpha, zBeta);
        interpretation =
            'لارتباط r=${effect.toStringAsFixed(2)} وقوة ${(input.desiredPower * 100).toInt()}% '
            'يُقترح n≈$recommended.';
        interpretationEn =
            'For correlation r=${effect.toStringAsFixed(2)} and '
            '${(input.desiredPower * 100).toInt()}% power, target n≈$recommended.';
      case StatisticalTestType.linearRegression:
        recommended = _nForRegression(effect, zAlpha, zBeta);
        interpretation =
            'لانحدار بـ R²≈${(effect * effect).toStringAsFixed(2)} '
            'يُقترح n≥$recommended (قاعدة 10–15 ملاحظة لكل متغير).';
        interpretationEn =
            'For regression with R²≈${(effect * effect).toStringAsFixed(2)}, '
            'target n≥$recommended (10–15 observations per predictor).';
      case StatisticalTestType.chiSquare:
        recommended = _nForChiSquare(effect);
        interpretation =
            'للمربع كاي مع أثر متوسط (w=${effect.toStringAsFixed(2)}) '
            'يُقترح n≥$recommended مع تكرارات متوقعة ≥5.';
        interpretationEn =
            'For chi-square with medium effect (w=${effect.toStringAsFixed(2)}), '
            'target n≥$recommended with expected counts ≥5.';
    }

    final adequate = input.sampleSize >= recommended;

    return PowerEstimate(
      recommendedSampleSize: recommended,
      interpretation: interpretation,
      interpretationEn: interpretationEn,
      currentSampleAdequate: adequate,
    );
  }

  double _defaultEffectSize(StatisticalTestType type) {
    return switch (type) {
      StatisticalTestType.pearsonCorrelation => 0.3,
      StatisticalTestType.linearRegression => 0.3,
      StatisticalTestType.chiSquare => 0.3,
      StatisticalTestType.oneWayAnova => 0.25,
      _ => 0.5,
    };
  }

  double _zForAlpha(double alpha) {
    if (alpha <= 0.01) return 2.576;
    if (alpha <= 0.05) return 1.96;
    return 1.645;
  }

  double _zForPower(double power) {
    if (power >= 0.9) return 1.28;
    if (power >= 0.8) return 0.84;
    return 0.52;
  }

  int _nPerGroupForTTest(double d, double zAlpha, double zBeta) {
    if (d <= 0) return 100;
    final n = 2 * math.pow((zAlpha + zBeta) / d, 2);
    return n.ceil().clamp(10, 500);
  }

  int _nPerGroupForAnova(double f, int k, double zAlpha, double zBeta) {
    if (f <= 0) return 50;
    final lambda = math.pow(zAlpha + zBeta, 2);
    final base = (lambda / (f * f)).ceil();
    return (base + k).clamp(15, 500);
  }

  int _nForCorrelation(double r, double zAlpha, double zBeta) {
    final absR = r.abs().clamp(0.05, 0.99);
    final zR = 0.5 * math.log((1 + absR) / (1 - absR));
    if (zR == 0) return 85;
    final n = math.pow((zAlpha + zBeta) / zR, 2) + 3;
    return n.ceil().clamp(20, 500);
  }

  int _nForRegression(double r, double zAlpha, double zBeta) {
    final corrN = _nForCorrelation(r, zAlpha, zBeta);
    return math.max(corrN, 50);
  }

  int _nForChiSquare(double w) {
    if (w <= 0) return 100;
    final n = 4 / (w * w);
    return n.ceil().clamp(30, 500);
  }

  ({String recommended, String recommendedEn, String alternative, String alternativeEn})
      _recommendTests(
    StatisticalAssumptionsInput input,
    List<AssumptionCheck> assumptions,
  ) {
    final normalityFailed =
        assumptions.any((c) => c.titleEn == 'Normality' && !c.passed);
    final homogeneityFailed = assumptions.any(
      (c) => c.titleEn == 'Homogeneity of variance' && !c.passed,
    );

    return switch (input.testType) {
      StatisticalTestType.independentTTest => (
          recommended: normalityFailed || homogeneityFailed
              ? 'Welch t-test (تباين غير متساوٍ) أو Mann-Whitney U'
              : 'Independent samples t-test',
          recommendedEn: normalityFailed || homogeneityFailed
              ? 'Welch t-test (unequal variances) or Mann-Whitney U'
              : 'Independent samples t-test',
          alternative: 'Mann-Whitney U (لا بارامتري)',
          alternativeEn: 'Mann-Whitney U (non-parametric)',
        ),
      StatisticalTestType.pairedTTest => (
          recommended: normalityFailed
              ? 'Wilcoxon signed-rank test'
              : 'Paired samples t-test',
          recommendedEn: normalityFailed
              ? 'Wilcoxon signed-rank test'
              : 'Paired samples t-test',
          alternative: 'اختبار t للفروقات مع Bootstrap للفترات',
          alternativeEn: 'Paired t-test on differences with bootstrap CIs',
        ),
      StatisticalTestType.oneWayAnova => (
          recommended: normalityFailed || homogeneityFailed
              ? 'Kruskal-Wallis H'
              : 'One-way ANOVA + Tukey HSD',
          recommendedEn: normalityFailed || homogeneityFailed
              ? 'Kruskal-Wallis H'
              : 'One-way ANOVA + Tukey HSD',
          alternative: 'Welch ANOVA + Games-Howell',
          alternativeEn: 'Welch ANOVA + Games-Howell',
        ),
      StatisticalTestType.pearsonCorrelation => (
          recommended: normalityFailed
              ? 'Spearman rho'
              : 'Pearson correlation',
          recommendedEn: normalityFailed
              ? 'Spearman rho'
              : 'Pearson correlation',
          alternative: 'Kendall tau-b للعينات الصغيرة',
          alternativeEn: 'Kendall tau-b for small samples',
        ),
      StatisticalTestType.linearRegression => (
          recommended: normalityFailed
              ? 'انحدار مقاوم (robust) أو تحويل المتغيرات'
              : 'OLS linear regression',
          recommendedEn: normalityFailed
              ? 'Robust regression or variable transform'
              : 'OLS linear regression',
          alternative: 'GLM أو انحدار متعدد الحدود',
          alternativeEn: 'GLM or polynomial regression',
        ),
      StatisticalTestType.chiSquare => (
          recommended: 'Pearson chi-square / Likelihood-ratio',
          recommendedEn: 'Pearson chi-square / Likelihood-ratio',
          alternative: 'Fisher’s exact (عينات صغيرة)',
          alternativeEn: 'Fisher’s exact (small samples)',
        ),
    };
  }

  ({List<String> ar, List<String> en}) _buildTips(
    StatisticalAssumptionsInput input,
    List<AssumptionCheck> assumptions,
    PowerEstimate power, {
    RealDataAnalysis? realData,
  }) {
    final tipsAr = <String>[
      if (realData?.fromRealData == true)
        'التحليل مبني على بياناتك الفعلية من الملف.'
      else
        'أدخل بياناتك أو ارفع ملف CSV للحصول على نتائج حقيقية.',
      'افحص القيم الشاذة (boxplot / z-score > 3) قبل التحليل.',
      'وثّق اختبارات الافتراضات في فصل المنهجية أو النتائج.',
    ];
    final tipsEn = <String>[
      if (realData?.fromRealData == true)
        'Analysis is based on your actual file data.'
      else
        'Upload a CSV file for real computed statistics.',
      'Check outliers (boxplot / z-score > 3) before analysis.',
      'Document assumption tests in your methodology or results chapter.',
    ];

    if (!power.currentSampleAdequate) {
      tipsAr.add(
        'حجم عينتك (${input.sampleSize}) أقل من المقترح (${power.recommendedSampleSize}) — '
        'قد تقل قوة الاختبار لاكتشاف أثر حقيقي.',
      );
      tipsEn.add(
        'Your sample (${input.sampleSize}) is below the suggested '
        '(${power.recommendedSampleSize}) — statistical power may be low.',
      );
    }

    if (assumptions.any((c) => !c.passed)) {
      tipsAr.add('لا تتجاهل انتهاك الافتراضات — اذكر البديل الذي اخترته ولماذا.');
      tipsEn.add(
        'Do not ignore violated assumptions — state the alternative you chose and why.',
      );
    }

    return (ar: tipsAr, en: tipsEn);
  }

  List<CodeSnippet> _buildCode(
    StatisticalAssumptionsInput input,
    String recommended,
  ) {
    final v = input.variableName;
    final g = input.groupVariableName;

    return [
      CodeSnippet(
        language: CodeLanguage.spss,
        caption: 'فحص التطبيع والوصفيات — SPSS',
        captionEn: 'Normality & descriptives — SPSS',
        code: _spssExamine(input, v, g),
      ),
      CodeSnippet(
        language: CodeLanguage.spss,
        caption: 'الاختبار الرئيسي — SPSS',
        captionEn: 'Main test — SPSS',
        code: _spssMainTest(input, v, g),
      ),
      CodeSnippet(
        language: CodeLanguage.r,
        caption: 'فحص التطبيع — R',
        captionEn: 'Normality checks — R',
        code: _rNormality(input, v, g),
      ),
      CodeSnippet(
        language: CodeLanguage.r,
        caption: 'الاختبار الرئيسي — R',
        captionEn: 'Main test — R',
        code: _rMainTest(input, v, g, recommended),
      ),
      CodeSnippet(
        language: CodeLanguage.python,
        caption: 'فحص التطبيع — Python',
        captionEn: 'Normality checks — Python',
        code: _pythonNormality(input, v, g),
      ),
      CodeSnippet(
        language: CodeLanguage.python,
        caption: 'الاختبار الرئيسي — Python',
        captionEn: 'Main test — Python',
        code: _pythonMainTest(input, v, g, recommended),
      ),
    ];
  }

  String _spssExamine(StatisticalAssumptionsInput input, String v, String g) {
    if (input.testType == StatisticalTestType.oneWayAnova ||
        input.testType == StatisticalTestType.independentTTest) {
      return '''
* فحص التطبيع والتباين
EXAMINE VARIABLES=$v BY $g
  /PLOT BOXPLOT NPPLOT
  /STATISTICS DESCRIPTIVES
  /CINTERVAL 95
  /MISSING LISTWISE
  /NOTOTAL.

* Levene — تجانس التباين
T-TEST GROUPS=$g(1 2) VARIABLES=$v
  /CRITERIA=CI(.95)
  /MISSING=ANALYSIS.''';
    }

    return '''
EXAMINE VARIABLES=$v
  /PLOT NPPLOT BOXPLOT
  /STATISTICS DESCRIPTIVES.''';
  }

  String _spssMainTest(StatisticalAssumptionsInput input, String v, String g) {
    return switch (input.testType) {
      StatisticalTestType.independentTTest => '''
T-TEST GROUPS=$g(1 2) VARIABLES=$v
  /CRITERIA=CI(.95)
  /MISSING=ANALYSIS.''',
      StatisticalTestType.pairedTTest => '''
T-TEST PAIRS=$v WITH $g (PAIRED)
  /CRITERIA=CI(.95).''',
      StatisticalTestType.oneWayAnova => '''
ONEWAY $v BY $g
  /STATISTICS DESCRIPTIVES HOMOGENEITY
  /MISSING ANALYSIS
  /POSTHOC=TUKEY ALPHA(0.05).''',
      StatisticalTestType.pearsonCorrelation => '''
CORRELATIONS
  /VARIABLES=$v $g
  /PRINT=TWOTAIL NOSIG
  /MISSING=PAIRWISE.''',
      StatisticalTestType.linearRegression => '''
REGRESSION
  /MISSING LISTWISE
  /STATISTICS COEFF OUTS R ANOVA
  /CRITERIA=PIN(.05) POUT(.10)
  /ORIGIN DEPENDENT $v METHOD=ENTER $g.''',
      StatisticalTestType.chiSquare => '''
CROSSTABS
  /TABLES=$g BY $v
  /STATISTICS=CHISQ PHI
  /CELLS=COUNT EXPECTED.''',
    };
  }

  String _rNormality(StatisticalAssumptionsInput input, String v, String g) {
    if (input.testType == StatisticalTestType.independentTTest ||
        input.testType == StatisticalTestType.oneWayAnova) {
      return '''
library(tidyverse)

# استبدل df وأسماء الأعمدة
df %>% group_by($g) %>%
  summarise(
    n = n(),
    shapiro_p = shapiro.test($v)\$p.value,
    skew = moments::skewness($v),
    kurt = moments::kurtosis($v)
  )

# Q-Q plot
ggplot(df, aes(sample = $v)) + stat_qq() + stat_qq_line() +
  facet_wrap(~$g)''';
    }

    return '''
shapiro.test(df\$$v)
qqnorm(df\$$v); qqline(df\$$v)
# skewness/kurtosis: moments::skewness(df\$$v)''';
  }

  String _rMainTest(
    StatisticalAssumptionsInput input,
    String v,
    String g,
    String recommended,
  ) {
    return switch (input.testType) {
      StatisticalTestType.independentTTest =>
        recommended.contains('Mann')
            ? '''
wilcox.test($v ~ $g, data = df, exact = FALSE)
# بديل بارامتري:
t.test($v ~ $g, data = df, var.equal = FALSE)'''
            : '''
t.test($v ~ $g, data = df, var.equal = TRUE)
# إن اختلف التباين:
t.test($v ~ $g, data = df, var.equal = FALSE)''',
      StatisticalTestType.pairedTTest => '''
t.test(df\$$v, df\$$g, paired = TRUE)
# بديل: wilcox.test(df\$$v, df\$$g, paired = TRUE)''',
      StatisticalTestType.oneWayAnova => '''
aov($v ~ factor($g), data = df) |> summary()
# بعديات: TukeyHSD(aov(...))
# بديل لا بارامتري: kruskal.test($v ~ $g, data = df)''',
      StatisticalTestType.pearsonCorrelation => '''
cor.test(df\$$v, df\$$g, method = "pearson")
# بديل: method = "spearman"''',
      StatisticalTestType.linearRegression => '''
fit <- lm($v ~ $g, data = df)
summary(fit)
# افتراضات: plot(fit)  # residuals vs fitted, Q-Q''',
      StatisticalTestType.chiSquare => '''
tbl <- table(df\$$g, df\$$v)
chisq.test(tbl)
# إن كانت خلايا صغيرة: fisher.test(tbl)''',
    };
  }

  String _pythonNormality(
    StatisticalAssumptionsInput input,
    String v,
    String g,
  ) {
    if (input.testType == StatisticalTestType.independentTTest ||
        input.testType == StatisticalTestType.oneWayAnova) {
      return '''
import pandas as pd
import numpy as np
from scipy import stats

# استبدل المسار وأسماء الأعمدة
df = pd.read_csv("data.csv")  # أو: pd.read_excel("data.xlsx")

def normality_by_group(data, value_col, group_col):
    rows = []
    for name, part in data.groupby(group_col):
        x = part[value_col].dropna()
        if len(x) < 3:
            continue
        w, p = stats.shapiro(x) if len(x) <= 5000 else (np.nan, np.nan)
        rows.append({
            group_col: name,
            "n": len(x),
            "mean": x.mean(),
            "std": x.std(ddof=1),
            "skew": stats.skew(x, bias=False),
            "kurtosis": stats.kurtosis(x, bias=False),
            "shapiro_W": w,
            "shapiro_p": p,
        })
    return pd.DataFrame(rows)

print(normality_by_group(df, "$v", "$g"))

# Levene (median = Brown-Forsythe)
groups = [g["$v"].dropna().values for _, g in df.groupby("$g")]
print(stats.levene(*groups, center="median"))''';
    }

    return '''
import pandas as pd
from scipy import stats

df = pd.read_csv("data.csv")
x = df["$v"].dropna()
print(stats.describe(x))
print(stats.shapiro(x) if len(x) <= 5000 else "n>5000: use D'Agostino / JB")
print("skew:", stats.skew(x, bias=False), "kurtosis:", stats.kurtosis(x, bias=False))''';
  }

  String _pythonMainTest(
    StatisticalAssumptionsInput input,
    String v,
    String g,
    String recommended,
  ) {
    return switch (input.testType) {
      StatisticalTestType.independentTTest => recommended.contains('Mann')
          ? '''
import pandas as pd
from scipy import stats

df = pd.read_csv("data.csv")
a = df.loc[df["$g"] == df["$g"].unique()[0], "$v"].dropna()
b = df.loc[df["$g"] == df["$g"].unique()[1], "$v"].dropna()

# Mann-Whitney (بديل لا بارامتري)
print(stats.mannwhitneyu(a, b, alternative="two-sided"))

# بديل بارامتري (Welch):
print(stats.ttest_ind(a, b, equal_var=False))'''
          : '''
import pandas as pd
from scipy import stats

df = pd.read_csv("data.csv")
a = df.loc[df["$g"] == df["$g"].unique()[0], "$v"].dropna()
b = df.loc[df["$g"] == df["$g"].unique()[1], "$v"].dropna()

# Student (تباين متساوٍ) أو Welch
print(stats.ttest_ind(a, b, equal_var=True))
print(stats.ttest_ind(a, b, equal_var=False))  # Welch

# Cohen's d تقريبي
import numpy as np
pooled = np.sqrt(((len(a)-1)*a.var(ddof=1) + (len(b)-1)*b.var(ddof=1)) / (len(a)+len(b)-2))
print("Cohen d:", abs(a.mean()-b.mean()) / pooled if pooled else None)

# بديل لا بارامتري:
print(stats.mannwhitneyu(a, b, alternative="two-sided"))''',
      StatisticalTestType.pairedTTest => '''
import pandas as pd
from scipy import stats

df = pd.read_csv("data.csv")
x = df["$v"].dropna()
y = df["$g"].dropna()
# تأكد أن العمودين مترابطان بنفس الطول
n = min(len(x), len(y))
print(stats.ttest_rel(x.iloc[:n], y.iloc[:n]))
# بديل Wilcoxon:
print(stats.wilcoxon(x.iloc[:n], y.iloc[:n]))''',
      StatisticalTestType.oneWayAnova => '''
import pandas as pd
from scipy import stats
import statsmodels.api as sm
from statsmodels.formula.api import ols

df = pd.read_csv("data.csv")

# ANOVA
groups = [g["$v"].dropna().values for _, g in df.groupby("$g")]
print(stats.f_oneway(*groups))

# تفاصيل + eta² عبر statsmodels
model = ols("$v ~ C($g)", data=df).fit()
anova_table = sm.stats.anova_lm(model, typ=2)
print(anova_table)

# بديل لا بارامتري:
print(stats.kruskal(*groups))''',
      StatisticalTestType.pearsonCorrelation => '''
import pandas as pd
from scipy import stats

df = pd.read_csv("data.csv")
x = df["$v"].dropna()
y = df["$g"].dropna()
paired = pd.concat([df["$v"], df["$g"]], axis=1).dropna()
print(stats.pearsonr(paired["$v"], paired["$g"]))
print(stats.spearmanr(paired["$v"], paired["$g"]))  # بديل رتبه''',
      StatisticalTestType.linearRegression => '''
import pandas as pd
import statsmodels.api as sm

df = pd.read_csv("data.csv")
paired = df[["$g", "$v"]].dropna()
X = sm.add_constant(paired["$g"])
y = paired["$v"]
model = sm.OLS(y, X).fit()
print(model.summary())
# افتراضات البواقي: model.resid — فحص Shapiro / مخططات''',
      StatisticalTestType.chiSquare => '''
import pandas as pd
from scipy import stats

df = pd.read_csv("data.csv")
tbl = pd.crosstab(df["$g"], df["$v"])
chi2, p, dof, expected = stats.chi2_contingency(tbl)
print(tbl)
print("chi2=", chi2, "p=", p, "dof=", dof)
print("expected:\\n", expected)
# خلايا صغيرة: stats.fisher_exact(tbl) للجداول 2x2''',
    };
  }

  String _advisorPrompt(
    StatisticalAssumptionsInput input,
    List<AssumptionCheck> assumptions,
    PowerEstimate power,
    ({
      String recommended,
      String recommendedEn,
      String alternative,
      String alternativeEn,
    }) tests,
    RealDataAnalysis? realData,
  ) {
    final failed = assumptions.where((a) => !a.passed).map((a) => a.title).join('، ');
    final dataBlock = realData != null && realData.fromRealData
        ? appTr(
            '- مصدر: ملف ${realData.fileName}\n'
            '- n=${realData.sampleSize}\n'
            '${realData.mainTestName != null ? '- ${realData.mainTestName}: p=${realData.mainTestP?.toStringAsFixed(4)}\n' : ''}'
            '${realData.observedEffectSize != null ? '- حجم الأثر المرصود=${realData.observedEffectSize!.toStringAsFixed(3)}\n' : ''}',
            '- Source: file ${realData.fileName}\n'
            '- n=${realData.sampleSize}\n'
            '${realData.mainTestName != null ? '- ${realData.mainTestName}: p=${realData.mainTestP?.toStringAsFixed(4)}\n' : ''}'
            '${realData.observedEffectSize != null ? '- Observed effect=${realData.observedEffectSize!.toStringAsFixed(3)}\n' : ''}',
          )
        : '';
    return appTr(
      'راجعت نتائج معالج الافتراضات الإحصائية:\n'
      '$dataBlock'
      '- التحليل: ${input.testType.label(false)}\n'
      '- حجم العينة: ${input.sampleSize}\n'
      '- التطبيع: ${input.normality.label(false)}\n'
      '- الاختبار المقترح: ${tests.recommended}\n'
      '- قوة العينة المقترحة: ${power.recommendedSampleSize}\n'
      '${failed.isNotEmpty ? '- افتراضات تحتاج انتباه: $failed\n' : ''}'
      'ساعدني في تفسير النتائج وكتابة فقرة منهجية مناسبة للرسالة.',
      'I reviewed the statistical assumptions wizard output:\n'
      '$dataBlock'
      '- Analysis: ${input.testType.label(true)}\n'
      '- Sample size: ${input.sampleSize}\n'
      '- Normality: ${input.normality.label(true)}\n'
      '- Suggested test: ${tests.recommendedEn}\n'
      '- Suggested sample for power: ${power.recommendedSampleSize}\n'
      '${failed.isNotEmpty ? '- Assumptions needing attention: $failed\n' : ''}'
      'Help me interpret the results and draft a methodology paragraph for my thesis.',
    );
  }
}
