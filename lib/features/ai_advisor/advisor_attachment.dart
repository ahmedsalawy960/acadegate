class AdvisorAttachment {
  final String name;
  final String mimeType;
  final String url;
  final bool isImage;

  const AdvisorAttachment({
    required this.name,
    required this.mimeType,
    required this.url,
    required this.isImage,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mimeType': mimeType,
      'url': url,
      'isImage': isImage,
    };
  }

  factory AdvisorAttachment.fromMap(Map<String, dynamic> map) {
    final mime = map['mimeType']?.toString() ?? 'application/octet-stream';
    return AdvisorAttachment(
      name: map['name']?.toString() ?? 'مرفق',
      mimeType: mime,
      url: map['url']?.toString() ?? '',
      isImage: map['isImage'] == true || mime.startsWith('image/'),
    );
  }
}

/// مرفق قبل الرفع — يُحفظ مؤقتاً في الذاكرة حتى الإرسال.
class PendingAdvisorAttachment {
  final String name;
  final String mimeType;
  final List<int> bytes;
  final bool isImage;

  const PendingAdvisorAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
    required this.isImage,
  });
}

/// جزء لإرسال Gemini (صورة أو ملف).
class GeminiInlinePart {
  final String mimeType;
  final String base64Data;
  final String fileName;

  const GeminiInlinePart({
    required this.mimeType,
    required this.base64Data,
    required this.fileName,
  });
}
