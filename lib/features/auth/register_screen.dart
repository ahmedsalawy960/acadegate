import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import 'portal_gateway.dart';
import 'portal_service.dart';
import 'portal_type.dart';
import 'user_account_service.dart';
import 'user_role.dart';
import 'language_switcher_button.dart';

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
      final l10n = context.l10n;
      String message = l10n.authErrorRegisterFailed;
      if (e.code == 'email-already-in-use') {
        message = l10n.authErrorEmailInUse;
      } else if (e.code == 'weak-password') {
        message = l10n.authErrorWeakPassword;
      } else if (e.code == 'invalid-email') {
        message = l10n.authErrorInvalidEmail;
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(l10n.registerTitle),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        actions: const [LanguageSwitcherButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chooseYourRole,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.registerRoleHint,
                style: const TextStyle(color: Colors.grey),
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
                      title: Text(L10nLookup.roleLabel(l10n, role)),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.fullName,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.nameRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.emailRequiredShort : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => (value ?? '').length < 6
                    ? l10n.passwordMinLength
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
                      : Text(l10n.createAccountButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
