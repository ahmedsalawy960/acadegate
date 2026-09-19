/// Egyptian / Arab institutions offering professional postgraduate programs.
/// Curated for AcadeGate directory — partnership unlocks in-app applications.
enum InstitutionPartnershipStatus {
  /// Listed for discovery; apply via website for now.
  directoryOnly,

  /// AcadeGate partnership active — in-app application enabled.
  partnered,
}

class ProfessionalInstitution {
  final String id;
  final String nameAr;
  final String nameEn;
  final String typeAr;
  final String typeEn;
  final String city;
  final String website;
  final String email;
  final String phone;
  final List<String> programAbbrs;
  final String summaryAr;
  final String summaryEn;
  final InstitutionPartnershipStatus partnershipStatus;
  /// External admissions page when not partnered (or as fallback).
  final String? admissionsUrl;

  const ProfessionalInstitution({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.typeAr,
    required this.typeEn,
    required this.city,
    required this.website,
    this.email = '',
    this.phone = '',
    this.programAbbrs = const [],
    required this.summaryAr,
    required this.summaryEn,
    this.partnershipStatus = InstitutionPartnershipStatus.directoryOnly,
    this.admissionsUrl,
  });

  bool get isPartnered =>
      partnershipStatus == InstitutionPartnershipStatus.partnered;

  String get applyLink => admissionsUrl?.trim().isNotEmpty == true
      ? admissionsUrl!.trim()
      : website;
}

const professionalInstitutionsCatalog = <ProfessionalInstitution>[
  ProfessionalInstitution(
    id: 'sams',
    nameAr: 'أكاديمية السادات للعلوم الإدارية',
    nameEn: 'Sadat Academy for Management Sciences (SAMS)',
    typeAr: 'أكاديمية حكومية',
    typeEn: 'Public academy',
    city: 'القاهرة + فروع (إسكندرية، طنطا، أسيوط…)',
    website: 'http://sams.edu.eg/',
    admissionsUrl: 'http://sams.edu.eg/fms/graduate-studies/mba',
    programAbbrs: ['MBA', 'DBA', 'MPA', 'PGDip', 'MIS'],
    summaryAr:
        'من أبرز مقدمي المسارات المهنية في مصر: ماجستير مهني MBA، دكتوراه مهنية DBA، '
        'ماجستير محاسبة مهني MPA، ودبلومات دراسات عليا — معتمدة من المجلس الأعلى للجامعات.',
    summaryEn:
        'A leading Egyptian provider of professional tracks: MBA, DBA, professional '
        'accounting (MPA), and postgraduate diplomas — accredited by the Supreme Council of Universities.',
  ),
  ProfessionalInstitution(
    id: 'mansoura_commerce',
    nameAr: 'كلية التجارة — جامعة المنصورة',
    nameEn: 'Faculty of Commerce — Mansoura University',
    typeAr: 'جامعة حكومية',
    typeEn: 'Public university',
    city: 'المنصورة',
    website: 'https://comfac.mans.edu.eg/',
    admissionsUrl:
        'https://comfac.mans.edu.eg/sectors-ar/graduate-studies-and-research-sector/mba-dba',
    programAbbrs: ['MBA', 'DBA'],
    summaryAr:
        'برامج الماجستير المهني والدكتوراه المهنية في إدارة الأعمال. صُنّف MBA المنصورة '
        'ضمن البرامج المتميزة إقليمياً في تقارير دولية.',
    summaryEn:
        'Professional MBA and DBA programs. Mansoura MBA has been highlighted among '
        'strong regional professional management programs.',
  ),
  ProfessionalInstitution(
    id: 'ain_shams_commerce',
    nameAr: 'كلية التجارة — جامعة عين شمس',
    nameEn: 'Faculty of Business — Ain Shams University',
    typeAr: 'جامعة حكومية',
    typeEn: 'Public university',
    city: 'العباسية / القاهرة',
    website: 'https://bus.asu.edu.eg/',
    email: 'PG.ELU@bus.asu.edu.eg',
    phone: '0222615603',
    admissionsUrl: 'https://bus.asu.edu.eg/ar/page/81',
    programAbbrs: ['MBA', 'DBA', 'MPA'],
    summaryAr:
        'برامج مهنية رائدة: MBA وDBA وMPA (محاسبة)، موجّهة للمصريين والوافدين ضمن '
        'مبادرات «ادرس في مصر». تخصصات DBA تشمل تمويل، تسويق، موارد بشرية، رعاية صحية.',
    summaryEn:
        'Leading professional MBA, DBA, and MPA (accounting) programs for Egyptian '
        'and international students. DBA tracks include finance, marketing, HR, healthcare.',
  ),
  ProfessionalInstitution(
    id: 'cairo_fcba_ppp',
    nameAr: 'كلية التجارة وإدارة الأعمال — برامج الدراسات العليا المهنية (PPP)',
    nameEn: 'Faculty of Commerce & Business Admin — Professional PG Programs',
    typeAr: 'جامعة حكومية / برامج مهنية',
    typeEn: 'Public university / professional programs',
    city: 'القاهرة',
    website: 'https://fcba.capu.edu.eg/',
    admissionsUrl: 'https://fcba.capu.edu.eg/index.php/ar/programs/ppp',
    programAbbrs: ['PGDip', 'MBA', 'DBA'],
    summaryAr:
        'مسار PPP متعدد المستويات: دبلومة مهنية، ماجستير مهني، وماجستير أكاديمي، '
        'وصولاً إلى DBA — مع شروط خبرة واختبارات لغة حسب المستوى.',
    summaryEn:
        'Multi-level PPP pathway: professional diploma, professional MBA, academic MBA, '
        'up to DBA — with experience and language requirements by level.',
  ),
  ProfessionalInstitution(
    id: 'auc_mba',
    nameAr: 'الجامعة الأمريكية بالقاهرة — برامج الإدارة',
    nameEn: 'The American University in Cairo — Management programs',
    typeAr: 'جامعة خاصة',
    typeEn: 'Private university',
    city: 'القاهرة الجديدة',
    website: 'https://www.aucegypt.edu/',
    admissionsUrl: 'https://www.aucegypt.edu/academics/graduate-studies',
    programAbbrs: ['MBA', 'MPA', 'EMBA'],
    summaryAr:
        'برامج إدارة مهنية بمعايير دولية (MBA / إدارة عامة). مناسبة لمن يبحث عن '
        'بيئة تعليمية ثنائية اللغة وشبكات مهنية إقليمية.',
    summaryEn:
        'International-standard professional management programs (MBA / public admin). '
        'Suited to bilingual study and regional professional networks.',
  ),
  ProfessionalInstitution(
    id: 'benha_fci_diplomas',
    nameAr: 'كلية الحاسبات والذكاء الاصطناعي — جامعة بنها',
    nameEn: 'Faculty of Computers & AI — Benha University',
    typeAr: 'جامعة حكومية',
    typeEn: 'Public university',
    city: 'بنها',
    website: 'https://fci.bu.edu.eg/',
    admissionsUrl:
        'https://fci.bu.edu.eg/graduate-studies/professional-diploma-programs',
    programAbbrs: ['PGDip'],
    summaryAr:
        'دبلومات مهنية بمصروفات وساعات معتمدة: ذكاء اصطناعي تطبيقي، ذكاء أعمال، '
        'ومعلوماتية طبية — مسار سريع للتخصص المهني.',
    summaryEn:
        'Credit-hour professional diplomas: applied AI, business intelligence, '
        'and medical informatics — a fast professional specialization path.',
  ),
  ProfessionalInstitution(
    id: 'asu_education_diplomas',
    nameAr: 'كلية التربية — جامعة عين شمس (دبلومات)',
    nameEn: 'Faculty of Education — Ain Shams University (diplomas)',
    typeAr: 'جامعة حكومية',
    typeEn: 'Public university',
    city: 'القاهرة',
    website: 'https://edu.asu.edu.eg/',
    admissionsUrl: 'https://services.asu.edu.eg/ar/344/page/الدبلومات',
    programAbbrs: ['PGDip', 'EdD'],
    summaryAr:
        'دبلومات تربية هامة (صحة نفسية، مناهج، إدارة تربوية، تربية خاصة) كجسر '
        'نحو الماجستير أو الترقي المهني للمعلمين.',
    summaryEn:
        'Key education diplomas (mental health, curriculum, educational admin, '
        'special education) as a bridge to master\'s or teacher career progression.',
  ),
  ProfessionalInstitution(
    id: 'capu_law_diplomas',
    nameAr: 'كلية الحقوق — برامج الدبلومات والدبلومات المهنية',
    nameEn: 'Faculty of Law — Diplomas & professional diplomas',
    typeAr: 'جامعة حكومية',
    typeEn: 'Public university',
    city: 'القاهرة',
    website: 'https://law.capu.edu.eg/',
    admissionsUrl:
        'https://law.capu.edu.eg/index.php/ar/graduate-studies/diplomas',
    programAbbrs: ['PGDip'],
    summaryAr:
        'دبلومات حقوق تقليدية (عام، خاص، جنائي، دولي…) ودبلومات مهنية مثل التحكيم '
        'وعقود الإنشاءات والقانون الطبي.',
    summaryEn:
        'Traditional law diplomas (public, private, criminal, international) plus '
        'professional tracks such as arbitration and construction contracts.',
  ),
  ProfessionalInstitution(
    id: 'damanhour_pg',
    nameAr: 'جامعة دمنهور — دراسات عليا (دبلوم / ماجستير مهني)',
    nameEn: 'Damanhour University — Postgraduate (diploma / professional master\'s)',
    typeAr: 'جامعة حكومية',
    typeEn: 'Public university',
    city: 'دمنهور',
    website: 'https://damanhour.dmu.edu.eg/',
    admissionsUrl:
        'https://damanhour.dmu.edu.eg/PGSR/Pages/Page.aspx?id=1125',
    programAbbrs: ['PGDip', 'MBA', 'EMBA'],
    summaryAr:
        'دبلومات تربية وتجارة، وماجستير مهني تنفيذي في إدارة الأعمال ضمن باقة '
        'درجات الدراسات العليا بالجامعة.',
    summaryEn:
        'Education and commerce diplomas, plus executive professional MBA among '
        'the university\'s postgraduate offerings.',
  ),
  ProfessionalInstitution(
    id: 'nile_university',
    nameAr: 'جامعة النيل — برامج دراسات عليا مهنية / تطبيقية',
    nameEn: 'Nile University — Professional / applied postgraduate programs',
    typeAr: 'جامعة أهلية',
    typeEn: 'National university',
    city: 'الشيخ زايد / الجيزة',
    website: 'https://nu.edu.eg/',
    admissionsUrl: 'https://nu.edu.eg/admissions/graduate/',
    programAbbrs: ['MBA', 'MIS', 'PGDip'],
    summaryAr:
        'برامج دراسات عليا مرتبطة بسوق العمل والتقنية والإدارة — خيار للأهداف '
        'المهنية التطبيقية في بيئة جامعية حديثة.',
    summaryEn:
        'Postgraduate programs linked to industry, technology, and management — '
        'suited to applied career goals in a modern campus setting.',
  ),
];
