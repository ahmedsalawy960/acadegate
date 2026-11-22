/// قواعد إنشاء كلمة مرور جديدة. الدخول بكلمة موجودة لا يستخدم هذا الفحص.
class PasswordStrength {
  const PasswordStrength(this.value);

  final String value;

  bool get longEnough => value.length >= 8;

  bool get hasCapital => RegExp('[A-Z]').hasMatch(value);

  bool get hasLetterAndNumber =>
      RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(value) &&
      RegExp('[0-9]').hasMatch(value);

  /// حروف وأرقام فقط، من غير مسافات أو رموز.
  bool get lettersAndDigitsOnly =>
      value.isNotEmpty &&
      RegExp(r'^[A-Za-z0-9\u0600-\u06FF]+$').hasMatch(value);

  List<bool> get checks =>
      [longEnough, hasCapital, hasLetterAndNumber, lettersAndDigitsOnly];

  int get metCount => checks.where((ok) => ok).length;

  bool get isStrong => metCount == 4;

  bool get isWeak => value.isNotEmpty && metCount < 4;
}
