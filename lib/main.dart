import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/auth/welcome_screen.dart';
// سنقوم لاحقاً بإنشاء صفحة الـ HomeScreen أو ربطها بالصفحة الرئيسية للتطبيق

void main() async {
  // التأكد من تهيئة أدوات فلاتر قبل الإقلاع
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الفايربيس اليدوية المباشرة لتخطي مشكلة الـ CLI
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA2cYZVquuQE_ti5v9dZmWBganVMqkY8gw",
  authDomain: "acadegate.firebaseapp.com",
  projectId: "acadegate",
  storageBucket: "acadegate.firebasestorage.app",
  messagingSenderId: "115536669882",
  appId: "1:115536669882:web:1ca4f3697129635bc1e683",
  measurementId: "G-32G8V032ET"
    ),
  );

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
          textDirection: TextDirection.rtl, // دعم الواجهة العربية البروفيشينال
          child: child!,
        );
      },
      // الـ StreamBuilder هنا هو الحارس الاحترافي للتطبيق
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // أثناء فحص البيانات السحابية تظهر حلقة التحميل المريحة للمستخدم
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFF1A237E))),
            );
          }
          // إذا كان مسجلاً دخولاً سابقاً وصاحب الحساب موثق يتم إدخاله فوراً
          if (snapshot.hasData) {
            // استبدل WelcomeScreen بصفحتك الرئيسية بعد تسجيل الدخول لاحقاً
            return const WelcomeScreen(); 
          }
          // إذا لم يسجل دخوله بعد يفتح إجبارياً على شاشة الترحيب/الدخول
          return const WelcomeScreen();
        },
      ),
    );
  }
}