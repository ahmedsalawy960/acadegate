import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../research_marketplace/research_marketplace_screen.dart';
import 'research_fund_models.dart';

/// Publisher view: awards for ideas they published.
class MyFundedIdeasScreen extends StatelessWidget {
  const MyFundedIdeasScreen({super.key});

  static const _brand = Color(0xFFBF360C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('أفكاري الممولة', 'My funded ideas')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<FundAward>>(
        stream: ResearchFundService.instance.watchMyAwards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final awards = snapshot.data ?? [];
          if (awards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.savings_outlined,
                        size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      context.t(
                        'لا تمويلات لأفكارك بعد',
                        'No funding for your ideas yet',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResearchMarketplaceScreen(),
                        ),
                      ),
                      child: Text(context.t(
                        'سوق الأفكار',
                        'Ideas marketplace',
                      )),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: awards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = awards[i];
              final date = a.createdAt;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.volunteer_activism, color: _brand),
                  title: Text(a.ideaTitle),
                  subtitle: Text(
                    [
                      '${a.amount} ${a.currency}',
                      a.partnerUniversity,
                      if (date != null)
                        '${date.year}/${date.month}/${date.day}',
                      context.t(a.status.labelAr, a.status.labelEn),
                    ].join(' · '),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
