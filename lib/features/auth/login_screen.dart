import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/acadegate_logo.dart';
import 'email_auth_gate.dart';
import 'email_verification_screen.dart';
import 'google_auth_service.dart';
import 'auth_password_reset_service.dart';
import 'user_account_service.dart';
import 'language_switcher_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _googleLoading = false;
  bool _resetLoading = false;
  bool _obscurePassword = true;

  Future<void> _navigateHome() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (EmailAuthGate.requiresVerification(user)) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
        (route) => false,
      );
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      final user = await GoogleAuthService.instance.signInWithGoogle();
      if (user != null) await _navigateHome();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await UserAccountService.instance.ensureAccountExists(
        FirebaseAuth.instance.currentUser!,
      );

      // Completes autofill save/update prompts on supported platforms.
      TextInput.finishAutofillContext();

      if (mounted) {
        await _navigateHome();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error: ${e.code} - ${e.message}");

      if (!mounted) return;
      final errorMessage = _loginErrorMessage(context, e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontSize: 14)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
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

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar(
        context.l10n.emailRequired,
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (!AuthPasswordResetService.instance.isValidEmail(email)) {
      _showSnackBar(
        context.l10n.authErrorInvalidEmail,
        backgroundColor: Colors.orange,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('إعادة تعيين كلمة المرور', 'Reset password')),
        content: Text(
          context.t(
            'سنُرسل رابط إعادة التعيين إلى:\n$email\n\n'
            'تحقق من الوارد والبريد المزعج (Spam) وPromotions.',
            'We will send a reset link to:\n$email\n\n'
            'Check Inbox, Spam, and Promotions folders.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('إرسال الرابط', 'Send link')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _resetLoading = true);
    try {
      final lang = Localizations.localeOf(context).languageCode;
      await AuthPasswordResetService.instance.sendResetEmail(
        email: email,
        languageCode: lang,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined, color: Colors.green),
          title: Text(context.t('تم إرسال الطلب', 'Request sent')),
          content: Text(
            context.t(
              'إذا كان $email مسجّلاً في AcadeGate، ستصلك رسالة خلال دقائق.\n\n'
              '• المرسل: ${AuthPasswordResetService.resetEmailSender}\n'
              '• تحقق من Spam / Promotions\n'
              '• إن سجّلت بـ Google، جرّب زر Google أيضاً',
              'If $email is registered in AcadeGate, you should receive an email '
              'within a few minutes.\n\n'
              '• Sender: ${AuthPasswordResetService.resetEmailSender}\n'
              '• Check Spam / Promotions\n'
              '• If you signed up with Google, try the Google button too',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.t('حسناً', 'OK')),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} - ${e.message}');
      if (!mounted) return;
      _showSnackBar(
        _passwordResetErrorMessage(context, e),
        backgroundColor: Colors.red,
      );
    } catch (e) {
      debugPrint('Password reset unexpected error: $e');
      if (!mounted) return;
      _showSnackBar(
        context.t(
          'تعذّر إرسال الرابط. تحقق من الاتصال وحاول مجدداً.',
          'Could not send the reset link. Check your connection and try again.',
        ),
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  void _showSnackBar(String message, {required Color backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  String _passwordResetErrorMessage(
    BuildContext context,
    FirebaseAuthException e,
  ) {
    final l10n = context.l10n;
    switch (e.code) {
      case 'invalid-email':
        return l10n.authErrorInvalidEmail;
      case 'user-not-found':
        return context.t(
          'لا يوجد حساب بهذا البريد. أنشئ حساباً أو استخدم Google.',
          'No account with this email. Create an account or use Google sign-in.',
        );
      case 'too-many-requests':
        return l10n.authErrorTooManyRequests;
      case 'operation-not-allowed':
        return context.t(
          'إعادة تعيين كلمة المرور غير مفعّلة. '
          'فعّل Email/Password من Firebase → Authentication → Sign-in method.',
          'Password reset is disabled. '
          'Enable Email/Password in Firebase → Authentication → Sign-in method.',
        );
      case 'unauthorized-continue-uri':
      case 'invalid-continue-uri':
      case 'missing-continue-uri':
        return context.t(
          'خطأ في إعدادات رابط إعادة التعيين. '
          'أضف نطاق التطبيق إلى Authorized domains في Firebase.',
          'Reset link configuration error. '
          'Add your app domain to Authorized domains in Firebase.',
        );
      default:
        return context.t(
          'تعذّر إرسال رابط إعادة التعيين (${e.code}).',
          'Could not send the reset link (${e.code}).',
        );
    }
  }

  String _loginErrorMessage(BuildContext context, FirebaseAuthException e) {
    final l10n = context.l10n;
    final email = _emailController.text.trim().toLowerCase();
    final looksLikeGmail =
        email.endsWith('@gmail.com') || email.endsWith('@googlemail.com');

    switch (e.code) {
      case 'user-not-found':
        return context.t(
          'لا يوجد حساب بهذا البريد. أنشئ حساباً جديداً أو استخدم Google.',
          'No account with this email. Create an account or use Google sign-in.',
        );
      case 'wrong-password':
        return context.t(
          'كلمة المرور غير صحيحة. جرّب «نسيت كلمة المرور؟»',
          'Incorrect password. Try "Forgot password?"',
        );
      case 'invalid-credential':
        if (looksLikeGmail) {
          return context.t(
            'إذا سجّلت سابقاً بـ Google، استخدم زر «Google» وليس كلمة المرور. '
            'أو أنشئ كلمة مرور عبر «نسيت كلمة المرور؟»',
            'If you signed up with Google, use the Google button instead of a password. '
            'Or set a password via "Forgot password?"',
          );
        }
        return context.t(
          'بيانات الدخول غير صحيحة. '
          'إن كنت سجّلت بـ Google أو Facebook استخدم نفس الطريقة.',
          'Invalid sign-in details. '
          'If you registered with Google or Facebook, use the same method.',
        );
      case 'invalid-email':
        return l10n.authErrorInvalidEmail;
      case 'user-disabled':
        return l10n.authErrorAccountDisabled;
      case 'too-many-requests':
        return l10n.authErrorTooManyRequests;
      case 'operation-not-allowed':
        return context.t(
          'تسجيل الدخول بالبريد غير مفعّل في Firebase. '
          'فعّل Email/Password من Authentication → Sign-in method.',
          'Email/password sign-in is disabled in Firebase. '
          'Enable Email/Password under Authentication → Sign-in method.',
        );
      default:
        return l10n.authErrorInvalidCredentials;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final googleAvailable = GoogleAuthService.isConfiguredForCurrentPlatform;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AcadeGateAppBar(
        title: Text(
          l10n.loginTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        actions: const [LanguageSwitcherButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AcadeGateLogoHeader(
                  logoSize: 108,
                ),
                const SizedBox(height: 28),
                AutofillGroup(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        enableSuggestions: true,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l10n.emailLabel,
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF1A237E),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? l10n.emailRequired
                                : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF1A237E),
                          ),
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
                        validator: (value) => (value == null || value.length < 6)
                            ? l10n.passwordMinLength
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: (_isLoading || _resetLoading)
                        ? null
                        : _handleForgotPassword,
                    child: _resetLoading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(context.t('جاري الإرسال…', 'Sending…')),
                            ],
                          )
                        : Text(
                            context.t('نسيت كلمة المرور؟', 'Forgot password?'),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            l10n.loginButton,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n.orDivider,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 16),
                if (!googleAvailable) ...[
                  Text(
                    context.t(
                      'تسجيل Google على الويب/سطح المكتب يحتاج إعداد GOOGLE_WEB_CLIENT_ID',
                      'Google sign-in on web/desktop requires GOOGLE_WEB_CLIENT_ID setup',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: (!googleAvailable || _isLoading || _googleLoading)
                        ? null
                        : _handleGoogleSignIn,
                    icon: _googleLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata, size: 28),
                    label: Text(l10n.googleLogin),
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
