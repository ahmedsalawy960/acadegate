import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../supervision/supervision_requests_screen.dart';
import 'supervisor_workload_service.dart';

class SupervisorWorkloadScreen extends StatelessWidget {
  const SupervisorWorkloadScreen({super.key});

  static const _brand = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('لوحة المشرف', 'Supervisor dashboard')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<SupervisorWorkloadSummary>(
        stream: SupervisorWorkloadService.instance.watchSummary(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = snapshot.data!;
          final loadColor = summary.loadRatio >= 0.85
              ? Colors.red.shade700
              : summary.loadRatio >= 0.5
                  ? Colors.orange.shade700
                  : Colors.green.shade700;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: loadColor.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.loadLabel,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: loadColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: summary.loadRatio,
                        color: loadColor,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          '${summary.totalActive} طلب/طالب نشط (تقدير)',
                          '${summary.totalActive} active request(s)/students (est.)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _statTile(
                context,
                icon: Icons.pending_actions,
                label: context.t('طلبات قيد المراجعة', 'Pending requests'),
                value: '${summary.pendingCount}',
              ),
              _statTile(
                context,
                icon: Icons.check_circle_outline,
                label: context.t('طلبات مقبولة', 'Accepted requests'),
                value: '${summary.acceptedCount}',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IncomingSupervisionRequestsScreen(),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.inbox),
                label: Text(context.t('إدارة الطلبات', 'Manage requests')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: _brand),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
