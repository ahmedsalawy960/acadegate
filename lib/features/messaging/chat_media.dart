import '../../core/locale/app_translate.dart';

enum ChatAttachmentKind {
  none,
  image,
  video,
  file,
  location,
}

extension ChatAttachmentKindX on ChatAttachmentKind {
  String get firestoreValue => switch (this) {
        ChatAttachmentKind.none => '',
        ChatAttachmentKind.image => 'image',
        ChatAttachmentKind.video => 'video',
        ChatAttachmentKind.file => 'file',
        ChatAttachmentKind.location => 'location',
      };

  static ChatAttachmentKind parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'image':
        return ChatAttachmentKind.image;
      case 'video':
        return ChatAttachmentKind.video;
      case 'file':
        return ChatAttachmentKind.file;
      case 'location':
        return ChatAttachmentKind.location;
      default:
        return ChatAttachmentKind.none;
    }
  }

  String previewLabel() {
    switch (this) {
      case ChatAttachmentKind.image:
        return appTr('صورة', 'Photo');
      case ChatAttachmentKind.video:
        return appTr('فيديو', 'Video');
      case ChatAttachmentKind.file:
        return appTr('ملف', 'File');
      case ChatAttachmentKind.location:
        return appTr('موقع', 'Location');
      case ChatAttachmentKind.none:
        return '';
    }
  }
}

class ChatAttachment {
  final ChatAttachmentKind kind;
  final String? url;
  final String? name;
  final String? mime;

  const ChatAttachment({
    this.kind = ChatAttachmentKind.none,
    this.url,
    this.name,
    this.mime,
  });

  bool get hasMedia =>
      kind != ChatAttachmentKind.none && (url ?? '').trim().isNotEmpty;

  factory ChatAttachment.fromMap(Map<String, dynamic> map) {
    return ChatAttachment(
      kind: ChatAttachmentKindX.parse(map['attachmentType']?.toString()),
      url: map['attachmentUrl']?.toString(),
      name: map['attachmentName']?.toString(),
      mime: map['attachmentMime']?.toString(),
    );
  }

  Map<String, dynamic> toFirestoreFields() {
    if (kind == ChatAttachmentKind.none) return const {};
    return {
      'attachmentType': kind.firestoreValue,
      if ((url ?? '').trim().isNotEmpty) 'attachmentUrl': url!.trim(),
      if ((name ?? '').trim().isNotEmpty) 'attachmentName': name!.trim(),
      if ((mime ?? '').trim().isNotEmpty) 'attachmentMime': mime!.trim(),
    };
  }
}

String chatLastMessagePreview({
  required String text,
  ChatAttachmentKind kind = ChatAttachmentKind.none,
}) {
  final trimmed = text.trim();
  if (trimmed.isNotEmpty) return trimmed;
  final label = kind.previewLabel();
  return label.isEmpty ? '…' : label;
}

String formatChatClock(DateTime? dt) {
  if (dt == null) return '';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatChatDayLabel(DateTime dt, {required bool isEnglish}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    return isEnglish ? 'Today' : 'اليوم';
  }
  if (diff == 1) {
    return isEnglish ? 'Yesterday' : 'أمس';
  }
  final y = dt.year.toString().padLeft(4, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y/$mo/$d';
}

String formatChatTimestamp(DateTime? dt, {required bool isEnglish}) {
  if (dt == null) return '';
  final clock = formatChatClock(dt);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return clock;
  if (diff == 1) {
    final label = isEnglish ? 'Yesterday' : 'أمس';
    return '$label $clock';
  }
  return '${formatChatDayLabel(dt, isEnglish: isEnglish)} $clock';
}

bool isSameChatDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// مجموعة إيموجي شائعة بدون حزمة خارجية.
const kChatEmojiPalette = <String>[
  '😀', '😁', '😂', '🤣', '😊', '😍', '🤩', '😘', '🤗', '🤔',
  '😎', '🥳', '😴', '😭', '😤', '🤯', '🫡', '👏', '🙌', '👍',
  '👎', '🙏', '💪', '🔥', '✨', '💯', '🎉', '❤️', '🧡', '💛',
  '💚', '💙', '💜', '🖤', '🤍', '💔', '⭐', '🌟', '✅', '❌',
  '📎', '📁', '📷', '🎥', '📍', '📚', '🧠', '🔬', '🧪', '🎓',
];
