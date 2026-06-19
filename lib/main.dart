import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/notifications/push_notification_bootstrap.dart';
import 'firebase_options.dart';
import 'features/auth/welcome_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationBootstrap.init();
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
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF1A237E)),
              ),
            );
          }
          // إذا كان مسجلاً دخولاً سابقاً وصاحب الحساب موثق يتم إدخاله فوراً
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          // إذا لم يسجل دخوله بعد يفتح إجبارياً على شاشة الترحيب/الدخول
          return const WelcomeScreen();
        },
      ),
    );
  }
}
