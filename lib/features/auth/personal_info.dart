import 'package:cloud_firestore/cloud_firestore.dart';

class Gender {
  static const male = 'male';
  static const female = 'female';

  static const all = [male, female];

  static String labelAr(String? g) => g == female ? 'أنثى' : 'ذكر';
  static String labelEn(String? g) => g == female ? 'Female' : 'Male';
}

/// Private personal details stored on `users/{uid}` (owner/admin read only).
class PersonalInfo {
  final String phone;
  final String gender;
  final DateTime? birthDate;
  final String governorate;

  const PersonalInfo({
    this.phone = '',
    this.gender = '',
    this.birthDate,
    this.governorate = '',
  });

  static const minAge = 15;
  static const maxAge = 100;

  bool get isComplete =>
      Gender.all.contains(gender) && governorate.trim().isNotEmpty;

  int? get age => birthDate == null ? null : ageOn(birthDate!, DateTime.now());

  static int ageOn(DateTime birth, DateTime today) {
    var years = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      years--;
    }
    return years;
  }

  /// Egyptian mobile: accepts 01xxxxxxxxx, 201xxxxxxxxx, +201xxxxxxxxx.
  /// Returns `+201xxxxxxxxx` or null when invalid.
  static String? normalizeEgyptPhone(String raw) {
    var digits = raw
        .replaceAll(RegExp(r'[\s\-()]'), '')
        .replaceAllMapped(
          RegExp('[٠-٩]'),
          (m) => (m.group(0)!.codeUnitAt(0) - 0x0660).toString(),
        );
    if (digits.startsWith('+')) digits = digits.substring(1);
    if (digits.startsWith('0020')) digits = digits.substring(2);
    if (digits.startsWith('20')) digits = '0${digits.substring(2)}';
    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(digits)) return null;
    return '+2$digits';
  }

  /// Egyptian mobile, or an international number written with `+` (8–15 digits).
  static String? normalizePhone(String raw) {
    final egypt = normalizeEgyptPhone(raw);
    if (egypt != null) return egypt;
    final compact = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(compact)) return compact;
    return null;
  }

  /// Local display form `01xxxxxxxxx`.
  static String localPhone(String stored) {
    final s = stored.trim();
    if (s.startsWith('+20')) return '0${s.substring(3)}';
    return s;
  }

  factory PersonalInfo.fromMap(Map<String, dynamic> map) {
    DateTime? birth;
    final raw = map['birthDate'];
    if (raw is Timestamp) {
      birth = raw.toDate();
    } else if (raw is String && raw.trim().isNotEmpty) {
      birth = DateTime.tryParse(raw.trim());
    }
    return PersonalInfo(
      phone: map['phone']?.toString() ?? '',
      gender: map['gender']?.toString() ?? '',
      birthDate: birth,
      governorate: map['governorate']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'phone': phone.trim(),
        'gender': gender,
        if (birthDate != null)
          'birthDate':
              '${birthDate!.year.toString().padLeft(4, '0')}-'
              '${birthDate!.month.toString().padLeft(2, '0')}-'
              '${birthDate!.day.toString().padLeft(2, '0')}',
        'governorate': governorate.trim(),
      };
}

class EgyptGovernorates {
  static const all = <(String, String)>[
    ('القاهرة', 'Cairo'),
    ('الجيزة', 'Giza'),
    ('الإسكندرية', 'Alexandria'),
    ('القليوبية', 'Qalyubia'),
    ('الدقهلية', 'Dakahlia'),
    ('الشرقية', 'Sharqia'),
    ('الغربية', 'Gharbia'),
    ('المنوفية', 'Monufia'),
    ('كفر الشيخ', 'Kafr El Sheikh'),
    ('البحيرة', 'Beheira'),
    ('دمياط', 'Damietta'),
    ('بورسعيد', 'Port Said'),
    ('الإسماعيلية', 'Ismailia'),
    ('السويس', 'Suez'),
    ('شمال سيناء', 'North Sinai'),
    ('جنوب سيناء', 'South Sinai'),
    ('الفيوم', 'Faiyum'),
    ('بني سويف', 'Beni Suef'),
    ('المنيا', 'Minya'),
    ('أسيوط', 'Asyut'),
    ('سوهاج', 'Sohag'),
    ('قنا', 'Qena'),
    ('الأقصر', 'Luxor'),
    ('أسوان', 'Aswan'),
    ('البحر الأحمر', 'Red Sea'),
    ('الوادي الجديد', 'New Valley'),
    ('مطروح', 'Matrouh'),
    ('خارج مصر', 'Outside Egypt'),
  ];
}
