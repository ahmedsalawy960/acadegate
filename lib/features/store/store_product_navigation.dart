import 'package:flutter/material.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import 'product_detail_screen.dart';
import 'store_catalog_service.dart';

Future<void> openStoreProductDetail(
  BuildContext context,
  StoreCatalogProduct product,
) {
  final priceLabel = product.price > 0
      ? '${product.price} ${appTr('ج.م', 'EGP')}'
      : context.t('السعر عند المورد', 'Price via supplier');

  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ProductDetailScreen(
        name: product.name,
        price: priceLabel,
        description: product.description.isNotEmpty
            ? product.description
            : context.t('لا يوجد وصف', 'No description'),
        storeName: product.storeName.isNotEmpty
            ? product.storeName
            : context.t('متجر غير معروف', 'Unknown store'),
        contact: product.contact,
        productId: product.id,
        createdBy: product.createdBy,
        priceValue: product.price,
        imageUrl: product.imageUrl,
        sourceUrl: product.sourceUrl,
        brand: product.brand,
        unit: product.unit,
        grade: product.grade,
        sellerType: product.sellerType,
        certifications: product.certifications,
        isVerifiedSeller: product.isVerifiedSeller,
        isDirectoryListing: product.isDirectoryListing,
        isPartner: product.isPartner,
        directoryStatus: product.directoryStatus,
        dataSourceLabelAr: product.dataSourceLabelAr,
        dataSourceLabelEn: product.dataSourceLabelEn,
        lastVerifiedIso: product.lastVerifiedIso,
        email: product.email,
        phone: product.phone,
        whatsapp: product.whatsapp,
        website: product.website,
        sku: product.sku,
        originCountry: product.originCountry,
        imageUrls: product.galleryUrls,
        inStock: product.inStock,
        city: product.city,
        fastShipping: product.fastShipping,
        badges: product.badges,
        categoryTitle: product.categoryCanonical.isNotEmpty
            ? product.categoryCanonical
            : product.categoryRaw,
        supplierId: product.supplierId,
        productType: product.productType,
        licenseMode: product.licenseMode,
        hasAssemblyGuide: product.hasAssemblyGuide,
      ),
    ),
  );
}
