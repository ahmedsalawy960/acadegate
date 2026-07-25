import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/locale/app_translate.dart';
import '../academic/academic_models.dart';
import '../moderation/content_delete_service.dart';
import '../notifications/admin_recipient_service.dart';
import '../notifications/notification_service.dart';

class TimeSlot {
  final String start;
  final String end;
  final bool isBooked;

  const TimeSlot({
    required this.start,
    required this.end,
    this.isBooked = false,
  });
}

class SmartLabsService {
  SmartLabsService._();

  static final SmartLabsService instance = SmartLabsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> defaultSlotStarts = [
    '08:00',
    '10:00',
    '12:00',
    '14:00',
  ];

  CollectionReference<Map<String, dynamic>> _bookings(String labId) =>
      _db.collection('labs').doc(labId).collection('bookings');

  CollectionReference<Map<String, dynamic>> _ratings(String labId) =>
      _db.collection('labs').doc(labId).collection('ratings');

  String formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  List<TimeSlot> buildSlots({
    required LabEquipment equipment,
    required List<LabBooking> existingBookings,
  }) {
    final durationHours = (equipment.durationMinutes / 60).ceil();
    final slots = <TimeSlot>[];

    for (final start in defaultSlotStarts) {
      final startHour = int.parse(start.split(':').first);
      final endHour = startHour + durationHours;
      if (endHour > 18) continue;

      final end = '${endHour.toString().padLeft(2, '0')}:00';
      final isBooked = existingBookings.any(
        (booking) =>
            booking.isConfirmed &&
            booking.equipmentId == equipment.id &&
            booking.slotStart == start,
      );

      slots.add(TimeSlot(start: start, end: end, isBooked: isBooked));
    }

    return slots;
  }

  Stream<List<LabBooking>> bookingsForDateStream({
    required String labId,
    required String date,
    String? equipmentId,
  }) {
    if (labId.isEmpty) {
      return Stream.value(const []);
    }

    return _bookings(labId)
        .where('date', isEqualTo: date)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => LabBooking.fromMap(
                  doc.data(),
                  id: doc.id,
                  labId: labId,
                ),
              )
              .where(
                (booking) =>
                    equipmentId == null || booking.equipmentId == equipmentId,
              )
              .toList(),
        );
  }

  Stream<List<LabBooking>> userBookingsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    return _db
        .collectionGroup('bookings')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (snapshot) {
            final bookings = snapshot.docs
                .map(
                  (doc) => LabBooking.fromMap(
                    doc.data(),
                    id: doc.id,
                    labId: doc.reference.parent.parent?.id ?? '',
                  ),
                )
                .toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
              );
            return bookings;
          },
        );
  }

  Stream<List<LabBooking>> incomingBookingsForOwnerStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _db
        .collectionGroup('bookings')
        .where('labOwnerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs
              .map(
                (doc) => LabBooking.fromMap(
                  doc.data(),
                  id: doc.id,
                  labId: doc.reference.parent.parent?.id ?? '',
                ),
              )
              .toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
            );
          return bookings;
        });
  }

  Stream<List<LabBooking>> unownedBookingsOpsStream() {
    return _db
        .collectionGroup('bookings')
        .where('needsOwnerRouting', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final bookings = snapshot.docs
              .map(
                (doc) => LabBooking.fromMap(
                  doc.data(),
                  id: doc.id,
                  labId: doc.reference.parent.parent?.id ?? '',
                ),
              )
              .where((b) => b.isConfirmed)
              .toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
            );
          return bookings;
        });
  }

  Stream<List<LabRating>> ratingsStream(String labId) {
    if (labId.isEmpty) {
      return Stream.value(const []);
    }

    return _ratings(labId).snapshots().map(
          (snapshot) {
            final ratings = snapshot.docs
                .map(
                  (doc) => LabRating.fromMap(doc.data(), id: doc.id),
                )
                .toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
              );
            return ratings;
          },
        );
  }

  Future<void> createBooking({
    required AcademicLab lab,
    required LabEquipment equipment,
    required DateTime date,
    required String slotStart,
    required String slotEnd,
    required String userName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
        appTr(
          'يجب تسجيل الدخول لحجز المختبر',
          'You must sign in to book the lab',
        ),
      );
    }
    if (!lab.isFromFirebase) {
      throw Exception(
        appTr(
          'الحجز متاح للمختبرات المسجلة في Firebase فقط',
          'Booking is available for Firebase-registered labs only',
        ),
      );
    }

    final dateKey = formatDate(date);
    final existing = await _bookings(lab.id!)
        .where('date', isEqualTo: dateKey)
        .where('equipmentId', isEqualTo: equipment.id)
        .where('slotStart', isEqualTo: slotStart)
        .where('status', isEqualTo: 'confirmed')
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        appTr(
          'هذا الموعد محجوز بالفعل — اختر وقتاً آخر',
          'This slot is already booked — choose another time',
        ),
      );
    }

    await _bookings(lab.id!).add({
      'userId': user.uid,
      'userName': userName,
      'equipmentId': equipment.id,
      'equipmentName': equipment.name,
      'date': dateKey,
      'slotStart': slotStart,
      'slotEnd': slotEnd,
      'status': 'confirmed',
      'costEstimate': equipment.costPerSession,
      'labOwnerId': lab.ownerId,
      'labName': lab.name,
      'needsOwnerRouting': lab.ownerId.trim().isEmpty,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final bookingSummary =
        '$userName — ${equipment.name} @ ${lab.name} ($dateKey $slotStart)';
    if (lab.ownerId.trim().isNotEmpty) {
      await NotificationService.instance.send(
        userId: lab.ownerId,
        title: appTr('حجز جهاز مختبر', 'Lab equipment booking'),
        body: bookingSummary,
        type: 'lab_booking',
        contextId: lab.id ?? '',
        contextType: 'lab',
      );
    } else {
      await AdminRecipientService.instance.notifyAllAdmins(
        title: appTr(
          'حجز على مختبر غير مربوط',
          'Booking on unowned lab',
        ),
        body: bookingSummary,
        type: 'lab_booking',
        contextId: lab.id ?? '',
        contextType: 'lab',
      );
    }
  }

  Future<void> cancelBooking({
    required String labId,
    required String bookingId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final ref = _bookings(labId).doc(bookingId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? {};
    final isBooker = data['userId'] == user.uid;
    final isLabOwner = data['labOwnerId'] == user.uid;
    if (!isBooker && !isLabOwner) {
      throw Exception(
        appTr(
          'لا يمكنك إلغاء هذا الحجز',
          'You cannot cancel this booking',
        ),
      );
    }

    await ref.update({'status': 'cancelled'});
  }

  Future<void> submitRating({
    required AcademicLab lab,
    required int rating,
    required String comment,
    required String userName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
        appTr(
          'يجب تسجيل الدخول لتقييم المختبر',
          'You must sign in to rate the lab',
        ),
      );
    }
    if (!lab.isFromFirebase) {
      throw Exception(
        appTr(
          'التقييم متاح للمختبرات المسجلة في Firebase فقط',
          'Ratings are available for Firebase-registered labs only',
        ),
      );
    }

    await _ratings(lab.id!).doc(user.uid).set({
      'userId': user.uid,
      'userName': userName,
      'rating': rating.clamp(1, 5),
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeEquipment({
    required AcademicLab lab,
    required String equipmentId,
  }) async {
    if (!lab.isFromFirebase) {
      throw Exception(appTr('المختبر غير مسجّل', 'Lab is not registered'));
    }
    final next = lab.devices
        .where((e) => e.id != equipmentId && e.name != equipmentId)
        .map(
          (e) => {
            'id': e.id,
            'name': e.name,
            'code': e.code,
            'costPerSession': e.costPerSession,
            'durationMinutes': e.durationMinutes,
            'waitDays': e.waitDays,
            if (e.storeCategoryTitle.isNotEmpty)
              'storeCategoryTitle': e.storeCategoryTitle,
          },
        )
        .toList();
    await _db.collection('labs').doc(lab.id).update({
      'equipmentList': next,
      'equipment': next.map((e) => e['name']).join('، '),
    });
  }

  Future<void> removeSampleService({
    required AcademicLab lab,
    required String serviceId,
  }) async {
    if (!lab.isFromFirebase) {
      throw Exception(appTr('المختبر غير مسجّل', 'Lab is not registered'));
    }
    final next = lab.sampleServices
        .where((s) => s.id != serviceId && s.name != serviceId)
        .map((s) => s.toMap())
        .toList();
    await _db.collection('labs').doc(lab.id).update({
      'sampleServices': next,
    });
  }

  /// Deletes experimental/demo labs (admin). Returns count deleted.
  Future<int> purgeExperimentalLabs() async {
    final snap = await _db.collection('labs').get();
    var deleted = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_looksExperimental(data)) continue;
      await ContentDeleteService.instance.deleteLabDocument(doc.id);
      deleted++;
    }
    return deleted;
  }

  bool _looksExperimental(Map<String, dynamic> data) {
    if (data['isDemo'] == true) return true;
    if (data['importSource']?.toString() == 'demo') return true;

    final name = (data['name'] ?? '').toString().trim().toLowerCase();
    const knownDemos = {
      'مختبر النانو',
      'nano lab',
      'مختبر تجريبي',
      'demo lab',
      'test lab',
    };
    if (knownDemos.contains(name)) return true;
    if (name.contains('تجريب') ||
        name.contains('demo') ||
        name.contains('test lab')) {
      return true;
    }

    // Egypt starter pack + any placeholder contact used example.* emails.
    final email = (data['contactEmail'] ?? '').toString().toLowerCase();
    if (email.contains('example.') ||
        email.contains('@example') ||
        email.endsWith('example.edu.eg')) {
      return true;
    }

    final tags = data['tags'];
    if (tags is List) {
      final joined = tags.map((t) => t.toString().toLowerCase()).join(' ');
      if (joined.contains('تجريب') || joined.contains('demo')) return true;
    }
    return false;
  }
}
