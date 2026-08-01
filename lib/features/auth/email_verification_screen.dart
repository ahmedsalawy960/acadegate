import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../profile/academic_profile_service.dart';
import 'email_auth_gate.dart';
import 'language_switcher_button.dart';
import 'portal_gateway.dart';
import 'welcome_screen.dart';

/// Blocks the app until the signed-in email/password user verifies email.
class EmailVerificationScreen extends StatefulWidget {
  /// True when the first automatic send after register failed.
  final bool initialSendFailed;
  final String? initialSendErrorCode;

  const EmailVerificationScreen({
    super.key,
    this.initialSendFailed = false,
    this.initialSendErrorCode,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;
  String? _statusMessage;

  String get _email =>
      FirebaseAuth.instance.currentUser?.email?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSendFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _statusMessage = _friendlySendError(widget.initialSendErrorCode);
        });
      });
    }
  }

  String _friendlySendError(String? code) {
    switch (code) {
      case 'too-many-requests':
        return context.t(
          'طلبات إرسال كثيرة. انتظر دقيقة ثم اضغط «إعادة إرسال الرابط».',
          'Too many send requests. Wait a minute, then tap "Resend link".',
        );
      case 'network':
      case 'network-request-failed':
        return context.t(
          'فشل الاتصال. تحقق من الإنترنت ثم أعد إرسال الرابط.',
          'Network error. Check your connection, then resend the link.',
        );
      case 'continue-uri':
      case 'unauthorized-continue-uri':
        return context.t(
          'خطأ إعداد رابط التأكيد في Firebase. تأكد أن acadegate-new.web.app '
          'ضمن Authorized domains.',
          'Verification link config error. Ensure acadegate-new.web.app is in Authorized domains.',
        );
      default:
        return context.t(
          'تعذّر إرسال رابط التأكيد${code != null ? ' ($code)' : ''}. '
          'اضغط «إعادة إرسال الرابط» وتحقق من Spam.\n'
          'المرسل: ${EmailAuthGate.verificationEmailSender}',
          'Could not send the verification link${code != null ? ' ($code)' : ''}. '
          'Tap "Resend link" and check Spam.\n'
          'Sender: ${EmailAuthGate.verificationEmailSender}',
        );
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _statusMessage = null;
    });
    try {
      final ok = await EmailAuthGate.reloadAndCheckVerified();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PortalGateway()),
          (_) => false,
        );
        return;
      }
      setState(() {
        _statusMessage = context.t(
          'لم يُؤكَّد البريد بعد. افتح الرابط من الرسالة ثم اضغط «تحقّقت».\n'
          'المرسل: ${EmailAuthGate.verificationEmailSender}',
          'Email not verified yet. Open the link from the email, then tap "I verified".\n'
          'Sender: ${EmailAuthGate.verificationEmailSender}',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _statusMessage = null;
    });
    try {
      final lang = Localizations.localeOf(context).languageCode;
      await EmailAuthGate.sendVerificationEmail(languageCode: lang);
      if (!mounted) return;
      setState(() {
        _statusMessage = context.t(
          'تم طلب إرسال الرابط إلى $_email\n'
          '• المرسل: ${EmailAuthGate.verificationEmailSender}\n'
          '• تحقق من Spam / الترويج / العروض\n'
          '• قد يتأخر وصول الرسالة دقيقة أو دقيقتين',
          'A verification link was requested for $_email\n'
          '• Sender: ${EmailAuthGate.verificationEmailSender}\n'
          '• Check Spam / Promotions\n'
          '• Delivery can take 1–2 minutes',
        );
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = _friendlySendError(
          EmailAuthGate.describeSendError(e),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = '$e');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    AcademicProfileService.instance.clearCache();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!EmailAuthGate.requiresVerification(FirebaseAuth.instance.currentUser)) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A237E)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AcadeGateAppBar(
        title: Text(context.t('تأكيد البريد', 'Verify email')),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        actions: const [LanguageSwitcherButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 72,
              color: Color(0xFF1A237E),
            ),
            const SizedBox(height: 20),
            Text(
              context.t(
                'أكد بريدك للمتابعة',
                'Confirm your email to continue',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.t(
                'يجب فتح رابط التأكيد المرسل إلى:\n$_email\n\n'
                'المرسل المتوقع:\n${EmailAuthGate.verificationEmailSender}\n\n'
                'تحقق من Spam إن لم تجد الرسالة، ثم اضغط «تحقّقت».',
                'Open the confirmation link sent to:\n$_email\n\n'
                'Expected sender:\n${EmailAuthGate.verificationEmailSender}\n\n'
                'Check Spam if missing, then tap "I verified".',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5, color: Colors.grey[800]),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange[900], height: 1.45),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _checking ? null : _checkVerified,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                minimumSize: const Size.fromHeight(52),
              ),
              child: _checking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      context.t(
                        'تحقّقت — فتح التطبيق',
                        'I verified — open app',
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _resending ? null : _resend,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _resending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t('إعادة إرسال الرابط', 'Resend link')),
            ),
            TextButton(
              onPressed: _signOut,
              child: Text(
                context.t(
                  'تسجيل الخروج / تغيير الحساب',
                  'Sign out / change account',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
