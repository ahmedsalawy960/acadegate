import '../../core/locale/l10n_lookup.dart';

class UserRole {
  UserRole._();

  static const student = 'student';
  static const supervisor = 'supervisor';
  static const merchant = 'merchant';
  static const labManager = 'lab_manager';
  static const ideaPublisher = 'idea_publisher';
  static const admin = 'admin';

  static const all = [
    student,
    supervisor,
    merchant,
    labManager,
    ideaPublisher,
  ];

  static String label(String? role) => L10nLookup.roleLabelStatic(role);

  static bool isAdmin(String? role) => role == admin;

  /// فقط التاجر والمدير يضيفان منتجات للمتجر.
  static bool canSellProducts(String? role) =>
      role == merchant || role == admin;
}
