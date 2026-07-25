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
    _tabController = TabController(length: 3, vsync: this);
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

  Widget _buildStatsTab() {
    return StreamBuilder<ModerationStats>(
      stream: _statsStream,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const ModerationStats();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
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

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0] : '?',
                  ),
                ),
                title: Text(
                  user.displayName.isNotEmpty ? user.displayName : user.email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${user.email}\n${L10nLookup.currentRoleLabel(UserRole.label(user.role))}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  tooltip: context.t('تغيير الدور', 'Change role'),
                  onSelected: (role) async {
                    try {
                      await UserAccountService.instance.updateUserRole(
                        uid: user.uid,
                        role: role,
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
                    PopupMenuItem(
                      value: UserRole.admin,
                      child: Text(L10nLookup.roleLabelStatic(UserRole.admin)),
                    ),
                  ],
                  child: const Icon(Icons.manage_accounts_outlined),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
