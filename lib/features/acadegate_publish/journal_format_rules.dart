import '../../core/locale/app_translate.dart';
import 'citation_formatter.dart';
import 'citation_linker.dart';
import 'publish_models.dart';

enum FormatRuleConfidence { partnerOfficial, publisherStandard, estimated }

class JournalCitationInference {
  final PublishCitationStyle style;
  final bool plainNumber;

  const JournalCitationInference({
    required this.style,
    this.plainNumber = false,
  });
}

class JournalFormatRules {
  final String journalName;
  final String publisher;
  final PublishCitationStyle citationStyle;
  final String fontFamily;
  final int bodyFontHalfPoints;
  final int titleFontHalfPoints;
  final int headingFontHalfPoints;
  final double lineSpacing;
  final int marginTwips;
  final bool justifyBody;
  final String referenceSectionTitle;
  /// In-text `[1]` with plain-number list `1. 2. 3.` (no brackets in bibliography).
  final bool referenceListPlainNumber;
  final String profileLabel;
  final FormatRuleConfidence confidence;
  final String basisAr;
  final String basisEn;
  final List<String> verifyStepsAr;
  final List<String> verifyStepsEn;
  final String? sourceUrl;
  final bool extractedFromGuide;
  final String? excerpt;
  /// 1 = single column, 2 = two-column body.
  final int columnCount;
  /// `a4` or `letter`.
  final String paperSize;
  final int firstLineIndentTwips;
  final bool headingNumbered;
  final bool headingUppercase;
  final String titleAlign;
  final bool pageNumbers;
  final bool runningHeader;
  final int? abstractMaxWords;
  final List<String> sectionOrder;
  /// Sample bibliography line copied from the author guide.
  final String? referenceExample;
  /// Sample in-text citation copied from the author guide.
  final String? inTextExample;
  final bool titleUppercase;
  final int? maxReferences;
  final int? maxFiguresAndTables;
  final double? figureMaxWidthCm;
  final int? keywordsMin;
  final int? keywordsMax;
  final int? runningTitleMaxChars;
  final bool noEtAlInReferences;
  final List<String> keyRequirements;

  const JournalFormatRules({
    required this.journalName,
    this.publisher = '',
    required this.citationStyle,
    this.fontFamily = 'Times New Roman',
    this.bodyFontHalfPoints = 24,
    this.titleFontHalfPoints = 32,
    this.headingFontHalfPoints = 28,
    this.lineSpacing = 2.0,
    this.marginTwips = 1440,
    this.justifyBody = true,
    this.referenceSectionTitle = 'References',
    this.referenceListPlainNumber = false,
    this.profileLabel = 'APA',
    this.confidence = FormatRuleConfidence.estimated,
    this.basisAr = '',
    this.basisEn = '',
    this.verifyStepsAr = const [],
    this.verifyStepsEn = const [],
    this.sourceUrl,
    this.extractedFromGuide = false,
    this.excerpt,
    this.columnCount = 1,
    this.paperSize = 'a4',
    this.firstLineIndentTwips = 0,
    this.headingNumbered = false,
    this.headingUppercase = false,
    this.titleAlign = 'center',
    this.pageNumbers = true,
    this.runningHeader = false,
    this.abstractMaxWords,
    this.sectionOrder = const [],
    this.referenceExample,
    this.inTextExample,
    this.titleUppercase = false,
    this.maxReferences,
    this.maxFiguresAndTables,
    this.figureMaxWidthCm,
    this.keywordsMin,
    this.keywordsMax,
    this.runningTitleMaxChars,
    this.noEtAlInReferences = false,
    this.keyRequirements = const [],
  });

  factory JournalFormatRules.forStudentStyle(PublishCitationStyle style) {
    return JournalFormatRules(
      journalName: '',
      citationStyle: style,
      profileLabel: CitationFormatter.styleLabel(style),
      referenceListPlainNumber: style == PublishCitationStyle.vancouver ||
          style == PublishCitationStyle.acs,
      basisAr: 'تنسيق المراجع الذي اختاره الطالب قبل اختيار المجلة',
      basisEn: 'Student-selected reference style before journal selection',
    );
  }

  int get lineSpacingTwips => (lineSpacing * 240).round();

  /// Word "exact" line height for reliable double/single spacing in exported DOCX.
  int get lineSpacingExactTwips {
    final pt = bodyFontHalfPoints / 2.0;
    return (pt * lineSpacing * 20).round();
  }

  String get lineSpacingRule => lineSpacing >= 1.99 ? 'exact' : 'auto';

  /// From extracted guide — numbered [n] in body (IEEE / BCSE / Vancouver).
  /// APA and author-date journals keep (Author, Year) in text.
  bool get usesNumberedInText =>
      (citationStyle == PublishCitationStyle.ieee ||
          citationStyle == PublishCitationStyle.vancouver ||
          citationStyle == PublishCitationStyle.acs) &&
      !usesAuthorDateInText;

  /// APA / Harvard / Chicago keep (Author, Year) in the body.
  bool get usesAuthorDateInText =>
      citationStyle == PublishCitationStyle.apa ||
      citationStyle == PublishCitationStyle.harvard ||
      citationStyle == PublishCitationStyle.chicago;

  /// From extracted guide — bibliography as 1. 2. 3. instead of [1].
  bool get usesPlainNumberBibliography => referenceListPlainNumber;

  String confidenceLabel({required bool isEnglish}) {
    if (extractedFromGuide && (sourceUrl ?? '').startsWith('template:')) {
      return appTr(
        'مستخرج من قالب المجلة المرفوع',
        'Extracted from uploaded journal template',
      );
    }
    if (extractedFromGuide) {
      return appTr(
        'مستخرج من دليل المؤلفين',
        'Extracted from author guide',
      );
    }
    return switch (confidence) {
      FormatRuleConfidence.partnerOfficial => appTr(
          'رسمي — من بيانات الشريك',
          'Official — partner data',
        ),
      FormatRuleConfidence.publisherStandard => appTr(
          'معيار الناشر — راجع دليل المؤلفين',
          'Publisher standard — verify author guide',
        ),
      FormatRuleConfidence.estimated => appTr(
          'تقديري — يجب التحقق من دليل المجلة',
          'Estimated — verify journal author guide',
        ),
    };
  }

  List<String> ruleDescriptions({required bool isEnglish}) {
    final styleName = CitationFormatter.styleMenuLabel(
      citationStyle,
      arabic: !isEnglish,
    );
    return [
      appTr(
        'نمط المراجع: $styleName',
        'Reference style: $styleName',
      ),
      if (referenceListPlainNumber)
        appTr(
          'قائمة المراجع: 1. 2. 3. بدون أقواس مربعة',
          'Reference list: 1. 2. 3. without square brackets',
        ),
      if (referenceExample != null && referenceExample!.trim().isNotEmpty)
        appTr(
          'شكل المرجع في الدليل: ${referenceExample!.trim()}',
          'Guide reference sample: ${referenceExample!.trim()}',
        ),
      if (inTextExample != null && inTextExample!.trim().isNotEmpty)
        appTr(
          'شكل الاقتباس في النص: ${inTextExample!.trim()}',
          'Guide in-text sample: ${inTextExample!.trim()}',
        ),
      if (extractedFromGuide && (sourceUrl ?? '').startsWith('template:'))
        appTr(
          'المصدر: قالب Word الرسمي المرفوع',
          'Source: uploaded official Word template',
        )
      else if (extractedFromGuide)
        appTr(
          'المصدر: دليل المؤلفين',
          'Source: author guidelines',
        )
      else
        appTr(
          'المصدر: تقدير احتياطي — ارفع قالب المجلة أو الصق دليل المؤلفين',
          'Source: fallback estimate — upload the journal template or paste the author guide',
        ),
      appTr(
        'الخط: $fontFamily — ${bodyFontHalfPoints ~/ 2} نقطة',
        'Font: $fontFamily — ${bodyFontHalfPoints ~/ 2} pt',
      ),
      appTr(
        'تباعد الأسطر: $lineSpacing',
        'Line spacing: $lineSpacing',
      ),
      appTr(
        'هوامش: ${(marginTwips / 1440).toStringAsFixed(1)} بوصة',
        'Margins: ${(marginTwips / 1440).toStringAsFixed(1)} inch',
      ),
      if (justifyBody)
        appTr('محاذاة النص: ضبط', 'Alignment: justified')
      else
        appTr('محاذاة النص: يسار', 'Alignment: left'),
      appTr(
        'الأعمدة: ${columnCount == 2 ? 'عمودان (العنوان والملخص بعرض كامل)' : 'عمود واحد'}',
        'Columns: ${columnCount == 2 ? 'two-column body (title/abstract full width)' : 'single column'}',
      ),
      appTr(
        'حجم الورق: ${paperSize.toUpperCase()}',
        'Paper: ${paperSize.toUpperCase()}',
      ),
      if (firstLineIndentTwips > 0)
        appTr(
          'مسافة أول السطر: ${(firstLineIndentTwips / 1440).toStringAsFixed(2)} بوصة',
          'First-line indent: ${(firstLineIndentTwips / 1440).toStringAsFixed(2)} in',
        ),
      if (titleUppercase)
        appTr(
          'العنوان: أحرف كبيرة عريضة',
          'Title: bold uppercase',
        ),
      appTr(
        'محاذاة العنوان: ${titleAlign == 'center' ? 'وسط' : 'يسار'}',
        'Title alignment: $titleAlign',
      ),
      if (headingNumbered)
        appTr('ترقيم العناوين: مفعّل', 'Numbered headings: on')
      else if (extractedFromGuide || keyRequirements.isNotEmpty)
        appTr('ترقيم العناوين: غير مسموح', 'Numbered headings: off'),
      if (headingUppercase)
        appTr('العناوين بأحرف كبيرة', 'Headings in uppercase'),
      if (keywordsMin != null || keywordsMax != null)
        appTr(
          'الكلمات المفتاحية: ${keywordsMin ?? 1}–${keywordsMax ?? keywordsMin} مفصولة بفاصلة',
          'Keywords: ${keywordsMin ?? 1}–${keywordsMax ?? keywordsMin}, comma-separated',
        ),
      if (runningTitleMaxChars != null)
        appTr(
          'عنوان جارٍ: حتى $runningTitleMaxChars حرفاً تحت العنوان',
          'Running title: up to $runningTitleMaxChars characters under the title',
        ),
      if (maxReferences != null)
        appTr(
          'حد المراجع: $maxReferences (للمراجعة قد يختلف)',
          'Reference limit: $maxReferences (reviews may differ)',
        ),
      if (noEtAlInReferences)
        appTr(
          'قائمة المراجع: أسماء كل المؤلفين — بدون et al.',
          'Reference list: all author names — do not use et al.',
        ),
      if (maxFiguresAndTables != null)
        appTr(
          'حد الأشكال والجداول والمخططات: $maxFiguresAndTables',
          'Schemes, tables, and figures: at most $maxFiguresAndTables',
        ),
      if (figureMaxWidthCm != null)
        appTr(
          'عرض الشكل/الجدول: حتى ${figureMaxWidthCm!.toStringAsFixed(1)} سم، والتوضيحات أسفل الشكل',
          'Figure/table width: at most ${figureMaxWidthCm!.toStringAsFixed(1)} cm; legends below figures',
        ),
      if (pageNumbers) appTr('ترقيم الصفحات: نعم', 'Page numbers: yes'),
      if (runningHeader)
        appTr('ترويسة جارية باسم المجلة', 'Running header with journal name'),
      if (abstractMaxWords != null)
        appTr(
          'حد الملخص: $abstractMaxWords كلمة',
          'Abstract limit: $abstractMaxWords words',
        ),
      if (sectionOrder.isNotEmpty)
        appTr(
          'ترتيب الأقسام: ${sectionOrder.join(' → ')}',
          'Section order: ${sectionOrder.join(' → ')}',
        ),
      appTr(
        'عنوان قسم المراجع: $referenceSectionTitle',
        'References heading: $referenceSectionTitle',
      ),
    ];
  }

  List<String> verificationSteps({required bool isEnglish}) =>
      isEnglish ? verifyStepsEn : verifyStepsAr;

  String basis({required bool isEnglish}) => isEnglish ? basisEn : basisAr;

  /// Prefer rules read from a guide/paste. Fill only empty layout slots from
  /// the publisher estimate — never discard the extracted guide.
  JournalFormatRules orFallback(JournalFormatRules fallback) {
    if (extractedFromGuide) return this;
    return fallback;
  }

  JournalFormatRules copyWith({
    PublishCitationStyle? citationStyle,
    String? fontFamily,
    int? bodyFontHalfPoints,
    int? titleFontHalfPoints,
    int? headingFontHalfPoints,
    double? lineSpacing,
    int? marginTwips,
    bool? justifyBody,
    String? referenceSectionTitle,
    bool? referenceListPlainNumber,
    String? profileLabel,
    int? columnCount,
    String? paperSize,
    int? firstLineIndentTwips,
    bool? headingNumbered,
    bool? headingUppercase,
    String? titleAlign,
    bool? pageNumbers,
    bool? runningHeader,
    int? abstractMaxWords,
    List<String>? sectionOrder,
    String? referenceExample,
    String? inTextExample,
    bool? extractedFromGuide,
    bool? titleUppercase,
    int? maxReferences,
    int? maxFiguresAndTables,
    double? figureMaxWidthCm,
    int? keywordsMin,
    int? keywordsMax,
    int? runningTitleMaxChars,
    bool? noEtAlInReferences,
    List<String>? keyRequirements,
  }) {
    return JournalFormatRules(
      journalName: journalName,
      publisher: publisher,
      citationStyle: citationStyle ?? this.citationStyle,
      fontFamily: fontFamily ?? this.fontFamily,
      bodyFontHalfPoints: bodyFontHalfPoints ?? this.bodyFontHalfPoints,
      titleFontHalfPoints: titleFontHalfPoints ?? this.titleFontHalfPoints,
      headingFontHalfPoints: headingFontHalfPoints ?? this.headingFontHalfPoints,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      marginTwips: marginTwips ?? this.marginTwips,
      justifyBody: justifyBody ?? this.justifyBody,
      referenceSectionTitle: referenceSectionTitle ?? this.referenceSectionTitle,
      referenceListPlainNumber:
          referenceListPlainNumber ?? this.referenceListPlainNumber,
      profileLabel: profileLabel ?? this.profileLabel,
      confidence: confidence,
      basisAr: basisAr,
      basisEn: basisEn,
      verifyStepsAr: verifyStepsAr,
      verifyStepsEn: verifyStepsEn,
      sourceUrl: sourceUrl,
      extractedFromGuide: extractedFromGuide ?? this.extractedFromGuide,
      excerpt: excerpt,
      columnCount: columnCount ?? this.columnCount,
      paperSize: paperSize ?? this.paperSize,
      firstLineIndentTwips: firstLineIndentTwips ?? this.firstLineIndentTwips,
      headingNumbered: headingNumbered ?? this.headingNumbered,
      headingUppercase: headingUppercase ?? this.headingUppercase,
      titleAlign: titleAlign ?? this.titleAlign,
      pageNumbers: pageNumbers ?? this.pageNumbers,
      runningHeader: runningHeader ?? this.runningHeader,
      abstractMaxWords: abstractMaxWords ?? this.abstractMaxWords,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      referenceExample: referenceExample ?? this.referenceExample,
      inTextExample: inTextExample ?? this.inTextExample,
      titleUppercase: titleUppercase ?? this.titleUppercase,
      maxReferences: maxReferences ?? this.maxReferences,
      maxFiguresAndTables: maxFiguresAndTables ?? this.maxFiguresAndTables,
      figureMaxWidthCm: figureMaxWidthCm ?? this.figureMaxWidthCm,
      keywordsMin: keywordsMin ?? this.keywordsMin,
      keywordsMax: keywordsMax ?? this.keywordsMax,
      runningTitleMaxChars: runningTitleMaxChars ?? this.runningTitleMaxChars,
      noEtAlInReferences: noEtAlInReferences ?? this.noEtAlInReferences,
      keyRequirements: keyRequirements ?? this.keyRequirements,
    );
  }

  JournalFormatRules withCitationStyle(PublishCitationStyle style) {
    return copyWith(
      citationStyle: style,
      profileLabel: referenceListPlainNumber
          ? profileLabel
          : CitationFormatter.styleLabel(style),
    );
  }

  factory JournalFormatRules.fromExtracted({
    required String journalName,
    String publisher = '',
    required String sourceUrl,
    required Map<String, dynamic> extracted,
    JournalFormatRules? fallback,
  }) {
    final fromTemplate = sourceUrl.startsWith('template:');
    final citationRaw = extracted['citationStyle']?.toString().trim();
    final refExample = extracted['referenceExample']?.toString().trim();
    final inTextExample = extracted['inTextExample']?.toString().trim();
    final inferred = inferCitationFromExamples(
      referenceExample: refExample,
      inTextExample: inTextExample,
    );
    var citation = citationRaw != null &&
            citationRaw.isNotEmpty &&
            citationRaw.toLowerCase() != 'other'
        ? _mapExtractedCitation(citationRaw)
        : (inferred?.style ?? fallback?.citationStyle ?? PublishCitationStyle.apa);
    if ((citationRaw == null ||
            citationRaw.isEmpty ||
            citationRaw.toLowerCase() == 'other') &&
        inferred != null) {
      citation = inferred.style;
    }
    final font = extracted['fontFamily']?.toString().trim();
    final bodyPt = _asExtractedDouble(extracted['bodyFontSizePt']);
    var lineSpacing = _asExtractedDouble(extracted['lineSpacing']);
    final spacingLabel = extracted['lineSpacingLabel']?.toString().toLowerCase();
    lineSpacing ??= switch (spacingLabel) {
      'single' => 1.0,
      'double' => 2.0,
      '1.5' => 1.5,
      _ => null,
    };
    final marginCm = _asExtractedDouble(extracted['marginCm']);
    final justify = extracted['justifyText'];
    final refsHeading = extracted['referencesHeading']?.toString().trim();
    final confidenceRaw = extracted['confidence']?.toString().toLowerCase();
    final columnsRaw = _asExtractedDouble(extracted['columns']);
    final paperRaw = extracted['paperSize']?.toString().toLowerCase().trim();
    final indentCm = _asExtractedDouble(extracted['firstLineIndentCm']);
    final titleFontPt = _asExtractedDouble(extracted['titleFontSizePt']);
    final headingFontPt = _asExtractedDouble(extracted['headingFontSizePt']);
    final abstractMax = extracted['abstractMaxWords'];
    final sections = extracted['sectionOrder'];
    final sectionOrder = sections is List
        ? sections.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];
    final titleAlignRaw = extracted['titleAlign']?.toString().toLowerCase();

    final confidence = switch (confidenceRaw) {
      'high' => FormatRuleConfidence.partnerOfficial,
      'medium' => FormatRuleConfidence.publisherStandard,
      _ => FormatRuleConfidence.estimated,
    };

    var plainNumber = extracted['referenceListPlainNumber'] == true;
    if (!plainNumber && inferred?.plainNumber == true) {
      plainNumber = true;
    }

    return JournalFormatRules(
      journalName: journalName,
      publisher: publisher,
      citationStyle: citation,
      fontFamily: font?.isNotEmpty == true
          ? font!
          : (fallback?.fontFamily ?? 'Times New Roman'),
      bodyFontHalfPoints: bodyPt != null
          ? (bodyPt * 2).round()
          : (fallback?.bodyFontHalfPoints ?? 24),
      titleFontHalfPoints: titleFontPt != null
          ? (titleFontPt * 2).round()
          : bodyPt != null
              ? (bodyPt * 2 + 8).round()
              : (fallback?.titleFontHalfPoints ?? 32),
      headingFontHalfPoints: headingFontPt != null
          ? (headingFontPt * 2).round()
          : bodyPt != null
              ? (bodyPt * 2 + 4).round()
              : (fallback?.headingFontHalfPoints ?? 28),
      lineSpacing: lineSpacing ?? fallback?.lineSpacing ?? 2.0,
      marginTwips: marginCm != null
          ? (marginCm * 567).round()
          : (fallback?.marginTwips ?? 1440),
      justifyBody: justify is bool ? justify : (fallback?.justifyBody ?? true),
      referenceSectionTitle: refsHeading?.isNotEmpty == true
          ? refsHeading!
          : (fallback?.referenceSectionTitle ?? 'References'),
      referenceListPlainNumber:
          plainNumber || (fallback?.referenceListPlainNumber ?? false),
      profileLabel: extracted['citationStyle']?.toString().toUpperCase() ??
          fallback?.profileLabel ??
          'GUIDE',
      confidence: confidence,
      sourceUrl: sourceUrl,
      extractedFromGuide: fromTemplate ||
          extracted['found'] == true ||
          _isDistinctiveExtract(extracted),
      excerpt: extracted['excerpt']?.toString(),
      columnCount: columnsRaw != null
          ? (columnsRaw >= 2 ? 2 : 1)
          : (fallback?.columnCount ?? 1),
      paperSize: paperRaw == 'letter'
          ? 'letter'
          : (paperRaw == 'a4' ? 'a4' : (fallback?.paperSize ?? 'a4')),
      firstLineIndentTwips: indentCm != null
          ? (indentCm * 567).round()
          : (fallback?.firstLineIndentTwips ?? 0),
      headingNumbered: extracted.containsKey('headingNumbered')
          ? extracted['headingNumbered'] == true
          : (fallback?.headingNumbered ?? false),
      headingUppercase: extracted['headingUppercase'] == true ||
          extracted['titleUppercase'] == true ||
          (fallback?.headingUppercase ?? false),
      titleAlign: titleAlignRaw == 'left'
          ? 'left'
          : (titleAlignRaw == 'center' || fallback?.titleAlign == 'center'
              ? 'center'
              : (fallback?.titleAlign ?? 'center')),
      pageNumbers: extracted['pageNumbers'] != false,
      runningHeader: extracted['runningHeader'] == true ||
          extracted['runningTitleMaxChars'] != null ||
          (fallback?.runningHeader ?? false),
      abstractMaxWords: abstractMax is num
          ? abstractMax.toInt()
          : int.tryParse(abstractMax?.toString() ?? '') ??
              fallback?.abstractMaxWords,
      sectionOrder: sectionOrder.isNotEmpty
          ? sectionOrder
          : (fallback?.sectionOrder ?? const []),
      referenceExample:
          (refExample != null && refExample.isNotEmpty) ? refExample : fallback?.referenceExample,
      inTextExample: (inTextExample != null && inTextExample.isNotEmpty)
          ? inTextExample
          : fallback?.inTextExample,
      titleUppercase: extracted['titleUppercase'] == true ||
          (fallback?.titleUppercase ?? false),
      maxReferences: _asExtractedInt(extracted['maxReferences']) ??
          fallback?.maxReferences,
      maxFiguresAndTables:
          _asExtractedInt(extracted['maxFiguresAndTables']) ??
              fallback?.maxFiguresAndTables,
      figureMaxWidthCm: _asExtractedDouble(extracted['figureMaxWidthCm']) ??
          fallback?.figureMaxWidthCm,
      keywordsMin:
          _asExtractedInt(extracted['keywordsMin']) ?? fallback?.keywordsMin,
      keywordsMax:
          _asExtractedInt(extracted['keywordsMax']) ?? fallback?.keywordsMax,
      runningTitleMaxChars:
          _asExtractedInt(extracted['runningTitleMaxChars']) ??
              fallback?.runningTitleMaxChars,
      noEtAlInReferences: extracted['noEtAlInReferences'] == true ||
          (fallback?.noEtAlInReferences ?? false),
      keyRequirements: _stringList(extracted['keyRequirements']).isNotEmpty
          ? _stringList(extracted['keyRequirements'])
          : (fallback?.keyRequirements ?? const []),
      basisAr: fromTemplate
          ? 'قُرئ من قالب Word الرسمي: ${sourceUrl.replaceFirst('template:', '')}'
          : sourceUrl.isNotEmpty
              ? 'مستخرج من دليل المؤلفين: $sourceUrl'
              : 'مستخرج من دليل المؤلفين',
      basisEn: fromTemplate
          ? 'Read from official Word template: ${sourceUrl.replaceFirst('template:', '')}'
          : sourceUrl.isNotEmpty
              ? 'Extracted from author guide: $sourceUrl'
              : 'Extracted from author guide',
      verifyStepsAr: const [
        'راجع المقتطف أدناه مع الصفحة الأصلية.',
        'إن وُجد قالب Word رسمي على موقع المجلة فهو الأدق.',
      ],
      verifyStepsEn: const [
        'Compare the excerpt below with the original page.',
        'If the journal provides an official Word template, prefer it.',
      ],
    );
  }

  static bool _isDistinctiveExtract(Map<String, dynamic> extracted) {
    if (extracted['found'] != true) return false;
    var n = 0;
    final style = extracted['citationStyle']?.toString().trim() ?? '';
    if (style.isNotEmpty && style != 'other') n++;
    if (extracted['lineSpacing'] != null ||
        extracted['lineSpacingLabel'] != null) {
      n++;
    }
    if (extracted['bodyFontSizePt'] != null) n++;
    if (extracted['columns'] != null) n++;
    if (extracted['firstLineIndentCm'] != null) n++;
    if (extracted['abstractMaxWords'] != null) n++;
    if (extracted['headingNumbered'] == true ||
        extracted['headingNumbered'] == false) {
      n++;
    }
    if (extracted['titleUppercase'] == true) n++;
    if (extracted['maxReferences'] != null) n++;
    if (extracted['keywordsMin'] != null) n++;
    if ((extracted['referenceExample']?.toString() ?? '').trim().length >= 20) {
      n++;
    }
    if ((extracted['inTextExample']?.toString() ?? '').trim().length >= 4) {
      n++;
    }
    final font = extracted['fontFamily']?.toString().trim() ?? '';
    if (font.isNotEmpty &&
        (extracted['bodyFontSizePt'] != null ||
            extracted['lineSpacing'] != null)) {
      n++;
    }
    return n >= 1;
  }

  /// Reads a sample bibliography / in-text line from the author guide.
  static JournalCitationInference? inferCitationFromExamples({
    String? referenceExample,
    String? inTextExample,
  }) {
    PublishCitationStyle? fromInText;
    PublishCitationStyle? fromList;
    var plain = false;

    final inT = (inTextExample ?? '').trim();
    if (inT.isNotEmpty) {
      if (RegExp(r'[¹²³⁴⁵⁶⁷⁸⁹⁰]').hasMatch(inT) ||
          inT.toLowerCase().contains('superscript')) {
        fromInText = PublishCitationStyle.acs;
      } else if (RegExp(r'\[\d+\]').hasMatch(inT)) {
        fromInText = PublishCitationStyle.ieee;
      } else if (RegExp(
        r'\([A-Z][A-Za-z\-]+.+(?:19|20)\d{2}',
      ).hasMatch(inT)) {
        fromInText = PublishCitationStyle.apa;
      }
    }

    final ref = (referenceExample ?? '').trim();
    if (ref.isNotEmpty) {
      if (RegExp(r'^\[\d+\]').hasMatch(ref)) {
        fromList = PublishCitationStyle.ieee;
      } else if (RegExp(r'^\d+\.\s').hasMatch(ref)) {
        fromList = PublishCitationStyle.vancouver;
        plain = true;
      } else if (RegExp(r'\((?:19|20)\d{2}\)\.').hasMatch(ref)) {
        fromList = PublishCitationStyle.apa;
      } else if (RegExp(r';\s*[A-Z][A-Za-z\-]+,\s*[A-Z]\.').hasMatch(ref) &&
          RegExp(r'\b(?:19|20)\d{2},\s*\d').hasMatch(ref)) {
        fromList = PublishCitationStyle.acs;
        plain = true;
      }
    }

    if (fromInText == PublishCitationStyle.acs) {
      return JournalCitationInference(
        style: PublishCitationStyle.acs,
        plainNumber: fromList == PublishCitationStyle.vancouver || plain,
      );
    }
    if (fromInText == PublishCitationStyle.ieee && plain) {
      return const JournalCitationInference(
        style: PublishCitationStyle.vancouver,
        plainNumber: true,
      );
    }
    final style = fromInText ?? fromList;
    if (style == null) return null;
    return JournalCitationInference(style: style, plainNumber: plain);
  }

  static PublishCitationStyle _mapExtractedCitation(String? raw) {
    final value = raw?.toLowerCase().trim() ?? '';
    return switch (value) {
      'ieee' || 'numbered' => PublishCitationStyle.ieee,
      'vancouver' => PublishCitationStyle.vancouver,
      'acs' => PublishCitationStyle.acs,
      'chicago' => PublishCitationStyle.chicago,
      'harvard' => PublishCitationStyle.harvard,
      'apa' => PublishCitationStyle.apa,
      _ => PublishCitationStyle.apa,
    };
  }

  static double? _asExtractedDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asExtractedInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }
}

class _PublisherProfile {
  final String label;
  final PublishCitationStyle citationStyle;
  final String fontFamily;
  final int bodyFontHalfPoints;
  final int titleFontHalfPoints;
  final int headingFontHalfPoints;
  final double lineSpacing;
  final int marginTwips;
  final bool justifyBody;
  final String referenceSectionTitle;
  final List<String> matchTokens;

  const _PublisherProfile({
    required this.label,
    required this.citationStyle,
    required this.fontFamily,
    required this.bodyFontHalfPoints,
    required this.titleFontHalfPoints,
    required this.headingFontHalfPoints,
    required this.lineSpacing,
    required this.marginTwips,
    required this.justifyBody,
    required this.referenceSectionTitle,
    required this.matchTokens,
  });

  bool matches(String combined) =>
      matchTokens.any((token) => combined.contains(token));
}

class JournalSectionLayout {
  JournalSectionLayout._();

  static const _aliases = <String, List<String>>{
    'abstract': ['abstract', 'الملخص'],
    'keywords': ['keywords', 'الكلمات المفتاحية', 'كلمات مفتاحية'],
    'introduction': ['introduction', 'المقدمة'],
    'experimental': ['experimental', 'experiment', 'التجريبي'],
    'methods': ['methods', 'methodology', 'materials and methods', 'المنهجية', 'المواد والطرق'],
    'results': ['results', 'النتائج'],
    'discussion': ['discussion', 'المناقشة'],
    'conclusion': ['conclusion', 'conclusions', 'الخاتمة'],
    'references': [
      'references',
      'bibliography',
      'literature cited',
      'works cited',
      'reference list',
      'المراجع',
    ],
    'acknowledgments': ['acknowledgment', 'acknowledgements', 'شكر'],
  };

  static bool isHeading(String text, List<String> names) {
    final key = _normalize(text);
    if (key.isEmpty) return false;
    // Headings are short labels. Never match the word "abstract" inside a
    // body sentence, or الملخص inside a long Arabic paragraph.
    if (key.length > 48) return false;
    for (final name in names) {
      final aliases = _aliases[_normalize(name)] ?? [_normalize(name)];
      for (final alias in aliases) {
        if (alias.isEmpty) continue;
        if (key == alias) return true;
        if (key.startsWith(alias) && key.length <= alias.length + 24) {
          return true;
        }
      }
    }
    return false;
  }

  static bool isReferencesHeading(String text) =>
      isHeading(text, const ['References', 'Bibliography', 'المراجع']);

  static bool isEnglishAbstractHeading(String text) =>
      isHeading(text, const ['Abstract']) &&
      !isHeading(text, const ['الملخص']);

  static bool isArabicAbstractHeading(String text) =>
      isHeading(text, const ['الملخص']);

  static bool isAbstractHeading(String text) =>
      isEnglishAbstractHeading(text) || isArabicAbstractHeading(text);

  static bool _looksLikeImportedBibliographyEntry(ManuscriptBlock block) {
    if (block.type != ManuscriptBlockType.paragraph) return false;
    final t = block.text.trim();
    if (t.length < 28 || t.length > 2500) return false;
    if (CitationLinker.looksLikeBibliographyLine(t)) return true;
    final numbered = RegExp(r'^\[(\d{1,3})\]\s+(.+)$').firstMatch(t) ??
        RegExp(r'^(\d{1,3})[.)]\s+(.+)$').firstMatch(t);
    if (numbered == null) return false;
    final body = numbered.group(2)!.trim();
    if (RegExp(
      r'^(The|This|In |However|Moreover|Figure|Table|Results|Therefore|These|It is|We |Our )\b',
      caseSensitive: false,
    ).hasMatch(body)) {
      return false;
    }
    final authorStart = RegExp(r"^(?:[A-Z]\.\s*)+[A-Z][A-Za-z'\-]").hasMatch(body) ||
        RegExp(r"^[A-Z][A-Za-z'\-]+,\s*[A-Z]\.").hasMatch(body);
    if (!authorStart) return false;
    return RegExp(
      r'\b(19|20)\d{2}\b|\bdoi\b|\bvol\.|\bpp\.|\bet al\.',
      caseSensitive: false,
    ).hasMatch(body);
  }

  static String _normalize(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'^\d+[.)]\s*'), '')
      .replaceAll(RegExp(r'[^a-z\u0600-\u06FF]'), '');

  /// Keep preamble and the file's section order. Drop only the imported
  /// References list (rebuilt from manuscript.references on export).
  /// Never drop الملخص when dropping a duplicated English Abstract.
  static List<ManuscriptBlock> prepareExportBlocks({
    required List<ManuscriptBlock> blocks,
    required List<String> sectionOrder,
    required bool dropAbstractSection,
  }) {
    if (blocks.isEmpty) return blocks;

    final preamble = <ManuscriptBlock>[];
    final sections = <_SectionGroup>[];
    _SectionGroup? current;

    for (final block in blocks) {
      if (block.type == ManuscriptBlockType.heading &&
          isReferencesHeading(block.text)) {
        current = _SectionGroup(block, const [], skip: true);
        sections.add(current);
        continue;
      }
      if (dropAbstractSection &&
          block.type == ManuscriptBlockType.heading &&
          isEnglishAbstractHeading(block.text)) {
        current = _SectionGroup(block, const [], skip: true);
        sections.add(current);
        continue;
      }
      // Bibliography lines belong after a References heading only.
      // A Methods sentence that happens to look like a citation must stay.
      if (current != null &&
          current.skip &&
          _looksLikeImportedBibliographyEntry(block)) {
        continue;
      }
      if (block.type == ManuscriptBlockType.heading) {
        current = _SectionGroup(block, []);
        sections.add(current);
      } else if (current == null) {
        preamble.add(block);
      } else if (!current.skip) {
        current.blocks.add(block);
      }
    }

    // Keep the imported order. Journal `sectionOrder` must not move الملخص
    // under Abstract or relocate figures.
    sectionOrder;
    return [
      ...preamble,
      for (final s in sections)
        if (!s.skip) ...[s.heading, ...s.blocks],
    ];
  }
}

class _SectionGroup {
  final ManuscriptBlock heading;
  final List<ManuscriptBlock> blocks;
  final bool skip;

  _SectionGroup(this.heading, List<ManuscriptBlock> blocks, {this.skip = false})
      : blocks = List<ManuscriptBlock>.from(blocks);
}

class JournalFormatRulesService {
  JournalFormatRulesService._();

  static final JournalFormatRulesService instance = JournalFormatRulesService._();

  static const _profiles = <_PublisherProfile>[
    _PublisherProfile(
      label: 'BCSE (Ethiopia)',
      citationStyle: PublishCitationStyle.ieee,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 32,
      headingFontHalfPoints: 28,
      lineSpacing: 1.0,
      marginTwips: 1440,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: [
        'bcse',
        'bulletin of the chemical society',
        'chemical society of ethiopia',
        'csechem',
      ],
    ),
    _PublisherProfile(
      label: 'IEEE',
      citationStyle: PublishCitationStyle.ieee,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 20,
      titleFontHalfPoints: 24,
      headingFontHalfPoints: 22,
      lineSpacing: 1.5,
      marginTwips: 1080,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['ieee', 'institute of electrical'],
    ),
    _PublisherProfile(
      label: 'Elsevier',
      citationStyle: PublishCitationStyle.apa,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 32,
      headingFontHalfPoints: 28,
      lineSpacing: 1.5,
      marginTwips: 1417,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['elsevier'],
    ),
    _PublisherProfile(
      label: 'Springer Nature',
      citationStyle: PublishCitationStyle.apa,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 22,
      titleFontHalfPoints: 28,
      headingFontHalfPoints: 24,
      lineSpacing: 1.5,
      marginTwips: 1417,
      justifyBody: false,
      referenceSectionTitle: 'References',
      matchTokens: ['springer', 'nature publishing', 'biomed central', 'bmc'],
    ),
    _PublisherProfile(
      label: 'Wiley',
      citationStyle: PublishCitationStyle.apa,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 32,
      headingFontHalfPoints: 28,
      lineSpacing: 2.0,
      marginTwips: 1440,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['wiley', 'blackwell'],
    ),
    _PublisherProfile(
      label: 'Taylor & Francis',
      citationStyle: PublishCitationStyle.apa,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 32,
      headingFontHalfPoints: 28,
      lineSpacing: 2.0,
      marginTwips: 1440,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['taylor', 'francis', 'routledge'],
    ),
    _PublisherProfile(
      label: 'ACS',
      citationStyle: PublishCitationStyle.acs,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 28,
      headingFontHalfPoints: 24,
      lineSpacing: 2.0,
      marginTwips: 1440,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['american chemical society', 'acs publications'],
    ),
    _PublisherProfile(
      label: 'MDPI',
      citationStyle: PublishCitationStyle.apa,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 28,
      headingFontHalfPoints: 24,
      lineSpacing: 2.0,
      marginTwips: 1440,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['mdpi'],
    ),
    _PublisherProfile(
      label: 'PLOS',
      citationStyle: PublishCitationStyle.apa,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 28,
      headingFontHalfPoints: 24,
      lineSpacing: 2.0,
      marginTwips: 1440,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['plos', 'public library of science'],
    ),
    _PublisherProfile(
      label: 'Frontiers',
      citationStyle: PublishCitationStyle.apa,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 28,
      headingFontHalfPoints: 24,
      lineSpacing: 2.0,
      marginTwips: 1440,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['frontiers'],
    ),
    _PublisherProfile(
      label: 'SAGE',
      citationStyle: PublishCitationStyle.apa,
      fontFamily: 'Times New Roman',
      bodyFontHalfPoints: 24,
      titleFontHalfPoints: 32,
      headingFontHalfPoints: 28,
      lineSpacing: 2.0,
      marginTwips: 1440,
      justifyBody: true,
      referenceSectionTitle: 'References',
      matchTokens: ['sage publications', 'sage '],
    ),
  ];

  static const _verifyStepsAr = [
    'افتح «بحث دليل المؤلفين» واقرأ آخر إصدار من دليل المجلة.',
    'قارن قسم المراجع والخطوط مع ملف Word المُصدَّر.',
    'بعض المجلات تطلب قالب Word رسمي — حمّله من موقع المجلة إن وُجد.',
    'Scimago يعرض التصنيف فقط ولا يحتوي قواعد التنسيق.',
  ];

  static const _verifyStepsEn = [
    'Open “Search author guidelines” and read the journal’s latest guide.',
    'Compare references and fonts with the exported Word file.',
    'Many journals provide an official Word template — download it if available.',
    'Scimago shows rankings only, not formatting rules.',
  ];

  JournalFormatRules resolve({
    required String journalName,
    String publisher = '',
    String categories = '',
    bool? supportsIeee,
    bool? supportsApa,
    String quartile = '',
    bool isPartner = false,
  }) {
    if (isPartner && (supportsIeee != null || supportsApa != null)) {
      final style = _partnerStyle(supportsIeee, supportsApa);
      return JournalFormatRules(
        journalName: journalName,
        publisher: publisher,
        citationStyle: style,
        profileLabel: CitationFormatter.styleLabel(style),
        confidence: FormatRuleConfidence.partnerOfficial,
        basisAr: 'بيانات مجلة الشريك في AcadeGate',
        basisEn: 'AcadeGate partner journal settings',
        verifyStepsAr: _verifyStepsAr,
        verifyStepsEn: _verifyStepsEn,
      );
    }

    final combined = '${journalName.toLowerCase()} '
        '${publisher.toLowerCase()} '
        '${categories.toLowerCase()}';

    for (final profile in _profiles) {
      if (profile.matches(combined)) {
        return JournalFormatRules(
          journalName: journalName,
          publisher: publisher,
          citationStyle: profile.citationStyle,
          fontFamily: profile.fontFamily,
          bodyFontHalfPoints: profile.bodyFontHalfPoints,
          titleFontHalfPoints: profile.titleFontHalfPoints,
          headingFontHalfPoints: profile.headingFontHalfPoints,
          lineSpacing: profile.lineSpacing,
          marginTwips: profile.marginTwips,
          justifyBody: profile.justifyBody,
          referenceSectionTitle: profile.referenceSectionTitle,
          profileLabel: profile.label,
          columnCount: profile.label.startsWith('IEEE') ? 2 : 1,
          paperSize: profile.label.startsWith('IEEE') ? 'letter' : 'a4',
          confidence: FormatRuleConfidence.publisherStandard,
          basisAr: 'معيار عام لناشر ${profile.label} — ليست قواعد المجلة حرفياً',
          basisEn:
              'General ${profile.label} publisher standard — not journal-specific',
          verifyStepsAr: _verifyStepsAr,
          verifyStepsEn: _verifyStepsEn,
        );
      }
    }

    final estimatedStyle = _estimateStyle(combined, quartile);
    return JournalFormatRules(
      journalName: journalName,
      publisher: publisher,
      citationStyle: estimatedStyle,
      profileLabel: CitationFormatter.styleLabel(estimatedStyle),
      confidence: FormatRuleConfidence.estimated,
      basisAr: publisher.trim().isNotEmpty
          ? 'تقدير من اسم المجلة والناشر «$publisher» — تحقق من دليل المؤلفين'
          : 'تقدير عام — الناشر غير معروف في قاعدة البيانات',
      basisEn: publisher.trim().isNotEmpty
          ? 'Estimated from journal name and publisher «$publisher»'
          : 'General estimate — publisher not in database',
      verifyStepsAr: _verifyStepsAr,
      verifyStepsEn: _verifyStepsEn,
    );
  }

  PublishCitationStyle _partnerStyle(bool? ieee, bool? apa) {
    if (ieee == true && apa != true) return PublishCitationStyle.ieee;
    if (apa == true && ieee != true) return PublishCitationStyle.apa;
    return PublishCitationStyle.apa;
  }

  PublishCitationStyle _estimateStyle(String combined, String quartile) {
    if (combined.contains('engineering') ||
        combined.contains('computer') ||
        combined.contains('electrical')) {
      return PublishCitationStyle.ieee;
    }
    if (quartile == 'Q3' || quartile == 'Q4') {
      return PublishCitationStyle.apa;
    }
    return PublishCitationStyle.apa;
  }
}
