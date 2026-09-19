import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../store/catalog_report_service.dart';
import 'admin_access_gate.dart';
import '../legal/privacy_request_service.dart';

/// لوحة أدمن لطلبات الخصوصية وبلاغات الكتالوج.
class AdminPrivacyOpsScreen extends StatelessWidget {
  const AdminPrivacyOpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AcadeGateAppBar(
            title: Text(
              context.t('خصوصية وبلاغات', 'Privacy & reports'),
            ),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            bottom: TabBar(
              indicatorColor: Colors.amber,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: context.t('خصوصية', 'Privacy')),
                Tab(text: context.t('كتالوج', 'Catalog')),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _PrivacyRequestsTab(),
              _CatalogReportsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyRequestsTab extends StatelessWidget {
  const _PrivacyRequestsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PrivacyRequestService.instance.watchOpenForAdmin(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs.where((d) {
          final s = '${d.data()['status']}';
          return s == 'open' || s == 'in_progress';
        }).toList();
        if (docs.isEmpty) {
          return Center(
            child: Text(context.t('لا طلبات مفتوحة', 'No open requests')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final id = docs[i].id;
            final type = PrivacyRequestTypeX.fromId('${d['type']}');
            final isAr = Localizations.localeOf(context).languageCode == 'ar';
            return Card(
              child: ListTile(
                title: Text(type.label(isAr)),
                subtitle: Text(
                  '${d['email'] ?? ''}\n${d['message'] ?? ''}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (s) => PrivacyRequestService.instance.setStatus(
                    id: id,
                    status: s,
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'in_progress',
                      child: Text(context.t('قيد المعالجة', 'In progress')),
                    ),
                    PopupMenuItem(
                      value: 'closed',
                      child: Text(context.t('إغلاق', 'Close')),
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
}

class _CatalogReportsTab extends StatelessWidget {
  const _CatalogReportsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CatalogReportService.instance.watchOpenForAdmin(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs
            .where((d) => '${d.data()['status']}' == 'open')
            .toList();
        if (docs.isEmpty) {
          return Center(
            child: Text(context.t('لا بلاغات مفتوحة', 'No open reports')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final id = docs[i].id;
            return Card(
              child: ListTile(
                title: Text('${d['reason'] ?? ''} · ${d['storeName'] ?? d['supplierId'] ?? ''}'),
                subtitle: Text(
                  '${d['details'] ?? ''}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (s) =>
                      CatalogReportService.instance.setStatus(id, s),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'reviewed',
                      child: Text(context.t('تمت المراجعة', 'Reviewed')),
                    ),
                    PopupMenuItem(
                      value: 'dismissed',
                      child: Text(context.t('رفض', 'Dismiss')),
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
}
