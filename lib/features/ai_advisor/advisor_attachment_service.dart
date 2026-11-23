import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../core/locale/app_translate.dart';
import 'advisor_attachment.dart';

class AdvisorAttachmentService {
  AdvisorAttachmentService._();

  static final AdvisorAttachmentService instance = AdvisorAttachmentService._();

  static const maxBytes = 10 * 1024 * 1024;
  static const maxAttachmentsPerMessage = 4;

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const mimeByExtension = <String, String>{
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'doc': 'application/msword',
    'xls': 'application/vnd.ms-excel',
    'ppt': 'application/vnd.ms-powerpoint',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'csv': 'text/csv',
    'tsv': 'text/tab-separated-values',
  };

  Future<PendingAdvisorAttachment?> pickImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final pending = _pendingFromBytes(
      bytes: bytes,
      name: file.name,
      mimeType: _mimeFromName(file.name, fallback: 'image/jpeg'),
      isImage: true,
    );
    return normalizeImageForGemini(pending);
  }

  /// التقاط صورة بالكاميرا لفحص خطوة التركيب / الواقع المعزّز المبسط.
  Future<PendingAdvisorAttachment?> pickFromCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final pending = _pendingFromBytes(
      bytes: bytes,
      name: file.name.isNotEmpty ? file.name : 'camera_step.jpg',
      mimeType: _mimeFromName(file.name, fallback: 'image/jpeg'),
      isImage: true,
    );
    return normalizeImageForGemini(pending);
  }

  Future<PendingAdvisorAttachment?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: mimeByExtension.keys.toList(),
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final mime = _mimeFromName(file.name, fallback: 'application/octet-stream');
    final pending = _pendingFromBytes(
      bytes: bytes,
      name: file.name,
      mimeType: mime,
      isImage: mime.startsWith('image/'),
    );
    if (!pending.isImage) return pending;
    return normalizeImageForGemini(pending);
  }

  /// يحوّل WebP/GIF وغيرها إلى JPEG — Gemini على السحابة يفشل أحياناً مع WebP من أمازون.
  PendingAdvisorAttachment normalizeImageForGemini(
    PendingAdvisorAttachment item,
  ) {
    if (!item.isImage || item.bytes.isEmpty) return item;
    final lowerMime = item.mimeType.toLowerCase();
    final lowerName = item.name.toLowerCase();
    final alreadyJpeg =
        lowerMime.contains('jpeg') || lowerMime.contains('jpg');
    final looksWebp = lowerMime.contains('webp') || lowerName.endsWith('.webp');
    final looksGif = lowerMime.contains('gif') || lowerName.endsWith('.gif');
    // JPEG الصغير الواضح نتركه؛ الباقي نعيد ترميزه لضمان توافق Gemini.
    if (alreadyJpeg && !looksWebp && item.bytes.length < 2 * 1024 * 1024) {
      return item;
    }

    try {
      final decoded = img.decodeImage(Uint8List.fromList(item.bytes));
      if (decoded == null) {
        if (looksWebp || looksGif) {
          throw Exception(appTr(
            'تعذر تحويل الصورة (WebP/GIF). احفظها كـ JPG أو PNG ثم أعد الرفع.',
            'Could not convert this image (WebP/GIF). Save as JPG/PNG and re-upload.',
          ));
        }
        return item;
      }
      final resized = decoded.width > 1600 || decoded.height > 1600
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? 1600 : null,
              height: decoded.height > decoded.width ? 1600 : null,
            )
          : decoded;
      final jpg = img.encodeJpg(resized, quality: 88);
      final base = item.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      return PendingAdvisorAttachment(
        name: '${base.isEmpty ? 'diagram' : base}.jpg',
        mimeType: 'image/jpeg',
        bytes: jpg,
        isImage: true,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      return item;
    }
  }

  /// يرفع الصورة إلى Storage ويرسل المسار لـ Gemini (أفضل من base64 الكبير على Windows).
  Future<List<GeminiInlinePart>> prepareGeminiParts(
    List<PendingAdvisorAttachment> pending, {
    String conversationId = 'custom_fit',
    bool preferStorage = true,
  }) async {
    if (pending.isEmpty) return const [];

    final normalized = <PendingAdvisorAttachment>[];
    for (final item in pending) {
      normalized.add(
        item.isImage ? normalizeImageForGemini(item) : item,
      );
    }

    _assertMessageLimits(normalized);
    final user = FirebaseAuth.instance.currentUser;
    final useStorage = preferStorage && user != null;
    if (!useStorage) {
      return toGeminiParts(normalized);
    }

    try {
      final parts = <GeminiInlinePart>[];
      for (final item in normalized) {
        final mime = _requiredMime(item);
        final safeName = item.name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
        final path =
            'uploads/${user.uid}/advisor/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
        final ref = _storage.ref().child(path);
        await ref.putData(
          Uint8List.fromList(item.bytes),
          SettableMetadata(contentType: mime),
        );
        parts.add(
          GeminiInlinePart(
            mimeType: mime,
            base64Data: '',
            fileName: item.name,
            storagePath: path,
          ),
        );
      }
      return parts;
    } catch (_) {
      // إن فشل الرفع نرسل الصورة مباشرة (base64)
      return toGeminiParts(normalized);
    }
  }

  PendingAdvisorAttachment _pendingFromBytes({
    required List<int> bytes,
    required String name,
    required String mimeType,
    required bool isImage,
  }) {
    if (bytes.length > maxBytes) {
      throw Exception(appTr(
        'حجم الملف يجب ألا يتجاوز 10 ميجابايت',
        'File size must not exceed 10 MB',
      ));
    }
    if (!_isAllowedMime(mimeType)) {
      throw Exception(appTr(
        'نوع الملف غير مدعوم. المسموح: صور، PDF، Word، Excel، PowerPoint، أو نص.',
        'Unsupported file type. Allowed: images, PDF, Word, Excel, PowerPoint, or text.',
      ));
    }

    return PendingAdvisorAttachment(
      name: name,
      mimeType: mimeType,
      bytes: bytes,
      isImage: isImage,
    );
  }

  bool _isAllowedMime(String mime) => mimeByExtension.containsValue(mime);

  String _extensionOf(String name) {
    final base = name.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    if (dot < 0 || dot == base.length - 1) return '';
    return base.substring(dot + 1).toLowerCase();
  }

  String _mimeFromName(String name, {required String fallback}) {
    return mimeByExtension[_extensionOf(name)] ?? fallback;
  }

  void _assertMessageLimits(List<PendingAdvisorAttachment> items) {
    if (items.length > maxAttachmentsPerMessage) {
      throw Exception(appTr(
        'يمكن إرفاق $maxAttachmentsPerMessage ملفات كحد أقصى',
        'You can attach up to $maxAttachmentsPerMessage files',
      ));
    }
    for (final item in items) {
      if (item.bytes.length > maxBytes) {
        throw Exception(appTr(
          'حجم الملف يجب ألا يتجاوز 10 ميجابايت',
          'File size must not exceed 10 MB',
        ));
      }
      if (!_isAllowedMime(_mimeFromName(item.name, fallback: item.mimeType))) {
        throw Exception(appTr(
          'نوع الملف غير مدعوم. المسموح: صور، PDF، Word، Excel، PowerPoint، أو نص.',
          'Unsupported file type. Allowed: images, PDF, Word, Excel, PowerPoint, or text.',
        ));
      }
    }
  }

  String _requiredMime(PendingAdvisorAttachment item) {
    final mime = mimeByExtension[_extensionOf(item.name)] ?? '';
    if (!_isAllowedMime(mime)) {
      throw Exception(appTr(
        'نوع الملف غير مدعوم. المسموح: صور، PDF، Word، Excel، PowerPoint، أو نص.',
        'Unsupported file type. Allowed: images, PDF, Word, Excel, PowerPoint, or text.',
      ));
    }
    return mime;
  }

  List<GeminiInlinePart> toGeminiParts(List<PendingAdvisorAttachment> pending) {
    _assertMessageLimits(pending);
    return pending
        .map(
          (item) => GeminiInlinePart(
            mimeType: _requiredMime(item),
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

    _assertMessageLimits(pending);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return pending
          .map(
            (item) => AdvisorAttachment(
              name: item.name,
              mimeType: _requiredMime(item),
              url: '',
              isImage: item.isImage,
            ),
          )
          .toList();
    }

    final uploaded = <AdvisorAttachment>[];
    for (final item in pending) {
      final mime = _requiredMime(item);
      final safeName = item.name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
      final path =
          'uploads/${user.uid}/advisor/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final ref = _storage.ref().child(path);
      await ref.putData(
        Uint8List.fromList(item.bytes),
        SettableMetadata(contentType: mime),
      );
      final url = await ref.getDownloadURL();
      uploaded.add(
        AdvisorAttachment(
          name: item.name,
          mimeType: mime,
          url: url,
          isImage: item.isImage,
        ),
      );
    }
    return uploaded;
  }
}
