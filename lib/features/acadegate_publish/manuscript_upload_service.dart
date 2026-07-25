import 'dart:async';

import 'dart:io';



import 'package:file_picker/file_picker.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/scheduler.dart';

import 'package:image_picker/image_picker.dart';



import '../../core/locale/app_translate.dart';
import 'publish_models.dart';

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



  Future<({String url, String name, String mime, int size})> pickAndUploadDocument({

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

      final url = await _putFile(

        manuscriptId: manuscriptId,

        file: diskFile,

        fileName: name,

        contentType: mime,

      );

      return (url: url, name: name, mime: mime, size: size);

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



    final url = await _putBytes(

      manuscriptId: manuscriptId,

      bytes: bytes,

      fileName: name,

      contentType: mime,

    );

    return (url: url, name: name, mime: mime, size: bytes.length);

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


