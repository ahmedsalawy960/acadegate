import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'admin_access_gate.dart';
import '../bugs/bug_report_service.dart';

class AdminBugsScreen extends StatefulWidget {
  const AdminBugsScreen({super.key});

  @override
  State<AdminBugsScreen> createState() => _AdminBugsScreenState();
}

class _AdminBugsScreenState extends State<AdminBugsScreen> {
  String _status = BugReportService.statusOpen;

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      child: Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('سجل المشاكل والأخطاء', 'Bugs & errors')),
          backgroundColor: const Color(0xFFB71C1C),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  _chip('open', context.t('مفتوحة', 'Open')),
                  _chip('investigating', context.t('قيد التحقيق', 'Investigating')),
                  _chip('resolved', context.t('محلولة', 'Resolved')),
                  _chip('wontfix', context.t('لن تُصلح', "Won't fix")),
                  _chip('all', context.t('الكل', 'All')),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: BugReportService.instance.watchForAdmin(
                  status: _status,
                ),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('${snap.error}'),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        context.t('لا مشاكل في هذا التصفية', 'No bugs in this filter'),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      return _BugCard(
                        id: doc.id,
                        data: doc.data(),
                        onChanged: () => setState(() {}),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => setState(() => _status = value),
      ),
    );
  }
}

class _BugCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onChanged;

  const _BugCard({
    required this.id,
    required this.data,
    required this.onChanged,
  });

  Color _severityColor(String s) {
    switch (s) {
      case 'critical':
        return const Color(0xFFB71C1C);
      case 'high':
        return Colors.deepOrange;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _sourceLabel(BuildContext context, String s) {
    switch (s) {
      case BugReportService.sourceAutoFlutter:
        return context.t('تلقائي Flutter', 'Auto Flutter');
      case BugReportService.sourceAutoPlatform:
        return context.t('تلقائي Platform', 'Auto Platform');
      case BugReportService.sourceCaught:
        return context.t('التُقط في الكود', 'Caught');
      case BugReportService.sourceProvider:
        return context.t('بلاغ مقدم خدمة', 'Provider report');
      case BugReportService.sourceUser:
        return context.t('بلاغ مستخدم', 'User report');
      default:
        return s;
    }
  }

  Future<void> _setStatus(BuildContext context, String status) async {
    await BugReportService.instance.updateStatus(id: id, status: status);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final message = '${data['message'] ?? ''}';
    final severity = '${data['severity'] ?? 'medium'}';
    final source = '${data['source'] ?? ''}';
    final portal = '${data['portal'] ?? ''}';
    final category = '${data['category'] ?? ''}';
    final email = '${data['email'] ?? ''}';
    final role = '${data['role'] ?? ''}';
    final platform = '${data['platform'] ?? ''}';
    final stack = '${data['stack'] ?? ''}';
    final screen = '${data['screen'] ?? ''}';
    final status = '${data['status'] ?? 'open'}';
    final created = data['createdAt'];
    String when = '';
    if (created is Timestamp) {
      when = created.toDate().toLocal().toString().split('.').first;
    }

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _severityColor(severity),
          child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
        ),
        title: Text(
          message.isEmpty ? id : message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            _sourceLabel(context, source),
            if (portal.isNotEmpty) portal,
            if (category.isNotEmpty) category,
            if (when.isNotEmpty) when,
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(message),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(label: Text(severity)),
                    Chip(label: Text(status)),
                    if (email.isNotEmpty) Chip(label: Text(email)),
                    if (role.isNotEmpty) Chip(label: Text(role)),
                    if (platform.isNotEmpty) Chip(label: Text(platform)),
                    if (screen.isNotEmpty) Chip(label: Text(screen)),
                  ],
                ),
                if (stack.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t('المكدس', 'Stack'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    padding: const EdgeInsets.all(8),
                    color: Colors.black87,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        stack,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _setStatus(
                        context,
                        BugReportService.statusInvestigating,
                      ),
                      child: Text(context.t('تحقيق', 'Investigate')),
                    ),
                    FilledButton(
                      onPressed: () => _setStatus(
                        context,
                        BugReportService.statusResolved,
                      ),
                      child: Text(context.t('حُلّت', 'Resolved')),
                    ),
                    TextButton(
                      onPressed: () => _setStatus(
                        context,
                        BugReportService.statusWontFix,
                      ),
                      child: Text(context.t('تجاهل', "Won't fix")),
                    ),
                    IconButton(
                      tooltip: context.t('نسخ', 'Copy'),
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: '$message\n\n$stack\n$id',
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t('تم النسخ', 'Copied')),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
