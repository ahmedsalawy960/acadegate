import 'package:flutter/material.dart';

import '../../../core/locale/l10n_lookup.dart';
import '../../../core/locale/locale_extensions.dart';
import '../store_categories.dart';
import '../store_theme.dart';
import 'product_import_parser.dart';

Future<StoreCategory?> pickStoreCategory(
  BuildContext context, {
  String? subtitleAr,
  String? subtitleEn,
}) {
  return showModalBottomSheet<StoreCategory>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ctx.t('اختر قسم المنتج', 'Choose product category'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitleAr != null) ...[
                const SizedBox(height: 4),
                Text(
                  ctx.t(subtitleAr, subtitleEn ?? subtitleAr),
                  style: TextStyle(color: StoreTheme.muted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: storeCategories.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = storeCategories[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.color.withValues(alpha: 0.15),
                        child: Icon(c.icon, color: c.color, size: 22),
                      ),
                      title: Text(L10nLookup.storeCategoryTitle(c.id)),
                      subtitle: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? c.audienceAr
                            : c.audienceEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Default category + store name + contact applied to every imported product.
class BulkListingFields extends StatelessWidget {
  const BulkListingFields({
    super.key,
    required this.category,
    required this.onCategoryChanged,
    required this.storeNameController,
    required this.contactController,
    this.markupController,
    this.onMarkupChanged,
    this.enabled = true,
  });

  final StoreCategory category;
  final ValueChanged<StoreCategory> onCategoryChanged;
  final TextEditingController storeNameController;
  final TextEditingController contactController;
  final TextEditingController? markupController;
  final VoidCallback? onMarkupChanged;
  final bool enabled;

  /// Empty or invalid input means no margin.
  static num parseMarkup(TextEditingController? controller) {
    final raw = (controller?.text ?? '').trim();
    final negative = raw.startsWith('-');
    final v = ProductImportParser.parsePrice(raw.replaceFirst('-', '')) ?? 0;
    return negative ? -v : v;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: category.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.t(
              'القسم الافتراضي (للصفوف بدون قسم)',
              'Default category (rows without one)',
            ),
            border: const OutlineInputBorder(),
          ),
          items: storeCategories
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    L10nLookup.storeCategoryTitle(c.id),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: !enabled
              ? null
              : (id) {
                  final c = id == null ? null : storeCategoryById(id);
                  if (c != null) onCategoryChanged(c);
                },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: storeNameController,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: context.t(
              'اسم المورد/المتجر (اختياري)',
              'Supplier/store name (optional)',
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: contactController,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: context.t(
              'رقم/وسيلة تواصل (اختياري)',
              'Phone/contact (optional)',
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        if (markupController != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: markupController,
            enabled: enabled,
            onChanged: (_) => onMarkupChanged?.call(),
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: context.t('نسبة الربح %', 'Profit margin %'),
              hintText: context.t('مثال: 15', 'e.g. 15'),
              suffixText: '%',
              helperText: context.t(
                'تُضاف لسعر المورد عند الاستيراد وعند كل تحديث، والسعر يُقرَّب لأقرب جنيه',
                'Added to the supplier price on import and every refresh, rounded to whole pounds',
              ),
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.trending_up),
            ),
          ),
        ],
      ],
    );
  }
}
