import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/locale_extensions.dart';
import '../store_theme.dart';
import 'research_partnership_detail_screen.dart';
import 'research_partnership_models.dart';
import 'research_partnership_service.dart';

class ResearchPartnershipsListScreen extends StatelessWidget {
  const ResearchPartnershipsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = ResearchPartnershipService.instance;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(context.t('شراكات بحثية', 'Research partnerships')),
          backgroundColor: StoreTheme.ink,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: StoreTheme.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: context.t('مفتوحة', 'Open')),
              Tab(text: context.t('شراكاتي', 'Mine')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PartnershipList(stream: svc.watchOpen()),
            _PartnershipList(stream: svc.watchMine(), emptyMine: true),
          ],
        ),
      ),
    );
  }
}

class _PartnershipList extends StatelessWidget {
  final Stream<List<ResearchPartnership>> stream;
  final bool emptyMine;

  const _PartnershipList({required this.stream, this.emptyMine = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResearchPartnership>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyMine
                    ? context.t(
                        'لا توجد شراكات شاركت فيها بعد.\nاطرح سلة من المتجر كفرصة شراكة.',
                        'No partnerships yet.\nOffer a cart as a partnership from the store.',
                      )
                    : context.t(
                        'لا توجد فرص مفتوحة حالياً',
                        'No open opportunities right now',
                      ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: StoreTheme.muted),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = list[i];
            return Card(
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResearchPartnershipDetailScreen(
                        partnershipId: p.id,
                      ),
                    ),
                  );
                },
                title: Text(p.title, maxLines: 2),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.raisedAmount.toStringAsFixed(0)} / ${p.goalAmount.toStringAsFixed(0)} ${context.t('ج.م', 'EGP')} · ${p.status}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: p.progress,
                          minHeight: 6,
                          backgroundColor: StoreTheme.hairline,
                          color: StoreTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_left),
              ),
            );
          },
        );
      },
    );
  }
}
