/// Suggested professional postgraduate programs for AcadeGate.
/// Curated from common Egyptian / Arab university offerings
/// (MBA, DBA, MPA, postgraduate diplomas, etc.).
enum ProfessionalProgramKind { masters, doctorate, diploma }

class ProfessionalProgramSuggestion {
  final String id;
  final String abbr;
  final String titleAr;
  final String titleEn;
  final ProfessionalProgramKind kind;
  final String summaryAr;
  final String summaryEn;
  final List<String> focusAreasAr;
  final List<String> focusAreasEn;
  /// Optional nearest traditional faculty for cross-linking supervisors.
  final String? relatedFacultyId;

  const ProfessionalProgramSuggestion({
    required this.id,
    required this.abbr,
    required this.titleAr,
    required this.titleEn,
    required this.kind,
    required this.summaryAr,
    required this.summaryEn,
    this.focusAreasAr = const [],
    this.focusAreasEn = const [],
    this.relatedFacultyId,
  });
}

const professionalProgramsCatalog = <ProfessionalProgramSuggestion>[
  // ─── Professional master's ─────────────────────────────
  ProfessionalProgramSuggestion(
    id: 'mba',
    abbr: 'MBA',
    titleAr: 'الماجستير المهني في إدارة الأعمال',
    titleEn: 'Master of Business Administration',
    kind: ProfessionalProgramKind.masters,
    summaryAr:
        'أشهر مسار مهني للترقي الإداري. يركّز على دراسات حالة ومهارات قيادية '
        'وتطبيق عملي أكثر من البحث النظري. غالباً يشترط خبرة عملية (حوالي عامين).',
    summaryEn:
        'The most common professional management path. Emphasizes case studies, '
        'leadership, and applied skills over pure research. Often requires ~2 years of work experience.',
    focusAreasAr: [
      'إدارة عامة',
      'تسويق',
      'تمويل',
      'موارد بشرية',
      'عمليات',
    ],
    focusAreasEn: [
      'General management',
      'Marketing',
      'Finance',
      'HR',
      'Operations',
    ],
    relatedFacultyId: 'Business',
  ),
  ProfessionalProgramSuggestion(
    id: 'emba',
    abbr: 'EMBA',
    titleAr: 'الماجستير المهني التنفيذي في إدارة الأعمال',
    titleEn: 'Executive MBA',
    kind: ProfessionalProgramKind.masters,
    summaryAr:
        'موجّه للمديرين التنفيذيين وذوي الخبرة المتقدمة. جداول مرنة غالباً '
        '(عطلات نهاية الأسبوع) مع تركيز على الاستراتيجية والقيادة العليا.',
    summaryEn:
        'Designed for senior managers. Flexible schedules (often weekends) '
        'with focus on strategy and executive leadership.',
    focusAreasAr: ['قيادة تنفيذية', 'استراتيجية', 'حوكمة'],
    focusAreasEn: ['Executive leadership', 'Strategy', 'Governance'],
    relatedFacultyId: 'Business',
  ),
  ProfessionalProgramSuggestion(
    id: 'mpa_public',
    abbr: 'MPA',
    titleAr: 'الماجستير المهني في الإدارة العامة',
    titleEn: 'Master of Public Administration',
    kind: ProfessionalProgramKind.masters,
    summaryAr:
        'للعاملين في القطاع العام والسياسات العامة والمنظمات الدولية. يغطّي '
        'إدارة حكومية، سياسات عامة، ومالية عامة.',
    summaryEn:
        'For public-sector and policy professionals. Covers public management, '
        'policy, and public finance.',
    focusAreasAr: ['سياسات عامة', 'إدارة حكومية', 'مالية عامة'],
    focusAreasEn: ['Public policy', 'Government management', 'Public finance'],
    relatedFacultyId: 'Business',
  ),
  ProfessionalProgramSuggestion(
    id: 'mpa_accounting',
    abbr: 'MPA',
    titleAr: 'الماجستير المهني في المحاسبة',
    titleEn: 'Professional Master of Accounting',
    kind: ProfessionalProgramKind.masters,
    summaryAr:
        'شائع في كليات التجارة والأكاديميات الإدارية في مصر. تخصصات مثل '
        'محاسبة مالية، مراجعة، تكاليف، ضرائب، ومحاسبة قضائية.',
    summaryEn:
        'Common in Egyptian commerce faculties. Tracks include financial '
        'accounting, audit, costing, tax, and forensic accounting.',
    focusAreasAr: [
      'محاسبة مالية',
      'مراجعة',
      'تكاليف',
      'ضرائب',
      'قضائية',
    ],
    focusAreasEn: [
      'Financial accounting',
      'Audit',
      'Costing',
      'Tax',
      'Forensic',
    ],
    relatedFacultyId: 'Business',
  ),
  ProfessionalProgramSuggestion(
    id: 'mha',
    abbr: 'MHA',
    titleAr: 'الماجستير المهني في إدارة الرعاية الصحية',
    titleEn: 'Master of Healthcare Administration',
    kind: ProfessionalProgramKind.masters,
    summaryAr:
        'لإدارة المستشفيات والخدمات الصحية والجودة الطبية — مسار مهني متنامٍ '
        'في مصر والخليج.',
    summaryEn:
        'For hospital and health-services management — a growing professional '
        'track in Egypt and the Gulf.',
    focusAreasAr: ['إدارة مستشفيات', 'جودة صحية', 'خدمات طبية'],
    focusAreasEn: ['Hospital management', 'Quality', 'Health services'],
    relatedFacultyId: 'Medicine',
  ),
  ProfessionalProgramSuggestion(
    id: 'mpm',
    abbr: 'MPM',
    titleAr: 'الماجستير المهني في إدارة المشروعات',
    titleEn: 'Master of Project Management',
    kind: ProfessionalProgramKind.masters,
    summaryAr:
        'يلائم المهندسين والمديرين العاملين على مشروعات كبيرة: تخطيط، مخاطر، '
        'تكلفة، وPMP-oriented skills.',
    summaryEn:
        'Suited to engineers and managers on large projects: planning, risk, '
        'cost, and PMP-oriented skills.',
    focusAreasAr: ['تخطيط', 'مخاطر', 'تكلفة', 'جداول زمنية'],
    focusAreasEn: ['Planning', 'Risk', 'Cost', 'Scheduling'],
    relatedFacultyId: 'Engineering',
  ),
  ProfessionalProgramSuggestion(
    id: 'mph',
    abbr: 'MPH',
    titleAr: 'الماجستير المهني في الصحة العامة',
    titleEn: 'Master of Public Health',
    kind: ProfessionalProgramKind.masters,
    summaryAr:
        'يربط الطب والإحصاء والسياسات الصحية: وبائيات، صحة مجتمع، وإدارة برامج صحية.',
    summaryEn:
        'Bridges medicine, statistics, and health policy: epidemiology, '
        'community health, and program management.',
    focusAreasAr: ['وبائيات', 'صحة مجتمع', 'سياسات صحية'],
    focusAreasEn: ['Epidemiology', 'Community health', 'Health policy'],
    relatedFacultyId: 'Medicine',
  ),
  ProfessionalProgramSuggestion(
    id: 'mis',
    abbr: 'MIS',
    titleAr: 'الماجستير المهني في نظم المعلومات الإدارية',
    titleEn: 'Master of Information Systems',
    kind: ProfessionalProgramKind.masters,
    summaryAr:
        'يجمع بين الإدارة وتقنية المعلومات: تحليل نظم، ذكاء أعمال، وتحوّل رقمي.',
    summaryEn:
        'Combines management and IT: systems analysis, business intelligence, '
        'and digital transformation.',
    focusAreasAr: ['ذكاء أعمال', 'تحليل نظم', 'تحوّل رقمي'],
    focusAreasEn: ['BI', 'Systems analysis', 'Digital transformation'],
    relatedFacultyId: 'CS',
  ),

  // ─── Professional doctorates ───────────────────────────
  ProfessionalProgramSuggestion(
    id: 'dba',
    abbr: 'DBA',
    titleAr: 'الدكتوراه المهنية في إدارة الأعمال',
    titleEn: 'Doctor of Business Administration',
    kind: ProfessionalProgramKind.doctorate,
    summaryAr:
        'أعلى درجة مهنية في إدارة الأعمال. بحث تطبيقي يحل مشكلة تنظيمية حقيقية، '
        'مناسب للمستشارين والمديرين الكبار (يختلف عن PhD الأكاديمي).',
    summaryEn:
        'Top professional doctorate in business. Applied research on real '
        'organizational problems — distinct from an academic PhD.',
    focusAreasAr: ['قيادة', 'استراتيجية', 'بحث تطبيقي'],
    focusAreasEn: ['Leadership', 'Strategy', 'Applied research'],
    relatedFacultyId: 'Business',
  ),
  ProfessionalProgramSuggestion(
    id: 'dpa',
    abbr: 'DPA',
    titleAr: 'الدكتوراه المهنية في الإدارة العامة',
    titleEn: 'Doctor of Public Administration',
    kind: ProfessionalProgramKind.doctorate,
    summaryAr:
        'مسار مهني رفيع لقيادات القطاع العام والسياسات. يركّز على تطبيق المعرفة '
        'في الحوكمة والإدارة الحكومية.',
    summaryEn:
        'Senior professional track for public-sector leaders. Emphasizes '
        'applied governance and public management.',
    focusAreasAr: ['حوكمة', 'سياسات', 'إدارة عامة'],
    focusAreasEn: ['Governance', 'Policy', 'Public management'],
    relatedFacultyId: 'Business',
  ),
  ProfessionalProgramSuggestion(
    id: 'edd',
    abbr: 'EdD',
    titleAr: 'الدكتوراه المهنية في التربية',
    titleEn: 'Doctor of Education',
    kind: ProfessionalProgramKind.doctorate,
    summaryAr:
        'للقيادات التربوية والإشراف التعليمي. تطبيق عملي في المناهج، الإدارة '
        'التربوية، أو التربية الخاصة — أقرب للممارسة من PhD التربية.',
    summaryEn:
        'For education leaders. Applied work in curriculum, educational '
        'administration, or special education — more practice-oriented than a PhD.',
    focusAreasAr: ['إدارة تربوية', 'مناهج', 'تربية خاصة'],
    focusAreasEn: [
      'Educational admin',
      'Curriculum',
      'Special education',
    ],
    relatedFacultyId: 'Education',
  ),
  ProfessionalProgramSuggestion(
    id: 'dnp',
    abbr: 'DNP',
    titleAr: 'دكتوراه ممارسة التمريض',
    titleEn: 'Doctor of Nursing Practice',
    kind: ProfessionalProgramKind.doctorate,
    summaryAr:
        'درجة مهنية سريرية للتمريض المتقدم وجودة الرعاية — مسار مهني عالمي '
        'يتوسع تدريجياً في المنطقة.',
    summaryEn:
        'Clinical professional doctorate for advanced nursing practice and '
        'care quality — growing regionally.',
    focusAreasAr: ['تمريض متقدم', 'جودة رعاية', 'قيادة سريرية'],
    focusAreasEn: [
      'Advanced nursing',
      'Care quality',
      'Clinical leadership',
    ],
    relatedFacultyId: 'Nursing',
  ),

  // ─── Important postgraduate diplomas ───────────────────
  ProfessionalProgramSuggestion(
    id: 'dip_business',
    abbr: 'PGDip',
    titleAr: 'دبلوم دراسات عليا في إدارة الأعمال / العلوم الإدارية',
    titleEn: 'Postgraduate Diploma in Business / Management',
    kind: ProfessionalProgramKind.diploma,
    summaryAr:
        'جسر شائع بين البكالوريوس والماجستير المهني. تخصصات مثل موارد بشرية، '
        'تسويق، استثمار وتمويل، وإدارة مستشفيات.',
    summaryEn:
        'Common bridge from bachelor’s to professional master’s. Tracks include '
        'HR, marketing, investment/finance, and hospital management.',
    focusAreasAr: [
      'موارد بشرية',
      'تسويق',
      'تمويل',
      'مستشفيات',
    ],
    focusAreasEn: ['HR', 'Marketing', 'Finance', 'Hospitals'],
    relatedFacultyId: 'Business',
  ),
  ProfessionalProgramSuggestion(
    id: 'dip_education',
    abbr: 'PGDip',
    titleAr: 'دبلومات التربية (عام / مهني / خاص)',
    titleEn: 'Education Postgraduate Diplomas',
    kind: ProfessionalProgramKind.diploma,
    summaryAr:
        'أساسية للمعلمين والتأهيل التربوي: صحة نفسية، مناهج، إدارة تربوية، '
        'وتربية خاصة. غالباً شرط للترقي أو الالتحاق بماجستير التربية.',
    summaryEn:
        'Core for teachers: mental health, curriculum, educational admin, '
        'special education. Often required for promotion or MEd entry.',
    focusAreasAr: [
      'صحة نفسية',
      'مناهج',
      'إدارة تربوية',
      'تربية خاصة',
    ],
    focusAreasEn: [
      'Mental health',
      'Curriculum',
      'Ed. admin',
      'Special ed.',
    ],
    relatedFacultyId: 'Education',
  ),
  ProfessionalProgramSuggestion(
    id: 'dip_law',
    abbr: 'PGDip',
    titleAr: 'دبلومات الحقوق والدبلومات المهنية القانونية',
    titleEn: 'Law & Legal Professional Diplomas',
    kind: ProfessionalProgramKind.diploma,
    summaryAr:
        'دبلومات تقليدية (قانون عام/خاص، جنائي، دولي…) بالإضافة لمسارات مهنية '
        'مثل التحكيم وعقود الإنشاءات والقانون الطبي.',
    summaryEn:
        'Traditional law diplomas (public/private, criminal, international) '
        'plus professional tracks like arbitration and construction contracts.',
    focusAreasAr: ['تحكيم', 'قانون عام', 'جنائي', 'تجارة دولية'],
    focusAreasEn: [
      'Arbitration',
      'Public law',
      'Criminal',
      'Intl. trade',
    ],
    relatedFacultyId: 'Law',
  ),
  ProfessionalProgramSuggestion(
    id: 'dip_cs',
    abbr: 'PGDip',
    titleAr: 'دبلوم مهني في الحاسبات والذكاء الاصطناعي',
    titleEn: 'Professional Diploma in Computing & AI',
    kind: ProfessionalProgramKind.diploma,
    summaryAr:
        'برامج حديثة بمصروفات/ساعات معتمدة: ذكاء اصطناعي تطبيقي، ذكاء أعمال، '
        'ومعلوماتية طبية — مناسبة لغير المتخصصين أو للتخصص السريع.',
    summaryEn:
        'Modern credit-hour programs: applied AI, business intelligence, '
        'medical informatics — for career switchers or rapid upskilling.',
    focusAreasAr: ['ذكاء اصطناعي', 'ذكاء أعمال', 'معلوماتية طبية'],
    focusAreasEn: ['Applied AI', 'BI', 'Medical informatics'],
    relatedFacultyId: 'CS',
  ),
  ProfessionalProgramSuggestion(
    id: 'dip_quality',
    abbr: 'PGDip',
    titleAr: 'دبلوم مهني في إدارة الجودة',
    titleEn: 'Professional Diploma in Quality Management',
    kind: ProfessionalProgramKind.diploma,
    summaryAr:
        'مطلوب في الصناعة والخدمات الصحية والتصنيع: نظم جودة، اعتماد، وتحسين مستمر.',
    summaryEn:
        'In demand across industry and healthcare: quality systems, accreditation, '
        'and continuous improvement.',
    focusAreasAr: ['ISO', 'اعتماد', 'تحسين مستمر'],
    focusAreasEn: ['ISO', 'Accreditation', 'Continuous improvement'],
    relatedFacultyId: 'Business',
  ),
  ProfessionalProgramSuggestion(
    id: 'dip_hr',
    abbr: 'PGDip',
    titleAr: 'دبلوم دراسات عليا في إدارة الموارد البشرية',
    titleEn: 'Postgraduate Diploma in Human Resources',
    kind: ProfessionalProgramKind.diploma,
    summaryAr:
        'مسار مهني سريع لوظائف HR: استقطاب، تدريب، أجور، وعلاقات عمل.',
    summaryEn:
        'Fast professional path into HR roles: recruitment, training, '
        'compensation, and employee relations.',
    focusAreasAr: ['استقطاب', 'تدريب', 'أجور', 'علاقات عمل'],
    focusAreasEn: [
      'Recruitment',
      'Training',
      'Compensation',
      'Labor relations',
    ],
    relatedFacultyId: 'Business',
  ),
];

List<ProfessionalProgramSuggestion> professionalProgramsByKind(
  ProfessionalProgramKind kind,
) {
  return professionalProgramsCatalog.where((p) => p.kind == kind).toList();
}
