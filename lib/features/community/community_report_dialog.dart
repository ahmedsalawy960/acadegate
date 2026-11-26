import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'community_report_service.dart';

/// Asks for a reason and sends a report. Shows the result as a snackbar.
Future<void> showCommunityReportDialog(
  BuildContext context, {
  required String postId,
  String? replyId,
  String postTitle = '',
}) async {
  var reason = CommunityReportReason.spam;
  final noteController = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(ctx.t('الإبلاغ عن محتوى', 'Report content')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in CommunityReportReason.all)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(CommunityReportReason.label(r)),
                  leading: Icon(
                    reason == r
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () => setState(() => reason = r),
                ),
              TextField(
                controller: noteController,
                maxLength: kCommunityReportNoteMaxLength,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: ctx.t('ملاحظة (اختياري)', 'Note (optional)'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('إرسال البلاغ', 'Send report')),
          ),
        ],
      ),
    ),
  );
  final note = noteController.text;
  noteController.dispose();
  if (send != true || !context.mounted) return;

  final error = await CommunityReportService.instance.submit(
    postId: postId,
    replyId: replyId,
    reason: reason,
    note: note,
    postTitle: postTitle,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error ??
            context.t(
              'تم إرسال البلاغ، شكراً لك',
              'Report sent, thank you',
            ),
      ),
    ),
  );
}
