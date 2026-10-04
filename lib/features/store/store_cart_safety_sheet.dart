import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale/locale_extensions.dart';
import 'store_cart_safety_models.dart';
import 'store_theme.dart';

Future<void> showCartSafetySheet(
  BuildContext context,
  CartSafetyScanResult result,
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
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, controller) {
          return _CartSafetySheetBody(
            result: result,
            scrollController: controller,
          );
        },
      );
    },
  );
}

class _CartSafetySheetBody extends StatelessWidget {
  final CartSafetyScanResult result;
  final ScrollController scrollController;

  const _CartSafetySheetBody({
    required this.result,
    required this.scrollController,
  });

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
              Icon(Icons.health_and_safety_outlined, color: levelColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('فحص سلامة السلة', 'Cart safety scan'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                      _levelLabel(context, result.overallLevel),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: levelColor,
                      ),
                    ),
                    if (result.overallSummary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.overallSummary,
                        style: const TextStyle(height: 1.4, fontSize: 13.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (result.disclaimer.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  result.disclaimer,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: StoreTheme.muted,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ...result.notes.map((n) => _ProductNoteCard(note: n)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final text = _copyText(context, result);
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t('تم نسخ الملخص', 'Summary copied'),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(context.t('نسخ الملخص', 'Copy summary')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _copyText(BuildContext context, CartSafetyScanResult r) {
    final buf = StringBuffer()
      ..writeln(context.t('فحص سلامة السلة — AcadeGate', 'Cart safety — AcadeGate'))
      ..writeln(_levelLabel(context, r.overallLevel))
      ..writeln(r.overallSummary)
      ..writeln()
      ..writeln(r.disclaimer)
      ..writeln();
    for (final n in r.notes) {
      buf.writeln('• ${n.productName} (${_levelLabel(context, n.level)})');
      if (n.summary.isNotEmpty) buf.writeln('  ${n.summary}');
      for (final h in n.hazards) {
        buf.writeln('  - ${context.t('خطر', 'Hazard')}: $h');
      }
      for (final h in n.handling) {
        buf.writeln('  - ${context.t('تعامل', 'Handling')}: $h');
      }
      for (final s in n.storage) {
        buf.writeln('  - ${context.t('تخزين', 'Storage')}: $s');
      }
      buf.writeln();
    }
    return buf.toString();
  }
}

class _ProductNoteCard extends StatelessWidget {
  final CartProductSafetyNote note;

  const _ProductNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(note.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _levelLabel(context, note.level),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (note.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(note.summary, style: const TextStyle(fontSize: 13, height: 1.35)),
            ],
            if (note.hazards.isNotEmpty) ...[
              const SizedBox(height: 8),
              _bulletBlock(
                context.t('المخاطر', 'Hazards'),
                note.hazards,
                Icons.warning_amber_rounded,
              ),
            ],
            if (note.handling.isNotEmpty) ...[
              const SizedBox(height: 8),
              _bulletBlock(
                context.t('كيفية التعامل', 'Handling'),
                note.handling,
                Icons.back_hand_outlined,
              ),
            ],
            if (note.storage.isNotEmpty) ...[
              const SizedBox(height: 8),
              _bulletBlock(
                context.t('التخزين', 'Storage'),
                note.storage,
                Icons.inventory_2_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bulletBlock(String title, List<String> lines, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: StoreTheme.accent),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...lines.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 3, right: 4, left: 4),
            child: Text('• $l', style: const TextStyle(fontSize: 12.5, height: 1.35)),
          ),
        ),
      ],
    );
  }
}

Color _levelColor(CartSafetyLevel level) {
  switch (level) {
    case CartSafetyLevel.high:
      return const Color(0xFFB3261E);
    case CartSafetyLevel.medium:
      return const Color(0xFFB26A00);
    case CartSafetyLevel.low:
      return const Color(0xFF1B7F4A);
  }
}

String _levelLabel(BuildContext context, CartSafetyLevel level) {
  switch (level) {
    case CartSafetyLevel.high:
      return context.t('خطر مرتفع', 'High');
    case CartSafetyLevel.medium:
      return context.t('احتياط متوسط', 'Medium');
    case CartSafetyLevel.low:
      return context.t('منخفض / عادي', 'Low / normal');
  }
}
