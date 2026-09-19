import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../moderation/approval_status.dart';
import '../moderation/moderation_service.dart';
import '../supervisor_import/admin_supervisor_import_screen.dart';
import 'admin_access_gate.dart';
import 'admin_activity_service.dart';
import 'admin_bugs_screen.dart';
import 'admin_kpi_screen.dart';
import 'admin_privacy_ops_screen.dart';
import 'admin_profile_claims_screen.dart';

class AdminModerationScreen extends StatefulWidget {
  final String initialFilter;

  const AdminModerationScreen({super.key, this.initialFilter = 'all'});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late String _filter;

  late final Stream<List<PendingItem>> _pendingStream;
  late final Stream<ModerationStats> _statsStream;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _tabController = TabController(length: 4, vsync: this);
    _pendingStream = ModerationService.instance.watchPendingItems();
    _statsStream = ModerationService.instance.watchStats(
      pendingStream: _pendingStream,
      usersStream: UserAccountService.instance.watchUsersRaw(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<PendingItem> _applyFilter(List<PendingItem> items) {
    if (_filter == 'all') return items;
    return items.where((item) => item.collection == _filter).toList();
  }

  Future<void> _approve(PendingItem item) async {
    await ModerationService.instance.approve(item.collection, item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10nLookup.approvedSnack),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reject(PendingItem item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(context.t('رفض المحتوى', 'Reject content')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: context.t(
                'سبب الرفض (اختياري)',
                'Rejection reason (optional)',
              ),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L10nLookup.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(L10nLookup.reject),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    await ModerationService.instance.reject(
      item.collection,
      item.id,
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10nLookup.rejectedSnack),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openDetails(PendingItem item) {
    final fields = ModerationService.instance.detailFields(item);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          ModerationService.instance
                              .collectionLabel(item.collection),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        ApprovalStatus.label(ApprovalStatus.pending),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        ...fields.map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  field.value.isEmpty ? '—' : field.value,
                                  style: const TextStyle(height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (item.ownerId.isNotEmpty)
                          Text(
                            L10nLookup.ownerIdLabel(item.ownerId),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _reject(item);
                          },
                          child: Text(L10nLookup.reject),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _approve(item);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(L10nLookup.approve),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      child: Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('لوحة الإدارة', 'Admin dashboard')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminBugsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bug_report, color: Colors.white),
            label: Text(
              context.t('المشاكل', 'Bugs'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminKpiScreen(),
                ),
              );
            },
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            label: Text(
              context.t('مؤشرات الأداء', 'KPIs'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            tooltip: context.t('مطالبات الملفات', 'Profile claims'),
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminProfileClaimsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: context.t('خصوصية وبلاغات', 'Privacy & reports'),
            icon: const Icon(Icons.privacy_tip_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminPrivacyOpsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: context.t('استيراد مشرفين', 'Import supervisors'),
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSupervisorImportScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: context.t('المراجعة', 'Review'),
              icon: const Icon(Icons.fact_check_outlined),
            ),
            Tab(
              text: context.t('النشاط', 'Activity'),
              icon: const Icon(Icons.timeline_outlined),
            ),
            Tab(
              text: context.t('إحصائيات', 'Statistics'),
              icon: const Icon(Icons.insights_outlined),
            ),
            Tab(
              text: context.t('المستخدمون', 'Users'),
              icon: const Icon(Icons.people_outline),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModerationTab(),
          _buildActivityTab(),
          _buildStatsTab(),
          _buildUsersTab(),
        ],
      ),
      ),
    );
  }

  Widget _buildModerationTab() {
    return StreamBuilder<List<PendingItem>>(
      stream: _pendingStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('${L10nLookup.error}: ${snapshot.error}'),
          );
        }

        final allItems = snapshot.data ?? [];
        final items = _applyFilter(allItems);

        return Column(
          children: [
            Material(
              color: const Color(0xFFB71C1C),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminBugsScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bug_report, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.t(
                            'سجل المشاكل والأخطاء — بلاغات المستخدمين ومقدمي الخدمة',
                            'Bugs & errors — user and provider reports',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_left, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: const Color(0xFF4527A0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminKpiScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.t(
                            'مؤشرات الأداء الأسبوعية — اضغط للفتح',
                            'Weekly KPIs — tap to open',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_left, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  _filterChip(
                    'all',
                    '${L10nLookup.all} (${allItems.length})',
                  ),
                  _filterChip(
                    'provider_applications',
                    L10nLookup.filterChipLabel(
                      'provider_applications',
                      allItems
                          .where((i) => i.collection == 'provider_applications')
                          .length,
                    ),
                  ),
                  _filterChip(
                    'supervisors',
                    L10nLookup.filterChipLabel(
                      'supervisors',
                      allItems
                          .where((i) => i.collection == 'supervisors')
                          .length,
                    ),
                  ),
                  _filterChip(
                    'labs',
                    L10nLookup.filterChipLabel(
                      'labs',
                      allItems.where((i) => i.collection == 'labs').length,
                    ),
                  ),
                  _filterChip(
                    'product',
                    L10nLookup.filterChipLabel(
                      'product',
                      allItems.where((i) => i.collection == 'product').length,
                    ),
                  ),
                  _filterChip(
                    'writing_services',
                    L10nLookup.filterChipLabel(
                      'writing_services',
                      allItems
                          .where((i) => i.collection == 'writing_services')
                          .length,
                    ),
                  ),
                  _filterChip(
                    'research_ideas',
                    L10nLookup.filterChipLabel(
                      'research_ideas',
                      allItems
                          .where((i) => i.collection == 'research_ideas')
                          .length,
                    ),
                  ),
                  _filterChip(
                    'community_posts',
                    L10nLookup.filterChipLabel(
                      'community_posts',
                      allItems
                          .where((i) => i.collection == 'community_posts')
                          .length,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        context.t(
                          'لا يوجد محتوى بانتظار المراجعة',
                          'No content pending review',
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          child: InkWell(
                            onTap: () => _openDetails(item),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Chip(
                                        label: Text(
                                          ModerationService.instance
                                              .collectionLabel(item.collection),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.live_tv,
                                          size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        ApprovalStatus.label(
                                          ApprovalStatus.pending,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(item.subtitle),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _openDetails(item),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                        label: Text(L10nLookup.details),
                                      ),
                                      const Spacer(),
                                      OutlinedButton(
                                        onPressed: () => _reject(item),
                                        child: Text(L10nLookup.reject),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _approve(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text(L10nLookup.approve),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _buildActivityTab() {
    final isAr = Localizations.localeOf(context).languageCode != 'en';
    return StreamBuilder<List<AdminActivityEvent>>(
      stream: AdminActivityService.instance.watchRecent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.t(
                  'تعذّر تحميل سجل النشاط. إن ظهرت مشكلة صلاحيات انشر قواعد Firestore.',
                  'Could not load the activity feed. If this is a permissions error, deploy Firestore rules.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final events = snapshot.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t(
                        'سجل الدخول والحركات (${events.length})',
                        'Login & activity log (${events.length})',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: events.isEmpty ? null : _clearOldActivity,
                    icon: const Icon(Icons.history_toggle_off, size: 18),
                    label: Text(
                      context.t('أقدم من 30 يوماً', 'Older than 30 days'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    onPressed: events.isEmpty ? null : _clearAllActivity,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: Text(context.t('مسح الكل', 'Clear all')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        context.t(
                          'لا يوجد نشاط بعد. سيظهر هنا كل دخول وتسجيل وتبديل بوابة وحركة مهمة.',
                          'No activity yet. Logins, registrations, portal switches, and key actions will appear here.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final e = events[index];
                        final color = _activityColor(e.type);
                        final when = e.createdAt;
                        final whenLabel = when == null
                            ? '—'
                            : '${when.year}/${when.month.toString().padLeft(2, '0')}/${when.day.toString().padLeft(2, '0')} '
                                '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: color.withValues(alpha: 0.25),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              child: Icon(
                                _activityIcon(e.type),
                                color: color,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              e.title(isAr: isAr),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (e.displayName.isNotEmpty) e.displayName,
                                if (e.email.isNotEmpty) e.email,
                                if (e.detail.isNotEmpty) e.detail,
                                if (e.role.isNotEmpty) e.role,
                                e.platform,
                                whenLabel,
                              ]
                                  .where((s) => s.trim().isNotEmpty)
                                  .join(' · '),
                              style: TextStyle(
                                height: 1.35,
                                color: Colors.grey[700],
                              ),
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: context.t('حذف', 'Delete'),
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red[700],
                              ),
                              onPressed: () => _deleteActivityEvent(e),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteActivityEvent(AdminActivityEvent event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('حذف هذا السجل؟', 'Delete this entry?')),
        content: Text(
          context.t(
            'سيُحذف سجل النشاط فقط ولن يؤثر على حساب المستخدم.',
            'Only this activity entry will be removed; the user account is unaffected.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AdminActivityService.instance.deleteEvent(event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم الحذف', 'Deleted')),
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
    }
  }

  Future<void> _clearOldActivity() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('حذف السجلات القديمة؟', 'Delete old entries?'),
        ),
        content: Text(
          context.t(
            'سيُحذف كل نشاط أقدم من 30 يوماً.',
            'All activity older than 30 days will be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final n =
          await AdminActivityService.instance.deleteOlderThan(cutoff);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم حذف $n سجلاً', 'Deleted $n entries'),
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
    }
  }

  Future<void> _clearAllActivity() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('مسح كل النشاط؟', 'Clear all activity?')),
        content: Text(
          context.t(
            'سيُحذف سجل النشاط بالكامل. هذا لا يحذف المستخدمين أو المحتوى.',
            'The entire activity log will be deleted. Users and content are not affected.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('مسح الكل', 'Clear all')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final n = await AdminActivityService.instance.clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم حذف $n سجلاً', 'Deleted $n entries'),
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
    }
  }

  IconData _activityIcon(String type) {
    return switch (type) {
      AdminActivityService.login => Icons.login,
      AdminActivityService.register => Icons.person_add_alt_1,
      AdminActivityService.logout => Icons.logout,
      AdminActivityService.roleSetup => Icons.badge_outlined,
      AdminActivityService.portalSwitch => Icons.swap_horiz,
      AdminActivityService.providerApplication => Icons.storefront_outlined,
      AdminActivityService.contentSubmit => Icons.upload_file_outlined,
      AdminActivityService.contentDecision => Icons.gavel_outlined,
      AdminActivityService.profileClaim => Icons.verified_user_outlined,
      _ => Icons.timeline,
    };
  }

  Color _activityColor(String type) {
    return switch (type) {
      AdminActivityService.login => const Color(0xFF1565C0),
      AdminActivityService.register => const Color(0xFF2E7D32),
      AdminActivityService.logout => const Color(0xFF6A1B9A),
      AdminActivityService.roleSetup => const Color(0xFF00695C),
      AdminActivityService.portalSwitch => const Color(0xFFEF6C00),
      AdminActivityService.providerApplication => const Color(0xFF2E7D32),
      AdminActivityService.contentSubmit => const Color(0xFF4527A0),
      AdminActivityService.contentDecision => const Color(0xFFC62828),
      AdminActivityService.profileClaim => const Color(0xFF00838F),
      _ => const Color(0xFF546E7A),
    };
  }

  Widget _buildStatsTab() {
    return StreamBuilder<ModerationStats>(
      stream: _statsStream,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const ModerationStats();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFF4527A0),
              child: ListTile(
                leading: const Icon(Icons.analytics_outlined, color: Colors.white),
                title: Text(
                  context.t('مؤشرات الأداء الأسبوعية', 'Weekly KPIs'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  context.t(
                    'مستخدمون · بحث · مطالبات · تواصل · احتفاظ · شركاء · CAC',
                    'Users · search · claims · contacts · retention · partners · CAC',
                  ),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(Icons.chevron_left, color: Colors.white),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminKpiScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _statCard(
              L10nLookup.approvalStatusLabel('pending'),
              '${stats.totalPending}',
              Icons.pending_actions,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _miniStat(
                  L10nLookup.collectionLabelPlural('provider_applications'),
                  stats.pendingProviderApplications,
                  const Color(0xFF2E7D32),
                ),
                _miniStat(
                  L10nLookup.supervisorsPlural,
                  stats.pendingSupervisors,
                  Colors.blue,
                ),
                _miniStat(L10nLookup.labsPlural, stats.pendingLabs, Colors.purple),
                _miniStat(L10nLookup.products, stats.pendingProducts, Colors.green),
                _miniStat(L10nLookup.ideas, stats.pendingIdeas, Colors.orange),
                _miniStat(
                  L10nLookup.community,
                  stats.pendingCommunityPosts,
                  const Color(0xFF00695C),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _statCard(
              context.t('إجمالي المستخدمين', 'Total users'),
              '${stats.totalUsers}',
              Icons.people,
              const Color(0xFF1A237E),
            ),
            const SizedBox(height: 16),
            Text(
              context.t('المستخدمون حسب الدور', 'Users by role'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...stats.usersByRole.entries.map(
              (entry) => Card(
                child: ListTile(
                  title: Text(UserRole.label(entry.key)),
                  trailing: Chip(label: Text('${entry.value}')),
                ),
              ),
            ),
            if (stats.usersByRole.isEmpty)
              Text(
                context.t(
                  'لا توجد بيانات مستخدمين بعد',
                  'No user data yet',
                ),
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color.withValues(alpha: 0.9)),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.sync, size: 16, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              L10nLookup.live,
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text('$value', style: TextStyle(color: color, fontSize: 12)),
      ),
      label: Text(label),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<List<UserAccount>>(
      stream: UserAccountService.instance.watchAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text(context.t('لا يوجد مستخدمون', 'No users')),
          );
        }

        final emailCounts = <String, int>{};
        for (final u in users) {
          final e = u.email.trim().toLowerCase();
          if (e.isEmpty) continue;
          emailCounts[e] = (emailCounts[e] ?? 0) + 1;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t(
                        'إن ظهر نفس الإيميل مرتين فغالباً ملف قديم يتيم بعد الحذف وإعادة التسجيل.',
                        'If the same email appears twice, it is usually an orphan profile after delete + re-register.',
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _cleanupOrphanUsers,
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: Text(context.t('تنظيف اليتيمة', 'Clean orphans')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final emailKey = user.email.trim().toLowerCase();
                  final isDuplicate =
                      emailKey.isNotEmpty && (emailCounts[emailKey] ?? 0) > 1;
                  return Card(
                    color: isDuplicate ? const Color(0xFFFFF8E1) : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0]
                              : '?',
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName
                                  : user.email,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isDuplicate)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Chip(
                                label: Text(
                                  context.t('مكرر', 'Duplicate'),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: Colors.orange.shade100,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${user.email}\n'
                        '${L10nLookup.currentRoleLabel(UserRole.label(user.role))}'
                        ' · ${user.isProActive ? 'Pro' : 'Free'}'
                        '${isDuplicate ? context.t(' · ملف مكرر لنفس البريد', ' · duplicate email profile') : ''}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        tooltip: context.t('إدارة المستخدم', 'Manage user'),
                        onSelected: (value) async {
                          if (value == '__quota__') {
                            await _editSubscriptionAndQuota(context, user);
                            return;
                          }
                          if (value == '__delete__') {
                            await _confirmDeleteUser(context, user);
                            return;
                          }
                          try {
                            await UserAccountService.instance.updateUserRole(
                              uid: user.uid,
                              role: value,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  L10nLookup.roleUpdated(user.displayName),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          ...UserRole.all.map(
                            (role) => PopupMenuItem(
                              value: role,
                              child: Text(UserRole.label(role)),
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: '__quota__',
                            child: Text(
                              context.t(
                                'الاشتراك والحدود',
                                'Plan & quotas',
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: '__delete__',
                            child: Text(
                              context.t(
                                'حذف من التطبيق',
                                'Remove from app',
                              ),
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cleanupOrphanUsers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('تنظيف الحسابات اليتيمة؟', 'Clean orphan profiles?'),
        ),
        content: Text(
          context.t(
            'سيُحذف أي ملف مستخدم في Firestore لم يعد له حساب في Authentication '
            '(مثل الصفوف المكررة بعد الحذف وإعادة التسجيل بنفس الإيميل).',
            'Removes Firestore user profiles that no longer have an Authentication '
            'account (e.g. duplicate rows after delete + re-register with the same email).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('تنظيف', 'Clean up')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result =
          await UserAccountService.instance.cleanupOrphanUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم حذف ${result.orphansRemoved} ملفاً يتيماً',
              'Removed ${result.orphansRemoved} orphan profile(s)',
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
    }
  }

  Future<void> _confirmDeleteUser(
    BuildContext context,
    UserAccount user,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('حذف المستخدم؟', 'Delete user?')),
        content: Text(
          context.t(
            'سيُحذف ملف «${user.displayName}» من التطبيق وحساب تسجيل الدخول، '
            'وتُحرَّر ملكية المختبرات/الموردين/المشرفين المرتبطة به حتى يمكنه '
            'التسجيل بنفس البريد والمطالبة من جديد للمراجعة.',
            'This removes «${user.displayName}» from the app and Firebase login, '
            'and releases linked labs/suppliers/supervisors so the same email '
            'can register again and claim for review.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10nLookup.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await UserAccountService.instance.deleteUserProfile(uid: user.uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم حذف المستخدم من التطبيق ومن Firebase Auth. يمكنه التسجيل من جديد بنفس البريد كحساب جديد.',
              'User removed from the app and Firebase Auth. They can register again with the same email as a new account.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editSubscriptionAndQuota(
    BuildContext context,
    UserAccount user,
  ) async {
    var tier = user.isProActive
        ? SubscriptionTier.pro
        : SubscriptionTier.normalize(user.subscription);
    var days = 30;
    final geminiCtrl = TextEditingController(
      text: user.quotaGeminiDaily?.toString() ?? '',
    );
    final scholarCtrl = TextEditingController(
      text: user.quotaScholarDaily?.toString() ?? '',
    );
    var clearOverrides = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(
                context.t('اشتراك والحدود', 'Subscription & limits'),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tier,
                        decoration: InputDecoration(
                          labelText: context.t('الباقة', 'Plan'),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SubscriptionTier.free,
                            child: Text('Free'),
                          ),
                          DropdownMenuItem(
                            value: SubscriptionTier.pro,
                            child: Text('Pro'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => tier = v);
                        },
                      ),
                      if (tier == SubscriptionTier.pro) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: days,
                          decoration: InputDecoration(
                            labelText: context.t('المدة', 'Duration'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 30,
                              child: Text(
                                context.t('30 يوماً', '30 days'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 90,
                              child: Text(
                                context.t('90 يوماً', '90 days'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 0,
                              child: Text(
                                context.t('بدون انتهاء', 'No expiry'),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() => days = v);
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        context.t(
                          'حدود يومية مخصصة (اتركها فارغة لاستخدام افتراضي الباقة)',
                          'Custom daily limits (leave empty for plan defaults)',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: geminiCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.t(
                            'حد AI يومي',
                            'Daily AI limit',
                          ),
                          hintText: tier == SubscriptionTier.pro ? '100' : '20',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: scholarCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.t(
                            'حد Scholar يومي',
                            'Daily Scholar limit',
                          ),
                          hintText: tier == SubscriptionTier.pro ? '30' : '6',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: clearOverrides,
                        onChanged: (v) =>
                            setLocal(() => clearOverrides = v ?? false),
                        title: Text(
                          context.t(
                            'مسح الحدود المخصصة',
                            'Clear custom limits',
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(L10nLookup.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(L10nLookup.save),
                ),
              ],
            );
          },
        );
      },
    );

    final geminiText = geminiCtrl.text.trim();
    final scholarText = scholarCtrl.text.trim();
    geminiCtrl.dispose();
    scholarCtrl.dispose();

    if (saved != true || !context.mounted) return;

    try {
      final gemini = int.tryParse(geminiText);
      final scholar = int.tryParse(scholarText);
      await UserAccountService.instance.updateUserSubscription(
        uid: user.uid,
        subscription: tier,
        clearExpiry: tier == SubscriptionTier.free || days == 0,
        expiresAt: tier == SubscriptionTier.pro && days > 0
            ? DateTime.now().add(Duration(days: days))
            : null,
        clearQuotaOverrides: clearOverrides,
        quotaGeminiDaily: clearOverrides ? null : gemini,
        quotaScholarDaily: clearOverrides ? null : scholar,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم تحديث اشتراك وحدود ${user.displayName}',
              'Updated plan & limits for ${user.displayName}',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
