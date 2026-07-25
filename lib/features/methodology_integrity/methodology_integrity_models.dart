enum IntegritySeverity { low, medium, high }

enum IntegrityIssueCategory {
  alignment,
  plagiarism,
  sampling,
  ethics,
  analysis,
  documentation,
  other,
}

class MethodologyIntegrityInput {
  final String thesisTitle;
  final String researchQuestion;
  final String statedMethodology;
  final String methodologyText;
  final String? population;
  final String? dataCollection;
  final String? analysisApproach;
  final List<int>? pdfBytes;
  final String? pdfFileName;

  const MethodologyIntegrityInput({
    this.thesisTitle = '',
    this.researchQuestion = '',
    required this.statedMethodology,
    required this.methodologyText,
    this.population,
    this.dataCollection,
    this.analysisApproach,
    this.pdfBytes,
    this.pdfFileName,
  });

  bool get hasPdfSource => pdfBytes != null && pdfBytes!.length > 44;

  bool get hasContent =>
      methodologyText.trim().length >= 40 ||
      researchQuestion.trim().isNotEmpty ||
      hasPdfSource;
}

class MethodologyPdfExtractionResult {
  final String fileName;
  final String title;
  final String researchQuestion;
  final String methodologyText;
  final String? methodologyType;
  final String? populationSample;
  final String? dataCollection;
  final String? analysisApproach;
  final bool truncated;

  const MethodologyPdfExtractionResult({
    required this.fileName,
    required this.title,
    required this.researchQuestion,
    required this.methodologyText,
    this.methodologyType,
    this.populationSample,
    this.dataCollection,
    this.analysisApproach,
    this.truncated = false,
  });
}

class IntegrityIssue {
  final IntegritySeverity severity;
  final IntegrityIssueCategory category;
  final String title;
  final String description;
  final String suggestion;

  const IntegrityIssue({
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    required this.suggestion,
  });

  factory IntegrityIssue.fromMap(Map<String, dynamic> map) {
    return IntegrityIssue(
      severity: _parseSeverity(map['severity']?.toString()),
      category: _parseCategory(map['category']?.toString()),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      suggestion: map['suggestion']?.toString() ?? '',
    );
  }

  static IntegritySeverity _parseSeverity(String? value) {
    final v = value?.toLowerCase() ?? '';
    if (v.contains('high') || v.contains('عال')) return IntegritySeverity.high;
    if (v.contains('low') || v.contains('منخف')) return IntegritySeverity.low;
    return IntegritySeverity.medium;
  }

  static IntegrityIssueCategory _parseCategory(String? value) {
    final v = value?.toLowerCase() ?? '';
    if (v.contains('plagiar') || v.contains('انتحال')) {
      return IntegrityIssueCategory.plagiarism;
    }
    if (v.contains('sample') || v.contains('عينة')) {
      return IntegrityIssueCategory.sampling;
    }
    if (v.contains('ethic') || v.contains('أخلاق')) {
      return IntegrityIssueCategory.ethics;
    }
    if (v.contains('analys') || v.contains('تحليل')) {
      return IntegrityIssueCategory.analysis;
    }
    if (v.contains('align') || v.contains('توافق')) {
      return IntegrityIssueCategory.alignment;
    }
    if (v.contains('doc') || v.contains('توثيق')) {
      return IntegrityIssueCategory.documentation;
    }
    return IntegrityIssueCategory.other;
  }
}

class MethodologyIntegrityReport {
  final int integrityScore;
  final String summary;
  final List<IntegrityIssue> issues;
  final List<String> strengths;
  final List<String> recommendations;
  final bool fromCloudAi;
  final String? modelUsed;
  final String? note;

  const MethodologyIntegrityReport({
    required this.integrityScore,
    required this.summary,
    this.issues = const [],
    this.strengths = const [],
    this.recommendations = const [],
    this.fromCloudAi = false,
    this.modelUsed,
    this.note,
  });

  int get highCount =>
      issues.where((i) => i.severity == IntegritySeverity.high).length;

  int get mediumCount =>
      issues.where((i) => i.severity == IntegritySeverity.medium).length;
}
