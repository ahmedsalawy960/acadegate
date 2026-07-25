import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../../core/locale/app_translate.dart';
import 'sample_analysis_marketplace_listing.dart';

class SampleAnalysisMarketplaceService {
  SampleAnalysisMarketplaceService._();

  static final SampleAnalysisMarketplaceService instance =
      SampleAnalysisMarketplaceService._();

  static const maxVisibleListings = 80;
  static const maxVisibleListingsFocused = 400;

  Stream<List<AcademicLab>> labsStream() {
    return AcademicContentService.instance.labsStream();
  }

  /// Build marketplace rows. NBSLE labs without real services appear only when
  /// the user searches or filters (keeps the default list fast).
  List<SampleAnalysisListing> buildListings({
    required List<AcademicLab> labs,
    String query = '',
    String city = '',
    String facultyId = '',
  }) {
    final q = query.trim();
    final hasFocus =
        q.length >= 2 || facultyId.trim().isNotEmpty || city.trim().isNotEmpty;

    final priority = <SampleAnalysisListing>[];
    final deferred = <SampleAnalysisListing>[];

    for (final lab in labs) {
      if (!lab.isPubliclyVisible) continue;
      if (!lab.offersSampleAnalysis && !lab.acceptsExternalSamples) continue;

      if (lab.sampleServices.isNotEmpty &&
          lab.sampleServices.first.id != '_listed') {
        for (final service in lab.sampleServices) {
          priority.add(SampleAnalysisListing(lab: lab, service: service));
        }
        continue;
      }

      // Lightweight placeholder or empty services → synthetic listing.
      if (!lab.acceptsExternalSamples) continue;

      final synthetic = SampleAnalysisListing(
        lab: lab,
        service: SampleAnalysisService(
          id: 'general',
          name: appTr(
            'تحليل عينة — ${lab.name}',
            'Sample analysis — ${lab.name}',
          ),
          description: lab.description.isNotEmpty
              ? lab.description
              : appTr(
                  'تحليل عينات خارجية — تواصل مع المختبر لتحديد نوع التحليل',
                  'External sample analysis — contact the lab for analysis type',
                ),
          turnaroundDays: lab.minWaitDays,
          priceFrom: lab.minCost,
          specialties: lab.tags,
        ),
      );

      if (lab.isNbsleImport || lab.sampleServices.isEmpty || lab.sampleServices.first.id == '_listed') {
        if (!hasFocus) continue;
        if (deferred.length >= maxVisibleListings * 3) continue;
        deferred.add(synthetic);
      } else {
        priority.add(synthetic);
      }
    }

    var combined = [...priority, ...deferred];
    if (combined.length > maxVisibleListings * 3) {
      // Pre-cap before UI sort to keep UI responsive on huge NBSLE sets.
      combined = combined.take(maxVisibleListings * 3).toList();
    }
    return combined;
  }

  Stream<List<SampleAnalysisListing>> listingsStream() {
    return labsStream().map((labs) => buildListings(labs: labs));
  }

  List<SampleAnalysisListing> filterAndSort({
    required List<SampleAnalysisListing> listings,
    String query = '',
    String city = '',
    String facultyId = '',
    SampleMarketplaceSort sort = SampleMarketplaceSort.recommended,
  }) {
    var result = listings.where((item) {
      return item.matchesQuery(query) &&
          item.matchesCity(city) &&
          item.matchesFaculty(facultyId);
    }).toList();

    switch (sort) {
      case SampleMarketplaceSort.priceAsc:
        result.sort((a, b) {
          final pa = a.priceFrom <= 0 ? double.maxFinite : a.priceFrom.toDouble();
          final pb = b.priceFrom <= 0 ? double.maxFinite : b.priceFrom.toDouble();
          return pa.compareTo(pb);
        });
      case SampleMarketplaceSort.turnaroundAsc:
        result.sort((a, b) => a.turnaroundDays.compareTo(b.turnaroundDays));
      case SampleMarketplaceSort.ratingDesc:
        result.sort((a, b) => b.rating.compareTo(a.rating));
      case SampleMarketplaceSort.recommended:
        result.sort((a, b) {
          final rating = b.rating.compareTo(a.rating);
          if (rating != 0) return rating;
          return a.turnaroundDays.compareTo(b.turnaroundDays);
        });
    }

    return result;
  }

  List<String> citiesFrom(List<AcademicLab> labs) {
    return labs
        .map((item) => item.city.trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
