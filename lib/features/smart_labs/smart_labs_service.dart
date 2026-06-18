import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../academic/academic_models.dart';

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
      throw Exception('يجب تسجيل الدخول لحجز المختبر');
    }
    if (!lab.isFromFirebase) {
      throw Exception('الحجز متاح للمختبرات المسجلة في Firebase فقط');
    }

    final dateKey = formatDate(date);
    final existing = await _bookings(lab.id!)
        .where('date', isEqualTo: dateKey)
        .where('equipmentId', isEqualTo: equipment.id)
        .where('slotStart', isEqualTo: slotStart)
        .where('status', isEqualTo: 'confirmed')
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('هذا الموعد محجوز بالفعل — اختر وقتاً آخر');
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelBooking({
    required String labId,
    required String bookingId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول');
    }

    final ref = _bookings(labId).doc(bookingId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? {};
    if (data['userId'] != user.uid) {
      throw Exception('لا يمكنك إلغاء حجز شخص آخر');
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
      throw Exception('يجب تسجيل الدخول لتقييم المختبر');
    }
    if (!lab.isFromFirebase) {
      throw Exception('التقييم متاح للمختبرات المسجلة في Firebase فقط');
    }

    await _ratings(lab.id!).doc(user.uid).set({
      'userId': user.uid,
      'userName': userName,
      'rating': rating.clamp(1, 5),
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
