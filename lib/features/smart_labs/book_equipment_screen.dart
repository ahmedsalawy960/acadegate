import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../academic/academic_models.dart';
import '../profile/academic_profile_service.dart';
import 'smart_labs_service.dart';

class BookEquipmentScreen extends StatefulWidget {
  final AcademicLab lab;
  final LabEquipment equipment;

  const BookEquipmentScreen({
    super.key,
    required this.lab,
    required this.equipment,
  });

  @override
  State<BookEquipmentScreen> createState() => _BookEquipmentScreenState();
}

class _BookEquipmentScreenState extends State<BookEquipmentScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlotStart;
  bool _isBooking = false;

  String get _dateKey => SmartLabsService.instance.formatDate(_selectedDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'اختر تاريخ الحجز',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlotStart = null;
      });
    }
  }

  Future<void> _confirmBooking(String slotEnd) async {
    if (_selectedSlotStart == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('يجب تسجيل الدخول لحجز المختبر', isError: true);
      return;
    }

    setState(() => _isBooking = true);

    try {
      final profile = await AcademicProfileService.instance.loadProfile();
      await SmartLabsService.instance.createBooking(
        lab: widget.lab,
        equipment: widget.equipment,
        date: _selectedDate,
        slotStart: _selectedSlotStart!,
        slotEnd: slotEnd,
        userName: profile?.fullName ?? user.email ?? 'طالب',
      );

      if (!mounted) return;
      _showMessage('تم تأكيد الحجز فوراً');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;
    final equipment = widget.equipment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجز فوري'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  equipment.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(lab.name, style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('تاريخ الحجز'),
                    subtitle: Text(_dateKey),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 8),
                _summaryRow('التكلفة التقديرية',
                    '${equipment.costPerSession} ج.م'),
                _summaryRow('مدة الجلسة', '${equipment.durationMinutes} دقيقة'),
                _summaryRow('مدة الانتظار المعتادة',
                    '${equipment.waitDays} يوم'),
                const SizedBox(height: 16),
                const Text(
                  'اختر الوقت',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (!lab.isFromFirebase)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: const Text(
                      'هذا مختبر تجريبي. أضف المختبر في Firebase لتفعيل الحجز الحقيقي.',
                    ),
                  )
                else
                  StreamBuilder<List<LabBooking>>(
                    stream: SmartLabsService.instance.bookingsForDateStream(
                      labId: lab.id!,
                      date: _dateKey,
                      equipmentId: equipment.id,
                    ),
                    builder: (context, snapshot) {
                      final bookings = snapshot.data ?? [];
                      final slots = SmartLabsService.instance.buildSlots(
                        equipment: equipment,
                        existingBookings: bookings,
                      );

                      if (slots.isEmpty) {
                        return const Text('لا توجد مواعيد متاحة في هذا اليوم');
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: slots.map((slot) {
                          final selected = _selectedSlotStart == slot.start;
                          final label = '${slot.start} - ${slot.end}';

                          return ChoiceChip(
                            label: Text(
                              slot.isBooked ? '$label (محجوز)' : label,
                            ),
                            selected: selected,
                            onSelected: slot.isBooked
                                ? null
                                : (_) => setState(
                                      () => _selectedSlotStart = slot.start,
                                    ),
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isBooking ||
                          _selectedSlotStart == null ||
                          !lab.isFromFirebase
                      ? null
                      : () {
                          final slots =
                              SmartLabsService.instance.buildSlots(
                            equipment: equipment,
                            existingBookings: const [],
                          );
                          final slot = slots.firstWhere(
                            (item) => item.start == _selectedSlotStart,
                          );
                          _confirmBooking(slot.end);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isBooking ? 'جارٍ التأكيد...' : 'تأكيد الحجز الفوري',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey[700]))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
