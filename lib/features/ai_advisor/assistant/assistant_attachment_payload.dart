/// Builds one academicAssistant attachment without losing its filename.
/// The server uses that filename to select the inline file validator.
Map<String, dynamic> buildAssistantAttachmentPayload({
  required String fileName,
  required String mimeType,
  required String base64Data,
  String? storagePath,
}) => {
  'fileName': fileName,
  'mimeType': mimeType,
  if (base64Data.trim().isNotEmpty) 'base64Data': base64Data,
  if (storagePath != null && storagePath.trim().isNotEmpty)
    'storagePath': storagePath,
};
