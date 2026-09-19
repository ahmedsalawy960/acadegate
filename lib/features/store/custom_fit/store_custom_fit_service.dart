import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/locale/app_translate.dart';
import '../../notifications/notification_service.dart';
import '../store_rfq_service.dart';
import 'cad_asset_models.dart';
import 'store_custom_fit_models.dart';

/// حفظ طلبات التوافق المخصص وربطها بـ RFQ للموردين.
class StoreCustomFitService {
  StoreCustomFitService._();
  static final StoreCustomFitService instance = StoreCustomFitService._();

  final _db = FirebaseFirestore.instance;

  Future<String> saveJob({
    required String title,
    required String specsText,
    String? diagramUrl,
    required CustomFitAnalysisResult analysis,
    String? preferredSellerId,
    String? preferredProductId,
    List<CadGeneratedAsset> cadAssets = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final buyerName = user.displayName ??
        user.email?.split('@').first ??
        appTr('باحث', 'Researcher');

    final top = analysis.matches.isEmpty ? null : analysis.matches.first;
    final doc = await _db.collection('store_custom_fit_jobs').add({
      'buyerId': user.uid,
      'buyerName': buyerName,
      'title': title.trim().isEmpty
          ? appTr('طلب توافق مخصص', 'Custom fit request')
          : title.trim(),
      'specsText': specsText.trim(),
      'diagramUrl': diagramUrl,
      'requirements': analysis.requirements.toMap(),
      'fabrication': analysis.fabrication.toMap(),
      'needsCustomFabrication': analysis.needsCustomFabrication,
      'fromAi': analysis.fromAi,
      'modelUsed': analysis.modelUsed,
      'topMatchProductId': top?.productId,
      'topMatchPercent': top?.matchPercent,
      'matchProductIds':
          analysis.matches.map((m) => m.productId).take(12).toList(),
      'preferredSellerId': preferredSellerId ?? '',
      'preferredProductId': preferredProductId ?? '',
      'cadAssets': cadAssets.map((a) => a.toMap()).toList(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// يرسل طلب تصنيع/تعديل كموجز للمورد عبر RFQ + سجل custom-fit.
  Future<({String jobId, String rfqId})> submitFabricationRequest({
    required String title,
    required String specsText,
    String? diagramUrl,
    required CustomFitAnalysisResult analysis,
    String sellerId = '',
    String? relatedProductId,
    String relatedProductName = '',
    List<CadGeneratedAsset> cadAssets = const [],
  }) async {
    final jobId = await saveJob(
      title: title,
      specsText: specsText,
      diagramUrl: diagramUrl,
      analysis: analysis,
      preferredSellerId: sellerId,
      preferredProductId: relatedProductId,
      cadAssets: cadAssets,
    );

    final fab = analysis.fabrication;
    final req = analysis.requirements;
    final details = StringBuffer()
      ..writeln(appTr(
        'طلب توافق مخصص (Custom Fit) — AcadeGate',
        'Custom Fit request — AcadeGate',
      ))
      ..writeln()
      ..writeln(appTr('الملخص:', 'Summary:'))
      ..writeln(
        req.summaryAr.isNotEmpty
            ? req.summaryAr
            : (req.summaryEn.isNotEmpty ? req.summaryEn : specsText),
      )
      ..writeln()
      ..writeln(appTr('المواصفات الحرجة:', 'Critical specs:'))
      ..writeln(
        req.criticalSpecs.isEmpty
            ? specsText
            : req.criticalSpecs.map((e) => '• $e').join('\n'),
      )
      ..writeln()
      ..writeln(appTr('موجز التصنيع الرقمي:', 'Digital fabrication brief:'))
      ..writeln(
        '${appTr('العملية', 'Process')}: ${fab.processHint.isEmpty ? '—' : fab.processHint}',
      )
      ..writeln(
        '${appTr('المادة', 'Material')}: ${fab.materialHint.isEmpty ? '—' : fab.materialHint}',
      )
      ..writeln(
        '${appTr('الأبعاد', 'Dimensions')}: ${fab.dimensionsSummary.isEmpty ? '—' : fab.dimensionsSummary}',
      )
      ..writeln(
        '${appTr('التحمّلات', 'Tolerances')}: ${fab.tolerances.isEmpty ? '—' : fab.tolerances}',
      )
      ..writeln()
      ..writeln(appTr('طلب للمورد:', 'Ask to supplier:'))
      ..writeln(
        fab.supplierAskAr.isNotEmpty
            ? fab.supplierAskAr
            : (fab.supplierAskEn.isNotEmpty
                ? fab.supplierAskEn
                : specsText),
      );

    if (diagramUrl != null && diagramUrl.trim().isNotEmpty) {
      details.writeln();
      details.writeln(appTr('رابط الرسم:', 'Diagram URL:'));
      details.writeln(diagramUrl.trim());
    }

    if (cadAssets.isNotEmpty) {
      details.writeln();
      details.writeln(appTr('ملفات CAD مولَّدة:', 'Generated CAD files:'));
      for (final a in cadAssets.take(6)) {
        if (!a.hasFile) continue;
        details.writeln('${a.providerLabel} · ${a.format.toUpperCase()}: ${a.url}');
      }
    }

    details.writeln();
    details.writeln('(jobId: $jobId)');

    // Firestore RFQ rule: details.size() <= 4000
    var detailsText = details.toString();
    if (detailsText.length > 3900) {
      detailsText = '${detailsText.substring(0, 3900)}…';
    }

    final productName = relatedProductName.trim().isNotEmpty
        ? relatedProductName.trim()
        : (title.trim().isNotEmpty
            ? title.trim()
            : appTr('تصنيع/تعديل قطعة مخصصة', 'Custom fabricated/modified part'));

    final rfqId = await StoreRfqService.instance.submit(
      productId: relatedProductId,
      productName: productName.length > 280
          ? '${productName.substring(0, 280)}…'
          : productName,
      category: appTr('توافق مخصص', 'Custom fit'),
      sellerId: sellerId,
      details: detailsText,
      quantity: 1,
    );

    await _db.collection('store_custom_fit_jobs').doc(jobId).update({
      'rfqId': rfqId,
      'status': 'quoted_requested',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (sellerId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: sellerId,
        title: appTr('طلب تصنيع مخصص', 'Custom fabrication request'),
        body: productName,
        type: 'store_order',
        contextId: jobId,
        contextType: 'store_custom_fit',
      );
    }

    return (jobId: jobId, rfqId: rfqId);
  }

  Stream<List<Map<String, dynamic>>> watchMine() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);
    return _db
        .collection('store_custom_fit_jobs')
        .where('buyerId', isEqualTo: user.uid)
        .limit(40)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
      list.sort((a, b) {
        final aAt = a['createdAt'];
        final bAt = b['createdAt'];
        if (aAt is Timestamp && bAt is Timestamp) {
          return bAt.compareTo(aAt);
        }
        return 0;
      });
      return list;
    });
  }
}
