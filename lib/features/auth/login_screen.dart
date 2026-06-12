import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../home/home_screen.dart'; // السطر الجديد للوصول للشاشة الرئيسية الشاملة

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // معرفات للتحكم بالنصوص المكتوبة
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // لمتابعة حالة التحميل لمنع الضغط المتكرر

  // دالة تسجيل الدخول عبر الـ Firebase
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // إرسال البيانات للفايربيس للتحقق
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // إذا نجح الدخول، يتم توجيهه فوراً إلى الشاشة الرئيسية (أو شاشة التوفيق الذكي كمثال حالي)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "حدث خطأ غير متوقع.";
      
      // مطابقة كود الخطأ القادم من السيرفر لإظهار رسالة عربية مفهومة
      if (e.code == 'user-not-found') {
        errorMessage = "هذا البريد الإلكتروني غير مسجل لدينا.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "كلمة المرور التي أدخلتها غير صحيحة.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "صيغة البريد الإلكتروني غير صحيحة.";
      } else if (e.code == 'user-disabled') {
        errorMessage = "تم تعطيل هذا الحساب من قبل الإدارة.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontSize: 14)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // تنظيف الذاكرة عند الخروج من الشاشة لرفع كفاءة التطبيق
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("تسجيل الدخول", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "أهلاً بك في AcadeGate",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 10),
                const Text(
                  "يرجى تسجيل الدخول الموثق للمتابعة",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                
                // حقل البريد الإلكتروني
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: "البريد الجامعي / الإلكتروني",
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "الرجاء إدخال البريد الإلكتروني";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // حقل كلمة المرور
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: "كلمة المرور",
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "الرجاء إدخال كلمة المرور";
                    }
                    if (value.length < 6) {
                      return "كلمة المرور يجب ألا تقل عن 6 أحرف";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                
                // زر الدخول الذكي
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("دخـــول", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}