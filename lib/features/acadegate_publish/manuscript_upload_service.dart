import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/locale/app_translate.dart';
import 'manuscript_image_session_cache.dart';
import 'publish_models.dart';

/// Last picked manuscript bytes, so formatting can read the file on-device
/// instead of waiting for a cloud function.
class ManuscriptFileBytesCache {
  ManuscriptFileBytesCache._();
  static final Map<String, Uint8List> _store = {};

  static String _key(String manuscriptId, String name) =>
      '$manuscriptId|${name.toLowerCase()}';

  static void store(String manuscriptId, String name, Uint8List bytes) {
    if (manuscriptId.isEmpty || name.isEmpty || bytes.isEmpty) return;
    _store[_key(manuscriptId, name)] = bytes;
  }

  static Uint8List? read(String manuscriptId, String name) =>
      _store[_key(manuscriptId, name)];
}

/// Prefer the original paper DOCX (largest, not a journal template).
ManuscriptAttachment? preferredSourceDocx(
  List<ManuscriptAttachment> attachments,
) {
  final docs = attachments.where((a) {
    final n = a.name.toLowerCase();
    return n.endsWith('.docx');
  }).toList();
  if (docs.isEmpty) return null;

  int score(ManuscriptAttachment a) {
    final n = a.name.toLowerCase();
    var s = a.sizeBytes;
    if (n.contains('template') ||
        n.contains('قالب') ||
        n.contains('guidelines') ||
        n.contains('guide')) {
      s -= 100000000;
    }
    return s;
  }

  docs.sort((a, b) => score(b).compareTo(score(a)));
  return docs.first;
}

class ManuscriptUploadService {

  ManuscriptUploadService._();



  static final ManuscriptUploadService instance = ManuscriptUploadService._();



  static const maxImageBytes = 8 * 1024 * 1024;

  static const maxDocumentBytes = 24 * 1024 * 1024;

  static const maxImportImagesPerBatch = 120;
  static const maxTableCellImagesPerBatch = 200;



  final FirebaseStorage _storage = FirebaseStorage.instance;

  final ImagePicker _imagePicker = ImagePicker();

  Future<void>? _uploadQueue;



  Future<String> uploadImage({
    required String manuscriptId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxImageBytes) {
      throw Exception(appTr(
        'حجم الصورة يجب ألا يتجاوز 8 ميجابايت',
        'Image must not exceed 8 MB',
      ));
    }
    final ext = _safeImageExt(file.name);
    return _putBytes(
      manuscriptId: manuscriptId,
      bytes: bytes,
      fileName: 'figure_${DateTime.now().millisecondsSinceEpoch}.$ext',
      contentType: 'image/$ext',
    );
  }

  /// Upload `data:` image URIs to Storage so figures survive app restart / Word export.
  Future<List<ManuscriptBlock>> persistDataUriImages({
    required String manuscriptId,
    required List<ManuscriptBlock> blocks,
  }) async {
    Future<String> uploadDataUri(String dataUri, String key) async {
      final comma = dataUri.indexOf(',');
      if (comma < 0) return dataUri;
      final header = dataUri.substring(0, comma);
      final mime = header.replaceFirst('data:', '').split(';').first;
      if (!mime.startsWith('image/')) return dataUri;
      final raw = base64Decode(dataUri.substring(comma + 1));
      if (raw.isEmpty || raw.length > maxImageBytes) return dataUri;
      final ext = _safeImageExt(mime.contains('png')
          ? 'x.png'
          : mime.contains('webp')
              ? 'x.webp'
              : mime.contains('gif')
                  ? 'x.gif'
                  : 'x.jpg');
      final url = await _putBytes(
        manuscriptId: manuscriptId,
        bytes: Uint8List.fromList(raw),
        fileName:
            'figure_${key.replaceAll(RegExp(r'[^\w\-]+'), '_')}.$ext',
        contentType: mime,
      );
      ManuscriptImageSessionCache.instance.register(key, dataUri);
      return url;
    }

    final out = <ManuscriptBlock>[];
    for (final block in blocks) {
      if ((block.type == ManuscriptBlockType.image ||
              block.type == ManuscriptBlockType.equation) &&
          (block.imageUrl ?? '').startsWith('data:')) {
        try {
          final url = await uploadDataUri(block.imageUrl!, block.id);
          out.add(block.copyWith(imageUrl: url));
        } catch (_) {
          out.add(block);
        }
        continue;
      }
      if (block.type == ManuscriptBlockType.table &&
          block.rowCellImages.isNotEmpty) {
        final rows = <List<String>>[];
        for (var r = 0; r < block.rowCellImages.length; r++) {
          final row = block.rowCellImages[r];
          final next = <String>[];
          for (var c = 0; c < row.length; c++) {
            final cell = row[c];
            if (cell.startsWith('data:')) {
              try {
                next.add(await uploadDataUri(cell, '${block.id}_r${r}_c$c'));
              } catch (_) {
                next.add(cell);
              }
            } else {
              next.add(cell);
            }
          }
          rows.add(next);
        }
        out.add(block.copyWith(rowCellImages: rows));
        continue;
      }
      out.add(block);
    }
    return out;
  }



  Future<({String name, Uint8List bytes})?> pickLocalDocument({
    List<String> extensions = const ['pdf', 'doc', 'docx'],
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      throw Exception(appTr('تعذر قراءة الملف', 'Could not read file'));
    }
    if (bytes.length > maxDocumentBytes) {
      throw Exception(appTr(
        'حجم الملف يجب ألا يتجاوز 24 ميجابايت',
        'File must not exceed 24 MB',
      ));
    }
    return (name: file.name, bytes: bytes);
  }

  Future<({String url, String name, String mime, int size, Uint8List bytes})>
      pickAndUploadDocument({
    required String manuscriptId,
  }) async {

    final result = await FilePicker.platform.pickFiles(

      type: FileType.custom,

      allowedExtensions: const ['pdf', 'doc', 'docx'],

      withData: kIsWeb,

    );

    if (result == null || result.files.isEmpty) {

      throw Exception(appTr('لم يُختر ملف', 'No file selected'));

    }



    final file = result.files.first;

    final name = file.name;

    final mime = _mimeForName(name);



    if (!kIsWeb && file.path != null) {

      final diskFile = File(file.path!);

      final size = await diskFile.length();

      if (size > maxDocumentBytes) {

        throw Exception(appTr(

          'حجم الملف يجب ألا يتجاوز 24 ميجابايت',

          'File must not exceed 24 MB',

        ));

      }

      final bytes = await diskFile.readAsBytes();
      ManuscriptFileBytesCache.store(manuscriptId, name, bytes);
      final url = await _putFile(
        manuscriptId: manuscriptId,
        file: diskFile,
        fileName: name,
        contentType: mime,
      );
      return (url: url, name: name, mime: mime, size: size, bytes: bytes);

    }



    Uint8List? bytes = file.bytes;

    if (bytes == null && file.path != null) {

      bytes = await File(file.path!).readAsBytes();

    }

    if (bytes == null) {

      throw Exception(appTr('تعذر قراءة الملف', 'Could not read file'));

    }

    if (bytes.length > maxDocumentBytes) {

      throw Exception(appTr(

        'حجم الملف يجب ألا يتجاوز 24 ميجابايت',

        'File must not exceed 24 MB',

      ));

    }



    ManuscriptFileBytesCache.store(manuscriptId, name, bytes);
    final url = await _putBytes(
      manuscriptId: manuscriptId,
      bytes: bytes,
      fileName: name,
      contentType: mime,
    );
    return (url: url, name: name, mime: mime, size: bytes.length, bytes: bytes);
  }

  /// Authenticated Storage download — raw http.get on the URL often returns 403.
  Future<Uint8List?> downloadDocumentBytes({
    required String url,
    String? manuscriptId,
    String? filename,
  }) async {
    if (manuscriptId != null && filename != null) {
      final cached = ManuscriptFileBytesCache.read(manuscriptId, filename);
      if (cached != null && cached.isNotEmpty) return cached;
    }
    try {
      final data = await _storage.refFromURL(url).getData(maxDocumentBytes);
      if (data != null && data.isNotEmpty) {
        if (manuscriptId != null && filename != null) {
          ManuscriptFileBytesCache.store(manuscriptId, filename, data);
        }
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Authenticated image download. Raw `http.get` on a Storage URL returns 403.
  Future<Uint8List?> downloadBytesFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    try {
      if (trimmed.startsWith('http') || trimmed.startsWith('gs://')) {
        final data = await _storage.refFromURL(trimmed).getData(maxDocumentBytes);
        if (data != null && data.isNotEmpty) return data;
      }
    } catch (_) {}
    return null;
  }

  Future<XFile?> pickImageFromGallery() =>

      _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 88);



  Future<String> uploadBytes({

    required String manuscriptId,

    required Uint8List bytes,

    required String fileName,

    required String contentType,

  }) =>

      _putBytes(

        manuscriptId: manuscriptId,

        bytes: bytes,

        fileName: fileName,

        contentType: contentType,

      );



  Future<void> deleteFileAtUrl(String url) async {

    if (url.trim().isEmpty) return;

    try {

      await _storage.refFromURL(url).delete();

    } catch (_) {

      // File may already be gone — still remove from manuscript metadata.

    }

  }



  /// Removes all Storage objects linked to a manuscript draft.

  Future<void> deleteManuscriptFiles({

    required String userId,

    required String manuscriptId,

    required PublishManuscript manuscript,

  }) async {

    final urls = <String>{};

    for (final attachment in manuscript.attachments) {

      if (attachment.url.trim().isNotEmpty) urls.add(attachment.url);

    }

    for (final block in manuscript.bodyBlocks) {

      if (block.type == ManuscriptBlockType.image) {

        final url = block.imageUrl?.trim() ?? '';

        if (url.isNotEmpty) urls.add(url);

      }

    }

    for (final url in urls) {

      await deleteFileAtUrl(url);

    }



    try {

      final folderRef =

          _storage.ref().child('publish/$userId/$manuscriptId');

      await _deleteStorageFolder(folderRef);

    } catch (_) {

      // Folder may not exist or rules may block prefix listing.

    }



    try {

      final importRef = _storage.ref().child('publish/$userId/import');

      final importList = await importRef.listAll();

      for (final prefix in importList.prefixes) {

        if (prefix.name.contains(manuscriptId)) {

          await _deleteStorageFolder(prefix);

        }

      }

    } catch (_) {}

  }



  Future<void> _deleteStorageFolder(Reference ref) async {

    final listing = await ref.listAll();

    for (final item in listing.items) {

      try {

        await item.delete();

      } catch (_) {}

    }

    for (final prefix in listing.prefixes) {

      await _deleteStorageFolder(prefix);

    }

  }



  Future<T> _enqueue<T>(Future<T> Function() action) {

    final previous = _uploadQueue;

    final completer = Completer<T>();

    _uploadQueue = (previous ?? Future.value()).then((_) async {

      try {

        completer.complete(await action());

      } catch (e, st) {

        completer.completeError(e, st);

      }

    });

    return completer.future;

  }



  Future<void> _beforeUpload() async {

    await SchedulerBinding.instance.endOfFrame;

    if (!kIsWeb && Platform.isWindows) {

      await Future<void>.delayed(const Duration(milliseconds: 900));

    }

  }



  Future<String> _putFile({

    required String manuscriptId,

    required File file,

    required String fileName,

    required String contentType,

  }) {

    return _enqueue(() async {

      await _beforeUpload();



      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {

        throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

      }



      final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');

      final path = 'publish/${user.uid}/$manuscriptId/$safeName';

      final ref = _storage.ref().child(path);

      await ref.putFile(file, SettableMetadata(contentType: contentType));

      return ref.getDownloadURL();

    });

  }



  Future<String> _putBytes({

    required String manuscriptId,

    required Uint8List bytes,

    required String fileName,

    required String contentType,

  }) {

    return _enqueue(() async {

      await _beforeUpload();



      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {

        throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));

      }



      final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');

      final path = 'publish/${user.uid}/$manuscriptId/$safeName';

      final ref = _storage.ref().child(path);

      await ref.putData(bytes, SettableMetadata(contentType: contentType));

      return ref.getDownloadURL();

    });

  }



  String _safeImageExt(String name) {

    final ext = name.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) return ext;

    return 'jpg';

  }



  String _mimeForName(String name) {

    final lower = name.toLowerCase();

    if (lower.endsWith('.pdf')) return 'application/pdf';

    if (lower.endsWith('.docx')) {

      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    }

    if (lower.endsWith('.doc')) return 'application/msword';

    return 'application/octet-stream';

  }

}


