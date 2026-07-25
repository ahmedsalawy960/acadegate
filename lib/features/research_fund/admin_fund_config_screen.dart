import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import '../academic/academic_models.dart';
import 'research_fund_models.dart';

class AdminFundConfigScreen extends StatefulWidget {
  const AdminFundConfigScreen({super.key});

  @override
  State<AdminFundConfigScreen> createState() => _AdminFundConfigScreenState();
}

class _AdminFundConfigScreenState extends State<AdminFundConfigScreen> {
  static const _brand = Color(0xFFBF360C);

  final _minVotesCtrl = TextEditingController();
  final _maxAwardCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _partnerNameCtrl = TextEditingController();
  final _partnerEmailCtrl = TextEditingController();

  bool _isActive = false;
  bool _loading = true;
  bool _saving = false;
  List<FundPartner> _partners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minVotesCtrl.dispose();
    _maxAwardCtrl.dispose();
    _currencyCtrl.dispose();
    _descriptionCtrl.dispose();
    _partnerNameCtrl.dispose();
    _partnerEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await ResearchFundService.instance.watchConfig().first;
    if (!mounted) return;
    setState(() {
      _isActive = config.isActive;
      _minVotesCtrl.text =
          config.minVotes > 0 ? '${config.minVotes}' : '';
      _maxAwardCtrl.text =
          config.maxAwardAmount > 0 ? '${config.maxAwardAmount}' : '';
      _currencyCtrl.text = config.currency;
      _descriptionCtrl.text = config.description;
      _partners = List.of(config.partners);
      _loading = false;
    });
  }

  void _addPartner() {
    final name = _partnerNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _partners.add(
        FundPartner(
          name: name,
          contactEmail: _partnerEmailCtrl.text.trim(),
        ),
      );
      _partnerNameCtrl.clear();
      _partnerEmailCtrl.clear();
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      await ResearchFundService.instance.saveConfig(
        ResearchFundConfig(
          isActive: _isActive,
          minVotes: int.tryParse(_minVotesCtrl.text.trim()) ?? 0,
          maxAwardAmount: double.tryParse(_maxAwardCtrl.text.trim()) ?? 0,
          currency: _currencyCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          partners: _partners,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('تم الحفظ', 'Saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _awardIdea(Map<String, dynamic> raw) async {
    final config = ResearchFundConfig(
      isActive: _isActive,
      minVotes: int.tryParse(_minVotesCtrl.text.trim()) ?? 0,
      maxAwardAmount: double.tryParse(_maxAwardCtrl.text.trim()) ?? 0,
      currency: _currencyCtrl.text.trim(),
      partners: _partners,
    );
    if (!config.isConfigured || _partners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'أكمل إعداد الصندوق وشركاء الجامعات أولاً',
            'Complete fund setup and partners first',
          )),
        ),
      );
      return;
    }

    final partner = await showDialog<FundPartner>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.t('اختر الشريك', 'Choose partner')),
        children: _partners
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(p.name),
              ),
            )
            .toList(),
      ),
    );
    if (partner == null || !mounted) return;

    final idea = AcademicResearchIdea.fromMap(raw, id: raw['id']?.toString());
    final amountCtrl = TextEditingController(
      text: config.maxAwardAmount > 0 ? '${config.maxAwardAmount}' : '',
    );

    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('تمويل فكرة', 'Fund idea')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                '«${idea.title}» عبر ${partner.name}',
                '"${idea.title}" via ${partner.name}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.t(
                  'المبلغ (حد أقصى ${config.maxAwardAmount} ${config.currency})',
                  'Amount (max ${config.maxAwardAmount} ${config.currency})',
                ),
                border: const OutlineInputBorder(),
                suffixText: config.currency,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(amountCtrl.text.trim());
              if (parsed == null || parsed <= 0) return;
              if (parsed > config.maxAwardAmount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t(
                      'المبلغ يتجاوز الحد الأقصى',
                      'Amount exceeds maximum',
                    )),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, parsed);
            },
            child: Text(context.t('تأكيد', 'Confirm')),
          ),
        ],
      ),
    );
    amountCtrl.dispose();
    if (amount == null || !mounted) return;

    try {
      await ResearchFundService.instance.createAward(
        ideaId: idea.id!,
        ideaTitle: idea.title,
        votesAtAward: idea.votesCount,
        amount: amount,
        currency: config.currency,
        partnerUniversity: partner.name,
        publisherId: idea.publisherId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('تم التمويل', 'Funded'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _setAwardStatus(FundAward award, FundAwardStatus status) async {
    if (award.id == null) return;
    try {
      await ResearchFundService.instance.updateAwardStatus(
        awardId: award.id!,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'تم تحديث الحالة',
              'Status updated',
            )),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, accountSnap) {
        if (accountSnap.data?.isAdmin != true) {
          return Scaffold(
            appBar: AcadeGateAppBar(
              title: Text(context.t('إعدادات الصندوق', 'Fund settings')),
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Text(context.t('مدير النظام فقط', 'Admin only')),
            ),
          );
        }

        if (_loading) {
          return Scaffold(
            appBar: AcadeGateAppBar(
              title: Text(context.t('إعدادات الصندوق', 'Fund settings')),
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final minVotes = int.tryParse(_minVotesCtrl.text.trim()) ?? 0;

        return Scaffold(
          appBar: AcadeGateAppBar(
            title: Text(context.t('إعدادات الصندوق', 'Fund settings')),
            backgroundColor: _brand,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: Text(context.t('تفعيل الصندوق', 'Enable fund')),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              TextField(
                controller: _minVotesCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.t('حد التصويت الأدنى', 'Minimum votes'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _maxAwardCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.t('حد التمويل', 'Max award'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _currencyCtrl,
                      decoration: InputDecoration(
                        labelText: context.t('العملة', 'Currency'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.t('وصف الصندوق', 'Fund description'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.t('شركاء الجامعات', 'University partners'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._partners.asMap().entries.map((e) {
                return ListTile(
                  title: Text(e.value.name),
                  subtitle: e.value.contactEmail.isNotEmpty
                      ? Text(e.value.contactEmail)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () =>
                        setState(() => _partners.removeAt(e.key)),
                  ),
                );
              }),
              TextField(
                controller: _partnerNameCtrl,
                decoration: InputDecoration(
                  labelText: context.t('اسم الجامعة', 'University name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _partnerEmailCtrl,
                decoration: InputDecoration(
                  labelText: context.t('بريد التواصل', 'Contact email'),
                  border: const OutlineInputBorder(),
                ),
              ),
              TextButton.icon(
                onPressed: _addPartner,
                icon: const Icon(Icons.add),
                label: Text(context.t('إضافة شريك', 'Add partner')),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _saveConfig,
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Text(context.t('حفظ الإعدادات', 'Save settings')),
              ),
              if (_isActive && minVotes > 0) ...[
                const SizedBox(height: 24),
                Text(
                  context.t('تمويل فكرة مؤهلة', 'Fund eligible idea'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: ResearchFundService.instance
                      .watchEligibleIdeas(minVotes),
                  builder: (context, snap) {
                    final ideas = snap.data ?? [];
                    if (ideas.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          context.t('لا أفكار مؤهلة', 'No eligible ideas'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }
                    return Column(
                      children: ideas.map((raw) {
                        final idea = AcademicResearchIdea.fromMap(
                          raw,
                          id: raw['id']?.toString(),
                        );
                        return ListTile(
                          title: Text(idea.title),
                          subtitle: Text('${idea.votesCount} votes'),
                          trailing: FilledButton(
                            onPressed: () => _awardIdea(raw),
                            child: Text(context.t('تمويل', 'Fund')),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              Text(
                context.t('إدارة التمويلات', 'Manage awards'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<FundAward>>(
                stream: ResearchFundService.instance.watchAwards(),
                builder: (context, snap) {
                  final awards = snap.data ?? [];
                  if (awards.isEmpty) {
                    return Text(
                      context.t('لا تمويلات بعد', 'No awards yet'),
                      style: TextStyle(color: Colors.grey[600]),
                    );
                  }
                  return Column(
                    children: awards.map((a) {
                      return Card(
                        child: ListTile(
                          title: Text(a.ideaTitle),
                          subtitle: Text(
                            [
                              '${a.amount} ${a.currency}',
                              a.partnerUniversity,
                              context.t(a.status.labelAr, a.status.labelEn),
                            ].join(' · '),
                          ),
                          trailing: PopupMenuButton<FundAwardStatus>(
                            tooltip: context.t('تغيير الحالة', 'Change status'),
                            onSelected: (s) => _setAwardStatus(a, s),
                            itemBuilder: (ctx) => FundAwardStatus.values
                                .map(
                                  (s) => PopupMenuItem(
                                    value: s,
                                    child: Text(
                                      context.t(s.labelAr, s.labelEn),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
