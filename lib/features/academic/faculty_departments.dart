import 'faculty_categories.dart';

/// Department / قسم inside a faculty. Search terms are English scholarly labels
/// used to keep literature inside that discipline.
class FacultyDepartment {
  final String id;
  final String facultyId;
  final String titleAr;
  final String titleEn;
  final List<String> searchTerms;
  final List<String> matchHints;

  const FacultyDepartment({
    required this.id,
    required this.facultyId,
    required this.titleAr,
    required this.titleEn,
    this.searchTerms = const [],
    this.matchHints = const [],
  });
}

class FacultyDepartments {
  FacultyDepartments._();

  static const englishFacultyTitle = <String, String>{
    'Engineering': 'Faculty of Engineering',
    'Science': 'Faculty of Science',
    'Medicine': 'Faculty of Medicine',
    'Dentistry': 'Faculty of Dentistry',
    'Pharmacy': 'Faculty of Pharmacy',
    'Nursing': 'Faculty of Nursing',
    'Veterinary': 'Faculty of Veterinary Medicine',
    'Law': 'Faculty of Law',
    'CS': 'Faculty of Computer Science',
    'Agriculture': 'Faculty of Agriculture',
    'Business': 'Faculty of Commerce',
    'Education': 'Faculty of Education',
    'Arts': 'Faculty of Arts',
    'Architecture': 'Faculty of Architecture',
    'MassCommunication': 'Faculty of Media',
    'Tourism': 'Faculty of Tourism and Hotels',
    'PhysicalEducation': 'Faculty of Physical Education',
    'FineArts': 'Faculty of Fine Arts',
    'ProfessionalStudies': 'Professional postgraduate studies',
  };

  /// Near-miss fields that steal hits for this faculty.
  static const alienHints = <String, List<String>>{
    'Agriculture': [
      'organic synthesis',
      'analytical chemistry chromatography',
      'clinical medicine',
      'mechanical engineering',
      'computer science',
      'literary criticism',
      'constitutional law',
      'tesol',
      'postcolonial',
      'imperialism',
      'pulmonary disease',
      'allergology',
      'powder diffraction',
      'political texts',
      'acm computing',
      'critical inquiry',
      'social-semiotic',
      'cognition and instruction',
    ],
    'Science': [
      'agronomy',
      'plant breeding',
      'crop science',
      'agricultural economics',
      'extension education',
      'clinical trial',
      'nursing',
      'pedagogy',
      'literary criticism',
      'tesol',
      'postcolonial',
      'imperialism',
      'pulmonary disease',
      'allergology',
      'political texts',
      'acm computing',
      'critical inquiry',
      'social-semiotic',
    ],
    'Engineering': [
      'agronomy',
      'plant breeding',
      'clinical trial',
      'literary criticism',
      'nursing education',
    ],
    'Medicine': [
      'agronomy',
      'crop science',
      'mechanical engineering',
      'civil engineering',
      'literary criticism',
    ],
    'Pharmacy': [
      'plant breeding',
      'agronomy',
      'civil engineering',
      'literary criticism',
    ],
    'Nursing': [
      'organic chemistry',
      'mechanical engineering',
      'agronomy',
    ],
    'Veterinary': [
      'human clinical trial',
      'civil engineering',
      'literary criticism',
    ],
    'Dentistry': [
      'agronomy',
      'plant breeding',
      'literary criticism',
    ],
    'CS': [
      'agronomy',
      'organic chemistry',
      'clinical medicine',
      'literary criticism',
    ],
    'Law': [
      'analytical chemistry',
      'agronomy',
      'mechanical engineering',
      'clinical trial',
    ],
    'Arts': [
      'analytical chemistry',
      'chromatography',
      'mechanical engineering',
      'agronomy',
      'clinical trial',
    ],
    'Education': [
      'organic synthesis',
      'mechanical engineering',
      'clinical trial',
      'crop breeding',
    ],
    'Business': [
      'organic chemistry',
      'plant breeding',
      'clinical medicine',
      'literary criticism',
    ],
    'Architecture': [
      'agronomy',
      'clinical medicine',
      'organic chemistry',
    ],
    'MassCommunication': [
      'analytical chemistry',
      'agronomy',
      'mechanical engineering',
    ],
    'Tourism': [
      'organic chemistry',
      'clinical trial',
      'plant breeding',
    ],
    'PhysicalEducation': [
      'organic chemistry',
      'civil engineering',
      'literary criticism',
    ],
    'FineArts': [
      'analytical chemistry',
      'agronomy',
      'clinical medicine',
    ],
    'ProfessionalStudies': [
      'organic chemistry',
      'plant breeding',
      'clinical trial',
    ],
  };

  static List<FacultyDepartment> forFaculty(String facultyId) {
    return _all.where((d) => d.facultyId == facultyId).toList();
  }

  static FacultyDepartment? byId(String facultyId, String departmentId) {
    for (final d in forFaculty(facultyId)) {
      if (d.id == departmentId) return d;
    }
    return null;
  }

  static FacultyDepartment? match(String facultyId, String text) {
    final hay = text.trim().toLowerCase();
    if (hay.isEmpty) return null;
    FacultyDepartment? best;
    var bestHits = 0;
    for (final d in forFaculty(facultyId)) {
      var hits = 0;
      for (final hint in [
        d.titleAr,
        d.titleEn,
        ...d.matchHints,
        ...d.searchTerms,
      ]) {
        final h = hint.toLowerCase();
        if (h.length >= 3 && hay.contains(h)) hits++;
      }
      if (hits > bestHits) {
        bestHits = hits;
        best = d;
      }
    }
    return bestHits > 0 ? best : null;
  }

  static String facultyTitleEn(String facultyId) =>
      englishFacultyTitle[facultyId] ?? facultyId;

  static String facultyTitleAr(String facultyId) =>
      facultyById(facultyId)?.titleAr ?? facultyId;

  static const _all = <FacultyDepartment>[
    FacultyDepartment(
      id: 'analytical_chem',
      facultyId: 'Science',
      titleAr: 'الكيمياء التحليلية',
      titleEn: 'Analytical chemistry',
      searchTerms: ['analytical chemistry', 'chromatography', 'spectroscopy'],
      matchHints: ['تحليلية', 'analytical', 'hplc', 'gc-ms', 'كرومات'],
    ),
    FacultyDepartment(
      id: 'organic_chem',
      facultyId: 'Science',
      titleAr: 'الكيمياء العضوية',
      titleEn: 'Organic chemistry',
      searchTerms: ['organic chemistry', 'organic synthesis'],
      matchHints: ['عضوية', 'organic'],
    ),
    FacultyDepartment(
      id: 'inorganic_chem',
      facultyId: 'Science',
      titleAr: 'الكيمياء غير العضوية',
      titleEn: 'Inorganic chemistry',
      searchTerms: ['inorganic chemistry', 'coordination chemistry'],
      matchHints: ['غير عضوية', 'inorganic'],
    ),
    FacultyDepartment(
      id: 'physical_chem',
      facultyId: 'Science',
      titleAr: 'الكيمياء الفيزيائية',
      titleEn: 'Physical chemistry',
      searchTerms: ['physical chemistry', 'thermodynamics'],
      matchHints: ['فيزيائية', 'physical chemistry'],
    ),
    FacultyDepartment(
      id: 'biochem',
      facultyId: 'Science',
      titleAr: 'الكيمياء الحيوية',
      titleEn: 'Biochemistry',
      searchTerms: ['biochemistry', 'molecular biology'],
      matchHints: ['حيوية', 'biochem'],
    ),
    FacultyDepartment(
      id: 'chemistry',
      facultyId: 'Science',
      titleAr: 'الكيمياء',
      titleEn: 'Chemistry',
      searchTerms: ['chemistry'],
      matchHints: ['كيمياء', 'chemist'],
    ),
    FacultyDepartment(
      id: 'physics',
      facultyId: 'Science',
      titleAr: 'الفيزياء',
      titleEn: 'Physics',
      searchTerms: ['physics'],
      matchHints: ['فيزياء', 'physics'],
    ),
    FacultyDepartment(
      id: 'math',
      facultyId: 'Science',
      titleAr: 'الرياضيات',
      titleEn: 'Mathematics',
      searchTerms: ['mathematics'],
      matchHints: ['رياضيات', 'math'],
    ),
    FacultyDepartment(
      id: 'botany',
      facultyId: 'Science',
      titleAr: 'النبات',
      titleEn: 'Botany',
      searchTerms: ['botany', 'plant biology', 'plant physiology'],
      matchHints: ['نبات', 'botany', 'plant biology'],
    ),
    FacultyDepartment(
      id: 'zoology',
      facultyId: 'Science',
      titleAr: 'علم الحيوان',
      titleEn: 'Zoology',
      searchTerms: ['zoology', 'animal biology'],
      matchHints: ['حيوان', 'zoology'],
    ),
    FacultyDepartment(
      id: 'microbiology',
      facultyId: 'Science',
      titleAr: 'الميكروبيولوجيا',
      titleEn: 'Microbiology',
      searchTerms: ['microbiology'],
      matchHints: ['ميكروب', 'microbiol'],
    ),
    FacultyDepartment(
      id: 'geology',
      facultyId: 'Science',
      titleAr: 'الجيولوجيا',
      titleEn: 'Geology',
      searchTerms: ['geology'],
      matchHints: ['جيولوج', 'geology'],
    ),
    FacultyDepartment(
      id: 'agronomy',
      facultyId: 'Agriculture',
      titleAr: 'المحاصيل / الإنتاج النباتي',
      titleEn: 'Agronomy / plant production',
      searchTerms: ['agronomy', 'crop science', 'plant production'],
      matchHints: ['محاصيل', 'إنتاج نباتي', 'agronomy', 'crop'],
    ),
    FacultyDepartment(
      id: 'breeding',
      facultyId: 'Agriculture',
      titleAr: 'الوراثة وتربية النبات',
      titleEn: 'Plant breeding and genetics',
      searchTerms: ['plant breeding', 'crop genetics', 'domestication'],
      matchHints: ['تربية النبات', 'وراثة', 'breeding', 'domestication'],
    ),
    FacultyDepartment(
      id: 'horticulture',
      facultyId: 'Agriculture',
      titleAr: 'البساتين',
      titleEn: 'Horticulture',
      searchTerms: ['horticulture'],
      matchHints: ['بساتين', 'horticult'],
    ),
    FacultyDepartment(
      id: 'plant_path',
      facultyId: 'Agriculture',
      titleAr: 'أمراض النبات',
      titleEn: 'Plant pathology',
      searchTerms: ['plant pathology'],
      matchHints: ['أمراض النبات', 'patholog'],
    ),
    FacultyDepartment(
      id: 'soils',
      facultyId: 'Agriculture',
      titleAr: 'الأراضي والمياه',
      titleEn: 'Soils and water',
      searchTerms: ['soil science', 'soil chemistry'],
      matchHints: ['أراضي', 'تربة', 'soil'],
    ),
    FacultyDepartment(
      id: 'food_science',
      facultyId: 'Agriculture',
      titleAr: 'علوم الأغذية',
      titleEn: 'Food science',
      searchTerms: ['food science', 'food technology'],
      matchHints: ['أغذية', 'food science', 'food tech'],
    ),
    FacultyDepartment(
      id: 'agri_econ',
      facultyId: 'Agriculture',
      titleAr: 'الاقتصاد الزراعي',
      titleEn: 'Agricultural economics',
      searchTerms: ['agricultural economics'],
      matchHints: ['اقتصاد زراعي', 'agricultural economics'],
    ),
    FacultyDepartment(
      id: 'animal_prod',
      facultyId: 'Agriculture',
      titleAr: 'الإنتاج الحيواني',
      titleEn: 'Animal production',
      searchTerms: ['animal science', 'animal production'],
      matchHints: ['إنتاج حيواني', 'animal production'],
    ),
    FacultyDepartment(
      id: 'civil',
      facultyId: 'Engineering',
      titleAr: 'الهندسة المدنية',
      titleEn: 'Civil engineering',
      searchTerms: ['civil engineering'],
      matchHints: ['مدني', 'civil'],
    ),
    FacultyDepartment(
      id: 'mechanical',
      facultyId: 'Engineering',
      titleAr: 'الهندسة الميكانيكية',
      titleEn: 'Mechanical engineering',
      searchTerms: ['mechanical engineering'],
      matchHints: ['ميكانيك', 'mechanical'],
    ),
    FacultyDepartment(
      id: 'electrical',
      facultyId: 'Engineering',
      titleAr: 'الهندسة الكهربائية',
      titleEn: 'Electrical engineering',
      searchTerms: ['electrical engineering'],
      matchHints: ['كهرب', 'electrical'],
    ),
    FacultyDepartment(
      id: 'chemical_eng',
      facultyId: 'Engineering',
      titleAr: 'الهندسة الكيميائية',
      titleEn: 'Chemical engineering',
      searchTerms: ['chemical engineering', 'process engineering'],
      matchHints: ['كيميائية', 'chemical engineering', 'تكرير'],
    ),
    FacultyDepartment(
      id: 'industrial_eng',
      facultyId: 'Engineering',
      titleAr: 'الهندسة الصناعية',
      titleEn: 'Industrial engineering',
      searchTerms: ['industrial engineering'],
      matchHints: ['صناعية', 'industrial engineering'],
    ),
    FacultyDepartment(
      id: 'cs_general',
      facultyId: 'CS',
      titleAr: 'علوم الحاسب',
      titleEn: 'Computer science',
      searchTerms: ['computer science'],
      matchHints: ['حاسب', 'computer science'],
    ),
    FacultyDepartment(
      id: 'ai',
      facultyId: 'CS',
      titleAr: 'الذكاء الاصطناعي',
      titleEn: 'Artificial intelligence',
      searchTerms: ['artificial intelligence', 'machine learning'],
      matchHints: ['ذكاء', 'machine learning', 'ai'],
    ),
    FacultyDepartment(
      id: 'is',
      facultyId: 'CS',
      titleAr: 'نظم المعلومات',
      titleEn: 'Information systems',
      searchTerms: ['information systems'],
      matchHints: ['نظم معلومات', 'information systems'],
    ),
    FacultyDepartment(
      id: 'internal_med',
      facultyId: 'Medicine',
      titleAr: 'الباطنة',
      titleEn: 'Internal medicine',
      searchTerms: ['internal medicine', 'clinical medicine'],
      matchHints: ['باطنة', 'internal medicine'],
    ),
    FacultyDepartment(
      id: 'surgery',
      facultyId: 'Medicine',
      titleAr: 'الجراحة',
      titleEn: 'Surgery',
      searchTerms: ['surgery'],
      matchHints: ['جراحة', 'surgery'],
    ),
    FacultyDepartment(
      id: 'pediatrics',
      facultyId: 'Medicine',
      titleAr: 'طب الأطفال',
      titleEn: 'Pediatrics',
      searchTerms: ['pediatrics'],
      matchHints: ['أطفال', 'pediatr'],
    ),
    FacultyDepartment(
      id: 'public_health',
      facultyId: 'Medicine',
      titleAr: 'الصحة العامة',
      titleEn: 'Public health',
      searchTerms: ['public health', 'epidemiology'],
      matchHints: ['صحة عامة', 'public health', 'وبائ'],
    ),
    FacultyDepartment(
      id: 'pharmaceutics',
      facultyId: 'Pharmacy',
      titleAr: 'الصيدلانيات',
      titleEn: 'Pharmaceutics',
      searchTerms: ['pharmaceutics', 'drug delivery'],
      matchHints: ['صيدلانيات', 'pharmaceutic'],
    ),
    FacultyDepartment(
      id: 'pharmacognosy',
      facultyId: 'Pharmacy',
      titleAr: 'العقاقير',
      titleEn: 'Pharmacognosy',
      searchTerms: ['pharmacognosy', 'natural products chemistry'],
      matchHints: ['عقاقير', 'pharmacognosy'],
    ),
    FacultyDepartment(
      id: 'clinical_pharm',
      facultyId: 'Pharmacy',
      titleAr: 'الصيدلة الإكلينيكية',
      titleEn: 'Clinical pharmacy',
      searchTerms: ['clinical pharmacy'],
      matchHints: ['إكلينيك', 'clinical pharmacy'],
    ),
    FacultyDepartment(
      id: 'private_law',
      facultyId: 'Law',
      titleAr: 'القانون الخاص',
      titleEn: 'Private law',
      searchTerms: ['private law', 'civil law'],
      matchHints: ['خاص', 'private law', 'مدني'],
    ),
    FacultyDepartment(
      id: 'public_law',
      facultyId: 'Law',
      titleAr: 'القانون العام',
      titleEn: 'Public law',
      searchTerms: ['public law', 'constitutional law'],
      matchHints: ['عام', 'public law', 'دستوري'],
    ),
    FacultyDepartment(
      id: 'arabic_lit',
      facultyId: 'Arts',
      titleAr: 'اللغة العربية وآدابها',
      titleEn: 'Arabic language and literature',
      searchTerms: ['Arabic literature', 'Arabic linguistics'],
      matchHints: ['عربية', 'أدب عربي', 'arabic literature'],
    ),
    FacultyDepartment(
      id: 'english_lit',
      facultyId: 'Arts',
      titleAr: 'اللغة الإنجليزية وآدابها',
      titleEn: 'English language and literature',
      searchTerms: ['English literature', 'literary criticism'],
      matchHints: ['إنجليز', 'english literature'],
    ),
    FacultyDepartment(
      id: 'history',
      facultyId: 'Arts',
      titleAr: 'التاريخ',
      titleEn: 'History',
      searchTerms: ['history', 'historiography'],
      matchHints: ['تاريخ', 'history'],
    ),
    FacultyDepartment(
      id: 'geography',
      facultyId: 'Arts',
      titleAr: 'الجغرافيا',
      titleEn: 'Geography',
      searchTerms: ['geography'],
      matchHints: ['جغراف', 'geography'],
    ),
    FacultyDepartment(
      id: 'philosophy',
      facultyId: 'Arts',
      titleAr: 'الفلسفة',
      titleEn: 'Philosophy',
      searchTerms: ['philosophy'],
      matchHints: ['فلسفة', 'philosophy'],
    ),
    FacultyDepartment(
      id: 'sociology',
      facultyId: 'Arts',
      titleAr: 'علم الاجتماع',
      titleEn: 'Sociology',
      searchTerms: ['sociology'],
      matchHints: ['اجتماع', 'sociology'],
    ),
    FacultyDepartment(
      id: 'curricula',
      facultyId: 'Education',
      titleAr: 'المناهج وطرق التدريس',
      titleEn: 'Curriculum and instruction',
      searchTerms: ['curriculum', 'pedagogy', 'teacher education'],
      matchHints: ['مناهج', 'تدريس', 'curriculum', 'pedagogy'],
    ),
    FacultyDepartment(
      id: 'ed_psych',
      facultyId: 'Education',
      titleAr: 'علم النفس التربوي',
      titleEn: 'Educational psychology',
      searchTerms: ['educational psychology'],
      matchHints: ['نفس تربوي', 'educational psychology'],
    ),
    FacultyDepartment(
      id: 'accounting',
      facultyId: 'Business',
      titleAr: 'المحاسبة',
      titleEn: 'Accounting',
      searchTerms: ['accounting'],
      matchHints: ['محاسب', 'accounting'],
    ),
    FacultyDepartment(
      id: 'management',
      facultyId: 'Business',
      titleAr: 'إدارة الأعمال',
      titleEn: 'Business administration',
      searchTerms: ['business administration', 'management'],
      matchHints: ['إدارة', 'management', 'business'],
    ),
    FacultyDepartment(
      id: 'economics',
      facultyId: 'Business',
      titleAr: 'الاقتصاد',
      titleEn: 'Economics',
      searchTerms: ['economics'],
      matchHints: ['اقتصاد', 'economics'],
    ),
    FacultyDepartment(
      id: 'architecture',
      facultyId: 'Architecture',
      titleAr: 'العمارة',
      titleEn: 'Architecture',
      searchTerms: ['architecture'],
      matchHints: ['عمارة', 'architecture'],
    ),
    FacultyDepartment(
      id: 'journalism',
      facultyId: 'MassCommunication',
      titleAr: 'الصحافة',
      titleEn: 'Journalism',
      searchTerms: ['journalism'],
      matchHints: ['صحافة', 'journalism'],
    ),
    FacultyDepartment(
      id: 'broadcasting',
      facultyId: 'MassCommunication',
      titleAr: 'الإذاعة والتلفزيون',
      titleEn: 'Broadcasting',
      searchTerms: ['broadcasting', 'media studies'],
      matchHints: ['إذاعة', 'تلفزيون', 'broadcast'],
    ),
    FacultyDepartment(
      id: 'nursing_gen',
      facultyId: 'Nursing',
      titleAr: 'التمريض',
      titleEn: 'Nursing',
      searchTerms: ['nursing'],
      matchHints: ['تمريض', 'nursing'],
    ),
    FacultyDepartment(
      id: 'vet_med',
      facultyId: 'Veterinary',
      titleAr: 'الطب البيطري',
      titleEn: 'Veterinary medicine',
      searchTerms: ['veterinary medicine'],
      matchHints: ['بيطر', 'veterinar'],
    ),
    FacultyDepartment(
      id: 'dentistry',
      facultyId: 'Dentistry',
      titleAr: 'طب الأسنان',
      titleEn: 'Dentistry',
      searchTerms: ['dentistry'],
      matchHints: ['أسنان', 'dentist'],
    ),
    FacultyDepartment(
      id: 'tourism',
      facultyId: 'Tourism',
      titleAr: 'السياحة',
      titleEn: 'Tourism studies',
      searchTerms: ['tourism'],
      matchHints: ['سياح', 'tourism'],
    ),
    FacultyDepartment(
      id: 'pe',
      facultyId: 'PhysicalEducation',
      titleAr: 'التربية الرياضية',
      titleEn: 'Physical education',
      searchTerms: ['physical education', 'sports science'],
      matchHints: ['رياضة', 'physical education', 'sport'],
    ),
    FacultyDepartment(
      id: 'fine_arts',
      facultyId: 'FineArts',
      titleAr: 'الفنون الجميلة',
      titleEn: 'Fine arts',
      searchTerms: ['fine arts', 'art criticism'],
      matchHints: ['فنون', 'fine art'],
    ),
    FacultyDepartment(
      id: 'professional',
      facultyId: 'ProfessionalStudies',
      titleAr: 'دراسات مهنية',
      titleEn: 'Professional studies',
      searchTerms: ['professional education', 'public administration'],
      matchHints: ['مهني', 'mba', 'mpa'],
    ),
  ];
}
