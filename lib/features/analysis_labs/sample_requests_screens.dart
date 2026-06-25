import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'sample_analysis_request_service.dart';

class MySampleAnalysisRequestsScreen extends StatelessWidget {
  const MySampleAnalysisRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات تحليل العينات'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: _SampleRequestList(
        stream: SampleAnalysisRequestService.instance.myRequestsStream(),
        emptyText: 'لم ترسل أي طلب تحليل عينات بعد',
      ),
    );
  }
}

class IncomingSampleAnalysisRequestsScreen extends StatelessWidget {
  const IncomingSampleAnalysisRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التحليل الواردة'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: _SampleRequestList(
        stream: SampleAnalysisRequestService.instance.incomingForLabOwnerStream(),
        emptyText: 'لا توجد طلبات تحليل واردة',
        showStudent: true,
        allowStatusUpdate: true,
      ),
    );
  }
}

class _SampleRequestList extends StatelessWidget {
  final Stream<List<SampleAnalysisRequest>> stream;
  final String emptyText;
  final bool showStudent;
  final bool allowStatusUpdate;

  const _SampleRequestList({
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
            return Card(
              child: ListTile(
                title: Text(
                  showStudent ? request.studentName : request.labName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${request.serviceName} • ${_statusLabel(request.status)}'),
                    if (request.sampleType.isNotEmpty)
                      Text('${request.sampleType} × ${request.sampleCount}'),
                    if (request.researchTitle.isNotEmpty)
                      Text(request.researchTitle),
                    if (request.notes.isNotEmpty) Text(request.notes),
                  ],
                ),
                isThreeLine: true,
                trailing: allowStatusUpdate && request.status == 'pending'
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (request.id == null) return;
                          SampleAnalysisRequestService.instance.updateStatus(
                            request.id!,
                            value,
                          );
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'quoted', child: Text('تسعير')),
                          PopupMenuItem(value: 'accepted', child: Text('قبول')),
                          PopupMenuItem(value: 'rejected', child: Text('رفض')),
                          PopupMenuItem(value: 'completed', child: Text('مكتمل')),
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
      'quoted' => 'بانتظار الموافقة على السعر',
      'accepted' => 'مقبول',
      'rejected' => 'مرفوض',
      'completed' => 'مكتمل',
      _ => 'قيد المراجعة',
    };
  }
}
