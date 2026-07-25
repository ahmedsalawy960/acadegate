import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/academic_content_service.dart';
import '../analysis_labs/request_sample_analysis_screen.dart';
import '../moderation/delete_content_button.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import 'sample_analysis_marketplace_listing.dart';

class SampleAnalysisMarketplaceDetailScreen extends StatelessWidget {
  final SampleAnalysisListing listing;

  const SampleAnalysisMarketplaceDetailScreen({
    super.key,
    required this.listing,
  });

  static const _brand = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    final lab = listing.lab;
    final service = listing.service;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(listing.serviceName),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: deleteAppBarActions(
          collection: 'labs',
          documentId: lab.id,
          ownerId: lab.ownerId,
          itemLabel: lab.name,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => openSampleAnalysisRequestScreen(
              context,
              lab: lab,
              preselectedService: service.id == 'general' ? null : service,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.send_outlined),
            label: Text(
              context.t('طلب تحليل هذه العينة', 'Request this analysis'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _infoRow(Icons.payments_outlined, listing.priceLabel),
                  _infoRow(Icons.schedule, listing.turnaroundLabel),
                  if (listing.rating > 0)
                    _infoRow(
                      Icons.star,
                      context.t(
                        'تقييم ${listing.rating.toStringAsFixed(1)}',
                        'Rating ${listing.rating.toStringAsFixed(1)}',
                      ),
                    ),
                  if (listing.acceptsExternalSamples)
                    _infoRow(
                      Icons.local_shipping_outlined,
                      context.t('يقبل عينات خارجية', 'Accepts external samples'),
                    ),
                ],
              ),
            ),
          ),
          if (service.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.t('عن الخدمة', 'About the service'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(service.description, style: const TextStyle(height: 1.5)),
          ],
          if (service.sampleTypes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.t('أنواع العينات', 'Sample types'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: service.sampleTypes
                  .map(
                    (type) => Chip(
                      label: Text(type),
                      backgroundColor: Colors.teal.shade50,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            context.t('المختبر / المركز', 'Lab / center'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.apartment, color: _brand),
              title: Text(lab.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lab.labTypeLabel),
                  if (listing.locationLabel.isNotEmpty)
                    Text(listing.locationLabel),
                  if (lab.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        lab.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                var target = lab;
                if (lab.isFromFirebase &&
                    (lab.equipmentList.isEmpty ||
                        lab.sampleServices.any((s) => s.id == '_listed'))) {
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  try {
                    final full = await AcademicContentService.instance
                        .fetchLabById(lab.id!);
                    if (full != null) target = full;
                  } finally {
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  }
                }
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SmartLabDetailScreen(lab: target),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.t(
              'بعد إرسال الطلب سيتواصل معك المختبر لترتيب استلام العينة والدفع.',
              'After submitting, the lab will contact you to arrange sample delivery and payment.',
            ),
            style: TextStyle(color: Colors.grey[700], height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _brand),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
