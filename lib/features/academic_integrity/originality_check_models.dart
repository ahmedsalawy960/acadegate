class OriginalitySourceMatch {
  final String title;
  final String url;
  final int? matchedWords;
  final double? percent;

  const OriginalitySourceMatch({
    required this.title,
    required this.url,
    this.matchedWords,
    this.percent,
  });

  factory OriginalitySourceMatch.fromJson(Map<String, dynamic> json) {
    return OriginalitySourceMatch(
      title: json['title']?.toString() ?? 'Source',
      url: json['url']?.toString() ?? '',
      matchedWords: json['matchedWords'] is num
          ? (json['matchedWords'] as num).toInt()
          : null,
      percent: json['percent'] is num
          ? (json['percent'] as num).toDouble()
          : null,
    );
  }
}

class OriginalityCheckReport {
  final String scanId;
  final String provider;
  final double similarityPercent;
  final int? totalWords;
  final int sourceCount;
  final List<OriginalitySourceMatch> sources;

  const OriginalityCheckReport({
    required this.scanId,
    required this.provider,
    required this.similarityPercent,
    required this.sourceCount,
    required this.sources,
    this.totalWords,
  });

  factory OriginalityCheckReport.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final sources = rawSources is List
        ? rawSources
            .whereType<Map>()
            .map((e) => OriginalitySourceMatch.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <OriginalitySourceMatch>[];

    return OriginalityCheckReport(
      scanId: json['scanId']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      similarityPercent: json['similarityPercent'] is num
          ? (json['similarityPercent'] as num).toDouble()
          : 0,
      totalWords: json['totalWords'] is num
          ? (json['totalWords'] as num).toInt()
          : null,
      sourceCount: json['sourceCount'] is num
          ? (json['sourceCount'] as num).toInt()
          : sources.length,
      sources: sources,
    );
  }

  String get providerLabel {
    switch (provider) {
      case 'copyleaks':
        return 'Copyleaks';
      case 'plagiarismcheck':
        return 'PlagiarismCheck.org';
      default:
        return provider;
    }
  }
}

enum OriginalityProvider {
  auto,
  copyleaks,
  plagiarismCheck,
}
