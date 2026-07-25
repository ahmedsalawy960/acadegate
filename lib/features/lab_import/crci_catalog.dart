import 'csv_lab_parser.dart';

/// Lightweight catalog of CRCI national research centers
/// (مجلس المراكز والمعاهد والهيئات البحثية — crci.sci.eg).
///
/// Institutional directory only — not a device bank like NBSLE.
class CrciCatalog {
  CrciCatalog._();

  static const portalUrl = 'http://www.crci.sci.eg/';
  static const directoryUrl = 'http://www.crci.sci.eg/?page_id=815';
  static const affiliationAr =
      'مجلس المراكز والمعاهد والهيئات البحثية (CRCI)';
  static const affiliationShortAr = 'مراكز CRCI القومية';

  /// Curated list (stable ids) for upsert into Firestore labs.
  static const centers = <CrciCenter>[
    CrciCenter(
      id: 'nrc',
      nameAr: 'المركز القومي للبحوث',
      nameEn: 'National Research Centre',
      city: 'القاهرة',
      website: 'https://www.nrc.sci.eg/',
      focusAr: 'بحوث علمية وتطبيقية متعددة التخصصات',
      focusEn: 'Multidisciplinary scientific and applied research',
      facultyId: 'Science',
    ),
    CrciCenter(
      id: 'niof',
      nameAr: 'المعهد القومي لعلوم البحار والمصايد',
      nameEn: 'National Institute of Oceanography and Fisheries',
      city: 'الإسكندرية',
      website: 'https://www.niof.sci.eg/',
      focusAr: 'علوم البحار والمصايد والبيئة البحرية',
      focusEn: 'Oceanography, fisheries and marine environment',
      facultyId: 'Science',
    ),
    CrciCenter(
      id: 'tbri',
      nameAr: 'معهد تيودور بلهارس للأبحاث',
      nameEn: 'Theodor Bilharz Research Institute',
      city: 'الجيزة',
      website: 'https://www.tbri.sci.eg/',
      focusAr: 'بحوث أمراض الكبد والطفيليات والصحة العامة',
      focusEn: 'Hepatic, parasitic and public health research',
      facultyId: 'Medicine',
    ),
    CrciCenter(
      id: 'rior',
      nameAr: 'معهد بحوث أمراض العيون',
      nameEn: 'Research Institute of Ophthalmology',
      city: 'الجيزة',
      website: 'https://www.rio.sci.eg/',
      focusAr: 'بحوث طب العيون والإبصار',
      focusEn: 'Ophthalmology and vision research',
      facultyId: 'Medicine',
    ),
    CrciCenter(
      id: 'epri',
      nameAr: 'معهد بحوث البترول',
      nameEn: 'Egyptian Petroleum Research Institute',
      city: 'القاهرة',
      website: 'https://www.epri.sci.eg/',
      focusAr: 'بحوث البترول والطاقة والكيماويات',
      focusEn: 'Petroleum, energy and chemical research',
      facultyId: 'Engineering',
    ),
    CrciCenter(
      id: 'eri',
      nameAr: 'معهد بحوث الإلكترونيات',
      nameEn: 'Electronics Research Institute',
      city: 'القاهرة',
      website: 'https://www.eri.sci.eg/',
      focusAr: 'الإلكترونيات والاتصالات والأنظمة الذكية',
      focusEn: 'Electronics, communications and smart systems',
      facultyId: 'Engineering',
    ),
    CrciCenter(
      id: 'cmrdi',
      nameAr: 'مركز بحوث وتطوير الفلزات',
      nameEn: 'Central Metallurgical Research and Development Institute',
      city: 'حلوان',
      website: 'https://www.cmrdi.sci.eg/',
      focusAr: 'بحوث الفلزات والمواد والصناعات المعدنية',
      focusEn: 'Metallurgy, materials and metal industries',
      facultyId: 'Engineering',
    ),
    CrciCenter(
      id: 'srtacity',
      nameAr: 'مدينة الأبحاث العلمية والتطبيقات التكنولوجية',
      nameEn: 'City of Scientific Research and Technological Applications',
      city: 'برج العرب',
      website: 'https://www.srtacity.sci.eg/',
      focusAr: 'بحوث تطبيقية وتكنولوجيا وابتكار',
      focusEn: 'Applied research, technology and innovation',
      facultyId: 'Science',
    ),
    CrciCenter(
      id: 'narss',
      nameAr: 'الهيئة القومية للاستشعار من البعد وعلوم الفضاء',
      nameEn: 'National Authority for Remote Sensing and Space Sciences',
      city: 'القاهرة',
      website: 'https://www.narss.sci.eg/',
      focusAr: 'الاستشعار عن بعد وعلوم الفضاء',
      focusEn: 'Remote sensing and space sciences',
      facultyId: 'Science',
    ),
    CrciCenter(
      id: 'nis',
      nameAr: 'المعهد القومي للمعايرة',
      nameEn: 'National Institute of Standards',
      city: 'الجيزة',
      website: 'https://www.nis.sci.eg/',
      focusAr: 'المعايرة والقياس والمعايير الوطنية',
      focusEn: 'Metrology, measurement and national standards',
      facultyId: 'Science',
    ),
    CrciCenter(
      id: 'nriag',
      nameAr: 'المعهد القومي للبحوث الفلكية والجيوفيزيقية',
      nameEn: 'National Research Institute of Astronomy and Geophysics',
      city: 'حلوان',
      website: 'https://www.nriag.sci.eg/',
      focusAr: 'الفلك والجيوفيزياء والزلازل',
      focusEn: 'Astronomy, geophysics and seismology',
      facultyId: 'Science',
    ),
  ];

  /// Build CSV-ready rows for [LabImportService].
  static List<CsvLabRow> toCsvRows() {
    return centers.map((c) => c.toCsvRow()).toList();
  }
}

class CrciCenter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String city;
  final String website;
  final String focusAr;
  final String focusEn;
  final String facultyId;

  const CrciCenter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.city,
    required this.website,
    required this.focusAr,
    required this.focusEn,
    required this.facultyId,
  });

  CsvLabRow toCsvRow() {
    return CsvLabRow(
      name: nameAr,
      university: CrciCatalog.affiliationAr,
      city: city,
      location: '$nameEn — $city',
      labType: 'research_center',
      category: facultyId,
      description:
          '$focusAr\n$focusEn\n\n'
          'تابع لمجلس المراكز والمعاهد والهيئات البحثية (CRCI) — '
          'وزارة التعليم العالي والبحث العلمي.\n'
          'الدليل: ${CrciCatalog.directoryUrl}\n'
          'الموقع: $website',
      tags: const ['CRCI', 'مركز قومي', 'مصر', 'research_center'],
      sampleServices: const [],
      equipmentNames: const [],
      acceptsExternalSamples: true,
      importSource: 'crci',
      sourceUrl: website.isNotEmpty ? website : CrciCatalog.directoryUrl,
      externalId: id,
      contactEmail: '',
      contactPhone: '',
      contactName: '',
    );
  }
}
