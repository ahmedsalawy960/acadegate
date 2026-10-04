/// كتالوج إرشادي لمنافذ النشر الإنساني/التربوي في السياق المصري والعربي.
/// ليس بديلاً عن قوائم المجلس الأعلى الرسمية — تحقق دائماً من اعتماد القسم.
library;

enum HumanitiesOutletKind {
  facultyAnnals,
  supremeCouncilJournal,
  peerReviewedArabic,
  conference,
  indexedMandumah,
}

enum HumanitiesCitationStyleHint {
  apaAr,
  chicago,
  harvard,
  vancouver,
  journalSpecific,
}

class HumanitiesPublishOutlet {
  final String id;
  final String nameAr;
  final String nameEn;
  final HumanitiesOutletKind kind;
  final List<String> facultyIds; // Education | Arts | Law | General…
  final String publisherAr;
  final String publisherEn;
  final String issn;
  final HumanitiesCitationStyleHint citationStyle;
  final String citationNotesAr;
  final String citationNotesEn;
  final List<String> requirementsAr;
  final List<String> requirementsEn;
  final String submissionUrl;
  final String portalHintAr;
  final String portalHintEn;
  final bool mandumahIndexed;
  final bool typicallyAcceptedForPromotion;

  const HumanitiesPublishOutlet({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.kind,
    required this.facultyIds,
    required this.publisherAr,
    required this.publisherEn,
    this.issn = '',
    required this.citationStyle,
    required this.citationNotesAr,
    required this.citationNotesEn,
    required this.requirementsAr,
    required this.requirementsEn,
    this.submissionUrl = '',
    required this.portalHintAr,
    required this.portalHintEn,
    this.mandumahIndexed = true,
    this.typicallyAcceptedForPromotion = true,
  });

  String kindLabelAr() => switch (kind) {
        HumanitiesOutletKind.facultyAnnals => 'حولية كلية',
        HumanitiesOutletKind.supremeCouncilJournal => 'مجلة معتمدة (نمط المجلس الأعلى)',
        HumanitiesOutletKind.peerReviewedArabic => 'مجلة عربية محكمة',
        HumanitiesOutletKind.conference => 'مؤتمر علمي',
        HumanitiesOutletKind.indexedMandumah => 'منفذ مفهرس (دار المنظومة)',
      };

  String kindLabelEn() => switch (kind) {
        HumanitiesOutletKind.facultyAnnals => 'Faculty yearbook/annals',
        HumanitiesOutletKind.supremeCouncilJournal =>
          'Supreme-Council-style approved journal',
        HumanitiesOutletKind.peerReviewedArabic => 'Arabic peer-reviewed journal',
        HumanitiesOutletKind.conference => 'Academic conference',
        HumanitiesOutletKind.indexedMandumah => 'Mandumah-indexed outlet',
      };

  String citationLabelAr() => switch (citationStyle) {
        HumanitiesCitationStyleHint.apaAr => 'APA (عربي)',
        HumanitiesCitationStyleHint.chicago => 'Chicago',
        HumanitiesCitationStyleHint.harvard => 'Harvard',
        HumanitiesCitationStyleHint.vancouver => 'Vancouver',
        HumanitiesCitationStyleHint.journalSpecific => 'حسب دليل المجلة',
      };

  String citationLabelEn() => switch (citationStyle) {
        HumanitiesCitationStyleHint.apaAr => 'APA (Arabic)',
        HumanitiesCitationStyleHint.chicago => 'Chicago',
        HumanitiesCitationStyleHint.harvard => 'Harvard',
        HumanitiesCitationStyleHint.vancouver => 'Vancouver',
        HumanitiesCitationStyleHint.journalSpecific => 'Journal-specific',
      };
}

/// بذور إرشادية — روابط عامة حيث وُجدت؛ حدّثها عند تغيّر موقع الحولية.
const List<HumanitiesPublishOutlet> humanitiesPublishCatalog = [
  HumanitiesPublishOutlet(
    id: 'edu_asu_annals',
    nameAr: 'مجلة كلية التربية — جامعة عين شمس',
    nameEn: 'Journal of the Faculty of Education — Ain Shams University',
    kind: HumanitiesOutletKind.facultyAnnals,
    facultyIds: ['Education'],
    publisherAr: 'كلية التربية — جامعة عين شمس',
    publisherEn: 'Faculty of Education — Ain Shams University',
    citationStyle: HumanitiesCitationStyleHint.apaAr,
    citationNotesAr:
        'غالباً APA مع توثيق عربي داخل النص (مؤلف، سنة). راجع عدد الصفحات وملخص عربي/إنجليزي.',
    citationNotesEn:
        'Usually APA with Arabic in-text (Author, Year). Check page limits and AR/EN abstracts.',
    requirementsAr: [
      'أصالة البحث وعدم نشره سابقاً',
      'ملخص عربي + إنجليزي + كلمات مفتاحية',
      'التزام بنمط التوثيق APA',
      'موافقة المشرف إن كان البحث من الرسالة',
    ],
    requirementsEn: [
      'Original unpublished work',
      'Arabic + English abstract and keywords',
      'APA citation style',
      'Supervisor approval if derived from a thesis',
    ],
    submissionUrl: 'https://edu.asu.edu.eg/',
    portalHintAr:
        'ارفع عبر صفحة المجلة/الحولية على موقع الكلية أو نظام التقديم الإلكتروني إن وُجد. احتفظ بإيصال الرفع ورقم الطلب.',
    portalHintEn:
        'Upload via the faculty journal page or e-submission system if available. Keep the receipt and request number.',
  ),
  HumanitiesPublishOutlet(
    id: 'edu_cairo_studies',
    nameAr: 'دراسات تربوية ونفسية — كلية التربية جامعة القاهرة',
    nameEn: 'Educational and Psychological Studies — Cairo University',
    kind: HumanitiesOutletKind.peerReviewedArabic,
    facultyIds: ['Education'],
    publisherAr: 'كلية التربية — جامعة القاهرة',
    publisherEn: 'Faculty of Education — Cairo University',
    citationStyle: HumanitiesCitationStyleHint.apaAr,
    citationNotesAr: 'APA شائع في البحوث التربوية المصرية؛ راجع دليل العدد الحالي.',
    citationNotesEn: 'APA is common in Egyptian education research; check the current issue guide.',
    requirementsAr: [
      'مشكلة تربوية واضحة ومنهج معلن',
      'جداول وأشكال داخل النص وفق الدليل',
      'قائمة مراجع حديثة نسبياً',
    ],
    requirementsEn: [
      'Clear educational problem and stated method',
      'Tables/figures per journal guide',
      'Reasonably recent reference list',
    ],
    submissionUrl: 'https://cu.edu.eg/',
    portalHintAr: 'قد يكون التقديم عبر بريد المجلة أو منصة Open Journal Systems — اتبع تعليمات العدد.',
    portalHintEn: 'Submission may be via journal email or OJS — follow the current call.',
  ),
  HumanitiesPublishOutlet(
    id: 'edu_conference_typical',
    nameAr: 'مؤتمر علمي تربوي (نمط كليات التربية)',
    nameEn: 'Education faculty scientific conference (typical)',
    kind: HumanitiesOutletKind.conference,
    facultyIds: ['Education'],
    publisherAr: 'لجنة المؤتمر / الكلية المنظمة',
    publisherEn: 'Conference committee / hosting faculty',
    citationStyle: HumanitiesCitationStyleHint.apaAr,
    citationNotesAr: 'غالباً نفس نمط APA؛ أحياناً قالب Word مرفق باستمارة المؤتمر.',
    citationNotesEn: 'Usually APA; sometimes a Word template is attached to the call.',
    requirementsAr: [
      'ملخص ممتد أو ورقة كاملة حسب الدعوة',
      'تسجيل ودفع رسوم إن وُجدت',
      'خطاب مشاركة + سيرة مختصرة',
    ],
    requirementsEn: [
      'Extended abstract or full paper per the call',
      'Registration and fees if required',
      'Participation letter + short CV',
    ],
    portalHintAr:
        'لا يوجد موقع واحد: استخدم رابط الدعوة في إعلان المؤتمر. احفظ شهادة المشاركة وكتاب القبول للمؤتمر.',
    portalHintEn:
        'No single portal: use the call URL. Keep the participation certificate and acceptance letter.',
    typicallyAcceptedForPromotion: false,
  ),
  HumanitiesPublishOutlet(
    id: 'arts_asu_annals',
    nameAr: 'حوليات آداب عين شمس',
    nameEn: 'Annals of the Faculty of Arts — Ain Shams',
    kind: HumanitiesOutletKind.facultyAnnals,
    facultyIds: ['Arts'],
    publisherAr: 'كلية الآداب — جامعة عين شمس',
    publisherEn: 'Faculty of Arts — Ain Shams University',
    citationStyle: HumanitiesCitationStyleHint.chicago,
    citationNotesAr:
        'الآداب غالباً Chicago أو أسلوب الحولية الداخلي (حواشٍ سفلية). لا تفترض APA تلقائياً.',
    citationNotesEn:
        'Arts often uses Chicago or the annals’ footnote style — do not assume APA.',
    requirementsAr: [
      'عنوان عربي/إنجليزي دقيق',
      'حواشٍ ومراجع وفق دليل الحولية',
      'ملخصين إن طُلبا',
    ],
    requirementsEn: [
      'Precise AR/EN titles',
      'Notes/references per annals guide',
      'Dual abstracts if required',
    ],
    submissionUrl: 'https://arts.asu.edu.eg/',
    portalHintAr:
        'ارفع ملف Word وفق قالب الحولية إن وُجد، أو عبر سكرتارية التحرير/النظام الإلكتروني للكلية.',
    portalHintEn:
        'Upload a Word file using the annals template if provided, or via editorial office / faculty e-system.',
  ),
  HumanitiesPublishOutlet(
    id: 'arts_cairo_annals',
    nameAr: 'مجلة كلية الآداب — جامعة القاهرة',
    nameEn: 'Journal of the Faculty of Arts — Cairo University',
    kind: HumanitiesOutletKind.facultyAnnals,
    facultyIds: ['Arts'],
    publisherAr: 'كلية الآداب — جامعة القاهرة',
    publisherEn: 'Faculty of Arts — Cairo University',
    citationStyle: HumanitiesCitationStyleHint.journalSpecific,
    citationNotesAr: 'اتبع دليل المؤلفين في آخر عدد؛ أساليب الآداب تختلف بين الأقسام.',
    citationNotesEn: 'Follow the authors’ guide in the latest issue; Arts styles vary by department.',
    requirementsAr: [
      'بحث أصيل في تخصص القسم',
      'موافقة القسم عند الاشتراط',
      'خلو من الانتحال',
    ],
    requirementsEn: [
      'Original work in the department field',
      'Department approval when required',
      'Plagiarism-free manuscript',
    ],
    submissionUrl: 'https://arts.cu.edu.eg/',
    portalHintAr: 'تحقق من صفحة المجلة أو نظام التقديم الخاص بالكلية قبل الرفع.',
    portalHintEn: 'Check the journal page or faculty submission system before uploading.',
  ),
  HumanitiesPublishOutlet(
    id: 'law_cairo_journal',
    nameAr: 'مجلة القانون والاقتصاد — جامعة القاهرة',
    nameEn: 'Journal of Law and Economics — Cairo University',
    kind: HumanitiesOutletKind.peerReviewedArabic,
    facultyIds: ['Law'],
    publisherAr: 'كلية الحقوق — جامعة القاهرة',
    publisherEn: 'Faculty of Law — Cairo University',
    citationStyle: HumanitiesCitationStyleHint.journalSpecific,
    citationNotesAr:
        'التوثيق القانوني غالباً حواشٍ مع ذكر التشريع/الحكم بدقة (رقم وتاريخ ومصدر).',
    citationNotesEn:
        'Legal citation often uses footnotes with precise statute/case references (number, date, source).',
    requirementsAr: [
      'مشكلة قانونية محددة',
      'توثيق نصوص وأحكام',
      'خاتمة وتوصيات إن وُجدت في الدليل',
    ],
    requirementsEn: [
      'Defined legal problem',
      'Documented statutes and judgments',
      'Conclusion/recommendations if required',
    ],
    submissionUrl: 'https://law.cu.edu.eg/',
    portalHintAr:
        'مجلة القانون والاقتصاد — غالباً عبر مكتب المجلة أو journals.ekb.eg. '
        'احتفظ بمستخرج القبول لصلاحية مناقشة الدكتوراه.',
    portalHintEn:
        'Journal of Law and Economics — usually via journal office or journals.ekb.eg. '
        'Keep the acceptance extract for PhD viva eligibility.',
  ),
  HumanitiesPublishOutlet(
    id: 'law_asu_rights',
    nameAr: 'مجلة الحقوق — جامعة عين شمس',
    nameEn: 'Journal of Legal Studies — Ain Shams University',
    kind: HumanitiesOutletKind.facultyAnnals,
    facultyIds: ['Law'],
    publisherAr: 'كلية الحقوق — جامعة عين شمس',
    publisherEn: 'Faculty of Law — Ain Shams University',
    citationStyle: HumanitiesCitationStyleHint.journalSpecific,
    citationNotesAr: 'راجع دليل المجلة لنمط الحواشي والاستشهاد بالتشريع المصري.',
    citationNotesEn: 'Check the journal guide for footnotes and Egyptian statute citation.',
    requirementsAr: [
      'بحث قانوني أصيل',
      'ملخص عربي (وإنجليزي إن طُلب)',
      'قائمة مراجع/أسانيد',
    ],
    requirementsEn: [
      'Original legal research',
      'Arabic abstract (and English if required)',
      'Reference/authorities list',
    ],
    submissionUrl: 'https://law.asu.edu.eg/',
    portalHintAr: 'اتبع مسار التقديم المنشور على موقع الكلية أو إعلان قبول الأبحاث.',
    portalHintEn: 'Follow the submission path on the faculty site or the call for papers.',
  ),
  HumanitiesPublishOutlet(
    id: 'arts_jssa_women_asu',
    nameAr: 'مجلة البحث العلمي في الآداب — كلية البنات عين شمس',
    nameEn: 'Journal of Scientific Research in Arts — Women’s College, ASU',
    kind: HumanitiesOutletKind.peerReviewedArabic,
    facultyIds: ['Arts'],
    publisherAr: 'كلية البنات للآداب والعلوم والتربية — جامعة عين شمس',
    publisherEn: 'Faculty of Women — Ain Shams University',
    issn: '2356-8321 / e: 2356-833X',
    citationStyle: HumanitiesCitationStyleHint.journalSpecific,
    citationNotesAr:
        'دورية محكمة ربع سنوية (إلكتروني وورقي). لغات وآداب + علوم اجتماعية وإنسانية. '
        'مفهرسة في DOAJ، شمعة، معرفة، المنظومة، وأرسيف (مثال: Q3 آداب 2022). '
        'استخدم قالب اللغات أو قالب العلوم الاجتماعية حسب التخصص.',
    citationNotesEn:
        'Quarterly peer-reviewed (print + online). Languages/literature + social sciences. '
        'Indexed in DOAJ, Shamaa, Emarefa, Mandumah, ARCIF. Use the matching Word template.',
    requirementsAr: [
      'بحث أصيل في اللغات/الآداب أو العلوم الاجتماعية والإنسانية',
      'تحكيم سري مزدوج',
      'قالب Word الرسمي + إقرار النشر',
      'مستل من الرسالة للدكتوراه غالباً مطلوب قبل تشكيل لجنة الحكم',
    ],
    requirementsEn: [
      'Original work in languages/literature or social sciences',
      'Double-blind peer review',
      'Official Word template + publication declaration',
      'PhD extract often required before forming the viva committee',
    ],
    submissionUrl: 'https://jssa.journals.ekb.eg',
    portalHintAr:
        'الاستقبال عبر الموقع الإلكتروني للمجلة على بنك المعرفة: jssa.journals.ekb.eg — '
        'بريد اللغات: Languages.journal@women.asu.edu.eg · '
        'بريد العلوم الاجتماعية: S.H.journal@women.asu.edu.eg. '
        'صفحة الوحدة: وحدة النشر العلمي بكلية البنات.',
    portalHintEn:
        'Submit via EKB journal site jssa.journals.ekb.eg — '
        'Languages: Languages.journal@women.asu.edu.eg · '
        'Social sciences: S.H.journal@women.asu.edu.eg.',
  ),
  HumanitiesPublishOutlet(
    id: 'edu_jssr_women_asu',
    nameAr: 'مجلة البحث العلمي في التربية — كلية البنات عين شمس',
    nameEn: 'Journal of Scientific Research in Education — Women’s College, ASU',
    kind: HumanitiesOutletKind.peerReviewedArabic,
    facultyIds: ['Education'],
    publisherAr: 'كلية البنات — جامعة عين شمس',
    publisherEn: 'Faculty of Women — Ain Shams University',
    citationStyle: HumanitiesCitationStyleHint.apaAr,
    citationNotesAr:
        'أصول تربية، مناهج وطرق تدريس، علم نفس تربوي، تكنولوجيا تعليم — غالباً APA. راجع دليل المؤلفين على وحدة النشر.',
    citationNotesEn:
        'Foundations, curriculum, educational psychology, instructional tech — usually APA. Check the unit’s author guide.',
    requirementsAr: [
      'بحث تربوي أصيل قابل للتحكيم',
      'ملخص عربي/إنجليزي',
      'توافق مع مجالات المجلة',
    ],
    requirementsEn: [
      'Original educational research',
      'AR/EN abstracts',
      'Fit to journal scopes',
    ],
    submissionUrl:
        'https://sites.google.com/view/scientificpublishingunit/',
    portalHintAr:
        'من وحدة النشر العلمي بكلية البنات → المجلات العلمية → مجلة البحث العلمي في التربية. '
        'قد يكون التقديم عبر journals.ekb.eg أو بريد التحرير المنشور على الصفحة.',
    portalHintEn:
        'From Women’s College Scientific Publishing Unit → journals → Education journal. '
        'Submission may be via journals.ekb.eg or the listed editorial email.',
  ),
  HumanitiesPublishOutlet(
    id: 'media_egypt_research_cu',
    nameAr: 'المجلة المصرية لبحوث الإعلام — جامعة القاهرة',
    nameEn: 'Egyptian Journal of Media Research — Cairo University',
    kind: HumanitiesOutletKind.peerReviewedArabic,
    facultyIds: ['MassCommunication'],
    publisherAr: 'كلية الإعلام — جامعة القاهرة',
    publisherEn: 'Faculty of Mass Communication — Cairo University',
    citationStyle: HumanitiesCitationStyleHint.apaAr,
    citationNotesAr: 'APA شائع في بحوث الإعلام؛ راجع دليل العدد على منصة EKB إن وُجدت.',
    citationNotesEn: 'APA is common in media research; check the EKB issue guide if available.',
    requirementsAr: [
      'مشكلة إعلامية محددة ومنهج معلن',
      'أداة/تحليل مضمون أو مسح وفق الأسئلة',
      'مستل للدكتوراه وفق لائحة الكلية',
    ],
    requirementsEn: [
      'Defined media problem and stated method',
      'Instrument/content analysis or survey aligned to questions',
      'PhD extract per faculty bylaws',
    ],
    submissionUrl: 'https://cu.edu.eg/ar/publications',
    portalHintAr:
        'راجع قائمة منشورات جامعة القاهرة وروابط مجلات الإعلام على journals.ekb.eg '
        '(بحوث صحافة / إذاعة وتلفزيون / علاقات عامة وإعلان).',
    portalHintEn:
        'See Cairo University publications list and media journals on journals.ekb.eg '
        '(journalism / broadcast / PR & advertising).',
  ),
  HumanitiesPublishOutlet(
    id: 'media_journalism_sci',
    nameAr: 'المجلة العلمية لبحوث الصحافة',
    nameEn: 'Scientific Journal of Journalism Research',
    kind: HumanitiesOutletKind.peerReviewedArabic,
    facultyIds: ['MassCommunication'],
    publisherAr: 'كليات الإعلام المصرية (نمط شائع)',
    publisherEn: 'Egyptian mass-communication faculties (common pattern)',
    citationStyle: HumanitiesCitationStyleHint.apaAr,
    citationNotesAr: 'التزم بدليل المؤلفين لكل عدد؛ لا تفترض Scopus.',
    citationNotesEn: 'Follow each issue’s author guide; do not assume Scopus.',
    requirementsAr: [
      'بحث صحفي/إعلامي محكَّم',
      'خلو من النشر المزدوج',
    ],
    requirementsEn: [
      'Peer-reviewed journalism/media paper',
      'No dual publication',
    ],
    submissionUrl: 'https://www.ekb.eg/',
    portalHintAr: 'ابحث عن المجلة على بنك المعرفة / journals.ekb.eg ثم ارفع عبر نظام المجلة.',
    portalHintEn: 'Find the journal on EKB / journals.ekb.eg then upload via its system.',
  ),
  HumanitiesPublishOutlet(
    id: 'ekb_journals_portal',
    nameAr: 'بوابة مجلات الجامعات المصرية (Journals EKB)',
    nameEn: 'Egyptian university journals portal (Journals EKB)',
    kind: HumanitiesOutletKind.indexedMandumah,
    facultyIds: ['Education', 'Arts', 'Law', 'MassCommunication', 'General'],
    publisherAr: 'بنك المعرفة المصري — منصة التقديم والتحكيم الإلكتروني',
    publisherEn: 'Egyptian Knowledge Bank — e-submission & peer-review platform',
    citationStyle: HumanitiesCitationStyleHint.journalSpecific,
    citationNotesAr:
        'المنصة الرسمية لمعظم مجلات الكليات الحكومية: إنشاء حساب → اختيار المجلة → رفع وفق القالب → متابعة التحكيم.',
    citationNotesEn:
        'Official platform for most public-faculty journals: create account → pick journal → upload per template → track review.',
    requirementsAr: [
      'حساب باحث على نظام المجلة',
      'ملفات وفق دليل المؤلفين',
      'حفظ رقم الطلب وخطاب القبول',
    ],
    requirementsEn: [
      'Author account on the journal system',
      'Files per authors’ guide',
      'Keep request ID and acceptance letter',
    ],
    submissionUrl: 'https://www.ekb.eg/',
    portalHintAr:
        'ابدأ من بنك المعرفة ثم ابحث عن مجلة كليتك (مثال: jssa.journals.ekb.eg). '
        'الرفع على EKB وليس على AcadeGate.',
    portalHintEn:
        'Start at EKB then find your faculty journal (e.g. jssa.journals.ekb.eg). '
        'Upload on EKB, not on AcadeGate.',
    typicallyAcceptedForPromotion: false,
  ),
  HumanitiesPublishOutlet(
    id: 'scu_style_arabic',
    nameAr: 'مجلة عربية محكمة معتمدة (قوائم المجلس الأعلى / الترقية والدكتوراه)',
    nameEn: 'Approved Arabic peer-reviewed journal (SCU lists / promotion & PhD)',
    kind: HumanitiesOutletKind.supremeCouncilJournal,
    facultyIds: [
      'Education',
      'Arts',
      'Law',
      'MassCommunication',
      'General',
    ],
    publisherAr: 'ناشر جامعي/علمي عربي معتمد في التخصص',
    publisherEn: 'Arab university/scholarly publisher approved in the specialty',
    citationStyle: HumanitiesCitationStyleHint.journalSpecific,
    citationNotesAr:
        'للدكتوراه غالباً: مستخرج رسمي بقبول/نشر بحث مستل من الرسالة في مجلة محكمة معتمدة '
        'قبل تشكيل لجنة الحكم. طابق المجلة مع قائمة تخصصك ولسنة التقديم.',
    citationNotesEn:
        'For PhD usually: official proof of acceptance/publication of a thesis-derived paper '
        'in an approved peer-reviewed journal before forming the viva committee. Match your specialty list and year.',
    requirementsAr: [
      'تحقق من اعتماد المجلة في تخصصك لسنة التقديم',
      'بحث مستل من الرسالة (غالباً للدكتوراه)',
      'إقرار عدم النشر المزدوج',
    ],
    requirementsEn: [
      'Verify journal approval for specialty and year',
      'Thesis-derived paper (usually for PhD)',
      'No dual-publication declaration',
    ],
    portalHintAr:
        'افتح موقع المجلة أو journals.ekb.eg → دليل المؤلفين → رفع → احفظ خطاب القبول لمجلس الدراسات العليا.',
    portalHintEn:
        'Open the journal site or journals.ekb.eg → authors’ guide → upload → save acceptance for the graduate board.',
  ),
  HumanitiesPublishOutlet(
    id: 'mandumah_discovery',
    nameAr: 'دار المنظومة — اكتشاف مجلات محكمة مفهرسة',
    nameEn: 'Dar Al-Mandumah — discover indexed peer-reviewed journals',
    kind: HumanitiesOutletKind.indexedMandumah,
    facultyIds: [
      'Education',
      'Arts',
      'Law',
      'MassCommunication',
      'General',
    ],
    publisherAr: 'منصة فهرسة (ليست جهة نشر بذاتها)',
    publisherEn: 'Indexing platform (not a publisher itself)',
    citationStyle: HumanitiesCitationStyleHint.journalSpecific,
    citationNotesAr:
        'المنظومة تساعد على إيجاد مجلات عربية محكمة؛ شروط الاقتباس من دليل كل مجلة بعد اختيارها.',
    citationNotesEn:
        'Mandumah helps find Arabic peer-reviewed journals; citation rules come from each journal’s guide after you pick one.',
    requirementsAr: [
      'ابحث بالموضوع/الكلية',
      'افتح صفحة المجلة الأصلية أو EKB',
      'تحقق من التحكيم والاعتماد قبل الإرسال',
    ],
    requirementsEn: [
      'Search by topic/faculty',
      'Open the original journal page or EKB',
      'Verify peer review and approval before submitting',
    ],
    submissionUrl: 'https://www.mandumah.com/',
    portalHintAr:
        'المنظومة للفهرسة والبحث — الرفع يتم على موقع المجلة/EKB وليس على المنظومة نفسها.',
    portalHintEn:
        'Mandumah is for discovery/indexing — upload on the journal/EKB site, not on Mandumah itself.',
    typicallyAcceptedForPromotion: false,
  ),
];

List<HumanitiesPublishOutlet> humanitiesOutletsForFaculty(String facultyId) {
  final id = facultyId.trim().isEmpty ? 'General' : facultyId;
  return humanitiesPublishCatalog
      .where(
        (o) =>
            o.facultyIds.contains(id) ||
            o.facultyIds.contains('General') ||
            id == 'General',
      )
      .toList();
}

HumanitiesPublishOutlet? humanitiesOutletById(String id) {
  for (final o in humanitiesPublishCatalog) {
    if (o.id == id) return o;
  }
  return null;
}
