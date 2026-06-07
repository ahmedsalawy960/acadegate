import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("تسجيل الدخول"), centerTitle: true),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24.0), child: Column(children: [
        const Text("أهلاً بك في AcadeGate", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
        const SizedBox(height: 40),
        TextFormField(decoration: InputDecoration(labelText: "البريد الجامعي", prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 20),
        TextFormField(obscureText: true, decoration: InputDecoration(labelText: "كلمة المرور", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, height: 55, child: FilledButton(onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1A237E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("دخـــول", style: TextStyle(fontSize: 18)))),
      ]))),
    );
  }
}