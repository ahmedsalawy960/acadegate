import '../academic/academic_models.dart';
import '../../core/locale/l10n_lookup.dart';
import '../supervisor_import/openalex_client.dart';
import 'scimago_quartile_service.dart';
import 'supervisor_metrics_models.dart';

class SupervisorMetricsService {
  SupervisorMetricsService._();

  static final SupervisorMetricsService instance = SupervisorMetricsService._();

  final _cache = <String, SupervisorPublicationMetrics>{};

  Future<SupervisorPublicationMetrics> loadMetrics(
    AcademicSupervisor supervisor,
  ) async {
    final cacheKey =
        supervisor.openAlexId.isNotEmpty
            ? supervisor.openAlexId
            : supervisor.orcid.isNotEmpty
            ? supervisor.orcid
            : supervisor.id ?? supervisor.name;

    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    if (!supervisor.hasPublicationIds) {
      final stored = _fromStoredFields(supervisor);
      if (stored.hasData) {
        _cache[cacheKey] = stored;
        return stored;
      }
      return SupervisorPublicationMetrics(
        sourceNote: L10nLookup.orcidMissingNote(),
      );
    }

    try {
      final authorRaw = await OpenAlexClient.instance.fetchAuthorRaw(
        openAlexId: supervisor.openAlexId.isNotEmpty
            ? supervisor.openAlexId
            : null,
        orcid: supervisor.orcid.isNotEmpty ? supervisor.orcid : null,
      );

      if (authorRaw == null) {
        return _fromStoredFields(supervisor);
      }

      final authorId = authorRaw['id']?.toString().replaceFirst(
            'https://openalex.org/',
            '',
          ) ??
          supervisor.openAlexId;

      final worksCount =
          (authorRaw['works_count'] as num?)?.toInt() ??
          supervisor.worksCount;
      final citedByCount =
          (authorRaw['cited_by_count'] as num?)?.toInt() ??
          supervisor.citedByCount;
      final summary = authorRaw['summary_stats'] as Map<String, dynamic>? ?? {};
      final hIndex = (summary['h_index'] as num?)?.toInt() ?? supervisor.hIndex;

      final works = await OpenAlexClient.instance.fetchAuthorWorks(
        openAlexId: authorId,
      );
      await ScimagoQuartileService.instance.ensureLoaded();
      final topVenues = await _aggregateVenues(works);
      final scimagoMatches = topVenues.where((v) => v.fromScimago).length;

      final metrics = SupervisorPublicationMetrics(
        worksCount: worksCount,
        citedByCount: citedByCount,
        hIndex: hIndex,
        topVenues: topVenues,
        fromOpenAlex: true,
        sourceNote: scimagoMatches > 0
            ? L10nLookup.openAlexScimagoNote(scimagoMatches)
            : L10nLookup.openAlexEstimateNote(),
      );

      _cache[cacheKey] = metrics;
      return metrics;
    } catch (_) {
      final fallback = _fromStoredFields(supervisor);
      if (fallback.hasData) {
        _cache[cacheKey] = fallback;
        return fallback;
      }
      return SupervisorPublicationMetrics(
        sourceNote: L10nLookup.publicationLoadFailed(),
      );
    }
  }

  SupervisorPublicationMetrics _fromStoredFields(AcademicSupervisor supervisor) {
    return SupervisorPublicationMetrics(
      worksCount: supervisor.worksCount,
      citedByCount: supervisor.citedByCount,
      hIndex: supervisor.hIndex,
      fromOpenAlex: supervisor.openAlexId.isNotEmpty,
      sourceNote: supervisor.hasStoredMetrics
          ? L10nLookup.storedImportMetricsNote()
          : '',
    );
  }

  Future<List<VenuePublicationStat>> _aggregateVenues(
    List<Map<String, dynamic>> works,
  ) async {
    final venueMap = <String, _VenueAccumulator>{};

    for (final work in works) {
      final location = work['primary_location'] as Map<String, dynamic>?;
      final source = location?['source'] as Map<String, dynamic>?;
      if (source == null) continue;

      final name = source['display_name']?.toString() ?? '';
      if (name.isEmpty) continue;

      final stats = source['summary_stats'] as Map<String, dynamic>? ?? {};
      final citedness =
          (stats['2yr_mean_citedness'] as num?)?.toDouble() ?? 0;
      final issns = _extractIssns(source);

      venueMap.putIfAbsent(name, () => _VenueAccumulator(name: name));
      final acc = venueMap[name]!;
      acc.count++;
      if (citedness > acc.maxCitedness) acc.maxCitedness = citedness;
      acc.issns.addAll(issns);
    }

    final scimago = ScimagoQuartileService.instance;
    final venues = venueMap.values
        .map((acc) {
          final scimagoInfo = scimago.lookup(
            issns: acc.issns.toList(),
            title: acc.name,
          );

          if (scimagoInfo != null) {
            return VenuePublicationStat(
              journalName: acc.name,
              worksCount: acc.count,
              citedness: acc.maxCitedness,
              tierLabel: 'Scimago ${scimagoInfo.quartile}',
              quartile: scimagoInfo.quartile,
              sjr: scimagoInfo.sjr,
              issn: acc.issns.isNotEmpty ? acc.issns.first : null,
              fromScimago: true,
            );
          }

          return VenuePublicationStat(
            journalName: acc.name,
            worksCount: acc.count,
            citedness: acc.maxCitedness,
            tierLabel: JournalTier.labelFromCitedness(acc.maxCitedness),
            issn: acc.issns.isNotEmpty ? acc.issns.first : null,
          );
        })
        .toList()
      ..sort((a, b) {
        final byWorks = b.worksCount.compareTo(a.worksCount);
        if (byWorks != 0) return byWorks;
        if (a.fromScimago != b.fromScimago) {
          return a.fromScimago ? -1 : 1;
        }
        return b.citedness.compareTo(a.citedness);
      });

    return venues.take(8).toList();
  }

  List<String> _extractIssns(Map<String, dynamic> source) {
    final issns = <String>[];
    final issnL = source['issn_l']?.toString();
    if (issnL != null && issnL.isNotEmpty) issns.add(issnL);

    final issnList = source['issn'];
    if (issnList is List) {
      for (final item in issnList) {
        final value = item?.toString() ?? '';
        if (value.isNotEmpty) issns.add(value);
      }
    }
    return issns;
  }
}

class _VenueAccumulator {
  final String name;
  int count = 0;
  double maxCitedness = 0;
  final Set<String> issns = {};

  _VenueAccumulator({required this.name});
}
