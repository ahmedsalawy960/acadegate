import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'import_models.dart';
import 'openalex_author_quality.dart';
import 'openalex_faculty_mapper.dart';
import 'openalex_search_aliases.dart';

class OpenAlexAuthorPreviewCard extends StatelessWidget {
  final OpenAlexAuthor author;
  final String institutionLabel;
  final bool selected;
  final ValueChanged<bool?> onSelected;

  const OpenAlexAuthorPreviewCard({
    super.key,
    required this.author,
    required this.institutionLabel,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final inferred = OpenAlexFacultyMapper.resolve(author);
    final quality = OpenAlexAuthorQuality.evaluate(author);
    final qualityColor = quality.score >= 70
        ? Colors.green
        : quality.score >= 45
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: selected, onChanged: onSelected),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        OpenAlexSearchAliases.formatUniversityWithFaculty(
                          faculty: inferred.facultyTitle,
                          institution: institutionLabel,
                        ),
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: qualityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: qualityColor),
                  ),
                  child: Text(
                    '${quality.score}%',
                    style: TextStyle(
                      color: qualityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(Icons.menu_book_outlined, '${author.worksCount}'),
                _chip(Icons.format_quote, '${author.citedByCount}'),
                _chip(Icons.trending_up, 'h${author.hIndex}'),
                if (author.i10Index > 0)
                  _chip(Icons.insights_outlined, 'i10 ${author.i10Index}'),
                if (author.orcid != null)
                  _chip(Icons.verified_outlined, 'ORCID'),
                if (author.lastPublicationYear != null)
                  _chip(
                    Icons.calendar_today_outlined,
                    '${author.lastPublicationYear}',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.t('التخصص: ', 'Field: ') + author.speciality,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (author.tags.length > 1) ...[
              const SizedBox(height: 6),
              Text(
                context.t('مجالات ذات صلة: ', 'Related fields: ') +
                    author.tags.skip(1).take(5).join(' • '),
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
            if (author.institutionNames.length > 1) ...[
              const SizedBox(height: 6),
              Text(
                context.t('جهات أخرى: ', 'Other affiliations: ') +
                    author.institutionNames.skip(1).take(2).join(' • '),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              quality.tierLabel,
              style: TextStyle(color: qualityColor, fontWeight: FontWeight.w600),
            ),
            if (quality.warnings.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quality.warnings.join(' • '),
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ],
            if (quality.strengths.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quality.strengths.join(' • '),
                style: TextStyle(color: Colors.green[700], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

String openAlexInstitutionLabel(
  OpenAlexAuthor author,
  String? selectedInstitutionName,
) {
  if (author.institutionName.isNotEmpty) return author.institutionName;
  return selectedInstitutionName ?? '—';
}
