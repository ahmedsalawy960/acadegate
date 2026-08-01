import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../moderation/approval_status.dart';
import '../moderation/content_delete_service.dart';
import '../admin/admin_moderation_screen.dart';
import '../academic_writing/expert_orders_screen.dart';
import '../academic_writing/my_writing_orders_screen.dart';
import '../messaging/conversations_screen.dart';
import '../lab_import/admin_lab_import_screen.dart';
import '../analysis_labs/sample_requests_screens.dart';
import '../supervision/supervision_requests_screen.dart';
import '../research_marketplace/publish_research_idea_screen.dart';
import '../research_marketplace/admin_research_ideas_seed_screen.dart';
import '../supervisor_import/admin_supervisor_import_screen.dart';
import '../store/merchant_store_screen.dart';
import '../store/import/admin_store_import_screen.dart';
import 'submit_lab_screen.dart';
import 'submit_supervisor_screen.dart';

class ContributorHubScreen extends StatelessWidget {
  const ContributorHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('لوحة المساهمة', 'Contributor hub')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<UserAccount?>(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, snapshot) {
          final account = snapshot.data;
          if (account == null) {
            return Center(
              child: Text(
                context.t(
                  'سجّل الدخول للوصول إلى لوحة المساهمة',
                  'Sign in to access the contributor hub',
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF1A237E),
                child: ListTile(
                  leading:
                      const Icon(Icons.badge_outlined, color: Colors.white),
                  title: Text(
                    account.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    UserRole.label(account.role),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (account.isAdmin) ...[
                Card(
                  color: const Color(0xFF1A237E),
                  child: ListTile(
                    leading: const Icon(Icons.fact_check, color: Colors.white),
                    title: Text(
                      context.t(
                        'مراجعة المحتوى — موافقة / رفض',
                        'Content review — approve / reject',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      context.t(
                        'المشرفون والمختبرات والمنتجات المعلقة',
                        'Pending supervisors, labs, and products',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminModerationScreen(
                            initialFilter: 'supervisors',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              if (_canWritingIncoming(account.role))
                _actionTile(
                  context,
                  icon: Icons.receipt_long,
                  title: context.t(
                    'طلبات الكتابة الواردة',
                    'Incoming writing requests',
                  ),
                  subtitle: context.t(
                    'قبول / رفض / تسليم طلبات العملاء',
                    'Accept / reject / deliver client requests',
                  ),
                  screen: const ExpertOrdersScreen(),
                ),
              if (_canOutgoingResearcher(account.role))
                _actionTile(
                  context,
                  icon: Icons.shopping_bag_outlined,
                  title: context.t('طلباتي — كتابة', 'My requests — writing'),
                  subtitle: context.t(
                    'متابعة ودفع طلباتك',
                    'Track and pay for your requests',
                  ),
                  screen: const MyWritingOrdersScreen(),
                ),
              _actionTile(
                context,
                icon: Icons.chat_outlined,
                title: context.t('الرسائل', 'Messages'),
                subtitle: context.t(
                  'الرد على محادثات المشترين والباحثين والمشرفين',
                  'Reply to buyers, researchers, and supervisors',
                ),
                screen: const ConversationsScreen(),
              ),
              if (_canOutgoingResearcher(account.role))
                _actionTile(
                  context,
                  icon: Icons.biotech_outlined,
                  title: context.t(
                    'طلبات تحليل العينات',
                    'Sample analysis requests',
                  ),
                  subtitle: context.t(
                    'متابعة ما أرسلته للمختبرات',
                    'Track what you sent to labs',
                  ),
                  screen: const MySampleAnalysisRequestsScreen(),
                ),
              if (_canLabIncoming(account.role))
                _actionTile(
                  context,
                  icon: Icons.science_outlined,
                  title: context.t(
                    'طلبات التحليل الواردة',
                    'Incoming analysis requests',
                  ),
                  subtitle: context.t(
                    'عينات يرسلها الباحثون لمختبرك',
                    'Samples researchers send to your lab',
                  ),
                  screen: const IncomingSampleAnalysisRequestsScreen(),
                ),
              if (_canSupervisionIncoming(account.role))
                _actionTile(
                  context,
                  icon: Icons.school_outlined,
                  title: context.t(
                    'طلبات الإشراف الواردة',
                    'Incoming supervision requests',
                  ),
                  subtitle: context.t(
                    'رسائل وطلبات من الطلاب',
                    'Messages and requests from students',
                  ),
                  screen: const IncomingSupervisionRequestsScreen(),
                ),
              if (_canOutgoingResearcher(account.role))
                _actionTile(
                  context,
                  icon: Icons.outgoing_mail,
                  title: context.t(
                    'طلباتي — إشراف وتواصل',
                    'My requests — supervision & contact',
                  ),
                  subtitle: context.t(
                    'متابعة ما أرسلته للمشرفين',
                    'Track what you sent to supervisors',
                  ),
                  screen: const MySupervisionRequestsScreen(),
                ),
              Text(
                context.t('إضافة محتوى', 'Add content'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (account.isAdmin)
                _actionTile(
                  context,
                  icon: Icons.cloud_download_outlined,
                  title: context.t('استيراد مشرفين', 'Import supervisors'),
                  subtitle: context.t(
                    'CSV أو OpenAlex — للمدير أو المساهمين',
                    'CSV or OpenAlex — for admins or contributors',
                  ),
                  screen: const AdminSupervisorImportScreen(),
                ),
              if (_canPublishIdea(account.role) || account.isAdmin)
                _actionTile(
                  context,
                  icon: Icons.auto_awesome_outlined,
                  title: context.t(
                    'حزمة أفكار بحثية (90)',
                    'Research ideas pack (90)',
                  ),
                  subtitle: context.t(
                    '5 أفكار كاملة لكل كلية — تُنشر باسمك',
                    '5 full ideas per faculty — published as you',
                  ),
                  screen: const AdminResearchIdeasSeedScreen(),
                ),
              if (account.isAdmin)
                _actionTile(
                  context,
                  icon: Icons.biotech,
                  title: context.t(
                    'استيراد مختبرات ومراكز بحوث',
                    'Import labs & research centers',
                  ),
                  subtitle: context.t(
                    'CSV — أضف مختبرات حقيقية دفعة واحدة',
                    'CSV — add real labs in bulk',
                  ),
                  screen: const AdminLabImportScreen(),
                ),
              if (account.isAdmin)
                _actionTile(
                  context,
                  icon: Icons.store_mall_directory_outlined,
                  title: context.t(
                    'استيراد موردين ومنتجات المتجر',
                    'Import store suppliers & products',
                  ),
                  subtitle: context.t(
                    'Piochem · Cornell · Labtronic · Omega + دليل تواصل',
                    'Piochem · Cornell · Labtronic · Omega + contacts directory',
                  ),
                  screen: const AdminStoreImportScreen(),
                ),
              if (_canSubmitSupervisor(account.role) ||
                  account.role == UserRole.student)
                _actionTile(
                  context,
                  icon: Icons.person_add_alt_1,
                  title: context.t(
                    'تسجيل ملف مشرف',
                    'Register supervisor profile',
                  ),
                  subtitle: context.t(
                    'يُرسل للمراجعة قبل الظهور',
                    'Sent for review before publishing',
                  ),
                  screen: const SubmitSupervisorScreen(),
                ),
              if (_canSubmitLab(account.role) ||
                  account.role == UserRole.student)
                _actionTile(
                  context,
                  icon: Icons.science_outlined,
                  title: context.t('تسجيل مختبر', 'Register lab'),
                  subtitle: context.t(
                    'أضف مختبرك وأجهزته',
                    'Add your lab and equipment',
                  ),
                  screen: const SubmitLabScreen(),
                ),
              if (_canAddProduct(account.role))
                _actionTile(
                  context,
                  icon: Icons.storefront_outlined,
                  title: context.t('متجري', 'My store'),
                  subtitle: context.t(
                    'منتجاتك، إضافة المزيد، وطلبات الشراء',
                    'Your products, add more, and purchase orders',
                  ),
                  screen: const MerchantStoreScreen(),
                ),
              if (_canPublishIdea(account.role))
                _actionTile(
                  context,
                  icon: Icons.lightbulb_outline,
                  title: context.t(
                    'نشر فكرة بحثية',
                    'Publish research idea',
                  ),
                  subtitle: context.t(
                    'تُراجع قبل الظهور في السوق',
                    'Reviewed before appearing in the marketplace',
                  ),
                  screen: const PublishResearchIdeaScreen(),
                ),
              const SizedBox(height: 20),
              Text(
                context.t('طلباتي قيد المراجعة', 'My pending submissions'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _MyPendingList(ownerId: account.uid),
            ],
          );
        },
      ),
    );
  }

  bool _canSubmitSupervisor(String role) =>
      role == UserRole.supervisor || role == UserRole.admin;

  bool _canSubmitLab(String role) =>
      role == UserRole.labManager || role == UserRole.admin;

  bool _canAddProduct(String role) => UserRole.canSellProducts(role);

  bool _canPublishIdea(String role) =>
      role == UserRole.ideaPublisher ||
      role == UserRole.supervisor ||
      role == UserRole.admin;

  bool _canWritingIncoming(String role) =>
      role == UserRole.supervisor || role == UserRole.admin;

  bool _canLabIncoming(String role) =>
      role == UserRole.labManager || role == UserRole.admin;

  bool _canSupervisionIncoming(String role) =>
      role == UserRole.supervisor || role == UserRole.admin;

  bool _canOutgoingResearcher(String role) =>
      role == UserRole.student ||
      role == UserRole.supervisor ||
      role == UserRole.admin;

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1A237E)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        ),
      ),
    );
  }
}

class _MyPendingList extends StatefulWidget {
  final String ownerId;

  const _MyPendingList({required this.ownerId});

  @override
  State<_MyPendingList> createState() => _MyPendingListState();
}

class _MyPendingListState extends State<_MyPendingList> {
  late Future<List<_OwnedItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPending();
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadPending());
    await _future;
  }

  String _typeLabel(String type) {
    return switch (type) {
      'supervisor' => L10nLookup.supervisor,
      'lab' => L10nLookup.lab,
      'product' => L10nLookup.product,
      'research_idea' => L10nLookup.researchIdea,
      _ => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_OwnedItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Text(
            context.t(
              'لا توجد طلبات معلقة حالياً',
              'No pending submissions right now',
            ),
            style: TextStyle(color: Colors.grey[600]),
          );
        }

        return Column(
          children: [
            ...items.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text(
                    '${_typeLabel(item.type)} • ${ApprovalStatus.label(item.status)}',
                  ),
                  trailing: IconButton(
                    tooltip: context.t('إزالة', 'Remove'),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final deleted =
                          await ContentDeleteService.instance.confirmAndDelete(
                        context,
                        collection: item.collection,
                        documentId: item.documentId,
                        itemLabel: item.title,
                      );
                      if (deleted && mounted) await _refresh();
                    },
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _refresh,
              child: Text(L10nLookup.refresh),
            ),
          ],
        );
      },
    );
  }

  Future<List<_OwnedItem>> _loadPending() async {
    final db = FirebaseFirestore.instance;
    final results = <_OwnedItem>[];

    final queries = await Future.wait([
      db
          .collection('supervisors')
          .where('ownerId', isEqualTo: widget.ownerId)
          .get(),
      db.collection('labs').where('ownerId', isEqualTo: widget.ownerId).get(),
      db
          .collection('product')
          .where('createdBy', isEqualTo: widget.ownerId)
          .get(),
      db
          .collection('research_ideas')
          .where('publisherId', isEqualTo: widget.ownerId)
          .get(),
    ]);

    for (final doc in queries[0].docs) {
      _addIfPending(
        results,
        doc.data(),
        doc.id,
        'supervisors',
        doc.data()['name'],
        'supervisor',
      );
    }
    for (final doc in queries[1].docs) {
      _addIfPending(
        results,
        doc.data(),
        doc.id,
        'labs',
        doc.data()['name'],
        'lab',
      );
    }
    for (final doc in queries[2].docs) {
      _addIfPending(
        results,
        doc.data(),
        doc.id,
        'product',
        doc.data()['name'],
        'product',
      );
    }
    for (final doc in queries[3].docs) {
      _addIfPending(
        results,
        doc.data(),
        doc.id,
        'research_ideas',
        doc.data()['title'],
        'research_idea',
      );
    }

    return results;
  }

  void _addIfPending(
    List<_OwnedItem> results,
    Map<String, dynamic> data,
    String documentId,
    String collection,
    dynamic titleField,
    String type,
  ) {
    final status = data['approvalStatus']?.toString() ?? '';
    if (status == ApprovalStatus.pending || status == ApprovalStatus.rejected) {
      results.add(
        _OwnedItem(
          title: titleField?.toString() ?? type,
          type: type,
          status: status,
          documentId: documentId,
          collection: collection,
        ),
      );
    }
  }
}

class _OwnedItem {
  final String title;
  final String type;
  final String status;
  final String documentId;
  final String collection;

  const _OwnedItem({
    required this.title,
    required this.type,
    required this.status,
    required this.documentId,
    required this.collection,
  });
}
