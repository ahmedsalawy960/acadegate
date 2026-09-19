import '../../core/config/feature_flags.dart';
import 'home_feed_models.dart';
import 'dashboard_card.dart';

/// ترتيب وبنرات افتراضية — تُستخدم عند فراغ Firestore وتُزرع اختيارياً من الأدمن.
class HomeFeedSeed {
  HomeFeedSeed._();

  static List<HomeSection> defaultSections() => const [
        // أعلى الصفحة: كاروسيل أبرز 10 مزايا (صورة + عنوان).
        HomeSection(id: 'sec_hero', type: HomeSectionType.heroCarousel, order: 10),
        HomeSection(id: 'sec_journey', type: HomeSectionType.journey, order: 20),
        HomeSection(id: 'sec_for_you', type: HomeSectionType.forYou, order: 30),
        HomeSection(
          id: 'sec_services',
          type: HomeSectionType.servicesGrid,
          order: 40,
          adBreaks: [4, 8],
          adPlacements: ['mid_1', 'mid_2'],
        ),
        HomeSection(id: 'sec_footer', type: HomeSectionType.footer, order: 100),
      ];

  /// إن وُجد تقسيم قديم (عدة شبكات خدمات + خانات إعلان منفصلة) نستخدم التخطيط الجديد.
  static bool looksChunked(List<HomeSection> sections) {
    final grids = sections
        .where((s) => s.type == HomeSectionType.servicesGrid)
        .length;
    final ads =
        sections.where((s) => s.type == HomeSectionType.adSlot).length;
    return grids >= 2 || ads >= 1;
  }

  static List<HomePromoBanner> defaultBanners() {
    final banners = <HomePromoBanner>[
      HomePromoBanner(
          id: 'banner_path',
          titleAr: 'مسار البحث الذكي',
          titleEn: 'Smart Research Path',
          subtitleAr: 'حزمة متكاملة: مشرف + مختبر + متجر + كتابة في خطوة واحدة',
          subtitleEn: 'One bundle: supervisor, lab, store, and writing support',
          imageUrl: HomeServiceImages.researchPath,
          linkType: 'route',
          linkTarget: 'research_path',
          placement: 'hero',
          kind: 'feature',
          weight: 5,
          accentColor: 0xFF006064,
          ctaAr: 'ابدأ المسار',
          ctaEn: 'Start path',
        ),
        HomePromoBanner(
          id: 'banner_thesis',
          titleAr: 'استوديو الرسالة',
          titleEn: 'Thesis Studio',
          subtitleAr: 'عنوان وملخص وفصول من هدف واحد — مراجع DOI مؤكدة فقط',
          subtitleEn: 'Title, abstract, and chapters from one goal — DOI-confirmed sources only',
          imageUrl: HomeServiceImages.thesisStudio,
          linkType: 'route',
          linkTarget: 'thesis_studio',
          placement: 'hero',
          kind: 'feature',
          weight: 5,
          accentColor: 0xFF1A237E,
          ctaAr: 'ابدأ المسودة',
          ctaEn: 'Start draft',
        ),
        HomePromoBanner(
          id: 'banner_labs',
          titleAr: 'مختبرات ومراكز تحليل',
          titleEn: 'Labs & Analysis Centers',
          subtitleAr: 'احجز جهازاً أو اطلب تحليل عينة من دليل المختبرات',
          subtitleEn: 'Book equipment or request sample analysis',
          imageUrl: HomeServiceImages.labs,
          linkType: 'route',
          linkTarget: 'labs',
          placement: 'hero',
          kind: 'feature',
          weight: 4,
          accentColor: 0xFF6A1B9A,
          ctaAr: 'تصفّح المختبرات',
          ctaEn: 'Browse labs',
        ),
        HomePromoBanner(
          id: 'banner_ai',
          titleAr: 'مساعد AcadeGate AI',
          titleEn: 'AcadeGate AI Advisor',
          subtitleAr: '11 وكيلاً متخصصاً لخطة الرسالة والمراجع والمنهجية',
          subtitleEn: '11 specialist agents for thesis planning and writing',
          imageUrl: HomeServiceImages.aiAdvisor,
          linkType: 'route',
          linkTarget: 'ai',
          placement: 'hero',
          kind: 'feature',
          weight: 4,
          accentColor: 0xFF4527A0,
          ctaAr: 'اسأل المساعد',
          ctaEn: 'Ask AI',
        ),
        // إعلانات وسط — ليست نسخاً من بطاقات الأقسام
        HomePromoBanner(
          id: 'ad_escrow_trust',
          titleAr: 'ادفع بثقة داخل المنصة',
          titleEn: 'Pay with in-app protection',
          subtitleAr:
              'نظام ضمان Escrow يحجز المبلغ حتى تأكيد الاستلام — للطلبات والمتجر',
          subtitleEn:
              'Escrow holds payment until you confirm delivery — for orders and store',
          imageUrl: '',
          linkType: 'route',
          linkTarget: 'store',
          placement: 'mid_1',
          kind: 'sponsored',
          weight: 4,
          accentColor: 0xFF1565C0,
          ctaAr: 'تعرّف على الضمان',
          ctaEn: 'About Escrow',
        ),
        HomePromoBanner(
          id: 'ad_profile_boost',
          titleAr: 'ملف أكاديمي أدق = مطابقة أفضل',
          titleEn: 'Richer profile = better matching',
          subtitleAr:
              'أضف كليتك وتخصصك واهتمامك البحثي لتحسين اقتراحات المشرفين',
          subtitleEn:
              'Add faculty, specialty, and research interest for better supervisor picks',
          imageUrl: '',
          linkType: 'route',
          linkTarget: 'matchmaking',
          placement: 'mid_1',
          kind: 'sponsored',
          weight: 3,
          accentColor: 0xFF283593,
          ctaAr: 'حسّن ملفك',
          ctaEn: 'Improve profile',
        ),
        HomePromoBanner(
          id: 'ad_partner_slot',
          titleAr: 'مساحة إعلان للشركاء',
          titleEn: 'Partner ad space',
          subtitleAr:
              'جامعات · مختبرات · موردون — تواصل للإعلان هنا دون مزاحمة بطاقات الخدمات',
          subtitleEn:
              'Universities, labs, suppliers — advertise here without crowding service cards',
          imageUrl: '',
          linkType: 'route',
          linkTarget: 'news',
          placement: 'mid_2',
          kind: 'sponsored',
          weight: 4,
          accentColor: 0xFF455A64,
          ctaAr: 'تفاصيل الشراكة',
          ctaEn: 'Partnership info',
        ),
    ];
    if (AcadeGateFeatureFlags.showPilotUniversityAds) {
      banners.add(
        const HomePromoBanner(
          id: 'ad_beta_invite',
          titleAr: 'برنامج تجريبي للجامعات',
          titleEn: 'University pilot program',
          subtitleAr: 'انضم لمرحلة الـ Pilot واستورد مشرفين ومختبراتك دفعة واحدة',
          subtitleEn: 'Join the pilot and bulk-import supervisors and labs',
          imageUrl: '',
          linkType: 'route',
          linkTarget: 'publish',
          placement: 'mid_2',
          kind: 'sponsored',
          weight: 2,
          accentColor: 0xFF006064,
          ctaAr: 'اعرف المزيد',
          ctaEn: 'Learn more',
        ),
      );
    }
    return banners;
  }
}
