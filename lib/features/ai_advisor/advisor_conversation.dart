import '../../core/locale/app_translate.dart';

class AdvisorConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdvisorConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AdvisorConversation.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw, DateTime fallback) {
      if (raw == null) return fallback;
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString()) ?? fallback;
    }

    final now = DateTime.now();
    return AdvisorConversation(
      id: id,
      title: map['title']?.toString().trim().isNotEmpty == true
          ? map['title'].toString()
          : appTr('محادثة جديدة', 'New conversation'),
      createdAt: parseTime(map['createdAt'], now),
      updatedAt: parseTime(map['updatedAt'], now),
    );
  }
}
