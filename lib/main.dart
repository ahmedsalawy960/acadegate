import 'package:flutter/material.dart';
import 'features/auth/welcome_screen.dart';

void main() {
  runApp(const AcadeGateApp());
}

class AcadeGateApp extends StatelessWidget {
  const AcadeGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AcadeGate',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const WelcomeScreen(),
    );
  }
}
// =======================================================
// ميزة المطابقة الذكية المضافة (Smart Matchmaking)
// =======================================================

// 1. موديل المشرف
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

// 2. القائمة العالمية للمشرفين والـ Tags الخاصة بهم لعملية التوافق
final List<Supervisor> allSupervisors = [
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

// 3. شاشة التوفيق الذكي (Smart Matchmaking Screen)
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
      // البحث والفلترة داخل الـ Tags لأخذ أفضل 3 مشرفين متطابقين
      _matchedSupervisors = allSupervisors.where((supervisor) {
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