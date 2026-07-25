import '../academic/academic_models.dart';
import '../../core/locale/app_translate.dart';
import '../lab_import/nbsle_university_cities.dart';

/// A marketplace row: one analysis service offered by a lab or center.
class SampleAnalysisListing {
  final AcademicLab lab;
  final SampleAnalysisService service;

  const SampleAnalysisListing({
    required this.lab,
    required this.service,
  });

  String get id => '${lab.id ?? lab.name}_${service.id}';

  String get serviceName => service.name;

  String get labName => lab.name;

  String get city => lab.city;

  String get university => lab.university;

  num get priceFrom => service.priceFrom;

  int get turnaroundDays => service.turnaroundDays;

  double get rating => lab.ratingAvg;

  List<String> get sampleTypes => service.sampleTypes;

  List<String> get specialties => service.specialties.isNotEmpty
      ? service.specialties
      : (lab.category.isNotEmpty ? [lab.category] : lab.tags);

  bool get acceptsExternalSamples => lab.acceptsExternalSamples;

  String get locationLabel {
    if (city.isNotEmpty && university.isNotEmpty) {
      return '$university · $city';
    }
    return city.isNotEmpty ? city : university;
  }

  String get priceLabel {
    if (priceFrom <= 0) {
      return appTr('السعر عند الطلب', 'Price on request');
    }
    return appTr('من $priceFrom ج.م', 'From $priceFrom EGP');
  }

  String get turnaroundLabel => appTr(
        '$turnaroundDays ${turnaroundDays == 1 ? 'يوم' : 'أيام'}',
        '$turnaroundDays ${turnaroundDays == 1 ? 'day' : 'days'}',
      );

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final fields = [
      service.name,
      service.description,
      lab.name,
      lab.university,
      lab.city,
      lab.description,
      ...lab.tags,
      ...service.sampleTypes,
      ...service.specialties,
    ];
    return fields.any((field) => field.toLowerCase().contains(q));
  }

  bool matchesCity(String cityFilter) {
    if (cityFilter.isEmpty) return true;
    return NbsleUniversityCities.cityMatches(lab.city, cityFilter);
  }

  bool matchesFaculty(String facultyId) {
    if (facultyId.isEmpty) return true;
    return lab.matchesFaculty(facultyId);
  }
}

enum SampleMarketplaceSort {
  recommended,
  priceAsc,
  turnaroundAsc,
  ratingDesc,
}
