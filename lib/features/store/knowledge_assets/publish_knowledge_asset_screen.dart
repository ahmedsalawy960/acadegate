import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../auth/user_account_service.dart';
import '../store_theme.dart';
import 'knowledge_asset_models.dart';
import 'knowledge_asset_publish_service.dart';

class PublishKnowledgeAssetScreen extends StatefulWidget {
  const PublishKnowledgeAssetScreen({super.key});

  @override
  State<PublishKnowledgeAssetScreen> createState() =>
      _PublishKnowledgeAssetScreenState();
}

class _PublishKnowledgeAssetScreenState
    extends State<PublishKnowledgeAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _store = TextEditingController();
  final _contact = TextEditingController();

  String _kind = KnowledgeAssetKind.code;
  String _licenseMode = KnowledgeLicenseMode.sale;
  int _rentalDays = 30;
  bool _saving = false;
  bool _picking = false;

  List<int>? _bytes;
  String? _fileName;
  String? _mime;

  @override
  void initState() {
    super.initState();
    _prefillStore();
  }

  Future<void> _prefillStore() async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    if (!mounted) return;
    if ((account?.displayName ?? '').trim().isNotEmpty) {
      _store.text = account!.displayName.trim();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _store.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final picked =
          await KnowledgeAssetPublishService.instance.pickAssetFile();
      if (picked == null || !mounted) return;
      setState(() {
        _bytes = picked.bytes;
        _fileName = picked.name;
        _mime = picked.mime;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bytes == null || _fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('ارفع ملف الأصل أولاً', 'Upload the asset file first'),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final price = num.parse(_price.text.trim().replaceAll(',', '.'));
      await KnowledgeAssetPublishService.instance.publish(
        name: _name.text,
        description: _desc.text,
        price: price,
        storeName: _store.text,
        contact: _contact.text,
        kind: _kind,
        licenseMode: _licenseMode,
        rentalDays:
            _licenseMode == KnowledgeLicenseMode.rental ? _rentalDays : null,
        fileBytes: _bytes!,
        fileName: _fileName!,
        mimeType: _mime ?? 'application/octet-stream',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم نشر الأصل المعرفي مشفّراً في المتجر',
              'Knowledge asset published encrypted to the store',
            ),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _kindLabel(String k) {
    switch (k) {
      case KnowledgeAssetKind.code:
        return context.t('شيفرة / سكربت تحليل', 'Code / analysis script');
      case KnowledgeAssetKind.model3d:
        return context.t('نموذج ثلاثي الأبعاد', '3D model');
      case KnowledgeAssetKind.dataset:
        return context.t('مجموعة بيانات', 'Dataset');
      case KnowledgeAssetKind.template:
        return context.t('قالب / بروتوكول', 'Template / protocol');
      default:
        return context.t('أخرى', 'Other');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(
            context.t('نشر أصل معرفي', 'Publish knowledge asset'),
          ),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Text(
                  context.t(
                    'يُشفَّر الملف قبل الرفع. المشتري يستخدمه داخل AcadeGate حسب الترخيص. '
                    'الحماية تقلّل التسريب وليست ضماناً مطلقاً ضد كل أشكال النسخ.',
                    'The file is encrypted before upload. Buyers use it inside AcadeGate per license. '
                    'Protection reduces leakage; it is not an absolute anti-copy guarantee.',
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.t('عنوان الأصل', 'Asset title'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? context.t('مطلوب', 'Required')
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: context.t(
                    'الوصف وما يغطيه الترخيص',
                    'Description & license coverage',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: context.t('السعر (ج.م)', 'Price (EGP)'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n <= 0) {
                    return context.t('أدخل سعراً أكبر من صفر', 'Enter price > 0');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: context.t('نوع الأصل', 'Asset kind'),
                  border: const OutlineInputBorder(),
                ),
                items: KnowledgeAssetKind.all
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(_kindLabel(k)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _kind = v);
                },
              ),
              const SizedBox(height: 12),
              Text(
                context.t('نمط الترخيص', 'License mode'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              RadioListTile<String>(
                value: KnowledgeLicenseMode.sale,
                groupValue: _licenseMode,
                title: Text(context.t('بيع ترخيص دائم', 'Perpetual sale')),
                subtitle: Text(
                  context.t(
                    'استخدام داخل التطبيق + تصدير مرخّص بعلامة مائية',
                    'In-app use + watermarked licensed export',
                  ),
                ),
                onChanged: (v) => setState(() => _licenseMode = v!),
              ),
              RadioListTile<String>(
                value: KnowledgeLicenseMode.rental,
                groupValue: _licenseMode,
                title: Text(context.t('إيجار مؤقت', 'Temporary rental')),
                subtitle: Text(
                  context.t(
                    'عرض واستخدام داخل التطبيق فقط — بدون تصدير',
                    'In-app view/use only — no export',
                  ),
                ),
                onChanged: (v) => setState(() => _licenseMode = v!),
              ),
              if (_licenseMode == KnowledgeLicenseMode.rental) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(context.t('المدة (أيام):', 'Days:')),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _rentalDays,
                      items: const [7, 14, 30, 60, 90]
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _rentalDays = v);
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _store,
                decoration: InputDecoration(
                  labelText: context.t('اسم البائع / المتجر', 'Seller / store name'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? context.t('مطلوب', 'Required')
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contact,
                decoration: InputDecoration(
                  labelText: context.t('تواصل (اختياري)', 'Contact (optional)'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: (_saving || _picking) ? null : _pick,
                icon: _picking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(
                  _fileName != null
                      ? context.t('الملف: $_fileName', 'File: $_fileName')
                      : context.t(
                          'رفع ملف مشفّر (كود / 3D / بيانات…)',
                          'Upload protected file (code / 3D / data…)',
                        ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _publish,
                style: FilledButton.styleFrom(
                  backgroundColor: StoreTheme.accent,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(
                  _saving
                      ? context.t('جارٍ التشفير والنشر…', 'Encrypting & publishing…')
                      : context.t('تشفير ونشر في المتجر', 'Encrypt & publish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
