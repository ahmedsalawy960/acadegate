import 'package:flutter/material.dart';

class CommunityRoom {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const CommunityRoom({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const communityRooms = <CommunityRoom>[
  CommunityRoom(
    id: 'engineering',
    title: 'هندسة',
    description: 'نقاشات ومشاريع هندسية',
    icon: Icons.engineering_outlined,
    color: Color(0xFFE65100),
  ),
  CommunityRoom(
    id: 'science',
    title: 'علوم',
    description: 'كيمياء، فيزياء، وأبحاث علمية',
    icon: Icons.science_outlined,
    color: Color(0xFF2E7D32),
  ),
  CommunityRoom(
    id: 'medicine',
    title: 'طب',
    description: 'حالات سريرية ودراسات طبية',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFC62828),
  ),
  CommunityRoom(
    id: 'law',
    title: 'حقوق',
    description: 'قانون وبحوث قانونية',
    icon: Icons.gavel_outlined,
    color: Color(0xFF5D4037),
  ),
  CommunityRoom(
    id: 'cs',
    title: 'حاسبات',
    description: 'برمجة، ذكاء اصطناعي، وبيانات',
    icon: Icons.computer_outlined,
    color: Color(0xFF1565C0),
  ),
  CommunityRoom(
    id: 'agriculture',
    title: 'زراعة',
    description: 'أبحاث زراعية وبيئية',
    icon: Icons.agriculture_outlined,
    color: Color(0xFF558B2F),
  ),
  CommunityRoom(
    id: 'general',
    title: 'عام',
    description: 'مواضيع أكاديمية متنوعة',
    icon: Icons.forum_outlined,
    color: Color(0xFF00695C),
  ),
];

CommunityRoom? communityRoomById(String id) {
  for (final room in communityRooms) {
    if (room.id == id) return room;
  }
  return null;
}

class CommunityPostType {
  CommunityPostType._();

  static const question = 'question';
  static const discussion = 'discussion';
  static const announcement = 'announcement';
  static const studyGroup = 'study_group';

  static const labels = <String, String>{
    question: 'سؤال',
    discussion: 'نقاش',
    announcement: 'إعلان مناقشة',
    studyGroup: 'مجموعة دراسة',
  };

  static String label(String? type) => labels[type] ?? 'منشور';

  static IconData icon(String? type) {
    return switch (type) {
      question => Icons.help_outline,
      discussion => Icons.chat_bubble_outline,
      announcement => Icons.campaign_outlined,
      studyGroup => Icons.groups_outlined,
      _ => Icons.article_outlined,
    };
  }
}
