import 'package:cloud_firestore/cloud_firestore.dart';

/// أنواع الأصول المعرفية الرقمية في المتجر.
class KnowledgeAssetKind {
  KnowledgeAssetKind._();

  static const code = 'code';
  static const model3d = 'model_3d';
  static const dataset = 'dataset';
  static const template = 'template';
  static const other = 'other';

  static const all = [code, model3d, dataset, template, other];
}

class KnowledgeLicenseMode {
  KnowledgeLicenseMode._();

  static const sale = 'sale';
  static const rental = 'rental';
}

class KnowledgeProductType {
  KnowledgeProductType._();

  static const physical = 'physical';
  static const knowledgeAsset = 'knowledge_asset';
}

class KnowledgeAssetMeta {
  final String productId;
  final String kind;
  final String licenseMode;
  final int? rentalDays;
  final String assetStoragePath;
  final String assetFileName;
  final String assetContentType;
  final int assetSizeBytes;
  final String assetSha256;
  final bool hasProtectedAsset;

  const KnowledgeAssetMeta({
    required this.productId,
    required this.kind,
    required this.licenseMode,
    this.rentalDays,
    required this.assetStoragePath,
    required this.assetFileName,
    required this.assetContentType,
    required this.assetSizeBytes,
    required this.assetSha256,
    this.hasProtectedAsset = true,
  });

  bool get isRental => licenseMode == KnowledgeLicenseMode.rental;
  bool get isSale => licenseMode == KnowledgeLicenseMode.sale;

  factory KnowledgeAssetMeta.fromProductMap(
    Map<String, dynamic> data, {
    required String productId,
  }) {
    return KnowledgeAssetMeta(
      productId: productId,
      kind: data['assetKind']?.toString() ?? KnowledgeAssetKind.other,
      licenseMode:
          data['licenseMode']?.toString() ?? KnowledgeLicenseMode.sale,
      rentalDays: data['rentalDays'] is int
          ? data['rentalDays'] as int
          : int.tryParse(data['rentalDays']?.toString() ?? ''),
      assetStoragePath: data['assetStoragePath']?.toString() ?? '',
      assetFileName: data['assetFileName']?.toString() ?? '',
      assetContentType: data['assetContentType']?.toString() ?? '',
      assetSizeBytes: data['assetSizeBytes'] is int
          ? data['assetSizeBytes'] as int
          : int.tryParse(data['assetSizeBytes']?.toString() ?? '') ?? 0,
      assetSha256: data['assetSha256']?.toString() ?? '',
      hasProtectedAsset: data['hasProtectedAsset'] != false,
    );
  }
}

class KnowledgeLicense {
  final String id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final String orderId;
  final String productName;
  final String licenseMode;
  final String status;
  final DateTime? grantedAt;
  final DateTime? expiresAt;
  final String decryptionKeyB64;
  final String ivB64;
  final String assetStoragePath;
  final String assetFileName;
  final String assetContentType;
  final String assetKind;
  final bool allowExport;
  final int accessCount;

  const KnowledgeLicense({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.orderId,
    required this.productName,
    required this.licenseMode,
    required this.status,
    this.grantedAt,
    this.expiresAt,
    required this.decryptionKeyB64,
    required this.ivB64,
    required this.assetStoragePath,
    required this.assetFileName,
    required this.assetContentType,
    required this.assetKind,
    this.allowExport = false,
    this.accessCount = 0,
  });

  bool get isActive {
    if (status != 'active') return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now());
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return !expiresAt!.isAfter(DateTime.now());
  }

  factory KnowledgeLicense.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? asDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      return DateTime.tryParse(v?.toString() ?? '');
    }

    return KnowledgeLicense(
      id: id,
      buyerId: map['buyerId']?.toString() ?? '',
      sellerId: map['sellerId']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      licenseMode: map['licenseMode']?.toString() ?? KnowledgeLicenseMode.sale,
      status: map['status']?.toString() ?? 'active',
      grantedAt: asDate(map['grantedAt']),
      expiresAt: asDate(map['expiresAt']),
      decryptionKeyB64: map['decryptionKeyB64']?.toString() ?? '',
      ivB64: map['ivB64']?.toString() ?? '',
      assetStoragePath: map['assetStoragePath']?.toString() ?? '',
      assetFileName: map['assetFileName']?.toString() ?? '',
      assetContentType: map['assetContentType']?.toString() ?? '',
      assetKind: map['assetKind']?.toString() ?? KnowledgeAssetKind.other,
      allowExport: map['allowExport'] == true,
      accessCount: map['accessCount'] is int
          ? map['accessCount'] as int
          : int.tryParse(map['accessCount']?.toString() ?? '') ?? 0,
    );
  }
}
