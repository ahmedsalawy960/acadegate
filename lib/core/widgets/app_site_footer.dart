import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_contact_info.dart';
import '../locale/locale_extensions.dart';
import '../../features/legal/privacy_policy_screen.dart';
import '../../features/legal/support_help_screen.dart';
import 'acadegate_logo.dart';

/// تذييل الموقع أسفل أقسام الصفحة الرئيسية: شعار، روابط قانونية، دعم، هواتف، حقوق.
class AppSiteFooter extends StatelessWidget {
  const AppSiteFooter({super.key, this.accentColor = const Color(0xFF1A237E)});

  final Color accentColor;

  Future<void> _call(String e164) async {
    final uri = Uri(scheme: 'tel', path: e164);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final muted = Colors.white.withValues(alpha: 0.78);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor,
            Color.lerp(accentColor, const Color(0xFF0D1333), 0.35)!,
          ],
        ),
      ),
      child: Column(
        children: [
          const AcadeGateLogo(
            size: 72,
            showShadow: false,
            variant: AcadeGateLogoVariant.compact,
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Acade',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                TextSpan(
                  text: 'Gate',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8C468),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'بوابتك للتميز في الدراسات العليا',
              'Your gateway to excellence in postgraduate studies',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _FooterChip(
                icon: Icons.privacy_tip_outlined,
                label: context.t('سياسة الخصوصية', 'Privacy Policy'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
              _FooterChip(
                icon: Icons.support_agent_outlined,
                label: context.t('المساعدة والدعم', 'Help & Support'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SupportHelpScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context.t('تواصل معنا', 'Contact us'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...AppContactInfo.phoneLines.map((line) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _call(line.e164),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 18, color: muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${line.label(isAr)}: ${line.display(isAr)}',
                          style: TextStyle(color: muted, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: AppContactInfo.supportEmail,
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, size: 18, color: muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppContactInfo.supportEmail,
                      style: TextStyle(color: muted, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 14),
          Text(
            AppContactInfo.copyrightNotice(isAr),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  const _FooterChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
