import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../academic/academic_models.dart';
import 'scholar_link_utils.dart';
import 'supervisor_metrics_models.dart';
import 'supervisor_metrics_service.dart';

/// شريحة مختصرة للبطاقة — عدد المنشورات والاستشهادات.
class SupervisorMetricsChipRow extends StatelessWidget {
  final AcademicSupervisor supervisor;

  const SupervisorMetricsChipRow({super.key, required this.supervisor});

  @override
  Widget build(BuildContext context) {
    if (supervisor.hasStoredMetrics) {
      return _chips(
        works: supervisor.worksCount,
        citations: supervisor.citedByCount,
      );
    }

    if (!supervisor.hasPublicationIds) {
      return Text(
        'لا بيانات نشر',
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      );
    }

    return FutureBuilder<SupervisorPublicationMetrics>(
      future: SupervisorMetricsService.instance.loadMetrics(supervisor),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[400],
            ),
          );
        }

        final metrics = snapshot.data;
        if (metrics == null || !metrics.hasData) {
          return Text(
            'لا بيانات نشر',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          );
        }

        return _chips(
          works: metrics.worksCount,
          citations: metrics.citedByCount,
          highImpact: metrics.highImpactVenueCount,
        );
      },
    );
  }

  Widget _chips({
    required int works,
    required int citations,
    int highImpact = 0,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _miniChip(Icons.article_outlined, '$works منشور'),
        _miniChip(Icons.format_quote, '$citations استشهاد'),
        if (highImpact > 0)
          _miniChip(Icons.star, '$highImpact مجلة Q1–Q2'),
      ],
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.blue[800]),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.blue[900]),
          ),
        ],
      ),
    );
  }
}

/// لوحة تفصيلية في ملف المشرف.
class SupervisorPublicationPanel extends StatefulWidget {
  final AcademicSupervisor supervisor;

  const SupervisorPublicationPanel({super.key, required this.supervisor});

  @override
  State<SupervisorPublicationPanel> createState() =>
      _SupervisorPublicationPanelState();
}

class _SupervisorPublicationPanelState
    extends State<SupervisorPublicationPanel> {
  late Future<SupervisorPublicationMetrics> _future;

  @override
  void initState() {
    super.initState();
    _future = SupervisorMetricsService.instance.loadMetrics(widget.supervisor);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<SupervisorPublicationMetrics>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final metrics = snapshot.data;
            if (metrics == null || !metrics.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الإنتاج العلمي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metrics?.sourceNote.isNotEmpty == true
                        ? metrics!.sourceNote
                        : 'لا تتوفر بيانات نشر لهذا المشرف.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الإنتاج العلمي والمجلات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statBox('منشورات', '${metrics.worksCount}'),
                    const SizedBox(width: 10),
                    _statBox('استشهادات', '${metrics.citedByCount}'),
                    const SizedBox(width: 10),
                    _statBox('H-index', '${metrics.hIndex}'),
                  ],
                ),
                if (supervisorHasScholarLink(widget.supervisor)) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openScholar(widget.supervisor),
                    icon: const Icon(Icons.school_outlined, size: 18),
                    label: const Text('عرض على Google Scholar'),
                  ),
                ],
                if (metrics.topVenues.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'أبرز المجلات التي نُشر فيها',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...metrics.topVenues.map(_venueTile),
                ],
                if (metrics.sourceNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    metrics.sourceNote,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A237E).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1A237E),
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Future<void> _openScholar(AcademicSupervisor supervisor) async {
    final uri = Uri.parse(resolveScholarUrl(supervisor));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح رابط Google Scholar')),
      );
    }
  }

  Widget _venueTile(VenuePublicationStat venue) {
    final color = _quartileColor(venue);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          venue.displayTier,
          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        venue.journalName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _venueSubtitle(venue),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Color _quartileColor(VenuePublicationStat venue) {
    if (venue.fromScimago && venue.quartile != null) {
      return switch (venue.quartile) {
        'Q1' => Colors.green[700]!,
        'Q2' => Colors.lightGreen[700]!,
        'Q3' => Colors.orange[700]!,
        'Q4' => Colors.grey[600]!,
        _ => Colors.grey,
      };
    }
    if (venue.citedness >= 2) return Colors.green;
    if (venue.citedness >= 1) return Colors.orange;
    return Colors.grey;
  }

  String _venueSubtitle(VenuePublicationStat venue) {
    final parts = <String>['${venue.worksCount} بحث'];
    if (venue.fromScimago && venue.quartile != null) {
      parts.add('Scimago ${venue.quartile}');
      if (venue.sjr != null) {
        parts.add('SJR ${venue.sjr!.toStringAsFixed(2)}');
      }
    } else {
      parts.add(venue.tierLabel);
    }
    return parts.join(' • ');
  }
}
