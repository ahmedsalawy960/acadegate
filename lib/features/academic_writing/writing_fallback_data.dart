import 'writing_models.dart';

const fallbackWritingExperts = <WritingExpert>[
  WritingExpert(
    id: 'demo-stats-1',
    name: 'د. سارة محمود',
    category: 'إحصاء وتحليل',
    speciality: 'تحليل كمي — SPSS و AMOS',
    bio:
        'أخصائية إحصاء تطبيقي. أجهّز تحليل البيانات، اختبار الفرضيات، '
        'وتفسير النتائج مع جداول جاهزة للرسالة.',
    priceRange: '800 – 2500 ج.م',
    deliveryDaysMin: 2,
    deliveryDaysMax: 7,
    rating: 4.9,
    completedOrders: 86,
    languages: ['العربية', 'الإنجليزية'],
    tools: ['SPSS', 'AMOS', 'Excel'],
    tags: ['رسالة', 'SPSS', 'انحدار', 'عوامل'],
    contact: 'stats.sara@example.com',
  ),
  WritingExpert(
    id: 'demo-thesis-1',
    name: 'أ. محمد الحسيني',
    category: 'رسائل علمية',
    speciality: 'رسائل ماجستير ودكتوراه — علوم تطبيقية',
    bio:
        'كاتب أكاديمي بخبرة 12 سنة في إعداد فصول الرسالة، '
        'المنهجية، والمناقشة مع الالتزام بمعايير الجامعة.',
    priceRange: '1500 – 8000 ج.م',
    deliveryDaysMin: 7,
    deliveryDaysMax: 30,
    rating: 4.7,
    completedOrders: 124,
    languages: ['العربية'],
    tags: ['ماجستير', 'دكتوراه', 'فصل منهجية'],
    contact: 'thesis.mh@example.com',
  ),
  WritingExpert(
    id: 'demo-paper-1',
    name: 'Dr. Layla Nasser',
    category: 'أوراق بحثية',
    speciality: 'Research papers — Engineering & CS',
    bio:
        'Peer-review experience. Full paper drafting, abstract, '
        'literature gap, and journal formatting (IEEE / Elsevier).',
    priceRange: '1200 – 4500 ج.م',
    deliveryDaysMin: 5,
    deliveryDaysMax: 21,
    rating: 4.8,
    completedOrders: 67,
    languages: ['الإنجليزية', 'ثنائي اللغة (عربي + إنجليزي)'],
    tags: ['IEEE', 'Scopus', 'conference'],
    contact: 'layla.n@example.com',
  ),
  WritingExpert(
    id: 'demo-review-1',
    name: 'أ. نورا عبد الله',
    category: 'مراجعة أدبيات',
    speciality: 'مراجعة منهجية وخريطة مفاهيمية',
    bio:
        'أعدّ مراجعات أدبيات منظمة حسب PRISMA أو narrative review '
        'مع جداول مقارنة ومصادر حديثة.',
    priceRange: '600 – 2200 ج.م',
    deliveryDaysMin: 4,
    deliveryDaysMax: 14,
    rating: 4.6,
    completedOrders: 53,
    languages: ['العربية', 'الإنجليزية'],
    tags: ['PRISMA', 'Scoping review'],
    contact: 'nora.review@example.com',
  ),
  WritingExpert(
    id: 'demo-edit-1',
    name: 'فريق تدقيق AcadeGate',
    category: 'تحرير وتدقيق',
    speciality: 'لغة أكاديمية — APA و Harvard',
    bio:
        'تدقيق لغوي ونحوي، إعادة صياغة، وتوحيد المصطلحات '
        'مع تقرير التعديلات.',
    priceRange: '400 – 1800 ج.م',
    deliveryDaysMin: 1,
    deliveryDaysMax: 5,
    rating: 4.5,
    completedOrders: 210,
    languages: ['العربية', 'الإنجليزية'],
    tags: ['APA', 'proofreading'],
    contact: 'editing@acadegate.example',
  ),
  WritingExpert(
    id: 'demo-proposal-1',
    name: 'د. خالد عمر',
    category: 'مقترحات بحث',
    speciality: 'مقترحات ماجستير ومنح',
    bio:
        'صياغة مشكلة البحث، أسئلة، أهداف، ومنهجية '
        'متوافقة مع لجان المناقشة.',
    priceRange: '500 – 1500 ج.م',
    deliveryDaysMin: 3,
    deliveryDaysMax: 10,
    rating: 4.7,
    completedOrders: 91,
    languages: ['العربية'],
    tags: ['مقترح', 'خطة بحث'],
    contact: 'proposal.k@example.com',
  ),
];

List<WritingExpert> fallbackExpertsForCategory(String categoryTitle) {
  return fallbackWritingExperts
      .where((expert) => expert.category == categoryTitle)
      .toList();
}
