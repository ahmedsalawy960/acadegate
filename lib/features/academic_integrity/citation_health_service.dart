import 'citation_health.dart';
import 'citation_models.dart';
import 'crossref_client.dart';
import 'openalex_works_client.dart';

class CitationHealthService {
  CitationHealthService._();

  static final CitationHealthService instance = CitationHealthService._();

  final _crossref = CrossrefClient.instance;
  final _openAlex = OpenAlexWorksClient.instance;
  final Map<String, CitationHealth> _cache = {};

  Future<CitationHealth> forDoi(String doi) async {
    final key = CitationHealthClassifier.normalizeDoi(doi);
    if (key.length < 6) return CitationHealth.empty;
    final cached = _cache[key];
    if (cached != null) return cached;

    var health = CitationHealth.empty;
    try {
      final open = await _openAlex.lookupDoi(key);
      if (open != null) {
        health = health.merge(
          CitationHealthClassifier.fromOpenAlexRetracted(open.isRetracted),
        );
      }
    } catch (_) {}

    try {
      final cross = await _crossref.lookupDoi(key);
      if (cross != null) {
        health = health.merge(
          CitationHealthClassifier.fromCrossrefRelations(
            retractedByRelation: cross.retractedByRelation,
          ),
        );
      }
    } catch (_) {}

    try {
      final updates = await _crossref.updatesFor(key);
      health = health.merge(_fromUpdates(updates));
    } catch (_) {}

    _cache[key] = health;
    return health;
  }

  Future<CitationMatch> enrich(CitationMatch match) async {
    final doi = match.doi;
    if (doi == null || doi.trim().isEmpty) return match;
    if (match.status != CitationValidationStatus.verified &&
        match.status != CitationValidationStatus.partial) {
      return match;
    }

    final health = await forDoi(doi);
    if (!health.hasAnyNotice) return match.copyWith(health: health);

    final extra = health.detailNote();
    final note = [
      if (match.note != null && match.note!.trim().isNotEmpty) match.note,
      extra,
    ].whereType<String>().join(' — ');
    return match.copyWith(health: health, note: note);
  }

  CitationHealthSnapshot snapshot(CitationCheckReport report) {
    var retracted = 0;
    var concern = 0;
    var corrected = 0;
    final titles = <String>[];
    for (final item in report.items) {
      final health = item.match?.health;
      if (health == null || !health.hasAnyNotice) continue;
      final title = item.match!.matchedTitle.trim().isNotEmpty
          ? item.match!.matchedTitle.trim()
          : item.citation.titleGuess;
      if (health.isRetracted) {
        retracted++;
        if (title.isNotEmpty) titles.add(title);
      } else if (health.hasExpressionOfConcern) {
        concern++;
        if (title.isNotEmpty) titles.add(title);
      } else if (health.hasCorrection) {
        corrected++;
      }
    }
    return CitationHealthSnapshot(
      checked: report.total,
      verified: report.verifiedCount,
      retracted: retracted,
      concern: concern,
      corrected: corrected,
      integrityScore: report.integrityScore,
      seriousTitles: titles.take(8).toList(),
    );
  }

  List<CitationHealthAlert> alerts(CitationCheckReport report) {
    final out = <CitationHealthAlert>[];
    for (final item in report.items) {
      final match = item.match;
      final health = match?.health;
      if (match == null || health == null || !health.hasAnyNotice) continue;
      final title = match.matchedTitle.trim().isNotEmpty
          ? match.matchedTitle.trim()
          : item.citation.titleGuess;
      out.add(
        CitationHealthAlert(
          kind: health.isRetracted || health.hasExpressionOfConcern
              ? 'error'
              : 'gap',
          quote: title,
          comment: health.examinerComment(title: title, doi: match.doi),
          question: health.examinerQuestion(title: title, doi: match.doi),
        ),
      );
    }
    return out;
  }

  CitationHealth _fromUpdates(List<CrossrefUpdateNotice> updates) {
    if (updates.isEmpty) return CitationHealth.empty;
    return CitationHealth(
      notices: updates.map((u) {
        final kind = CitationHealthClassifier.classify(
          '${u.type} ${u.label ?? ''}',
        );
        return CitationNotice(
          kind: kind,
          source: 'Crossref',
          noticeDoi: u.noticeDoi,
          label: (u.label != null && u.label!.isNotEmpty) ? u.label : u.type,
          year: u.year,
        );
      }).where((n) => n.kind != CitationNoticeKind.other).toList(),
    );
  }
}
