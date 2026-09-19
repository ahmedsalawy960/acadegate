import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../../core/locale/locale_extensions.dart';
import '../store_theme.dart';
import 'knowledge_asset_access_service.dart';
import 'knowledge_asset_models.dart';
import 'knowledge_asset_workspace_screen.dart';

class MyKnowledgeLicensesScreen extends StatelessWidget {
  const MyKnowledgeLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        backgroundColor: StoreTheme.bg,
        appBar: AcadeGateAppBar(
          title: Text(
            context.t('تراخيص الأصول المعرفية', 'Knowledge asset licenses'),
          ),
          backgroundColor: StoreTheme.appBar,
          foregroundColor: StoreTheme.appBarForeground,
        ),
        body: StreamBuilder<List<KnowledgeLicense>>(
          stream: KnowledgeAssetAccessService.instance.watchMyLicenses(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.t(
                      'لا توجد تراخيص بعد. اشترِ أو استأجر أصلاً معرفياً من المتجر.',
                      'No licenses yet. Buy or rent a knowledge asset from the store.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final lic = items[i];
                final active = lic.isActive;
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: StoreTheme.hairline),
                  ),
                  child: ListTile(
                    leading: Icon(
                      active ? Icons.lock_open_outlined : Icons.lock_clock,
                      color: active ? const Color(0xFF2E7D32) : Colors.grey,
                    ),
                    title: Text(
                      lic.productName.isNotEmpty
                          ? lic.productName
                          : lic.productId,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        lic.licenseMode == KnowledgeLicenseMode.rental
                            ? context.t('إيجار', 'Rental')
                            : context.t('بيع', 'Sale'),
                        if (!active) context.t('منتهٍ / غير نشط', 'Expired / inactive'),
                        if (lic.expiresAt != null)
                          context.t(
                            'حتى ${lic.expiresAt!.toLocal().toString().split('.').first}',
                            'Until ${lic.expiresAt!.toLocal()}',
                          ),
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: active
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KnowledgeAssetWorkspaceScreen(
                                  license: lic,
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
