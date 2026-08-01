import '../../l10n/app_localizations.dart';
import '../../features/auth/portal_type.dart';
import '../../features/auth/user_role.dart';
import 'app_translate.dart';
import 'locale_service.dart';

/// Central bilingual labels for static data and services without [BuildContext].
class L10nLookup {
  L10nLookup._();

  static String roleLabel(AppLocalizations l10n, String? role) =>
      roleLabelStatic(role);

  static String roleLabelStatic(String? role) {
    switch (role) {
      case UserRole.student:
        return appTr('طالب / باحث', 'Student / Researcher');
      case UserRole.supervisor:
        return appTr('مشرف أكاديمي', 'Academic supervisor');
      case UserRole.merchant:
        return appTr('تاجر / مورد', 'Merchant / Supplier');
      case UserRole.labManager:
        return appTr('مسؤول مختبر', 'Lab manager');
      case UserRole.ideaPublisher:
        return appTr('ناشر أفكار بحثية', 'Research idea publisher');
      case UserRole.admin:
        return appTr('مدير النظام', 'System admin');
      default:
        return appTr('مستخدم', 'User');
    }
  }

  static String portalLabel(AppLocalizations l10n, String? portal) =>
      portalLabelStatic(portal);

  static String portalLabelStatic(String? portal) {
    if (portal == PortalType.provider) {
      return appTr('بوابة مقدم الخدمة', 'Service provider portal');
    }
    if (portal == PortalType.user) {
      return appTr('بوابة المستخدم', 'User portal');
    }
    return portal ?? appTr('البوابة', 'Portal');
  }

  static String facultyTitle(AppLocalizations l10n, String facultyId) =>
      facultyTitleStatic(facultyId);

  static String facultyTitleStatic(String facultyId) {
    switch (facultyId) {
      case 'Engineering':
        return appTr('كلية الهندسة', 'Faculty of Engineering');
      case 'Science':
        return appTr('كلية العلوم', 'Faculty of Science');
      case 'Medicine':
        return appTr('كلية الطب', 'Faculty of Medicine');
      case 'Dentistry':
        return appTr('كلية طب الأسنان', 'Faculty of Dentistry');
      case 'Pharmacy':
        return appTr('كلية الصيدلة', 'Faculty of Pharmacy');
      case 'Nursing':
        return appTr('كلية التمريض', 'Faculty of Nursing');
      case 'Veterinary':
        return appTr('كلية الطب البيطري', 'Faculty of Veterinary Medicine');
      case 'Law':
        return appTr('كلية الحقوق', 'Faculty of Law');
      case 'CS':
        return appTr('كلية الحاسبات', 'Faculty of Computer Science');
      case 'Agriculture':
        return appTr('كلية الزراعة', 'Faculty of Agriculture');
      case 'Business':
        return appTr('كلية التجارة', 'Faculty of Commerce');
      case 'Education':
        return appTr('كلية التربية', 'Faculty of Education');
      case 'Arts':
        return appTr('كلية الآداب', 'Faculty of Arts');
      case 'Architecture':
        return appTr('كلية العمارة', 'Faculty of Architecture');
      case 'MassCommunication':
        return appTr('كلية الإعلام', 'Faculty of Media');
      case 'Tourism':
        return appTr('كلية السياحة والفنادق', 'Faculty of Tourism & Hotels');
      case 'PhysicalEducation':
        return appTr('كلية التربية الرياضية', 'Faculty of Physical Education');
      case 'FineArts':
        return appTr('كلية الفنون الجميلة', 'Faculty of Fine Arts');
      default:
        return facultyId;
    }
  }

  static String supervisorsTitleForCategory(String facultyId) {
    final title = facultyTitleStatic(facultyId);
    if (LocaleService.instance.isEnglish) {
      final short = title.replaceFirst('Faculty of ', '');
      return '$short Supervisors';
    }
    if (title.startsWith('كلية ')) {
      return 'مشرفو ${title.replaceFirst('كلية ', '')}';
    }
    return 'مشرفو $title';
  }

  static String storeCategoryTitle(String id) {
    switch (id) {
      case 'chemicals':
      case 'chemical': // legacy id
        return appTr('كيميائيات وكواشف', 'Chemicals & reagents');
      case 'biology':
        return appTr('بيولوجيا وتقنية حيوية', 'Biology & biotech');
      case 'medical':
        return appTr('طبي وصيدلي وسريري', 'Medical & clinical');
      case 'engineering':
        return appTr('هندسة وإلكترونيات', 'Engineering & electronics');
      case 'physics_materials':
        return appTr('فيزياء ومواد', 'Physics & materials');
      case 'agriculture':
      case 'agricultural': // legacy id
        return appTr('زراعة وبيطري', 'Agriculture & veterinary');
      case 'computing':
        return appTr('حوسبة وبرمجيات بحثية', 'Computing & research software');
      case 'consumables':
        return appTr('مستهلكات وأدوات مختبر', 'Lab consumables & tools');
      case 'instruments':
        return appTr('أجهزة وأدوات قياس', 'Instruments & measurement');
      case 'safety':
        return appTr('سلامة ومعدات وقاية', 'Safety & PPE');
      case 'field':
        return appTr('أدوات ميدانية ومسح', 'Field & survey tools');
      case 'books':
        return appTr('كتب ومراجع علمية', 'Books & references');
      case 'humanities':
        return appTr(
          'إنسانيات وتربية وبحث اجتماعي',
          'Humanities & social research',
        );
      case 'office':
        return appTr(
          'مستلزمات كتابة وتوثيق البحث',
          'Research writing & documentation',
        );
      case 'general':
        return appTr('مستلزمات عامة', 'General supplies');
      default:
        return id;
    }
  }

  static String writingTitle(String id) {
    switch (id) {
      case 'research_paper':
        return appTr('أوراق بحثية', 'Research papers');
      case 'thesis':
        return appTr('رسائل علمية', 'Theses');
      case 'statistics':
        return appTr('إحصاء وتحليل', 'Statistics & analysis');
      case 'literature_review':
        return appTr('مراجعة أدبيات', 'Literature review');
      case 'proposal':
        return appTr('مقترحات بحث', 'Research proposals');
      case 'editing':
        return appTr('تحرير وتدقيق', 'Editing & proofreading');
      case 'formatting':
        return appTr('تنسيق وتوثيق', 'Formatting & citations');
      case 'translation':
        return appTr('ترجمة علمية', 'Academic translation');
      default:
        return id;
    }
  }

  static String writingSubtitle(String id) {
    switch (id) {
      case 'research_paper':
        return appTr(
          'مقالات، أوراق مؤتمرات، نشر علمي',
          'Articles, conference papers, publishing',
        );
      case 'thesis':
        return appTr(
          'ماجستير، دكتوراه، مشروع تخرج',
          'Master\'s, PhD, graduation project',
        );
      case 'statistics':
        return appTr(
          'SPSS، R، Excel، تفسير النتائج',
          'SPSS, R, Excel, results interpretation',
        );
      case 'literature_review':
        return appTr('نقد، تلخيص، خريطة مفاهيمية', 'Critique, summary, concept map');
      case 'proposal':
        return appTr('خطة بحث، أهداف، منهجية', 'Research plan, objectives, methodology');
      case 'editing':
        return appTr('لغة، أسلوب، إعادة صياغة', 'Language, style, paraphrasing');
      case 'formatting':
        return appTr('APA، MLA، Harvard، IEEE', 'APA, MLA, Harvard, IEEE');
      case 'translation':
        return appTr(
          'عربي ↔ إنجليزي، مصطلحات دقيقة',
          'Arabic ↔ English, precise terminology',
        );
      default:
        return '';
    }
  }

  static String communityRoomTitle(String id) {
    switch (id) {
      case 'engineering':
      case 'Engineering':
        return appTr('هندسة', 'Engineering');
      case 'science':
      case 'Science':
        return appTr('علوم', 'Science');
      case 'medicine':
      case 'Medicine':
        return appTr('طب', 'Medicine');
      case 'Dentistry':
        return appTr('طب أسنان', 'Dentistry');
      case 'Pharmacy':
        return appTr('صيدلة', 'Pharmacy');
      case 'Nursing':
        return appTr('تمريض', 'Nursing');
      case 'Veterinary':
        return appTr('طب بيطري', 'Veterinary');
      case 'law':
      case 'Law':
        return appTr('حقوق', 'Law');
      case 'cs':
      case 'CS':
        return appTr('حاسبات', 'Computer Science');
      case 'agriculture':
      case 'Agriculture':
        return appTr('زراعة', 'Agriculture');
      case 'Business':
        return appTr('تجارة', 'Business');
      case 'Education':
        return appTr('تربية', 'Education');
      case 'Arts':
        return appTr('آداب', 'Arts');
      case 'Architecture':
        return appTr('عمارة', 'Architecture');
      case 'MassCommunication':
        return appTr('إعلام', 'Media');
      case 'Tourism':
        return appTr('سياحة وفنادق', 'Tourism & Hotels');
      case 'PhysicalEducation':
        return appTr('تربية رياضية', 'Physical Education');
      case 'FineArts':
        return appTr('فنون جميلة', 'Fine Arts');
      case 'general':
        return appTr('عام', 'General');
      default:
        return id;
    }
  }

  static String communityRoomDescription(String id) {
    switch (id) {
      case 'engineering':
      case 'Engineering':
        return appTr(
          'أسئلة ونقاشات ومجموعات دراسة هندسية',
          'Engineering questions, discussions, and study groups',
        );
      case 'science':
      case 'Science':
        return appTr(
          'علوم أساسية: كيمياء، فيزياء، أحياء ورياضيات',
          'Basic sciences: chemistry, physics, biology, and math',
        );
      case 'medicine':
      case 'Medicine':
        return appTr(
          'حالات سريرية ودراسات طبية',
          'Clinical cases and medical studies',
        );
      case 'Dentistry':
        return appTr(
          'نقاشات وبحوث طب الأسنان',
          'Dentistry discussions and research',
        );
      case 'Pharmacy':
        return appTr(
          'صيدلة سريرية وصناعية وبحوث دوائية',
          'Clinical/industrial pharmacy and drug research',
        );
      case 'Nursing':
        return appTr(
          'تمريض سريري وبحوث رعاية صحية',
          'Clinical nursing and healthcare research',
        );
      case 'Veterinary':
        return appTr(
          'طب بيطري وصحة حيوانية',
          'Veterinary medicine and animal health',
        );
      case 'law':
      case 'Law':
        return appTr('قانون وبحوث قانونية', 'Law and legal research');
      case 'cs':
      case 'CS':
        return appTr(
          'برمجة، ذكاء اصطناعي، وبيانات',
          'Programming, AI, and data',
        );
      case 'agriculture':
      case 'Agriculture':
        return appTr(
          'أبحاث زراعية وبيئية',
          'Agricultural and environmental research',
        );
      case 'Business':
        return appTr(
          'إدارة، محاسبة، واقتصاد وبحوث تجارية',
          'Management, accounting, economics, and business research',
        );
      case 'Education':
        return appTr(
          'تربية ومناهج وبحوث تعليمية',
          'Education, curricula, and teaching research',
        );
      case 'Arts':
        return appTr(
          'آداب ولغات وعلوم إنسانية',
          'Arts, languages, and humanities',
        );
      case 'Architecture':
        return appTr(
          'تصميم عمراني ومعماري ونقاشات المشاريع',
          'Architectural design and project discussions',
        );
      case 'MassCommunication':
        return appTr(
          'إعلام وصحافة واتصال جماهيري',
          'Media, journalism, and mass communication',
        );
      case 'Tourism':
        return appTr(
          'سياحة وضيافة وإدارة فنادق',
          'Tourism, hospitality, and hotel management',
        );
      case 'PhysicalEducation':
        return appTr(
          'رياضة وعلوم حركة وبحوث بدنية',
          'Sports, movement science, and physical research',
        );
      case 'FineArts':
        return appTr(
          'فنون تشكيلية وتصميم ونقد فني',
          'Fine arts, design, and art criticism',
        );
      case 'general':
        return appTr(
          'مواضيع أكاديمية متعددة التخصصات',
          'Cross-disciplinary academic topics',
        );
      default:
        return '';
    }
  }

  static String communityPostTypeLabel(String? type) {
    switch (type) {
      case 'question':
        return appTr('سؤال', 'Question');
      case 'discussion':
        return appTr('نقاش', 'Discussion');
      case 'announcement':
        return appTr('إعلان مناقشة', 'Seminar announcement');
      case 'study_group':
        return appTr('مجموعة دراسة', 'Study group');
      default:
        return appTr('منشور', 'Post');
    }
  }

  static String approvalStatusLabel(String? value) {
    switch (value) {
      case 'pending':
        return appTr('بانتظار المراجعة', 'Pending review');
      case 'approved':
        return appTr('معتمد', 'Approved');
      case 'rejected':
        return appTr('مرفوض', 'Rejected');
      case 'suspended':
        return appTr('موقوف', 'Suspended');
      default:
        return value ?? appTr('غير محدد', 'Unknown');
    }
  }

  static String paymentStatusLabel(String status) {
    switch (status) {
      case 'paid_held':
        return appTr('مدفوع — محجوز', 'Paid — held in escrow');
      case 'released':
        return appTr('تم التسليم للبائع', 'Released to seller');
      case 'refunded':
        return appTr('مسترد', 'Refunded');
      default:
        return appTr('بانتظار الدفع', 'Pending payment');
    }
  }

  static String get save => appTr('حفظ', 'Save');
  static String get delete => appTr('حذف', 'Delete');
  static String get edit => appTr('تعديل', 'Edit');
  static String get submit => appTr('إرسال', 'Submit');
  static String get approve => appTr('موافقة', 'Approve');
  static String get reject => appTr('رفض', 'Reject');
  static String get back => appTr('رجوع', 'Back');
  static String get search => appTr('بحث', 'Search');
  static String get noResults => appTr('لا توجد نتائج', 'No results');
  static String get loading => appTr('جاري التحميل...', 'Loading...');
  static String get error => appTr('حدث خطأ', 'An error occurred');
  static String get success => appTr('تم بنجاح', 'Success');
  static String get required => appTr('مطلوب', 'Required');
  static String get optional => appTr('اختياري', 'Optional');
  static String get yes => appTr('نعم', 'Yes');
  static String get no => appTr('لا', 'No');
  static String get close => appTr('إغلاق', 'Close');
  static String get details => appTr('التفاصيل', 'Details');
  static String get preview => appTr('معاينة', 'Preview');
  static String get loginRequired => appTr('تسجيل الدخول مطلوب', 'Sign-in required');
  static String get loginRequiredMessage =>
      appTr('يجب تسجيل الدخول للمتابعة.', 'You must sign in to continue.');
  static String get sentForReview =>
      appTr('تم الإرسال للمراجعة', 'Sent for review');
  static String get cancel => appTr('إلغاء', 'Cancel');
  static String get refresh => appTr('تحديث', 'Refresh');
  static String get all => appTr('الكل', 'All');
  static String get item => appTr('عنصر', 'Item');
  static String get data => appTr('بيانات', 'Data');
  static String get product => appTr('منتج', 'Product');
  static String get user => appTr('مستخدم', 'User');
  static String get conversation => appTr('محادثة', 'Conversation');
  static String get notifications => appTr('الإشعارات', 'Notifications');
  static String get markAllRead => appTr('قراءة الكل', 'Mark all read');
  static String get deleteAll => appTr('حذف الكل', 'Delete all');
  static String deleteNotificationConfirm(String title) => appTr(
        'هل تريد حذف هذا الإشعار؟\n«$title»',
        'Delete this notification?\n"$title"',
      );
  static String get deleteAllNotificationsConfirm => appTr(
        'هل تريد حذف جميع الإشعارات؟\nلا يمكن التراجع عن هذا الإجراء.',
        'Delete all notifications?\nThis cannot be undone.',
      );
  static String get noNotifications => appTr('لا إشعارات', 'No notifications');
  static String get messages => appTr('الرسائل', 'Messages');
  static String get supervisor => appTr('مشرف', 'Supervisor');
  static String get lab => appTr('مختبر', 'Lab');
  static String get researchIdea => appTr('فكرة بحثية', 'Research idea');
  static String get communityPost => appTr('منشور', 'Post');
  static String get communityPostFull => appTr('منشور مجتمع', 'Community post');
  static String get institution => appTr('مؤسسة', 'Institution');
  static String get researcher => appTr('باحث', 'Researcher');
  static String get academicResearch => appTr('بحث أكاديمي', 'Academic research');
  static String get confirmDelete => appTr('تأكيد الحذف', 'Confirm deletion');
  static String get deleteFromApp => appTr('حذف من التطبيق', 'Delete from app');
  static String get availableServices =>
      appTr('الخدمات المتاحة', 'Available services');
  static String get noSearchMatches => appTr(
        'لم نجد نتائج. جرّب اسماً أقصر أو كلمة من التخصص/الجامعة/المختبر.',
        'No results. Try a shorter name or a specialty/university/lab keyword.',
      );
  static String get searchMinCharsHint => appTr(
        'اكتب حرفين على الأقل للبحث في كل الأقسام',
        'Type at least 2 characters to search all sections',
      );
  static String get sectionsAndServices =>
      appTr('الأقسام والخدمات', 'Sections & services');
  static String get inSectionServices =>
      appTr('خدمات داخل الأقسام', 'In-section services');
  static String get faculties => appTr('الكليات', 'Faculties');
  static String get supervisorsSection =>
      appTr('قسم المشرفون', 'Supervisors section');
  static String get academicSupervisors =>
      appTr('المشرفون الأكاديميون', 'Academic supervisors');
  static String get researchIdeas => appTr('أفكار بحثية', 'Research ideas');
  static String get labs => appTr('المختبرات', 'Labs');
  static String get storeCategories => appTr('أقسام المتجر', 'Store categories');
  static String get storeProducts => appTr('منتجات المتجر', 'Store products');
  static String get writingExperts =>
      appTr('خبراء الكتابة', 'Writing experts');
  static String get communityPosts =>
      appTr('منشورات المجتمع', 'Community posts');
  static String get scienceNewsArticles =>
      appTr('أخبار علمية', 'Science news');
  static String get researchRooms =>
      appTr('غرف بحثية', 'Research rooms');
  static String get noDescription =>
      appTr('لا يوجد وصف متاح.', 'No description available.');
  static String get unknownStore => appTr('متجر غير معروف', 'Unknown store');
  static String get live => appTr('مباشر', 'Live');
  static String get noPublicationData => appTr('لا بيانات نشر', 'No publication data');
  static String get scientificOutput =>
      appTr('الإنتاج العلمي', 'Scientific output');
  static String get scientificOutputAndJournals => appTr(
        'الإنتاج العلمي والمجلات',
        'Scientific output & journals',
      );
  static String get publications => appTr('منشورات', 'Publications');
  static String get citations => appTr('استشهادات', 'Citations');
  static String get topJournals =>
      appTr('أبرز المجلات التي نُشر فيها', 'Top journals published in');
  static String get viewOnGoogleScholar =>
      appTr('عرض على Google Scholar', 'View on Google Scholar');
  static String get noSupervisorPublicationData => appTr(
        'لا تتوفر بيانات نشر لهذا المشرف.',
        'No publication data for this supervisor.',
      );
  static String get selectAll => appTr('تحديد الكل', 'Select all');
  static String get copyAll => appTr('نسخ الكل', 'Copy all');
  static String get autoApprove => appTr('موافقة تلقائية', 'Auto-approve');
  static String get community => appTr('مجتمع', 'Community');
  static String get ideas => appTr('أفكار', 'Ideas');
  static String get products => appTr('منتجات', 'Products');
  static String get supervisorsPlural => appTr('مشرفون', 'Supervisors');
  static String get labsPlural => appTr('مختبرات', 'Labs');

  static String currencyEgp(num price) => appTr('$price ج.م', '$price EGP');

  static String searchResultsFor(String query) =>
      appTr('نتائج البحث عن: ($query)', 'Search results for: ($query)');

  static String listSeparator() => appTr('، ', ', ');

  static String currencyPriceCategory(String category, num price) =>
      appTr('$category • $price ج.م', '$category • $price EGP');

  static String collectionLabel(String collection) {
    switch (collection) {
      case 'supervisors':
        return supervisor;
      case 'labs':
        return lab;
      case 'product':
        return product;
      case 'research_ideas':
        return researchIdea;
      case 'community_posts':
        return communityPostFull;
      default:
        return collection;
    }
  }

  static String collectionLabelPlural(String collection) {
    switch (collection) {
      case 'supervisors':
        return supervisorsPlural;
      case 'labs':
        return labsPlural;
      case 'product':
        return products;
      case 'research_ideas':
        return ideas;
      case 'community_posts':
        return community;
      default:
        return collection;
    }
  }

  static String filterChipLabel(String collection, int count) =>
      '${collectionLabelPlural(collection)} ($count)';

  static String contentTitleFallback(String collection) {
    switch (collection) {
      case 'supervisors':
        return supervisor;
      case 'labs':
        return lab;
      case 'product':
        return product;
      case 'research_ideas':
        return researchIdea;
      case 'community_posts':
        return communityPost;
      default:
        return item;
    }
  }

  static String moderationDetailField(String field) {
    switch (field) {
      case 'name':
        return appTr('الاسم', 'Name');
      case 'university':
        return appTr('الجامعة', 'University');
      case 'speciality':
        return appTr('التخصص', 'Speciality');
      case 'faculty':
        return appTr('الكلية', 'Faculty');
      case 'category':
        return appTr('التصنيف', 'Category');
      case 'methodology':
        return appTr('المنهجية', 'Methodology');
      case 'available':
        return appTr('متاح', 'Available');
      case 'bio':
        return appTr('نبذة', 'Bio');
      case 'tags':
        return appTr('الوسوم', 'Tags');
      case 'location':
        return appTr('الموقع', 'Location');
      case 'city':
        return appTr('المدينة', 'City');
      case 'equipment':
        return appTr('الأجهزة', 'Equipment');
      case 'equipmentList':
        return appTr('قائمة الأجهزة', 'Equipment list');
      case 'price':
        return appTr('السعر', 'Price');
      case 'department':
        return appTr('القسم', 'Department');
      case 'description':
        return appTr('الوصف', 'Description');
      case 'store':
        return appTr('المتجر', 'Store');
      case 'contact':
        return appTr('التواصل', 'Contact');
      case 'title':
        return appTr('العنوان', 'Title');
      case 'provider':
        return appTr('الجهة', 'Provider');
      case 'details':
        return appTr('التفاصيل', 'Details');
      case 'budget':
        return appTr('الميزانية', 'Budget');
      case 'status':
        return appTr('الحالة', 'Status');
      case 'room':
        return appTr('الغرفة', 'Room');
      case 'type':
        return appTr('النوع', 'Type');
      case 'content':
        return appTr('المحتوى', 'Content');
      case 'author':
        return appTr('الكاتب', 'Author');
      case 'eventDate':
        return appTr('تاريخ المناقشة', 'Discussion date');
      default:
        return field;
    }
  }

  static String equipmentLine(String name, num cost, int waitDays) => appTr(
        '• $name — $cost ج.م — انتظار $waitDays يوم',
        '• $name — $cost EGP — $waitDays day wait',
      );

  static List<String> get defaultMethodologies => [
        appTr('كمي', 'Quantitative'),
        appTr('نوعي', 'Qualitative'),
        appTr('مختلط', 'Mixed'),
      ];

  static String supervisorBioDefault(String field) =>
      appTr('مشرف أكاديمي في $field', 'Academic supervisor in $field');

  static String researcherBio(
    String institution,
    int works,
    int citations,
  ) =>
      appTr(
        'باحث في $institution. $works منشور، $citations استشهاد.',
        'Researcher at $institution. $works publications, $citations citations.',
      );

  static String researcherBioDetailed({
    required String institution,
    required int works,
    required int citations,
    required int hIndex,
    required String speciality,
  }) {
    final place = institution.trim().isEmpty
        ? appTr('جهة غير محددة', 'unspecified institution')
        : institution;
    return appTr(
      'باحث في $place. التخصص الرئيسي: $speciality. '
      '$works منشور، $citations استشهاد، h-index: $hIndex. '
      'البيانات من OpenAlex وتحتاج مراجعة إدارية قبل النشر.',
      'Researcher at $place. Main field: $speciality. '
      '$works publications, $citations citations, h-index: $hIndex. '
      'Data from OpenAlex and requires admin review before publishing.',
    );
  }

  static String journalTierLabel(double citedness) {
    if (citedness >= 5) {
      return appTr('تأثير مرتفع جداً (≈ Q1)', 'Very high impact (≈ Q1)');
    }
    if (citedness >= 2) {
      return appTr('تأثير مرتفع (≈ Q1–Q2)', 'High impact (≈ Q1–Q2)');
    }
    if (citedness >= 1) {
      return appTr('تأثير جيد (≈ Q2–Q3)', 'Good impact (≈ Q2–Q3)');
    }
    if (citedness >= 0.3) {
      return appTr('تأثير معتدل (≈ Q3–Q4)', 'Moderate impact (≈ Q3–Q4)');
    }
    return appTr('تأثير قياسي', 'Standard impact');
  }

  static String publicationsCount(int count) =>
      appTr('$count منشور', '$count publications');

  static String citationsCount(int count) =>
      appTr('$count استشهاد', '$count citations');

  static String q1q2JournalsCount(int count) =>
      appTr('$count مجلة Q1–Q2', '$count Q1–Q2 journals');

  static String researchCount(int count) => appTr('$count بحث', '$count papers');

  static String itemDeleted(String label) =>
      appTr('تم حذف «$label»', 'Deleted "$label"');

  static String deleteConfirmMessage(String label) => appTr(
        'هل تريد حذف «$label» نهائياً؟\nلا يمكن التراجع عن هذا الإجراء.',
        'Delete "$label" permanently?\nThis cannot be undone.',
      );

  static String deleteFailed(Object error) =>
      appTr('تعذر الحذف: $error', 'Could not delete: $error');

  static String ownerIdLabel(String id) =>
      appTr('معرّف المالك: $id', 'Owner ID: $id');

  static String currentRoleLabel(String role) => appTr(
        'الدور الحالي: $role',
        'Current role: $role',
      );

  static String roleUpdated(String name) =>
      appTr('تم تحديث دور $name', 'Updated role for $name');

  static String get approvedSnack => appTr('تمت الموافقة', 'Approved');
  static String get rejectedSnack => appTr('تم الرفض', 'Rejected');

  static String csvMissingNameColumn() => appTr(
        'الملف يجب أن يحتوي على عمود name أو الاسم',
        'File must contain a name or الاسم column',
      );

  static String orcidMissingNote() => appTr(
        'لا يوجد ORCID أو معرّف OpenAlex — أضفهما عند تسجيل المشرف لعرض الإنتاج العلمي.',
        'No ORCID or OpenAlex ID — add them when registering the supervisor to show publications.',
      );

  static String openAlexScimagoNote(int matches) => appTr(
        'البيانات من OpenAlex مع تصنيف Scimago الرسمي (Q1–Q4) لـ $matches مجلة مطابقة.',
        'Data from OpenAlex with official Scimago quartiles (Q1–Q4) for $matches matched journals.',
      );

  static String openAlexEstimateNote() => appTr(
        'البيانات من OpenAlex — لم تُطابق المجلات قاعدة Scimago؛ يُعرض تقدير التأثير فقط.',
        'Data from OpenAlex — journals did not match Scimago; showing impact estimate only.',
      );

  static String publicationLoadFailed() => appTr(
        'تعذر تحميل بيانات النشر حالياً.',
        'Could not load publication data right now.',
      );

  static String storedImportMetricsNote() => appTr(
        'أرقام محفوظة عند الاستيراد — افتح الملف لتحديث التفاصيل.',
        'Numbers saved at import — open the profile to refresh details.',
      );

  static String scholarLinkFailed() => appTr(
        'تعذر فتح رابط Google Scholar',
        'Could not open Google Scholar link',
      );

  static String newMessageTitle() => appTr('رسالة جديدة', 'New message');

  static String paymentConfirmTitle() => appTr('تأكيد دفع', 'Payment confirmed');

  static String paymentConfirmBody(num amount, String title) => appTr(
        'تم استلام دفعة بقيمة $amount ج.م — $title',
        'Payment of $amount EGP received — $title',
      );

  static String paymentReleasedTitle() =>
      appTr('تم تحرير الدفعة', 'Payment released');

  static String paymentReleasedBody(String title) => appTr(
        'تم إفراج المبلغ لطلب: $title',
        'Funds released for order: $title',
      );

  static String refundTitle() => appTr('استرداد', 'Refund');

  static String refundBody(String title) => appTr(
        'تم استرداد المبلغ لطلب: $title',
        'Refund issued for order: $title',
      );

  static String get chooseFaculty => appTr('اختر الكلية', 'Choose faculty');

  static String get importSupervisors =>
      appTr('استيراد مشرفين', 'Import supervisors');

  static String get reviewSupervisorsApproveReject => appTr(
        'مراجعة المشرفين — موافقة / رفض',
        'Review supervisors — approve / reject',
      );

  static String get registerAsSupervisor =>
      appTr('سجّل كمشرف', 'Register as supervisor');

  static String get supervisorSubmittedForReview => appTr(
        'تم إرسال ملف المشرف للمراجعة',
        'Supervisor profile submitted for review',
      );

  static String supervisorsPendingApproval(int count) => appTr(
        '$count مشرف بانتظار الموافقة',
        '$count supervisor(s) pending approval',
      );

  static String get tapToApproveOrReject =>
      appTr('اضغط للموافقة أو الرفض', 'Tap to approve or reject');

  static String get reviewPending =>
      appTr('مراجعة المعلقين', 'Review pending');

  static String get noSupervisorsYet =>
      appTr('لا يوجد مشرفون بعد', 'No supervisors yet');

  static String supervisorCount(int count) =>
      appTr('$count مشرف', '$count supervisor(s)');

  static String supervisorPreviewSubtitle(
    int count,
    String names,
    String extra,
  ) =>
      appTr(
        '$count مشرف • $names$extra',
        '$count supervisor(s) • $names$extra',
      );

  static String get noSupervisorsInCategory => appTr(
        'لا يوجد مشرفون في هذا القسم',
        'No supervisors in this section',
      );

  static String get supervisorProfile =>
      appTr('الملف الشخصي', 'Profile');

  static String specialityLabel(String speciality) =>
      appTr('التخصص: $speciality', 'Speciality: $speciality');

  static String get supervisorBioSection =>
      appTr('نبذة عن المشرف:', 'About the supervisor:');

  static String get messageSupervisor => appTr('مراسلة', 'Message');

  static String get requestSupervisionLabel =>
      appTr('طلب إشراف', 'Request supervision');

  static String professorBioDefault(String field) => appTr(
        'أستاذ متخصص في $field.',
        'Professor specialising in $field.',
      );
}
