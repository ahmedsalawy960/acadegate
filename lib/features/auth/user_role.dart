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

  static const labels = <String, String>{
    student: 'طالب / باحث',
    supervisor: 'مشرف أكاديمي',
    merchant: 'تاجر / مورد',
    labManager: 'مسؤول مختبر',
    ideaPublisher: 'ناشر أفكار بحثية',
    admin: 'مدير النظام',
  };

  static String label(String? role) {
    return labels[role] ?? role ?? 'مستخدم';
  }

  static bool isAdmin(String? role) => role == admin;
}
