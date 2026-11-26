/// Limits for attachments on community replies and research discussions.
/// Keep in sync with storage.rules (community_uploads) and firestore.rules
/// (isSafeReplyAttachment).
const int kCommunityAttachmentMaxBytes = 5 * 1024 * 1024;

const Map<String, String> kCommunityAttachmentMimeByExt = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'pdf': 'application/pdf',
};

String? communityAttachmentExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return null;
  final ext = fileName.substring(dot + 1).toLowerCase();
  return kCommunityAttachmentMimeByExt.containsKey(ext) ? ext : null;
}

/// Returns an error text (Arabic, English) or null when the file is allowed.
({String ar, String en})? communityAttachmentError({
  required String fileName,
  required int sizeBytes,
}) {
  if (communityAttachmentExtension(fileName) == null) {
    return (
      ar: 'المسموح صور (PNG وJPG وWebP وGIF) وملفات PDF فقط',
      en: 'Only images (PNG, JPG, WebP, GIF) and PDF files are allowed',
    );
  }
  if (sizeBytes <= 0 || sizeBytes > kCommunityAttachmentMaxBytes) {
    return (
      ar: 'حجم الملف يجب ألا يتجاوز 5 ميجابايت',
      en: 'The file must be 5 MB or smaller',
    );
  }
  return null;
}
