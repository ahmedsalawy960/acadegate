import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/portal_switch_button.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../auth/welcome_screen.dart';
import '../admin/admin_moderation_screen.dart';
import '../academic_writing/expert_orders_screen.dart';
import '../contributor/contributor_hub_screen.dart';
import '../contributor/submit_lab_screen.dart';
import '../contributor/submit_supervisor_screen.dart';
import '../messaging/conversations_screen.dart';
import '../notifications/notifications_screen.dart';
import '../research_marketplace/publish_research_idea_screen.dart';
import '../store/store_categories_screen.dart';
import '../analysis_labs/sample_requests_screens.dart';
import '../supervision/supervision_requests_screen.dart';

/// بوابة مقدمي الخدمات: تاجر، مختبر، كاتب، ناشر أفكار، مشرف.
class ProviderHomeScreen extends StatelessWidget {
  final VoidCallback? onSwitchPortal;

  const ProviderHomeScreen({super.key, this.onSwitchPortal});

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بوابة مقدم الخدمة'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (onSwitchPortal != null)
            PortalSwitchButton(
              onSwitchPortal: onSwitchPortal!,
              tooltip: 'التبديل إلى بوابة المستخدم',
            ),
          const NotificationIconButton(),
          IconButton(
            tooltip: 'الرسائل',
            icon: const Icon(Icons.chat_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConversationsScreen(),
                ),
              );
            },
          ),
          if (isLoggedIn)
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context),
            ),
        ],
      ),
      body: isLoggedIn
          ? StreamBuilder<UserAccount?>(
              stream: UserAccountService.instance.watchCurrentAccount(),
              builder: (context, snapshot) {
                final account = snapshot.data;
                if (account == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _ProviderBody(account: account);
              },
            )
          : _GuestProviderBody(onSwitchPortal: onSwitchPortal),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContributorHubScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF2E7D32),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('لوحة المساهمة الكاملة'),
            )
          : null,
    );
  }
}

class _ProviderBody extends StatelessWidget {
  final UserAccount account;

  const _ProviderBody({required this.account});

  @override
  Widget build(BuildContext context) {
    final role = account.role;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(account: account),
        const SizedBox(height: 20),
        if (account.isAdmin) ...[
          _sectionTitle('إدارة النظام'),
          _tile(
            context,
            icon: Icons.admin_panel_settings_outlined,
            title: 'مراجعة المحتوى',
            subtitle: 'موافقة / رفض المشرفين والمختبرات والمنتجات',
            color: const Color(0xFF1A237E),
            screen: const AdminModerationScreen(initialFilter: 'supervisors'),
          ),
          const SizedBox(height: 20),
        ],
        _sectionTitle('إدارة الطلبات الواردة'),
        if (_showWriting(role))
          _tile(
            context,
            icon: Icons.receipt_long,
            title: 'طلبات الكتابة الواردة',
            subtitle: 'قبول ورفض وتسليم طلبات العملاء',
            color: const Color(0xFF6A1B9A),
            screen: const ExpertOrdersScreen(),
          ),
        if (_showLabIncoming(role))
          _tile(
            context,
            icon: Icons.science_outlined,
            title: 'طلبات تحليل العينات',
            subtitle: 'عينات يرسلها الباحثون لمختبرك',
            color: const Color(0xFF00695C),
            screen: const IncomingSampleAnalysisRequestsScreen(),
          ),
        if (_showSupervisionIncoming(role))
          _tile(
            context,
            icon: Icons.school_outlined,
            title: 'طلبات الإشراف الواردة',
            subtitle: 'رسائل وطلبات من الطلاب',
            color: const Color(0xFF1565C0),
            screen: const IncomingSupervisionRequestsScreen(),
          ),
        const SizedBox(height: 20),
        _sectionTitle('إضافة ونشر محتواك'),
        if (_showProduct(role))
          _tile(
            context,
            icon: Icons.storefront_outlined,
            title: 'إضافة منتج للمتجر',
            subtitle: 'اختر القسم ثم أضف منتجك',
            color: const Color(0xFFE65100),
            screen: const StoreCategoriesScreen(),
          ),
        if (_showLabSubmit(role))
          _tile(
            context,
            icon: Icons.biotech,
            title: 'تسجيل مختبر',
            subtitle: 'أضف مختبرك وأجهزته للمراجعة',
            color: const Color(0xFF00695C),
            screen: const SubmitLabScreen(),
          ),
        if (_showSupervisorSubmit(role))
          _tile(
            context,
            icon: Icons.person_add_alt_1,
            title: 'تسجيل ملف مشرف',
            subtitle: 'يُرسل للمراجعة قبل الظهور',
            color: const Color(0xFF1565C0),
            screen: const SubmitSupervisorScreen(),
          ),
        if (_showIdea(role))
          _tile(
            context,
            icon: Icons.lightbulb_outline,
            title: 'نشر فكرة بحثية',
            subtitle: 'تُراجع قبل الظهور في السوق',
            color: const Color(0xFFF57F17),
            screen: const PublishResearchIdeaScreen(),
          ),
        const SizedBox(height: 20),
        _sectionTitle('متابعة طلباتك'),
        _tile(
          context,
          icon: Icons.outgoing_mail,
          title: 'طلباتي — إشراف وتواصل',
          subtitle: 'متابعة ما أرسلته',
          color: const Color(0xFF455A64),
          screen: const MySupervisionRequestsScreen(),
        ),
        _tile(
          context,
          icon: Icons.biotech_outlined,
          title: 'طلبات تحليلي للمختبرات',
          subtitle: 'متابعة عينات أرسلتها',
          color: const Color(0xFF455A64),
          screen: const MySampleAnalysisRequestsScreen(),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  bool _showWriting(String role) =>
      role == UserRole.admin || role == UserRole.supervisor;

  bool _showLabIncoming(String role) =>
      role == UserRole.labManager || role == UserRole.admin;

  bool _showSupervisionIncoming(String role) =>
      role == UserRole.supervisor || role == UserRole.admin;

  bool _showProduct(String role) =>
      role == UserRole.merchant || role == UserRole.admin;

  bool _showLabSubmit(String role) =>
      role == UserRole.labManager ||
      role == UserRole.admin ||
      role == UserRole.student;

  bool _showSupervisorSubmit(String role) =>
      role == UserRole.supervisor ||
      role == UserRole.admin ||
      role == UserRole.student;

  bool _showIdea(String role) =>
      role == UserRole.ideaPublisher ||
      role == UserRole.supervisor ||
      role == UserRole.admin;
}

class _GuestProviderBody extends StatelessWidget {
  final VoidCallback? onSwitchPortal;

  const _GuestProviderBody({this.onSwitchPortal});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF2E7D32),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'أنت تتصفح كضيف',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'سجّل الدخول أو أنشئ حساباً كمقدم خدمة للوصول إلى لوحة المساهمة وإدارة طلباتك.',
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('ما يمكنك فعله بعد التسجيل'),
        _tile(
          context,
          icon: Icons.storefront_outlined,
          title: 'بيع منتجات أكاديمية',
          subtitle: 'تاجر / مورد',
          color: const Color(0xFFE65100),
          onTap: () => _promptLogin(context),
        ),
        _tile(
          context,
          icon: Icons.biotech,
          title: 'إدارة مختبر وتحليل عينات',
          subtitle: 'مسؤول مختبر',
          color: const Color(0xFF00695C),
          onTap: () => _promptLogin(context),
        ),
        _tile(
          context,
          icon: Icons.edit_note,
          title: 'تقديم خدمات الكتابة الأكاديمية',
          subtitle: 'كاتب / خبير',
          color: const Color(0xFF6A1B9A),
          onTap: () => _promptLogin(context),
        ),
        _tile(
          context,
          icon: Icons.lightbulb_outline,
          title: 'نشر أفكار بحثية',
          subtitle: 'ناشر أفكار',
          color: const Color(0xFFF57F17),
          onTap: () => _promptLogin(context),
        ),
      ],
    );
  }

  void _promptLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سجّل الدخول من الشاشة الرئيسية للمتابعة'),
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserAccount account;

  const _HeaderCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2E7D32),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              child: Icon(Icons.storefront, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    UserRole.label(account.role),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );
}

Widget _tile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  Widget? screen,
  VoidCallback? onTap,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap ??
          (screen != null
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => screen),
                  )
              : null),
    ),
  );
}
