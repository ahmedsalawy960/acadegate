import 'package:flutter/material.dart';
import 'package:acadegate/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // كُنترولر للتحكم بنص البحث
  final TextEditingController _searchController = TextEditingController();

  // الكلمة التي يبحث عنها المستخدم حالياً
  String _searchQuery = "";

  // 1. قائمة الأقسام الرئيسية والتصنيفات
  final List<Map<String, dynamic>> _allServices = [
    {
      "title": "المشرفون",
      "icon": Icons.people_alt_rounded,
      "image": "assets/images/supervisors.jpg", // 👈 أضفنا مسار الصورة هنا
      "color": Colors.blue,
      "tags": ["كلية", "جامعة", "أساتذة", "دكتور", "مشرفين", "مشرف"],
      "screen": const FacultiesScreen(),
    },
    {
      "title": "أفكار بحثية",
      "icon": Icons.lightbulb_rounded,
      "color": Colors.orange,
      "image":
          "assets/images/ideas.jpg", // 👈 هذا هو السطر السحري الجديد لقسم الأفكار البحثية
      "tags": ["بحث", "أفكار", "مقترح", "مشاريع", "طاقة", "مرور", "دراسة"],
      "screen": const ResearchIdeasScreen(),
    },
    {
      "title": "المختبرات",
      "icon": Icons.science_rounded,
      "color": Colors.purple,
      "image":
          "assets/images/labs.jpg", // 👈 هذا هو السطر السحري الجديد لقسم المختبرات
      "tags": ["مختبر", "مختبرات", "معمل", "أجهزة", "نانو", "تحليل", "كيمياء"],
      "screen": const LabsScreen(),
    },
    {
      "title": "المتجر",
      "icon": Icons.shopping_cart_rounded,
      "color": Colors.green,
      "image": "assets/images/shop.jpg", // 👈 هذا هو السطر الخاص بالمتجر
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
      "screen": const MarketplaceScreen(),
    },
  ];

  // 2. قاعدة بيانات المشرفين المتاحة في التطبيق للبحث المباشر عنها
  final List<Map<String, dynamic>> _allSupervisors = [
    {
      "name": "أ.د. عادل محمود",
      "speciality": "هندسة مدنية",
      "university": "جامعة القاهرة",
      "category": "Engineering",
    },
    {
      "name": "د. هدى الشافعي",
      "speciality": "هندسة معمارية",
      "university": "جامعة عين شمس",
      "category": "Engineering",
    },
    {
      "name": "أ.د. سارة علي",
      "speciality": "كيمياء عضوية",
      "university": "جامعة الملك سعود",
      "category": "Science",
    },
    {
      "name": "أ.د. مجدي يعقوب",
      "speciality": "جراحة قلب",
      "university": "مركز القلب",
      "category": "Medicine",
    },
    {
      "name": "المستشار أحمد فتحي",
      "speciality": "قانون دولي",
      "university": "جامعة القاهرة",
      "category": "Law",
    },
    {
      "name": "أ.د. محمد أحمد",
      "speciality": "ذكاء اصطناعي",
      "university": "جامعة القاهرة",
      "category": "CS",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();

    // فلترة الأقسام الرئيسية
    final filteredServices = _allServices.where((service) {
      final title = service["title"].toString().toLowerCase();
      final tags = (service["tags"] as List<String>).join(" ").toLowerCase();
      return title.contains(query) || tags.contains(query);
    }).toList();

    // فلترة المشرفين بناءً على الاسم أو التخصص
    final filteredSupervisors = _allSupervisors.where((sup) {
      final name = sup["name"].toString().toLowerCase();
      final speciality = sup["speciality"].toString().toLowerCase();
      final university = sup["university"].toString().toLowerCase();
      return name.contains(query) ||
          speciality.contains(query) ||
          university.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("الرئيسية"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'ابحث عن اسم مشرف، تخصص، مادة أو قسم...',
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
              child: _searchQuery.isEmpty
                  ? GridView.builder(
                      itemCount: _allServices.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemBuilder: (context, index) {
                        final item = _allServices[index];
                        return DashboardCard(
                          title: item["title"],
                          imagePath:
                              item["image"], // 👈 قمنا بتغيير هذا السطر لتمرير حقل الصورة الجديد
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
                  : (filteredServices.isEmpty && filteredSupervisors.isEmpty)
                  ? const Center(
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
                            "عذراً، لم نجد نتائج تطابق بحثك!",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        // إذا وُجدت أقسام تطابق البحث
                        if (filteredServices.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "الأقسام والخدمات",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
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
                                    builder: (context) => item["screen"],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // إذا وُجد مشرفون يطابقون البحث
                        if (filteredSupervisors.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "المشرفون الأكاديميون",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ...filteredSupervisors.map(
                            (sup) => SupervisorListCard(
                              name: sup["name"],
                              speciality: sup["speciality"],
                              university: sup["university"],
                              isAvailable: true,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final String imagePath; // 🟢 تم التغيير هنا ليكون مسار الصورة نصياً (String)
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.imagePath, // 🟢 تم التحديث هنا لاستقبال حقل الصورة المطور
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 35,
                // استخدام الـ التعديل الحديث بدلاً من withOpacity لتفادي أي تحذيرات زرقاء
                backgroundColor: color.withValues(alpha: 0.1),
                backgroundImage: AssetImage(
                  imagePath,
                ), // 🟢 لعرض الصورة ديناميكياً
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
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
        title: const Text("اختر التخصص"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FacultyCard(
            name: "كلية الهندسة",
            icon: Icons.engineering,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const SupervisorsListScreen(category: "Engineering"),
              ),
            ),
          ),
          FacultyCard(
            name: "كلية العلوم",
            icon: Icons.science,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const SupervisorsListScreen(category: "Science"),
              ),
            ),
          ),
          FacultyCard(
            name: "كلية الطب",
            icon: Icons.medical_services,
            color: Colors.red,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const SupervisorsListScreen(category: "Medicine"),
              ),
            ),
          ),
          FacultyCard(
            name: "كلية الحقوق",
            icon: Icons.gavel,
            color: Colors.brown,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const SupervisorsListScreen(category: "Law"),
              ),
            ),
          ),
          FacultyCard(
            name: "كلية الحاسبات",
            icon: Icons.computer,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const SupervisorsListScreen(category: "CS"),
              ),
            ),
          ),
        ],
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
  final VoidCallback onTap;
  const FacultyCard({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
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
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
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
  const SupervisorsListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    String title = "";
    List<Widget> supervisors = [];

    if (category == "Engineering") {
      title = "مشرفو الهندسة";
      supervisors = const [
        SupervisorListCard(
          name: "أ.د. عادل محمود",
          speciality: "هندسة مدنية",
          university: "جامعة القاهرة",
          isAvailable: true,
        ),
        SupervisorListCard(
          name: "د. هدى الشافعي",
          speciality: "هندسة معمارية",
          university: "جامعة عين شمس",
          isAvailable: false,
        ),
      ];
    } else if (category == "Science") {
      title = "مشرفو العلوم";
      supervisors = const [
        SupervisorListCard(
          name: "أ.د. سارة علي",
          speciality: "كيمياء عضوية",
          university: "جامعة الملك سعود",
          isAvailable: false,
        ),
      ];
    } else if (category == "Medicine") {
      title = "مشرفو الطب";
      supervisors = const [
        SupervisorListCard(
          name: "أ.د. مجدي يعقوب",
          speciality: "جراحة قلب",
          university: "مركز القلب",
          isAvailable: true,
        ),
      ];
    } else if (category == "Law") {
      title = "مشرفو الحقوق";
      supervisors = const [
        SupervisorListCard(
          name: "المستشار أحمد فتحي",
          speciality: "قانون دولي",
          university: "جامعة القاهرة",
          isAvailable: true,
        ),
      ];
    } else {
      title = "مشرفو الحاسبات";
      supervisors = const [
        SupervisorListCard(
          name: "أ.د. محمد أحمد",
          speciality: "ذكاء اصطناعي",
          university: "جامعة القاهرة",
          isAvailable: true,
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: supervisors),
    );
  }
}

class SupervisorListCard extends StatelessWidget {
  final String name;
  final String speciality;
  final String university;
  final bool isAvailable;
  const SupervisorListCard({
    super.key,
    required this.name,
    required this.speciality,
    required this.university,
    required this.isAvailable,
  });
  @override
  Widget build(BuildContext context) {
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
                bio: "أستاذ متخصص في $speciality.",
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
                      "$speciality\n$university",
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
  const SupervisorProfileScreen({
    super.key,
    required this.name,
    required this.speciality,
    required this.university,
    required this.bio,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الملف الشخصي"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
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
                          onPressed: () {},
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// قسم الأفكار البحثية
// =======================================================
class ResearchIdeasScreen extends StatelessWidget {
  const ResearchIdeasScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("أفكار بحثية"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ResearchIdeaCard(
            title: "نظام مرور ذكي",
            provider: "وزارة النقل",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ResearchDetailScreen(
                  title: "نظام مرور ذكي",
                  details:
                      "يهدف هذا البحث لتطوير خوارزميات للتحكم في الإشارات.",
                ),
              ),
            ),
          ),
          ResearchIdeaCard(
            title: "طاقة شمسية",
            provider: "شركة الكهرباء",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ResearchDetailScreen(
                  title: "طاقة شمسية",
                  details: "دراسة تأثير الحرارة على كفاءة الألواح.",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResearchIdeaCard extends StatelessWidget {
  final String title, provider;
  final VoidCallback onTap;
  const ResearchIdeaCard({
    super.key,
    required this.title,
    required this.provider,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          leading: const Icon(Icons.lightbulb, color: Colors.orange),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(provider),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }
}

class ResearchDetailScreen extends StatelessWidget {
  final String title, details;
  const ResearchDetailScreen({
    super.key,
    required this.title,
    required this.details,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل البحث"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "التفاصيل:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(details, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                ),
                child: const Text("تقديم مقترح"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// قسم المختبرات
// =======================================================
class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("المختبرات"),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabCard(
            name: "مختبر النانو",
            location: "كلية العلوم",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LabDetailScreen(
                  name: "مختبر النانو",
                  equipment: "مجهر إلكتروني (SEM)",
                ),
              ),
            ),
          ),
          LabCard(
            name: "معمل التحليل",
            location: "مركز البحوث",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LabDetailScreen(
                  name: "معمل التحليل",
                  equipment: "جهاز NMR",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LabCard extends StatelessWidget {
  final String name, location;
  final VoidCallback onTap;
  const LabCard({
    super.key,
    required this.name,
    required this.location,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          leading: const Icon(Icons.science, color: Colors.purple),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(location),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }
}

class LabDetailScreen extends StatelessWidget {
  final String name, equipment;
  const LabDetailScreen({
    super.key,
    required this.name,
    required this.equipment,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل المختبر"),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "الأجهزة:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(equipment, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text("حجز موعد"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// قسم المتجر
// =======================================================
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("المتجر"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          ProductCard(
            name: "مجهر ضوئي",
            price: "1200 ر.س",
            icon: Icons.biotech,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProductDetailScreen(
                  name: "مجهر ضوئي",
                  price: "1200 ر.س",
                ),
              ),
            ),
          ),
          ProductCard(
            name: "أنابيب اختبار",
            price: "50 ر.س",
            icon: Icons.science,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProductDetailScreen(
                  name: "أنابيب اختبار",
                  price: "50 ر.س",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final String name, price;
  final IconData icon;
  final VoidCallback onTap;
  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.green[50],
                width: double.infinity,
                child: Icon(icon, size: 50, color: Colors.green),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(price, style: TextStyle(color: Colors.green[700])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  final String name, price;
  const ProductDetailScreen({
    super.key,
    required this.name,
    required this.price,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل المنتج"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.shopping_cart, size: 100, color: Colors.green[200]),
            const SizedBox(height: 20),
            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              price,
              style: const TextStyle(fontSize: 20, color: Colors.green),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text("إضافة للسلة"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// ويدجيت شاشة المطابقة الذكية (MatchmakingScreen) مدمجة هنا محلياً لمنع مشاكل الـ Import
// ==============================================================================

class Supervisor {
  final String name;
  final String university;
  final String speciality;
  final String bio;
  final List<String> tags;

  const Supervisor({
    required this.name,
    required this.university,
    required this.speciality,
    required this.bio,
    required this.tags,
  });
}

final List<Supervisor> allSupervisorsForMatch = [
  const Supervisor(
    name: "أ.د. عادل محمود",
    university: "جامعة القاهرة",
    speciality: "هندسة النانو",
    bio: "مخترع وباحث في تكنولوجيا المواد الدقيقة والنانو.",
    tags: ["nano", "نانو", "engineering", "هندسة"],
  ),
  const Supervisor(
    name: "د. هدى الشافعي",
    university: "جامعة عين شمس",
    speciality: "ذكاء اصطناعي",
    bio: "متخصصة في معالجة اللغات الطبيعية والتعلم العميق.",
    tags: ["ai", "ذكاء", "computer", "حاسب"],
  ),
  const Supervisor(
    name: "أ.د. سارة علي",
    university: "جامعة الملك سعود",
    speciality: "كيمياء حيوية",
    bio: "أبحاث متقدمة في دمج النانو تكنولوجي بالصناعات الكيميائية.",
    tags: ["chemistry", "كيمياء", "nano", "نانو"],
  ),
  const Supervisor(
    name: "أ.د. محمد أحمد",
    university: "جامعة القاهرة",
    speciality: "علم البيانات",
    bio: "خبير في تحليل البيانات الضخمة والرؤية الحاسوبية.",
    tags: ["data", "بيانات", "ai", "ذكاء"],
  ),
  const Supervisor(
    name: "د. خالد عمر",
    university: "جامعة الملك فهد",
    speciality: "التحكم الذكي",
    bio: "تطوير أنظمة روبوتية معتمدة على الذكاء الاصطناعي.",
    tags: ["ai", "ذكاء", "robots", "روبوت"],
  ),
];

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final TextEditingController _interestController = TextEditingController();
  List<Supervisor> _matchedSupervisors = [];
  bool _hasSearched = false;

  void _findSupervisor() {
    final input = _interestController.text.trim().toLowerCase();
    if (input.isEmpty) return;

    setState(() {
      _hasSearched = true;
      _matchedSupervisors = allSupervisorsForMatch.where((supervisor) {
        return supervisor.tags.any((tag) => tag.contains(input));
      }).take(3).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("التوفيق الذكي للمشرفين"),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "أدخل اهتمامك البحثي (مثال: AI، نانو، كيمياء):",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _interestController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: "ما هو مجال البحث الذي تفكر به؟",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.psychology, color: Color(0xFF1A237E)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _findSupervisor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.bolt_rounded),
                label: const Text("Find My Supervisor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
            if (_hasSearched) ...[
              const Text("أفضل 3 مشرفين مقترحين لاهتمامك:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              const SizedBox(height: 10),
              _matchedSupervisors.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40.0),
                        child: Text("لم نجد مشرفين يطابقون هذا الاهتمام حالياً.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        itemCount: _matchedSupervisors.length,
                        itemBuilder: (context, index) {
                          final sup = _matchedSupervisors[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("${sup.speciality} - ${sup.university}"),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => SupervisorProfileScreen(
                                  name: sup.name,
                                  speciality: sup.speciality,
                                  university: sup.university,
                                  bio: sup.bio,
                                )));
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}