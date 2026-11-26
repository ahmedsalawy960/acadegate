import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../community/community_report_service.dart';
import '../community/community_service.dart';
import '../moderation/content_delete_service.dart';
import 'admin_access_gate.dart';

/// Open reports on community posts and replies, for admins.
class AdminCommunityReportsScreen extends StatelessWidget {
  const AdminCommunityReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      child: Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('بلاغات المجتمع', 'Community reports')),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: CommunityReportService.instance.watchOpen(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aAt = a.data()['createdAt'];
                final bAt = b.data()['createdAt'];
                if (aAt is Timestamp && bAt is Timestamp) {
                  return bAt.compareTo(aAt);
                }
                return 0;
              });
            if (docs.isEmpty) {
              return Center(
                child: Text(context.t('لا توجد بلاغات مفتوحة', 'No open reports')),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, i) => _ReportCard(doc: docs[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _ReportCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final postId = data['postId']?.toString() ?? '';
    final replyId = data['replyId']?.toString() ?? '';
    final isReply = replyId.isNotEmpty;
    final title = data['postTitle']?.toString() ?? '';
    final note = data['note']?.toString() ?? '';
    final reason = CommunityReportReason.label(data['reason']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReply
                  ? context.t('بلاغ عن رد', 'Reported reply')
                  : context.t('بلاغ عن منشور', 'Reported post'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (title.isNotEmpty) Text(title),
            Text('${context.t('السبب', 'Reason')}: $reason'),
            if (note.isNotEmpty) Text(note),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      CommunityReportService.instance.setStatus(doc.id, 'dismissed'),
                  child: Text(context.t('تجاهل البلاغ', 'Dismiss')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    if (isReply) {
                      final error = await CommunityService.instance
                          .deleteReply(postId: postId, replyId: replyId);
                      if (error != null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(error)));
                        }
                        return;
                      }
                    } else {
                      final done = await ContentDeleteService.instance
                          .confirmAndDelete(
                        context,
                        collection: 'community_posts',
                        documentId: postId,
                        itemLabel: title.isEmpty ? postId : title,
                      );
                      if (!done) return;
                    }
                    await CommunityReportService.instance
                        .setStatus(doc.id, 'actioned');
                  },
                  child: Text(
                    isReply
                        ? context.t('حذف الرد', 'Delete reply')
                        : context.t('حذف المنشور', 'Delete post'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
