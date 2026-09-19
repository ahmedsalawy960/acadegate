import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/directory/directory_trust_service.dart';
import '../../../core/directory/directory_trust_status.dart';
import '../../../core/locale/locale_extensions.dart';
import '../../admin/admin_access_gate.dart';
import '../store_theme.dart';
import 'egypt_store_suppliers_catalog.dart';
import 'store_supplier_import_service.dart';

class AdminStoreImportScreen extends StatefulWidget {
  const AdminStoreImportScreen({super.key});

  @override
  State<AdminStoreImportScreen> createState() => _AdminStoreImportScreenState();
}

class _AdminStoreImportScreenState extends State<AdminStoreImportScreen> {
  bool _syncing = false;
  bool _cancel = false;
  StoreSupplierSyncProgress? _progress;
  DateTime? _lastSyncAt;
  String? _lastSummary;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final at = await StoreSupplierImportService.instance.loadLastSyncAt();
    if (!mounted) return;
    setState(() => _lastSyncAt = at);
  }

  Future<void> _runSync({required bool withProducts}) async {
    setState(() {
      _syncing = true;
      _cancel = false;
      _progress = null;
      _lastSummary = null;
    });
    try {
      final result = await StoreSupplierImportService.instance.syncAll(
        syncProducts: withProducts,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
        shouldCancel: () => _cancel,
      );
      if (!mounted) return;
      await _loadLastSync();
      if (!mounted) return;
      final summary = context.t(
        'موردون ${result.suppliersUpserted} · منتجات جديدة ${result.productsImported} · محدّثة ${result.productsUpdated}',
        'Suppliers ${result.suppliersUpserted} · new ${result.productsImported} · updated ${result.productsUpdated}',
      );
      setState(() => _lastSummary = summary);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary),
          backgroundColor: StoreTheme.verified,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = '$e';
      if (msg.contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('تم إلغاء المزامنة', 'Sync cancelled')),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminAccessGate(
      child: Theme(
        data: StoreTheme.overlay(context),
        child: Scaffold(
          backgroundColor: StoreTheme.bg,
          appBar: AcadeGateAppBar(
            title: Text(
              context.t('استيراد موردين المتجر', 'Store supplier import'),
            ),
            backgroundColor: StoreTheme.appBar,
            foregroundColor: StoreTheme.appBarForeground,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _heroCard(context),
              const SizedBox(height: 12),
              if (_lastSyncAt != null)
                Text(
                  context.t(
                    'آخر مزامنة: ${_lastSyncAt!.toLocal()}',
                    'Last sync: ${_lastSyncAt!.toLocal()}',
                  ),
                  style: const TextStyle(color: StoreTheme.muted),
                ),
              if (_lastSummary != null) ...[
                const SizedBox(height: 6),
                Text(
                  _lastSummary!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: StoreTheme.ink,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_syncing) ...[
                LinearProgressIndicator(
                  value: _progress?.fraction,
                  color: StoreTheme.accent,
                  backgroundColor: StoreTheme.border,
                ),
                const SizedBox(height: 8),
                Text(_progress?.detail ?? context.t('جاري…', 'Working…')),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _cancel = true),
                  child: Text(context.t('إلغاء', 'Cancel')),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _syncing ? null : () => _runSync(withProducts: true),
                style: FilledButton.styleFrom(
                  backgroundColor: StoreTheme.accent,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.sync),
                label: Text(
                  context.t(
                    'مزامنة الموردين + الكتالوج الكامل',
                    'Sync suppliers + full catalogs',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _syncing ? null : () => _runSync(withProducts: false),
                icon: const Icon(Icons.storefront_outlined),
                label: Text(
                  context.t(
                    'تحديث بيانات الموردين فقط',
                    'Update supplier contacts only',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t(
                  'المزامنة تسحب كل صفحات كتالوج WooCommerce لكل مورد مفعّل (قد تستغرق دقائق للمتاجر الكبيرة مثل ميكرز).',
                  'Sync pulls every WooCommerce catalog page for each enabled supplier (large shops like Makers may take several minutes).',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t(
                  'التحديث التلقائي: بعد المزامنة الأولى يمكن جدولة Cloud Function أسبوعياً (جاهز في functions/store_suppliers_sync.js).',
                  'Auto-update: after the first sync you can schedule the weekly Cloud Function (functions/store_suppliers_sync.js).',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: StoreTheme.muted,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.t(
                  'الموردون في الدليل (${egyptStoreSuppliersCatalog.length})',
                  'Directory suppliers (${egyptStoreSuppliersCatalog.length})',
                ),
                style: StoreTheme.sectionTitle.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 8),
              ...egyptStoreSuppliersCatalog.map(_supplierTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StoreTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StoreTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'دليل موردين لكل التخصصات',
              'Supplier directory for every specialty',
            ),
            style: const TextStyle(
              color: StoreTheme.ink,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              '${egyptStoreSuppliersCatalog.length} مورداً عبر كل التخصصات · ${egyptStoreSuppliersWithProductSync.length} مصادر بمنتجات عبر API',
              '${egyptStoreSuppliersCatalog.length} suppliers across specialties · ${egyptStoreSuppliersWithProductSync.length} sources with product API',
            ),
            style: const TextStyle(
              color: StoreTheme.muted,
              height: 1.35,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierTile(EgyptStoreSupplier supplier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('store_suppliers')
            .doc(supplier.id)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final status = DirectoryTrustStatus.resolve(
            directoryStatus: data?['directoryStatus']?.toString(),
            isPartner: data?['isPartner'] == true,
            isVerifiedSeller: data?['isVerifiedSeller'] == true,
            claimedByUid: data?['claimedByUid']?.toString(),
          );
          return ListTile(
            leading: Icon(
              supplier.productSyncEnabled
                  ? Icons.cloud_sync_outlined
                  : Icons.contact_phone_outlined,
              color: StoreTheme.ink,
            ),
            title: Text(
              supplier.nameAr,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                DirectoryTrustChip(status: status, compact: true),
                const SizedBox(height: 4),
                Text(
                  [
                    if (supplier.city.isNotEmpty) supplier.city,
                    if (supplier.phone.isNotEmpty) supplier.phone,
                    if (supplier.productSyncEnabled)
                      context.t('مزامنة منتجات', 'Product sync'),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: context.t('حالة الدليل', 'Directory status'),
                  onSelected: (s) async {
                    try {
                      await DirectoryTrustService.instance.setSupplierStatus(
                        supplierId: supplier.id,
                        status: s,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.t(
                              'تم تحديث الحالة: ${DirectoryTrustStatus.label(s, isAr: true)}',
                              'Status updated: ${DirectoryTrustStatus.label(s, isAr: false)}',
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e')),
                      );
                    }
                  },
                  itemBuilder: (_) => DirectoryTrustStatus.all
                      .map(
                        (s) => PopupMenuItem(
                          value: s,
                          child: Text(
                            DirectoryTrustStatus.label(
                              s,
                              isAr: Localizations.localeOf(context)
                                      .languageCode ==
                                  'ar',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                IconButton(
                  tooltip: context.t('فتح الموقع', 'Open website'),
                  icon: const Icon(Icons.open_in_new, size: 20),
                  onPressed: () async {
                    final uri = Uri.tryParse(supplier.website);
                    if (uri == null) return;
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

