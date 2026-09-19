import 'citation_health.dart';

enum CitationValidationStatus {
  verified,
  partial,
  notFound,
  invalidDoi,
  error,
}

enum CitationDataSource { crossref, openAlex, semanticScholar }

class ParsedCitation {
  final int index;
  final String rawText;
  final String? doi;
  final String titleGuess;
  final int? yearGuess;
  final String searchQuery;

  const ParsedCitation({
    required this.index,
    required this.rawText,
    this.doi,
    required this.titleGuess,
    this.yearGuess,
    required this.searchQuery,
  });
}

class CitationMatch {
  final CitationValidationStatus status;
  final CitationDataSource source;
  final String matchedTitle;
  final String? matchedAuthors;
  final int? year;
  final String? doi;
  final String? url;
  final String? note;
  final String? scholarSearchUrl;
  final CitationHealth? health;

  const CitationMatch({
    required this.status,
    required this.source,
    required this.matchedTitle,
    this.matchedAuthors,
    this.year,
    this.doi,
    this.url,
    this.note,
    this.scholarSearchUrl,
    this.health,
  });

  CitationMatch copyWith({
    String? note,
    String? scholarSearchUrl,
    CitationHealth? health,
  }) {
    return CitationMatch(
      status: status,
      source: source,
      matchedTitle: matchedTitle,
      matchedAuthors: matchedAuthors,
      year: year,
      doi: doi,
      url: url,
      note: note ?? this.note,
      scholarSearchUrl: scholarSearchUrl ?? this.scholarSearchUrl,
      health: health ?? this.health,
    );
  }
}

class CitationCheckItem {
  final ParsedCitation citation;
  final CitationMatch? match;

  const CitationCheckItem({
    required this.citation,
    this.match,
  });
}

class CitationCheckReport {
  final List<CitationCheckItem> items;
  final int verifiedCount;
  final int partialCount;
  final int notFoundCount;
  final int invalidCount;
  final int errorCount;
  /// How many bibliography rows were parsed (may exceed [total] if capped).
  final int parsedCount;

  const CitationCheckReport({
    required this.items,
    required this.verifiedCount,
    required this.partialCount,
    required this.notFoundCount,
    required this.invalidCount,
    required this.errorCount,
    this.parsedCount = 0,
  });

  int get parsedTotal => parsedCount > 0 ? parsedCount : total;

  int get total => items.length;

  int get retractedCount => items.where((i) => i.match?.health?.isRetracted == true).length;

  int get concernCount =>
      items.where((i) => i.match?.health?.hasExpressionOfConcern == true).length;

  int get correctionCount =>
      items.where((i) => i.match?.health?.hasCorrection == true).length;

  int get integrityScore {
    if (total == 0) return 0;
    var sum = 0;
    for (final item in items) {
      final match = item.match;
      if (match == null) continue;
      var base = switch (match.status) {
        CitationValidationStatus.verified => 100,
        CitationValidationStatus.partial => 55,
        CitationValidationStatus.notFound ||
        CitationValidationStatus.invalidDoi ||
        CitationValidationStatus.error =>
          0,
      };
      final health = match.health;
      if (health != null) {
        if (health.isRetracted) {
          base = 0;
        } else if (health.hasExpressionOfConcern) {
          base = (base * 0.35).round();
        } else if (health.hasCorrection) {
          base = (base * 0.75).round();
        }
      }
      sum += base;
    }
    return (sum / total).round().clamp(0, 100);
  }
}
