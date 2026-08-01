import 'statistical_assumptions_models.dart';

/// Thesis-ready methodology text + researcher-facing decision path.
class DecisionTreeStep {
  final String questionAr;
  final String questionEn;
  final String answerAr;
  final String answerEn;
  final bool favorable;

  const DecisionTreeStep({
    required this.questionAr,
    required this.questionEn,
    required this.answerAr,
    required this.answerEn,
    this.favorable = true,
  });

  String question(bool isEnglish) => isEnglish ? questionEn : questionAr;
  String answer(bool isEnglish) => isEnglish ? answerEn : answerAr;
}

class MethodologyParagraph {
  final String arabic;
  final String english;

  const MethodologyParagraph({
    required this.arabic,
    required this.english,
  });

  String text(bool isEnglish) => isEnglish ? english : arabic;
}

class StatisticalReportEnrichment {
  StatisticalReportEnrichment._();

  static MethodologyParagraph buildMethodology({
    required StatisticalAssumptionsInput input,
    required String recommendedAr,
    required String recommendedEn,
    required String alternativeAr,
    required String alternativeEn,
    required List<AssumptionCheck> assumptions,
    required PowerEstimate power,
    RealDataAnalysis? realData,
  }) {
    final v = input.variableName;
    final g = input.groupVariableName;
    final n = realData?.fromRealData == true
        ? realData!.sampleSize
        : input.sampleSize;
    final alpha = input.alpha;
    final failed = assumptions.where((a) => !a.passed).toList();
    final passed = assumptions.where((a) => a.passed).toList();

    final testLabelAr = input.testType.label(false);
    final testLabelEn = input.testType.label(true);

    final assumeAr = passed.isEmpty
        ? 'لم تُستوفَ كل الافتراضات الأولية'
        : 'تم فحص افتراضات التحليل (${passed.map((a) => a.title).join('، ')})';
    final assumeEn = passed.isEmpty
        ? 'not all primary assumptions were met'
        : 'analytical assumptions were examined (${passed.map((a) => a.titleEn).join(', ')})';

    final failAr = failed.isEmpty
        ? ''
        : ' ونظراً لانتهاك (${failed.map((a) => a.title).join('، ')}) '
            'اعتمد الباحث البديل المناسب: $alternativeAr.';
    final failEn = failed.isEmpty
        ? ''
        : ' Given violations of (${failed.map((a) => a.titleEn).join(', ')}), '
            'the researcher adopted the appropriate alternative: $alternativeEn.';

    final effect = realData?.observedEffectSize;
    final effectAr = effect == null
        ? ''
        : ' وبلغ حجم الأثر المرصود ${effect.toStringAsFixed(3)}.';
    final effectEn = effect == null
        ? ''
        : ' The observed effect size was ${effect.toStringAsFixed(3)}.';

    final pPartAr = realData?.mainTestP == null
        ? ''
        : ' وأظهرت نتيجة ${realData!.mainTestName ?? 'الاختبار'} '
            'قيمة p = ${realData.mainTestP!.toStringAsFixed(4)} عند α = $alpha.';
    final pPartEn = realData?.mainTestP == null
        ? ''
        : ' The ${realData!.mainTestName ?? 'test'} yielded '
            'p = ${realData.mainTestP!.toStringAsFixed(4)} at α = $alpha.';

    final powerAr = power.currentSampleAdequate
        ? 'وتشير تقديرات القوة الإحصائية إلى كفاية حجم العينة الحالي (n = $n).'
        : 'وتشير تقديرات القوة إلى أن الحجم المقترح المناسب يقترب من '
            '${power.recommendedSampleSize} (الحالي n = $n).';
    final powerEn = power.currentSampleAdequate
        ? 'Power estimation suggests the current sample size is adequate (n = $n).'
        : 'Power estimation suggests a target sample near '
            '${power.recommendedSampleSize} (current n = $n).';

    final arabic = 'حُلّلت البيانات باستخدام $testLabelAr للمتغير «$v»'
        '${_groupPhraseAr(input, g)} على عينة حجمها n = $n. '
        '$assumeAr، واختير الاختبار $recommendedAr عند مستوى دلالة α = $alpha.'
        '$failAr$effectAr$pPartAr $powerAr '
        'وأُجريت الفحوصات عبر معالج الافتراضات الإحصائية في منصة AcadeGate، '
        'مع إمكانية إعادة التحليل في SPSS أو R أو Python للتوثيق.';

    final english =
        'Data were analyzed using $testLabelEn for the variable “$v”'
        '${_groupPhraseEn(input, g)} with a sample of n = $n. '
        '$assumeEn, and $recommendedEn was selected at α = $alpha.'
        '$failEn$effectEn$pPartEn $powerEn '
        'Checks were performed via the AcadeGate statistical assumptions wizard, '
        'with optional replication in SPSS, R, or Python for documentation.';

    return MethodologyParagraph(arabic: arabic, english: english);
  }

  static List<DecisionTreeStep> buildDecisionTree({
    required StatisticalAssumptionsInput input,
    required List<AssumptionCheck> assumptions,
    required String recommendedAr,
    required String recommendedEn,
    required String alternativeAr,
    required String alternativeEn,
    RealDataAnalysis? realData,
  }) {
    final steps = <DecisionTreeStep>[];

    steps.add(
      DecisionTreeStep(
        questionAr: 'ما سؤال البحث / نوع التحليل؟',
        questionEn: 'What is the research question / analysis type?',
        answerAr: input.testType.label(false),
        answerEn: input.testType.label(true),
        favorable: true,
      ),
    );

    final n = realData?.fromRealData == true
        ? realData!.sampleSize
        : input.sampleSize;
    steps.add(
      DecisionTreeStep(
        questionAr: 'هل حجم العينة كافٍ للبدء؟',
        questionEn: 'Is the sample size enough to proceed?',
        answerAr: n >= 10
            ? 'n = $n — يمكن المتابعة مع الحذر إن كان صغيراً'
            : 'n = $n — عينة صغيرة جداً؛ فسّر بحذر',
        answerEn: n >= 10
            ? 'n = $n — proceed (interpret cautiously if small)'
            : 'n = $n — very small; interpret with caution',
        favorable: n >= 10,
      ),
    );

    if (_needsNormality(input.testType)) {
      final norm = assumptions.where((a) =>
          a.title.contains('التطبيع') || a.titleEn.toLowerCase().contains('normal'));
      final check = norm.isEmpty ? null : norm.first;
      final ok = check?.passed ?? input.normality == NormalityStatus.normal;
      steps.add(
        DecisionTreeStep(
          questionAr: 'هل التوزيع طبيعي تقريباً؟',
          questionEn: 'Is the distribution approximately normal?',
          answerAr: ok
              ? 'نعم — البارامتري مناسب مبدئياً'
              : 'لا / مشكوك — فكّر في البديل اللا بارامتري',
          answerEn: ok
              ? 'Yes — parametric tests are initially suitable'
              : 'No / questionable — consider a nonparametric alternative',
          favorable: ok,
        ),
      );
    }

    if (input.testType == StatisticalTestType.independentTTest ||
        input.testType == StatisticalTestType.oneWayAnova) {
      final homo = assumptions.where((a) =>
          a.title.contains('تجانس') ||
          a.titleEn.toLowerCase().contains('homogeneity'));
      final check = homo.isEmpty ? null : homo.first;
      final ok = check?.passed ?? input.homogeneityOk;
      steps.add(
        DecisionTreeStep(
          questionAr: 'هل التباين متجانس بين المجموعات؟',
          questionEn: 'Are group variances homogeneous?',
          answerAr: ok
              ? 'نعم — Student / ANOVA الكلاسيكي مناسب'
              : 'لا — فضّل Welch أو بدائل لا بارامترية',
          answerEn: ok
              ? 'Yes — classic Student / ANOVA is suitable'
              : 'No — prefer Welch or nonparametric alternatives',
          favorable: ok,
        ),
      );
    }

    if (input.testType == StatisticalTestType.pearsonCorrelation ||
        input.testType == StatisticalTestType.linearRegression) {
      final lin = assumptions.where((a) =>
          a.title.contains('خطي') || a.titleEn.toLowerCase().contains('linear'));
      final check = lin.isEmpty ? null : lin.first;
      final ok = check?.passed ?? input.linearityOk;
      steps.add(
        DecisionTreeStep(
          questionAr: 'هل العلاقة خطية؟',
          questionEn: 'Is the relationship linear?',
          answerAr: ok
              ? 'نعم — Pearson / الانحدار الخطي مناسب'
              : 'لا بوضوح — Spearman أو تحويل البيانات',
          answerEn: ok
              ? 'Yes — Pearson / linear regression fits'
              : 'Not clearly — Spearman or a data transform',
          favorable: ok,
        ),
      );
    }

    if (input.testType == StatisticalTestType.chiSquare) {
      final exp = assumptions.where((a) =>
          a.title.contains('متوقع') ||
          a.titleEn.toLowerCase().contains('expected'));
      final check = exp.isEmpty ? null : exp.first;
      final ok = check?.passed ?? true;
      steps.add(
        DecisionTreeStep(
          questionAr: 'هل التكرارات المتوقعة ≥ 5؟',
          questionEn: 'Are expected counts ≥ 5?',
          answerAr: ok
              ? 'نعم — مربع كاي مناسب'
              : 'لا — فكّر في Fisher أو دمج فئات',
          answerEn: ok
              ? 'Yes — chi-square is appropriate'
              : 'No — consider Fisher exact or merging categories',
          favorable: ok,
        ),
      );
    }

    final allOk = assumptions.every((a) => a.passed);
    steps.add(
      DecisionTreeStep(
        questionAr: 'ما القرار النهائي؟',
        questionEn: 'What is the final decision?',
        answerAr: allOk
            ? 'اعتمد: $recommendedAr'
            : 'الأفضل عملياً: $recommendedAr — مع إبقاء البديل: $alternativeAr',
        answerEn: allOk
            ? 'Adopt: $recommendedEn'
            : 'Practically prefer: $recommendedEn — keep alternative: $alternativeEn',
        favorable: allOk,
      ),
    );

    return steps;
  }

  static String buildWritingBrief({
    required MethodologyParagraph methodology,
    required String recommendedAr,
    required bool isEnglish,
  }) {
    if (isEnglish) {
      return 'I need academic writing help for my results/methods section.\n\n'
          'Recommended test: $recommendedAr\n\n'
          'Draft methodology paragraph:\n${methodology.english}\n\n'
          'Please refine this into clear thesis-ready English (APA style) '
          'and suggest a short results wording.';
    }
    return 'أحتاج مساعدة في صياغة قسم المنهج/النتائج إحصائياً.\n\n'
        'الاختبار المقترح: $recommendedAr\n\n'
        'مسودة فقرة المنهجية:\n${methodology.arabic}\n\n'
        'فضلاً حسّن الصياغة بأسلوب أكاديمي عربي مناسب لرسالة ماجستير/دكتوراه '
        'واقترح صياغة مختصرة للنتائج.';
  }

  static bool _needsNormality(StatisticalTestType type) {
    return type != StatisticalTestType.chiSquare;
  }

  static String _groupPhraseAr(
    StatisticalAssumptionsInput input,
    String g,
  ) {
    return switch (input.testType) {
      StatisticalTestType.independentTTest ||
      StatisticalTestType.oneWayAnova ||
      StatisticalTestType.chiSquare =>
        ' وفق مجموعات «$g»',
      StatisticalTestType.pairedTTest ||
      StatisticalTestType.pearsonCorrelation ||
      StatisticalTestType.linearRegression =>
        ' مع المتغير «$g»',
    };
  }

  static String _groupPhraseEn(
    StatisticalAssumptionsInput input,
    String g,
  ) {
    return switch (input.testType) {
      StatisticalTestType.independentTTest ||
      StatisticalTestType.oneWayAnova ||
      StatisticalTestType.chiSquare =>
        ' by group “$g”',
      StatisticalTestType.pairedTTest ||
      StatisticalTestType.pearsonCorrelation ||
      StatisticalTestType.linearRegression =>
        ' with variable “$g”',
    };
  }
}
