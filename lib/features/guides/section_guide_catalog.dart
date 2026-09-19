import 'package:flutter/material.dart';

import 'section_guide_catalog_rest.dart';
import 'section_guide_models.dart';

/// أدلة الأقسام — نص للمبتدئ الذي لا يعرف التطبيق بعد.
class SectionGuideCatalog {
  SectionGuideCatalog._();

  static const String supervisors = 'supervisors';
  static const String store = 'store';
  static const String labs = 'labs';
  static const String writing = 'writing';
  static const String publish = 'publish';
  static const String matchmaking = 'matchmaking';
  static const String ideas = 'ideas';
  static const String researchPath = 'research_path';
  static const String community = 'community';
  static const String ai = 'ai';
  static const String thesisStudio = 'thesis_studio';
  static const String integrity = 'integrity';
  static const String fund = 'fund';
  static const String news = 'news';

  static SectionGuide? byId(String id) {
    switch (id) {
      case supervisors:
        return supervisorsGuide;
      case store:
        return storeGuide;
      case labs:
        return labsGuide;
      case writing:
        return writingGuide;
      case publish:
        return publishGuide;
      case matchmaking:
        return SectionGuideCatalogRest.matchmakingGuide;
      case ideas:
        return SectionGuideCatalogRest.ideasGuide;
      case researchPath:
        return SectionGuideCatalogRest.researchPathGuide;
      case community:
        return SectionGuideCatalogRest.communityGuide;
      case ai:
        return SectionGuideCatalogRest.aiGuide;
      case thesisStudio:
        return SectionGuideCatalogRest.thesisStudioGuide;
      case integrity:
        return SectionGuideCatalogRest.integrityGuide;
      case fund:
        return SectionGuideCatalogRest.fundGuide;
      case news:
        return SectionGuideCatalogRest.newsGuide;
      default:
        return null;
    }
  }

  static const SectionGuide supervisorsGuide = SectionGuide(
    id: supervisors,
    titleAr: 'دليل المشرفين الأكاديميين',
    titleEn: 'Academic supervisors guide',
    introAr:
        'هذا القسم يساعدك على إيجاد مشرف أكاديمي (أستاذ/باحث) مناسب لتخصصك، '
        'قراءة ملفه، ثم مراسلته أو طلب إشراف عبر التطبيق. '
        'لا تحتاج خبرة تقنية: اتبع الخطوات بالترتيب من الأعلى للأسفل.',
    introEn:
        'This section helps you find an academic supervisor who fits your field, '
        'read their profile, then message them or request supervision in the app. '
        'No tech experience needed — follow the steps in order.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول أولاً',
        titleEn: '1) Sign in first',
        bodyAr:
            'من الشاشة الرئيسية افتح حسابك (أيقونة الحساب أعلى اليمين عادةً) وسجّل الدخول '
            'بالبريد وكلمة المرور، أو أنشئ حساباً جديداً إن لم يكن لديك واحد.\n'
            'بدون تسجيل دخول لن تتمكن من إرسال رسائل أو طلبات إشراف بشكل موثوق.\n'
            'بعد الدخول، أكمل ملفك الأكاديمي إن ظهر لك: الكلية، التخصص، الدرجة (ماجستير/دكتوراه). '
            'هذا يساعد لاحقاً على اقتراحات أفضل.',
        bodyEn:
            'From Home, open your account (usually the avatar at the top) and sign in '
            'with email and password, or create an account if you are new.\n'
            'Without sign-in you cannot reliably send messages or supervision requests.\n'
            'After signing in, complete your academic profile if prompted: faculty, specialty, degree. '
            'That improves later recommendations.',
      ),
      SectionGuideStep(
        icon: Icons.school_outlined,
        titleAr: '٢) افتح قسم المشرفين',
        titleEn: '2) Open Supervisors',
        bodyAr:
            'من الصفحة الرئيسية ابحث عن بطاقة أو زر «المشرفون» / «Supervisors» واضغط عليها.\n'
            'ستظهر لك شاشة «اختر الكلية»: قائمة كليات (طب، هندسة، علوم، …).\n'
            'كل بطاقة كلية تعرض تقريباً عدد المشرفين المتاحين وأسماء قليلة كمثال.',
        bodyEn:
            'On Home, tap «Supervisors».\n'
            'You will see «Choose faculty»: a list of faculties (Medicine, Engineering, Sciences, …).\n'
            'Each faculty card shows roughly how many supervisors are listed and a few sample names.',
      ),
      SectionGuideStep(
        icon: Icons.category_outlined,
        titleAr: '٣) اختر كليتك',
        titleEn: '3) Choose your faculty',
        bodyAr:
            'اضغط على الكلية الأقرب لتخصصك (مثلاً «الزراعة» أو «العلوم»).\n'
            'ستفتح قائمة بأسماء المشرفين في هذه الكلية فقط.\n'
            'إذا كنت في دراسات مهنية قد تظهر شاشة خاصة للبرامج المهنية — اختر ما يناسبك منها.',
        bodyEn:
            'Tap the faculty closest to your field (e.g. Agriculture or Sciences).\n'
            'A list of supervisors in that faculty opens.\n'
            'Professional studies may open a dedicated hub — pick what fits you.',
      ),
      SectionGuideStep(
        icon: Icons.person_search_outlined,
        titleAr: '٤) تصفّح قائمة المشرفين',
        titleEn: '4) Browse the list',
        bodyAr:
            'كل صف عادةً يعرض: الاسم، الجامعة/الجهة، ومجال الاهتمام إن وُجد.\n'
            'مرّر للأسفل لرؤية المزيد. اضغط على أي مشرف لفتح صفحته التفصيلية.\n'
            'لا تختر عشوائياً: اقرأ التخصص والمنشورات إن ظهرت قبل التواصل.',
        bodyEn:
            'Each row usually shows: name, university/affiliation, and research interest if available.\n'
            'Scroll for more. Tap any supervisor to open their detail page.\n'
            'Do not pick at random — read specialty and publications before contacting.',
      ),
      SectionGuideStep(
        icon: Icons.badge_outlined,
        titleAr: '٥) اقرأ صفحة المشرف',
        titleEn: '5) Read the profile page',
        bodyAr:
            'في صفحة المشرف ستجد غالباً:\n'
            '• الاسم والكلية/التخصص\n'
            '• نبذة أو مجالات بحث\n'
            '• روابط أو منشورات إن كانت متوفرة\n'
            'اقرأ بهدوء. الهدف أن تعرف هل اهتماماته قريبة من موضوع رسالتك.',
        bodyEn:
            'On the profile page you typically see:\n'
            '• Name and faculty/specialty\n'
            '• Bio or research areas\n'
            '• Links or publications when available\n'
            'Read carefully. Goal: decide if their interests match your thesis topic.',
      ),
      SectionGuideStep(
        icon: Icons.chat_outlined,
        titleAr: '٦) راسل المشرف من داخل التطبيق',
        titleEn: '6) Message the supervisor in-app',
        bodyAr:
            'زر «مراسلة المشرف» / Message يفتح محادثة داخل AcadeGate.\n'
            'اكتب رسالة مهذبة قصيرة تتضمن: اسمك، جامعتك، موضوع البحث المقترح، وسبب اختيارك له.\n'
            'لا ترسل بيانات حساسة (كلمات مرور، بطاقات بنكية).\n'
            'ستجد المحادثة لاحقاً من أيقونة الرسائل في التطبيق.',
        bodyEn:
            '«Message supervisor» opens an in-app chat.\n'
            'Write a short polite note: your name, university, proposed topic, and why you chose them.\n'
            'Never send passwords or banking data.\n'
            'Find the thread later under Messages in the app.',
      ),
      SectionGuideStep(
        icon: Icons.how_to_reg_outlined,
        titleAr: '٧) إن كنت أنت المشرف الظاهر في القائمة',
        titleEn: '7) If YOU are the listed supervisor',
        bodyAr:
            'إذا وجدت صفحتك منشورة مسبقاً (من قواعد بيانات أكاديمية) واسمك صحيح:\n'
            'اضغط «هذا أنا — ربط حسابي».\n'
            'سيُطلب تأكيد؛ بعد الربط تصبح طلبات الإشراف والرسائل موجّهة لحسابك.\n'
            'إن لم تجد اسمك: استخدم زر «التسجيل كمشرف» أعلى الشاشة أو الزر العائم في قائمة الكلية، '
            'واملأ النموذج ثم انتظر المراجعة إن لزم.',
        bodyEn:
            'If your profile is already listed and the name is correct:\n'
            'Tap «This is me — link my account».\n'
            'Confirm; then supervision requests and messages go to your account.\n'
            'If you are not listed: use «Register as supervisor» (app bar or floating button), '
            'submit the form, and wait for review if required.',
      ),
      SectionGuideStep(
        icon: Icons.auto_awesome_outlined,
        titleAr: '٨) المطابقة الذكية (اختياري)',
        titleEn: '8) Smart match (optional)',
        bodyAr:
            'قد ترى بانر «مطابقة ذكية» أعلى قائمة الكليات.\n'
            'إن أكملت ملفك الأكاديمي، يمكن أن يقترح التطبيق مشرفين أقرب لتخصصك.\n'
            'استخدمها كمساعدة — القرار النهائي لك بعد قراءة الملف.',
        bodyEn:
            'You may see a «Smart match» banner above the faculty list.\n'
            'With a completed profile, the app can suggest closer-fit supervisors.\n'
            'Treat it as help — final choice is yours after reading the profile.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الدعم الفني',
        titleEn: 'Support',
        bodyAr:
            'إن واجهت مشكلة تقنية راسل acadegate@gmail.com من بريدك مع وصف المشكلة ولقطة شاشة إن أمكن.',
        bodyEn:
            'For technical issues email acadegate@gmail.com with a short description and a screenshot if possible.',
      ),
      SectionGuideNote(
        titleAr: 'البيانات ليست ضمان قبول',
        titleEn: 'Listing ≠ acceptance',
        bodyAr:
            'وجود مشرف في القائمة لا يعني أنه قبل الإشراف عليك. التواصل مهذب ومتابعة داخل التطبيق هما الطريق الصحيح.',
        bodyEn:
            'Being listed does not mean they accepted you. Polite contact and follow-up in the app is the right path.',
      ),
    ],
  );

  static const SectionGuide storeGuide = SectionGuide(
    id: store,
    titleAr: 'دليل المتجر الأكاديمي',
    titleEn: 'Academic store guide',
    introAr:
        'المتجر لشراء مستلزمات بحثية (أجهزة، كيماويات، كتب، مستهلكات، …) من موردين على المنصة. '
        'الفكرة مثل متجر إلكتروني عادي: تصفّح → أضف للعربة → راجع → ادفع/أكمل الطلب حسب ما يظهر لك. '
        'ابدأ من الصفر باتباع الخطوات التالية.',
    introEn:
        'The store is for research supplies (instruments, chemicals, books, consumables, …) from platform vendors. '
        'Flow is familiar: browse → cart → review → checkout as shown. '
        'Follow the steps below from zero.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول',
        titleEn: '1) Sign in',
        bodyAr:
            'افتح حسابك من الشاشة الرئيسية وسجّل الدخول قبل الشراء.\n'
            'بعض الإجراءات (طلب منتج كمورد، تراخيص معرفية، شراكات) تتطلب حساباً مفعّلاً.',
        bodyEn:
            'Sign in from Home before purchasing.\n'
            'Some actions (supplier listing, knowledge licenses, partnerships) need an active account.',
      ),
      SectionGuideStep(
        icon: Icons.storefront_outlined,
        titleAr: '٢) افتح المتجر',
        titleEn: '2) Open the store',
        bodyAr:
            'من الرئيسية اضغط «المتجر» / Academic store.\n'
            'سترى أعلى الشاشة: بحث، أدوات ذكية، وأقسام المنتجات.\n'
            'أيقونة العربة (🛒) في الشريط العلوي تعرض عدد المنتجات المضافة.',
        bodyEn:
            'From Home tap «Academic store».\n'
            'You will see search, smart tools, and product categories.\n'
            'The cart icon in the app bar shows how many items you added.',
      ),
      SectionGuideStep(
        icon: Icons.search,
        titleAr: '٣) ابحث أو اختر قسماً',
        titleEn: '3) Search or pick a category',
        bodyAr:
            'اكتب في مربع البحث اسم منتج أو كلمة مفتاحية (مثلاً: ماصة، PCR، دفتر).\n'
            'أو اضغط قسماً جاهزاً: كيماويات، أجهزة، سلامة، كتب، …\n'
            'قد تظهر توصيات حسب ملفك الأكاديمي («مقترح لك») — اختياري.',
        bodyEn:
            'Type a product name or keyword in search (e.g. pipette, PCR, notebook).\n'
            'Or tap a category: chemicals, instruments, safety, books, …\n'
            'You may see profile-based recommendations — optional.',
      ),
      SectionGuideStep(
        icon: Icons.inventory_2_outlined,
        titleAr: '٤) افتح صفحة المنتج',
        titleEn: '4) Open a product page',
        bodyAr:
            'اضغط أي منتج لقراءة: الوصف، السعر إن وُجد، المورد، والمواصفات.\n'
            'تأكد من الكمية والوحدة قبل الإضافة.\n'
            'إن كان المنتج غير مناسب، ارجع بالقائمة الخلفية وجرب منتجاً آخر.',
        bodyEn:
            'Tap a product to read description, price if shown, vendor, and specs.\n'
            'Check quantity and unit before adding.\n'
            'If unsuitable, go back and try another item.',
      ),
      SectionGuideStep(
        icon: Icons.add_shopping_cart,
        titleAr: '٥) أضف إلى العربة',
        titleEn: '5) Add to cart',
        bodyAr:
            'استخدم زر الإضافة للعربة من صفحة المنتج.\n'
            'يمكنك إضافة عدة منتجات من أقسام مختلفة.\n'
            'افتح العربة من أيقونة السلة أعلى اليمين لمراجعة القائمة وتعديل الكميات أو الحذف.',
        bodyEn:
            'Use Add to cart on the product page.\n'
            'You can mix items from different categories.\n'
            'Open the cart from the top icon to review, change quantities, or remove items.',
      ),
      SectionGuideStep(
        icon: Icons.payments_outlined,
        titleAr: '٦) أكمل الطلب من العربة',
        titleEn: '6) Complete the order from the cart',
        bodyAr:
            'في شاشة العربة راجع الإجمالي ثم اتبع زر المتابعة/الدفع كما يظهر.\n'
            'اتبع التعليمات على الشاشة بدقة (عنوان، طريقة دفع إن طُلبت).\n'
            'احتفظ برقم الطلب أو تأكيد الشاشة بعد الإتمام.\n'
            'إن توقفت عملية الدفع، لا تكرر الدفع عشوائياً — راجع العربة أو راسل الدعم.',
        bodyEn:
            'In the cart, review the total then follow Continue/Pay as shown.\n'
            'Follow on-screen fields carefully (address, payment if asked).\n'
            'Keep the order confirmation.\n'
            'If payment stalls, do not pay twice blindly — recheck the cart or email support.',
      ),
      SectionGuideStep(
        icon: Icons.handyman_outlined,
        titleAr: '٧) أدوات إضافية في المتجر',
        titleEn: '7) Extra store tools',
        bodyAr:
            '• شراكات بحثية (أيقونة المصافحة): عروض تعاون بحثي عبر المتجر.\n'
            '• اكتشاف منتج / تفصيل حسب احتياجك: إن ظهرت أزرار «تخصيص» أو اكتشاف، استخدمها لوصف ما تحتاجه.\n'
            '• أصول معرفية: نشر أو إدارة تراخيص محتوى معرفي إن كنت مورداً/ناشراً.\n'
            '• إضافة منتج: للموردين المسجّلين لعرض بضاعتهم (ليس للباحث المشتري العادي).',
        bodyEn:
            '• Research partnerships (handshake icon): collaboration offers.\n'
            '• Discover / custom-fit tools: describe what you need if those buttons appear.\n'
            '• Knowledge assets: publish or manage licenses if you are a vendor/publisher.\n'
            '• Add product: for registered suppliers (not for ordinary buyers).',
      ),
      SectionGuideStep(
        icon: Icons.refresh,
        titleAr: '٨) حدّث القائمة',
        titleEn: '8) Refresh the catalog',
        bodyAr:
            'زر التحديث في الشريط العلوي يعيد تحميل المنتجات إن بدا أن القائمة قديمة أو فارغة بالخطأ.',
        bodyEn:
            'The refresh icon in the app bar reloads products if the list looks stale or empty by mistake.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الأسعار والتوفر',
        titleEn: 'Price & stock',
        bodyAr:
            'المنصة في طور تجريبي لبعض الموردين؛ قد يتغير السعر أو التوفر. اقرأ الوصف جيداً قبل الدفع.',
        bodyEn:
            'The platform is still onboarding suppliers; price/stock may change. Read the listing carefully before paying.',
      ),
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'للمشاكل: acadegate@gmail.com مع رقم الطلب إن وُجد.',
        bodyEn: 'Issues: acadegate@gmail.com with your order reference if you have one.',
      ),
    ],
  );

  static const SectionGuide labsGuide = SectionGuide(
    id: labs,
    titleAr: 'دليل المختبرات وتحليل العينات',
    titleEn: 'Labs & sample analysis guide',
    introAr:
        'قسم المختبرات يخدم غرضين: (أ) طلب تحليل عينة لدى معمل، و(ب) حجز أجهزة/مختبرات. '
        'الشاشة مقسّمة إلى تبويبين أعلى الصفحة. اقرأ كل خطوة قبل الإرسال.',
    introEn:
        'Labs covers two jobs: (A) request sample analysis at a lab, and (B) book equipment/facilities. '
        'The screen has two tabs at the top. Read each step before submitting.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول وأكمل ملفك',
        titleEn: '1) Sign in and complete your profile',
        bodyAr:
            'سجّل الدخول من الحساب.\n'
            'يفضّل تعبئة الكلية والجامعة في الملف — تظهر اقتراحات مختبرات أقرب لتخصصك.',
        bodyEn:
            'Sign in from your account.\n'
            'Fill faculty/university in your profile — lab suggestions improve.',
      ),
      SectionGuideStep(
        icon: Icons.science_outlined,
        titleAr: '٢) افتح «المختبرات والتحليل»',
        titleEn: '2) Open Labs & analysis',
        bodyAr:
            'من الرئيسية ادخل قسم المختبرات.\n'
            'ستجد تبويبين:\n'
            '• تحليل عينات\n'
            '• حجز أجهزة\n'
            'اختر التبويب المناسب لهدفك أولاً.',
        bodyEn:
            'From Home open Labs.\n'
            'Two tabs:\n'
            '• Sample analysis\n'
            '• Book equipment\n'
            'Pick the tab that matches your goal first.',
      ),
      SectionGuideStep(
        icon: Icons.biotech_outlined,
        titleAr: '٣) تبويب تحليل العينات',
        titleEn: '3) Sample analysis tab',
        bodyAr:
            'هنا تتصفّح عروض/معامل تحليل العينات (سوق التحليل).\n'
            'اقرأ نوع التحليل، المتطلبات، والجهة المقدِّمة.\n'
            'عند اختيار عرض مناسب اتبع زر الطلب واملأ بيانات العينة بدقة '
            '(نوع العينة، عددها، ملاحظات السلامة إن لزم).\n'
            'بعد الإرسال راقب حالة الطلب من أيقونة «طلبات تحليل العينات» في الشريط العلوي.',
        bodyEn:
            'Browse sample-analysis offers/labs (marketplace).\n'
            'Read analysis type, requirements, and provider.\n'
            'When you pick an offer, follow the request button and fill sample details carefully '
            '(sample type, count, safety notes if needed).\n'
            'Track status via «Sample analysis requests» in the app bar.',
      ),
      SectionGuideStep(
        icon: Icons.precision_manufacturing_outlined,
        titleAr: '٤) تبويب حجز الأجهزة',
        titleEn: '4) Book equipment tab',
        bodyAr:
            'قائمة مختبرات يمكن تصفيتها حسب المدينة والجامعة والكلية.\n'
            'استخدم البحث باسم المختبر أو الجهاز.\n'
            'اضغط مختبراً لفتح التفاصيل: الأجهزة، الموقع، طريقة الحجز.\n'
            'اختر موعداً/جهازاً إن طُلب واتبع تأكيد الحجز.\n'
            'حجوزاتك تظهر من أيقونة «حجوزاتي» أعلى الشاشة.',
        bodyEn:
            'Lab list can be filtered by city, university, and faculty.\n'
            'Search by lab or equipment name.\n'
            'Open a lab for details: equipment, location, booking steps.\n'
            'Pick a slot/device if asked and confirm.\n'
            'Your bookings are under «My bookings» in the app bar.',
      ),
      SectionGuideStep(
        icon: Icons.filter_alt_outlined,
        titleAr: '٥) الفلاتر والاقتراحات',
        titleEn: '5) Filters & suggestions',
        bodyAr:
            'ابدأ بـ«كل المدن» ثم ضيّق إن كانت القائمة طويلة.\n'
            'إن ظهرت اقتراحات حسب كليتك، راجعها أولاً ثم وسع البحث.\n'
            'يمكنك أيضاً فتح سجل المختبرات الرسمي للجامعات المصرية عبر الرابط إن ظهر (NBSLE) للاطلاع الخارجي.',
        bodyEn:
            'Start with «All cities», then narrow if the list is long.\n'
            'If faculty-based suggestions appear, review them first then widen search.\n'
            'An official Egyptian labs registry link (NBSLE) may appear for external browsing.',
      ),
      SectionGuideStep(
        icon: Icons.add_business_outlined,
        titleAr: '٦) إضافة مختبر (للمساهمين)',
        titleEn: '6) Add a lab (contributors)',
        bodyAr:
            'الزر العائم «إضافة مختبر» لمن يدير معملاً ويريد نشره على المنصة.\n'
            'الباحث العادي لا يحتاجه — اتركه إن كنت طالباً تبحث عن خدمة فقط.',
        bodyEn:
            'Floating «Add lab» is for lab managers listing a facility.\n'
            'Students who only need a service can ignore it.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'السلامة والعينات',
        titleEn: 'Safety & samples',
        bodyAr:
            'لا ترسل عينات خطرة دون تنسيق صريح مع المعمل. اتبع تعليمات السلامة التي يذكرها المعمل في الطلب.',
        bodyEn:
            'Do not ship hazardous samples without explicit lab coordination. Follow the lab’s safety instructions.',
      ),
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com عند فشل الحجز أو عدم ظهور المعمل المتوقع.',
        bodyEn: 'acadegate@gmail.com if booking fails or an expected lab is missing.',
      ),
    ],
  );

  static const SectionGuide writingGuide = SectionGuide(
    id: writing,
    titleAr: 'دليل خدمات الكتابة الأكاديمية',
    titleEn: 'Academic writing services guide',
    introAr:
        'هذا القسم لطلب كتابة/تحرير بشري متخصص (كاتب حقيقي)، وليس لاستبدال رسالتك بذكاء اصطناعي. '
        'تختار نوع الخدمة → تضع متطلباتك → تحجز مع خبير. '
        'هناك أيضاً أدوات مساعدة بجانب الكاتب (مستشار ذكي، محاكي مناقشة، إحصاء).',
    introEn:
        'This section books specialist human writing/editing — not AI replacing your thesis. '
        'Choose a service type → set requirements → book an expert. '
        'Companion tools (AI advisor, viva practice, stats wizard) sit alongside.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول',
        titleEn: '1) Sign in',
        bodyAr:
            'يجب تسجيل الدخول لإنشاء طلبات ومتابعتها من «طلباتي» أعلى الشاشة.',
        bodyEn:
            'Sign in so you can create orders and track them under «My orders» in the app bar.',
      ),
      SectionGuideStep(
        icon: Icons.edit_note,
        titleAr: '٢) افتح خدمات الكتابة',
        titleEn: '2) Open writing services',
        bodyAr:
            'من الرئيسية ادخل «خدمات الكتابة الأكاديمية».\n'
            'اقرأ الشريط التوضيحي: الخدمة بشرية متخصصة.',
        bodyEn:
            'From Home open «Academic writing services».\n'
            'Read the banner: this is specialist human work.',
      ),
      SectionGuideStep(
        icon: Icons.build_outlined,
        titleAr: '٣) أدوات مساعدة (اختيارية قبل الطلب)',
        titleEn: '3) Companion tools (optional before ordering)',
        bodyAr:
            '• راجع بالذكاء: مسودة ملاحظات من المساعد الأكاديمي — للمساعدة لا للتسليم النهائي للجامعة.\n'
            '• تمرّن للمناقشة: أسئلة لجنة وهمية.\n'
            '• معالج الافتراضات الإحصائية: تطبيع/قوة عينة وإرشادات SPSS/R.\n'
            '• مطابقة كاتب: اقتراح كاتب حسب تخصصك ولغتك.\n'
            'هذه الأدوات لا تلغي الحاجة لطلب رسمي من الأقسام أدناه إن أردت كاتباً.',
        bodyEn:
            '• Review with AI: feedback drafts — help only, not a final university submission.\n'
            '• Practice viva: mock committee questions.\n'
            '• Statistical assumptions wizard: normality/power and SPSS/R guidance.\n'
            '• Match a writer: suggestions by specialty and language.\n'
            'Tools do not replace a formal order if you need a human writer.',
      ),
      SectionGuideStep(
        icon: Icons.grid_view_outlined,
        titleAr: '٤) اختر نوع الخدمة',
        titleEn: '4) Choose a service type',
        bodyAr:
            'من شبكة الأقسام اختر ما تحتاجه، مثلاً:\n'
            'أوراق بحثية · رسائل علمية · إحصاء وتحليل · مراجعة أدبيات · '
            'مقترحات بحث · تحرير وتدقيق · تنسيق وتوثيق · ترجمة علمية.\n'
            'يمكنك البحث أعلى الصفحة بكلمات مثل «إحصاء» أو «ترجمة».',
        bodyEn:
            'From the category grid pick what you need, e.g.:\n'
            'research papers · theses · statistics · literature review · '
            'proposals · editing · formatting/citation · scientific translation.\n'
            'Search at the top with words like «statistics» or «translation».',
      ),
      SectionGuideStep(
        icon: Icons.person_outline,
        titleAr: '٥) اختر خبيراً أو انشر احتياجك',
        titleEn: '5) Pick an expert or publish a need',
        bodyAr:
            'بعد فتح القسم ستظهر قائمة خبراء/خدمات أو مسار لطلب جديد.\n'
            'اقرأ ملف الكاتب: التخصص، اللغة، الأدوات.\n'
            'إن كنت كاتباً محترفاً: قد ترى خيار نشر خدمتك — ذلك للمقدّمين لا للطلاب طالبي الخدمة.',
        bodyEn:
            'After opening a category you see experts/services or a new-order path.\n'
            'Read the writer profile: specialty, language, tools.\n'
            'If you are a professional writer: publishing your service is for providers, not student buyers.',
      ),
      SectionGuideStep(
        icon: Icons.description_outlined,
        titleAr: '٦) اكتب متطلبات الطلب بوضوح',
        titleEn: '6) Write clear requirements',
        bodyAr:
            'حدّد: اللغة، عدد الكلمات/الصفحات التقريبي، الموعد، أسلوب التوثيق (APA/IEEE…)، '
            'وما هو الممنوع (مثلاً لا تريد إعادة صياغة كاملة إن كان المطلوب تدقيقاً فقط).\n'
            'أرفق ملفاً إن طُلب. كن صادقاً بخصوص نسبة العمل المطلوبة من الكاتب.',
        bodyEn:
            'Specify: language, approx. words/pages, deadline, citation style (APA/IEEE…), '
            'and boundaries (e.g. proofreading only vs full rewrite).\n'
            'Attach a file if asked. Be honest about how much you need the writer to do.',
      ),
      SectionGuideStep(
        icon: Icons.receipt_long_outlined,
        titleAr: '٧) تابع الطلب من «طلباتي»',
        titleEn: '7) Track orders under My orders',
        bodyAr:
            'أيقونة الإيصال أعلى الشاشة تفتح طلباتك: الحالة، الردود، والتسليمات.\n'
            'لا تغلق المحادثة مع الكاتب داخل التطبيق إن وُجدت — استخدمها للتعديلات.',
        bodyEn:
            'The receipt icon opens your orders: status, replies, deliveries.\n'
            'Keep using in-app chat with the writer for revisions when available.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الأمانة العلمية',
        titleEn: 'Academic integrity',
        bodyAr:
            'أنت المسؤول أمام جامعتك. استخدم الكتابة البشرية للمساعدة المشروعة (تحرير، ترجمة، إحصاء) وفق لوائح مؤسستك.',
        bodyEn:
            'You remain responsible to your university. Use human writing help within your institution’s rules.',
      ),
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com لمشاكل الدفع أو عدم ظهور الطلب.',
        bodyEn: 'acadegate@gmail.com for payment issues or missing orders.',
      ),
    ],
  );

  static const SectionGuide publishGuide = SectionGuide(
    id: publish,
    titleAr: 'دليل النشر وتنسيق المخطوطات',
    titleEn: 'Publish & manuscript formatting guide',
    introAr:
        'قسم النشر يساعدك على إنشاء مسودة بحث، رفع ملف Word/PDF، استخراج المراجع، '
        'تنسيق الاستشهادات، اختيار مجلة، وتصدير نسخة جاهزة قدر الإمكان. '
        'اعمل خطوة بخطوة — لا تقفز للتصدير قبل رفع النص والمراجع.',
    introEn:
        'Publish helps you create a manuscript draft, upload Word/PDF, extract references, '
        'format citations, pick a journal, and export a usable file. '
        'Go step by step — do not export before text and references are in place.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول',
        titleEn: '1) Sign in',
        bodyAr:
            'المسودات مربوطة بحسابك. بدون دخول لن تُحفظ أعمالك عبر الأجهزة.',
        bodyEn:
            'Drafts are tied to your account. Without sign-in they will not sync across devices.',
      ),
      SectionGuideStep(
        icon: Icons.article_outlined,
        titleAr: '٢) افتح قسم النشر',
        titleEn: '2) Open Publish',
        bodyAr:
            'من الرئيسية ادخل خدمة النشر.\n'
            'إن لم يكن لديك مسودات سترى رسالة فارغة وزر «مسودة جديدة».\n'
            'إن وُجدت مسودات سابقة تظهر كقائمة: العنوان + الحالة.',
        bodyEn:
            'From Home open Publish.\n'
            'With no drafts you see an empty state and «New draft».\n'
            'Existing drafts appear as a list: title + status.',
      ),
      SectionGuideStep(
        icon: Icons.note_add_outlined,
        titleAr: '٣) أنشئ مسودة جديدة',
        titleEn: '3) Create a new draft',
        bodyAr:
            'اضغط الزر العائم «مسودة جديدة».\n'
            'قد يُطلب منك تسجيل الدخول إن لم تكن كذلك.\n'
            'تُفتح شاشة المحرر للمسودة الجديدة.',
        bodyEn:
            'Tap floating «New draft».\n'
            'You may be asked to sign in.\n'
            'The manuscript editor opens for the new draft.',
      ),
      SectionGuideStep(
        icon: Icons.upload_file,
        titleAr: '٤) ارفع البحث (Word أو PDF)',
        titleEn: '4) Upload the manuscript (Word or PDF)',
        bodyAr:
            'في المحرر ابحث عن «رفع البحث كاملاً» واختر ملفاً من جهازك (حد أقصى تقريباً كما يظهر على الشاشة).\n'
            'يحاول النظام قراءة النص واستخراج قسم المراجع تلقائياً إن وُجد.\n'
            'إن فشل الاستخراج: أضف المراجع يدوياً أو أعد الرفع بعد التأكد أن الملف يحتوي قسماً واضحاً للمراجع.',
        bodyEn:
            'In the editor use «Upload full manuscript» and pick a file (size limit as shown).\n'
            'The system tries to read text and extract a References section when present.\n'
            'If extraction fails: add references manually or re-upload with a clear References section.',
      ),
      SectionGuideStep(
        icon: Icons.format_quote,
        titleAr: '٥) راجع المراجع والاستشهادات',
        titleEn: '5) Review references & citations',
        bodyAr:
            'أضف مراجع ناقصة، صحّح العناوين، وتأكد من DOI إن وُجد.\n'
            'استخدم أدوات التنسيق (IEEE/APA وغيرها) من مسار «التالي: التنسيق» أو شاشات التنسيق المرتبطة.\n'
            'لا تعتمد على تنسيق أعمى: راجع القائمة النهائية سطراً بسطر.',
        bodyEn:
            'Add missing references, fix titles, keep DOIs when available.\n'
            'Use formatting tools (IEEE/APA, etc.) via «Next: format» or related screens.\n'
            'Do not trust blind formatting — review the final list line by line.',
      ),
      SectionGuideStep(
        icon: Icons.menu_book_outlined,
        titleAr: '٦) اختر مجلة (عند الجاهزية)',
        titleEn: '6) Choose a journal (when ready)',
        bodyAr:
            'من مسارات المحرر يمكنك اختيار مجلة والاطلاع على إرشادات الشكل إن توفرت.\n'
            'الهدف تقريب مخطوطتك لمتطلبات المجلة — التقديم النهائي للمجلة يتم عادة عبر موقع المجلة نفسها.',
        bodyEn:
            'From editor flows you can pick a journal and view formatting guidelines when available.\n'
            'Goal: align your manuscript with journal rules — final submission is usually on the journal’s own site.',
      ),
      SectionGuideStep(
        icon: Icons.file_download_outlined,
        titleAr: '٧) صدّر PDF أو Word',
        titleEn: '7) Export PDF or Word',
        bodyAr:
            'من قائمة التصدير اختر PDF أو Word حسب حاجتك.\n'
            'احفظ الملف على جهازك وراجعه قبل إرساله لأي جهة.\n'
            'إن أدرجت صوراً من الاستيراد، صدّر Word قبل إغلاق الجلسة إن نبهك التطبيق لذلك.',
        bodyEn:
            'From Export choose PDF or Word.\n'
            'Save locally and proofread before sending anywhere.\n'
            'If imported images are session-only, export Word before closing when the app warns you.',
      ),
      SectionGuideStep(
        icon: Icons.delete_outline,
        titleAr: '٨) حذف مسودة (بحذر)',
        titleEn: '8) Delete a draft (carefully)',
        bodyAr:
            'من قائمة المسودات يمكنك حذف مسودة نهائياً مع ملفاتها.\n'
            'لا يمكن التراجع — تأكد قبل التأكيد.',
        bodyEn:
            'From the drafts list you can permanently delete a draft and its files.\n'
            'This cannot be undone — confirm carefully.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الملكية الفكرية',
        titleEn: 'IP ownership',
        bodyAr:
            'ملفاتك ملكك. لا تشارك حسابك مع آخرين. احتفظ بنسخ احتياطية خارج التطبيق أيضاً.',
        bodyEn:
            'Your files are yours. Do not share your account. Keep offline backups too.',
      ),
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'فشل الرفع أو الاستخراج؟ راسل acadegate@gmail.com مع نوع الملف وحجم تقريبي.',
        bodyEn:
            'Upload/extract failure? Email acadegate@gmail.com with file type and approximate size.',
      ),
    ],
  );
}
