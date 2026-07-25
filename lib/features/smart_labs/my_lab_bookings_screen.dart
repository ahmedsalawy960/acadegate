import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import 'smart_labs_service.dart';

class MyLabBookingsScreen extends StatelessWidget {
  const MyLabBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('حجوزاتي', 'My bookings')),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? Center(
              child: Text(
                context.t(
                  'سجّل الدخول لعرض حجوزاتك',
                  'Sign in to view your bookings',
                ),
              ),
            )
          : StreamBuilder<List<LabBooking>>(
              stream: SmartLabsService.instance.userBookingsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bookings = (snapshot.data ?? [])
                    .where((booking) => booking.isConfirmed)
                    .toList();

                if (bookings.isEmpty) {
                  return Center(
                    child: Text(
                      context.t(
                        'لا توجد حجوزات حالياً',
                        'No bookings yet',
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_available,
                            color: Colors.purple),
                        title: Text(
                          booking.equipmentName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${booking.date}\n${booking.slotStart} - ${booking.slotEnd}\n'
                          '${booking.costEstimate} ${appTr('ج.م', 'EGP')}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: context.t('إلغاء الحجز', 'Cancel booking'),
                          onPressed: () => _cancel(context, booking),
                          icon: const Icon(Icons.cancel_outlined,
                              color: Colors.red),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _cancel(BuildContext context, LabBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('إلغاء الحجز', 'Cancel booking')),
        content: Text(
          ctx.t('هل تريد إلغاء هذا الحجز؟', 'Do you want to cancel this booking?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('لا', 'No')),
          ),
          TextButton(
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
        SnackBar(
          content: Text(
            context.t('تم إلغاء الحجز', 'Booking cancelled'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
