import 'package:acadegate/features/auth/personal_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone', () {
    test('accepts Egyptian mobile formats', () {
      expect(PersonalInfo.normalizePhone('01012345678'), '+201012345678');
      expect(PersonalInfo.normalizePhone('010 1234 5678'), '+201012345678');
      expect(PersonalInfo.normalizePhone('+201112345678'), '+201112345678');
      expect(PersonalInfo.normalizePhone('201212345678'), '+201212345678');
      expect(PersonalInfo.normalizePhone('00201512345678'), '+201512345678');
      expect(PersonalInfo.normalizePhone('٠١٠١٢٣٤٥٦٧٨'), '+201012345678');
    });

    test('accepts international numbers with +', () {
      expect(PersonalInfo.normalizePhone('+966501234567'), '+966501234567');
    });

    test('rejects invalid numbers', () {
      expect(PersonalInfo.normalizePhone(''), isNull);
      expect(PersonalInfo.normalizePhone('0101234567'), isNull);
      expect(PersonalInfo.normalizePhone('01312345678'), isNull);
      expect(PersonalInfo.normalizePhone('0223456789'), isNull);
      expect(PersonalInfo.normalizePhone('abc'), isNull);
    });
  });

  test('ageOn handles birthdays not yet reached', () {
    final birth = DateTime(2000, 6, 15);
    expect(PersonalInfo.ageOn(birth, DateTime(2026, 6, 14)), 25);
    expect(PersonalInfo.ageOn(birth, DateTime(2026, 6, 15)), 26);
  });

  test('map round-trip and completeness', () {
    final info = PersonalInfo(
      phone: '+201012345678',
      gender: Gender.female,
      birthDate: DateTime(1999, 3, 7),
      governorate: 'القاهرة',
    );
    final back = PersonalInfo.fromMap(info.toMap());
    expect(back.isComplete, isTrue);
    expect(back.birthDate, DateTime(1999, 3, 7));
    expect(info.toMap()['birthDate'], '1999-03-07');
    expect(const PersonalInfo().isComplete, isFalse);
  });
}
