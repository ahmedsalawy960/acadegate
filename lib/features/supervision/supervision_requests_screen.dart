import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'supervision_request_models.dart';
import 'supervision_request_service.dart';

class MySupervisionRequestsScreen extends StatelessWidget {
  const MySupervisionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t(
          'طلباتي — إشراف وتواصل',
          'My requests — supervision & contact',
        )),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _RequestsList(
        stream: SupervisionRequestService.instance.myRequestsStream(),
        emptyText: context.t(
          'لم ترسل أي طلب إشراف أو رسالة بعد',
          'You have not sent any supervision or contact requests yet',
        ),
      ),
    );
  }
}

class IncomingSupervisionRequestsScreen extends StatelessWidget {
  const IncomingSupervisionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t(
          'طلبات الإشراف الواردة',
          'Incoming supervision requests',
        )),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _RequestsList(
        stream: SupervisionRequestService.instance.incomingForOwnerStream(),
        emptyText: context.t(
          'لا توجد طلبات واردة حالياً',
          'No incoming requests at the moment',
        ),
        showStudent: true,
        allowStatusUpdate: true,
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  final Stream<List<SupervisionRequest>> stream;
  final String emptyText;
  final bool showStudent;
  final bool allowStatusUpdate;

  const _RequestsList({
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
        child: Text(context.t(
          'سجّل الدخول لعرض الطلبات',
          'Sign in to view requests',
        )),
      );
    }

    return StreamBuilder<List<SupervisionRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(emptyText, textAlign: TextAlign.center),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final request = requests[index];
            return Card(
              child: ListTile(
                title: Text(
                  showStudent ? request.studentName : request.supervisorName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.typeLabel} • ${_statusLabel(context, request.status)}',
                    ),
                    if (showStudent && request.studentEmail.isNotEmpty)
                      Text(
                        request.studentEmail,
                        style: const TextStyle(fontSize: 12),
                      ),
                    const SizedBox(height: 4),
                    Text(request.message),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  tooltip: context.t('إجراءات', 'Actions'),
                  onSelected: (value) async {
                    if (request.id == null) return;
                    if (value == 'remove') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            ctx.t('إزالة الطلب', 'Remove request'),
                          ),
                          content: Text(
                            ctx.t(
                              'حذف هذا الطلب من قائمتك؟',
                              'Remove this request from your list?',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(ctx.t('الرجوع', 'Back')),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(ctx.t('إزالة', 'Remove')),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !context.mounted) return;
                      try {
                        await SupervisionRequestService.instance
                            .removeRequest(request);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                    try {
                      await SupervisionRequestService.instance.updateStatus(
                        request.id!,
                        value,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (allowStatusUpdate && request.status == 'pending') ...[
                      PopupMenuItem(
                        value: 'accepted',
                        child: Text(ctx.t('قبول', 'Accept')),
                      ),
                      PopupMenuItem(
                        value: 'rejected',
                        child: Text(ctx.t('رفض', 'Reject')),
                      ),
                      const PopupMenuDivider(),
                    ],
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        ctx.t('إزالة', 'Remove'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _statusLabel(BuildContext context, String status) {
    return switch (status) {
      'accepted' => context.t('مقبول', 'Accepted'),
      'rejected' => context.t('مرفوض', 'Rejected'),
      'cancelled' => context.t('ملغى', 'Cancelled'),
      _ => context.t('قيد الانتظار', 'Pending'),
    };
  }
}
