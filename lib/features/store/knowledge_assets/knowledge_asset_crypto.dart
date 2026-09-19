import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// تشفير AES-256-CBC لأصول المعرفة قبل الرفع — المفتاح لا يُنشر مع المنتج.
class KnowledgeAssetCrypto {
  KnowledgeAssetCrypto._();

  static final _secureRandom = Random.secure();

  static ({Uint8List key, Uint8List iv}) generateKeyIv() {
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => _secureRandom.nextInt(256)),
    );
    final iv = Uint8List.fromList(
      List<int>.generate(16, (_) => _secureRandom.nextInt(256)),
    );
    return (key: key, iv: iv);
  }

  static Uint8List encryptBytes({
    required List<int> plain,
    required Uint8List key,
    required Uint8List iv,
  }) {
    final aesKey = enc.Key(key);
    final aesIv = enc.IV(iv);
    final encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plain, iv: aesIv);
    return Uint8List.fromList(encrypted.bytes);
  }

  static Uint8List decryptBytes({
    required List<int> cipher,
    required Uint8List key,
    required Uint8List iv,
  }) {
    final aesKey = enc.Key(key);
    final aesIv = enc.IV(iv);
    final encrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(Uint8List.fromList(cipher)),
      iv: aesIv,
    );
    return Uint8List.fromList(decrypted);
  }

  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  static String b64(Uint8List bytes) => base64Encode(bytes);

  static Uint8List fromB64(String value) =>
      Uint8List.fromList(base64Decode(value));
}
