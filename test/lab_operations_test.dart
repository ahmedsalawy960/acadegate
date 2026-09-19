import 'package:acadegate/features/academic/academic_models.dart';
import 'package:acadegate/features/smart_labs/lab_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlapping sessions on the same device are blocked', () {
    const existing = [
      LabBooking(
        labId: 'lab1',
        userId: 'u1',
        userName: 'A',
        equipmentId: 'hplc',
        equipmentName: 'HPLC',
        date: '2026-09-06',
        slotStart: '08:00',
        slotEnd: '11:00',
      ),
    ];
    expect(
      LabOperations.conflictsWithExisting(
        existing: existing,
        equipmentId: 'hplc',
        start: '10:00',
        end: '12:00',
      ),
      isTrue,
    );
    expect(
      LabOperations.conflictsWithExisting(
        existing: existing,
        equipmentId: 'hplc',
        start: '12:00',
        end: '14:00',
      ),
      isFalse,
    );
    expect(
      LabOperations.conflictsWithExisting(
        existing: existing,
        equipmentId: 'nmr',
        start: '10:00',
        end: '12:00',
      ),
      isFalse,
    );
  });

  test('cancelled bookings do not block the calendar', () {
    const existing = [
      LabBooking(
        labId: 'lab1',
        userId: 'u1',
        userName: 'A',
        equipmentId: 'hplc',
        equipmentName: 'HPLC',
        date: '2026-09-06',
        slotStart: '08:00',
        slotEnd: '10:00',
        status: 'cancelled',
      ),
    ];
    expect(
      LabOperations.conflictsWithExisting(
        existing: existing,
        equipmentId: 'hplc',
        start: '08:00',
        end: '10:00',
      ),
      isFalse,
    );
  });

  test('NBSLE catalog devices require a training gate by default', () {
    const hplc = LabEquipment(id: '1', name: 'HPLC Alliance');
    const stirrer = LabEquipment(id: '2', name: 'Magnetic stirrer');
    const waived = LabEquipment(
      id: '3',
      name: 'HPLC',
      trainingRequired: false,
    );

    expect(
      LabOperations.needsTrainingGate(equipment: hplc, nbsleLab: false),
      isTrue,
    );
    expect(
      LabOperations.needsTrainingGate(equipment: stirrer, nbsleLab: true),
      isTrue,
    );
    expect(
      LabOperations.needsTrainingGate(equipment: stirrer, nbsleLab: false),
      isFalse,
    );
    expect(
      LabOperations.needsTrainingGate(equipment: waived, nbsleLab: true),
      isFalse,
    );
  });

  test('day lock rejects overlapping intervals for the same device date', () {
    final lockId = LabOperations.dayLockId(
      equipmentId: 'HPLC Alliance',
      date: '2026-09-06',
    );
    expect(lockId, isNot(contains(' ')));

    final intervals = LabOperations.readIntervals({
      'intervals': [
        {'start': '08:00', 'end': '11:00', 'bookingId': 'a'},
      ],
    });
    expect(
      LabOperations.intervalsOverlap(
        intervals,
        start: '10:00',
        end: '12:00',
      ),
      isTrue,
    );
    expect(
      LabOperations.intervalsOverlap(
        intervals,
        start: '12:00',
        end: '14:00',
      ),
      isFalse,
    );
  });
}
