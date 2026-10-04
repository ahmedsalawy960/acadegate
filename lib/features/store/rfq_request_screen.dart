import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import 'store_rfq_service.dart';
import 'store_theme.dart';

class RfqRequestScreen extends StatefulWidget {
  final String? productId;
  final String productName;
  final String category;
  final String sellerId;

  const RfqRequestScreen({
    super.key,
    this.productId,
    required this.productName,
    this.category = '',
    this.sellerId = '',
  });

  @override
  State<RfqRequestScreen> createState() => _RfqRequestScreenState();
}

class _RfqRequestScreenState extends State<RfqRequestScreen> {
  final _details = TextEditingController();
  final _qty = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void dispose() {
    _details.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ensureLoggedIn(context);
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await StoreRfqService.instance.submit(
        productId: widget.productId,
        productName: widget.productName,
        category: widget.category,
        sellerId: widget.sellerId,
        details: _details.text,
        quantity: int.tryParse(_qty.text.trim()) ?? 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم إرسال طلب عرض السعر للمورد',
              'Quote request sent to the supplier',
            ),
          ),
          behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(context.t('طلب عرض سعر', 'Request a quote')),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: StoreTheme.appBarForeground,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.productName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'للأصناف غير المتوفرة أو الكميات الكبيرة — يرسل الطلب للمورد للرد بعرض.',
              'For unavailable items or bulk quantities — the supplier receives your request.',
            ),
            style: TextStyle(color: StoreTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.t('الكمية التقريبية', 'Approximate quantity'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            minLines: 5,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: context.t(
                'التفاصيل (نقاء، مواصفات، مدينة التسليم…)',
                'Details (purity, specs, delivery city…)',
              ),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: StoreTheme.accent,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(context.t('إرسال الطلب', 'Send request')),
          ),
        ],
      ),
    ),
    );
  }
}
