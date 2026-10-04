import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'research_proposal_branding.dart';
import 'research_proposal_models.dart';
import 'research_proposal_storage.dart';
import 'research_proposal_workshop.dart';

class ResearchProposalWorkshopScreen extends StatefulWidget {
  const ResearchProposalWorkshopScreen({super.key});

  @override
  State<ResearchProposalWorkshopScreen> createState() =>
      _ResearchProposalWorkshopScreenState();
}

class _ResearchProposalWorkshopScreenState
    extends State<ResearchProposalWorkshopScreen> {
  static const _brand = Color(ResearchProposalBranding.brand);
  ProposalDraft? _draft;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ResearchProposalStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _draft = d;
      _loading = false;
    });
  }

  Future<void> _toggle(String id, bool value) async {
    final d = _draft;
    if (d == null) return;
    setState(() => d.workshopChecks[id] = value);
    await ResearchProposalStorage.instance.save(d);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('ورشة أخطاء الخطط', 'Proposal faults workshop')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final draft = _draft!;
    final done = draft.workshopChecks.values.where((e) => e).length;

    // Group by cluster
    final clusters = <String, List<ProposalWorkshopItem>>{};
    for (final item in proposalWorkshopItems) {
      clusters.putIfAbsent(item.clusterAr, () => []).add(item);
    }

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('ورشة أخطاء الخطط', 'Proposal faults workshop')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t(
                  'علّم على كل بند بعد أن تراجع مسودتك. الهدف: تجنّب الأخطاء الشائعة '
                  'قبل عرض الخطة على القسم. مكتمل: $done / ${proposalWorkshopItems.length}',
                  'Check each item after revising your draft. Goal: avoid common faults '
                  'before the department review. Done: $done / ${proposalWorkshopItems.length}',
                ),
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in clusters.entries) ...[
            Text(
              entry.key,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _brand,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in entry.value)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: Checkbox(
                    value: draft.workshopChecks[item.id] == true,
                    activeColor: _brand,
                    onChanged: (v) => _toggle(item.id, v == true),
                  ),
                  title: Text(
                    context.t(item.titleAr, item.titleEn),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        context.t('الخطأ الشائع', 'Common fault'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(item.faultAr, item.faultEn),
                      style: const TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        context.t('التصحيح', 'Fix'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(item.fixAr, item.fixEn),
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
