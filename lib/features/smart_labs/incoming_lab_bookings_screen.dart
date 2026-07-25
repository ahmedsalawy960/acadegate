import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import 'smart_labs_service.dart';

Future<void> _cancelIncomingBooking(
  BuildContext context,
  LabBooking booking,
) async {
  if (booking.id == null || booking.labId.isEmpty) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('إلغاء الحجز', 'Cancel booking')),
      content: Text(
        ctx.t(
          'هل تريد إلغاء هذا الحجز؟',
          'Do you want to cancel this booking?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.t('لا', 'No')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.t('نعم، إلغاء', 'Yes, cancel')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await SmartLabsService.instance.cancelBooking(
      labId: booking.labId,
      bookingId: booking.id!,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('تم إلغاء الحجز', 'Booking cancelled'))),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: Colors.red),
    );
  }
}

/// Incoming equipment bookings for the claimed lab owner.
class IncomingLabBookingsScreen extends StatelessWidget {
  const IncomingLabBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('حجوزات الأجهزة الواردة', 'Incoming equipment bookings'),
        ),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<LabBooking>>(
        stream: SmartLabsService.instance.incomingBookingsForOwnerStream(),
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
                    'تعذر تحميل الحجوزات. قد يلزم فهرس Firestore لـ labOwnerId.',
                    'Could not load bookings. A Firestore index for labOwnerId may be required.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final bookings = (snapshot.data ?? [])
              .where((b) => b.isConfirmed)
              .toList();
          if (bookings.isEmpty) {
            return Center(
              child: Text(
                context.t(
                  'لا توجد حجوزات واردة لمختبراتك',
                  'No incoming bookings for your labs',
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
                  leading: Icon(
                    b.isConfirmed ? Icons.event_available : Icons.event_busy,
                    color: b.isConfirmed ? Colors.teal : Colors.grey,
                  ),
                  title: Text(
                    b.equipmentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${b.labName.isNotEmpty ? b.labName : b.labId}\n'
                    '${b.userName} • ${b.date} ${b.slotStart}-${b.slotEnd}\n'
                    '${b.status}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: context.t('إلغاء الحجز', 'Cancel booking'),
                    onPressed: () => _cancelIncomingBooking(context, b),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
