import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores pictures from a fresh read of whatever file was uploaded', () {
    final saved = [
      const ManuscriptBlock(
        id: 'p1',
        type: ManuscriptBlockType.paragraph,
        text: 'kept',
      ),
      const ManuscriptBlock(
        id: 'eq1',
        type: ManuscriptBlockType.equation,
        text: 'kept formula',
        imageUrl: '{{img:eq1}}',
      ),
      const ManuscriptBlock(
        id: 't1',
        type: ManuscriptBlockType.table,
        rows: [
          ['Structure'],
          [''],
        ],
        rowCellImages: [
          [''],
          ['{{img:t1_r1_c0}}'],
        ],
      ),
    ];

    expect(ManuscriptDocumentParser.needsSourceMediaRestore(saved), isTrue);

    final restored = ManuscriptDocumentParser.restoreMediaFromParsed(
      saved: saved,
      parsed: const [
        ManuscriptBlock(
          id: 'new-eq',
          type: ManuscriptBlockType.equation,
          text: 'parsed formula',
          imageUrl: 'data:image/png;base64,AAAA',
        ),
        ManuscriptBlock(
          id: 'new-t',
          type: ManuscriptBlockType.table,
          rowCellImages: [
            [''],
            ['data:image/png;base64,BBBB'],
          ],
        ),
      ],
    );

    expect(restored[0].text, 'kept');
    expect(restored[1].text, 'kept formula');
    expect(restored[1].imageUrl, 'data:image/png;base64,AAAA');
    expect(restored[2].rowCellImages[1][0], 'data:image/png;base64,BBBB');
    expect(
      ManuscriptDocumentParser.needsSourceMediaRestore(restored),
      isFalse,
    );
  });
}
