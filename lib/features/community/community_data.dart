import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';
import '../academic/faculty_categories.dart';

class CommunityRoom {
  final String id;
  final IconData icon;
  final Color color;

  const CommunityRoom({
    required this.id,
    required this.icon,
    required this.color,
  });

  String get title => L10nLookup.communityRoomTitle(id);
  String get description => L10nLookup.communityRoomDescription(id);

  /// Faculty category id when this room maps to a faculty; null for general.
  String? get facultyCategoryId => id == 'general' ? null : id;
}

/// Legacy lowercase room ids → canonical faculty category ids.
const Map<String, String> communityRoomLegacyAliases = {
  'engineering': 'Engineering',
  'science': 'Science',
  'medicine': 'Medicine',
  'law': 'Law',
  'cs': 'CS',
  'agriculture': 'Agriculture',
};

const Map<String, String> communityRoomCanonicalToLegacy = {
  'Engineering': 'engineering',
  'Science': 'science',
  'Medicine': 'medicine',
  'Law': 'law',
  'CS': 'cs',
  'Agriculture': 'agriculture',
};

/// All faculty rooms + a general catch-all (canonical faculty ids).
final List<CommunityRoom> communityRooms = [
  ...facultyCategories.map(
    (faculty) => CommunityRoom(
      id: faculty.id,
      icon: faculty.icon,
      color: faculty.color,
    ),
  ),
  const CommunityRoom(
    id: 'general',
    icon: Icons.forum_outlined,
    color: Color(0xFF00695C),
  ),
];

String normalizeCommunityRoomId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return trimmed;
  return communityRoomLegacyAliases[trimmed] ?? trimmed;
}

/// Ids to query in Firestore so legacy + new posts both appear.
List<String> communityRoomQueryIds(String roomId) {
  final canonical = normalizeCommunityRoomId(roomId);
  final legacy = communityRoomCanonicalToLegacy[canonical];
  if (legacy != null && legacy != canonical) {
    return [canonical, legacy];
  }
  return [canonical];
}

CommunityRoom? communityRoomById(String id) {
  final canonical = normalizeCommunityRoomId(id);
  for (final room in communityRooms) {
    if (room.id == canonical || room.id == id) return room;
  }
  return null;
}

/// Rooms ordered with [preferredFacultyId] first when it matches a room.
List<CommunityRoom> communityRoomsPinnedFirst(String? preferredFacultyId) {
  if (preferredFacultyId == null || preferredFacultyId.trim().isEmpty) {
    return List<CommunityRoom>.from(communityRooms);
  }
  final preferred = normalizeCommunityRoomId(preferredFacultyId);
  final pinned = <CommunityRoom>[];
  final rest = <CommunityRoom>[];
  for (final room in communityRooms) {
    if (room.id == preferred) {
      pinned.add(room);
    } else {
      rest.add(room);
    }
  }
  return [...pinned, ...rest];
}

class CommunityPostType {
  CommunityPostType._();

  static const question = 'question';
  static const discussion = 'discussion';
  static const announcement = 'announcement';
  static const studyGroup = 'study_group';

  static const allTypes = [question, discussion, announcement, studyGroup];

  static String label(String? type) => L10nLookup.communityPostTypeLabel(type);

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

/// Who can see a community post.
class PostAudienceScope {
  PostAudienceScope._();

  /// Everyone in the faculty room (all specializations).
  static const faculty = 'faculty';

  /// Only viewers whose specialization matches [targetSpecialization].
  static const specialization = 'specialization';

  /// Everyone in the app (general master's / PhD topics).
  static const app = 'app';

  static const all = [faculty, specialization, app];

  static String label(String? scope, {required bool english}) {
    return switch (scope) {
      specialization => english
          ? 'Specific specialization'
          : 'تخصص محدد',
      app => english
          ? 'Everyone in the app'
          : 'الجميع في التطبيق',
      _ => english
          ? 'All faculty specializations'
          : 'كل تخصصات الكلية',
    };
  }

  static IconData icon(String? scope) {
    return switch (scope) {
      specialization => Icons.school_outlined,
      app => Icons.public,
      _ => Icons.apartment_outlined,
    };
  }

  static bool specializationMatches(String viewer, String target) {
    final a = viewer.trim().toLowerCase();
    final b = target.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a);
  }
}
