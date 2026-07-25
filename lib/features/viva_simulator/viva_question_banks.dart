import '../academic/faculty_categories.dart';
import 'viva_committee.dart';

/// Realistic viva-style question banks inspired by common thesis-defense
/// themes across universities (contribution, novelty, methods, ethics,
/// limitations, implications) — specialized lightly by faculty.
class VivaQuestionBanks {
  VivaQuestionBanks._();

  /// [ar, en] pairs.
  static List<List<String>> forMember({
    required String memberId,
    String? facultyCategoryId,
  }) {
    final faculty = facultyCategoryId == null || facultyCategoryId.isEmpty
        ? null
        : facultyById(facultyCategoryId);
    final specialty = _specialtyExtra(faculty?.id);
    final core = _coreByMember[memberId] ?? _coreByMember['supervisor']!;
    return [...core, ...specialty];
  }

  static const _coreByMember = <String, List<List<String>>>{
    'supervisor': [
      [
        'ما المساهمة الأصلية التي تقدمها دراستك في «{title}» مقارنة بالدراسات السابقة؟',
        'What original contribution does your study on «{title}» make compared to prior research?',
      ],
      [
        'لماذا اخترت هذا الموضوع تحديداً، وما أهميته العلمية والتطبيقية الآن؟',
        'Why did you choose this topic, and what is its scientific and practical importance now?',
      ],
      [
        'كيف ترتبط أهدافك البحثية بمشكلة البحث التي عرضتها في المقدمة؟',
        'How do your research objectives link to the research problem stated in your introduction?',
      ],
      [
        'ما الفجوة البحثية التي سدّتها دراستك، وكيف برهنت على وجودها من الأدبيات؟',
        'What research gap did your study fill, and how did you evidence that gap from the literature?',
      ],
      [
        'لخّص نتائجك الرئيسية في دقيقتين، واربطها مباشرة بأسئلتك البحثية.',
        'Summarize your key findings in two minutes and link them directly to your research questions.',
      ],
      [
        'ما التوصيات العملية أو النظرية التي تستخلصها، ومن المستفيد منها؟',
        'What practical or theoretical recommendations do you draw, and who benefits from them?',
      ],
      [
        'لو طُلب منك نشر ورقة من الرسالة، أي فصل تختار ولماذا؟',
        'If asked to publish a paper from the thesis, which chapter would you choose and why?',
      ],
    ],
    'external': [
      [
        'هل المنهجية ({methodology}) هي الأنسب لطبيعة بياناتك؟ برّر اختيارك باختصار.',
        'Is the ({methodology}) methodology best suited to your data? Briefly justify your choice.',
      ],
      [
        'ما أبرز حدود دراستك، وكيف تعاملت معها أثناء التنفيذ؟',
        'What are the main limitations of your study, and how did you address them during execution?',
      ],
      [
        'إذا أُجريت الدراسة مجدداً، ما الذي ستغيّره في التصميم البحثي؟',
        'If you ran the study again, what would you change in the research design?',
      ],
      [
        'كيف تضمن أن نتائجك قابلة للتكرار أو النقل إلى سياقات مشابهة؟',
        'How do you ensure your findings are replicable or transferable to similar contexts?',
      ],
      [
        'ما أقوى نقد يمكن أن يوجّهه باحث متخصص لتصميم دراستك؟ وكيف ترد عليه؟',
        'What is the strongest critique a specialist could make of your design, and how would you respond?',
      ],
      [
        'هل توجد متغيرات أو عوامل لم تُضبط وقد تفسّر جزءاً من النتائج؟',
        'Are there uncontrolled variables or factors that might partly explain the results?',
      ],
      [
        'كيف تميّز دراستك عن أحدث الأعمال المنشورة (2023–2026) في المجال؟',
        'How does your study differ from the most recent published work (2023–2026) in the field?',
      ],
    ],
    'methodology': [
      [
        'وضّح منطق اختيار العينة وحجمها في سياق تخصص «{specialization}».',
        'Explain the rationale for your sample selection and size in «{specialization}».',
      ],
      [
        'كيف ضمنت صدق وثبات أدوات جمع البيانات أو تحليلها؟',
        'How did you ensure the validity and reliability of your data collection or analysis tools?',
      ],
      [
        'ما الإجراءات الأخلاقية التي اتبعتها عند جمع البيانات أو التعامل مع المشاركين؟',
        'What ethical procedures did you follow when collecting data or working with participants?',
      ],
      [
        'لماذا استبعدت منهجيات بديلة كانت متاحة لنفس السؤال البحثي؟',
        'Why did you reject alternative methodologies that could address the same research question?',
      ],
      [
        'كيف تعاملت مع البيانات الناقصة أو القيم الشاذة أو التحيز المحتمل؟',
        'How did you handle missing data, outliers, or potential bias?',
      ],
      [
        'ما معايير الإدراج والاستبعاد، وهل أثّرت على قابلية تعميم النتائج؟',
        'What were the inclusion/exclusion criteria, and did they affect generalizability?',
      ],
      [
        'اشرح خطوة بخطوة كيف انتقلت من البيانات الخام إلى الاستنتاجات.',
        'Walk through step by step how you moved from raw data to conclusions.',
      ],
    ],
  };

  static List<List<String>> _specialtyExtra(String? facultyId) {
    switch (facultyId) {
      case 'Medicine':
      case 'Dentistry':
      case 'Pharmacy':
      case 'Nursing':
      case 'Veterinary':
        return const [
          [
            'كيف راعيت سلامة المرضى/المشاركين وموافقة الأخلاقيات الطبية؟',
            'How did you address patient/participant safety and medical ethics approval?',
          ],
          [
            'هل حجم العينة كافٍ إحصائياً لاكتشاف الأثر السريري المتوقع؟',
            'Is the sample size statistically adequate to detect the expected clinical effect?',
          ],
          [
            'كيف تربط نتائجك بالدلائل الإرشادية السريرية أو الممارسة اليومية؟',
            'How do your findings relate to clinical guidelines or daily practice?',
          ],
        ];
      case 'Engineering':
      case 'Architecture':
      case 'CS':
        return const [
          [
            'ما معايير الأداء التي استخدمتها، ولماذا هذه المقاييس تحديداً؟',
            'What performance metrics did you use, and why those metrics specifically?',
          ],
          [
            'هل قارنت مقترحك بخطوط أساس (baselines) معتمدة؟ وما الفرق الجوهري؟',
            'Did you compare your proposal to accepted baselines? What is the essential difference?',
          ],
          [
            'ما قيود التنفيذ العملي أو التكلفة أو قابلية التوسع لنظامك؟',
            'What are the practical, cost, or scalability constraints of your system?',
          ],
        ];
      case 'Science':
      case 'Agriculture':
        return const [
          [
            'كيف ضمنت قابلية تكرار التجربة وضبط الظروف المخبرية/الميدانية؟',
            'How did you ensure experimental reproducibility and control lab/field conditions?',
          ],
          [
            'ما الاختبارات الإحصائية المستخدمة ولماذا تناسب توزيع بياناتك؟',
            'Which statistical tests did you use and why do they fit your data distribution?',
          ],
          [
            'هل نتائجك متسقة مع النظريات أو النماذج المعتمدة في المجال؟',
            'Are your results consistent with established theories or models in the field?',
          ],
        ];
      case 'Law':
        return const [
          [
            'ما الإطار التشريعي أو القضائي الذي اعتمدت عليه، وكيف تعاملت مع التعارض بين النصوص؟',
            'What legislative or judicial framework did you rely on, and how did you handle conflicting texts?',
          ],
          [
            'هل دراستك تحليلية مقارنة أم تطبيقية، وكيف يؤثر ذلك على قوة الحجة؟',
            'Is your study comparative-analytical or applied, and how does that affect argument strength?',
          ],
        ];
      case 'Business':
      case 'Tourism':
        return const [
          [
            'كيف ترجمت نتائجك إلى توصيات إدارية قابلة للتنفيذ لصنّاع القرار؟',
            'How did you translate findings into actionable managerial recommendations for decision-makers?',
          ],
          [
            'ما حدود تعميم نتائجك على مؤسسات أو أسواق مختلفة؟',
            'What are the limits of generalizing your findings to different organizations or markets?',
          ],
        ];
      case 'Education':
      case 'Arts':
      case 'MassCommunication':
      case 'PhysicalEducation':
      case 'FineArts':
        return const [
          [
            'كيف راعيت السياق الثقافي/التربوي عند تفسير النتائج؟',
            'How did you account for the cultural/educational context when interpreting results?',
          ],
          [
            'ما أثر دراستك على الممارسة المهنية أو المناهج أو الجمهور المستهدف؟',
            'What is the impact of your study on professional practice, curricula, or the target audience?',
          ],
        ];
      default:
        return const [
          [
            'كيف تقنع لجنة متعددة التخصصات بأهمية دراستك خارج نطاق تخصصك الضيق؟',
            'How would you convince a multidisciplinary committee of your study’s importance beyond your narrow specialty?',
          ],
        ];
    }
  }

  static String cloudStyleGuide({
    required String? facultyCategoryId,
    required String specialization,
    required int questionIndex,
    required int maxQuestions,
  }) {
    final faculty = facultyCategoryId == null || facultyCategoryId.isEmpty
        ? null
        : facultyById(facultyCategoryId);
    final fieldLabel = faculty?.titleAr ?? specialization;
    final phase = questionIndex < (maxQuestions / 3)
        ? 'opening (problem, novelty, aims)'
        : questionIndex < (2 * maxQuestions / 3)
            ? 'methods & rigor'
            : 'findings, limitations, implications & closing';

    return '''
Generate ONE viva voce (thesis defense) question as typically asked by real university examiners
in Egypt and the Arab region.

CRITICAL — ground the question in THIS thesis materials provided in the user message
(Title, Summary, DefenseContextFromThesis, ThesisExcerpt). You MUST:
- Reference a concrete claim, aim, method, sample detail, finding, or limitation from those materials
  (paraphrase or short quote; do not invent facts not present there).
- Ask something an examiner would only ask AFTER reading THIS thesis — not a generic template
  that could apply to any thesis in $fieldLabel.
- Forbidden: vague questions like "what is your contribution?" without tying them to the stated
  title/aims/findings; forbidden: purely specialty trivia unrelated to the submitted text.

Field focus: $fieldLabel
Session progress: question ${questionIndex + 1} of $maxQuestions — prefer themes for: $phase
Rotate across: contribution vs stated aims, literature gap vs claimed novelty, methodology vs
declared design, sampling as described, validity/reliability, ethics, analysis of reported
results, limitations as stated, implications, future work.
One question only. No preamble, no answer.
''';
  }
}

/// Convenience: member ids match [VivaCommitteeMember.id].
List<String> vivaCommitteeMemberIds() =>
    VivaCommittee.members.map((m) => m.id).toList();
