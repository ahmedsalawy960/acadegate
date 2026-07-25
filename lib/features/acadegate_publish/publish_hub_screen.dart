import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import '../auth/user_account_service.dart';
import 'admin_journal_form_screen.dart';
import 'manuscript_editor_screen.dart';
import 'publish_models.dart';
import 'publish_services.dart';

class PublishHubScreen extends StatelessWidget {
  const PublishHubScreen({super.key});

  static const _brand = Color(0xFF4A148C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.l10n.servicePublish),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (snapshot.data?.isAdmin != true) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: context.t('إضافة مجلة', 'Add journal'),
                icon: const Icon(Icons.library_add_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminJournalFormScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PublishManuscript>>(
        stream: ManuscriptService.instance.watchMine(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];

          return StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, accountSnap) {
              final isAdmin = accountSnap.data?.isAdmin == true;

              return CustomScrollView(
                slivers: [
                  if (isAdmin)
                    SliverToBoxAdapter(
                      child: _PendingJournalsPanel(),
                    ),
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final m = items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(_statusIcon(m.status), color: _brand),
                                title: Text(
                                  m.title.trim().isEmpty
                                      ? context.t(
                                          'مسودة بدون عنوان',
                                          'Untitled draft',
                                        )
                                      : m.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(_statusLabel(context, m)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: context.t(
                                        'حذف المسودة',
                                        'Delete draft',
                                      ),
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red[400],
                                      ),
                                      onPressed: () => _confirmDeleteDraft(
                                        context,
                                        m,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ManuscriptEditorScreen(
                                      manuscriptId: m.id!,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDraft(context),
        backgroundColor: _brand,
        icon: const Icon(Icons.note_add_outlined),
        label: Text(context.t('مسودة جديدة', 'New draft')),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              context.t(
                'لا توجد مسودات بعد',
                'No drafts yet',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'ابدأ مسودة → نسّق IEEE/APA → اختر مجلة للتقديم',
                'Start a draft → format IEEE/APA → pick a journal to submit',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDraft(
    BuildContext context,
    PublishManuscript m,
  ) async {
    if (m.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('حذف المسودة؟', 'Delete draft?')),
        content: Text(
          context.t(
            'سيتم حذف المسودة وملفاتها ومراجعها نهائياً ولا يمكن التراجع.',
            'This will permanently delete the draft, its files, and references.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ManuscriptService.instance.deleteCompletely(m.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم حذف المسودة', 'Draft deleted')),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _createDraft(BuildContext context) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !context.mounted) return;

    try {
      final id = await ManuscriptService.instance.createEmpty();
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManuscriptEditorScreen(manuscriptId: id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  IconData _statusIcon(ManuscriptStatus status) => switch (status) {
        ManuscriptStatus.draft => Icons.edit_note,
        ManuscriptStatus.formatted => Icons.format_quote,
        ManuscriptStatus.submitted => Icons.send,
      };

  String _statusLabel(BuildContext context, PublishManuscript m) {
    final status = switch (m.status) {
      ManuscriptStatus.draft => context.t('مسودة', 'Draft'),
      ManuscriptStatus.formatted => context.t('منسّق', 'Formatted'),
      ManuscriptStatus.submitted => context.t('مُقدَّم', 'Submitted'),
    };
    if (m.journalName != null && m.journalName!.isNotEmpty) {
      return '$status · ${m.journalName}';
    }
    return status;
  }
}

class _PendingJournalsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PublishJournal>>(
      stream: JournalCatalogService.instance.watchPending(),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? [];
        if (pending.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('مجلات بانتظار الموافقة', 'Journals pending approval'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...pending.map((j) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(j.name),
                      subtitle: j.partnerUniversity.isNotEmpty
                          ? Text(j.partnerUniversity)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () =>
                                JournalCatalogService.instance.approve(j.id!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () =>
                                JournalCatalogService.instance.reject(j.id!),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
