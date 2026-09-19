import 'dart:convert';
import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/locale/app_translate.dart';
import 'knowledge_asset_crypto.dart';
import 'knowledge_asset_models.dart';

class KnowledgeAssetAccessBundle {
  final KnowledgeLicense license;
  final Uint8List plainBytes;
  final String? textPreview;

  const KnowledgeAssetAccessBundle({
    required this.license,
    required this.plainBytes,
    this.textPreview,
  });
}

/// فتح الأصل المعرفي المرخّص داخل التطبيق (فك تشفير في الذاكرة).
class KnowledgeAssetAccessService {
  KnowledgeAssetAccessService._();
  static final KnowledgeAssetAccessService instance =
      KnowledgeAssetAccessService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  static String licenseIdFor({
    required String buyerId,
    required String productId,
  }) =>
      '${buyerId}_$productId';

  Stream<List<KnowledgeLicense>> watchMyLicenses() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('product_licenses')
        .where('buyerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => KnowledgeLicense.fromMap(d.data(), id: d.id))
          .toList();
      list.sort((a, b) {
        final aa = a.grantedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.grantedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });
      return list;
    });
  }

  Future<KnowledgeLicense?> loadLicenseForProduct(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final id = licenseIdFor(buyerId: uid, productId: productId);
    final doc = await _db.collection('product_licenses').doc(id).get();
    if (!doc.exists) return null;
    return KnowledgeLicense.fromMap(doc.data()!, id: doc.id);
  }

  Future<KnowledgeAssetAccessBundle> openProtectedAsset({
    required KnowledgeLicense license,
  }) async {
    if (!license.isActive) {
      throw Exception(appTr(
        'الترخيص غير نشط أو منتهٍ',
        'License is inactive or expired',
      ));
    }
    if (license.decryptionKeyB64.isEmpty ||
        license.ivB64.isEmpty ||
        license.assetStoragePath.isEmpty) {
      throw Exception(appTr(
        'بيانات الترخيص غير مكتملة',
        'License data is incomplete',
      ));
    }

    final ref = _storage.ref().child(license.assetStoragePath);
    final cipher = await ref.getData(45 * 1024 * 1024);
    if (cipher == null || cipher.isEmpty) {
      throw Exception(appTr(
        'تعذر تنزيل الأصل المحمي',
        'Could not download protected asset',
      ));
    }

    final plain = KnowledgeAssetCrypto.decryptBytes(
      cipher: cipher,
      key: KnowledgeAssetCrypto.fromB64(license.decryptionKeyB64),
      iv: KnowledgeAssetCrypto.fromB64(license.ivB64),
    );

    await _db.collection('product_licenses').doc(license.id).set({
      'accessCount': FieldValue.increment(1),
      'lastAccessedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    String? textPreview;
    if (_looksText(license.assetContentType, license.assetFileName)) {
      try {
        final decoded = utf8.decode(plain, allowMalformed: true);
        textPreview = decoded.length > 120000
            ? '${decoded.substring(0, 120000)}\n\n…'
            : decoded;
      } catch (_) {}
    }

    return KnowledgeAssetAccessBundle(
      license: license,
      plainBytes: plain,
      textPreview: textPreview,
    );
  }

  /// تصدير مرخّص (بيع فقط) مع علامة مائية نصية عند الإمكان.
  Future<void> exportLicensedCopy({
    required KnowledgeLicense license,
    required Uint8List plainBytes,
  }) async {
    if (!license.allowExport || !license.isActive) {
      throw Exception(appTr(
        'التصدير غير مسموح لهذا الترخيص (إيجار أو منتهٍ)',
        'Export is not allowed for this license (rental or expired)',
      ));
    }

    final stamp = utf8.encode(
      'AcadeGate licensed copy · license=${license.id} · '
      'buyer=${license.buyerId} · product=${license.productId}\n'
      '---\n',
    );
    final out = _looksText(license.assetContentType, license.assetFileName)
        ? Uint8List.fromList([...stamp, ...plainBytes])
        : plainBytes;

    if (kIsWeb) {
      final x = XFile.fromData(
        out,
        name: 'licensed_${license.assetFileName}',
        mimeType: license.assetContentType.isNotEmpty
            ? license.assetContentType
            : 'application/octet-stream',
      );
      await Share.shareXFiles([x]);
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/licensed_${license.id}_${license.assetFileName}';
    await File(path).writeAsBytes(out, flush: true);
    await Share.shareXFiles([XFile(path)]);
  }

  bool _looksText(String mime, String name) {
    final m = mime.toLowerCase();
    final n = name.toLowerCase();
    if (m.startsWith('text/')) return true;
    if (m.contains('json') || m.contains('xml') || m.contains('javascript')) {
      return true;
    }
    return n.endsWith('.py') ||
        n.endsWith('.r') ||
        n.endsWith('.m') ||
        n.endsWith('.js') ||
        n.endsWith('.ts') ||
        n.endsWith('.dart') ||
        n.endsWith('.txt') ||
        n.endsWith('.md') ||
        n.endsWith('.csv') ||
        n.endsWith('.json') ||
        n.endsWith('.ipynb') ||
        n.endsWith('.xml');
  }
}
