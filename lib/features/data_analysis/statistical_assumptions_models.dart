import '../../core/locale/app_translate.dart';

enum DataInputMode { fromFile, manual }

enum StatisticalTestType {
  independentTTest,
  pairedTTest,
  oneWayAnova,
  pearsonCorrelation,
  linearRegression,
  chiSquare,
}

extension StatisticalTestTypeX on StatisticalTestType {
  String label(bool isEnglish) => switch (this) {
        StatisticalTestType.independentTTest => appTr(
            'اختبار t لمستقلتين',
            'Independent samples t-test',
          ),
        StatisticalTestType.pairedTTest => appTr(
            'اختبار t للعينات المترابطة',
            'Paired samples t-test',
          ),
        StatisticalTestType.oneWayAnova => appTr(
            'تحليل تباين أحادي الاتجاه',
            'One-way ANOVA',
          ),
        StatisticalTestType.pearsonCorrelation => appTr(
            'ارتباط بيرسون',
            'Pearson correlation',
          ),
        StatisticalTestType.linearRegression => appTr(
            'انحدار خطي بسيط',
            'Simple linear regression',
          ),
        StatisticalTestType.chiSquare => appTr(
            'مربع كاي / جداول تقاطع',
            'Chi-square / crosstabs',
          ),
      };
}

enum NormalityStatus {
  normal,
  questionable,
  nonNormal,
  unknown,
}

extension NormalityStatusX on NormalityStatus {
  String label(bool isEnglish) => switch (this) {
        NormalityStatus.normal => appTr('طبيعي', 'Normal'),
        NormalityStatus.questionable => appTr('مشكوك', 'Questionable'),
        NormalityStatus.nonNormal => appTr('غير طبيعي', 'Non-normal'),
        NormalityStatus.unknown => appTr('لم أفحص بعد', 'Not checked yet'),
      };
}

enum CodeLanguage { spss, r }

class StatisticalAssumptionsInput {
  final StatisticalTestType testType;
  final int sampleSize;
  final int? groupCount;
  final int? groupSize;
  final double alpha;
  final double desiredPower;
  final double? effectSize;
  final NormalityStatus normality;
  final double? shapiroP;
  final double? skewness;
  final double? kurtosis;
  final bool homogeneityOk;
  final bool linearityOk;
  final bool independenceOk;
  final String variableName;
  final String groupVariableName;
  final bool fromRealData;

  const StatisticalAssumptionsInput({
    required this.testType,
    this.sampleSize = 30,
    this.groupCount,
    this.groupSize,
    this.alpha = 0.05,
    this.desiredPower = 0.8,
    this.effectSize,
    this.normality = NormalityStatus.unknown,
    this.shapiroP,
    this.skewness,
    this.kurtosis,
    this.homogeneityOk = true,
    this.linearityOk = true,
    this.independenceOk = true,
    this.variableName = 'score',
    this.groupVariableName = 'group',
    this.fromRealData = false,
  });

  int get effectiveGroupCount => groupCount ?? 2;

  int get effectiveGroupSize {
    if (groupSize != null && groupSize! > 0) return groupSize!;
    if (effectiveGroupCount <= 0) return sampleSize;
    return (sampleSize / effectiveGroupCount).ceil();
  }

  StatisticalAssumptionsInput copyWith({
    StatisticalTestType? testType,
    int? sampleSize,
    int? groupCount,
    int? groupSize,
    double? alpha,
    double? desiredPower,
    double? effectSize,
    NormalityStatus? normality,
    double? shapiroP,
    double? skewness,
    double? kurtosis,
    bool? homogeneityOk,
    bool? linearityOk,
    bool? independenceOk,
    String? variableName,
    String? groupVariableName,
    bool? fromRealData,
  }) {
    return StatisticalAssumptionsInput(
      testType: testType ?? this.testType,
      sampleSize: sampleSize ?? this.sampleSize,
      groupCount: groupCount ?? this.groupCount,
      groupSize: groupSize ?? this.groupSize,
      alpha: alpha ?? this.alpha,
      desiredPower: desiredPower ?? this.desiredPower,
      effectSize: effectSize ?? this.effectSize,
      normality: normality ?? this.normality,
      shapiroP: shapiroP ?? this.shapiroP,
      skewness: skewness ?? this.skewness,
      kurtosis: kurtosis ?? this.kurtosis,
      homogeneityOk: homogeneityOk ?? this.homogeneityOk,
      linearityOk: linearityOk ?? this.linearityOk,
      independenceOk: independenceOk ?? this.independenceOk,
      variableName: variableName ?? this.variableName,
      groupVariableName: groupVariableName ?? this.groupVariableName,
      fromRealData: fromRealData ?? this.fromRealData,
    );
  }

  static StatisticalAssumptionsInput fromAnalysis({
    required StatisticalTestType testType,
    required RealDataAnalysis data,
    required String dependentColumn,
    required String groupColumn,
    double alpha = 0.05,
    double desiredPower = 0.8,
  }) {
    return StatisticalAssumptionsInput(
      testType: testType,
      sampleSize: data.sampleSize,
      groupCount: data.groupCount,
      effectSize: data.observedEffectSize,
      alpha: alpha,
      desiredPower: desiredPower,
      normality: data.normality,
      shapiroP: data.shapiroP,
      skewness: data.skewness,
      kurtosis: data.kurtosis,
      homogeneityOk: data.homogeneityOk,
      linearityOk: data.linearityOk,
      variableName: dependentColumn,
      groupVariableName: groupColumn,
      fromRealData: true,
    );
  }
}

class AssumptionCheck {
  final String title;
  final String titleEn;
  final bool passed;
  final String advice;
  final String adviceEn;

  const AssumptionCheck({
    required this.title,
    required this.titleEn,
    required this.passed,
    required this.advice,
    required this.adviceEn,
  });

  String displayTitle(bool isEnglish) => isEnglish ? titleEn : title;
  String displayAdvice(bool isEnglish) => isEnglish ? adviceEn : advice;
}

class PowerEstimate {
  final int recommendedSampleSize;
  final String interpretation;
  final String interpretationEn;
  final bool currentSampleAdequate;

  const PowerEstimate({
    required this.recommendedSampleSize,
    required this.interpretation,
    required this.interpretationEn,
    required this.currentSampleAdequate,
  });

  String displayInterpretation(bool isEnglish) =>
      isEnglish ? interpretationEn : interpretation;
}

class CodeSnippet {
  final CodeLanguage language;
  final String code;
  final String caption;
  final String captionEn;

  const CodeSnippet({
    required this.language,
    required this.code,
    required this.caption,
    required this.captionEn,
  });

  String displayCaption(bool isEnglish) => isEnglish ? captionEn : caption;
}

class StatisticalAssumptionsReport {
  final StatisticalAssumptionsInput input;
  final List<AssumptionCheck> assumptions;
  final PowerEstimate power;
  final String recommendedTest;
  final String recommendedTestEn;
  final String alternativeTest;
  final String alternativeTestEn;
  final List<String> tips;
  final List<String> tipsEn;
  final List<CodeSnippet> codeSnippets;
  final String advisorPrompt;
  final RealDataAnalysis? realData;

  const StatisticalAssumptionsReport({
    required this.input,
    required this.assumptions,
    required this.power,
    required this.recommendedTest,
    required this.recommendedTestEn,
    required this.alternativeTest,
    required this.alternativeTestEn,
    required this.tips,
    required this.tipsEn,
    required this.codeSnippets,
    required this.advisorPrompt,
    this.realData,
  });

  bool get allAssumptionsMet => assumptions.every((a) => a.passed);

  String displayRecommendedTest(bool isEnglish) =>
      isEnglish ? recommendedTestEn : recommendedTest;

  String displayAlternativeTest(bool isEnglish) =>
      isEnglish ? alternativeTestEn : alternativeTest;

  List<String> displayTips(bool isEnglish) => isEnglish ? tipsEn : tips;
}

class NumericColumnSummary {
  final String column;
  final int n;
  final double mean;
  final double std;
  final double skewness;
  final double kurtosis;
  final double? normalityP;
  final String normalityTestName;

  const NumericColumnSummary({
    required this.column,
    required this.n,
    required this.mean,
    required this.std,
    required this.skewness,
    required this.kurtosis,
    this.normalityP,
    this.normalityTestName = 'Shapiro-Wilk',
  });
}

class RealDataFinding {
  final String labelAr;
  final String labelEn;
  final String value;
  final bool passed;

  const RealDataFinding({
    required this.labelAr,
    required this.labelEn,
    required this.value,
    this.passed = true,
  });

  String label(bool isEnglish) => isEnglish ? labelEn : labelAr;
}

class RealDataAnalysis {
  final bool fromRealData;
  final String? fileName;
  final int sampleSize;
  final int? groupCount;
  final double? shapiroP;
  final double? leveneP;
  final double? observedEffectSize;
  final double? mainTestP;
  final String? mainTestName;
  final bool homogeneityOk;
  final bool linearityOk;
  final NormalityStatus normality;
  final double? skewness;
  final double? kurtosis;
  final List<NumericColumnSummary> columnSummaries;
  final List<RealDataFinding> findings;
  final List<String> warnings;

  const RealDataAnalysis({
    this.fromRealData = false,
    this.fileName,
    this.sampleSize = 0,
    this.groupCount,
    this.shapiroP,
    this.leveneP,
    this.observedEffectSize,
    this.mainTestP,
    this.mainTestName,
    this.homogeneityOk = true,
    this.linearityOk = true,
    this.normality = NormalityStatus.unknown,
    this.skewness,
    this.kurtosis,
    this.columnSummaries = const [],
    this.findings = const [],
    this.warnings = const [],
  });

  static const empty = RealDataAnalysis();
}
