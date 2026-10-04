import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/app_translate.dart';
import '../../../core/locale/locale_extensions.dart';
import '../../auth/auth_guard.dart';
import '../store_theme.dart';
import 'research_partnership_chat_screen.dart';
import 'research_partnership_models.dart';
import 'research_partnership_service.dart';

class ResearchPartnershipDetailScreen extends StatefulWidget {
  final String partnershipId;

  const ResearchPartnershipDetailScreen({
    super.key,
    required this.partnershipId,
  });

  @override
  State<ResearchPartnershipDetailScreen> createState() =>
      _ResearchPartnershipDetailScreenState();
}

class _ResearchPartnershipDetailScreenState
    extends State<ResearchPartnershipDetailScreen> {
  final _sharesCtrl = TextEditingController(text: '1');
  bool _busy = false;

  @override
  void dispose() {
    _sharesCtrl.dispose();
    super.dispose();
  }

  Future<void> _join(ResearchPartnership p) async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;
    final shares = int.tryParse(_sharesCtrl.text.trim()) ?? 0;
    setState(() => _busy = true);
    try {
      await ResearchPartnershipService.instance.joinWithShares(
        partnershipId: p.id,
        shares: shares,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم تسجيل مساهمتك — حوّل للمضيف وانتظر التأكيد',
              'Contribution registered — transfer to host and wait for confirmation',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String contributorId) async {
    setState(() => _busy = true);
    try {
      await ResearchPartnershipService.instance.confirmContribution(
        partnershipId: widget.partnershipId,
        contributorId: contributorId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم تأكيد المساهمة', 'Contribution confirmed')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _placeOrders() async {
    setState(() => _busy = true);
    try {
      final ids = await ResearchPartnershipService.instance
          .placeStoreOrders(widget.partnershipId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم إنشاء ${ids.length} طلب/طلبات متجر',
              'Created ${ids.length} store order(s)',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyInvite() async {
    final text = 'acadegate://research_partnership/${widget.partnershipId}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'تم نسخ رابط الدعوة (معرّف الفرصة)',
            'Invite link copied (opportunity id)',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final svc = ResearchPartnershipService.instance;

    return Scaffold(
      backgroundColor: StoreTheme.bg,
      appBar: AcadeGateAppBar(
        title: Text(context.t('تفاصيل الشراكة', 'Partnership details')),
        backgroundColor: StoreTheme.appBar,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('نسخ الدعوة', 'Copy invite'),
            onPressed: _copyInvite,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: StreamBuilder<ResearchPartnership?>(
        stream: svc.watchById(widget.partnershipId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) {
            return Center(
              child: Text(context.t('غير موجود', 'Not found')),
            );
          }
          final isHost = p.hostId == uid;
          final isParticipant = p.participantIds.contains(uid);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(p.title, style: StoreTheme.sectionTitle),
              const SizedBox(height: 6),
              Text(
                context.t('المضيف: ${p.hostName}', 'Host: ${p.hostName}'),
                style: const TextStyle(color: StoreTheme.muted),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: p.progress,
                  minHeight: 10,
                  backgroundColor: StoreTheme.hairline,
                  color: StoreTheme.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${p.raisedAmount.toStringAsFixed(0)} / ${p.goalAmount.toStringAsFixed(0)} ${appTr('ج.م', 'EGP')}'
                ' · ${context.t('الحصة', 'Share')}: ${p.sharePrice} · ${p.status}',
              ),
              if (p.deadline != null) ...[
                const SizedBox(height: 4),
                Text(
                  context.t(
                    'المهلة: ${p.deadline!.toLocal().toString().split('.').first}',
                    'Deadline: ${p.deadline!.toLocal().toString().split('.').first}',
                  ),
                  style: const TextStyle(fontSize: 12.5, color: StoreTheme.muted),
                ),
              ],
              const SizedBox(height: 14),
              _section(
                context.t('أصناف السلة', 'Cart items'),
                children: p.items
                    .map(
                      (e) => Text(
                        '• ${e.name} × ${e.quantity} — ${e.lineTotal} ${appTr('ج.م', 'EGP')}',
                      ),
                    )
                    .toList(),
              ),
              _section(
                context.t('حقوق المساهمين', 'Contributor rights'),
                children: [Text(p.rightsText)],
              ),
              _section(
                context.t('بيانات التحويل للمستضيف', 'Host payment details'),
                children: [Text(p.hostReceiverNote)],
              ),
              if (p.storeOrderIds.isNotEmpty)
                _section(
                  context.t('طلبات المتجر', 'Store orders'),
                  children: [
                    Text(
                      p.storeOrderIds.join('\n'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (isParticipant || isHost)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResearchPartnershipChatScreen(
                          partnershipId: p.id,
                          title: p.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: Text(
                    context.t('غرفة المعرفة المشتركة', 'Shared knowledge room'),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                context.t('المساهمات', 'Contributions'),
                style: StoreTheme.sectionTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<ResearchPartnershipContribution>>(
                stream: svc.watchContributions(p.id),
                builder: (context, cSnap) {
                  final list = cSnap.data ?? const [];
                  if (list.isEmpty) {
                    return Text(
                      context.t('لا مساهمات بعد', 'No contributions yet'),
                      style: const TextStyle(color: StoreTheme.muted),
                    );
                  }
                  return Column(
                    children: list.map((c) {
                      return Card(
                        child: ListTile(
                          title: Text('${c.userName} · ${c.shares} ${context.t('حصة', 'shares')}'),
                          subtitle: Text(
                            '${c.amount} ${appTr('ج.م', 'EGP')} · ${c.paymentStatus}',
                          ),
                          trailing: isHost && c.isPending && c.userId != uid
                              ? TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _confirm(c.userId),
                                  child: Text(context.t('تأكيد', 'Confirm')),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (p.isOpen && !isHost) ...[
                TextField(
                  controller: _sharesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.t(
                      'عدد الحصص (الحد الأدنى ${p.minShares})',
                      'Shares (min ${p.minShares})',
                    ),
                    border: const OutlineInputBorder(),
                    helperText: context.t(
                      'المتبقي تقريباً: ${p.remainingShares} حصة',
                      'About ${p.remainingShares} shares remaining',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _join(p),
                  style: FilledButton.styleFrom(
                    backgroundColor: StoreTheme.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.handshake_outlined),
                  label: Text(
                    context.t('انضم وساهم', 'Join & contribute'),
                  ),
                ),
              ],
              if (isHost && (p.status == 'funded' ||
                  (p.raisedAmount >= p.goalAmount && !p.isOrdered))) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy ? null : _placeOrders,
                  style: FilledButton.styleFrom(
                    backgroundColor: StoreTheme.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                    context.t(
                      'إنشاء طلبات المتجر الآن',
                      'Place store orders now',
                    ),
                  ),
                ),
              ],
              if (isHost && p.isOpen) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            await svc.cancelOpen(p.id);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        },
                  child: Text(
                    context.t('إلغاء الفرصة', 'Cancel opportunity'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, {required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: StoreTheme.sectionTitle.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
