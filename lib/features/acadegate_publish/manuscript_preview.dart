import 'package:flutter/material.dart';

import 'manuscript_citation_helper.dart';
import 'manuscript_document_parser.dart';
import 'manuscript_import_image.dart';
import 'publish_models.dart';

class ManuscriptBlockPreview extends StatelessWidget {
  final ManuscriptBlock block;
  final PublishManuscript manuscript;

  const ManuscriptBlockPreview({
    super.key,
    required this.block,
    required this.manuscript,
  });

  @override
  Widget build(BuildContext context) {
    final style = manuscript.effectiveStyle;

    return switch (block.type) {
      ManuscriptBlockType.heading => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text.rich(
            TextSpan(
              children: ManuscriptCitationHelper.buildInlineSpans(
                text: block.text,
                manuscript: manuscript,
                style: style,
                baseStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ManuscriptBlockType.paragraph => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(
            TextSpan(
              children: ManuscriptCitationHelper.buildInlineSpans(
                text: block.text,
                manuscript: manuscript,
                style: style,
              ),
            ),
          ),
        ),
      ManuscriptBlockType.equation => Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              if (block.imageUrl != null && block.imageUrl!.isNotEmpty)
                ManuscriptImportImage(url: block.imageUrl!, height: 48),
              Text(
                block.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cambria Math',
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ManuscriptBlockType.image => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.imageUrl != null && block.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ManuscriptImportImage(
                  url: block.imageUrl!,
                  fit: BoxFit.contain,
                ),
              ),
            if (block.caption != null && block.caption!.isNotEmpty)
              Text(
                block.caption!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ManuscriptBlockType.table => _TablePreview(block: block),
    };
  }
}

class ManuscriptPreview extends StatelessWidget {
  final PublishManuscript manuscript;

  const ManuscriptPreview({super.key, required this.manuscript});

  @override
  Widget build(BuildContext context) {
    if (manuscript.bodyBlocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: manuscript.bodyBlocks
          .map(
            (b) => ManuscriptBlockPreview(block: b, manuscript: manuscript),
          )
          .toList(),
    );
  }
}

class _TablePreview extends StatelessWidget {
  final ManuscriptBlock block;

  const _TablePreview({required this.block});

  Widget _cellContent(String text, String imageUrl) {
    final hasImage = imageUrl.isNotEmpty;
    final hasText = text.trim().isNotEmpty;

    Widget imageWidget = ManuscriptImportImage(
      url: imageUrl,
      height: 72,
      fit: BoxFit.contain,
    );

    if (hasImage && hasText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          imageWidget,
          const SizedBox(height: 4),
          Text(ManuscriptDocumentParser.formatChemicalFormulaForDisplay(text)),
        ],
      );
    }
    if (hasImage) return imageWidget;
    return Text(ManuscriptDocumentParser.formatChemicalFormulaForDisplay(text));
  }

  @override
  Widget build(BuildContext context) {
    final rows = ManuscriptBlock.normalizedRows(block.rows);
    if (rows.isEmpty) return const SizedBox.shrink();
    final cellImages = ManuscriptBlock.normalizedCellImages(
      block.rowCellImages,
      rows,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade400),
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: List.generate(rows.length, (r) {
                return TableRow(
                  children: List.generate(rows[r].length, (c) {
                    final imgUrl = r < cellImages.length && c < cellImages[r].length
                        ? cellImages[r][c]
                        : '';
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: _cellContent(rows[r][c], imgUrl),
                    );
                  }),
                );
              }),
            ),
          ),
          if (block.caption != null && block.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                block.caption!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
