import '../store_categories.dart';

/// Curated Egyptian academic/lab suppliers for AcadeGate Store.
///
/// [categoryIds] must stay tight: primary specialty first, optional secondary only.
class EgyptStoreSupplier {
  final String id;
  final String nameAr;
  final String nameEn;
  final String website;
  final String email;
  final String phone;
  final String whatsapp;
  final String city;
  final String address;
  final List<String> focusAreas;
  /// Store category ids — keep focused (1–2 max).
  final List<String> categoryIds;
  final String? wooCommerceBaseUrl;
  final String defaultCategoryTitle;
  final bool productSyncEnabled;
  /// Soft cap for huge catalogs (e.g. Makers ~8k). Null = no cap.
  final int? syncMaxProducts;

  const EgyptStoreSupplier({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.website,
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.city = '',
    this.address = '',
    this.focusAreas = const [],
    this.categoryIds = const ['general'],
    this.wooCommerceBaseUrl,
    this.defaultCategoryTitle = 'مستلزمات عامة',
    this.productSyncEnabled = false,
    this.syncMaxProducts,
  });

  String get displayContact {
    final parts = <String>[
      if (phone.isNotEmpty) '\u200E$phone',
      if (whatsapp.isNotEmpty && whatsapp != phone) '\u200Eواتساب: $whatsapp',
      if (email.isNotEmpty) '\u200E$email',
      if (website.isNotEmpty) '\u200E$website',
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toFirestoreMap({required DateTime? syncedAt}) {
    return {
      'id': id,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'name': nameAr,
      'website': website,
      'email': email,
      'phone': phone,
      'whatsapp': whatsapp,
      'city': city,
      'address': address,
      'focusAreas': focusAreas,
      'categoryIds': categoryIds,
      'contact': displayContact,
      'defaultCategoryTitle': defaultCategoryTitle,
      'productSyncEnabled': productSyncEnabled,
      'wooCommerceBaseUrl': ?wooCommerceBaseUrl,
      'importSource': 'egypt_suppliers_catalog_2026',
      'isVerifiedSeller': true,
      'syncedAt': ?syncedAt,
    };
  }
}

const egyptStoreSuppliersCatalog = <EgyptStoreSupplier>[
  // ─── Chemicals ─────────────────────────────────────────
  EgyptStoreSupplier(
    id: 'piochem',
    nameAr: 'بايوكيم — Piochem',
    nameEn: 'Piochem',
    website: 'https://piochem.com/',
    email: 'info@piochem.com',
    phone: '+201205700001',
    city: '6 أكتوبر / الجيزة',
    address: 'AREA 269A, 1st industrial zone, 6th of October, Giza',
    focusAreas: ['كيميائيات', 'مذيبات', 'كواشف معامل'],
    categoryIds: ['chemicals'],
    wooCommerceBaseUrl: 'https://piochem.com',
    defaultCategoryTitle: 'كيميائيات وكواشف',
    productSyncEnabled: true,
  ),
  EgyptStoreSupplier(
    id: 'cornell_lab',
    nameAr: 'كورنيل لاب — Cornell Lab',
    nameEn: 'Cornell Lab',
    website: 'https://cornelllab.com/',
    email: 'info@cornelllab.com',
    phone: '+201001431106',
    city: 'المعادي / القاهرة',
    address: 'Zahraa El Maadi, Cairo',
    focusAreas: ['كيماويات بحثية', 'زجاجيات', 'مستهلكات'],
    categoryIds: ['chemicals', 'consumables'],
    wooCommerceBaseUrl: 'https://cornelllab.com',
    defaultCategoryTitle: 'كيميائيات وكواشف',
    productSyncEnabled: true,
  ),
  EgyptStoreSupplier(
    id: 'trust_scientific',
    nameAr: 'تراست ساينتيفيك — Trust Scientific',
    nameEn: 'Trust Scientific',
    website: 'https://trust-scientific.com/',
    email: 'info@trust-scientific.com',
    city: 'فيصل / الجيزة',
    address: '56 El Eshreen St, Faisal, Giza',
    focusAreas: ['كيماويات بحثية', 'NMR'],
    categoryIds: ['chemicals', 'physics_materials'],
    defaultCategoryTitle: 'كيميائيات وكواشف',
  ),
  EgyptStoreSupplier(
    id: 'lct_chemicals',
    nameAr: 'الكيماويات المعملية — LCT',
    nameEn: 'Lab Chemicals Trading Co.',
    website: 'http://www.lct-chemicals.com/',
    phone: '+20227923295',
    city: 'جاردن سيتي / القاهرة',
    address: '12st Dr Handousa, Kasr el Ani, Garden City',
    focusAreas: ['كيماويات معامل', 'صيدلانية'],
    categoryIds: ['chemicals'],
    defaultCategoryTitle: 'كيميائيات وكواشف',
  ),
  EgyptStoreSupplier(
    id: 'nile_chem',
    nameAr: 'النيل للكيماويات',
    nameEn: 'Nile Chem',
    website: 'https://nilegroupe.com/ar/nile-chem/',
    city: 'مصر',
    focusAreas: ['كيماويات صناعية', 'كيماويات مختبرات'],
    categoryIds: ['chemicals'],
    defaultCategoryTitle: 'كيميائيات وكواشف',
  ),
  EgyptStoreSupplier(
    id: 'perfect_lab',
    nameAr: 'بيرفكت لاب',
    nameEn: 'Perfect Lab',
    website: 'https://perfectlabeg.com/',
    email: 'info@perfectlabeg.com',
    phone: '01146037062',
    whatsapp: '01062207698',
    city: 'السيدة زينب / القاهرة',
    address: '11 Aly Yousef St, Alqasr Al Ayni',
    focusAreas: ['كيماويات', 'زجاجيات'],
    categoryIds: ['chemicals', 'consumables'],
    defaultCategoryTitle: 'كيميائيات وكواشف',
  ),

  // ─── Biology ───────────────────────────────────────────
  EgyptStoreSupplier(
    id: 'igtechnology',
    nameAr: 'آي جي تكنولوجي — IGTechnology',
    nameEn: 'IGTechnology',
    website: 'https://www.igtechnologyeg.com/',
    city: 'مصر',
    focusAreas: ['ELISA', 'PCR', 'زراعة خلايا'],
    categoryIds: ['biology'],
    defaultCategoryTitle: 'بيولوجيا وتقنية حيوية',
  ),

  // ─── Medical ───────────────────────────────────────────
  EgyptStoreSupplier(
    id: 'labtronic',
    nameAr: 'لابترونيك — LABTRONIC',
    nameEn: 'LABTRONIC',
    website: 'https://labtronic-eg.com/',
    email: 'info@labtronic-eg.com',
    phone: '+201090548848',
    whatsapp: '01094557032',
    city: 'مصر',
    focusAreas: ['كواشف طبية', 'اختبارات سريعة', 'أجهزة تحاليل'],
    categoryIds: ['medical'],
    wooCommerceBaseUrl: 'https://labtronic-eg.com',
    defaultCategoryTitle: 'طبي وصيدلي وسريري',
    productSyncEnabled: true,
  ),
  EgyptStoreSupplier(
    id: 'omega_lab_equip',
    nameAr: 'أوميجا للتجهيزات المعملية',
    nameEn: 'Omega Laboratory Equipment',
    website: 'https://ome-ga.com/',
    phone: '01095069944',
    whatsapp: '01095069944',
    city: 'مصر',
    focusAreas: ['أجهزة تحاليل طبية', 'CBC', 'كيمياء دم'],
    categoryIds: ['medical'],
    wooCommerceBaseUrl: 'https://ome-ga.com',
    defaultCategoryTitle: 'طبي وصيدلي وسريري',
    productSyncEnabled: true,
  ),
  EgyptStoreSupplier(
    id: 'delta_medical',
    nameAr: 'دلتا ميديكال',
    nameEn: 'Delta Medical',
    website: 'https://deltamedicalco.com/',
    city: 'مصر',
    focusAreas: ['أجهزة طبية', 'كواشف معامل'],
    categoryIds: ['medical'],
    defaultCategoryTitle: 'طبي وصيدلي وسريري',
  ),
  EgyptStoreSupplier(
    id: 'arkan_scientech',
    nameAr: 'أركان ساينتك — Arkan Scientech',
    nameEn: 'Arkan Scientech',
    website: 'https://arkanscientech.com/',
    city: 'مصر',
    focusAreas: ['أجهزة معامل طبية', 'كواشف تشخيصية'],
    categoryIds: ['medical'],
    defaultCategoryTitle: 'طبي وصيدلي وسريري',
  ),
  EgyptStoreSupplier(
    id: 'ultra_diagnostic',
    nameAr: 'ألترا دياجنوستك',
    nameEn: 'Ultra Diagnostic',
    website: 'https://ultradiagnostic-eg.net/',
    city: 'المقطم / القاهرة',
    address: '354, 9 St, District D, Al-Nafoura SQ, Mokattam',
    focusAreas: ['معامل سريرية وتشخيصية'],
    categoryIds: ['medical'],
    defaultCategoryTitle: 'طبي وصيدلي وسريري',
  ),
  EgyptStoreSupplier(
    id: 'diagnostica_egypt',
    nameAr: 'دياجنوستيكا إيجيبت',
    nameEn: 'Diagnostica Egypt',
    website: 'http://www.diagnosticaegypt.com/',
    email: 'Info@diagnosticaegypt.com',
    phone: '+20222901397',
    city: 'مصر الجديدة / القاهرة',
    address: '30 Yacoub Artin St, Heliopolis',
    focusAreas: ['تشخيص مخبري', 'اختبارات بيطرية'],
    categoryIds: ['medical', 'agriculture'],
    defaultCategoryTitle: 'طبي وصيدلي وسريري',
  ),

  // ─── Agriculture / vet ─────────────────────────────────
  EgyptStoreSupplier(
    id: 'biolab_pharma',
    nameAr: 'بيولاب فارما إيجي',
    nameEn: 'Biolab Pharma Egy',
    website: 'https://biolabpharma-egy.com/',
    city: 'مصر',
    focusAreas: ['تشخيص بيطري', 'أعلاف'],
    categoryIds: ['agriculture'],
    defaultCategoryTitle: 'زراعة وبيطري',
  ),
  EgyptStoreSupplier(
    id: 'technoscience_agri',
    nameAr: 'تكنو سينس للمستلزمات الزراعية',
    nameEn: 'Techno Science Agri',
    website: 'https://technoscience-agri.com/home/',
    city: 'مصر',
    focusAreas: ['مستلزمات إنتاج زراعي'],
    categoryIds: ['agriculture'],
    defaultCategoryTitle: 'زراعة وبيطري',
  ),
  EgyptStoreSupplier(
    id: 'pharmachem_int',
    nameAr: 'فارما كيم إنترناشونال',
    nameEn: 'PharmaChem International',
    website: 'https://www.pharmachem-int.com/',
    city: 'مصر',
    focusAreas: ['صحة حيوانية', 'إضافات أعلاف'],
    categoryIds: ['agriculture'],
    defaultCategoryTitle: 'زراعة وبيطري',
  ),
  EgyptStoreSupplier(
    id: 'imc_egypt',
    nameAr: 'آي إم سي إيجيبت — IMC',
    nameEn: 'IMC Egypt',
    website: 'https://www.imcwakeel.com/',
    city: 'مصر',
    focusAreas: ['سلامة أعلاف وغذاء', 'ELISA دواجن'],
    categoryIds: ['agriculture'],
    defaultCategoryTitle: 'زراعة وبيطري',
  ),
  EgyptStoreSupplier(
    id: 'mabrouk_eng',
    nameAr: 'مبروك الدولية للصناعات الهندسية',
    nameEn: 'Mabrouk International',
    website: 'https://mabroukegypt.net/ar/',
    city: 'مصر',
    focusAreas: ['معدات زراعية وهندسية'],
    categoryIds: ['agriculture', 'engineering'],
    defaultCategoryTitle: 'زراعة وبيطري',
  ),

  // ─── Engineering / electronics ─────────────────────────
  EgyptStoreSupplier(
    id: 'makers_electronics',
    nameAr: 'ميكرز إلكترونكس — Makers',
    nameEn: 'Makers Electronics',
    website: 'https://makerselectronics.com/',
    email: 'info@makerselectronics.com',
    phone: '+20248813824',
    whatsapp: '01211981188',
    city: 'الإسكندرية',
    address: '158 شارع الحرية، الإبراهيمية',
    focusAreas: ['Arduino', 'مكونات إلكترونية', 'أجهزة قياس', 'IoT'],
    categoryIds: ['engineering', 'computing'],
    wooCommerceBaseUrl: 'https://makerselectronics.com',
    defaultCategoryTitle: 'هندسة وإلكترونيات',
    productSyncEnabled: true,
    syncMaxProducts: 2000,
  ),
  EgyptStoreSupplier(
    id: 'am_electronics',
    nameAr: 'إيه إم إلكترونكس — AM Electronics',
    nameEn: 'AM Electronics',
    website: 'https://am-electronics.com/',
    city: 'مصر',
    focusAreas: ['مشاريع جامعية', 'Arduino', 'روبوتات', 'CNC / طباعة ثلاثية'],
    categoryIds: ['engineering'],
    wooCommerceBaseUrl: 'https://am-electronics.com',
    defaultCategoryTitle: 'هندسة وإلكترونيات',
    productSyncEnabled: true,
  ),
  EgyptStoreSupplier(
    id: 'ekostra',
    nameAr: 'إيكوسترا إلكترونكس',
    nameEn: 'Ekostra Electronics',
    website: 'https://ekostra.com/',
    city: 'التجمع الأول / القاهرة',
    focusAreas: ['Arduino', 'حساسات', 'لوحات تطوير'],
    categoryIds: ['engineering'],
    wooCommerceBaseUrl: 'https://ekostra.com',
    defaultCategoryTitle: 'هندسة وإلكترونيات',
    productSyncEnabled: true,
  ),
  EgyptStoreSupplier(
    id: 'ram_electronics',
    nameAr: 'رام للإلكترونيات',
    nameEn: 'RAM Electronics',
    website: 'https://www.ram.com.eg/',
    email: 'sales@ram-electronics.com',
    phone: '+20227960551',
    city: 'باب اللوق / القاهرة',
    address: '32 شارع الفلكي، باب اللوق',
    focusAreas: ['مكونات إلكترونية', 'أجهزة قياس', 'Raspberry Pi'],
    categoryIds: ['engineering'],
    defaultCategoryTitle: 'هندسة وإلكترونيات',
  ),
  EgyptStoreSupplier(
    id: 'el_gammal_electronics',
    nameAr: 'الجمّال للإلكترونيات',
    nameEn: 'El Gammal Electronics',
    website: 'https://elgammalelectronic.com/',
    email: 'support@elgammalelectronic.com',
    city: 'مصر',
    focusAreas: ['مكونات', 'أدوات قياس', 'لوحات تطوير'],
    categoryIds: ['engineering'],
    defaultCategoryTitle: 'هندسة وإلكترونيات',
  ),
  EgyptStoreSupplier(
    id: 'met_egypt',
    nameAr: 'الموارد للهندسة والتجارة — MET',
    nameEn: 'MET Egypt',
    website: 'https://www.met-eg.org/',
    email: 'info@met-eg.com',
    phone: '01223033988',
    city: 'مصر',
    focusAreas: ['أتمتة صناعية', 'حساسات', 'محركات', 'لوحات تحكم'],
    categoryIds: ['engineering'],
    defaultCategoryTitle: 'هندسة وإلكترونيات',
  ),
  EgyptStoreSupplier(
    id: 'best_lab_eg',
    nameAr: 'بست لاب للتجهيزات المعملية',
    nameEn: 'Best Lab',
    website: 'https://best-lab.org/',
    city: 'القاهرة',
    address: '21 شارع المواردي، القصر العيني',
    focusAreas: ['تجهيز معامل', 'أجهزة', 'صيانة'],
    categoryIds: ['engineering', 'medical'],
    defaultCategoryTitle: 'هندسة وإلكترونيات',
  ),
  EgyptStoreSupplier(
    id: 'meslo_egypt',
    nameAr: 'ميسلو إيجيبت — MESLO',
    nameEn: 'MESLO Egypt',
    website: 'https://meslo.com.eg/',
    city: 'مصر',
    focusAreas: ['أجهزة علمية هندسية', 'تحليل طيفي', 'كروماتوجرافيا'],
    categoryIds: ['engineering', 'instruments', 'physics_materials'],
    defaultCategoryTitle: 'هندسة وإلكترونيات',
  ),
  EgyptStoreSupplier(
    id: 'egs_egypt',
    nameAr: 'المجموعة المصرية للأنظمة — EGS',
    nameEn: 'Egyptian Group Systems',
    website: 'https://egs.com.eg/',
    city: 'مصر',
    focusAreas: ['أجهزة معامل', 'مواد', 'حلول مختبرية'],
    categoryIds: ['engineering', 'instruments'],
    defaultCategoryTitle: 'هندسة وإلكترونيات',
  ),
  EgyptStoreSupplier(
    id: 'eciss_egypt',
    nameAr: 'الشركة المصرية للخدمات الصناعية والعلمية',
    nameEn: 'ECISS',
    website: 'https://www.eciss.com.eg/',
    city: 'مصر',
    focusAreas: ['اختبارات صناعية', 'قياس', 'أجهزة معامل'],
    categoryIds: ['engineering', 'instruments'],
    defaultCategoryTitle: 'هندسة وإلكترونيات',
  ),

  // ─── Physics / materials ───────────────────────────────
  EgyptStoreSupplier(
    id: 'gemicatech',
    nameAr: 'جيميكاتيك — Gemicatech',
    nameEn: 'Gemicatech',
    website: 'https://gemicatech.com/',
    city: 'مصر',
    focusAreas: ['أجهزة تحليلية', 'حلول علمية'],
    categoryIds: ['instruments', 'physics_materials'],
    defaultCategoryTitle: 'أجهزة وأدوات قياس',
  ),

  // ─── Consumables ───────────────────────────────────────
  EgyptStoreSupplier(
    id: 'lab_supply_group',
    nameAr: 'لاب سابلاي جروب',
    nameEn: 'Lab Supply Group',
    website: 'https://lab-supply.net/',
    email: 'sales@lab-supply.net',
    phone: '+201050227430',
    whatsapp: '+201018768333',
    city: 'مصر',
    focusAreas: ['مستهلكات', 'أجهزة معامل', 'كيماويات'],
    categoryIds: ['consumables', 'instruments'],
    wooCommerceBaseUrl: 'https://lab-supply.net',
    defaultCategoryTitle: 'مستهلكات وأدوات مختبر',
    productSyncEnabled: true,
  ),
  EgyptStoreSupplier(
    id: 'elemental_eg',
    nameAr: 'إليمنتال — Elemental',
    nameEn: 'Elemental',
    website: 'https://elementaleg.com/',
    email: 'info@elementaleg.com',
    phone: '+201067828381',
    city: 'مدينة نصر / القاهرة',
    focusAreas: ['زجاجيات', 'بلاستيك معامل', 'مستهلكات'],
    categoryIds: ['consumables'],
    defaultCategoryTitle: 'مستهلكات وأدوات مختبر',
  ),
  EgyptStoreSupplier(
    id: 'lab_supply_egypt',
    nameAr: 'لاب سابلاي إيجيبت',
    nameEn: 'Lab Supply Egypt',
    website: 'https://labsupplyegypt.com/',
    city: 'مصر',
    focusAreas: ['مستلزمات معامل'],
    categoryIds: ['consumables'],
    defaultCategoryTitle: 'مستهلكات وأدوات مختبر',
  ),

  // ─── Instruments ───────────────────────────────────────
  EgyptStoreSupplier(
    id: 'sam_lab_egypt',
    nameAr: 'سام لاب إيجيبت',
    nameEn: 'SAM Lab Egypt',
    website: 'https://samlabegypt.com/',
    email: 'info@samlabegypt.com',
    phone: '+201001012695',
    city: 'حلميّة الزيتون / القاهرة',
    address: '3 El Bishry St, Helmyete El Zitoun',
    focusAreas: ['أجهزة علمية ومعملية'],
    categoryIds: ['instruments'],
    defaultCategoryTitle: 'أجهزة وأدوات قياس',
  ),
  EgyptStoreSupplier(
    id: 'lab_egypt',
    nameAr: 'لاب إيجيبت — Lab Egypt',
    nameEn: 'Lab Egypt',
    website: 'https://labegypt.com/',
    city: 'مصر',
    focusAreas: ['أجهزة قياس pH / EC / DO'],
    categoryIds: ['instruments'],
    defaultCategoryTitle: 'أجهزة وأدوات قياس',
  ),

  // ─── Safety ────────────────────────────────────────────
  EgyptStoreSupplier(
    id: 'first_env',
    nameAr: 'فرست للاستشارات والبيئة',
    nameEn: 'FIRST Company',
    website: 'https://www.first-env.com/',
    city: 'مصر',
    focusAreas: ['سلامة شخصية', 'معايرة', 'حماية'],
    categoryIds: ['safety'],
    defaultCategoryTitle: 'سلامة ومعدات وقاية',
  ),

  // ─── Field / survey ────────────────────────────────────
  EgyptStoreSupplier(
    id: 'field_survey_note',
    nameAr: 'أجهزة مساحة ومسح (عبر فرست / لاب إيجيبت)',
    nameEn: 'Survey & field gear contacts',
    website: 'https://www.first-env.com/',
    city: 'مصر',
    focusAreas: ['مسح', 'قياس ميداني', 'بيئة'],
    categoryIds: ['field'],
    defaultCategoryTitle: 'أدوات ميدانية ومسح',
  ),

  // ─── Computing ─────────────────────────────────────────
  EgyptStoreSupplier(
    id: 'itida_dir',
    nameAr: 'هيئة تنمية صناعة تكنولوجيا المعلومات (ITIDA)',
    nameEn: 'ITIDA',
    website: 'https://itida.gov.eg/',
    city: 'مصر',
    focusAreas: ['برمجيات', 'شركات تقنية'],
    categoryIds: ['computing'],
    defaultCategoryTitle: 'حوسبة وبرمجيات بحثية',
  ),
  EgyptStoreSupplier(
    id: 'mcit_egypt',
    nameAr: 'وزارة الاتصالات وتكنولوجيا المعلومات',
    nameEn: 'MCIT Egypt',
    website: 'https://mcit.gov.eg/',
    city: 'مصر',
    focusAreas: ['مبادرات رقمية'],
    categoryIds: ['computing'],
    defaultCategoryTitle: 'حوسبة وبرمجيات بحثية',
  ),

  // ─── Books ─────────────────────────────────────────────
  EgyptStoreSupplier(
    id: 'ekb',
    nameAr: 'بنك المعرفة المصري',
    nameEn: 'Egyptian Knowledge Bank',
    website: 'https://www.ekb.eg/',
    city: 'مصر',
    focusAreas: [
      'قواعد بيانات عالمية وعربية',
      'مراجع وكتب إلكترونية',
      'دوريات ورسائل علمية',
      'تربية وإنسانيات وعلوم اجتماعية',
    ],
    categoryIds: ['humanities', 'books'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'auc_press',
    nameAr: 'مطبعة الجامعة الأمريكية بالقاهرة',
    nameEn: 'AUC Press',
    website: 'https://aucpress.com/',
    city: 'القاهرة',
    focusAreas: ['كتب أكاديمية'],
    categoryIds: ['books'],
    defaultCategoryTitle: 'كتب ومراجع علمية',
  ),
  EgyptStoreSupplier(
    id: 'al_shorouk',
    nameAr: 'الشروق',
    nameEn: 'Al Shorouk',
    website: 'https://www.shoroukbookstores.com/',
    city: 'مصر',
    focusAreas: ['كتب ومراجع'],
    categoryIds: ['books'],
    defaultCategoryTitle: 'كتب ومراجع علمية',
  ),

  // ─── Humanities / education / social research ───────────
  EgyptStoreSupplier(
    id: 'mandumah',
    nameAr: 'دار المنظومة',
    nameEn: 'Dar Almandumah',
    website: 'https://mandumah.com/',
    city: 'عربي / عبر الجامعات المصرية',
    focusAreas: [
      'رسائل ماجستير ودكتوراه عربية',
      'دوريات محكمة',
      'قواعد تربية وإنسانيات وعلوم اجتماعية',
    ],
    categoryIds: ['humanities', 'books'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'dar_elkotob',
    nameAr: 'دار الكتب والوثائق القومية',
    nameEn: 'National Library & Archives',
    website: 'https://www.darelkotob.gov.eg/',
    city: 'القاهرة',
    focusAreas: ['وثائق', 'مخطوطات', 'مراجع إنسانيات'],
    categoryIds: ['humanities', 'books'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'bibalex',
    nameAr: 'مكتبة الإسكندرية',
    nameEn: 'Bibliotheca Alexandrina',
    website: 'https://www.bibalex.org/',
    city: 'الإسكندرية',
    focusAreas: ['أرشيف', 'بحث إنساني', 'مكتبة رقمية'],
    categoryIds: ['humanities', 'books'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'cairo_univ_central_library',
    nameAr: 'المكتبة المركزية الجديدة — جامعة القاهرة',
    nameEn: 'Cairo University New Central Library',
    website: 'https://cl.cu.edu.eg/',
    city: 'القاهرة',
    focusAreas: [
      'مكتبة رقمية جامعية',
      'كتب ومراجع ورسائل',
      'خدمات باحثين وطلاب',
    ],
    categoryIds: ['humanities', 'books'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'auc_library',
    nameAr: 'مكتبة الجامعة الأمريكية بالقاهرة',
    nameEn: 'AUC Library',
    website: 'https://library.aucegypt.edu/',
    city: 'القاهرة',
    focusAreas: [
      'مراجع إنسانية واجتماعية',
      'دوريات وقواعد بيانات',
      'خدمات بحث أكاديمي',
    ],
    categoryIds: ['humanities', 'books'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'al_azhar_library',
    nameAr: 'مكتبة الأزهر الشريف',
    nameEn: 'Al-Azhar Library',
    website: 'https://www.azhar.eg/',
    city: 'القاهرة',
    focusAreas: [
      'مخطوطات وتراث',
      'دراسات إسلامية وإنسانية',
      'مراجع شرعية ولغوية',
    ],
    categoryIds: ['humanities'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'ain_shams_library',
    nameAr: 'مكتبة جامعة عين شمس',
    nameEn: 'Ain Shams University Library',
    website: 'https://www.asu.edu.eg/',
    city: 'القاهرة',
    focusAreas: [
      'مراجع تربية وآداب',
      'خدمات مكتبية جامعية',
      'دعم البحث الاجتماعي',
    ],
    categoryIds: ['humanities'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'alex_univ_library',
    nameAr: 'مكتبات جامعة الإسكندرية',
    nameEn: 'Alexandria University Libraries',
    website: 'https://alexu.edu.eg/',
    city: 'الإسكندرية',
    focusAreas: [
      'مكتبات كليات الآداب والتربية',
      'مراجع ورسائل جامعية',
    ],
    categoryIds: ['humanities'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'ncerd',
    nameAr: 'المركز القومي للبحوث التربوية والتنمية',
    nameEn: 'NCERD — National Center for Educational Research',
    website: 'http://www.ncerd.edu.eg/',
    city: 'القاهرة',
    focusAreas: [
      'بحوث تربوية',
      'مناهج وتطوير تعليم',
      'مراجع للباحثين في التربية',
    ],
    categoryIds: ['humanities'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'capmas',
    nameAr: 'الجهاز المركزي للتعبئة العامة والإحصاء',
    nameEn: 'CAPMAS',
    website: 'https://www.capmas.gov.eg/',
    city: 'القاهرة',
    focusAreas: [
      'إحصاءات سكانية واجتماعية',
      'بيانات للبحث الاجتماعي',
      'تقارير رسمية',
    ],
    categoryIds: ['humanities'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'idsc',
    nameAr: 'مركز المعلومات ودعم اتخاذ القرار',
    nameEn: 'IDSC Egypt',
    website: 'https://www.idsc.gov.eg/',
    city: 'القاهرة',
    focusAreas: [
      'تقارير سياسات عامة',
      'بيانات وبحوث اجتماعية',
      'دعم باحثين وصنّاع قرار',
    ],
    categoryIds: ['humanities'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),
  EgyptStoreSupplier(
    id: 'gebo',
    nameAr: 'الهيئة المصرية العامة للكتاب',
    nameEn: 'Egyptian General Book Organization',
    website: 'https://gebo.gov.eg/',
    city: 'القاهرة',
    focusAreas: [
      'نشر كتب عربية',
      'معارض ومراجع ثقافية',
      'إصدارات إنسانية وأدبية',
    ],
    categoryIds: ['humanities', 'books'],
    defaultCategoryTitle: 'إنسانيات وتربية وبحث اجتماعي',
  ),

  // ─── Research writing / documentation / thesis print ───
  EgyptStoreSupplier(
    id: 'alwan_stationary',
    nameAr: 'ألوان للقرطاسية والمستلزمات المكتبية',
    nameEn: 'Alwan Stationery',
    website: 'https://alwan.com.eg/',
    email: 'info@alwan.com.eg',
    phone: '19275',
    city: 'مصر',
    focusAreas: [
      'دفاتر وأوراق',
      'أقلام وأدوات كتابة',
      'ملفات وأرشفة',
      'مستلزمات مكتبية للباحث',
    ],
    categoryIds: ['office'],
    defaultCategoryTitle: 'مستلزمات كتابة وتوثيق البحث',
  ),
  EgyptStoreSupplier(
    id: 'zamzam_printing',
    nameAr: 'زمزم للطباعة والتجليد',
    nameEn: 'Zamzam Printing & Binding',
    website: 'https://zamzam.com.eg/',
    phone: '+20 2 27952362',
    whatsapp: '+20 101 221 4422',
    city: 'القاهرة',
    address: '53 شارع نوبار، وسط البلد، القاهرة',
    focusAreas: [
      'طباعة أطروحات ورسائل',
      'تجليد غلاف صلب',
      'طباعة عند الطلب',
    ],
    categoryIds: ['office'],
    defaultCategoryTitle: 'مستلزمات كتابة وتوثيق البحث',
  ),
  EgyptStoreSupplier(
    id: 'salama_printing',
    nameAr: 'سلامة للطباعة',
    nameEn: 'Salama Printing',
    website: 'https://salamaprinting.com/',
    phone: '+20 2 24550391',
    city: 'القاهرة',
    address: 'مصر الجديدة / جسر السويس',
    focusAreas: [
      'طباعة كتب وكتالوجات',
      'تجليد سلكي ومثالي',
      'طباعة مكتبية أكاديمية',
    ],
    categoryIds: ['office'],
    defaultCategoryTitle: 'مستلزمات كتابة وتوثيق البحث',
  ),
  EgyptStoreSupplier(
    id: 'algazera_press',
    nameAr: 'الجزيرة إنترناشونال برس',
    nameEn: 'Al Gazera International Press',
    website: 'https://algazerapress.com/',
    city: 'الجيزة',
    address: 'المهندسين / العجوزة',
    focusAreas: [
      'طباعة رقمية وأوفست',
      'تجليد أطروحات',
      'أرشفة ووثائق',
    ],
    categoryIds: ['office'],
    defaultCategoryTitle: 'مستلزمات كتابة وتوثيق البحث',
  ),


  // ─── General ───────────────────────────────────────────
  EgyptStoreSupplier(
    id: 'general_lab_hub',
    nameAr: 'مستلزمات عامة للمعامل',
    nameEn: 'General lab supplies hub',
    website: 'https://labsupplyegypt.com/',
    city: 'مصر',
    focusAreas: ['توريدات عامة للمعامل'],
    categoryIds: ['general'],
    defaultCategoryTitle: 'مستلزمات عامة',
  ),
];

EgyptStoreSupplier? egyptStoreSupplierById(String id) {
  for (final s in egyptStoreSuppliersCatalog) {
    if (s.id == id) return s;
  }
  return null;
}

List<EgyptStoreSupplier> get egyptStoreSuppliersWithProductSync =>
    egyptStoreSuppliersCatalog.where((s) => s.productSyncEnabled).toList();

/// Exact specialty match only — no cross-dumping into unrelated sections.
List<EgyptStoreSupplier> egyptStoreSuppliersForCategory({
  String? categoryId,
  String? categoryTitle,
}) {
  final id = categoryId ??
      storeCategoryByTitle(categoryTitle ?? '')?.id ??
      '';
  if (id.isEmpty) return const [];
  return egyptStoreSuppliersCatalog
      .where((s) => s.categoryIds.contains(id))
      .toList();
}

Map<String, int> egyptStoreSupplierCoverageCounts() {
  final map = <String, int>{};
  for (final c in storeCategories) {
    map[c.id] = egyptStoreSuppliersCatalog
        .where((s) => s.categoryIds.contains(c.id))
        .length;
  }
  return map;
}
