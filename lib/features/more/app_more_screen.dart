import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_contact_info.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../../core/widgets/acadegate_app_bar.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_of_service_screen.dart';
import '../profile/account_profile_screen.dart';

/// خيارات الحساب العامة، خارج المتجر، من شريط التطبيق.
class AppMoreScreen extends StatelessWidget {
  const AppMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AcadeGateColors.page,
      appBar: AcadeGateAppBar(
        title: Text(context.t('المزيد', 'More')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              final account = snapshot.data;
              final name = account?.displayName.trim().isNotEmpty == true
                  ? account!.displayName.trim()
                  : (user?.displayName ?? '');
              final email = account?.email ?? user?.email ?? '';
              final role = UserRole.label(account?.role ?? UserRole.student);
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AcadeGateColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AcadeGateColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('أهلاً', 'Hello'),
                      style: const TextStyle(color: AcadeGateColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name.isEmpty ? context.t('حسابك', 'Your account') : name,
                      style: const TextStyle(
                        color: AcadeGateColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(color: AcadeGateColors.muted),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('نوع الحساب: $role', 'Account type: $role'),
                      style: const TextStyle(color: AcadeGateColors.text),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _MoreRow(
            icon: Icons.settings_outlined,
            title: context.t('إعدادات الحساب', 'Account settings'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountProfileScreen()),
            ),
          ),
          _MoreRow(
            icon: Icons.share_outlined,
            title: context.t('مشاركة التطبيق', 'Share the app'),
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text: context.t(
                  'AcadeGate — منصة للباحثين: مشرفون ومختبرات ومتجر أكاديمي.\nhttps://acadegate-new.web.app',
                  'AcadeGate — supervisors, labs, and an academic store.\nhttps://acadegate-new.web.app',
                ),
              ),
            ),
          ),
          _MoreRow(
            icon: Icons.star_outline,
            title: context.t('قيّمنا', 'Rate us'),
            onTap: () async {
              final uri = Uri.parse('https://acadegate-new.web.app');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          _MoreRow(
            icon: Icons.info_outline,
            title: context.t('حول التطبيق', 'About'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppAboutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AcadeGateColors.card,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AcadeGateColors.line),
          ),
          leading: CircleAvatar(
            backgroundColor: AcadeGateColors.gold.withValues(alpha: 0.15),
            child: Icon(icon, color: AcadeGateColors.gold),
          ),
          title: Text(title),
          onTap: onTap,
        ),
      ),
    );
  }
}

class AppAboutScreen extends StatelessWidget {
  const AppAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AcadeGateColors.page,
      appBar: AcadeGateAppBar(
        title: Text(context.t('حول التطبيق', 'About')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.t(
              'AcadeGate منصة للباحثين: مشرفون، مختبرات، رسالة، ومتجر أكاديمي. في طلبات Partner نحتفظ بالمبلغ حتى تأكيد الاستلام. قوائم الدليل معلومات عامة وليست بيعاً من المنصة.',
              'AcadeGate is for researchers: supervisors, labs, a thesis file, and an academic store. Partner orders hold payment until delivery is confirmed. Directory listings are public information, not a sale by the platform.',
            ),
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(AppContactInfo.supportEmail),
          const SizedBox(height: 12),
          ListTile(
            title: Text(context.t('شروط الاستخدام', 'Terms of use')),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
            ),
          ),
          ListTile(
            title: Text(context.t('سياسة الخصوصية', 'Privacy policy')),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
