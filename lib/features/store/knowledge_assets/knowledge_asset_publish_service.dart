import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../core/locale/app_translate.dart';
import '../../auth/provider_publish_gate.dart';
import '../../auth/user_account_service.dart';
import '../../auth/user_role.dart';
import 'knowledge_asset_crypto.dart';
import 'knowledge_asset_models.dart';

class KnowledgeAssetPublishResult {
  final String productId;
  final String licenseMode;

  const KnowledgeAssetPublishResult({
    required this.productId,
    required this.licenseMode,
  });
}

/// نشر أصل معرفي مشفّر في المتجر.
class KnowledgeAssetPublishService {
  KnowledgeAssetPublishService._();
  static final KnowledgeAssetPublishService instance =
      KnowledgeAssetPublishService._();

  static const maxBytes = 40 * 1024 * 1024;
  static const maxSizeMb = 40;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<({List<int> bytes, String name, String mime})?> pickAssetFile() async {
    final readFromPath = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'py',
        'r',
        'm',
        'ipynb',
        'js',
        'ts',
        'dart',
        'cpp',
        'c',
        'h',
        'java',
        'txt',
        'md',
        'csv',
        'json',
        'xml',
        'stl',
        'step',
        'stp',
        'obj',
        'glb',
        'gltf',
        'pdf',
        'docx',
        'zip',
      ],
      withData: !readFromPath,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = await _readBytes(file);
    if (bytes == null || bytes.isEmpty) {
      throw Exception(appTr('تعذر قراءة الملف', 'Could not read file'));
    }
    if (bytes.length > maxBytes) {
      throw Exception(appTr(
        'حجم الملف يجب ألا يتجاوز $maxSizeMb ميجابايت',
        'File must not exceed $maxSizeMb MB',
      ));
    }
    return (bytes: bytes, name: file.name, mime: _mimeFromName(file.name));
  }

  Future<KnowledgeAssetPublishResult> publish({
    required String name,
    required String description,
    required num price,
    required String storeName,
    required String contact,
    required String kind,
    required String licenseMode,
    int? rentalDays,
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('سجّل الدخول أولاً', 'Sign in first'));
    }

    await UserAccountService.instance.ensureAccountExists(user);
    var account = await UserAccountService.instance.loadCurrentAccount();
    if (!UserRole.canSellProducts(account?.role)) {
      await UserAccountService.instance.enableMerchantSelling();
      account = await UserAccountService.instance.loadCurrentAccount();
    }
    if (!UserRole.canSellProducts(account?.role)) {
      throw Exception(appTr(
        'يلزم دور تاجر لنشر أصول معرفية',
        'Merchant role required to publish knowledge assets',
      ));
    }
    if (!ProviderPublishGate.canSubmitContent(account)) {
      throw Exception(
        appTr(
          ProviderPublishGate.blockMessageAr(account),
          ProviderPublishGate.blockMessageEn(account),
        ),
      );
    }

    if (name.trim().isEmpty || price <= 0) {
      throw Exception(appTr(
        'الاسم والسعر مطلوبان (سعر > 0)',
        'Name and price (> 0) are required',
      ));
    }
    if (licenseMode == KnowledgeLicenseMode.rental &&
        (rentalDays == null || rentalDays < 1)) {
      throw Exception(appTr(
        'حدد مدة الإيجار بالأيام',
        'Set rental duration in days',
      ));
    }

    final keyIv = KnowledgeAssetCrypto.generateKeyIv();
    final plainHash = KnowledgeAssetCrypto.sha256Hex(fileBytes);
    final cipher = KnowledgeAssetCrypto.encryptBytes(
      plain: fileBytes,
      key: keyIv.key,
      iv: keyIv.iv,
    );

    final productRef = _db.collection('product').doc();
    final productId = productRef.id;
    final storagePath =
        'knowledge_assets/${user.uid}/$productId/payload.enc';

    await _storage.ref().child(storagePath).putData(
          Uint8List.fromList(cipher),
          SettableMetadata(
            contentType: 'application/octet-stream',
            customMetadata: {
              'originalName': fileName,
              'originalMime': mimeType,
              'productId': productId,
            },
          ),
        );

    await _db.collection('knowledge_asset_secrets').doc(productId).set({
      'productId': productId,
      'sellerId': user.uid,
      'decryptionKeyB64': KnowledgeAssetCrypto.b64(keyIv.key),
      'ivB64': KnowledgeAssetCrypto.b64(keyIv.iv),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await productRef.set({
      'name': name.trim(),
      'price': price,
      'category': 'أصول معرفية رقمية',
      'description': description.trim(),
      'storeName': storeName.trim(),
      'contact': contact.trim(),
      'createdBy': user.uid,
      'approvalStatus':
          ProviderPublishGate.contentApprovalStatus(account),
      'createdAt': FieldValue.serverTimestamp(),
      'productType': KnowledgeProductType.knowledgeAsset,
      'licenseMode': licenseMode,
      if (licenseMode == KnowledgeLicenseMode.rental) 'rentalDays': rentalDays,
      'assetKind': kind,
      'assetStoragePath': storagePath,
      'assetFileName': fileName,
      'assetContentType': mimeType,
      'assetSizeBytes': fileBytes.length,
      'assetSha256': plainHash,
      'hasProtectedAsset': true,
      'inStock': true,
      'unit': licenseMode == KnowledgeLicenseMode.rental
          ? appTr('ترخيص إيجار', 'Rental license')
          : appTr('ترخيص ملكية', 'Ownership license'),
      'badges': [
        'knowledge_asset',
        if (licenseMode == KnowledgeLicenseMode.rental) 'rental' else 'sale',
      ],
    });

    return KnowledgeAssetPublishResult(
      productId: productId,
      licenseMode: licenseMode,
    );
  }

  Future<List<int>?> _readBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes;
    final path = file.path;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      final io = File(path);
      if (await io.exists()) return io.readAsBytes();
    }
    return null;
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.stl')) return 'model/stl';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.py') ||
        lower.endsWith('.r') ||
        lower.endsWith('.m') ||
        lower.endsWith('.js') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.dart') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.md') ||
        lower.endsWith('.ipynb')) {
      return 'text/plain';
    }
    return 'application/octet-stream';
  }
}
