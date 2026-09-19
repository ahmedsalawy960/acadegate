import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  }

  Future<String?> uploadImage({
    required XFile file,
    required String folder,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول لرفع صورة');

    final bytes = await file.readAsBytes();
    // Keep in sync with storage.rules general image upload limit.
    const maxBytes = 15 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw Exception('حجم الصورة يجب ألا يتجاوز 15 ميجابايت');
    }

    final ext = file.name.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    final path =
        'uploads/${user.uid}/$folder/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    final ref = _storage.ref().child(path);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: 'image/$safeExt'),
    );
    return ref.getDownloadURL();
  }

  Future<String> uploadBytes({
    required List<int> bytes,
    required String folder,
    String fileName = 'frame.png',
    String contentType = 'image/png',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول لرفع صورة');
    const maxBytes = 15 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw Exception('حجم الملف يجب ألا يتجاوز 15 ميجابايت');
    }
    final ext = fileName.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'webp', 'pdf'].contains(ext)
        ? ext
        : (contentType.contains('pdf') ? 'pdf' : 'png');
    final path =
        'uploads/${user.uid}/$folder/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final ref = _storage.ref().child(path);
    final mime = contentType.contains('/')
        ? contentType
        : (safeExt == 'pdf' ? 'application/pdf' : 'image/$safeExt');
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: mime),
    );
    return ref.getDownloadURL();
  }

  /// تحميل بايتات الصورة عبر SDK (يتجاوز CORS على الويب) ثم HTTP كاحتياط.
  Future<Uint8List?> downloadBytes(
    String url, {
    int maxSize = 8 * 1024 * 1024,
  }) async {
    final u = url.trim();
    if (u.isEmpty) return null;
    if (_isFirebaseUrl(u)) {
      try {
        final data = await _storage.refFromURL(u).getData(maxSize);
        if (data != null && data.isNotEmpty) return data;
      } catch (_) {}
    }
    try {
      final res = await http.get(
        Uri.parse(u),
        headers: const {
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          res.bodyBytes.isNotEmpty &&
          res.bodyBytes.length <= maxSize) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  bool _isFirebaseUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('firebasestorage') ||
        u.contains('googleapis.com') ||
        u.contains('appspot.com');
  }
}
