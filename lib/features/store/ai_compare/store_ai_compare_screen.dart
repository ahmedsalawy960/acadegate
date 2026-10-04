import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../../core/widgets/acadegate_app_bar.dart';
import '../store_product_navigation.dart';
import '../store_theme.dart';
import 'store_ai_compare_service.dart';

/// بحث بالذكاء ثم مقارنة نفس الجهاز بين الموردين حسب السعر والموديل.
class StoreAiCompareScreen extends StatefulWidget {
  final String initialQuery;
  final String brand;
  final String categoryTitle;
  final String description;
  final String? productId;
  final String storeName;
  final num price;
  final String? imageUrl;
  final String? sourceUrl;

  const StoreAiCompareScreen({
    super.key,
    this.initialQuery = '',
    this.brand = '',
    this.categoryTitle = '',
    this.description = '',
    this.productId,
    this.storeName = '',
    this.price = 0,
    this.imageUrl,
    this.sourceUrl,
  });

  @override
  State<StoreAiCompareScreen> createState() => _StoreAiCompareScreenState();
}

class _StoreAiCompareScreenState extends State<StoreAiCompareScreen> {
  late final TextEditingController _query;
  bool _loading = false;
  String? _error;
  StoreAiCompareResult? _result;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  StoreAiCompareOffer? get _current {
    final name = widget.initialQuery.trim();
    if (name.isEmpty || widget.productId == null && widget.storeName.isEmpty) {
      return null;
    }
    if (widget.productId == null && widget.price <= 0 && widget.storeName.isEmpty) {
      return null;
    }
    return StoreAiCompareOffer(
      name: name,
      storeName: widget.storeName,
      price: widget.price,
      brand: widget.brand,
      description: widget.description,
      productId: widget.productId,
      sourceUrl: widget.sourceUrl,
      imageUrl: widget.imageUrl,
      isCurrent: true,
    );
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await StoreAiCompareService.instance.compare(
        query: _query.text,
        brand: widget.brand,
        categoryTitle: widget.categoryTitle,
        description: widget.description,
        excludeProductId: widget.productId,
        current: _query.text.trim() == widget.initialQuery.trim()
            ? _current
            : null,
        onPreview: (preview) {
          if (!mounted) return;
          setState(() => _result = preview);
        },
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(StoreAiCompareOffer offer) async {
    final product = offer.catalogProduct;
    if (product != null) {
      await openStoreProductDetail(context, product);
      return;
    }
    final url = (offer.sourceUrl ?? '').trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final cheapest = _cheapest(result?.same ?? const []);

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(context.t('بحث ومقارنة الأسعار', 'Search and compare prices')),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              context.t(
                'اكتب اسم الجهاز. نجمع العروض من الكتالوج وباقي الموردين، '
                'ونطابق نفس الجهاز حتى لو اختلف الاسم قليلاً، ثم نرتّب الأرخص أولاً.',
                'Type a device name. We gather offers from the catalog and other suppliers, '
                'match the same device even if the title differs slightly, then list the lowest price first.',
              ),
              style: const TextStyle(
                color: StoreTheme.muted,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              style: const TextStyle(color: StoreTheme.ink),
              cursorColor: StoreTheme.ink,
              decoration: InputDecoration(
                labelText: context.t('اسم الجهاز أو الموديل', 'Device or model'),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loading ? null : _run(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _run,
              style: FilledButton.styleFrom(
                backgroundColor: StoreTheme.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.price_check),
              label: Text(
                _loading
                    ? context.t(
                        _result == null
                            ? 'جارٍ البحث والمقارنة…'
                            : 'جارٍ تدقيق الأسماء…',
                        _result == null
                            ? 'Searching and comparing…'
                            : 'Checking names…',
                      )
                    : context.t('ابحث وقارن', 'Search and compare'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: StoreTheme.danger)),
            ],
            if (result != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: StoreTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StoreTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.deviceLabel,
                      style: const TextStyle(
                        color: StoreTheme.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.summary,
                      style: const TextStyle(
                        color: StoreTheme.ink,
                        height: 1.4,
                      ),
                    ),
                    if (result.notice != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.notice!,
                        style: const TextStyle(
                          color: StoreTheme.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _heading(context.t(
                'نفس الجهاز — الأرخص أولاً',
                'Same device — lowest price first',
              )),
              if (result.same.isEmpty)
                Text(
                  context.t(
                    'لم يُعثر على نفس الجهاز لدى مورد آخر.',
                    'The same device was not found at another supplier.',
                  ),
                  style: const TextStyle(color: StoreTheme.muted),
                )
              else
                ...result.same.map(
                  (row) => _OfferCard(
                    row: row,
                    cheapest: cheapest != null && identical(row, cheapest),
                    onOpen: () => _open(row.offer),
                  ),
                ),
              if (result.related.isNotEmpty) ...[
                _heading(context.t(
                  'موديلات قريبة — ليست نفس الجهاز',
                  'Related models — not the same device',
                )),
                ...result.related.map(
                  (row) => _OfferCard(row: row, onOpen: () => _open(row.offer)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  StoreAiCompareRow? _cheapest(List<StoreAiCompareRow> rows) {
    StoreAiCompareRow? best;
    for (final row in rows) {
      if (row.offer.price <= 0) continue;
      if (best == null || row.offer.price < best.offer.price) best = row;
    }
    return best;
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: StoreTheme.ink,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final StoreAiCompareRow row;
  final bool cheapest;
  final VoidCallback onOpen;

  const _OfferCard({
    required this.row,
    this.cheapest = false,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final offer = row.offer;
    final price = offer.price > 0
        ? '${offer.price} ${context.t('ج.م', 'EGP')}'
        : context.t('السعر عند المورد', 'Price via supplier');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cheapest ? const Color(0xFF1E3358) : StoreTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cheapest ? const Color(0xFFFBBF24) : StoreTheme.border,
                width: cheapest ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        offer.name,
                        style: const TextStyle(
                          color: StoreTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (cheapest)
                      Container(
                        margin: const EdgeInsetsDirectional.only(start: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          context.t('الأقل سعراً', 'Lowest price'),
                          style: const TextStyle(
                            color: Color(0xFF071433),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  offer.storeName.isEmpty
                      ? context.t('مورد', 'Supplier')
                      : offer.storeName,
                  style: const TextStyle(color: StoreTheme.muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    color: StoreTheme.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (row.model.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${context.t('الموديل', 'Model')}: ${row.model}',
                    style: const TextStyle(color: StoreTheme.ink, fontSize: 13),
                  ),
                ],
                if (row.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    row.notes,
                    style: const TextStyle(
                      color: StoreTheme.muted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
                if (offer.isCurrent) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.t('هذا الجهاز الذي فتحته', 'This is the device you opened'),
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
