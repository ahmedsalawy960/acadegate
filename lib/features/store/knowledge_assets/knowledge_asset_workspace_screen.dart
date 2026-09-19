import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/locale_extensions.dart';
import '../store_theme.dart';
import 'knowledge_asset_access_service.dart';
import 'knowledge_asset_models.dart';

class KnowledgeAssetWorkspaceScreen extends StatefulWidget {
  final KnowledgeLicense license;

  const KnowledgeAssetWorkspaceScreen({super.key, required this.license});

  @override
  State<KnowledgeAssetWorkspaceScreen> createState() =>
      _KnowledgeAssetWorkspaceScreenState();
}

class _KnowledgeAssetWorkspaceScreenState
    extends State<KnowledgeAssetWorkspaceScreen> {
  bool _loading = true;
  String? _error;
  KnowledgeAssetAccessBundle? _bundle;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await KnowledgeAssetAccessService.instance
          .openProtectedAsset(license: widget.license);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    final bundle = _bundle;
    if (bundle == null) return;
    try {
      await KnowledgeAssetAccessService.instance.exportLicensedCopy(
        license: bundle.license,
        plainBytes: bundle.plainBytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم تجهيز النسخة المرخّصة', 'Licensed copy ready'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = widget.license;
    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(
            license.productName.isNotEmpty
                ? license.productName
                : context.t('بيئة الأصل المعرفي', 'Knowledge workspace'),
          ),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
          actions: [
            if (_bundle != null && license.allowExport && license.isActive)
              IconButton(
                tooltip: context.t('تصدير مرخّص', 'Licensed export'),
                onPressed: _export,
                icon: const Icon(Icons.ios_share_outlined),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _open,
                            child: Text(context.t('إعادة المحاولة', 'Retry')),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final license = _bundle!.license;
    final text = _bundle!.textPreview;
    final rental = license.licenseMode == KnowledgeLicenseMode.rental;

    return Column(
      children: [
        Material(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t(
                      'جلسة مرخّصة · ${rental ? 'إيجار' : 'بيع'}'
                      '${license.expiresAt != null ? ' · حتى ${license.expiresAt!.toLocal().toString().split('.').first}' : ''}'
                      ' · فك التشفير داخل التطبيق فقط',
                      'Licensed session · ${rental ? 'rental' : 'sale'}'
                      '${license.expiresAt != null ? ' · until ${license.expiresAt!.toLocal()}' : ''}'
                      ' · decrypt in-app only',
                    ),
                    style: const TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Text(
            context.t(
              'تنبيه: الحماية تقلّل التسريب وليست ضماناً مطلقاً ضد لقطات الشاشة أو إعادة الكتابة.',
              'Note: protection reduces leakage; it is not absolute against screenshots or retyping.',
            ),
            style: const TextStyle(fontSize: 11.5, color: StoreTheme.muted),
          ),
        ),
        Expanded(
          child: text != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StoreTheme.hairline),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        context.t(
                          'أصل ثنائي (${license.assetFileName}) محمّل في الجلسة.',
                          'Binary asset (${license.assetFileName}) loaded in session.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          'الحجم: ${(_bundle!.plainBytes.length / 1024).toStringAsFixed(1)} ك.ب',
                          'Size: ${(_bundle!.plainBytes.length / 1024).toStringAsFixed(1)} KB',
                        ),
                        style: const TextStyle(color: StoreTheme.muted),
                      ),
                      if (license.allowExport) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _export,
                          icon: const Icon(Icons.ios_share_outlined),
                          label: Text(
                            context.t(
                              'تصدير نسخة مرخّصة',
                              'Export licensed copy',
                            ),
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            context.t(
                              'الإيجار لا يسمح بالتصدير خارج الجلسة.',
                              'Rental does not allow export outside the session.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: StoreTheme.muted),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        if (text != null && license.allowExport)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(
                  context.t('تصدير نسخة مرخّصة', 'Export licensed copy'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
