import 'package:flutter/material.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/acadegate_logo.dart';
import 'portal_gateway.dart';
import 'google_auth_service.dart';
import 'facebook_auth_service.dart';
import 'apple_auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'language_switcher_button.dart';
import 'welcome_feature_showcase.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _googleSignIn(BuildContext context) async {
    try {
      final user = await GoogleAuthService.instance.signInWithGoogle();
      if (user != null && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PortalGateway()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _facebookSignIn(BuildContext context) async {
    try {
      final user = await FacebookAuthService.instance.signInWithFacebook();
      if (user != null && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PortalGateway()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _appleSignIn(BuildContext context) async {
    try {
      final user = await AppleAuthService.instance.signInWithApple();
      if (user != null && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PortalGateway()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: const WelcomeFeatureCarousel(),
                  ),
                  Expanded(
                    flex: 9,
                    child: _WelcomeAuthPanel(
                      onGoogle: () => _googleSignIn(context),
                      onFacebook: () => _facebookSignIn(context),
                      onApple: () => _appleSignIn(context),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(
                  height: (constraints.maxHeight * 0.48).clamp(300.0, 420.0),
                  child: const WelcomeFeatureCarousel(),
                ),
                Expanded(
                  child: _WelcomeAuthPanel(
                    onGoogle: () => _googleSignIn(context),
                    onFacebook: () => _facebookSignIn(context),
                    onApple: () => _appleSignIn(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeAuthPanel extends StatelessWidget {
  const _WelcomeAuthPanel({
    required this.onGoogle,
    required this.onFacebook,
    required this.onApple,
  });

  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onApple;

  static const _brand = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final googleAvailable = GoogleAuthService.isConfiguredForCurrentPlatform;
    final facebookAvailable = FacebookAuthService.isAvailable;
    final appleAvailable = AppleAuthService.isAvailable;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const PortalGateway()),
                ),
                child: Text(l10n.browseGuest),
              ),
              const Spacer(),
              const LanguageSwitcherButton(),
            ],
          ),
          const SizedBox(height: 8),
          AcadeGateLogoHeader(
            logoSize: 110,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.login,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.login_rounded, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegisterScreen(),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _brand,
                side: const BorderSide(color: _brand),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l10n.register,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  context.t('خيارات دخول أخرى', 'Other sign-in options'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialIconButton(
                tooltip: l10n.googleSignIn,
                enabled: googleAvailable,
                icon: Icons.g_mobiledata,
                onPressed: onGoogle,
              ),
              const SizedBox(width: 14),
              _SocialIconButton(
                tooltip: context.t(
                  'متابعة بـ Facebook',
                  'Continue with Facebook',
                ),
                enabled: facebookAvailable,
                icon: Icons.facebook_rounded,
                onPressed: onFacebook,
              ),
              const SizedBox(width: 14),
              _SocialIconButton(
                tooltip: context.t(
                  'متابعة بـ Apple',
                  'Continue with Apple',
                ),
                enabled: appleAvailable,
                icon: Icons.apple,
                onPressed: onApple,
              ),
            ],
          ),
          if (!googleAvailable) ...[
            const SizedBox(height: 12),
            Text(
              context.t(
                'Google على سطح المكتب يحتاج GOOGLE_WEB_CLIENT_ID',
                'Google on desktop needs GOOGLE_WEB_CLIENT_ID',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            context.t(
              'اسحب الخلفية يميناً/يساراً لاستكشاف خدمات المنصة',
              'Swipe the hero to explore platform services',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final String tooltip;
  final bool enabled;
  final IconData icon;
  final VoidCallback onPressed;

  const _SocialIconButton({
    required this.tooltip,
    required this.enabled,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF6A1B9A);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? borderColor : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 30,
            color: enabled ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
