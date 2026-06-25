import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'advisor_attachment.dart';

class AdvisorAttachmentService {
  AdvisorAttachmentService._();

  static final AdvisorAttachmentService instance = AdvisorAttachmentService._();

  static const maxBytes = 10 * 1024 * 1024;
  static const maxAttachmentsPerMessage = 4;

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const _allowedMimePrefixes = [
    'image/',
    'application/pdf',
    'text/plain',
    'text/csv',
    'application/msword',
    'application/vnd.openxmlformats-officedocument',
  ];

  Future<PendingAdvisorAttachment?> pickImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return _pendingFromBytes(
      bytes: bytes,
      name: file.name,
      mimeType: _mimeFromName(file.name, fallback: 'image/jpeg'),
      isImage: true,
    );
  }

  Future<PendingAdvisorAttachment?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'txt',
        'csv',
        'doc',
        'docx',
        'png',
        'jpg',
        'jpeg',
        'webp',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final mime = _mimeFromName(file.name, fallback: 'application/octet-stream');
    return _pendingFromBytes(
      bytes: bytes,
      name: file.name,
      mimeType: mime,
      isImage: mime.startsWith('image/'),
    );
  }

  PendingAdvisorAttachment? _pendingFromBytes({
    required List<int> bytes,
    required String name,
    required String mimeType,
    required bool isImage,
  }) {
    if (bytes.length > maxBytes) {
      throw Exception('حجم الملف يجب ألا يتجاوز 10 ميجابايت');
    }
    if (!_isAllowedMime(mimeType)) {
      throw Exception('نوع الملف غير مدعوم. جرّب صورة أو PDF أو Word أو نص.');
    }

    return PendingAdvisorAttachment(
      name: name,
      mimeType: mimeType,
      bytes: bytes,
      isImage: isImage,
    );
  }

  bool _isAllowedMime(String mime) {
    return _allowedMimePrefixes.any((prefix) => mime.startsWith(prefix));
  }

  String _mimeFromName(String name, {required String fallback}) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => fallback,
    };
  }

  List<GeminiInlinePart> toGeminiParts(List<PendingAdvisorAttachment> pending) {
    return pending
        .map(
          (item) => GeminiInlinePart(
            mimeType: item.mimeType,
            base64Data: base64Encode(item.bytes),
            fileName: item.name,
          ),
        )
        .toList();
  }

  Future<List<AdvisorAttachment>> uploadAll({
    required List<PendingAdvisorAttachment> pending,
    required String conversationId,
  }) async {
    if (pending.isEmpty) return [];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return pending
          .map(
            (item) => AdvisorAttachment(
              name: item.name,
              mimeType: item.mimeType,
              url: '',
              isImage: item.isImage,
            ),
          )
          .toList();
    }

    final uploaded = <AdvisorAttachment>[];
    for (final item in pending) {
      final safeName = item.name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
      final path =
          'uploads/${user.uid}/advisor/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final ref = _storage.ref().child(path);
      await ref.putData(
        Uint8List.fromList(item.bytes),
        SettableMetadata(contentType: item.mimeType),
      );
      final url = await ref.getDownloadURL();
      uploaded.add(
        AdvisorAttachment(
          name: item.name,
          mimeType: item.mimeType,
          url: url,
          isImage: item.isImage,
        ),
      );
    }
    return uploaded;
  }
}
