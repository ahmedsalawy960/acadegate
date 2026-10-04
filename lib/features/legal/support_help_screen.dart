import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/config/app_contact_info.dart';
import '../../core/locale/locale_extensions.dart';
import 'privacy_policy_screen.dart';
import 'privacy_rights_screen.dart';
import 'terms_of_service_screen.dart';

/// المساعدة والدعم مع قنوات التواصل.
class SupportHelpScreen extends StatelessWidget {
  const SupportHelpScreen({super.key});

  Future<void> _launchUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('المساعدة والدعم', 'Help & Support')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      'نحن هنا لمساعدتك',
                      'We are here to help',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF4F7FB),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'للاستفسارات التقنية، الحسابات، أو مشاكل الطلبات — تواصل معنا عبر القنوات أدناه.',
                      'For technical questions, accounts, or order issues — reach us through the channels below.',
                    ),
                    style: TextStyle(height: 1.5, color: const Color(0xFFB7C3D6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.t('البريد الإلكتروني', 'Email'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8EAF6),
                child: Icon(Icons.email_outlined, color: Color(0xFF1A237E)),
              ),
              title: Text(context.t('دعم AcadeGate', 'AcadeGate support')),
              subtitle: const Text(AppContactInfo.supportEmail),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _launchUri(
                Uri(
                  scheme: 'mailto',
                  path: AppContactInfo.supportEmail,
                  queryParameters: {
                    'subject': isAr
                        ? 'طلب دعم — AcadeGate'
                        : 'Support request — AcadeGate',
                  },
                ),
              ),
            ),
          ),
          if (AppContactInfo.phoneLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...AppContactInfo.phoneLines.map((line) {
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8EAF6),
                    child: Icon(Icons.phone_outlined, color: Color(0xFF1A237E)),
                  ),
                  title: Text(line.label(isAr)),
                  subtitle: Text(line.display(isAr)),
                  trailing: IconButton(
                    tooltip: context.t('اتصال', 'Call'),
                    icon: const Icon(Icons.call, color: Color(0xFF86EFAC)),
                    onPressed: () =>
                        _launchUri(Uri(scheme: 'tel', path: line.e164)),
                  ),
                  onLongPress: () async {
                    await Clipboard.setData(
                      ClipboardData(text: line.display(isAr)),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.t('تم نسخ الرقم', 'Number copied'),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          Text(
            context.t('الخصوصية والشروط', 'Privacy & terms'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8EAF6),
                child: Icon(Icons.manage_accounts_outlined, color: const Color(0xFFF4F7FB)),
              ),
              title: Text(context.t('حقوق الخصوصية', 'Privacy rights')),
              subtitle: Text(
                context.t(
                  'اطلاع · تصحيح · حذف بيانات',
                  'Access · correct · erase data',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyRightsScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8EAF6),
                child: Icon(Icons.privacy_tip_outlined, color: const Color(0xFFF4F7FB)),
              ),
              title: Text(context.t('سياسة الخصوصية', 'Privacy Policy')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8EAF6),
                child: Icon(Icons.gavel_outlined, color: const Color(0xFFF4F7FB)),
              ),
              title: Text(context.t('شروط الاستخدام', 'Terms of Service')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.t(
              'ساعات الرد التقريبية: يومياً 10 ص — 6 م (توقيت مصر)، عدا العطل الرسمية.',
              'Typical reply hours: daily 10:00–18:00 (Egypt time), excluding public holidays.',
            ),
            style: TextStyle(fontSize: 13, color: const Color(0xFFB7C3D6), height: 1.4),
          ),
        ],
      ),
    );
  }
}
