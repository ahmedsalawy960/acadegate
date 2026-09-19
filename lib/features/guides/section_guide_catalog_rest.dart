import 'package:flutter/material.dart';

import 'section_guide_models.dart';

/// أدلة الأقسام المتبقية (مطابقة، أفكار، مسار، مجتمع، ذكاء، استوديو، نزاهة، تمويل، أخبار).
abstract final class SectionGuideCatalogRest {
  static const SectionGuide matchmakingGuide = SectionGuide(
    id: 'matchmaking',
    titleAr: 'دليل المطابقة الذكية',
    titleEn: 'Smart matching guide',
    introAr:
        'المطابقة الذكية تقترح مشرفين (وأحياناً عناصر أخرى) أقرب لهدفك البحثي وملفك الأكاديمي. '
        'بدون ملف مكتمل لن تظهر نتائج مفيدة — ابدأ بتسجيل الدخول وإكمال الملف.',
    introEn:
        'Smart matching suggests supervisors (and related fits) closest to your research goal and academic profile. '
        'Without a complete profile results stay weak — sign in and finish your profile first.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول',
        titleEn: '1) Sign in',
        bodyAr: 'من الرئيسية افتح حسابك وسجّل الدخول حتى يُحفظ ملفك وتظهر المطابقات لحسابك.',
        bodyEn: 'From Home open your account and sign in so your profile and matches stay tied to you.',
      ),
      SectionGuideStep(
        icon: Icons.auto_awesome,
        titleAr: '٢) افتح المطابقة الذكية',
        titleEn: '2) Open Smart matching',
        bodyAr: 'من بطاقات الخدمات على الرئيسية اضغط «المطابقة الذكية».',
        bodyEn: 'On Home service cards tap «Smart matching».',
      ),
      SectionGuideStep(
        icon: Icons.person_outline,
        titleAr: '٣) أكمل الملف الأكاديمي',
        titleEn: '3) Complete your academic profile',
        bodyAr:
            'إن ظهرت رسالة أن الملف غير مكتمل: اضغط تعديل الملف (أيقونة الشخص أعلى الشاشة) '
            'واملأ الكلية والتخصص والدرجة وأي حقول مطلوبة حتى يصبح الملف «مكتملاً».\n'
            'بدون ذلك لن تُحسب المطابقة بشكل صحيح.',
        bodyEn:
            'If you see an incomplete-profile message: tap the person icon in the app bar '
            'and fill faculty, specialty, degree, and required fields until the profile is complete.\n'
            'Matching will not work well otherwise.',
      ),
      SectionGuideStep(
        icon: Icons.edit_note,
        titleAr: '٤) اكتب هدفك البحثي',
        titleEn: '4) Write your research goal',
        bodyAr:
            'في مربع الهدف اكتب بجمل واضحة: ماذا تريد أن تدرس؟ (موضوع، مشكلة، منهج إن عرفته).\n'
            'مثال: «تأثير جودة المياه على محصول الأرز في الدلتا باستخدام تحليل إحصائي».',
        bodyEn:
            'In the goal box write clearly what you want to study (topic, problem, method if known).\n'
            'Example: «Effect of water quality on rice yield in the Delta using statistical analysis».',
      ),
      SectionGuideStep(
        icon: Icons.play_arrow,
        titleAr: '٥) شغّل المطابقة واقرأ النتائج',
        titleEn: '5) Run matching and read results',
        bodyAr:
            'اضغط زر التشغيل/المطابقة إن ظهر، ثم راجع قائمة المقترحات مرتبة حسب التوافق.\n'
            'اضغط أي مشرف لفتح ملفه ثم راسله من هناك إن ناسبك.\n'
            'المقترح مساعدة — القرار النهائي لك بعد قراءة الملف.',
        bodyEn:
            'Tap run/match if shown, then review ranked suggestions.\n'
            'Open a supervisor profile and message them if they fit.\n'
            'Suggestions are help — final choice is yours after reading the profile.',
      ),
      SectionGuideStep(
        icon: Icons.refresh,
        titleAr: '٦) حدّث الملف وأعد المحاولة',
        titleEn: '6) Update profile and retry',
        bodyAr:
            'إن كانت النتائج بعيدة عن تخصصك: عدّل الملف أو صِغ الهدف بدقة أكبر ثم أعد المطابقة.',
        bodyEn:
            'If results feel off: edit the profile or refine the goal, then run matching again.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com إن فشل التحميل أو بقي الملف «غير مكتمل» رغم التعبئة.',
        bodyEn: 'acadegate@gmail.com if loading fails or the profile stays incomplete after filling fields.',
      ),
    ],
  );

  static const SectionGuide ideasGuide = SectionGuide(
    id: 'ideas',
    titleAr: 'دليل سوق الأفكار البحثية',
    titleEn: 'Research ideas marketplace guide',
    introAr:
        'سوق الأفكار مكان تنشر فيه جهات أو باحثون مشاكل/أفكاراً بحثية، ويتصفحها الطلاب، يصوّتون، '
        'وقد يقدّمون مقترحات. بعض الأفكار المؤهلة بالتصويت تدخل مسار صندوق التمويل لاحقاً.',
    introEn:
        'The ideas marketplace is where partners or researchers post research problems/ideas; students browse, vote, '
        'and may submit proposals. Highly voted ideas can later enter the research fund path.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول',
        titleEn: '1) Sign in',
        bodyAr: 'التسجيل مطلوب للتصويت ونشر فكرة ومتابعة حالتها.',
        bodyEn: 'Sign-in is required to vote, publish an idea, and track status.',
      ),
      SectionGuideStep(
        icon: Icons.lightbulb_outline,
        titleAr: '٢) افتح سوق الأفكار',
        titleEn: '2) Open the ideas marketplace',
        bodyAr:
            'من الرئيسية اضغط «الأفكار» / سوق الأفكار.\n'
            'اقرأ الشريط التوضيحي أعلى القائمة ثم تصفّح البطاقات.',
        bodyEn:
            'From Home tap Ideas / marketplace.\n'
            'Read the top banner, then browse idea cards.',
      ),
      SectionGuideStep(
        icon: Icons.open_in_new,
        titleAr: '٣) افتح فكرة واقرأ التفاصيل',
        titleEn: '3) Open an idea and read details',
        bodyAr:
            'اضغط أي فكرة لقراءة المشكلة، الفجوة، الأهداف، والمنهج المقترح إن وُجد.\n'
            'قرّر هل تناسب تخصصك قبل التصويت أو التقديم.',
        bodyEn:
            'Tap an idea to read the problem, gap, goals, and proposed method if any.\n'
            'Decide if it fits your field before voting or applying.',
      ),
      SectionGuideStep(
        icon: Icons.how_to_vote_outlined,
        titleAr: '٤) صوّت على فكرة جيدة',
        titleEn: '4) Vote for a strong idea',
        bodyAr:
            'من صفحة الفكرة استخدم زر التصويت (أو إلغاء التصويت إن صوّت سابقاً).\n'
            'التصويت يساعد الفكرة على التأهل للتمويل عند بلوغ الحد الأدنى في صندوق البحث.',
        bodyEn:
            'On the idea page use Vote (or remove vote if you already voted).\n'
            'Votes help the idea reach the research-fund eligibility threshold.',
      ),
      SectionGuideStep(
        icon: Icons.add,
        titleAr: '٥) انشر فكرتك أنت',
        titleEn: '5) Publish your own idea',
        bodyAr:
            'الزر العائم «نشر فكرة» يفتح نموذجاً: عنوان، وصف واضح للمشكلة والأهداف، وسوم إن طُلبت.\n'
            'بعد الإرسال غالباً تذهب للمراجعة وتظهر للعامة بعد الموافقة.\n'
            'اكتب بلغة مهنية وبدون بيانات شخصية حساسة.',
        bodyEn:
            'Floating «Publish idea» opens a form: title, clear problem/goals, tags if asked.\n'
            'After submit it usually goes to review and appears publicly after approval.\n'
            'Write professionally; avoid sensitive personal data.',
      ),
      SectionGuideStep(
        icon: Icons.volunteer_activism_outlined,
        titleAr: '٦) اربط مع صندوق التمويل',
        titleEn: '6) Link with the research fund',
        bodyAr:
            'بعد جمع تصويتات كافية قد تظهر الفكرة ضمن الأفكار المؤهلة في قسم «صندوق تمويل البحث».\n'
            'راجع ذلك القسم لفهم حد التصويت ومبلغ التمويل وحدود الاستثمار/التحديات الصناعية.',
        bodyEn:
            'With enough votes the idea may appear under eligible ideas in Research Fund.\n'
            'Open that section to learn vote thresholds, award limits, and industry-challenge options.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com إن لم تظهر فكرتك بعد أيام من الإرسال.',
        bodyEn: 'acadegate@gmail.com if your idea does not appear days after submission.',
      ),
    ],
  );

  static const SectionGuide researchPathGuide = SectionGuide(
    id: 'research_path',
    titleAr: 'دليل مسار البحث (سلسلة التوريد البحثية)',
    titleEn: 'Research path guide',
    introAr:
        'مسار البحث يبني لك «حزمة» من اقتراحات مرتبطة بهدفك: مشرف، مختبر، مواد من المتجر، كتابة، تمويل إن وُجد تطابق حقيقي. '
        'ليس سحراً: يعتمد على ملفك وما هو منشور فعلياً في المنصة.',
    introEn:
        'Research path builds a bundle around your goal: supervisor, lab, store items, writing, funding when a real match exists. '
        'Not magic — it depends on your profile and what is actually listed on the platform.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول وأكمل الملف',
        titleEn: '1) Sign in and complete profile',
        bodyAr:
            'استخدم أيقونة الملف أعلى الشاشة لإكمال الكلية والتخصص.\n'
            'الملف الناقص يقلل جودة الحزمة.',
        bodyEn:
            'Use the profile icon in the app bar to finish faculty/specialty.\n'
            'An incomplete profile weakens the bundle.',
      ),
      SectionGuideStep(
        icon: Icons.account_tree_outlined,
        titleAr: '٢) افتح مسار البحث',
        titleEn: '2) Open Research path',
        bodyAr: 'من الرئيسية ادخل بطاقة مسار البحث / سلسلة التوريد البحثية.',
        bodyEn: 'From Home open the Research path card.',
      ),
      SectionGuideStep(
        icon: Icons.flag_outlined,
        titleAr: '٣) اكتب هدفك البحثي',
        titleEn: '3) Write your research goal',
        bodyAr:
            'في الحقل الكبير صف هدفك بجمل كاملة (موضوع + سياق + مخرج إن أمكن).\n'
            'ثم اضغط زر بناء المسار / التوليد كما يظهر على الشاشة.',
        bodyEn:
            'In the large field describe your goal in full sentences (topic + context + outcome if known).\n'
            'Then tap build/generate as shown on screen.',
      ),
      SectionGuideStep(
        icon: Icons.checklist_outlined,
        titleAr: '٤) اقرأ الحزمة خطوة بخطوة',
        titleEn: '4) Read the bundle step by step',
        bodyAr:
            'ستظهر بطاقات اقتراح (مشرف، مختبر، منتج، خدمة كتابة، تمويل…).\n'
            'اضغط كل بطاقة مناسبة للانتقال للقسم الحقيقي وتنفيذ الخطوة هناك (مراسلة، حجز، شراء…).',
        bodyEn:
            'Suggestion cards appear (supervisor, lab, product, writing, funding…).\n'
            'Tap each relevant card to open the real section and act there (message, book, buy…).',
      ),
      SectionGuideStep(
        icon: Icons.picture_as_pdf_outlined,
        titleAr: '٥) صدّر أو اطبع المسار (اختياري)',
        titleEn: '5) Export or print the path (optional)',
        bodyAr:
            'بعد ظهور الحزمة قد يظهر زر PDF/طباعة في الشريط العلوي لحفظ خطة المسار خارج التطبيق.',
        bodyEn:
            'Once a bundle exists, a PDF/print action may appear in the app bar to keep the plan offline.',
      ),
      SectionGuideStep(
        icon: Icons.info_outline,
        titleAr: '٦) صدق النتائج',
        titleEn: '6) Treat results honestly',
        bodyAr:
            'المنصة لا تخترع ممولاً أو مختبراً غير موجود. إن لم يظهر تمويل فهو غير متاح بعد في البيانات.',
        bodyEn:
            'The platform does not invent funders or labs that are not listed. Missing funding means none matched yet.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com عند فشل التوليد أو التصدير.',
        bodyEn: 'acadegate@gmail.com if generate or export fails.',
      ),
    ],
  );

  static const SectionGuide communityGuide = SectionGuide(
    id: 'community',
    titleAr: 'دليل المجتمع الأكاديمي',
    titleEn: 'Academic community guide',
    introAr:
        'المجتمع للنقاش الجماعي: غرف حسب الكلية، غرف بحثية موضوعية، ودوائر دراسة. '
        'استخدمه لطرح أسئلة أكاديمية محترمة ومشاركة الخبرات — ليس للإعلانات العشوائية.',
    introEn:
        'Community is for group discussion: faculty rooms, topical research rooms, and study circles. '
        'Use it for respectful academic questions and experience sharing — not spam ads.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول',
        titleEn: '1) Sign in',
        bodyAr: 'المشاركة والنشر في الغرف يحتاج حساباً مسجّلاً.',
        bodyEn: 'Posting and joining rooms requires a signed-in account.',
      ),
      SectionGuideStep(
        icon: Icons.forum_outlined,
        titleAr: '٢) افتح المجتمع',
        titleEn: '2) Open Community',
        bodyAr: 'من الرئيسية ادخل «المجتمع الأكاديمي».',
        bodyEn: 'From Home open «Academic community».',
      ),
      SectionGuideStep(
        icon: Icons.tab,
        titleAr: '٣) افهم التبويبات الثلاثة',
        titleEn: '3) Understand the three tabs',
        bodyAr:
            '• غرف التخصص: نقاشات مرتبطة بكليتك/تخصصك.\n'
            '• الغرف البحثية: غرف حول موضوع بحثي محدد (يمكنك إنشاء واحدة).\n'
            '• دوائر دراسة: مجموعات دراسة أصغر للتعاون المنتظم.',
        bodyEn:
            '• Faculty rooms: discussions tied to your faculty/field.\n'
            '• Research rooms: topic rooms (you can create one).\n'
            '• Study circles: smaller groups for regular collaboration.',
      ),
      SectionGuideStep(
        icon: Icons.meeting_room_outlined,
        titleAr: '٤) ادخل غرفة وشارك',
        titleEn: '4) Enter a room and participate',
        bodyAr:
            'افتح غرفة، اقرأ القواعد إن وُجدت، ثم اكتب سؤالاً واضحاً أو رداً مفيداً.\n'
            'تجنب مشاركة ملفات سرية أو بيانات شخصية للآخرين.',
        bodyEn:
            'Open a room, read rules if shown, then post a clear question or helpful reply.\n'
            'Do not share confidential files or other people’s private data.',
      ),
      SectionGuideStep(
        icon: Icons.add_circle_outline,
        titleAr: '٥) أنشئ غرفة بحثية',
        titleEn: '5) Create a research room',
        bodyAr:
            'من أيقونة الإضافة أعلى الشاشة أو الزر العائم في تبويب الغرف البحثية: اختر اسماً ووصفاً وموضوعاً.\n'
            'اجعل العنوان محدداً حتى يجدك الباحثون المهتمون.',
        bodyEn:
            'From the add icon in the app bar or the FAB on Research rooms: set name, description, topic.\n'
            'Keep the title specific so interested researchers can find you.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'السلوك',
        titleEn: 'Conduct',
        bodyAr: 'النقاش الأكاديمي محترم. التبليغ عن الإساءة عبر الدعم: acadegate@gmail.com',
        bodyEn: 'Keep discussion respectful. Report abuse via acadegate@gmail.com',
      ),
    ],
  );

  static const SectionGuide aiGuide = SectionGuide(
    id: 'ai',
    titleAr: 'دليل المساعد الأكاديمي (الذكاء)',
    titleEn: 'AI academic advisor guide',
    introAr:
        'المساعد أداة للحوار والاقتراح (عناوين، أسئلة بحثية، تلخيص، ملاحظات مسودة). '
        'هو ليس بديلاً عن مشرفك ولا عن أمانة البحث، ولا يضمن قبول الجامعة.',
    introEn:
        'The advisor is for dialogue and suggestions (titles, research questions, summaries, draft notes). '
        'It does not replace your supervisor or research integrity, and does not guarantee university acceptance.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول إن طُلب',
        titleEn: '1) Sign in if prompted',
        bodyAr: 'بعض الميزات قد تتطلب حساباً لحفظ الجلسات أو الحدود.',
        bodyEn: 'Some features may require an account for sessions or limits.',
      ),
      SectionGuideStep(
        icon: Icons.psychology_alt_outlined,
        titleAr: '٢) افتح المساعد',
        titleEn: '2) Open the advisor',
        bodyAr: 'من الرئيسية أو أيقونة المساعد في الشريط العلوي للرئيسية.',
        bodyEn: 'From Home or the advisor icon on the Home app bar.',
      ),
      SectionGuideStep(
        icon: Icons.chat_bubble_outline,
        titleAr: '٣) اكتب سؤالك بوضوح',
        titleEn: '3) Ask clearly',
        bodyAr:
            'مثال جيد: «اقترح ٣ عناوين ماجستير في هندسة الري مع فجوة بحثية قصيرة».\n'
            'مثال ضعيف: «ساعدني» بدون سياق.\n'
            'أرفق تخصصك ومرحلتك (ماجستير/دكتوراه) في الرسالة الأولى.',
        bodyEn:
            'Good: «Suggest 3 MSc titles in irrigation engineering with a short research gap».\n'
            'Weak: «Help me» with no context.\n'
            'Include your field and stage (MSc/PhD) in the first message.',
      ),
      SectionGuideStep(
        icon: Icons.gavel_outlined,
        titleAr: '٤) محاكي لجنة المناقشة',
        titleEn: '4) Viva committee simulator',
        bodyAr:
            'أيقونة المطرقة في الشريط تفتح محاكي المناقشة للتدرّب على أسئلة اللجنة.\n'
            'تدرّب ثم راجع إجاباتك مع مشرفك الحقيقي.',
        bodyEn:
            'The gavel icon opens the viva simulator for committee-style practice.\n'
            'Practice, then review answers with your real supervisor.',
      ),
      SectionGuideStep(
        icon: Icons.volume_up_outlined,
        titleAr: '٥) قراءة الردود صوتياً (اختياري)',
        titleEn: '5) Read replies aloud (optional)',
        bodyAr: 'زر الصوت يفعّل أو يوقف قراءة الردود. أوقفه إن كنت في مكان هادئ مشترَك.',
        bodyEn: 'The volume button toggles reading replies aloud. Turn it off in quiet shared spaces.',
      ),
      SectionGuideStep(
        icon: Icons.warning_amber_outlined,
        titleAr: '٦) تحقق بنفسك',
        titleEn: '6) Verify yourself',
        bodyAr:
            'لا تنسخ نصاً للجامعة دون مراجعة. راجع المراجع الحقيقية (DOI) والأرقام والإحصاء في أدوات النزاهة/النشر.',
        bodyEn:
            'Do not paste unchecked text to your university. Verify real references (DOI), numbers, and stats via integrity/publish tools.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com عند تعطل المحادثة أو الصوت.',
        bodyEn: 'acadegate@gmail.com if chat or voice fails.',
      ),
    ],
  );

  static const SectionGuide thesisStudioGuide = SectionGuide(
    id: 'thesis_studio',
    titleAr: 'دليل استوديو الرسالة',
    titleEn: 'Thesis Studio guide',
    introAr:
        'استوديو الرسالة يساعدك على تنظيم مسودة الرسالة: هدف، فصول، ملخصات، وتصدير. '
        'اعمل تدريجياً واحفظ تقدّمك — لا تتوقع رسالة كاملة جاهزة بضغطة واحدة.',
    introEn:
        'Thesis Studio helps organize a thesis draft: goal, chapters, summaries, and export. '
        'Work step by step and keep progress — do not expect a full thesis in one click.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول وأكمل الملف',
        titleEn: '1) Sign in and complete profile',
        bodyAr: 'أيقونة الملف أعلى الشاشة تربط الاستوديو بكليتك وتخصصك.',
        bodyEn: 'The profile icon ties the studio to your faculty and specialty.',
      ),
      SectionGuideStep(
        icon: Icons.menu_book_outlined,
        titleAr: '٢) افتح استوديو الرسالة',
        titleEn: '2) Open Thesis Studio',
        bodyAr: 'من الرئيسية اضغط بطاقة استوديو الرسالة.',
        bodyEn: 'From Home tap Thesis Studio.',
      ),
      SectionGuideStep(
        icon: Icons.flag_outlined,
        titleAr: '٣) اكتب هدف الرسالة',
        titleEn: '3) Write the thesis goal',
        bodyAr:
            'في الحقل الكبير صف موضوع الرسالة والمشكلة والمخرج المتوقع.\n'
            'اتبع أزرار التوليد/البناء المعروضة لبدء المسودة الهيكلية.',
        bodyEn:
            'In the large field describe topic, problem, and expected outcome.\n'
            'Use the on-screen generate/build actions to start a structural draft.',
      ),
      SectionGuideStep(
        icon: Icons.view_agenda_outlined,
        titleAr: '٤) راجع الفصول وعدّلها',
        titleEn: '4) Review and edit chapters',
        bodyAr:
            'افتح كل فصل، عدّل النص، وأكمل النواقص بنفسك أو بمساعدة المساعد/الكاتب لاحقاً.\n'
            'المسودة ملكك — راجعها علمياً ولغوياً قبل التسليم للجامعة.',
        bodyEn:
            'Open each chapter, edit text, and fill gaps yourself or with advisor/writer help later.\n'
            'The draft is yours — review academically and linguistically before university submission.',
      ),
      SectionGuideStep(
        icon: Icons.picture_as_pdf_outlined,
        titleAr: '٥) صدّر المسودة',
        titleEn: '5) Export the draft',
        bodyAr: 'عند جاهزية جزئية استخدم زر التصدير/PDF في الشريط لحفظ نسخة خارجية.',
        bodyEn: 'When partly ready, use the export/PDF action in the app bar for an offline copy.',
      ),
      SectionGuideStep(
        icon: Icons.link,
        titleAr: '٦) اربط بأقسام أخرى',
        titleEn: '6) Connect other sections',
        bodyAr:
            'للمراجع والتنسيق استخدم قسم النشر؛ للمراجعة البشرية قسم الكتابة؛ للنزاهة قسم النزاهة الأكاديمية.',
        bodyEn:
            'For references/formatting use Publish; for human editing use Writing; for checks use Academic integrity.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com عند فشل التصدير أو فقدان المسودة.',
        bodyEn: 'acadegate@gmail.com if export fails or a draft seems lost.',
      ),
    ],
  );

  static const SectionGuide integrityGuide = SectionGuide(
    id: 'integrity',
    titleAr: 'دليل النزاهة الأكاديمية',
    titleEn: 'Academic integrity guide',
    introAr:
        'هذا القسم أدوات مساعدة للأمانة العلمية: فحص تشابه/أصالة، مراجع، منهجية، وإرشادات. '
        'النتيجة ليست بديلاً عن سياسات جامعتك أو موافقة مشرفك.',
    introEn:
        'This section offers integrity helpers: similarity/originality checks, references, methodology, and guidance. '
        'Results do not replace your university policies or supervisor approval.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول',
        titleEn: '1) Sign in',
        bodyAr: 'بعض فحوصات الأصالة أو حفظ التقارير قد تحتاج حساباً.',
        bodyEn: 'Some originality checks or report saves may require an account.',
      ),
      SectionGuideStep(
        icon: Icons.balance_outlined,
        titleAr: '٢) افتح النزاهة الأكاديمية',
        titleEn: '2) Open Academic integrity',
        bodyAr: 'من الرئيسية ادخل بطاقة النزاهة واقرأ المقدمة القصيرة أعلى الصفحة.',
        bodyEn: 'From Home open Integrity and read the short intro at the top.',
      ),
      SectionGuideStep(
        icon: Icons.search,
        titleAr: '٣) ابحث عن الأداة المناسبة',
        titleEn: '3) Search for the right tool',
        bodyAr:
            'استخدم مربع البحث: مراجع، تشابه، منهجية…\n'
            'ثم اضغط بطاقة الأداة واتبع التعليمات داخلها (رفع نص/ملف إن طُلب).',
        bodyEn:
            'Use search: references, similarity, methodology…\n'
            'Tap a tool card and follow its steps (paste/upload if asked).',
      ),
      SectionGuideStep(
        icon: Icons.fact_check_outlined,
        titleAr: '٤) فسّر النتيجة بمسؤولية',
        titleEn: '4) Interpret results responsibly',
        bodyAr:
            'نسبة تشابه مرتفعة تعني مراجعة الاقتباس وإعادة الصياغة — لا حذفاً أعمى.\n'
            'صحّح المراجع والاستشهادات قبل التسليم.',
        bodyEn:
            'A high similarity score means fix citation and paraphrasing — not blind deletion.\n'
            'Correct references before submission.',
      ),
      SectionGuideStep(
        icon: Icons.school_outlined,
        titleAr: '٥) التزم بلوائح جامعتك',
        titleEn: '5) Follow your university rules',
        bodyAr: 'ما يُقبل في منصة مساعدة قد لا يكفي لجنة جامعتك. اسأل مشرفك عن متطلبات النزاهة الرسمية.',
        bodyEn: 'What a helper tool accepts may not satisfy your committee. Ask your supervisor for official rules.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com عند فشل الرفع أو الفحص.',
        bodyEn: 'acadegate@gmail.com if upload or scanning fails.',
      ),
    ],
  );

  static const SectionGuide fundGuide = SectionGuide(
    id: 'fund',
    titleAr: 'دليل صندوق تمويل البحث والاستثمار',
    titleEn: 'Research fund & investment guide',
    introAr:
        'صندوق تمويل البحث يعرّف الناس بمسارين: (١) تمويل أفكار بحثية عبر التصويت ومراجعة الإدارة، '
        'و(٢) تحديات صناعية بعربون/ضمان يمكن للمستثمرين والشركات والمختبرات المشاركة فيها. '
        'حتى لو كان تفعيل شركاء الجامعات تدريجياً، القسم ظاهر ليتعرّف الناس ويستثمروا أو يموّلوا بوعي.',
    introEn:
        'The research fund introduces two paths: (1) funding research ideas via votes and admin review, '
        'and (2) industry challenges with escrow/deposit where investors, companies, and labs can take part. '
        'Even while university partners onboard gradually, the section is visible so people can learn and invest thoughtfully.',
    steps: [
      SectionGuideStep(
        icon: Icons.login,
        titleAr: '١) سجّل الدخول',
        titleEn: '1) Sign in',
        bodyAr: 'التصفح ممكن أحياناً، لكن التصويت والتمويل ونشر التحديات يحتاج حساباً.',
        bodyEn: 'Browsing may work sometimes; voting, funding actions, and posting challenges need an account.',
      ),
      SectionGuideStep(
        icon: Icons.volunteer_activism_outlined,
        titleAr: '٢) افتح صندوق تمويل البحث',
        titleEn: '2) Open Research Fund',
        bodyAr: 'من الرئيسية اضغط بطاقة «صندوق تمويل البحث».',
        bodyEn: 'From Home tap «Research Fund».',
      ),
      SectionGuideStep(
        icon: Icons.factory_outlined,
        titleAr: '٣) تحديات الصناعة (استثمار / عربون)',
        titleEn: '3) Industry challenges (invest / escrow)',
        bodyAr:
            'في أعلى الصفحة بطاقة تحديات الصناعة بعربون.\n'
            'ادخلها لتصفّح مشاكل صناعية حقيقية: الشركة تحبس عربوناً قبل البروتوكول.\n'
            'إن كنت باحثاً: قدّم حلاً/بروتوكولاً حسب الشاشة.\n'
            'إن كنت مستثمراً أو جهة صناعية: انشر تحدياً من بوابة المزوّد/الصناعة عند توفر الدور، '
            'والتزم بمبلغ العربون الظاهر قبل أي التزام بحثي.',
        bodyEn:
            'At the top is Industry challenges (escrow).\n'
            'Open it to browse real industrial problems: the company holds a deposit before any protocol.\n'
            'As a researcher: submit a solution/protocol as the screen asks.\n'
            'As an investor/industry partner: post a challenge from the provider/industry portal when your role allows, '
            'and commit the shown deposit before research work starts.',
      ),
      SectionGuideStep(
        icon: Icons.how_to_vote_outlined,
        titleAr: '٤) مسار تمويل الأفكار (تصويت)',
        titleEn: '4) Idea funding path (votes)',
        bodyAr:
            '١) انشر فكرة في سوق الأفكار أو صوّت لأفكار قوية.\n'
            '٢) عند بلوغ حد التصويت الأدنى تظهر ضمن «أفكار مؤهلة» هنا.\n'
            '٣) يراجعها المدير وقد يموّلها حتى الحد الأقصى الظاهر في بطاقة الإعداد.\n'
            'إن ظهر أن «صندوق الجامعات غير مُفعّل بعد»: تحديات الصناعة ما زالت متاحة للتعارف والاستثمار المبكر، '
            'وشراكات الجامعات تُفعَّل لاحقاً دون بيانات وهمية.',
        bodyEn:
            '1) Publish an idea in the marketplace or vote for strong ones.\n'
            '2) When the vote threshold is reached it appears under eligible ideas here.\n'
            '3) Admin reviews and may fund up to the max shown on the config card.\n'
            'If «university fund is not configured yet» still shows: industry challenges remain for early investment/discovery; '
            'university partners activate later — no fake default data.',
      ),
      SectionGuideStep(
        icon: Icons.history,
        titleAr: '٥) راجع التمويلات السابقة',
        titleEn: '5) Review past awards',
        bodyAr: 'أسفل الصفحة قائمة تمويلات سابقة إن وُجدت — لفهم ما يُموَّل فعلاً.',
        bodyEn: 'Lower on the page, past awards (if any) show what actually got funded.',
      ),
      SectionGuideStep(
        icon: Icons.lightbulb_outline,
        titleAr: '٦) اذهب لسوق الأفكار بسرعة',
        titleEn: '6) Jump to the ideas marketplace',
        bodyAr: 'الأزرار/البطاقات داخل الصندوق تفتح سوق الأفكار للتصفح والتصويت والنشر.',
        bodyEn: 'Buttons/cards inside the fund open the ideas marketplace to browse, vote, and publish.',
      ),
      SectionGuideStep(
        icon: Icons.handshake_outlined,
        titleAr: '٧) للمستثمر والشريك',
        titleEn: '7) For investors & partners',
        bodyAr:
            '• تعرّف على التحديات بعربون كآلية ثقة.\n'
            '• تواصل عبر acadegate@gmail.com لشراكة تمويل جامعي أو رعاية تحديات.\n'
            '• لا ترسل أموالاً خارج القنوات الرسمية داخل التطبيق/العربون المعروض.',
        bodyEn:
            '• Learn escrow challenges as a trust mechanism.\n'
            '• Email acadegate@gmail.com for university fund partnership or challenge sponsorship.\n'
            '• Do not send money outside official in-app/escrow channels.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'شفافية البيتا',
        titleEn: 'Beta transparency',
        bodyAr:
            'قد تكون بعض حدود التمويل قيد الضبط مع الشركاء. لا تُعرض أرقام دعم وهمية — ما تراه في الإعدادات هو المرجع.',
        bodyEn:
            'Some award limits may still be tuned with partners. No fake support figures — on-screen config is the source of truth.',
      ),
      SectionGuideNote(
        titleAr: 'التواصل',
        titleEn: 'Contact',
        bodyAr: 'شراكات واستثمار: acadegate@gmail.com',
        bodyEn: 'Partnerships & investment: acadegate@gmail.com',
      ),
    ],
  );

  static const SectionGuide newsGuide = SectionGuide(
    id: 'news',
    titleAr: 'دليل الأخبار العلمية',
    titleEn: 'Science news guide',
    introAr:
        'قسم الأخبار يعرض مستجدات علمية للقراءة والاستلهام — ليس بديلاً عن مراجعة الأدبيات الرسمية لرسالتك.',
    introEn:
        'Science news shows research updates for reading and inspiration — not a substitute for formal literature review.',
    steps: [
      SectionGuideStep(
        icon: Icons.newspaper_outlined,
        titleAr: '١) افتح الأخبار العلمية',
        titleEn: '1) Open Science news',
        bodyAr: 'من الرئيسية اضغط بطاقة الأخبار.',
        bodyEn: 'From Home tap the News card.',
      ),
      SectionGuideStep(
        icon: Icons.filter_list,
        titleAr: '٢) صفِّ حسب المجال إن وُجد',
        titleEn: '2) Filter by field if available',
        bodyAr: 'شريط التصنيفات أعلى القائمة يضيّق الأخبار حسب اهتمامك.',
        bodyEn: 'Category chips above the list narrow news to your interest.',
      ),
      SectionGuideStep(
        icon: Icons.article_outlined,
        titleAr: '٣) اقرأ الخبر وافتح المصدر',
        titleEn: '3) Read and open the source',
        bodyAr:
            'اضغط خبراً لقراءة الملخص ثم افتح الرابط الخارجي عند الحاجة.\n'
            'تحقق من المصدر قبل الاقتباس في بحثك.',
        bodyEn:
            'Tap an item for the summary, then open the external link when needed.\n'
            'Verify the source before citing in your research.',
      ),
      SectionGuideStep(
        icon: Icons.refresh,
        titleAr: '٤) حدّث القائمة',
        titleEn: '4) Refresh the feed',
        bodyAr: 'زر التحديث في الشريط يعيد جلب أحدث الأخبار.',
        bodyEn: 'The refresh icon reloads the latest items.',
      ),
      SectionGuideStep(
        icon: Icons.lightbulb_outline,
        titleAr: '٥) حوّل الإلهام إلى عمل',
        titleEn: '5) Turn inspiration into action',
        bodyAr:
            'إن ألهمك خبر: افتح سوق الأفكار أو المطابقة أو مسار البحث لصياغة سؤال بحثي قابل للتنفيذ على المنصة.',
        bodyEn:
            'If a story inspires you: open Ideas, Matching, or Research path to shape an actionable research question on the platform.',
      ),
    ],
    notes: [
      SectionGuideNote(
        titleAr: 'الدعم',
        titleEn: 'Support',
        bodyAr: 'acadegate@gmail.com إن بقيت القائمة فارغة بعد التحديث.',
        bodyEn: 'acadegate@gmail.com if the list stays empty after refresh.',
      ),
    ],
  );
}
