import '../../core/locale/l10n_lookup.dart';

class UserRole {
  UserRole._();

  static const student = 'student';
  static const supervisor = 'supervisor';
  static const merchant = 'merchant';
  static const labManager = 'lab_manager';
  static const ideaPublisher = 'idea_publisher';
  static const writer = 'writer';
  static const admin = 'admin';

  static const all = [
    student,
    supervisor,
    merchant,
    labManager,
    ideaPublisher,
    writer,
  ];

  static String label(String? role) => L10nLookup.roleLabelStatic(role);

  static bool isAdmin(String? role) => role == admin;

  /// فقط التاجر والمدير يضيفان منتجات للمتجر.
  static bool canSellProducts(String? role) =>
      role == merchant || role == admin;

  /// تاجر أو مدير ينشر تحدياً صناعياً بعربون في صندوق التمويل.
  static bool canPostIndustryChallenge(String? role) =>
      role == merchant || role == admin;

  /// يستقبل طلبات الكتابة الواردة (كاتب / مشرف / مدير).
  static bool canReceiveWritingOrders(String? role) =>
      role == writer || role == supervisor || role == admin;

  /// ملف أكاديمي بارز للطالب/الباحث والمشرف.
  static bool showsAcademicProfile(String? role) =>
      role == student || role == supervisor;

  /// بيانات منشأة تجارية (تاجر).
  static bool showsMerchantBusiness(String? role) =>
      role == merchant || role == admin;

  /// بيانات جهة/خدمة (مختبر، مشرف، كاتب، ناشر أفكار).
  static bool showsProviderOrg(String? role) =>
      role == labManager ||
      role == supervisor ||
      role == writer ||
      role == ideaPublisher ||
      role == admin;
}
