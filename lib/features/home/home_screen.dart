import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../academic/academic_content_service.dart';
import '../academic/faculty_categories.dart';
import '../academic/academic_fallback_data.dart';
import '../academic/academic_models.dart';
import '../auth/welcome_screen.dart';
import '../admin/admin_moderation_screen.dart';
import '../auth/user_account_service.dart';
import '../academic_writing/writing_hub_screen.dart';
import '../ai_advisor/ai_advisor_screen.dart';
import '../community/community_hub_screen.dart';
import '../contributor/contributor_hub_screen.dart';
import '../contributor/submit_supervisor_screen.dart';
import '../supervisor_import/admin_supervisor_import_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../moderation/approval_status.dart';
import '../moderation/delete_content_button.dart';
import '../moderation/moderation_service.dart';
import '../messaging/conversations_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/academic_profile_screen.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../research_marketplace/research_marketplace_screen.dart';
import '../science_news/science_news_screen.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import '../smart_labs/smart_labs_screen.dart';
import '../store/product_detail_screen.dart';
import '../store/product_list_screen.dart';
import '../store/store_categories.dart';
import '../store/store_categories_screen.dart';
import 'dashboard_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // كُنترولر للتحكم بنص البحث
  final TextEditingController _searchController = TextEditingController();
  final Stream<AcademicContent> _academicContentStream = AcademicContentService
      .instance
      .watchAll();

  // الكلمة التي يبحث عنها المستخدم حالياً
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      UserAccountService.instance.ensureAccountExists(user);
    }
  }

  // 1. قائمة الأقسام الرئيسية والتصنيفات
  final List<Map<String, dynamic>> _allServices = [
    {
      "title": "المشرفون",
      "icon": Icons.people_alt_rounded,
      "imageUrl": HomeServiceImages.supervisors,
      "assetFallback": "assets/images/supervisors.jpg",
      "color": Colors.blue,
      "tags": ["كلية", "جامعة", "أساتذة", "دكتور", "مشرفين", "مشرف"],
      "screen": const FacultiesScreen(),
    },
    {
      "title": "أفكار بحثية",
      "icon": Icons.lightbulb_rounded,
      "color": Colors.orange,
      "imageUrl": HomeServiceImages.ideas,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": ["بحث", "أفكار", "مقترح", "مشاريع", "طاقة", "مرور", "دراسة"],
      "screen": const ResearchMarketplaceScreen(),
    },
    {
      "title": "مختبرات ذكية",
      "icon": Icons.science_rounded,
      "color": Colors.purple,
      "imageUrl": HomeServiceImages.labs,
      "assetFallback": "assets/images/labs.jpg",
      "tags": ["مختبر", "مختبرات", "معمل", "أجهزة", "نانو", "تحليل", "كيمياء"],
      "screen": const SmartLabsScreen(),
    },
    {
      "title": "المتجر",
      "icon": Icons.shopping_cart_rounded,
      "color": Colors.green,
      "imageUrl": HomeServiceImages.shop,
      "assetFallback": "assets/images/shop.jpg",
      "tags": [
        "متجر",
        "شراء",
        "بيع",
        "أدوات",
        "مجهر",
        "أنابيب",
        "أجهزة",
        "سعر",
      ],
      "screen": const StoreCategoriesScreen(),
    },
    {
      "title": "المجتمع الأكاديمي",
      "icon": Icons.forum_rounded,
      "color": const Color(0xFF00695C),
      "imageUrl": HomeServiceImages.community,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "مجتمع",
        "نقاش",
        "سؤال",
        "مجموعة",
        "دراسة",
        "مناقشة",
        "أكاديمي",
        "غرفة",
      ],
      "screen": const CommunityHubScreen(),
    },
    {
      "title": "المساعد الأكاديمي",
      "icon": Icons.psychology_alt_rounded,
      "color": const Color(0xFF4527A0),
      "imageUrl": HomeServiceImages.aiAdvisor,
      "assetFallback": "assets/images/supervisors.jpg",
      "tags": [
        "مساعد",
        "ذكي",
        "ai",
        "عناوين",
        "سؤال بحثي",
        "تلخيص",
        "مشرف",
        "رسالة",
      ],
      "screen": const AiAdvisorScreen(),
    },
    {
      "title": "خدمات الكتابة",
      "icon": Icons.edit_note_rounded,
      "color": const Color(0xFF5D4037),
      "imageUrl": HomeServiceImages.writingServices,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "كتابة",
        "رسالة",
        "بحث",
        "إحصاء",
        "SPSS",
        "ماجستير",
        "دكتوراه",
        "تحرير",
        "مراجعة أدبيات",
        "حجز",
      ],
      "screen": const WritingHubScreen(),
    },
    {
      "title": "أخبار علمية",
      "icon": Icons.newspaper_rounded,
      "color": const Color(0xFF0D47A1),
      "imageUrl": HomeServiceImages.scienceNews,
      "assetFallback": "assets/images/ideas.jpg",
      "tags": [
        "أخبار",
        "علم",
        "بحث",
        "اكتشاف",
        "nature",
        "دراسة",
        "منشور",
        "إنجاز",
      ],
      "screen": const ScienceNewsScreen(),
    },
  ];

  // 2. بيانات الكليات للبحث
  List<Map<String, dynamic>> get _allFaculties => facultyCategories
      .map(
        (faculty) => {
          'name': faculty.titleAr,
          'category': faculty.id,
          'icon': faculty.icon,
          'color': faculty.color,
        },
      )
      .toList();

  bool _matchesFields(String query, List<String> fields) {
    if (query.isEmpty) return false;
    final haystack = fields.join(' ').toLowerCase();
    return haystack.contains(query);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
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
    final query = _searchQuery.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    // فلترة الأقسام الرئيسية
    final filteredServices = _allServices.where((service) {
      return _matchesFields(query, [
        service["title"].toString(),
        ...(service["tags"] as List<String>),
      ]);
    }).toList();

    // فلترة الكليات
    final filteredFaculties = _allFaculties.where((faculty) {
      return _matchesFields(query, [
        faculty["name"].toString(),
        faculty["category"].toString(),
      ]);
    }).toList();

    // فلترة أقسام المتجر
    final filteredStoreCategories = storeCategories.where((category) {
      return _matchesFields(query, [category.title, category.id]);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("الرئيسية"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              final account = snapshot.data;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (account?.isAdmin == true)
                    IconButton(
                      tooltip: 'مراجعة المحتوى',
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminModerationScreen(),
                          ),
                        );
                      },
                    ),
                  IconButton(
                    tooltip: 'لوحة المساهمة',
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContributorHubScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const NotificationIconButton(),
          IconButton(
            tooltip: 'الرسائل',
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
            tooltip: 'المساعد الأكاديمي',
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
          IconButton(
            tooltip: 'المطابقة الذكية',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MatchmakingScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'ملفي الأكاديمي',
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
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context),
            ),
        ],
      ),
      body: Padding(
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
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText:
                      'ابحث في كل الأقسام: مشرفين، أفكار، مختبرات، متجر...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF1A237E),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = "";
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // عنوان يتغير حسب حالة البحث
            Text(
              _searchQuery.isEmpty
                  ? "الخدمات المتاحة"
                  : "نتائج البحث عن: ($_searchQuery)",
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
                  ? GridView.builder(
                      itemCount: _allServices.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 168,
                          ),
                      itemBuilder: (context, index) {
                        final item = _allServices[index];
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
                    )
                  : StreamBuilder<AcademicContent>(
                      stream: _academicContentStream,
                      builder: (context, academicSnapshot) {
                        final content =
                            academicSnapshot.data ?? fallbackContent;

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

                        final filteredLabs = content.labs.where((lab) {
                          return _matchesFields(query, [
                            lab.name,
                            lab.location,
                            lab.equipment,
                            ...lab.tags,
                          ]);
                        }).toList();

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('product')
                              .snapshots(),
                          builder: (context, productSnapshot) {
                            final filteredProducts =
                                (productSnapshot.data?.docs ?? []).where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final status =
                                      data['approvalStatus']?.toString();
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

                            final hasResults =
                                filteredServices.isNotEmpty ||
                                filteredFaculties.isNotEmpty ||
                                filteredSupervisors.isNotEmpty ||
                                filteredResearchIdeas.isNotEmpty ||
                                filteredLabs.isNotEmpty ||
                                filteredStoreCategories.isNotEmpty ||
                                filteredProducts.isNotEmpty;

                            if (!hasResults) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'عذراً، لم نجد نتائج تطابق بحثك!',
                                      style: TextStyle(
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
                                  _searchSectionTitle('الأقسام والخدمات'),
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
                                if (filteredFaculties.isNotEmpty) ...[
                                  _searchSectionTitle('الكليات'),
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
                                        subtitle: const Text('قسم المشرفون'),
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
                                  _searchSectionTitle('المشرفون الأكاديميون'),
                                  ...filteredSupervisors.map(
                                    (sup) => SupervisorListCard(
                                      name: sup.name,
                                      speciality: sup.speciality,
                                      faculty: sup.faculty,
                                      university: sup.university,
                                      bio: sup.bio,
                                      isAvailable: sup.isAvailable,
                                      supervisorId: sup.id,
                                      ownerId: sup.ownerId,
                                    ),
                                  ),
                                ],
                                if (filteredResearchIdeas.isNotEmpty) ...[
                                  _searchSectionTitle('أفكار بحثية'),
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
                                if (filteredLabs.isNotEmpty) ...[
                                  _searchSectionTitle('المختبرات'),
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
                                  _searchSectionTitle('أقسام المتجر'),
                                  ...filteredStoreCategories.map(
                                    (category) => Card(
                                      child: ListTile(
                                        leading: Icon(
                                          category.icon,
                                          color: category.color,
                                        ),
                                        title: Text(
                                          category.title,
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
                                  _searchSectionTitle('منتجات المتجر'),
                                  ...filteredProducts.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name =
                                        data['name']?.toString() ?? 'منتج';
                                    final price = '${data['price'] ?? 0} ج.م';
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
                                                      'لا يوجد وصف متاح.',
                                                  storeName:
                                                      data['storeName']
                                                          ?.toString() ??
                                                      'متجر غير معروف',
                                                  contact:
                                                      data['contact']
                                                          ?.toString() ??
                                                      '',
                                                  productId: doc.id,
                                                  createdBy:
                                                      data['createdBy']
                                                          ?.toString(),
                                                  priceValue:
                                                      (data['price'] as num?) ??
                                                      0,
                                                  imageUrl:
                                                      data['imageUrl']
                                                          ?.toString(),
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("اختر الكلية"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, accountSnapshot) {
              final isAdmin = accountSnapshot.data?.isAdmin == true;
              if (!isAdmin) {
                return IconButton(
                  tooltip: 'استيراد مشرفين',
                  icon: const Icon(Icons.cloud_download_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminSupervisorImportScreen(),
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
                        tooltip: 'مراجعة المشرفين — موافقة / رفض',
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
                        tooltip: 'استيراد مشرفين',
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
            tooltip: 'سجّل كمشرف',
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
                  const SnackBar(
                    content: Text('تم إرسال ملف المشرف للمراجعة'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AcademicSupervisor>>(
        stream: AcademicContentService.instance.supervisorsStream(),
        builder: (context, snapshot) {
          final supervisors = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                      if (pendingSupervisors == 0) return const SizedBox.shrink();

                      return Card(
                        color: Colors.orange.withValues(alpha: 0.12),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: const Icon(Icons.pending_actions, color: Colors.orange),
                          title: Text('$pendingSupervisors مشرف بانتظار الموافقة'),
                          subtitle: const Text('اضغط للموافقة أو الرفض'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
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
                      );
                    },
                  );
                },
              ),
              ...facultyCategories.map((faculty) {
                final inFaculty = supervisors
                    .where((supervisor) => supervisor.category == faculty.id)
                    .toList();
                final previewNames =
                    inFaculty.take(3).map((supervisor) => supervisor.name).toList();

                return FacultyCard(
                  name: faculty.titleAr,
                  icon: faculty.icon,
                  color: faculty.color,
                  supervisorCount: inFaculty.length,
                  previewNames: previewNames,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorsListScreen(
                        category: faculty.id,
                        facultyTitle: faculty.titleAr,
                      ),
                    ),
                  ),
                );
              }),
            ],
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
        label: const Text("المطابقة الذكية"),
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
      subtitle = 'لا يوجد مشرفون بعد';
    } else if (previewNames.isEmpty) {
      subtitle = '$supervisorCount مشرف';
    } else {
      final names = previewNames.join('، ');
      final extra = supervisorCount > previewNames.length
          ? ' +${supervisorCount - previewNames.length}'
          : '';
      subtitle = '$supervisorCount مشرف • $names$extra';
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

  String get _title =>
      facultyTitle ?? supervisorsTitleForCategory(category);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (snapshot.data?.isAdmin != true) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'مراجعة المعلقين',
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
              const SnackBar(
                content: Text('تم إرسال ملف المشرف للمراجعة'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('سجّل كمشرف'),
      ),
      body: StreamBuilder<List<AcademicSupervisor>>(
        stream: AcademicContentService.instance.supervisorsStream(
          category: category,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final supervisors = snapshot.data ?? [];

          if (supervisors.isEmpty) {
            return const Center(child: Text('لا يوجد مشرفون في هذا القسم'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: supervisors.length,
            itemBuilder: (context, index) {
              final supervisor = supervisors[index];
              return SupervisorListCard(
                name: supervisor.name,
                speciality: supervisor.speciality,
                faculty: supervisor.faculty,
                university: supervisor.university,
                bio: supervisor.bio,
                isAvailable: supervisor.isAvailable,
                supervisorId: supervisor.id,
                ownerId: supervisor.ownerId,
              );
            },
          );
        },
      ),
    );
  }
}

class SupervisorListCard extends StatelessWidget {
  final String name;
  final String speciality;
  final String faculty;
  final String university;
  final String bio;
  final bool isAvailable;
  final String? supervisorId;
  final String? ownerId;

  const SupervisorListCard({
    super.key,
    required this.name,
    required this.speciality,
    this.faculty = '',
    required this.university,
    this.bio = '',
    required this.isAvailable,
    this.supervisorId,
    this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final facultyLine = faculty.isNotEmpty ? faculty : speciality;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SupervisorProfileScreen(
                name: name,
                speciality: speciality,
                university: university,
                bio: bio.isEmpty ? 'أستاذ متخصص في $speciality.' : bio,
                supervisorId: supervisorId,
                ownerId: ownerId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                      speciality.isNotEmpty && faculty.isNotEmpty
                          ? '$speciality\n$university'
                          : university,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.circle,
                color: isAvailable ? Colors.green : Colors.red,
                size: 12,
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class SupervisorProfileScreen extends StatelessWidget {
  final String name;
  final String speciality;
  final String university;
  final String bio;
  final String? supervisorId;
  final String? ownerId;

  const SupervisorProfileScreen({
    super.key,
    required this.name,
    required this.speciality,
    required this.university,
    required this.bio,
    this.supervisorId,
    this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الملف الشخصي"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: deleteAppBarActions(
          collection: 'supervisors',
          documentId: supervisorId,
          ownerId: ownerId,
          itemLabel: name,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF1A237E),
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 60, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    university,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "التخصص: $speciality",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Divider(height: 30),
                  const Text(
                    "نبذة عن المشرف:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: ownerId == null || ownerId!.isEmpty
                              ? null
                              : () async {
                                  await openChatWithUser(
                                    context,
                                    otherUserId: ownerId!,
                                    otherUserName: name,
                                    contextType: 'supervisor',
                                    contextId: supervisorId ?? '',
                                    contextTitle: name,
                                  );
                                },
                          icon: const Icon(Icons.email),
                          label: const Text("مراسلة"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.check_circle),
                          label: const Text("طلب إشراف"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ManageContentActions(
                    collection: 'supervisors',
                    documentId: supervisorId,
                    ownerId: ownerId,
                    itemLabel: name,
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
