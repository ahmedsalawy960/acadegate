import '../../core/assets/weekly_image_rotator.dart';

/// ميزة بارزة تُعرض في كاروسيل أعلى الصفحة الرئيسية (ليست بطاقة قسم).
class HomeFeatureHighlight {
  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final String linkTarget;

  const HomeFeatureHighlight({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.subtitleAr = '',
    this.subtitleEn = '',
    required this.linkTarget,
  });

  String title(bool arabic) => arabic ? titleAr : titleEn;
  String subtitle(bool arabic) => arabic ? subtitleAr : subtitleEn;

  /// صورة أصلية تتبدّل أسبوعياً من مجلد التطبيق.
  String get imageUrl => AcadeGateWeeklyImages.feature(id);
}

/// أبرز مزايا AcadeGate للعرض العلوي المتحرك.
class HomeFeatureHighlights {
  HomeFeatureHighlights._();

  static List<HomeFeatureHighlight> topTen() => const [
        HomeFeatureHighlight(
          id: 'feat_path',
          titleAr: 'مسار بحث متكامل في خطوة',
          titleEn: 'Full research path in one step',
          subtitleAr: 'مشرف + مختبر + متجر + كتابة معاً',
          subtitleEn: 'Supervisor, lab, store, and writing together',
          linkTarget: 'research_path',
        ),
        HomeFeatureHighlight(
          id: 'feat_thesis',
          titleAr: 'استوديو الرسالة من هدف واحد',
          titleEn: 'Thesis Studio from one goal',
          subtitleAr: 'فصول وملخص من دراسات DOI مؤكدة',
          subtitleEn: 'Chapters and abstract from DOI-confirmed studies',
          linkTarget: 'thesis_studio',
        ),
        HomeFeatureHighlight(
          id: 'feat_match',
          titleAr: 'مطابقة مشرف حسب تخصصك',
          titleEn: 'Supervisor match by specialty',
          subtitleAr: 'اقتراحات أدق من ملفك الأكاديمي',
          subtitleEn: 'Smarter picks from your academic profile',
          linkTarget: 'matchmaking',
        ),
        HomeFeatureHighlight(
          id: 'feat_supervisors',
          titleAr: 'دليل مشرفين بمقاييس نشر',
          titleEn: 'Supervisors with publication metrics',
          subtitleAr: 'OpenAlex وh-index وتصنيف المجلات',
          subtitleEn: 'OpenAlex, h-index, and journal ranks',
          linkTarget: 'supervisors',
        ),
        HomeFeatureHighlight(
          id: 'feat_labs',
          titleAr: 'حجز أجهزة وتحليل عينات',
          titleEn: 'Book equipment & sample analysis',
          subtitleAr: 'مختبرات ومراكز تحليل في مكان واحد',
          subtitleEn: 'Labs and analysis centers in one place',
          linkTarget: 'labs',
        ),
        HomeFeatureHighlight(
          id: 'feat_ai',
          titleAr: 'مساعد AI بـ 11 وكيلاً',
          titleEn: 'AI advisor with 11 agents',
          subtitleAr: 'خطة رسالة، مراجع، منهجية، وتحرير',
          subtitleEn: 'Thesis plan, citations, methods, editing',
          linkTarget: 'ai',
        ),
        HomeFeatureHighlight(
          id: 'feat_escrow',
          titleAr: 'شراء بضمان Escrow',
          titleEn: 'Buy with Escrow protection',
          subtitleAr: 'المبلغ يُحجز حتى تأكيد الاستلام',
          subtitleEn: 'Payment held until you confirm delivery',
          linkTarget: 'store',
        ),
        HomeFeatureHighlight(
          id: 'feat_writing',
          titleAr: 'كتابة أكاديمية بشرية',
          titleEn: 'Human academic writing',
          subtitleAr: 'خبراء متخصصون — ليست نصوص AI عامة',
          subtitleEn: 'Specialist experts — not generic AI text',
          linkTarget: 'writing',
        ),
        HomeFeatureHighlight(
          id: 'feat_ideas',
          titleAr: 'سوق أفكار بحثية',
          titleEn: 'Research ideas marketplace',
          subtitleAr: 'انشر فكرة، صوّت، وقدّم مقترحاً',
          subtitleEn: 'Publish, vote, and submit proposals',
          linkTarget: 'ideas',
        ),
        HomeFeatureHighlight(
          id: 'feat_community',
          titleAr: 'مجتمع وغرف بحث محمية',
          titleEn: 'Community & private research rooms',
          subtitleAr: 'نقاشات تخصصية وغرف بكلمة مرور',
          subtitleEn: 'Faculty rooms and password-protected spaces',
          linkTarget: 'community',
        ),
        HomeFeatureHighlight(
          id: 'feat_integrity',
          titleAr: 'نزاهة وأصالة أكاديمية',
          titleEn: 'Academic integrity tools',
          subtitleAr: 'أدوات تدعم الأمانة في البحث والنشر',
          subtitleEn: 'Tools that support honest research and publishing',
          linkTarget: 'integrity',
        ),
      ];
}
