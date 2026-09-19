import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale/locale_extensions.dart';
import 'store_cart_service.dart';
import 'store_catalog_service.dart';
import 'store_product_navigation.dart';
import 'store_protocol_sim_models.dart';
import 'store_protocol_sim_service.dart';
import 'store_theme.dart';

/// يفتح إدخال البروتوكول ثم يعرض نتيجة المحاكاة الاسترشادية.
Future<void> showProtocolSimFlow(
  BuildContext context, {
  required List<StoreCartItem> cartItems,
}) async {
  final input = await showModalBottomSheet<_ProtocolSimInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: StoreTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _ProtocolSimInputSheet(),
  );
  if (input == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                context.t(
                  'جارٍ محاكاة البروتوكول مقابل السلة…',
                  'Simulating protocol against cart…',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  ProtocolSimResult result;
  try {
    result = await StoreProtocolSimService.instance.analyze(
      cartItems: cartItems,
      protocolText: input.text,
      fileBytes: input.bytes,
      fileName: input.fileName,
      fileMime: input.mime,
    );
  } catch (e) {
    result = ProtocolSimResult(error: '$e');
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // loading dialog

  if (result.hasError && !result.hasContent) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error!)),
    );
    return;
  }

  await showProtocolSimResultSheet(context, result);
}

Future<void> showProtocolSimResultSheet(
  BuildContext context,
  ProtocolSimResult result,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: StoreTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return _ProtocolSimResultBody(
            result: result,
            scrollController: controller,
          );
        },
      );
    },
  );
}

class _ProtocolSimInput {
  final String text;
  final List<int>? bytes;
  final String? fileName;
  final String? mime;

  const _ProtocolSimInput({
    this.text = '',
    this.bytes,
    this.fileName,
    this.mime,
  });
}

class _ProtocolSimInputSheet extends StatefulWidget {
  const _ProtocolSimInputSheet();

  @override
  State<_ProtocolSimInputSheet> createState() => _ProtocolSimInputSheetState();
}

class _ProtocolSimInputSheetState extends State<_ProtocolSimInputSheet> {
  final _controller = TextEditingController();
  List<int>? _bytes;
  String? _fileName;
  String? _mime;
  bool _picking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final picked = await StoreProtocolSimService.instance.pickProtocolFile();
      if (picked == null || !mounted) return;
      setState(() {
        _bytes = picked.bytes;
        _fileName = picked.name;
        _mime = picked.mime;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && (_bytes == null || _bytes!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'الصق البروتوكول أو ارفع ملفاً أولاً',
              'Paste the protocol or upload a file first',
            ),
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _ProtocolSimInput(
        text: text,
        bytes: _bytes,
        fileName: _fileName,
        mime: _mime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: StoreTheme.hairline,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.science_outlined, color: StoreTheme.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(
                    'محاكاة البروتوكول قبل الشراء',
                    'Protocol check before purchase',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'فحص استرشادي: توافق السلة مع خطوات التجربة، مخاطر محتملة، كميات، وبدائل من المتجر. ليس ضمان نجاح.',
              'Advisory check: cart vs protocol fit, likely risks, quantities, and store alternatives. Not a success guarantee.',
            ),
            style: const TextStyle(fontSize: 12.5, color: StoreTheme.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: context.t(
                'الصق خطوات البروتوكول / المواد / الظروف هنا…',
                'Paste protocol steps / materials / conditions here…',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _picking ? null : _pickFile,
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
                      'أو ارفع PDF / TXT',
                      'Or upload PDF / TXT',
                    ),
            ),
          ),
          if (_fileName != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() {
                  _bytes = null;
                  _fileName = null;
                  _mime = null;
                }),
                child: Text(context.t('إزالة الملف', 'Remove file')),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              context.t('ابدأ المحاكاة الاسترشادية', 'Start advisory simulation'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolSimResultBody extends StatelessWidget {
  final ProtocolSimResult result;
  final ScrollController scrollController;

  const _ProtocolSimResultBody({
    required this.result,
    required this.scrollController,
  });

  Color _levelColor(ProtocolSimLevel level) {
    switch (level) {
      case ProtocolSimLevel.high:
        return const Color(0xFFB3261E);
      case ProtocolSimLevel.medium:
        return const Color(0xFF9A6B00);
      case ProtocolSimLevel.low:
        return const Color(0xFF1B7F4A);
    }
  }

  String _feasibilityLabel(BuildContext context, ProtocolFeasibility f) {
    switch (f) {
      case ProtocolFeasibility.likely:
        return context.t('توافق مرجّح مع السلة', 'Likely cart fit');
      case ProtocolFeasibility.unlikely:
        return context.t('توافق ضعيف / نواقص مهمة', 'Weak fit / major gaps');
      case ProtocolFeasibility.uncertain:
        return context.t('غير مؤكد — راجع مع مشرف', 'Uncertain — review with supervisor');
    }
  }

  Future<void> _copyReport(BuildContext context) async {
    final buf = StringBuffer()
      ..writeln(
        context.t(
          'محاكاة بروتوكول استرشادية — AcadeGate',
          'Advisory protocol simulation — AcadeGate',
        ),
      )
      ..writeln(result.disclaimer)
      ..writeln()
      ..writeln(result.overallSummary);
    if (result.protocolSummary.isNotEmpty) {
      buf.writeln();
      buf.writeln(result.protocolSummary);
    }
    for (final r in result.risks) {
      buf.writeln('- [${r.severity}] ${r.title}: ${r.detail}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تم النسخ', 'Copied')),
      ),
    );
  }

  void _applyQty(ProtocolSimQtyChange change) {
    StoreCartService.instance.setQuantity(change.productId, change.suggestedQty);
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(result.overallLevel);

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: StoreTheme.hairline,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(Icons.science_outlined, color: levelColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('نتيجة محاكاة البروتوكول', 'Protocol simulation result'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.t('نسخ', 'Copy'),
                onPressed: () => _copyReport(context),
                icon: const Icon(Icons.copy_outlined, size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: levelColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _feasibilityLabel(context, result.feasibility),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: levelColor,
                      ),
                    ),
                    if (result.overallSummary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(result.overallSummary),
                    ],
                    if (result.fromAi) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.modelUsed != null
                            ? 'AI · ${result.modelUsed}'
                            : 'AI',
                        style: const TextStyle(
                          fontSize: 11,
                          color: StoreTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (result.disclaimer.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  result.disclaimer,
                  style: const TextStyle(fontSize: 11.5, color: StoreTheme.muted),
                ),
              ],
              if (result.sourceLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  context.t(
                    'المصدر: ${result.sourceLabel}',
                    'Source: ${result.sourceLabel}',
                  ),
                  style: const TextStyle(fontSize: 11.5, color: StoreTheme.muted),
                ),
              ],
              if (result.protocolSummary.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  context.t('ملخص البروتوكول', 'Protocol summary'),
                ),
                Text(result.protocolSummary),
              ],
              if (result.risks.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(context.t('مخاطر / احتمالات فشل', 'Risks / failure modes')),
                ...result.risks.map((r) => _bulletCard(
                      title: r.title.isEmpty ? r.severity : r.title,
                      body: r.detail,
                      accent: r.severity.toLowerCase() == 'high'
                          ? const Color(0xFFB3261E)
                          : StoreTheme.ink,
                    )),
              ],
              if (result.interactions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  context.t('تفاعلات / عدم توافق محتمل', 'Possible interactions'),
                ),
                ...result.interactions.map((i) => _bulletCard(
                      title: i.materials.join(' + '),
                      body: [
                        if (i.issue.isNotEmpty) i.issue,
                        if (i.mitigation.isNotEmpty)
                          context.t('تخفيف: ${i.mitigation}', 'Mitigation: ${i.mitigation}'),
                      ].join('\n'),
                    )),
              ],
              if (result.quantityChanges.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  context.t('اقتراح تعديل الكميات', 'Suggested quantity changes'),
                ),
                ...result.quantityChanges.map((q) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: StoreTheme.hairline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.productName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t(
                              '${q.currentQty} → ${q.suggestedQty}',
                              '${q.currentQty} → ${q.suggestedQty}',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (q.reason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(q.reason, style: const TextStyle(fontSize: 13)),
                          ],
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: () {
                                _applyQty(q);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.t(
                                        'تم تحديث الكمية في السلة',
                                        'Cart quantity updated',
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                context.t('تطبيق على السلة', 'Apply to cart'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              if (result.gaps.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  context.t('نواقص وبدائل من المتجر', 'Gaps & store alternatives'),
                ),
                ...result.gaps.map((g) => _gapCard(context, g)),
              ],
              if (result.cartNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  context.t('ملاحظات على أصناف السلة', 'Notes on cart items'),
                ),
                ...result.cartNotes.map((n) => _bulletCard(
                      title: n.productName,
                      body: n.note,
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
      ),
    );
  }

  Widget _bulletCard({
    required String title,
    required String body,
    Color accent = StoreTheme.ink,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: StoreTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty)
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w700, color: accent),
            ),
          if (body.trim().isNotEmpty) ...[
            if (title.trim().isNotEmpty) const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13.2)),
          ],
        ],
      ),
    );
  }

  Widget _gapCard(BuildContext context, ProtocolSimGap gap) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: StoreTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(gap.needed, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (gap.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(gap.reason, style: const TextStyle(fontSize: 13)),
          ],
          if (gap.catalogMatches.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.t(
                'لا توجد مطابقات واضحة في الكتالوج الحالي — جرّب البحث يدوياً.',
                'No clear catalog matches — try searching manually.',
              ),
              style: const TextStyle(fontSize: 12, color: StoreTheme.muted),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              context.t('بدائل مقترحة:', 'Suggested alternatives:'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...gap.catalogMatches.map((p) => _altTile(context, p)),
          ],
        ],
      ),
    );
  }

  Widget _altTile(BuildContext context, StoreCatalogProduct p) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (p.storeName.isNotEmpty) p.storeName,
          if (p.price > 0) '${p.price} ${context.t('ج.م', 'EGP')}',
        ].join(' · '),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => openStoreProductDetail(context, p),
    );
  }
}
