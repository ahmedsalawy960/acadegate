import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/acadegate_logo.dart';
import '../home/dashboard_card.dart';

class WelcomeFeatureSlide {
  const WelcomeFeatureSlide({
    required this.imageUrl,
    required this.icon,
    required this.accent,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.highlightsAr,
    required this.highlightsEn,
  });

  final String imageUrl;
  final IconData icon;
  final Color accent;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final List<String> highlightsAr;
  final List<String> highlightsEn;

  String title(BuildContext context) =>
      context.t(titleAr, titleEn);

  String subtitle(BuildContext context) =>
      context.t(subtitleAr, subtitleEn);

  List<String> highlights(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return isAr ? highlightsAr : highlightsEn;
  }
}

List<WelcomeFeatureSlide> welcomeFeatureSlides() => [
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.aiAdvisor,
        icon: Icons.account_balance_rounded,
        accent: const Color(0xFF1A237E),
        titleAr: 'AcadeGate — بوابتك للتميز الأكاديمي',
        titleEn: 'AcadeGate — your gateway to academic excellence',
        subtitleAr:
            'منصة متكاملة للدراسات العليا: من اختيار المشرف حتى النشر العلمي — في مكان واحد.',
        subtitleEn:
            'An all-in-one postgraduate platform: from supervisor matching to scholarly publishing.',
        highlightsAr: [
          'مشرفون، مختبرات، متجر بحثي، ومجتمع أكاديمي',
          'وكلاء ذكاء اصطناعي متخصصون لكل مرحلة',
          'متابعة ذكية لمسار الرسالة والتنبيهات',
        ],
        highlightsEn: [
          'Supervisors, labs, research store & academic community',
          'Specialized AI agents for every thesis stage',
          'Smart thesis journey tracking & in-app alerts',
        ],
      ),
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.aiAdvisor,
        icon: Icons.psychology_alt_rounded,
        accent: const Color(0xFF4527A0),
        titleAr: 'مساعد بحث ذكي — وكلاء متخصصون',
        titleEn: 'Smart research assistant — specialized agents',
        subtitleAr:
            'اسأل بلغتك الطبيعية: أفكار بحثية، كتابة فصول، مراجعة أدبية، منهجية، استشهاد، ومحاكاة مناقشة.',
        subtitleEn:
            'Ask in plain language: ideas, chapter drafting, literature review, methodology, citations & viva simulation.',
        highlightsAr: [
          'توجيه تلقائي للوكيل المناسب حسب سؤالك',
          'دعم العربية والإنجليزية الأكاديمية',
          'مرفقات صور وملفات للتحليل',
        ],
        highlightsEn: [
          'Auto-routing to the right agent for your question',
          'Arabic & English academic support',
          'Attach images and files for analysis',
        ],
      ),
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.matchmaking,
        icon: Icons.auto_awesome,
        accent: const Color(0xFF283593),
        titleAr: 'مشرفون ومطابقة ذكية',
        titleEn: 'Supervisors & smart matchmaking',
        subtitleAr:
            'تصفّح كليات وجامعات، اطلع على ملفات المشرفين، واطلب مطابقة ذكية حسب تخصصك ومنهجيتك.',
        subtitleEn:
            'Browse faculties and universities, explore supervisor profiles, and request smart matching by field & methodology.',
        highlightsAr: [
          'دليل أكاديمي شامل للمشرفين',
          'مطابقة ذكية مع تنبيهات داخل التطبيق',
          'تواصل مباشر وطلب إشراف',
        ],
        highlightsEn: [
          'Comprehensive academic supervisor directory',
          'Smart matching with in-app notifications',
          'Direct contact & supervision requests',
        ],
      ),
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.ideas,
        icon: Icons.lightbulb_rounded,
        accent: Colors.orange,
        titleAr: 'أفكار بحثية ومسار ذكي',
        titleEn: 'Research ideas & intelligent path',
        subtitleAr:
            'سوق أفكار بحثية، مسار بحث متكامل، وصندوق تمويل جامعي — من الفكرة إلى التنفيذ.',
        subtitleEn:
            'Research idea marketplace, integrated research path, and university research fund — from idea to execution.',
        highlightsAr: [
          'عرض وشراء أفكار بحثية جاهزة',
          'حزمة مسار بحث (مشرف + مختبر + متجر)',
          'تصويت وتمويل أفكار واعدة',
        ],
        highlightsEn: [
          'Browse and acquire ready research ideas',
          'Research path bundle (supervisor + lab + store)',
          'Vote and fund promising ideas',
        ],
      ),
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.labs,
        icon: Icons.science_rounded,
        accent: Colors.purple,
        titleAr: 'مختبرات ذكية وتحليل بيانات',
        titleEn: 'Smart labs & data analysis',
        subtitleAr:
            'احجز مختبرات، اطلب تحليل عينات، واستخدم معالج الافتراضات الإحصائية مع بيانات CSV حقيقية.',
        subtitleEn:
            'Book labs, request sample analysis, and use the statistical assumptions wizard with real CSV data.',
        highlightsAr: [
          'مختبرات وأجهزة بحثية مع حجز مباشر',
          'تتبع SLA لطلبات التحليل',
          'Shapiro-Wilk، Levene، t-test و ANOVA من ملفك',
        ],
        highlightsEn: [
          'Research labs & equipment with direct booking',
          'SLA tracking for analysis requests',
          'Shapiro-Wilk, Levene, t-test & ANOVA from your file',
        ],
      ),
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.writingServices,
        icon: Icons.edit_note_rounded,
        accent: const Color(0xFF5D4037),
        titleAr: 'كتابة ونشر علمي',
        titleEn: 'Academic writing & publishing',
        subtitleAr:
            'مركز كتابة الرسائل، طلب كتب أكاديمية، ومحرر نشر مع قوالب IEEE و APA وتصدير PDF.',
        subtitleEn:
            'Thesis writing hub, academic book orders, and publish editor with IEEE/APA templates & PDF export.',
        highlightsAr: [
          'خدمات كتابة ومراجعة أدبيات',
          'محرر مسودات علمية منظّم',
          'تصدير ونشر بمعايير المجلات',
        ],
        highlightsEn: [
          'Writing services & literature review support',
          'Structured scholarly manuscript editor',
          'Export & publish to journal standards',
        ],
      ),
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.integrity,
        icon: Icons.verified_user_rounded,
        accent: const Color(0xFF1B5E20),
        titleAr: 'سلامة أكاديمية واستشهاد',
        titleEn: 'Academic integrity & citations',
        subtitleAr:
            'فحص الاستشهاد عبر Crossref، فحص الأصالة، وإرشاد منهجي — لرسالة أكثر موثوقية.',
        subtitleEn:
            'Crossref citation checks, originality screening, and methodology guidance — for a more credible thesis.',
        highlightsAr: [
          'التحقق من DOI والمراجع',
          'فحص تشابه ونصائح سلامة أكاديمية',
          'ربط مع وكلاء المنهجية والمراجع',
        ],
        highlightsEn: [
          'DOI & reference verification',
          'Similarity checks & integrity guidance',
          'Linked methodology & citation agents',
        ],
      ),
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.community,
        icon: Icons.forum_rounded,
        accent: const Color(0xFF00695C),
        titleAr: 'مجتمع أكاديمي ومتجر بحثي',
        titleEn: 'Academic community & research store',
        subtitleAr:
            'غرف نقاش، أسئلة وأجوبة، ومتجر لأدوات البحث — مجهر، أنابيب، أجهزة، وكل ما يحتاجه الباحث.',
        subtitleEn:
            'Discussion rooms, Q&A, and a store for research tools — microscopes, lab supplies, equipment & more.',
        highlightsAr: [
          'مجتمع تفاعلي للباحثين',
          'شراء وبيع أدوات ومستلزمات بحثية',
          'رسائل وإشعارات داخل التطبيق',
        ],
        highlightsEn: [
          'Interactive researcher community',
          'Buy & sell research tools and supplies',
          'In-app messaging & notifications',
        ],
      ),
      WelcomeFeatureSlide(
        imageUrl: HomeServiceImages.scienceNews,
        icon: Icons.timeline_rounded,
        accent: const Color(0xFF0D47A1),
        titleAr: 'أخبار علمية ومتابعة الرسالة',
        titleEn: 'Science news & thesis progress',
        subtitleAr:
            'آخر أخبار العلوم، بطاقة تقدم الرسالة الذكية، وتنبيهات للمهام والمواعيد — دون إزعاج خارج التطبيق.',
        subtitleEn:
            'Latest science news, smart thesis progress card, and task deadline alerts — without external push noise.',
        highlightsAr: [
          'أخبار واكتشافات علمية محدّثة',
          'تتبع تلقائي لتقدم الرسالة',
          'نصائح الخطوة التالية في رحلتك',
        ],
        highlightsEn: [
          'Updated science news & discoveries',
          'Automatic thesis progress tracking',
          'Next-step advice for your journey',
        ],
      ),
    ];

/// Auto-rotating hero with Ken Burns background and per-slide copy.
class WelcomeFeatureCarousel extends StatefulWidget {
  const WelcomeFeatureCarousel({super.key});

  @override
  State<WelcomeFeatureCarousel> createState() => _WelcomeFeatureCarouselState();
}

class _WelcomeFeatureCarouselState extends State<WelcomeFeatureCarousel>
    with TickerProviderStateMixin {
  static const _brand = Color(0xFF1A237E);

  final _pageController = PageController();
  late final AnimationController _kenBurnsController;
  late final Animation<double> _kenBurnsScale;
  Timer? _autoTimer;
  int _index = 0;

  List<WelcomeFeatureSlide> get _slides => welcomeFeatureSlides();

  @override
  void initState() {
    super.initState();
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _kenBurnsScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.easeInOut),
    );
    _kenBurnsController.forward();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _kenBurnsController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _kenBurnsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: SizedBox(
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _slides.length,
              itemBuilder: (context, i) {
                return AnimatedBuilder(
                  animation: _kenBurnsScale,
                  builder: (context, child) {
                    final scale = i == _index ? _kenBurnsScale.value : 1.05;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: _SlideBackground(slide: _slides[i]),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.55),
                    _brand.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AcadeGateLogo(
                        size: 44,
                        showShadow: false,
                        variant: AcadeGateLogoVariant.compact,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'AcadeGate',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _SlideCopy(
                      key: ValueKey(_index),
                      slide: slide,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.amber
                              : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideBackground extends StatelessWidget {
  const _SlideBackground({required this.slide});

  final WelcomeFeatureSlide slide;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      slide.imageUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [slide.accent, slide.accent.withValues(alpha: 0.6)],
          ),
        ),
        child: Icon(slide.icon, size: 80, color: Colors.white24),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: slide.accent.withValues(alpha: 0.3),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        );
      },
    );
  }
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({super.key, required this.slide});

  final WelcomeFeatureSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slide.title(context),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide.subtitle(context),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        ...slide.highlights(context).map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.amber.shade200,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
