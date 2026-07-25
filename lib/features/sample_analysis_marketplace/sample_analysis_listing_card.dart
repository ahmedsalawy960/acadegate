import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../moderation/delete_content_button.dart';
import 'sample_analysis_marketplace_listing.dart';

/// Compact marketplace row for one lab analysis service.
class SampleAnalysisListingCard extends StatelessWidget {
  final SampleAnalysisListing listing;
  final VoidCallback onTap;

  const SampleAnalysisListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  static const _brand = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    final lab = listing.lab;
    final specialties = listing.specialties.take(3).toList();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.biotech, color: _brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.serviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          listing.labName,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                        if (listing.locationLabel.isNotEmpty)
                          Text(
                            listing.locationLabel,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DeleteContentButton(
                    collection: 'labs',
                    documentId: lab.id,
                    ownerId: lab.ownerId,
                    itemLabel: lab.name,
                    asAppBarAction: false,
                    iconColor: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _metaChip(Icons.payments_outlined, listing.priceLabel),
                  _metaChip(Icons.schedule, listing.turnaroundLabel),
                  if (listing.rating > 0)
                    _metaChip(
                      Icons.star,
                      listing.rating.toStringAsFixed(1),
                    ),
                  if (listing.acceptsExternalSamples)
                    _metaChip(
                      Icons.local_shipping_outlined,
                      context.t('عينات خارجية', 'External samples'),
                    ),
                ],
              ),
              if (specialties.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: specialties
                      .map(
                        (s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: Colors.teal.shade50,
                          padding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _brand),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
