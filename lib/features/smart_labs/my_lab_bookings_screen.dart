import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../academic/academic_models.dart';
import 'smart_labs_service.dart';

class MyLabBookingsScreen extends StatelessWidget {
  const MyLabBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزاتي'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(
              child: Text('سجّل الدخول لعرض حجوزاتك'),
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
                  return const Center(child: Text('لا توجد حجوزات حالياً'));
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
                          '${booking.date}\n${booking.slotStart} - ${booking.slotEnd}\n${booking.costEstimate} ج.م',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'إلغاء الحجز',
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
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل تريد إلغاء هذا الحجز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، إلغاء'),
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
        const SnackBar(
          content: Text('تم إلغاء الحجز'),
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
