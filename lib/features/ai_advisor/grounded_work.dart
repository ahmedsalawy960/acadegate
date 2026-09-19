class GroundedWork {
  final String title;
  final String doi;
  final int? year;
  final String authors;
  final String source;
  final String? journal;
  final String abstractText;
  /// Landing page when DOI is missing (Semantic Scholar / Europe PMC / OpenAlex).
  final String externalUrl;

  const GroundedWork({
    required this.title,
    required this.source,
    this.doi = '',
    this.year,
    this.authors = '',
    this.journal,
    this.abstractText = '',
    this.externalUrl = '',
  });

  bool get hasDoi {
    final d = doi.trim().toLowerCase();
    return d.startsWith('10.') && d.contains('/');
  }

  String get doiUrl => hasDoi ? 'https://doi.org/${doi.trim()}' : '';

  String get primaryUrl {
    if (hasDoi) return doiUrl;
    final u = externalUrl.trim();
    return u.startsWith('http') ? u : '';
  }

  /// Stable merge key: DOI when present, otherwise normalized title+year.
  String get mergeKey {
    if (hasDoi) return 'doi:${doi.trim().toLowerCase()}';
    final t = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ')
        .trim();
    return 't:$t|${year ?? 0}';
  }

  String get apaLine {
    final who = authors.trim().isEmpty ? title : authors;
    final yearBit = year == null ? 'n.d.' : '$year';
    final journalBit =
        journal == null || journal!.trim().isEmpty ? '' : ' $journal.';
    final link = primaryUrl;
    final linkBit = link.isEmpty ? '' : ' $link';
    return '$who ($yearBit). $title.$journalBit$linkBit';
  }
}

class GroundedReferenceBundle {
  final String topic;
  final List<GroundedWork> works;
  final int droppedInventedDois;

  const GroundedReferenceBundle({
    required this.topic,
    this.works = const [],
    this.droppedInventedDois = 0,
  });

  bool get isEmpty => works.isEmpty;

  Set<String> get doiSet => {
        for (final w in works)
          if (w.hasDoi) w.doi.trim().toLowerCase(),
      };
}
