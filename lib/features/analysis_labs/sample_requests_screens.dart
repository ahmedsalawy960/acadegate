import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import 'sample_analysis_request_service.dart';
import 'sample_analysis_sla.dart';
import 'sample_analysis_sla_alert_service.dart';

class MySampleAnalysisRequestsScreen extends StatefulWidget {
  const MySampleAnalysisRequestsScreen({super.key});

  @override
  State<MySampleAnalysisRequestsScreen> createState() =>
      _MySampleAnalysisRequestsScreenState();
}

class _MySampleAnalysisRequestsScreenState
    extends State<MySampleAnalysisRequestsScreen> {
  @override
  void initState() {
    super.initState();
    SampleAnalysisSlaAlertService.instance.maybeNotify();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('طلبات تحليل العينات', 'Sample analysis requests'),
        ),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: SampleRequestListView(
        stream: SampleAnalysisRequestService.instance.myRequestsStream(),
        emptyText: context.t(
          'لم ترسل أي طلب تحليل عينات بعد',
          'You have not sent any sample analysis requests yet',
        ),
      ),
    );
  }
}

class IncomingSampleAnalysisRequestsScreen extends StatefulWidget {
  const IncomingSampleAnalysisRequestsScreen({super.key});

  @override
  State<IncomingSampleAnalysisRequestsScreen> createState() =>
      _IncomingSampleAnalysisRequestsScreenState();
}

class _IncomingSampleAnalysisRequestsScreenState
    extends State<IncomingSampleAnalysisRequestsScreen> {
  @override
  void initState() {
    super.initState();
    SampleAnalysisSlaAlertService.instance.maybeNotify();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('طلبات التحليل الواردة', 'Incoming analysis requests'),
        ),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: SampleRequestListView(
        stream: SampleAnalysisRequestService.instance.incomingForLabOwnerStream(),
        emptyText: context.t(
          'لا توجد طلبات تحليل واردة',
          'No incoming analysis requests',
        ),
        showStudent: true,
        allowStatusUpdate: true,
      ),
    );
  }
}

class SampleRequestListView extends StatelessWidget {
  final Stream<List<SampleAnalysisRequest>> stream;
  final String emptyText;
  final bool showStudent;
  final bool allowStatusUpdate;

  const SampleRequestListView({
    super.key,
    required this.stream,
    required this.emptyText,
    this.showStudent = false,
    this.allowStatusUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          context.t('سجّل الدخول لعرض الطلبات', 'Sign in to view requests'),
        ),
      );
    }

    final isEnglish = LocaleService.instance.isEnglish;

    return StreamBuilder<List<SampleAnalysisRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(child: Text(emptyText, textAlign: TextAlign.center));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final request = requests[index];
            final sla = SampleAnalysisSla.evaluate(request);

            return Card(
              color: sla.isOverdue && sla.daysOverdue >= 3
                  ? Colors.orange.shade50
                  : null,
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        showStudent ? request.studentName : request.labName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (sla.showBadge) _SlaBadge(sla: sla, isEnglish: isEnglish),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.serviceName} • ${_statusLabel(request.status)}',
                    ),
                    if (request.sampleType.isNotEmpty)
                      Text('${request.sampleType} × ${request.sampleCount}'),
                    if (request.researchTitle.isNotEmpty)
                      Text(request.researchTitle),
                    if (request.notes.isNotEmpty) Text(request.notes),
                    if (sla.detailLine(isEnglish).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          sla.detailLine(isEnglish),
                          style: TextStyle(
                            fontSize: 12,
                            color: sla.isOverdue
                                ? Colors.orange.shade900
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
                isThreeLine: true,
                trailing: _RequestActions(
                  request: request,
                  allowStatusUpdate: allowStatusUpdate,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'quoted' => appTr(
          'بانتظار الموافقة على السعر',
          'Awaiting price approval',
        ),
      'accepted' => appTr('مقبول', 'Accepted'),
      'rejected' => appTr('مرفوض', 'Rejected'),
      'completed' => appTr('مكتمل', 'Completed'),
      'cancelled' => appTr('ملغى', 'Cancelled'),
      _ => appTr('قيد المراجعة', 'Under review'),
    };
  }
}

class _RequestActions extends StatelessWidget {
  final SampleAnalysisRequest request;
  final bool allowStatusUpdate;

  const _RequestActions({
    required this.request,
    required this.allowStatusUpdate,
  });

  bool get _isOpen =>
      request.status == 'pending' ||
      request.status == 'quoted' ||
      request.status == 'accepted';

  @override
  Widget build(BuildContext context) {
    final showStatus = allowStatusUpdate && request.status == 'pending';

    return PopupMenuButton<String>(
      tooltip: context.t('إجراءات', 'Actions'),
      onSelected: (value) async {
        if (request.id == null) return;
        if (value == 'remove') {
          await _confirmRemove(context);
          return;
        }
        try {
          await SampleAnalysisRequestService.instance.updateStatus(
            request.id!,
            value,
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      },
      itemBuilder: (ctx) => [
        if (showStatus) ...[
          PopupMenuItem(
            value: 'quoted',
            child: Text(ctx.t('تسعير', 'Quote')),
          ),
          PopupMenuItem(
            value: 'accepted',
            child: Text(ctx.t('قبول', 'Accept')),
          ),
          PopupMenuItem(
            value: 'rejected',
            child: Text(ctx.t('رفض', 'Reject')),
          ),
          PopupMenuItem(
            value: 'completed',
            child: Text(ctx.t('مكتمل', 'Completed')),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: 'remove',
          child: Text(
            _isOpen
                ? ctx.t('إلغاء وإزالة', 'Cancel & remove')
                : ctx.t('إزالة من القائمة', 'Remove from list'),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('إزالة الطلب', 'Remove request')),
        content: Text(
          _isOpen
              ? ctx.t(
                  'سيتم إلغاء هذا الطلب وإخفاؤه من القائمة النشطة.',
                  'This request will be cancelled and removed from the active list.',
                )
              : ctx.t(
                  'حذف هذا الطلب نهائياً من قائمتك؟',
                  'Permanently delete this request from your list?',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('الرجوع', 'Back')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('إزالة', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await SampleAnalysisRequestService.instance.removeRequest(request);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم إزالة الطلب', 'Request removed'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _SlaBadge extends StatelessWidget {
  final SampleSlaStatus sla;
  final bool isEnglish;

  const _SlaBadge({required this.sla, required this.isEnglish});

  @override
  Widget build(BuildContext context) {
    final label = sla.badgeLabel(isEnglish);
    if (label.isEmpty) return const SizedBox.shrink();

    final color = sla.isOverdue && sla.daysOverdue >= 3
        ? Colors.deepOrange
        : sla.isOverdue
            ? Colors.orange
            : Colors.blueGrey;

    final Color fg = sla.isOverdue && sla.daysOverdue >= 3
        ? Colors.deepOrange.shade800
        : sla.isOverdue
            ? Colors.orange.shade800
            : Colors.blueGrey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
