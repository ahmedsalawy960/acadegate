import '../auth/user_account.dart';

/// One thing the user can spend. The count is what they see; the kind is
/// only how the server meters it.
class PlanAllowance {
  final String titleAr;
  final String titleEn;
  final String countsAr;
  final String countsEn;
  final int perMonth;
  final int perDay;

  const PlanAllowance({
    required this.titleAr,
    required this.titleEn,
    required this.countsAr,
    required this.countsEn,
    required this.perMonth,
    required this.perDay,
  });

  bool get included => perMonth > 0;
}

class AppPlan {
  final String id;
  final String nameAr;
  final String nameEn;
  final String summaryAr;
  final String summaryEn;
  final int priceEgp;
  final List<PlanAllowance> allowances;

  const AppPlan({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.summaryAr,
    required this.summaryEn,
    required this.priceEgp,
    required this.allowances,
  });
}

class AppPlans {
  AppPlans._();

  static const includedEverywhere = <(String, String)>[
    ('تصفح المشرفين واقتراح الأنسب لتخصصك', 'Browse supervisors and see who fits your field'),
    ('دليل المختبرات وحجز الأجهزة وطلب تحليل العينات', 'Labs, device booking, and sample analysis'),
    ('المتجر: التصفح والسلة والطلب والدفع', 'Store browsing, cart, orders, and payment'),
    ('الرسائل بينك وبين المشرف أو البائع', 'Messages with a supervisor or seller'),
    ('ملفك الأكاديمي وبيانات حسابك', 'Your academic profile and account details'),
    ('متابعة خطوات رسالتك يدوياً', 'Tracking your thesis steps yourself'),
    ('طلب كتابة من متخصص', 'Ordering writing from a person'),
    ('الأخبار العلمية', 'Science news'),
    ('ترتيب مراجع رسالتك من الفهارس المفتوحة', 'Formatting references from open indexes'),
  ];

  static List<PlanAllowance> _allowances({
    required int writingMonth,
    required int writingDay,
    required int referencesMonth,
    required int referencesDay,
    required int synthesisMonth,
    required int synthesisDay,
    required int originalityMonth,
    required int originalityDay,
  }) {
    return [
      PlanAllowance(
        titleAr: 'المساعدة في الكتابة والتخطيط',
        titleEn: 'Help with writing and planning',
        countsAr:
            'يُحسب طلباً واحداً في كل مرة تطلب: إجابة من المساعد، عنواناً أو خطة أو منهجية، '
            'كتابة فقرة أو مراجعتها، تدريب مناقشة، مسار بحث، فحص منهجية، فكرة من بنك الموضوعات، '
            'تجهيز بحث للنشر، مقارنة منتج أو محاكاة تجربة أو شرح تجميع، أو تحويل صوت إلى نص.',
        countsEn:
            'One request each time you ask for an assistant answer, a title, plan, or method, '
            'a written or revised paragraph, viva practice, a research path, a method check, '
            'a topic idea, publication help, a product comparison, a protocol simulation, '
            'assembly guidance, or voice turned into text.',
        perMonth: writingMonth,
        perDay: writingDay,
      ),
      PlanAllowance(
        titleAr: 'جلب مراجع ودراسات سابقة',
        titleEn: 'Finding references and prior studies',
        countsAr: 'يُحسب بحثاً واحداً كلما طلبت قائمة دراسات أو مراجع في موضوع.',
        countsEn: 'One search each time you ask for studies or references on a topic.',
        perMonth: referencesMonth,
        perDay: referencesDay,
      ),
      PlanAllowance(
        titleAr: 'خلاصة ما توصلت إليه الدراسات',
        titleEn: 'What the studies conclude',
        countsAr: 'يُحسب سؤالاً واحداً كلما سألت: ماذا اتفقت عليه الدراسات في هذا الموضوع؟',
        countsEn: 'One question each time you ask what the studies agree on.',
        perMonth: synthesisMonth,
        perDay: synthesisDay,
      ),
      PlanAllowance(
        titleAr: 'فحص التشابه والأصالة',
        titleEn: 'Similarity and originality check',
        countsAr: 'يُحسب فحصاً واحداً كلما فحصت نصاً أو ملفاً قبل التسليم.',
        countsEn: 'One check each time you scan a text or file before submission.',
        perMonth: originalityMonth,
        perDay: originalityDay,
      ),
    ];
  }

  static AppPlan byId(String id) {
    for (final plan in plans) {
      if (plan.id == id) return plan;
    }
    return plans.first;
  }

  static final plans = <AppPlan>[
    AppPlan(
      id: SubscriptionTier.free,
      nameAr: 'مجانية',
      nameEn: 'Free',
      summaryAr: 'كل ما لا يحتاج رصيداً: التصفح والحجز والطلب والمتابعة.',
      summaryEn: 'Everything that needs no balance: browsing, booking, orders, and tracking.',
      priceEgp: 0,
      allowances: _allowances(
        writingMonth: 0,
        writingDay: 0,
        referencesMonth: 0,
        referencesDay: 0,
        synthesisMonth: 0,
        synthesisDay: 0,
        originalityMonth: 0,
        originalityDay: 0,
      ),
    ),
    AppPlan(
      id: SubscriptionTier.plus,
      nameAr: 'أساسية',
      nameEn: 'Plus',
      summaryAr:
          'رصيد شهر كامل لجلسات الكتابة والمراجع. السقف اليومي يمنع أن يُستهلك الشهر في يوم واحد، ويتجدد المتبقي كل شهر.',
      summaryEn:
          'A month of writing and reference sessions. The daily ceiling stops one day from using the whole month, and the balance renews each month.',
      priceEgp: 550,
      allowances: _allowances(
        writingMonth: 300,
        writingDay: 40,
        referencesMonth: 90,
        referencesDay: 15,
        synthesisMonth: 45,
        synthesisDay: 8,
        originalityMonth: 15,
        originalityDay: 2,
      ),
    ),
    AppPlan(
      id: SubscriptionTier.pro,
      nameAr: 'شاملة',
      nameEn: 'Pro',
      summaryAr:
          'رصيد شهر للكتابة المكثفة، مع إجابات أعمق في المساعد. السقف اليومي يحمي الرصيد، ويتجدد كل شهر.',
      summaryEn:
          'A month of intensive writing, with deeper assistant answers. The daily ceiling protects the balance, which renews each month.',
      priceEgp: 3350,
      allowances: _allowances(
        writingMonth: 1500,
        writingDay: 120,
        referencesMonth: 450,
        referencesDay: 40,
        synthesisMonth: 225,
        synthesisDay: 20,
        originalityMonth: 75,
        originalityDay: 6,
      ),
    ),
  ];
}
