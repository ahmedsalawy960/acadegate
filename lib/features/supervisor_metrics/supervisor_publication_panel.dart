import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/l10n_lookup.dart';
import '../academic/academic_models.dart';
import 'scholar_link_utils.dart';
import 'supervisor_identity.dart';
import 'supervisor_metrics_models.dart';
import 'supervisor_metrics_service.dart';

/// شريحة مختصرة للبطاقة — عدد المنشورات والاستشهادات.
class SupervisorMetricsChipRow extends StatelessWidget {
  final AcademicSupervisor supervisor;

  const SupervisorMetricsChipRow({super.key, required this.supervisor});

  @override
  Widget build(BuildContext context) {
    if (!supervisor.hasPublicationIds) {
      if (supervisor.hasStoredMetrics) {
        return _chips(
          works: supervisor.worksCount,
          citations: supervisor.citedByCount,
        );
      }
      return Text(
        L10nLookup.noPublicationData,
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      );
    }

    return FutureBuilder<SupervisorPublicationMetrics>(
      future: SupervisorMetricsService.instance.loadMetrics(supervisor),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (supervisor.hasStoredMetrics) {
            return _chips(
              works: supervisor.worksCount,
              citations: supervisor.citedByCount,
            );
          }
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
          if (supervisor.hasStoredMetrics) {
            return _chips(
              works: supervisor.worksCount,
              citations: supervisor.citedByCount,
            );
          }
          return Text(
            L10nLookup.noPublicationData,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          );
        }

        return _chips(
          works: metrics.worksCount,
          citations: metrics.citedByCount,
          highImpact: metrics.highImpactVenueCount,
          topics: metrics.identityTopics.take(3).toList(),
        );
      },
    );
  }

  Widget _chips({
    required int works,
    required int citations,
    int highImpact = 0,
    List<ResearchIdentityTopic> topics = const [],
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _miniChip(Icons.article_outlined, L10nLookup.publicationsCount(works)),
        _miniChip(Icons.format_quote, L10nLookup.citationsCount(citations)),
        if (highImpact > 0)
          _miniChip(Icons.star, L10nLookup.q1q2JournalsCount(highImpact)),
        ...topics.map(
          (t) => _miniChip(Icons.biotech_outlined, t.label),
        ),
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
  bool _showAllWorks = false;

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
                  Text(
                    L10nLookup.scientificOutput,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metrics?.sourceNote.isNotEmpty == true
                        ? metrics!.sourceNote
                        : L10nLookup.noSupervisorPublicationData,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10nLookup.scientificOutputAndJournals,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statBox(L10nLookup.publications, '${metrics.worksCount}'),
                    const SizedBox(width: 10),
                    _statBox(L10nLookup.citations, '${metrics.citedByCount}'),
                    const SizedBox(width: 10),
                    _statBox('H-index', '${metrics.hIndex}'),
                  ],
                ),
                if (supervisorHasScholarLink(widget.supervisor)) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openScholar(widget.supervisor),
                    icon: const Icon(Icons.school_outlined, size: 18),
                    label: Text(L10nLookup.viewOnGoogleScholar),
                  ),
                ],
                if (metrics.identityTopics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    L10nLookup.researchIdentity,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    L10nLookup.researchIdentityHint,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  ...metrics.identityTopics.map(_topicBar),
                ],
                if (metrics.works.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    L10nLookup.supervisorWorks,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ...(_visibleWorks(metrics.works).map(_workTile)),
                  if (metrics.works.length > 8)
                    TextButton(
                      onPressed: () =>
                          setState(() => _showAllWorks = !_showAllWorks),
                      child: Text(
                        _showAllWorks
                            ? L10nLookup.showFewerWorks
                            : L10nLookup.showMoreWorks,
                      ),
                    ),
                ],
                if (metrics.collaborators.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    L10nLookup.topCollaborators,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ...metrics.collaborators.map(_collaboratorTile),
                ],
                if (metrics.affiliations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    L10nLookup.partnerInstitutions,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: metrics.affiliations
                        .map(
                          (a) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              a.countryCode.isEmpty
                                  ? a.name
                                  : '${a.name} (${a.countryCode})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (metrics.topVenues.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    L10nLookup.topJournals,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
        SnackBar(content: Text(L10nLookup.scholarLinkFailed())),
      );
    }
  }

  List<ResearchWork> _visibleWorks(List<ResearchWork> works) {
    if (_showAllWorks || works.length <= 8) return works;
    return works.take(8).toList();
  }

  Future<void> _openWork(ResearchWork work) async {
    if (!work.canOpen) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10nLookup.paperUnavailable)),
      );
      return;
    }
    final uri = Uri.tryParse(work.openUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10nLookup.paperOpenFailed)),
      );
    }
  }

  Widget _workTile(ResearchWork work) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        work.hasPdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined,
        color: work.canOpen ? const Color(0xFF1A237E) : Colors.grey,
      ),
      title: Text(work.title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        [
          if (work.year > 0) '${work.year}',
          if (work.venue.isNotEmpty) work.venue,
          if (work.citedByCount > 0)
            L10nLookup.citationsCount(work.citedByCount),
        ].join(' • '),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: work.canOpen
          ? IconButton(
              tooltip: work.hasPdf ? L10nLookup.openPdf : L10nLookup.openPaper,
              onPressed: () => _openWork(work),
              icon: Icon(
                work.hasPdf ? Icons.picture_as_pdf_outlined : Icons.open_in_new,
                size: 20,
              ),
            )
          : Tooltip(
              message: L10nLookup.paperUnavailable,
              child: Icon(Icons.link_off, size: 18, color: Colors.grey[400]),
            ),
      onTap: work.canOpen ? () => _openWork(work) : null,
    );
  }

  Widget _topicBar(ResearchIdentityTopic topic) {
    final value = topic.percent / 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topic.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${topic.percent}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.08),
              color: const Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collaboratorTile(ResearchCollaborator person) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.people_outline, size: 20, color: Color(0xFF1A237E)),
      title: Text(person.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        [
          if (person.institution.isNotEmpty) person.institution,
          L10nLookup.jointWorksCount(person.jointWorks),
        ].join(' • '),
        style: const TextStyle(fontSize: 12),
      ),
    );
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
    final parts = <String>[L10nLookup.researchCount(venue.worksCount)];
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
