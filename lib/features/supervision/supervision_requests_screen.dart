import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'supervision_request_models.dart';
import 'supervision_request_service.dart';

class MySupervisionRequestsScreen extends StatelessWidget {
  const MySupervisionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي — إشراف وتواصل'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _RequestsList(
        stream: SupervisionRequestService.instance.myRequestsStream(),
        emptyText: 'لم ترسل أي طلب إشراف أو رسالة بعد',
      ),
    );
  }
}

class IncomingSupervisionRequestsScreen extends StatelessWidget {
  const IncomingSupervisionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الإشراف الواردة'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _RequestsList(
        stream: SupervisionRequestService.instance.incomingForOwnerStream(),
        emptyText: 'لا توجد طلبات واردة حالياً',
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
      return const Center(child: Text('سجّل الدخول لعرض الطلبات'));
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
                    Text('${request.typeLabel} • ${_statusLabel(request.status)}'),
                    if (showStudent && request.studentEmail.isNotEmpty)
                      Text(request.studentEmail, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(request.message),
                  ],
                ),
                isThreeLine: true,
                trailing: allowStatusUpdate && request.status == 'pending'
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (request.id == null) return;
                          SupervisionRequestService.instance.updateStatus(
                            request.id!,
                            value,
                          );
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'accepted', child: Text('قبول')),
                          PopupMenuItem(value: 'rejected', child: Text('رفض')),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'accepted' => 'مقبول',
      'rejected' => 'مرفوض',
      _ => 'قيد الانتظار',
    };
  }
}
