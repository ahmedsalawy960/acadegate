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
  });
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

  const CitationCheckReport({
    required this.items,
    required this.verifiedCount,
    required this.partialCount,
    required this.notFoundCount,
    required this.invalidCount,
    required this.errorCount,
  });

  int get total => items.length;

  int get integrityScore {
    if (total == 0) return 0;
    final weighted = verifiedCount * 100 + partialCount * 55;
    return (weighted / total).round().clamp(0, 100);
  }
}
