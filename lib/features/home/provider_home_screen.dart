import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:acadegate/core/widgets/app_site_footer.dart';
import '../../core/config/feature_flags.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/auth_navigation.dart';
import '../auth/language_switcher_button.dart';
import '../auth/login_screen.dart';
import '../auth/portal_switch_button.dart';
import '../auth/provider_publish_gate.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../moderation/approval_status.dart';
import '../admin/admin_bugs_screen.dart';
import '../admin/admin_kpi_screen.dart';
import '../admin/admin_moderation_screen.dart';
import '../admin/admin_unowned_lab_ops_screen.dart';
import '../bugs/report_problem_sheet.dart';
import '../academic_writing/expert_orders_screen.dart';
import '../contributor/contributor_hub_screen.dart';
import '../contributor/submit_lab_screen.dart';
import '../contributor/submit_supervisor_screen.dart';
import '../messaging/conversations_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/account_app_bar_avatar.dart';
import '../research_fund/industry_challenges_screen.dart';
import '../research_fund/my_funded_ideas_screen.dart';
import '../research_marketplace/publish_research_idea_screen.dart';
import '../store/merchant_store_screen.dart';
import '../analysis_labs/sample_requests_screens.dart';
import '../smart_labs/incoming_lab_bookings_screen.dart';
import '../supervision/supervision_requests_screen.dart';
import '../supervisor_dashboard/supervisor_workload_screen.dart';

/// بوابة مقدمي الخدمات: تاجر، مختبر، كاتب، ناشر أفكار، مشرف.
class ProviderHomeScreen extends StatelessWidget {
  final VoidCallback? onSwitchPortal;

  const ProviderHomeScreen({super.key, this.onSwitchPortal});

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = context.l10n;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await AuthNavigation.signOutToWelcome(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(l10n.providerPortalTitle),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const LanguageSwitcherButton(),
          if (onSwitchPortal != null)
            PortalSwitchButton(
              onSwitchPortal: onSwitchPortal!,
              tooltip: l10n.switchToUserPortal,
            ),
          if (isLoggedIn) const ReportProblemIconButton(portal: 'provider'),
          StreamBuilder<UserAccount?>(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snap) {
              if (snap.data?.isAdmin != true) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: context.t('سجل المشاكل', 'Bugs'),
                    icon: const Icon(Icons.bug_report),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminBugsScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: context.t('مؤشرات الأداء', 'Weekly KPIs'),
                    icon: const Icon(Icons.insights_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminKpiScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const NotificationIconButton(),
          IconButton(
            tooltip: l10n.messages,
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
          if (isLoggedIn) ...[
            const AccountAppBarAvatar(),
            IconButton(
              tooltip: l10n.logout,
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context),
            ),
          ],
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
              label: Text(l10n.contributorHub),
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
    final l10n = context.l10n;
    final role = account.role;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(account: account),
        if (ProviderPublishGate.isProviderRole(account.role) &&
            !ProviderPublishGate.isApproved(account)) ...[
          const SizedBox(height: 12),
          _ProviderApprovalBanner(account: account),
        ],
        const SizedBox(height: 20),
        _sectionTitle(context.t('التواصل', 'Messaging')),
        _tile(
          context,
          icon: Icons.chat_outlined,
          title: l10n.messages,
          subtitle: context.t(
            'الرد على رسائل المشترين والباحثين',
            'Reply to buyers and researchers',
          ),
          color: const Color(0xFF2E7D32),
          screen: const ConversationsScreen(),
        ),
        const SizedBox(height: 20),
        if (account.isAdmin) ...[
          _sectionTitle(l10n.sectionSystemAdmin),
          _tile(
            context,
            icon: Icons.admin_panel_settings_outlined,
            title: l10n.contentModeration,
            subtitle: l10n.contentModerationSub,
            color: const Color(0xFF1A237E),
            screen: const AdminModerationScreen(initialFilter: 'supervisors'),
          ),
          _tile(
            context,
            icon: Icons.insights_outlined,
            title: context.t('مؤشرات الأداء الأسبوعية', 'Weekly KPIs'),
            subtitle: context.t(
              'مستخدمون · بحث · مطالبات · تواصل · احتفاظ · شركاء · CAC',
              'Users · search · claims · contacts · retention · partners · CAC',
            ),
            color: const Color(0xFF4527A0),
            screen: const AdminKpiScreen(),
          ),
          _tile(
            context,
            icon: Icons.bug_report_outlined,
            title: context.t('سجل المشاكل والأخطاء', 'Bugs & errors log'),
            subtitle: context.t(
              'بلاغات المستخدمين ومقدمي الخدمة + أخطاء تلقائية',
              'User/provider reports + automatic crashes',
            ),
            color: const Color(0xFFB71C1C),
            screen: const AdminBugsScreen(),
          ),
          _tile(
            context,
            icon: Icons.hub_outlined,
            title: context.t(
              'عمليات المختبرات غير المربوطة',
              'Unowned lab operations',
            ),
            subtitle: context.t(
              'حجوزات وطلبات تحليل من مختبرات NBSLE بدون مالك',
              'Bookings & sample requests from unowned NBSLE labs',
            ),
            color: const Color(0xFF00695C),
            screen: const AdminUnownedLabOpsScreen(),
          ),
          const SizedBox(height: 20),
        ],
        if (_hasIncoming(role)) ...[
          _sectionTitle(l10n.sectionIncomingOrders),
          if (_showWriting(role))
            _tile(
              context,
              icon: Icons.receipt_long,
              title: l10n.writingOrdersIncoming,
              subtitle: l10n.writingOrdersIncomingSub,
              color: const Color(0xFF6A1B9A),
              screen: const ExpertOrdersScreen(),
            ),
          if (_showLabIncoming(role)) ...[
            _tile(
              context,
              icon: Icons.science_outlined,
              title: l10n.sampleAnalysisIncoming,
              subtitle: l10n.sampleAnalysisIncomingSub,
              color: const Color(0xFF00695C),
              screen: const IncomingSampleAnalysisRequestsScreen(),
            ),
            _tile(
              context,
              icon: Icons.event_available_outlined,
              title: context.t(
                'حجوزات الأجهزة الواردة',
                'Incoming equipment bookings',
              ),
              subtitle: context.t(
                'حجوزات الباحثين على مختبراتك',
                'Researcher bookings on your labs',
              ),
              color: const Color(0xFF00897B),
              screen: const IncomingLabBookingsScreen(),
            ),
          ],
          if (_showSupervisionIncoming(role)) ...[
            _tile(
              context,
              icon: Icons.dashboard_outlined,
              title: context.t('لوحة المشرف', 'Supervisor dashboard'),
              subtitle: context.t(
                'الطلاب، الطلبات، ومؤشر الحمل',
                'Students, requests & workload',
              ),
              color: const Color(0xFF1565C0),
              screen: const SupervisorWorkloadScreen(),
            ),
            _tile(
              context,
              icon: Icons.school_outlined,
              title: l10n.supervisionIncoming,
              subtitle: l10n.supervisionIncomingSub,
              color: const Color(0xFF1565C0),
              screen: const IncomingSupervisionRequestsScreen(),
            ),
          ],
          if (_showProduct(role))
            _tile(
              context,
              icon: Icons.shopping_bag_outlined,
              title: context.t('طلبات الشراء الواردة', 'Incoming store orders'),
              subtitle: context.t(
                'طلبات المشترين على منتجاتك',
                'Buyer orders on your products',
              ),
              color: const Color(0xFFE65100),
              screen: const MerchantStoreScreen(),
            ),
          if (_showProduct(role) && AcadeGateFeatureFlags.showResearchFundOnHome)
            _tile(
              context,
              icon: Icons.factory_outlined,
              title: context.t(
                'تحديات الصناعة بعربون',
                'Industry challenges (escrow)',
              ),
              subtitle: context.t(
                'انشر مشكلة صناعية واحبس العربون قبل أي بروتوكول',
                'Post an industry problem and hold the deposit before any protocol',
              ),
              color: const Color(0xFFBF360C),
              screen: const IndustryChallengesScreen(),
            ),
          const SizedBox(height: 20),
        ],
        if (_hasPublish(role)) ...[
          _sectionTitle(l10n.sectionPublishContent),
          if (_showProduct(role))
            _tile(
              context,
              icon: Icons.storefront_outlined,
              title: context.t('متجري', 'My store'),
              subtitle: context.t(
                'منتجاتك، إضافة المزيد، وطلبات الشراء',
                'Your products, add more, and purchase orders',
              ),
              color: const Color(0xFFE65100),
              screen: const MerchantStoreScreen(),
            ),
          if (_showLabSubmit(role))
            _tile(
              context,
              icon: Icons.biotech,
              title: l10n.registerLab,
              subtitle: l10n.registerLabSub,
              color: const Color(0xFF00695C),
              screen: const SubmitLabScreen(),
            ),
          if (_showSupervisorSubmit(role))
            _tile(
              context,
              icon: Icons.person_add_alt_1,
              title: l10n.registerSupervisor,
              subtitle: l10n.registerSupervisorSub,
              color: const Color(0xFF1565C0),
              screen: const SubmitSupervisorScreen(),
            ),
          if (_showIdea(role)) ...[
            _tile(
              context,
              icon: Icons.lightbulb_outline,
              title: l10n.publishIdea,
              subtitle: l10n.publishIdeaSub,
              color: const Color(0xFFF57F17),
              screen: const PublishResearchIdeaScreen(),
            ),
            if (AcadeGateFeatureFlags.showResearchFundOnHome)
              _tile(
                context,
                icon: Icons.savings_outlined,
                title: context.t('أفكاري الممولة', 'My funded ideas'),
                subtitle: context.t(
                  'تمويلات أفكارك من صندوق البحث',
                  'Awards for your ideas from the research fund',
                ),
                color: const Color(0xFFBF360C),
                screen: const MyFundedIdeasScreen(),
              ),
          ],
          const SizedBox(height: 20),
        ],
        // طلبات صادرة للباحثين فقط — ليست للمورد/المختبر
        if (_showOutgoingResearcherRequests(role)) ...[
          _sectionTitle(l10n.sectionTrackOrders),
          _tile(
            context,
            icon: Icons.outgoing_mail,
            title: l10n.mySupervisionRequests,
            subtitle: l10n.mySupervisionRequestsSub,
            color: const Color(0xFF455A64),
            screen: const MySupervisionRequestsScreen(),
          ),
          _tile(
            context,
            icon: Icons.biotech_outlined,
            title: l10n.mySampleRequests,
            subtitle: l10n.mySampleRequestsSub,
            color: const Color(0xFF455A64),
            screen: const MySampleAnalysisRequestsScreen(),
          ),
        ],
        const AppSiteFooter(accentColor: Color(0xFF2E7D32)),
        const SizedBox(height: 24),
      ],
    );
  }

  bool _showWriting(String role) => UserRole.canReceiveWritingOrders(role);

  bool _showLabIncoming(String role) =>
      role == UserRole.labManager || role == UserRole.admin;

  bool _showSupervisionIncoming(String role) =>
      role == UserRole.supervisor || role == UserRole.admin;

  bool _showProduct(String role) =>
      role == UserRole.merchant || role == UserRole.admin;

  bool _showLabSubmit(String role) =>
      role == UserRole.labManager || role == UserRole.admin;

  bool _showSupervisorSubmit(String role) =>
      role == UserRole.supervisor || role == UserRole.admin;

  bool _showIdea(String role) =>
      role == UserRole.ideaPublisher ||
      role == UserRole.supervisor ||
      role == UserRole.admin;

  /// إشراف وتحليل عينات = مسارات باحث، لا تظهر للمورد.
  bool _showOutgoingResearcherRequests(String role) =>
      role == UserRole.student ||
      role == UserRole.supervisor ||
      role == UserRole.admin;

  bool _hasIncoming(String role) =>
      _showWriting(role) ||
      _showLabIncoming(role) ||
      _showSupervisionIncoming(role) ||
      _showProduct(role);

  bool _hasPublish(String role) =>
      _showProduct(role) ||
      _showLabSubmit(role) ||
      _showSupervisorSubmit(role) ||
      _showIdea(role);
}

class _ProviderApprovalBanner extends StatefulWidget {
  final UserAccount account;

  const _ProviderApprovalBanner({required this.account});

  @override
  State<_ProviderApprovalBanner> createState() =>
      _ProviderApprovalBannerState();
}

class _ProviderApprovalBannerState extends State<_ProviderApprovalBanner> {
  bool _busy = false;

  Future<void> _reapply() async {
    setState(() => _busy = true);
    try {
      await UserAccountService.instance.reapplyProviderReview();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'أُعيد إرسال طلبك للمراجعة',
              'Your application was re-submitted for review',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejected = ProviderPublishGate.isRejected(widget.account);
    final color = rejected ? const Color(0xFFC62828) : const Color(0xFFEF6C00);
    final title = rejected
        ? context.t('الحساب مرفوض', 'Account rejected')
        : context.t('بانتظار موافقة الإدارة', 'Pending admin approval');
    final body = rejected
        ? context.t(
            ProviderPublishGate.blockMessageAr(widget.account),
            ProviderPublishGate.blockMessageEn(widget.account),
          )
        : context.t(
            'يمكنك تجهيز بياناتك، لكن النشر للعامة يبدأ بعد القبول. المحتوى المُرسل يبقى قيد المراجعة.',
            'You can prepare your details, but public publishing starts after approval. Submitted content stays under review.',
          );

    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  rejected ? Icons.block : Icons.hourglass_top,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    ApprovalStatus.label(
                      rejected
                          ? ApprovalStatus.rejected
                          : ApprovalStatus.pending,
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(height: 1.4, color: Colors.grey[800])),
            if (rejected) ...[
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: _busy ? null : _reapply,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        context.t('إعادة تقديم الطلب', 'Re-apply for review'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuestProviderBody extends StatelessWidget {
  final VoidCallback? onSwitchPortal;

  const _GuestProviderBody({this.onSwitchPortal});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF2E7D32),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  l10n.guestBrowsing,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.guestProviderHint,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(l10n.afterRegisterTitle),
        _tile(
          context,
          icon: Icons.storefront_outlined,
          title: l10n.sellProducts,
          subtitle: l10n.sellProductsSub,
          color: const Color(0xFFE65100),
          onTap: () => _promptLogin(context),
        ),
        _tile(
          context,
          icon: Icons.biotech,
          title: l10n.manageLab,
          subtitle: l10n.manageLabSub,
          color: const Color(0xFF00695C),
          onTap: () => _promptLogin(context),
        ),
        _tile(
          context,
          icon: Icons.edit_note,
          title: l10n.offerWriting,
          subtitle: l10n.offerWritingSub,
          color: const Color(0xFF6A1B9A),
          onTap: () => _promptLogin(context),
        ),
        _tile(
          context,
          icon: Icons.lightbulb_outline,
          title: l10n.publishIdeasGuest,
          subtitle: l10n.publishIdeasGuestSub,
          color: const Color(0xFFF57F17),
          onTap: () => _promptLogin(context),
        ),
        const AppSiteFooter(accentColor: Color(0xFF2E7D32)),
        const SizedBox(height: 24),
      ],
    );
  }

  void _promptLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.signInToContinue),
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserAccount account;

  const _HeaderCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
                    L10nLookup.roleLabel(l10n, account.role),
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
