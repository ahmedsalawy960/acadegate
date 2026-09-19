import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import 'catalog_report_service.dart';

/// إخلاء مسؤولية موحّد لقوائم الدليل العامة مقابل شركاء Partner.
class CatalogDisclaimerBanner extends StatelessWidget {
  const CatalogDisclaimerBanner({
    super.key,
    this.isPartner = false,
    this.isDirectoryListing = true,
    this.compact = false,
  });

  final bool isPartner;
  final bool isDirectoryListing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (isPartner) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: Text(
          context.t(
            'شريك Partner — ملف موثّق ومُدار بعد التحقق من تمثيل المنشأة على AcadeGate.',
            'AcadeGate Partner — Managed Verified profile after representation checks.',
          ),
          style: TextStyle(
            height: 1.35,
            fontSize: compact ? 12 : 13,
            color: Colors.green[900],
          ),
        ),
      );
    }

    if (!isDirectoryListing) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Text(
        context.t(
          'بيانات عامة من مواقع/كتالوجات معلنة — ليست اعتماداً ولا شارة «موثّق» ما لم يظهر «موثّق ومُدار» بعد التحقق.',
          'Public directory data — not an endorsement and not a Verified badge unless Managed Verified is shown after checks.',
        ),
        style: TextStyle(
          height: 1.35,
          fontSize: compact ? 12 : 13,
          color: Colors.brown[900],
        ),
      ),
    );
  }
}

class CatalogSourceMeta extends StatelessWidget {
  const CatalogSourceMeta({
    super.key,
    required this.sourceLabel,
    this.lastVerifiedLabel,
    this.lastManagedLabel,
  });

  final String sourceLabel;
  final String? lastVerifiedLabel;
  final String? lastManagedLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      [
        context.t('المصدر', 'Source'),
        ': $sourceLabel',
        if (lastVerifiedLabel != null && lastVerifiedLabel!.isNotEmpty)
          ' · ${context.t('آخر تحقق', 'Last verified')}: $lastVerifiedLabel',
        if (lastManagedLabel != null && lastManagedLabel!.isNotEmpty)
          ' · ${context.t('آخر ترتيب', 'Last arranged')}: $lastManagedLabel',
      ].join(),
      style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.35),
    );
  }
}

/// زر/ورقة «بلّغ عن خطأ» لبيانات مورد أو منتج دليلي.
Future<void> showCatalogReportSheet(
  BuildContext context, {
  required String targetType,
  String? productId,
  String? supplierId,
  String? storeName,
  String? sourceUrl,
  String initialReason = 'inaccurate',
}) async {
  final ok = await ensureLoggedIn(context);
  if (!ok || !context.mounted) return;

  final detailsCtrl = TextEditingController();
  var reason = initialReason;

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ctx.t('بلّغ عن خطأ في البيانات', 'Report incorrect data'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: InputDecoration(
                    labelText: ctx.t('السبب', 'Reason'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'inaccurate',
                      child: Text(ctx.t('بيانات غير دقيقة', 'Inaccurate data')),
                    ),
                    DropdownMenuItem(
                      value: 'outdated',
                      child: Text(ctx.t('بيانات قديمة', 'Outdated')),
                    ),
                    DropdownMenuItem(
                      value: 'wrong_contact',
                      child: Text(ctx.t('تواصل خاطئ', 'Wrong contact')),
                    ),
                    DropdownMenuItem(
                      value: 'scam',
                      child: Text(ctx.t('احتيال / إساءة', 'Scam / abuse')),
                    ),
                    DropdownMenuItem(
                      value: 'fake_supplier',
                      child: Text(
                        ctx.t(
                          'مورد وهمي / انتحال هوية',
                          'Fake supplier / impersonation',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'fake_lab',
                      child: Text(
                        ctx.t(
                          'مختبر وهمي / انتحال',
                          'Fake lab / impersonation',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'fake_supervisor',
                      child: Text(
                        ctx.t(
                          'مشرف وهمي / انتحال',
                          'Fake supervisor / impersonation',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(ctx.t('أخرى', 'Other')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => reason = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: ctx.t('التفاصيل', 'Details'),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.t('إرسال البلاغ', 'Submit report')),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  if (submitted != true || !context.mounted) {
    detailsCtrl.dispose();
    return;
  }

  try {
    final id = await CatalogReportService.instance.submit(
      targetType: targetType,
      reason: reason,
      details: detailsCtrl.text,
      productId: productId,
      supplierId: supplierId,
      storeName: storeName,
      sourceUrl: sourceUrl,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('تم تسجيل البلاغ ($id)', 'Report recorded ($id)'),
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: Colors.red[800]),
    );
  } finally {
    detailsCtrl.dispose();
  }
}

class CatalogReportLink extends StatelessWidget {
  const CatalogReportLink({
    super.key,
    required this.targetType,
    this.productId,
    this.supplierId,
    this.storeName,
    this.sourceUrl,
    this.emphasizeFakeSupplier = false,
    this.emphasizeFakeLab = false,
    this.emphasizeFakeSupervisor = false,
  });

  final String targetType;
  final String? productId;
  final String? supplierId;
  final String? storeName;
  final String? sourceUrl;
  final bool emphasizeFakeSupplier;
  final bool emphasizeFakeLab;
  final bool emphasizeFakeSupervisor;

  @override
  Widget build(BuildContext context) {
    if (emphasizeFakeSupervisor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => showCatalogReportSheet(
              context,
              targetType: targetType,
              productId: productId,
              supplierId: supplierId,
              storeName: storeName,
              sourceUrl: sourceUrl,
              initialReason: 'fake_supervisor',
            ),
            icon: Icon(Icons.report_gmailerrorred_outlined,
                size: 18, color: Colors.red[800]),
            label: Text(
              context.t('الإبلاغ عن مشرف وهمي', 'Report fake supervisor'),
              style: TextStyle(color: Colors.red[800]),
            ),
          ),
          TextButton.icon(
            onPressed: () => showCatalogReportSheet(
              context,
              targetType: targetType,
              productId: productId,
              supplierId: supplierId,
              storeName: storeName,
              sourceUrl: sourceUrl,
            ),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(context.t('بلّغ عن خطأ', 'Report an error')),
          ),
        ],
      );
    }

    if (emphasizeFakeLab) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => showCatalogReportSheet(
              context,
              targetType: targetType,
              productId: productId,
              supplierId: supplierId,
              storeName: storeName,
              sourceUrl: sourceUrl,
              initialReason: 'fake_lab',
            ),
            icon: Icon(Icons.report_gmailerrorred_outlined,
                size: 18, color: Colors.red[800]),
            label: Text(
              context.t('الإبلاغ عن مختبر وهمي', 'Report fake lab'),
              style: TextStyle(color: Colors.red[800]),
            ),
          ),
          TextButton.icon(
            onPressed: () => showCatalogReportSheet(
              context,
              targetType: targetType,
              productId: productId,
              supplierId: supplierId,
              storeName: storeName,
              sourceUrl: sourceUrl,
            ),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(context.t('بلّغ عن خطأ', 'Report an error')),
          ),
        ],
      );
    }

    if (emphasizeFakeSupplier) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => showCatalogReportSheet(
              context,
              targetType: targetType,
              productId: productId,
              supplierId: supplierId,
              storeName: storeName,
              sourceUrl: sourceUrl,
              initialReason: 'fake_supplier',
            ),
            icon: Icon(Icons.report_gmailerrorred_outlined,
                size: 18, color: Colors.red[800]),
            label: Text(
              context.t('الإبلاغ عن مورد وهمي', 'Report fake supplier'),
              style: TextStyle(color: Colors.red[800]),
            ),
          ),
          TextButton.icon(
            onPressed: () => showCatalogReportSheet(
              context,
              targetType: targetType,
              productId: productId,
              supplierId: supplierId,
              storeName: storeName,
              sourceUrl: sourceUrl,
            ),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(context.t('بلّغ عن خطأ', 'Report an error')),
          ),
        ],
      );
    }

    return TextButton.icon(
      onPressed: () => showCatalogReportSheet(
        context,
        targetType: targetType,
        productId: productId,
        supplierId: supplierId,
        storeName: storeName,
        sourceUrl: sourceUrl,
      ),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: Text(context.t('بلّغ عن خطأ', 'Report an error')),
    );
  }
}
