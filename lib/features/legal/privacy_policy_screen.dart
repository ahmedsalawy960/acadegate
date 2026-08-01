import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/locale_extensions.dart';

/// سياسة الخصوصية — نص مبسّط مناسب لمرحلة MVP.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('سياسة الخصوصية', 'Privacy Policy')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(
            context.t(
              'نحترم خصوصيتك ونوضّح هنا كيف نتعامل مع بياناتك داخل AcadeGate.',
              'We respect your privacy. This page explains how AcadeGate handles your data.',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          _section(
            context,
            titleAr: 'ما الذي نجمعه؟',
            titleEn: 'What we collect',
            bodyAr:
                'بيانات الحساب (الاسم، البريد، الدور)، الملف الأكاديمي إن أضفته، '
                'ومحتوى التفاعل داخل المنصة مثل الطلبات والرسائل والمنشورات. '
                'نستخدم Firebase للمصادقة والتخزين.',
            bodyEn:
                'Account data (name, email, role), academic profile if you add one, '
                'and in-app activity such as orders, messages, and posts. '
                'We use Firebase for authentication and storage.',
            isAr: isAr,
          ),
          _section(
            context,
            titleAr: 'كيف نستخدم البيانات؟',
            titleEn: 'How we use data',
            bodyAr:
                'لتشغيل الخدمات (مطابقة، طلبات، مجتمع، مساعد AI)، وتحسين التجربة، '
                'والتواصل معك بخصوص حسابك أو الدعم. لا نبيع بياناتك الشخصية لأطراف ثالثة.',
            bodyEn:
                'To run services (matching, orders, community, AI advisor), improve the experience, '
                'and contact you about your account or support. We do not sell your personal data.',
            isAr: isAr,
          ),
          _section(
            context,
            titleAr: 'المشاركة والأمان',
            titleEn: 'Sharing and security',
            bodyAr:
                'قد تظهر بياناتك العامة (مثل ملف المشرف أو منشورات المجتمع) للمستخدمين الآخرين حسب إعدادات النشر. '
                'نطبّق قواعد أمان على Firestore ونحدّ من الوصول للعمليات الحساسة.',
            bodyEn:
                'Public content (e.g. supervisor profiles or community posts) may be visible to other users per publishing settings. '
                'We apply Firestore security rules and restrict sensitive actions.',
            isAr: isAr,
          ),
          _section(
            context,
            titleAr: 'حقوقك',
            titleEn: 'Your rights',
            bodyAr:
                'يمكنك تحديث ملفك، طلب حذف محتوى تملكه، أو التواصل معنا لحذف الحساب '
                'عبر صفحة المساعدة والدعم.',
            bodyEn:
                'You can update your profile, delete content you own, or contact us to delete your account '
                'via Help & Support.',
            isAr: isAr,
          ),
          _section(
            context,
            titleAr: 'التحديثات',
            titleEn: 'Updates',
            bodyAr:
                'قد نحدّث هذه السياسة مع تطوّر المنصة. استمرار استخدامك للتطبيق بعد التحديث يعني اطلاعك على النسخة الأحدث.',
            bodyEn:
                'We may update this policy as the platform evolves. Continued use after updates means you acknowledge the latest version.',
            isAr: isAr,
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required bool isAr,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? titleAr : titleEn,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAr ? bodyAr : bodyEn,
            style: TextStyle(
              height: 1.6,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
