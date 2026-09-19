import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/firebase/callable_http_client.dart';
import '../../core/locale/locale_extensions.dart';
import '../analytics/kpi_analytics_service.dart';
import '../auth/user_account_service.dart';

class AdminKpiScreen extends StatefulWidget {
  const AdminKpiScreen({super.key});

  @override
  State<AdminKpiScreen> createState() => _AdminKpiScreenState();
}

class _AdminKpiScreenState extends State<AdminKpiScreen> {
  bool _computing = false;
  String? _selectedWeekId;

  @override
  void initState() {
    super.initState();
    _selectedWeekId = KpiAnalyticsService.instance.weekId();
  }

  Future<void> _compute([String? weekId]) async {
    setState(() => _computing = true);
    try {
      final id = weekId ?? _selectedWeekId ?? KpiAnalyticsService.instance.weekId();
      final preferHttp = UserAccountService.preferHttpCallable;
      final Map<String, dynamic> raw;
      if (preferHttp) {
        raw = await CallableHttpClient.call(
          name: 'adminComputeWeeklyKpis',
          data: {'weekId': id},
          timeout: const Duration(seconds: 120),
          callableProtocol: true,
        );
      } else {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'adminComputeWeeklyKpis',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        );
        final result = await callable.call({'weekId': id});
        raw = Map<String, dynamic>.from(result.data as Map? ?? {});
      }
      if (!mounted) return;
      setState(() => _selectedWeekId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم تحديث مؤشرات $id',
              'Updated KPIs for $id',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Touch raw to avoid unused warning if snack only.
      debugPrint('KPI compute ok: ${raw['ok']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _computing = false);
    }
  }

  Future<void> _setAdSpend(Map<String, dynamic> kpi) async {
    final weekId = kpi['weekId']?.toString() ??
        _selectedWeekId ??
        KpiAnalyticsService.instance.weekId();
    final current = (kpi['adSpend'] as num?)?.toDouble() ?? 0;
    final controller = TextEditingController(
      text: current == 0 ? '' : current.toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('تكلفة الإعلانات للأسبوع', 'Weekly ad spend')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.t('المبلغ (ج.م)', 'Amount (EGP)'),
            hintText: '0',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حفظ', 'Save')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final spend = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (spend == null || spend < 0) return;
    try {
      final preferHttp = UserAccountService.preferHttpCallable;
      if (preferHttp) {
        await CallableHttpClient.call(
          name: 'adminSetWeeklyAdSpend',
          data: {'weekId': weekId, 'adSpend': spend},
          timeout: const Duration(seconds: 120),
          callableProtocol: true,
        );
      } else {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'adminSetWeeklyAdSpend',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        );
        await callable.call({'weekId': weekId, 'adSpend': spend});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم حفظ التكلفة وتحديث CAC', 'Spend saved & CAC updated')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWeek = KpiAnalyticsService.instance.weekId();
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مؤشرات الأداء الأسبوعية', 'Weekly KPIs')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('إعادة الحساب', 'Recompute'),
            onPressed: _computing ? null : () => _compute(),
            icon: _computing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: KpiAnalyticsService.instance.watchRecentWeeks(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          if (snap.connectionState == ConnectionState.waiting && docs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t(
                        'لا توجد مؤشرات بعد. اضغط «إعادة الحساب» لتوليد أسبوع $currentWeek.',
                        'No KPIs yet. Tap refresh to compute week $currentWeek.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _computing ? null : () => _compute(currentWeek),
                      child: Text(context.t('حساب هذا الأسبوع', 'Compute this week')),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final kpi = docs[index].data();
              final weekId = kpi['weekId']?.toString() ?? docs[index].id;
              return _KpiWeekCard(
                weekId: weekId,
                kpi: kpi,
                highlighted: weekId == currentWeek,
                onSetAdSpend: () => _setAdSpend(kpi),
                onRecompute: () => _compute(weekId),
              );
            },
          );
        },
      ),
    );
  }
}

class _KpiWeekCard extends StatelessWidget {
  final String weekId;
  final Map<String, dynamic> kpi;
  final bool highlighted;
  final VoidCallback onSetAdSpend;
  final VoidCallback onRecompute;

  const _KpiWeekCard({
    required this.weekId,
    required this.kpi,
    required this.highlighted,
    required this.onSetAdSpend,
    required this.onRecompute,
  });

  int _i(String key) => (kpi[key] as num?)?.toInt() ?? 0;
  num? _n(String key) => kpi[key] as num?;

  @override
  Widget build(BuildContext context) {
    final retentionD7 = _n('retentionD7Pct');
    final retentionD30 = _n('retentionD30Pct');
    final cac = _n('cac');
    final searchesPerUser = _n('searchesPerActiveUser') ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: highlighted ? const Color(0xFFE8EAF6) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    weekId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRecompute,
                  child: Text(context.t('تحديث', 'Refresh')),
                ),
                TextButton(
                  onPressed: onSetAdSpend,
                  child: Text(context.t('إعلانات', 'Ads')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(
                  context.t('مسجّلون جدد', 'New registered'),
                  '${_i('registeredUsers')}',
                ),
                _metric(
                  context.t('نشطون', 'Active'),
                  '${_i('activeUsers')}',
                ),
                _metric(
                  context.t('أول بحث (باحثون)', 'First search'),
                  '${_i('firstSearchResearchers')}',
                ),
                _metric(
                  context.t('بحث / نشط', 'Searches / active'),
                  '$searchesPerUser',
                ),
                _metric(
                  context.t('مطالبات', 'Claims'),
                  '${_i('profileClaims')}',
                ),
                _metric(
                  context.t('موثّقون', 'Verified'),
                  '${_i('profileVerified')}',
                ),
                _metric(
                  context.t('طلبات تواصل', 'Contact requests'),
                  '${_i('contactRequests')}',
                ),
                _metric(
                  context.t('عودة 7 أيام', 'D7 return'),
                  retentionD7 == null ? '—' : '$retentionD7%',
                ),
                _metric(
                  context.t('عودة 30 يوماً', 'D30 return'),
                  retentionD30 == null ? '—' : '$retentionD30%',
                ),
                _metric(
                  context.t('أخطاء حرجة', 'Critical errors'),
                  '${_i('criticalErrors')}',
                ),
                _metric(
                  context.t('شركاء نشطون', 'Active partners'),
                  '${_i('activePartners')} / ${_i('partnersInDb')}',
                ),
                _metric(
                  context.t('تكلفة استكتاب (CAC)', 'CAC'),
                  cac == null
                      ? context.t('أدخل إنفاق الإعلانات', 'Enter ad spend')
                      : '$cac',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }
}
