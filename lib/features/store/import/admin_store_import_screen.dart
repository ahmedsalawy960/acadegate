import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../auth/user_account_service.dart';
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
          backgroundColor: Colors.green[700],
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
    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data?.isAdmin == true;
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AcadeGateAppBar(
            title: Text(
              context.t('استيراد موردين المتجر', 'Store supplier import'),
            ),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
          body: !isAdmin
              ? Center(
                  child: Text(
                    context.t(
                      'هذه الصفحة للمسؤولين فقط',
                      'Admins only',
                    ),
                  ),
                )
              : ListView(
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
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    if (_lastSummary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _lastSummary!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_syncing) ...[
                      LinearProgressIndicator(
                        value: _progress?.fraction,
                        color: Colors.green[700],
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
                      onPressed: _syncing
                          ? null
                          : () => _runSync(withProducts: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.sync),
                      label: Text(
                        context.t(
                          'مزامنة الموردين + المنتجات الآن',
                          'Sync suppliers + products now',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _syncing
                          ? null
                          : () => _runSync(withProducts: false),
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
                        'التحديث التلقائي: بعد المزامنة الأولى يمكن جدولة Cloud Function أسبوعياً (جاهز في functions/store_suppliers_sync.js).',
                        'Auto-update: after the first sync you can schedule the weekly Cloud Function (functions/store_suppliers_sync.js).',
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.t(
                        'الموردون في الدليل (${egyptStoreSuppliersCatalog.length})',
                        'Directory suppliers (${egyptStoreSuppliersCatalog.length})',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...egyptStoreSuppliersCatalog.map(_supplierTile),
                  ],
                ),
        );
      },
    );
  }

  Widget _heroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(14),
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
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              '${egyptStoreSuppliersCatalog.length} مورداً عبر كل التخصصات · ${egyptStoreSuppliersWithProductSync.length} مصادر بمنتجات عبر API',
              '${egyptStoreSuppliersCatalog.length} suppliers across specialties · ${egyptStoreSuppliersWithProductSync.length} sources with product API',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierTile(EgyptStoreSupplier supplier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          supplier.productSyncEnabled
              ? Icons.cloud_sync_outlined
              : Icons.contact_phone_outlined,
          color: Colors.green[700],
        ),
        title: Text(
          supplier.nameAr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (supplier.city.isNotEmpty) supplier.city,
            if (supplier.phone.isNotEmpty) supplier.phone,
            if (supplier.email.isNotEmpty) supplier.email,
            if (supplier.productSyncEnabled)
              context.t('مزامنة منتجات', 'Product sync'),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: context.t('فتح الموقع', 'Open website'),
          icon: const Icon(Icons.open_in_new, size: 20),
          onPressed: () async {
            final uri = Uri.tryParse(supplier.website);
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }
}
