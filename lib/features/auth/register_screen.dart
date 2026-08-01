import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/faculty_categories.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import 'email_auth_gate.dart';
import 'email_verification_screen.dart';
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
  final _universityController = TextEditingController();
  final _specializationController = TextEditingController();
  final _researchInterestController = TextEditingController();

  String _selectedRole = UserRole.student;
  String _degree = 'ماجستير';
  String? _facultyCategory;
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _needsAcademicProfile =>
      _selectedRole == UserRole.student ||
      _selectedRole == UserRole.supervisor;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _universityController.dispose();
    _specializationController.dispose();
    _researchInterestController.dispose();
    super.dispose();
  }

  Future<void> _saveAcademicProfileIfNeeded(String displayName) async {
    if (!_needsAcademicProfile) return;

    final specialization = _specializationController.text.trim();
    final researchInterest = _researchInterestController.text.trim();
    final facultyCategory = _facultyCategory?.trim() ??
        inferFacultyCategoryFromText('$specialization $researchInterest') ??
        '';

    final profile = AcademicProfile(
      fullName: displayName,
      university: _universityController.text.trim(),
      degree: _degree,
      facultyCategory: facultyCategory,
      specialization: specialization,
      researchInterest: researchInterest,
      methodology: 'كمي',
      preferredLanguage: 'العربية',
      city: '',
    );

    await AcademicProfileService.instance.saveProfile(profile);

    if (profile.isComplete) {
      await ThesisProgressService.instance.recordActivity(
        ThesisActivityId.profileComplete.name,
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Drop previous guest/account offline progress on this device.
      AcademicProfileService.instance.clearCache();

      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user!;
      final displayName = _nameController.text.trim();
      await user.updateDisplayName(displayName);

      await UserAccountService.instance.createAccount(
        firebaseUser: user,
        displayName: displayName,
        role: _selectedRole,
      );

      await _saveAcademicProfileIfNeeded(displayName);

      final suggested = PortalType.suggestedForRole(_selectedRole);
      if (suggested != null) {
        await PortalService.instance.setActivePortal(suggested);
      }

      var sendFailed = false;
      String? sendErrorCode;
      try {
        if (!mounted) return;
        final lang = Localizations.localeOf(context).languageCode;
        await EmailAuthGate.sendVerificationEmail(languageCode: lang);
      } on FirebaseAuthException catch (e) {
        sendFailed = true;
        sendErrorCode = EmailAuthGate.describeSendError(e);
      } catch (_) {
        sendFailed = true;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            initialSendFailed: sendFailed,
            initialSendErrorCode: sendErrorCode,
          ),
        ),
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
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? context.t('إظهار كلمة المرور', 'Show password')
                        : context.t('إخفاء كلمة المرور', 'Hide password'),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => (value ?? '').length < 6
                    ? l10n.passwordMinLength
                    : null,
              ),
              if (_needsAcademicProfile) ...[
                const SizedBox(height: 28),
                Text(
                  context.t('الملف الأكاديمي', 'Academic profile'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(
                    'تظهر في ملفك ويمكنك تعديلها لاحقاً من ملفي الأكاديمي.',
                    'Saved to your profile — you can edit later anytime.',
                  ),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _universityController,
                  decoration: InputDecoration(
                    labelText: context.t('الجامعة', 'University'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? context.t('مطلوب', 'Required')
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _degree,
                  decoration: InputDecoration(
                    labelText: context.t('الدرجة العلمية', 'Degree'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'ماجستير',
                      child: Text(context.t('ماجستير', "Master's")),
                    ),
                    DropdownMenuItem(
                      value: 'دكتوراه',
                      child: Text(context.t('دكتوراه', 'PhD')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _degree = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _facultyCategory,
                  decoration: InputDecoration(
                    labelText: context.t('الكلية', 'Faculty / college'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    for (final faculty in facultyCategories)
                      DropdownMenuItem(
                        value: faculty.id,
                        child: Text(faculty.titleAr),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _facultyCategory = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _specializationController,
                  decoration: InputDecoration(
                    labelText: context.t('التخصص', 'Specialization'),
                    hintText: context.t(
                      'مثال: كيمياء عضوية، هندسة مدنية',
                      'e.g. Organic chemistry, civil engineering',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? context.t('مطلوب', 'Required')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _researchInterestController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText:
                        context.t('اهتمامك البحثي', 'Research interest'),
                    hintText: context.t(
                      'مثال: الطاقة الشمسية، النانو تكنولوجي',
                      'e.g. Solar energy, nanotechnology',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? context.t('مطلوب', 'Required')
                      : null,
                ),
              ],
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
