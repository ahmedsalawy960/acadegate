import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'portal_gateway.dart';
import 'portal_service.dart';
import 'portal_type.dart';
import 'user_account_service.dart';
import 'user_role.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = UserRole.student;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await UserAccountService.instance.createAccount(
        firebaseUser: credential.user!,
        displayName: _nameController.text.trim(),
        role: _selectedRole,
      );

      final suggested = PortalType.suggestedForRole(_selectedRole);
      if (suggested != null) {
        await PortalService.instance.setActivePortal(suggested);
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const PortalGateway()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'تعذر إنشاء الحساب';
      if (e.code == 'email-already-in-use') {
        message = 'هذا البريد مستخدم بالفعل';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة';
      } else if (e.code == 'invalid-email') {
        message = 'صيغة البريد غير صحيحة';
      }
      _showError(message);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختر دورك في المنصة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'يحدد الدور ما يمكنك إضافته: منتجات، مختبر، ملف مشرف، أو أفكار بحثية.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: _selectedRole,
                onChanged: (value) {
                  if (value != null) setState(() => _selectedRole = value);
                },
                child: Column(
                  children: UserRole.all.map((role) {
                    return RadioListTile<String>(
                      value: role,
                      title: Text(UserRole.label(role)),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'الاسم الكامل',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'البريد مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => (value ?? '').length < 6
                    ? 'كلمة المرور 6 أحرف على الأقل'
                    : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إنشاء الحساب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
