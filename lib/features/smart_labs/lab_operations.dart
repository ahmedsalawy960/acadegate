import '../academic/academic_models.dart';

/// Operational rules on top of the NBSLE catalog: overlap calendar + training gate.
class LabOperations {
  LabOperations._();

  static const _instrumentHints = [
    'hplc',
    'uhplc',
    'nmr',
    'sem',
    'tem',
    'xrd',
    'xrf',
    'gc-ms',
    'gcms',
    'lc-ms',
    'lcms',
    'icp',
    'ftir',
    'confocal',
    'cytometr',
    'autoclave',
    'spectrom',
    'diffract',
    'microscope',
    'pcr',
    'qpcr',
    'sequenc',
    'كرومات',
    'مطياف',
    'مجهر',
    'تعقيم',
    'رنين',
    'حيود',
  ];

  static int minutesOf(String hhmm) {
    final parts = hhmm.trim().split(RegExp(r'[:.]'));
    if (parts.isEmpty) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  static bool slotsOverlap({
    required String startA,
    required String endA,
    required String startB,
    required String endB,
  }) {
    return minutesOf(startA) < minutesOf(endB) &&
        minutesOf(startB) < minutesOf(endA);
  }

  static bool conflictsWithExisting({
    required List<LabBooking> existing,
    required String equipmentId,
    required String start,
    required String end,
  }) {
    return existing.any(
      (booking) =>
          booking.isConfirmed &&
          booking.equipmentId == equipmentId &&
          slotsOverlap(
            startA: booking.slotStart,
            endA: booking.slotEnd.isEmpty ? booking.slotStart : booking.slotEnd,
            startB: start,
            endB: end,
          ),
    );
  }

  static bool inferInstrumentTraining(String name) {
    final n = name.toLowerCase();
    return _instrumentHints.any(n.contains);
  }

  /// NBSLE catalog devices default to a training gate unless explicitly waived.
  static bool needsTrainingGate({
    required LabEquipment equipment,
    bool nbsleLab = false,
  }) {
    if (equipment.trainingRequired == true) return true;
    if (equipment.trainingRequired == false) return false;
    if (inferInstrumentTraining(equipment.name)) return true;
    return nbsleLab;
  }

  static String trainingDocId({
    required String labId,
    required String equipmentId,
  }) {
    final raw = '${labId}_$equipmentId';
    return raw.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  }

  static String dayLockId({
    required String equipmentId,
    required String date,
  }) {
    final raw = '${equipmentId}_$date';
    return raw.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  }

  static List<({String start, String end, String bookingId})> readIntervals(
    Map<String, dynamic>? data,
  ) {
    final raw = data?['intervals'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return (
        start: map['start']?.toString() ?? '',
        end: map['end']?.toString() ?? '',
        bookingId: map['bookingId']?.toString() ?? '',
      );
    }).where((i) => i.start.isNotEmpty && i.end.isNotEmpty).toList();
  }

  static bool intervalsOverlap(
    List<({String start, String end, String bookingId})> intervals, {
    required String start,
    required String end,
  }) {
    return intervals.any(
      (i) => slotsOverlap(
        startA: i.start,
        endA: i.end,
        startB: start,
        endB: end,
      ),
    );
  }

  static List<Map<String, String>> writeIntervals(
    List<({String start, String end, String bookingId})> intervals,
  ) {
    return [
      for (final i in intervals)
        {'start': i.start, 'end': i.end, 'bookingId': i.bookingId},
    ];
  }
}
