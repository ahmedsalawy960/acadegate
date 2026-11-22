import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/app_translate.dart';
import '../../../core/locale/l10n_lookup.dart';
import '../../../core/locale/locale_extensions.dart';
import '../../auth/provider_publish_gate.dart';
import '../../thesis_studio/thesis_studio_file_share.dart';
import '../store_categories.dart';
import '../store_theme.dart';
import 'bulk_listing_form.dart';
import 'merchant_product_bulk_service.dart';
import 'merchant_sell_gate.dart';
import 'product_import_parser.dart';

/// Upload a CSV / Excel product list, review row errors, then import.
class ProductSheetImportScreen extends StatefulWidget {
  const ProductSheetImportScreen({
    super.key,
    this.supplierId,
    this.storeNameHint,
    this.contactHint,
    this.initialCategoryTitle,
  });

  final String? supplierId;
  final String? storeNameHint;
  final String? contactHint;
  final String? initialCategoryTitle;

  @override
  State<ProductSheetImportScreen> createState() =>
      _ProductSheetImportScreenState();
}

class _ProductSheetImportScreenState extends State<ProductSheetImportScreen> {
  late StoreCategory _category;
  late final TextEditingController _storeName;
  late final TextEditingController _contact;
  final _markup = TextEditingController();
  static const _markupScope = 'sheet';

  String? _fileName;
  ProductImportParseResult? _parsed;
  bool _onlyProblems = false;
  bool _updateBySku = true;
  bool _importing = false;
  BulkWriteProgress? _progress;

  @override
  void initState() {
    super.initState();
    _category = storeCategoryByTitle(widget.initialCategoryTitle ?? '') ??
        storeCategories.last;
    _storeName = TextEditingController(text: widget.storeNameHint ?? '');
    _contact = TextEditingController(text: widget.contactHint ?? '');
    MerchantProductBulkService.instance.loadMarkup(_markupScope).then((v) {
      if (!mounted || v == null || v == 0 || _markup.text.isNotEmpty) return;
      setState(() => _markup.text = v == v.roundToDouble() ? '${v.toInt()}' : '$v');
    });
  }

  num get _markupPercent => BulkListingFields.parseMarkup(_markup);

  @override
  void dispose() {
    _storeName.dispose();
    _contact.dispose();
    _markup.dispose();
    super.dispose();
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveTemplate() async {
    // BOM makes Excel open the Arabic sample rows as UTF-8.
    final bytes = Uint8List.fromList(
      utf8.encode('\uFEFF${ProductImportParser.templateCsv()}'),
    );
    try {
      await shareThesisFile(bytes: bytes, name: 'acadegate_products_template.csv');
    } catch (e) {
      if (!mounted) return;
      _toast('$e', error: true);
    }
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(
      ClipboardData(text: ProductImportParser.templateCsv()),
    );
    if (!mounted) return;
    _toast(context.t('تم نسخ القالب', 'Template copied'));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ProductImportParser.supportedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      _toast(context.t('تعذر قراءة الملف', 'Could not read file'), error: true);
      return;
    }
    try {
      final parsed = ProductImportParser.parseBytes(
        bytes: bytes,
        fileName: file.name,
      );
      setState(() {
        _fileName = file.name;
        _parsed = parsed;
        _onlyProblems = parsed.invalidCount > 0;
      });
    } on FormatException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      _toast('${context.t('تعذر قراءة الملف', 'Could not read file')}: $e',
          error: true);
    }
  }

  Future<void> _import() async {
    final parsed = _parsed;
    if (parsed == null || parsed.validCount == 0) return;
    final account = await ensureMerchantCanSell(context);
    if (account == null || !mounted) return;

    setState(() {
      _importing = true;
      _progress = null;
    });
    try {
      final markup = _markupPercent;
      await MerchantProductBulkService.instance.saveMarkup(_markupScope, markup);
      final result = await MerchantProductBulkService.instance.importRows(
        rows: parsed.rows,
        updateExistingBySku: _updateBySku,
        listing: MerchantListingContext(
          defaultCategory: _category.title,
          approvalStatus: ProviderPublishGate.contentApprovalStatus(account),
          storeName: _storeName.text.trim(),
          contact: _contact.text.trim(),
          supplierId: widget.supplierId,
          markupPercent: markup,
        ),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('اكتمل الاستيراد', 'Import complete')),
          content: Text(
            ctx.t(
              'منتجات جديدة: ${result.created}\nمحدّثة (نفس SKU): ${result.updated}\nصفوف متخطاة بسبب أخطاء: ${result.skipped}',
              'New products: ${result.created}\nUpdated (same SKU): ${result.updated}\nRows skipped due to errors: ${result.skipped}',
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('تم', 'Done')),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('${context.t('فشل الاستيراد', 'Import failed')}: $e', error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(context.t('رفع قائمة منتجات', 'Upload product list')),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _infoCard(context),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _saveTemplate,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(context.t('تحميل القالب', 'Download template')),
                ),
                OutlinedButton.icon(
                  onPressed: _copyTemplate,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(context.t('نسخ القالب', 'Copy template')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BulkListingFields(
              category: _category,
              onCategoryChanged: (c) => setState(() => _category = c),
              storeNameController: _storeName,
              contactController: _contact,
              markupController: _markup,
              onMarkupChanged: () => setState(() {}),
              enabled: !_importing,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _importing ? null : _pickFile,
              style: FilledButton.styleFrom(
                backgroundColor: StoreTheme.ink,
                foregroundColor: StoreTheme.bg,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.upload_file),
              label: Text(
                _fileName == null
                    ? context.t('اختيار ملف CSV أو Excel', 'Choose CSV or Excel file')
                    : context.t('اختيار ملف آخر', 'Choose another file'),
              ),
            ),
            if (parsed != null) ..._preview(context, parsed),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StoreTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StoreTheme.border),
      ),
      child: Text(
        context.t(
          'حمّل القالب واملأه في Excel، ثم ارفعه بصيغة xlsx أو CSV.\n'
          'الأعمدة المطلوبة: name (الاسم)، price (السعر).\n'
          'اختيارية: category, description, sku, brand, unit, grade, origin_country, city, in_stock, fast_shipping, image_url.\n'
          'القسم يقبل اسم القسم بالعربية أو معرّفه (مثل chemicals). المنتج الذي له نفس SKU لمنتج موجود يتم تحديثه بدلاً من تكراره.',
          'Download the template, fill it in Excel, then upload as xlsx or CSV.\n'
          'Required columns: name, price.\n'
          'Optional: category, description, sku, brand, unit, grade, origin_country, city, in_stock, fast_shipping, image_url.\n'
          'Category accepts the Arabic section title or its id (e.g. chemicals). Rows whose SKU matches an existing product update it instead of duplicating.',
        ),
        style: const TextStyle(height: 1.5, fontSize: 13),
      ),
    );
  }

  List<Widget> _preview(BuildContext context, ProductImportParseResult parsed) {
    final warned = parsed.rows.where((r) => r.warnings.isNotEmpty).length;
    final visible = _onlyProblems
        ? parsed.rows
            .where((r) => !r.isValid || r.warnings.isNotEmpty)
            .toList()
        : parsed.rows;
    const maxShown = 100;

    return [
      const SizedBox(height: 16),
      Text(
        context.t('الملف: $_fileName', 'File: $_fileName'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _countChip(context.t('صالح', 'Valid'), parsed.validCount,
              StoreTheme.verified),
          _countChip(context.t('به أخطاء', 'Errors'), parsed.invalidCount,
              StoreTheme.danger),
          _countChip(context.t('تنبيهات', 'Warnings'), warned,
              const Color(0xFFB45309)),
        ],
      ),
      if (parsed.unknownColumns.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          context.t(
            'أعمدة غير معروفة تم تجاهلها: ${parsed.unknownColumns.join('، ')}',
            'Unknown columns ignored: ${parsed.unknownColumns.join(', ')}',
          ),
          style: TextStyle(color: StoreTheme.muted, fontSize: 12),
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.t('عرض الصفوف التي بها مشاكل فقط',
            'Show only rows with problems')),
        value: _onlyProblems,
        onChanged: (v) => setState(() => _onlyProblems = v),
      ),
      ...visible.take(maxShown).map((r) => _rowTile(context, r)),
      if (visible.length > maxShown)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            context.t('... و ${visible.length - maxShown} صف إضافي',
                '... and ${visible.length - maxShown} more rows'),
            style: TextStyle(color: StoreTheme.muted),
          ),
        ),
      if (visible.isEmpty)
        Text(context.t('لا توجد مشاكل 👍', 'No problems found')),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.t('تحديث المنتجات الموجودة بنفس SKU',
            'Update existing products with the same SKU')),
        subtitle: Text(context.t(
          'بدلاً من إنشاء نسخة مكررة — مفيد لتحديث الأسعار من نفس الملف',
          'Instead of creating duplicates — handy for refreshing prices',
        )),
        value: _updateBySku,
        onChanged: _importing ? null : (v) => setState(() => _updateBySku = v),
      ),
      if (_importing) ...[
        LinearProgressIndicator(
          value: _progress?.fraction,
          color: StoreTheme.accent,
          backgroundColor: StoreTheme.border,
        ),
        const SizedBox(height: 6),
        Text(
          context.t(
            'جارٍ الحفظ ${_progress?.done ?? 0} / ${_progress?.total ?? parsed.validCount}',
            'Saving ${_progress?.done ?? 0} / ${_progress?.total ?? parsed.validCount}',
          ),
        ),
        const SizedBox(height: 8),
      ],
      FilledButton.icon(
        onPressed: _importing || parsed.validCount == 0 ? null : _import,
        style: FilledButton.styleFrom(
          backgroundColor: StoreTheme.accent,
          minimumSize: const Size.fromHeight(50),
        ),
        icon: const Icon(Icons.cloud_upload_outlined),
        label: Text(
          context.t(
            'استيراد ${parsed.validCount} منتج',
            'Import ${parsed.validCount} product(s)',
          ),
        ),
      ),
      if (parsed.invalidCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            context.t(
              'الصفوف التي بها أخطاء (${parsed.invalidCount}) لن تُستورد — صحّحها في الملف وارفعه مرة أخرى.',
              'Rows with errors (${parsed.invalidCount}) will not be imported — fix them and re-upload.',
            ),
            style: TextStyle(color: StoreTheme.muted, fontSize: 12),
          ),
        ),
    ];
  }

  Widget _countChip(String label, int count, Color color) {
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      label: Text(
        '$label: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _rowTile(BuildContext context, ProductImportRow r) {
    final categoryTitle = r.category ?? _category.title;
    final category = storeCategoryByTitle(categoryTitle);
    final categoryLabel = category != null
        ? L10nLookup.storeCategoryTitle(category.id)
        : categoryTitle;
    final markup = _markupPercent;
    final currency = appTr('ج.م', 'EGP');
    final price = r.price == null
        ? '—'
        : markup == 0
            ? '${r.price} $currency'
            : appTr(
                '${r.price} ← ${MerchantProductBulkService.applyMarkup(r.price!, markup)} $currency',
                '${r.price} → ${MerchantProductBulkService.applyMarkup(r.price!, markup)} $currency',
              );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: r.isValid ? StoreTheme.border : StoreTheme.danger,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${r.rowNumber}',
                  style: TextStyle(color: StoreTheme.muted, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.name.isEmpty ? '—' : r.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                price,
                categoryLabel,
                if (r.sku.isNotEmpty) 'SKU ${r.sku}',
                if (!r.inStock) context.t('غير متوفر', 'Out of stock'),
              ].join(' · '),
              style: TextStyle(color: StoreTheme.muted, fontSize: 12),
            ),
            for (final e in r.errors)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('✖ $e',
                    style: const TextStyle(color: StoreTheme.danger, fontSize: 12)),
              ),
            for (final w in r.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('⚠ $w',
                    style: const TextStyle(color: Color(0xFFB45309), fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
