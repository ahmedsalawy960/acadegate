import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import '../lab_import/nbsle_contact_enrichment_service.dart';
import '../profile/academic_profile_service.dart';
import 'lab_contacts_panel.dart';
import 'lab_operations.dart';
import 'lab_training_service.dart';
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
  bool _safetyAck = false;
  bool _recordingTraining = false;
  late AcademicLab _lab;

  bool get _needsTraining => LabOperations.needsTrainingGate(
        equipment: widget.equipment,
        nbsleLab: _lab.isNbsleImport,
      );

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
        title: Text(
          context.t('تشغيل الجهاز — رزنامة وتدريب', 'Device ops — calendar & training'),
        ),
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
                Text(lab.name, style: TextStyle(color: const Color(0xFFB7C3D6))),
                const SizedBox(height: 10),
                _opsBanner(lab),
                if (lab.hasLabContact || lab.contacts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LabContactsPanel(
                    lab: lab,
                    backgroundColor: Colors.teal.shade50,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  context.t('رزنامة الأسبوع', 'Week calendar'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _weekStrip(),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(context.t('تاريخ الحجز', 'Booking date')),
                    subtitle: Text(_dateKey),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: _pickDate,
                  ),
                ),
                if (_needsTraining) ...[
                  const SizedBox(height: 12),
                  _trainingGate(lab),
                ],
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
              child: StreamBuilder<bool>(
                stream: lab.isFromFirebase && _needsTraining
                    ? LabTrainingService.instance.watchCompleted(
                        labId: lab.id!,
                        equipmentId: equipment.id,
                      )
                    : Stream.value(true),
                builder: (context, trainedSnap) {
                  final trained = !_needsTraining || trainedSnap.data == true;
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isBooking ||
                              _selectedSlotStart == null ||
                              !lab.isFromFirebase ||
                              !trained
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
                            : trained
                                ? context.t(
                                    'تأكيد الحجز (رزنامة بلا تعارض)',
                                    'Confirm booking (no-overlap calendar)',
                                  )
                                : context.t(
                                    'سجّل التدريب أولاً',
                                    'Record training first',
                                  ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _opsBanner(AcademicLab lab) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        lab.isNbsleImport
            ? context.t(
                'طبقة تشغيل فوق سجل NBSLE: الرزنامة تمنع تعارض الجلسات، والتدريب المسجّل شرط التأكيد. الدليل القومي لا يحجز.',
                'Operations on top of NBSLE: the calendar blocks overlapping sessions, and recorded training is required to confirm. The national catalog does not book.',
              )
            : context.t(
                'رزنامة الجهاز تمنع التعارض. إن لزم تدريب مسجّل فلن يُؤكَّد الحجز بدونه.',
                'The device calendar blocks overlaps. If training is required, booking will not confirm without it.',
              ),
        style: const TextStyle(height: 1.45, fontSize: 13),
      ),
    );
  }

  Widget _weekStrip() {
    final start = DateTime.now();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = DateTime(start.year, start.month, start.day + index);
          final key = SmartLabsService.instance.formatDate(day);
          final selected = key == _dateKey;
          return ChoiceChip(
            label: Text(
              '${day.day}/${day.month}\n${_weekday(day)}',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.2, fontSize: 12),
            ),
            selected: selected,
            onSelected: (_) => setState(() {
              _selectedDate = day;
              _selectedSlotStart = null;
            }),
          );
        },
      ),
    );
  }

  String _weekday(DateTime day) {
    const ar = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
    const en = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final i = day.weekday % 7;
    return context.t(ar[i], en[i]);
  }

  Widget _trainingGate(AcademicLab lab) {
    if (!lab.isFromFirebase) {
      return Text(
        context.t(
          'التدريب يُسجَّل بعد ربط المختبر في المنصة.',
          'Training is recorded after the lab is on the platform.',
        ),
      );
    }
    return StreamBuilder<bool>(
      stream: LabTrainingService.instance.watchCompleted(
        labId: lab.id!,
        equipmentId: widget.equipment.id,
      ),
      builder: (context, snap) {
        final done = snap.data == true;
        if (done) {
          return Card(
            color: Colors.green.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(Icons.verified, color: Colors.green),
              title: Text(
                context.t(
                  'تدريب مسجّل على هذا الجهاز',
                  'Training recorded for this device',
                ),
              ),
              subtitle: Text(
                context.t(
                  'يمكنك تأكيد موعد لا يتعارض مع حجوزات قائمة.',
                  'You can confirm a slot that does not overlap existing bookings.',
                ),
              ),
            ),
          );
        }
        return Card(
          color: Colors.orange.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(
                    'بوابة تدريب — شرط تأكيد الحجز',
                    'Training gate — required to confirm',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(
                    'أجهزة السجل القومي لا تُشغَّل بحجز تقويمي فقط. سجّل أنك اطّلعت على السلامة وحضور المشغّل عند الحاجة.',
                    'National-catalog devices are not booked by calendar alone. Record that you reviewed safety and staff presence when required.',
                  ),
                  style: const TextStyle(height: 1.4, fontSize: 13),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _safetyAck,
                  onChanged: (v) => setState(() => _safetyAck = v ?? false),
                  title: Text(
                    context.t(
                      'أقرّ بقواعد السلامة وعهدة العينة وعدم التشغيل دون تصريح المعمل.',
                      'I accept safety rules, sample custody, and no operation without lab clearance.',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: !_safetyAck || _recordingTraining
                      ? null
                      : _recordTraining,
                  icon: _recordingTraining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.school_outlined),
                  label: Text(
                    context.t('تسجيل التدريب', 'Record training'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _recordTraining() async {
    setState(() => _recordingTraining = true);
    try {
      await LabTrainingService.instance.recordSelfAttested(
        lab: _lab,
        equipment: widget.equipment,
      );
      if (!mounted) return;
      _showMessage(
        context.t('تم تسجيل التدريب — اختر موعداً', 'Training recorded — pick a slot'),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _recordingTraining = false);
    }
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: const Color(0xFFB7C3D6)))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
