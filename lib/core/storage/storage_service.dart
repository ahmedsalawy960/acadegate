import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
}
