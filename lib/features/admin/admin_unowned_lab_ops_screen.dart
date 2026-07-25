import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../analysis_labs/sample_analysis_request_service.dart';
import '../analysis_labs/sample_requests_screens.dart';
import '../smart_labs/smart_labs_service.dart';
import '../academic/academic_models.dart';
import 'admin_access_gate.dart';

/// Admin inbox for bookings & sample requests on unowned (NBSLE) labs.
class AdminUnownedLabOpsScreen extends StatelessWidget {
  const AdminUnownedLabOpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      child: DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(
            context.t(
              'عمليات المختبرات غير المربوطة',
              'Unowned lab operations',
            ),
          ),
          backgroundColor: Colors.teal[800],
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                text: context.t('تحليل عينات', 'Sample analysis'),
              ),
              Tab(
                text: context.t('حجوزات أجهزة', 'Equipment bookings'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SampleRequestListView(
              stream:
                  SampleAnalysisRequestService.instance.unownedOpsStream(),
              emptyText: context.t(
                'لا توجد طلبات تحليل على مختبرات غير مربوطة',
                'No sample requests on unowned labs',
              ),
              showStudent: true,
              allowStatusUpdate: true,
            ),
            _UnownedBookingsList(),
          ],
        ),
      ),
      ),
    );
  }
}

class _UnownedBookingsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LabBooking>>(
      stream: SmartLabsService.instance.unownedBookingsOpsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.t(
                  'تعذر تحميل الحجوزات. قد يلزم فهرس Firestore لـ needsOwnerRouting.',
                  'Could not load bookings. A Firestore index for needsOwnerRouting may be required.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) {
          return Center(
            child: Text(
              context.t(
                'لا توجد حجوزات على مختبرات غير مربوطة',
                'No bookings on unowned labs',
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: bookings.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final b = bookings[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.event_available),
                title: Text(
                  b.labName.isNotEmpty ? b.labName : b.labId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${b.userName}\n${b.equipmentName} • ${b.date} ${b.slotStart}-${b.slotEnd}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
