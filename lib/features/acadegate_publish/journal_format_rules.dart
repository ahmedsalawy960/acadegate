import '../../core/locale/app_translate.dart';
import 'citation_formatter.dart';
import 'publish_models.dart';

enum FormatRuleConfidence { partnerOfficial, publisherStandard, estimated }

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
  });

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

  /// Some guides require author names in text, not [1] (rare; overrides ieee list).
  bool get usesAuthorDateInText => false;

  /// From extracted guide — bibliography as 1. 2. 3. instead of [1].
  bool get usesPlainNumberBibliography => referenceListPlainNumber;

  String confidenceLabel({required bool isEnglish}) {
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
    final styleName = referenceListPlainNumber
        ? appTr(
            'مرقّم [1] في النص — 1. 2. 3. في قائمة المراجع',
            'Numbered [1] in text — 1. 2. 3. in reference list',
          )
        : citationStyle == PublishCitationStyle.ieee
            ? appTr(
                'IEEE / Vancouver — [1] في النص والقائمة',
                'IEEE / Vancouver — [1] in text and list',
              )
            : appTr('APA — (Author, Year)', 'APA — (Author, Year)');
    return [
      appTr(
        'نمط المراجع: $styleName',
        'Reference style: $styleName',
      ),
      if (extractedFromGuide)
        appTr(
          'المصدر: دليل المؤلفين',
          'Source: author guidelines',
        )
      else
        appTr(
          'المصدر: تقدير احتياطي — الصق دليل المجلة للدقة',
          'Source: fallback estimate — paste author guide for accuracy',
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
        'عنوان قسم المراجع: $referenceSectionTitle',
        'References heading: $referenceSectionTitle',
      ),
    ];
  }

  List<String> verificationSteps({required bool isEnglish}) =>
      isEnglish ? verifyStepsEn : verifyStepsAr;

  String basis({required bool isEnglish}) => isEnglish ? basisEn : basisAr;

  /// Guide-extracted rules win; otherwise use publisher/journal fallback estimate.
  JournalFormatRules orFallback(JournalFormatRules fallback) =>
      extractedFromGuide ? this : fallback;

  JournalFormatRules withCitationStyle(PublishCitationStyle style) {
    return JournalFormatRules(
      journalName: journalName,
      publisher: publisher,
      citationStyle: style,
      fontFamily: fontFamily,
      bodyFontHalfPoints: bodyFontHalfPoints,
      titleFontHalfPoints: titleFontHalfPoints,
      headingFontHalfPoints: headingFontHalfPoints,
      lineSpacing: lineSpacing,
      marginTwips: marginTwips,
      justifyBody: justifyBody,
      referenceSectionTitle: referenceSectionTitle,
      referenceListPlainNumber: referenceListPlainNumber,
      profileLabel: referenceListPlainNumber
          ? profileLabel
          : CitationFormatter.styleLabel(style),
      confidence: confidence,
      basisAr: basisAr,
      basisEn: basisEn,
      verifyStepsAr: verifyStepsAr,
      verifyStepsEn: verifyStepsEn,
      sourceUrl: sourceUrl,
      extractedFromGuide: extractedFromGuide,
      excerpt: excerpt,
    );
  }

  factory JournalFormatRules.fromExtracted({
    required String journalName,
    String publisher = '',
    required String sourceUrl,
    required Map<String, dynamic> extracted,
    JournalFormatRules? fallback,
  }) {
    final citationRaw = extracted['citationStyle']?.toString().trim();
    final citation = citationRaw != null && citationRaw.isNotEmpty
        ? _mapExtractedCitation(citationRaw)
        : (fallback?.citationStyle ?? PublishCitationStyle.apa);
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

    final confidence = switch (confidenceRaw) {
      'high' => FormatRuleConfidence.partnerOfficial,
      'medium' => FormatRuleConfidence.publisherStandard,
      _ => FormatRuleConfidence.estimated,
    };

    final plainNumber = extracted['referenceListPlainNumber'] == true;

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
      titleFontHalfPoints: bodyPt != null
          ? (bodyPt * 2 + 8).round()
          : (fallback?.titleFontHalfPoints ?? 32),
      headingFontHalfPoints: bodyPt != null
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
      referenceListPlainNumber: plainNumber,
      profileLabel: extracted['citationStyle']?.toString().toUpperCase() ??
          fallback?.profileLabel ??
          'GUIDE',
      confidence: confidence,
      sourceUrl: sourceUrl,
      extractedFromGuide: true,
      excerpt: extracted['excerpt']?.toString(),
      basisAr: sourceUrl.isNotEmpty
          ? 'مستخرج من دليل المؤلفين: $sourceUrl'
          : 'مستخرج من دليل المؤلفين',
      basisEn: sourceUrl.isNotEmpty
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
      citationStyle: PublishCitationStyle.apa,
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
