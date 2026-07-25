import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import '../lab_import/nbsle_contact_enrichment_service.dart';
import '../profile/academic_profile_service.dart';
import 'lab_contacts_panel.dart';
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
  late AcademicLab _lab;

  @override
  void initState() {
    super.initState();
    _lab = widget.lab;
    _enrichContacts();
  }

  Future<void> _enrichContacts() async {
    final enriched =
        await NbsleContactEnrichmentService.instance.enrichIfNeeded(_lab);
    if (!mounted) return;
    setState(() => _lab = enriched);
  }

  String get _dateKey => SmartLabsService.instance.formatDate(_selectedDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: context.t('اختر تاريخ الحجز', 'Choose booking date'),
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
      _showMessage(
        context.t(
          'يجب تسجيل الدخول لحجز المختبر',
          'You must sign in to book the lab',
        ),
        isError: true,
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final profile = await AcademicProfileService.instance.loadProfile();
      await SmartLabsService.instance.createBooking(
        lab: _lab,
        equipment: widget.equipment,
        date: _selectedDate,
        slotStart: _selectedSlotStart!,
        slotEnd: slotEnd,
        userName: profile?.fullName ??
            user.email ??
            appTr('طالب', 'Student'),
      );

      if (!mounted) return;
      _showMessage(
        context.t('تم تأكيد الحجز فوراً', 'Booking confirmed instantly'),
      );
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
    final lab = _lab;
    final equipment = widget.equipment;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('حجز فوري', 'Instant booking')),
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
                if (lab.hasLabContact || lab.contacts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LabContactsPanel(
                    lab: lab,
                    backgroundColor: Colors.teal.shade50,
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(context.t('تاريخ الحجز', 'Booking date')),
                    subtitle: Text(_dateKey),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  context.t('التكلفة التقديرية', 'Estimated cost'),
                  '${equipment.costPerSession} ${appTr('ج.م', 'EGP')}',
                ),
                _summaryRow(
                  context.t('مدة الجلسة', 'Session duration'),
                  context.t(
                    '${equipment.durationMinutes} دقيقة',
                    '${equipment.durationMinutes} min',
                  ),
                ),
                _summaryRow(
                  context.t('مدة الانتظار المعتادة', 'Typical wait time'),
                  context.t(
                    '${equipment.waitDays} يوم',
                    '${equipment.waitDays} days',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.t('اختر الوقت', 'Choose a time'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    child: Text(
                      context.t(
                        'هذا مختبر تجريبي. أضف المختبر في Firebase لتفعيل الحجز الحقيقي.',
                        'This is a demo lab. Add the lab in Firebase to enable real booking.',
                      ),
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
                        return Text(
                          context.t(
                            'لا توجد مواعيد متاحة في هذا اليوم',
                            'No available slots on this day',
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: slots.map((slot) {
                          final selected = _selectedSlotStart == slot.start;
                          final label = '${slot.start} - ${slot.end}';

                          return ChoiceChip(
                            label: Text(
                              slot.isBooked
                                  ? context.t(
                                      '$label (محجوز)',
                                      '$label (booked)',
                                    )
                                  : label,
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
                    _isBooking
                        ? context.t('جارٍ التأكيد...', 'Confirming...')
                        : context.t('تأكيد الحجز الفوري', 'Confirm instant booking'),
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
