import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/app_translate.dart';
import '../../../core/locale/locale_extensions.dart';
import '../../auth/auth_guard.dart';
import '../store_cart_service.dart';
import '../store_theme.dart';
import 'research_partnership_detail_screen.dart';
import 'research_partnership_service.dart';

class CreateResearchPartnershipScreen extends StatefulWidget {
  final List<StoreCartItem> items;

  const CreateResearchPartnershipScreen({super.key, required this.items});

  @override
  State<CreateResearchPartnershipScreen> createState() =>
      _CreateResearchPartnershipScreenState();
}

class _CreateResearchPartnershipScreenState
    extends State<CreateResearchPartnershipScreen> {
  final _titleCtrl = TextEditingController();
  final _rightsCtrl = TextEditingController(
    text:
        'المساهمون يحصلون على: (1) حق استخدام نسبي للجهاز/المواد حسب الحصص، '
        '(2) مشاركة النتائج عبر غرفة المعرفة الخاصة بالفرصة، '
        '(3) ذكر المساهمة في أي نشر باتفاق مسبق. '
        'المضيف هو المستلم المادي والمسؤول عن التشغيل الآمن.',
  );
  final _receiverCtrl = TextEditingController();
  final _sharePriceCtrl = TextEditingController();
  final _minSharesCtrl = TextEditingController(text: '1');
  final _deadlineCtrl = TextEditingController(text: '14');
  final _hostSharesCtrl = TextEditingController(text: '0');
  bool _saving = false;

  num get _goal => widget.items.fold<num>(0, (s, e) => s + e.lineTotal);

  @override
  void initState() {
    super.initState();
    final goal = _goal;
    final suggested = goal >= 4 ? (goal / 4).round() : goal;
    _sharePriceCtrl.text = suggested.toString();
    _titleCtrl.text = context.mounted
        ? ''
        : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_titleCtrl.text.isEmpty && widget.items.isNotEmpty) {
        final first = widget.items.first.name;
        _titleCtrl.text = appTr(
          'شراكة بحثية: $first',
          'Research partnership: $first',
        );
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _rightsCtrl.dispose();
    _receiverCtrl.dispose();
    _sharePriceCtrl.dispose();
    _minSharesCtrl.dispose();
    _deadlineCtrl.dispose();
    _hostSharesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    final sharePrice = num.tryParse(_sharePriceCtrl.text.trim()) ?? 0;
    final minShares = int.tryParse(_minSharesCtrl.text.trim()) ?? 1;
    final days = int.tryParse(_deadlineCtrl.text.trim()) ?? 14;
    final hostShares = int.tryParse(_hostSharesCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      final id = await ResearchPartnershipService.instance.createFromCart(
        items: widget.items,
        title: _titleCtrl.text,
        rightsText: _rightsCtrl.text,
        hostReceiverNote: _receiverCtrl.text,
        sharePrice: sharePrice,
        minShares: minShares,
        deadlineDays: days,
        hostShares: hostShares,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم إنشاء فرصة الشراكة', 'Partnership opportunity created'),
          ),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResearchPartnershipDetailScreen(partnershipId: id),
        ),
      );
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
    return Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('شراكة بحثية من السلة', 'Research partnership from cart'),
        ),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('قيمة السلة (هدف التمويل)', 'Cart total (funding goal)'),
                    style: StoreTheme.sectionTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_goal.toStringAsFixed(0)} ${appTr('ج.م', 'EGP')}',
                    style: StoreTheme.priceStyle.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 10),
                  ...widget.items.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${e.name} × ${e.quantity} — ${e.lineTotal} ${appTr('ج.م', 'EGP')}',
                        style: const TextStyle(fontSize: 13, color: StoreTheme.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: context.t('عنوان الفرصة', 'Opportunity title'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sharePriceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.t('سعر الحصة الواحدة (ج.م)', 'Share price (EGP)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minSharesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.t('حد أدنى للحصص', 'Min shares'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _deadlineCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.t('المهلة (أيام)', 'Deadline (days)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostSharesCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.t(
                'حصصك كمساهم أولي (اختياري)',
                'Your seed shares (optional)',
              ),
              border: const OutlineInputBorder(),
              helperText: context.t(
                'تُحتسب مباشرة ضمن التمويل عند الإنشاء',
                'Counted toward funding immediately at creation',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receiverCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.t(
                'بيانات التحويل للمستضيف',
                'Host payment instructions',
              ),
              hintText: context.t(
                'مثال: فودافون كاش / إنستاباي / حساب بنكي',
                'e.g. Vodafone Cash / InstaPay / bank account',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rightsCtrl,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: context.t(
                'حقوق المساهمين (استخدام / نتائج / نشر)',
                'Contributor rights (use / results / publication)',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t(
              'عند اكتمال التمويل يُنشئ المضيف طلبات شراء عادية عبر الضمان لكل صنف.',
              'When funded, the host places normal escrow store orders for each item.',
            ),
            style: const TextStyle(fontSize: 12.5, color: StoreTheme.muted),
          ),
          const SizedBox(height: 16),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.handshake_outlined),
            label: Text(
              context.t('نشر فرصة الشراكة', 'Publish partnership opportunity'),
            ),
          ),
        ],
      ),
    );
  }
}
