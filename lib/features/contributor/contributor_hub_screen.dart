import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import '../moderation/approval_status.dart';
import '../research_marketplace/publish_research_idea_screen.dart';
import '../store/store_categories_screen.dart';
import 'submit_lab_screen.dart';
import 'submit_supervisor_screen.dart';

class ContributorHubScreen extends StatelessWidget {
  const ContributorHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المساهمة'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<UserAccount?>(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, snapshot) {
          final account = snapshot.data;
          if (account == null) {
            return const Center(
              child: Text('سجّل الدخول للوصول إلى لوحة المساهمة'),
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
              const Text(
                'إضافة محتوى',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (_canSubmitSupervisor(account.role) ||
                  account.role == UserRole.student)
                _actionTile(
                  context,
                  icon: Icons.person_add_alt_1,
                  title: 'تسجيل ملف مشرف',
                  subtitle: 'يُرسل للمراجعة قبل الظهور',
                  screen: const SubmitSupervisorScreen(),
                ),
              if (_canSubmitLab(account.role) ||
                  account.role == UserRole.student)
                _actionTile(
                  context,
                  icon: Icons.science_outlined,
                  title: 'تسجيل مختبر',
                  subtitle: 'أضف مختبرك وأجهزته',
                  screen: const SubmitLabScreen(),
                ),
              if (_canAddProduct(account.role))
                _actionTile(
                  context,
                  icon: Icons.storefront_outlined,
                  title: 'إضافة منتج للمتجر',
                  subtitle: 'اختر قسم المتجر ثم أضف منتجك',
                  screen: const StoreCategoriesScreen(),
                ),
              if (_canPublishIdea(account.role))
                _actionTile(
                  context,
                  icon: Icons.lightbulb_outline,
                  title: 'نشر فكرة بحثية',
                  subtitle: 'تُراجع قبل الظهور في السوق',
                  screen: const PublishResearchIdeaScreen(),
                ),
              const SizedBox(height: 20),
              const Text(
                'طلباتي قيد المراجعة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  bool _canAddProduct(String role) =>
      role == UserRole.merchant || role == UserRole.admin;

  bool _canPublishIdea(String role) =>
      role == UserRole.ideaPublisher ||
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
            'لا توجد طلبات معلقة حالياً',
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
                    '${item.type} • ${ApprovalStatus.label(item.status)}',
                  ),
                ),
              ),
            ),
            TextButton(onPressed: _refresh, child: const Text('تحديث')),
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
      _addIfPending(results, doc.data(), doc.data()['name'], 'مشرف');
    }
    for (final doc in queries[1].docs) {
      _addIfPending(results, doc.data(), doc.data()['name'], 'مختبر');
    }
    for (final doc in queries[2].docs) {
      _addIfPending(results, doc.data(), doc.data()['name'], 'منتج');
    }
    for (final doc in queries[3].docs) {
      _addIfPending(results, doc.data(), doc.data()['title'], 'فكرة بحثية');
    }

    return results;
  }

  void _addIfPending(
    List<_OwnedItem> results,
    Map<String, dynamic> data,
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
        ),
      );
    }
  }
}

class _OwnedItem {
  final String title;
  final String type;
  final String status;

  const _OwnedItem({
    required this.title,
    required this.type,
    required this.status,
  });
}
