import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../academic/academic_content_service.dart';
import '../academic/faculty_categories.dart';
import '../academic/academic_models.dart';
import '../auth/language_switcher_button.dart';
import '../auth/portal_switch_button.dart';
import '../auth/welcome_screen.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/layout/responsive_layout.dart';
import '../../l10n/app_localizations.dart';
import '../admin/admin_moderation_screen.dart';
import '../auth/user_account_service.dart';
import '../academic_writing/writing_hub_screen.dart';
import '../ai_advisor/ai_advisor_screen.dart';
import '../community/community_hub_screen.dart';
import '../contributor/submit_supervisor_screen.dart';
import '../supervisor_import/admin_supervisor_import_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../matchmaking/smart_match_app_bar_button.dart';
import '../matchmaking/smart_match_promo_banner.dart';
import '../moderation/approval_status.dart';
import '../moderation/moderation_service.dart';
import '../messaging/conversations_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/academic_profile_screen.dart';
import '../research_supply_chain/research_supply_chain_screen.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../research_marketplace/research_marketplace_screen.dart';
import '../science_news/science_news_screen.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import '../smart_labs/smart_labs_screen.dart';
import '../store/product_detail_screen.dart';
import '../supervisor_metrics/supervisor_publication_panel.dart';
import '../store/product_list_screen.dart';
import '../store/store_categories.dart';
import '../store/store_categories_screen.dart';
import '../academic/supervisor_profile_screen.dart';
import '../moderation/delete_content_button.dart';
import '../acadegate_publish/publish_hub_screen.dart';
import '../research_fund/research_fund_screen.dart';
import '../matchmaking/smart_match_alert_service.dart';
import '../analysis_labs/sample_analysis_sla_alert_service.dart';
import '../research_journey/thesis_progress_home_card.dart';
import '../academic_writing/writing_expert_detail_screen.dart';
import '../academic_writing/writing_categories.dart';
import '../community/community_post_detail_screen.dart';
import '../community/community_data.dart';
import '../community/research_room_navigator.dart';
import 'home_search_catalog.dart';
import 'home_search_extras.dart';
import 'home_search_utils.dart';
import 'dashboard_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSwitchPortal;

  const HomeScreen({super.key, this.onSwitchPortal});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // كُنترولر للتحكم بنص البحث
  final TextEditingController _searchController = TextEditingController();
  final Stream<AcademicContent> _academicContentStream =
      AcademicContentService.instance.watchCore();

  // الكلمة التي يبحث عنها المستخدم حالياً
  String _searchQuery = "";
  List<AcademicLab> _searchLabs = const [];
  bool _searchLabsLoading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      UserAccountService.instance.ensureAccountExists(user);
      // Defer heavy work so first frame stays responsive.
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        SmartMatchAlertService.instance.maybeNotify();
        SampleAnalysisSlaAlertService.instance.maybeNotify();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _searchLabs = const [];
        _searchLabsLoading = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searchLabsLoading = true);
      final labs = await AcademicContentService.instance.searchLabs(
        query: q,
        limit: 25,
      );
      if (!mounted) return;
      setState(() {
        _searchLabs = labs;
        _searchLabsLoading = false;
      });
    });
  }

  // 1. قائمة الأقسام الرئيسية والتصنيفات
  List<Map<String, dynamic>> _allServices(AppLocalizations l10n) => [
    {
      "title": l10n.serviceSupervisors,
      "icon": Icons.people_alt_rounded,
      "imageUrl": HomeServiceImages.supervisors,
      "assetFallback": "assets/images/supervisors.jpg",
      "color": Colors.blue,
      "tags": [
        "كلية", "جامعة", "أساتذة", "دكتور", "مشرفين", "مشرف",
        "faculty", "university", "professors", "doctor", "supervisors", "supervisor",
      ],
      "screen": const FacultiesScreen(),
    },
    {
      "title": l10n.smartMatchmaking,
      "icon": Icons.auto_awesome,
      "color": const Color(0xFF283593),
      "imageUrl": HomeServiceImages.matchmaking,
      "assetFallback": "assets/images/supervisors.jpg",
      "tags": [
        "مطابقة", "ذكية", "مشرف", "توافق", "ملف", "اقتراح", "منهجية", "تخصص",
        "matchmaking", "smart", "supervisor", "match", "profile", "fit", "recommend",
      ],
      "screen": const MatchmakingScreen(),
    },
    {
      "title": l10n.serviceIdeas,
      "icon": Icons.lightbulb_rounded,
      "color": Colors.orange,
      "imageUrl": HomeServiceImages.ideas,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "بحث", "أفكار", "مقترح", "مشاريع", "طاقة", "مرور", "دراسة",
        "research", "ideas", "proposal", "projects", "energy", "traffic", "study",
      ],
      "screen": const ResearchMarketplaceScreen(),
    },
    {
      "title": l10n.serviceResearchPath,
      "icon": Icons.account_tree_rounded,
      "color": const Color(0xFF006064),
      "imageUrl": HomeServiceImages.researchPath,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "حزمة", "مسار", "بحث", "ذكاء", "مشرف", "مختبر", "متجر", "كتابة", "ai",
        "bundle", "path", "research", "intelligence", "supervisor", "lab", "store", "writing",
      ],
      "screen": const ResearchSupplyChainScreen(),
    },
    {
      "title": l10n.serviceLabs,
      "icon": Icons.science_rounded,
      "color": Colors.purple,
      "imageUrl": HomeServiceImages.labs,
      "assetFallback": "assets/images/labs.jpg",
      "tags": [
        "مختبر", "مختبرات", "معمل", "أجهزة", "نانو", "تحليل", "عينات", "مركز بحوث", "كيمياء", "طب",
        "lab", "labs", "equipment", "nano", "analysis", "samples", "research center", "chemistry", "medicine",
      ],
      "screen": const SmartLabsScreen(),
    },
    {
      "title": l10n.serviceStore,
      "icon": Icons.shopping_cart_rounded,
      "color": Colors.green,
      "imageUrl": HomeServiceImages.shop,
      "assetFallback": "assets/images/shop.jpg",
      "tags": [
        "متجر", "شراء", "بيع", "أدوات", "مجهر", "أنابيب", "أجهزة", "سعر",
        "store", "buy", "sell", "tools", "microscope", "tubes", "equipment", "price",
      ],
      "screen": const StoreCategoriesScreen(),
    },
    {
      "title": l10n.serviceCommunity,
      "icon": Icons.forum_rounded,
      "color": const Color(0xFF00695C),
      "imageUrl": HomeServiceImages.community,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "مجتمع", "نقاش", "سؤال", "مجموعة", "دراسة", "مناقشة", "أكاديمي", "غرفة",
        "community", "discussion", "question", "group", "study", "academic", "room",
      ],
      "screen": const CommunityHubScreen(),
    },
    {
      "title": l10n.serviceAiAdvisor,
      "icon": Icons.psychology_alt_rounded,
      "color": const Color(0xFF4527A0),
      "imageUrl": HomeServiceImages.aiAdvisor,
      "assetFallback": "assets/images/supervisors.jpg",
      "tags": [
        "مساعد", "ذكي", "ai", "عناوين", "سؤال بحثي", "تلخيص", "مشرف", "رسالة",
        "مناقشة", "لجنة", "محاكاة", "viva", "defense",
        "منهجية", "انتحال", "سلامة", "integrity", "methodology",
        "مراجع", "crossref", "citation", "references", "doi",
        "assistant", "smart", "titles", "research question", "summary", "thesis",
        "plagiarism", "method", "copyleaks", "originality", "similarity",
      ],
      "screen": const AiAdvisorScreen(),
    },
    {
      "title": l10n.serviceWriting,
      "icon": Icons.edit_note_rounded,
      "color": const Color(0xFF5D4037),
      "imageUrl": HomeServiceImages.writingServices,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "كتابة", "رسالة", "بحث", "إحصاء", "SPSS", "ماجستير", "دكتوراه", "تحرير", "مراجعة أدبيات", "حجز",
        "سلامة", "أكاديمية", "مراجع", "doi", "تشابه", "انتحال", "منهجية", "copyleaks",
        "writing", "thesis", "research", "statistics", "master", "phd", "editing", "literature review", "book",
        "integrity", "plagiarism", "citation", "similarity", "methodology", "originality",
      ],
      "screen": const WritingHubScreen(),
    },
    {
      "title": l10n.servicePublish,
      "icon": Icons.publish_rounded,
      "color": const Color(0xFF4A148C),
      "imageUrl": HomeServiceImages.publish,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "نشر", "مجلة", "IEEE", "APA", "مسودة", "manuscript", "publish", "journal", "citation",
      ],
      "screen": const PublishHubScreen(),
    },
    {
      "title": l10n.serviceFund,
      "icon": Icons.volunteer_activism_rounded,
      "color": const Color(0xFFBF360C),
      "imageUrl": HomeServiceImages.researchFund,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "تمويل", "صندوق", "fund", "university", "جامعة", "تصويت", "vote", "أفكار",
      ],
      "screen": const ResearchFundScreen(),
    },
    {
      "title": l10n.serviceNews,
      "icon": Icons.newspaper_rounded,
      "color": const Color(0xFF0D47A1),
      "imageUrl": HomeServiceImages.scienceNews,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "أخبار", "علم", "بحث", "اكتشاف", "nature", "دراسة", "منشور", "إنجاز",
        "news", "science", "research", "discovery", "study", "publication", "achievement",
      ],
      "screen": const ScienceNewsScreen(),
    },
  ];

  // 2. بيانات الكليات للبحث
  List<Map<String, dynamic>> _allFaculties(AppLocalizations l10n) =>
      facultyCategories
          .map(
            (faculty) => {
              'name': L10nLookup.facultyTitle(l10n, faculty.id),
              'category': faculty.id,
              'icon': faculty.icon,
              'color': faculty.color,
            },
          )
          .toList();

  bool _matchesFields(String query, List<String> fields) =>
      homeSearchMatches(query, fields);

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = context.l10n;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _searchQuery.trim().toLowerCase();
    final isSearching = query.isNotEmpty;
    final allServices = _allServices(l10n);
    final allFaculties = _allFaculties(l10n);
    final allSubServices = buildHomeSearchSubServices(context, l10n);

    // فلترة الأقسام الرئيسية
    final filteredServices = allServices.where((service) {
      return _matchesFields(query, [
        service["title"].toString(),
        ...(service["tags"] as List<String>),
      ]);
    }).toList();

    final filteredSubServices =
        allSubServices.where((item) => item.matches(query)).toList();

  // فلترة الكليات
    final filteredFaculties = allFaculties.where((faculty) {
      return _matchesFields(query, [
        faculty["name"].toString(),
        faculty["category"].toString(),
      ]);
    }).toList();

    // فلترة أقسام المتجر
    final filteredStoreCategories = storeCategories.where((category) {
      return _matchesFields(query, [
        category.title,
        L10nLookup.storeCategoryTitle(category.id),
        category.id,
        category.audienceAr,
        category.audienceEn,
      ]);
    }).toList();

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(l10n.userPortalHomeTitle),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const LanguageSwitcherButton(),
          if (widget.onSwitchPortal != null)
            PortalSwitchButton(
              onSwitchPortal: widget.onSwitchPortal!,
              tooltip: l10n.switchToProviderPortal,
            ),
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              final account = snapshot.data;
              if (account?.isAdmin != true) return const SizedBox.shrink();
              return IconButton(
                tooltip: l10n.contentReview,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminModerationScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const NotificationIconButton(),
          IconButton(
            tooltip: l10n.messages,
            icon: const Icon(Icons.chat_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConversationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: l10n.serviceAiAdvisor,
            icon: const Icon(Icons.psychology_alt_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AiAdvisorScreen(),
                ),
              );
            },
          ),
          const SmartMatchAppBarButton(),
          IconButton(
            tooltip: l10n.academicProfile,
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcademicProfileScreen(),
                ),
              );
            },
          ),
          if (FirebaseAuth.instance.currentUser != null)
            IconButton(
              tooltip: l10n.logout,
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context),
            ),
        ],
      ),
      body: ResponsiveLayout.constrainContent(
        context,
        Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= شريط البحث المطور =================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.start,
                decoration: InputDecoration(
                  hintText: l10n.homeSearchHint,
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF1A237E),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 16),
              const ThesisProgressHomeCard(),
            ],
            const SizedBox(height: 24),

            // عنوان يتغير حسب حالة البحث
            Text(
              _searchQuery.isEmpty
                  ? L10nLookup.availableServices
                  : L10nLookup.searchResultsFor(_searchQuery),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 16),

            // عرض المحتوى بناءً على حالة البحث
            Expanded(
              child: !isSearching
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            ResponsiveLayout.homeGridColumns(context);
                        final extent =
                            ResponsiveLayout.homeCardExtent(context);
                        return GridView.builder(
                      itemCount: allServices.length,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: extent,
                          ),
                      itemBuilder: (context, index) {
                        final item = allServices[index];
                        return DashboardCard(
                          title: item["title"],
                          imageUrl: item["imageUrl"],
                          assetFallback: item["assetFallback"],
                          icon: item["icon"],
                          color: item["color"],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => item["screen"],
                            ),
                          ),
                        );
                      },
                    );
                      },
                    )
                  : StreamBuilder<AcademicContent>(
                      stream: _academicContentStream,
                      builder: (context, academicSnapshot) {
                        final content =
                            academicSnapshot.data ?? AcademicContent.empty;

                        final filteredSupervisors = content.supervisors.where((
                          sup,
                        ) {
                          return _matchesFields(query, [
                            sup.name,
                            sup.speciality,
                            sup.university,
                            sup.category,
                            sup.faculty,
                            sup.bio,
                            ...sup.tags,
                          ]);
                        }).toList();

                        final filteredResearchIdeas = content.ideas.where((
                          idea,
                        ) {
                          return _matchesFields(query, [
                            idea.title,
                            idea.provider,
                            idea.details,
                            ...idea.tags,
                          ]);
                        }).toList();

                        final filteredLabs = _searchLabs;

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('product')
                              .snapshots(),
                          builder: (context, productSnapshot) {
                            final filteredProducts =
                                (productSnapshot.data?.docs ?? []).where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final status = data['approvalStatus']
                                      ?.toString();
                                  if (!ApprovalStatus.isPublic(status)) {
                                    return false;
                                  }
                                  return _matchesFields(query, [
                                    data['name']?.toString() ?? '',
                                    data['description']?.toString() ?? '',
                                    data['storeName']?.toString() ?? '',
                                    data['category']?.toString() ?? '',
                                    data['contact']?.toString() ?? '',
                                  ]);
                                }).toList();

                            return HomeSearchExtrasBuilder(
                              query: query,
                              builder: (context, extras) {
                            final hasResults =
                                filteredServices.isNotEmpty ||
                                filteredSubServices.isNotEmpty ||
                                filteredFaculties.isNotEmpty ||
                                filteredSupervisors.isNotEmpty ||
                                filteredResearchIdeas.isNotEmpty ||
                                filteredLabs.isNotEmpty ||
                                _searchLabsLoading ||
                                filteredStoreCategories.isNotEmpty ||
                                filteredProducts.isNotEmpty ||
                                !extras.isEmpty;

                            if (!hasResults) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.search_off_rounded,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      L10nLookup.noSearchMatches,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView(
                              children: [
                                if (filteredServices.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.sectionsAndServices),
                                  ...filteredServices.map(
                                    (item) => Card(
                                      child: ListTile(
                                        leading: Icon(
                                          item["icon"],
                                          color: item["color"],
                                        ),
                                        title: Text(
                                          item["title"],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                item["screen"],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (filteredSubServices.isNotEmpty) ...[
                                  _searchSectionTitle(
                                    L10nLookup.inSectionServices,
                                  ),
                                  ...filteredSubServices.map(
                                    (item) => Card(
                                      child: ListTile(
                                        leading: Icon(
                                          item.icon,
                                          color: item.color,
                                        ),
                                        title: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          item.subtitle != null
                                              ? '${item.parentSection} • ${item.subtitle}'
                                              : item.parentSection,
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => item.screen,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (filteredFaculties.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.faculties),
                                  ...filteredFaculties.map(
                                    (faculty) => Card(
                                      child: ListTile(
                                        leading: Icon(
                                          faculty["icon"] as IconData,
                                          color: faculty["color"] as Color,
                                        ),
                                        title: Text(
                                          faculty["name"],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(L10nLookup.supervisorsSection),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                SupervisorsListScreen(
                                                  category: faculty["category"],
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (filteredSupervisors.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.academicSupervisors),
                                  ...filteredSupervisors.map(
                                    (sup) =>
                                        SupervisorListCard(supervisor: sup),
                                  ),
                                ],
                                if (filteredResearchIdeas.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.researchIdeas),
                                  ...filteredResearchIdeas.map(
                                    (idea) => Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.lightbulb,
                                          color: Colors.orange,
                                        ),
                                        title: Text(
                                          idea.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(idea.provider),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ResearchIdeaMarketplaceDetailScreen(
                                                  idea: idea,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (_searchLabsLoading ||
                                    filteredLabs.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.labs),
                                  if (_searchLabsLoading)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ...filteredLabs.map(
                                    (lab) => Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.science,
                                          color: Colors.purple,
                                        ),
                                        title: Text(
                                          lab.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(lab.location),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                SmartLabDetailScreen(lab: lab),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (filteredStoreCategories.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.storeCategories),
                                  ...filteredStoreCategories.map(
                                    (category) => Card(
                                      child: ListTile(
                                        leading: Icon(
                                          category.icon,
                                          color: category.color,
                                        ),
                                        title: Text(
                                          L10nLookup.storeCategoryTitle(
                                            category.id,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ProductListScreen(
                                                  categoryTitle: category.title,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (filteredProducts.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.storeProducts),
                                  ...filteredProducts.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name =
                                        data['name']?.toString() ??
                                            L10nLookup.product;
                                    final price = L10nLookup.currencyEgp(
                                      (data['price'] as num?) ?? 0,
                                    );
                                    final category =
                                        data['category']?.toString() ?? '';

                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: Colors.green,
                                        ),
                                        title: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text('$price • $category'),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ProductDetailScreen(
                                                  name: name,
                                                  price: price,
                                                  description:
                                                      data['description']
                                                          ?.toString() ??
                                                      L10nLookup.noDescription,
                                                  storeName:
                                                      data['storeName']
                                                          ?.toString() ??
                                                      L10nLookup.unknownStore,
                                                  contact:
                                                      data['contact']
                                                          ?.toString() ??
                                                      '',
                                                  productId: doc.id,
                                                  createdBy: data['createdBy']
                                                      ?.toString(),
                                                  priceValue:
                                                      (data['price'] as num?) ??
                                                      0,
                                                  imageUrl: data['imageUrl']
                                                      ?.toString(),
                                                  brand: data['brand']
                                                          ?.toString() ??
                                                      '',
                                                  unit: data['unit']
                                                          ?.toString() ??
                                                      '',
                                                  grade: data['grade']
                                                          ?.toString() ??
                                                      '',
                                                  sellerType: data['sellerType']
                                                          ?.toString() ??
                                                      '',
                                                  certifications: (data[
                                                              'certifications']
                                                          is List)
                                                      ? (data['certifications']
                                                              as List)
                                                          .map(
                                                            (e) =>
                                                                e.toString(),
                                                          )
                                                          .toList()
                                                      : const [],
                                                  isVerifiedSeller: data[
                                                          'isVerifiedSeller'] ==
                                                      true,
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                if (extras.writingExperts.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.writingExperts),
                                  ...extras.writingExperts.map((expert) {
                                    final category =
                                        writingCategoryByTitle(expert.category) ??
                                            writingCategories.first;
                                    return Card(
                                      child: ListTile(
                                        leading: Icon(
                                          category.icon,
                                          color: category.color,
                                        ),
                                        title: Text(
                                          expert.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${expert.category} • ${expert.speciality}',
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                WritingExpertDetailScreen(
                                              expert: expert,
                                              category: category,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                if (extras.communityPosts.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.communityPosts),
                                  ...extras.communityPosts.map((post) {
                                    final room = communityRoomById(post.roomId) ??
                                        communityRooms.last;
                                    return Card(
                                      child: ListTile(
                                        leading: Icon(
                                          CommunityPostType.icon(post.type),
                                          color: room.color,
                                        ),
                                        title: Text(
                                          post.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${post.authorName} • ${room.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CommunityPostDetailScreen(
                                              post: post,
                                              room: room,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                if (extras.researchRooms.isNotEmpty) ...[
                                  _searchSectionTitle(L10nLookup.researchRooms),
                                  ...extras.researchRooms.map((room) {
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.groups_outlined,
                                          color: Color(0xFF00695C),
                                        ),
                                        title: Text(
                                          room.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          room.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                        ),
                                        onTap: () =>
                                            openResearchRoom(context, room),
                                      ),
                                    );
                                  }),
                                ],
                                if (extras.scienceNews.isNotEmpty) ...[
                                  _searchSectionTitle(
                                    L10nLookup.scienceNewsArticles,
                                  ),
                                  ...extras.scienceNews.map((item) {
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.newspaper_outlined,
                                          color: Color(0xFF0D47A1),
                                        ),
                                        title: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${item.source} • ${item.category}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: const Icon(
                                          Icons.open_in_new,
                                          size: 16,
                                        ),
                                        onTap: () async {
                                          final uri = Uri.tryParse(item.url);
                                          if (uri == null) return;
                                          await launchUrl(
                                            uri,
                                            mode: LaunchMode.externalApplication,
                                          );
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _searchSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}

// =======================================================
// قسم المشرفين
// =======================================================
class FacultiesScreen extends StatelessWidget {
  const FacultiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(L10nLookup.chooseFaculty),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, accountSnapshot) {
              final isAdmin = accountSnapshot.data?.isAdmin == true;
              if (!isAdmin) {
                return IconButton(
                  tooltip: L10nLookup.importSupervisors,
                  icon: const Icon(Icons.cloud_download_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AdminSupervisorImportScreen(),
                      ),
                    );
                  },
                );
              }

              return StreamBuilder<List<PendingItem>>(
                stream: ModerationService.instance.watchPendingItems(),
                builder: (context, pendingSnapshot) {
                  final pending = pendingSnapshot.data ?? [];
                  final pendingSupervisors = pending
                      .where((item) => item.collection == 'supervisors')
                      .length;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: L10nLookup.reviewSupervisorsApproveReject,
                        icon: Badge(
                          isLabelVisible: pendingSupervisors > 0,
                          label: Text('$pendingSupervisors'),
                          child: const Icon(Icons.fact_check_outlined),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminModerationScreen(
                                initialFilter: 'supervisors',
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: L10nLookup.importSupervisors,
                        icon: const Icon(Icons.cloud_download_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminSupervisorImportScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            tooltip: L10nLookup.registerAsSupervisor,
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubmitSupervisorScreen(),
                ),
              );
              if (created == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(L10nLookup.supervisorSubmittedForReview),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, accountSnapshot) {
          final isAdmin = accountSnapshot.data?.isAdmin == true;

          return StreamBuilder<List<AcademicSupervisor>>(
            stream: AcademicContentService.instance.supervisorsStream(
              includePending: isAdmin,
            ),
            builder: (context, snapshot) {
              final supervisors = snapshot.data ?? [];

              return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SmartMatchPromoBanner(),
              StreamBuilder(
                stream: UserAccountService.instance.watchCurrentAccount(),
                builder: (context, accountSnapshot) {
                  final isAdmin = accountSnapshot.data?.isAdmin == true;
                  if (!isAdmin) return const SizedBox.shrink();

                  return StreamBuilder<List<PendingItem>>(
                    stream: ModerationService.instance.watchPendingItems(),
                    builder: (context, pendingSnapshot) {
                      final pendingSupervisors = (pendingSnapshot.data ?? [])
                          .where((item) => item.collection == 'supervisors')
                          .length;
                      if (pendingSupervisors == 0) {
                        return const SizedBox.shrink();
                      }

                      return Card(
                        color: Colors.orange.withValues(alpha: 0.12),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: const Icon(
                            Icons.pending_actions,
                            color: Colors.orange,
                          ),
                          title: Text(
                            L10nLookup.supervisorsPendingApproval(
                              pendingSupervisors,
                            ),
                          ),
                          subtitle: Text(L10nLookup.tapToApproveOrReject),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AdminModerationScreen(
                                      initialFilter: 'supervisors',
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
              ...facultyCategories.map((faculty) {
                final inFaculty = supervisors
                    .where((supervisor) => supervisor.category == faculty.id)
                    .toList();
                final previewNames = inFaculty
                    .take(3)
                    .map((supervisor) => supervisor.name)
                    .toList();

                return FacultyCard(
                  name: L10nLookup.facultyTitleStatic(faculty.id),
                  icon: faculty.icon,
                  color: faculty.color,
                  supervisorCount: inFaculty.length,
                  previewNames: previewNames,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorsListScreen(
                        category: faculty.id,
                        facultyTitle: L10nLookup.facultyTitleStatic(faculty.id),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
            },
          );
        },
      ),

      // ======= تم تعديل الزر هنا وحذف كلمة const ليعمل بنجاح دون أخطاء =======
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MatchmakingScreen()),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: Text(l10n.smartMatchmaking),
      ),
    );
  }
}

class FacultyCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final int supervisorCount;
  final List<String> previewNames;
  final VoidCallback onTap;

  const FacultyCard({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    this.supervisorCount = 0,
    this.previewNames = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String subtitle;
    if (supervisorCount == 0) {
      subtitle = L10nLookup.noSupervisorsYet;
    } else if (previewNames.isEmpty) {
      subtitle = L10nLookup.supervisorCount(supervisorCount);
    } else {
      final names = previewNames.join(L10nLookup.listSeparator());
      final extra = supervisorCount > previewNames.length
          ? ' +${supervisorCount - previewNames.length}'
          : '';
      subtitle = L10nLookup.supervisorPreviewSubtitle(
        supervisorCount,
        names,
        extra,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class SupervisorsListScreen extends StatelessWidget {
  final String category;
  final String? facultyTitle;

  const SupervisorsListScreen({
    super.key,
    required this.category,
    this.facultyTitle,
  });

  String get _title => facultyTitle ?? supervisorsTitleForCategory(category);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (snapshot.data?.isAdmin != true) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: L10nLookup.reviewPending,
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminModerationScreen(
                        initialFilter: 'supervisors',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SubmitSupervisorScreen(initialCategory: category),
            ),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(L10nLookup.supervisorSubmittedForReview),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(L10nLookup.registerAsSupervisor),
      ),
      body: StreamBuilder(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, accountSnapshot) {
          final isAdmin = accountSnapshot.data?.isAdmin == true;

          return StreamBuilder<List<AcademicSupervisor>>(
            stream: AcademicContentService.instance.supervisorsStream(
              category: category,
              includePending: isAdmin,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('${L10nLookup.error}: ${snapshot.error}'),
                );
              }

              final supervisors = snapshot.data ?? [];

              if (supervisors.isEmpty) {
                return Center(child: Text(L10nLookup.noSupervisorsInCategory));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: supervisors.length,
                itemBuilder: (context, index) {
                  final supervisor = supervisors[index];
                  return SupervisorListCard(supervisor: supervisor);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class SupervisorListCard extends StatelessWidget {
  final AcademicSupervisor supervisor;

  const SupervisorListCard({super.key, required this.supervisor});

  @override
  Widget build(BuildContext context) {
    final facultyLine = supervisor.faculty.isNotEmpty
        ? supervisor.faculty
        : supervisor.speciality;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SupervisorProfileScreen(supervisor: supervisor),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      backgroundImage: supervisor.photoUrl.isNotEmpty
                          ? NetworkImage(supervisor.photoUrl)
                          : null,
                      child: supervisor.photoUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supervisor.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (supervisor.approvalStatus ==
                              ApprovalStatus.pending)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 2),
                              child: Text(
                                context.t(
                                  'قيد المراجعة — غير ظاهر للطلاب',
                                  'Pending review — hidden from students',
                                ),
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Text(
                            facultyLine,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            supervisor.speciality.isNotEmpty &&
                                    supervisor.faculty.isNotEmpty
                                ? '${supervisor.speciality}\n${supervisor.university}'
                                : supervisor.university,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          SupervisorMetricsChipRow(supervisor: supervisor),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.circle,
                      color: supervisor.isAvailable ? Colors.green : Colors.red,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ),
            DeleteContentButton(
              collection: 'supervisors',
              documentId: supervisor.id,
              ownerId: supervisor.ownerId,
              itemLabel: supervisor.name,
              isDemo: supervisor.isDemo,
              asAppBarAction: false,
              onDeleted: () {},
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
