import 'dart:convert';
import 'dart:typed_data';
import 'package:acadegate/features/acadegate_publish/journal_format_rules.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:acadegate/features/acadegate_publish/manuscript_docx_export_service.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Uint8List _document(String visual) {
  final zip = Archive()
    ..addFile(ArchiveFile('word/media/image1.png', _png.length, _png))
    ..addFile(
      ArchiveFile(
        'word/_rels/document.xml.rels',
        0,
        utf8.encode('''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId8" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
</Relationships>'''),
      ),
    )
    ..addFile(
      ArchiveFile(
        'word/document.xml',
        0,
        utf8.encode('''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><w:body>
<w:p><w:r><w:t>Visual preservation sample with enough unmodified scientific prose.</w:t></w:r></w:p>
<w:p><w:r>$visual</w:r></w:p></w:body></w:document>'''),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

void main() {
  test(
    'legacy VML preview keeps width and height from point dimensions',
    () async {
      final parsed = await ManuscriptDocumentParser.parseFile(
        bytes: _document(
          '<w:object><v:shape style="width:186pt;height:18pt"><v:imagedata r:id="rId8"/></v:shape></w:object>',
        ),
        filename: 'legacy-preview.docx',
      );
      final image = parsed.bodyBlocks.firstWhere(
        (b) => b.type == ManuscriptBlockType.image,
      );
      expect(image.imageWidthEmu, 2362200);
      expect(image.imageHeightEmu, 228600);
    },
  );
  test('DrawingML prefix does not hide visual extents', () async {
    final parsed = await ManuscriptDocumentParser.parseFile(
      bytes: _document(
        '<w:drawing><wp:inline><wp:extent cx="3200000" cy="700000"/><a:graphic><a:blip r:embed="rId8"/></a:graphic></wp:inline></w:drawing>',
      ),
      filename: 'drawing.docx',
    );
    final image = parsed.bodyBlocks.firstWhere(
      (b) => b.type == ManuscriptBlockType.image,
    );
    expect(image.imageWidthEmu, 3200000);
    expect(image.imageHeightEmu, 700000);
  });
  test(
    'inline pictures expand their own line even under double-spaced rules',
    () async {
      final bytes = await ManuscriptDocxExportService.instance.buildDocx(
        manuscript: PublishManuscript(
          userId: 'test',
          title: 'Picture height test',
          bodyBlocks: [
            ManuscriptBlock(
              id: 'picture',
              type: ManuscriptBlockType.image,
              imageUrl: 'data:image/png;base64,${base64Encode(_png)}',
              imageWidthEmu: 2000000,
              imageHeightEmu: 1000000,
            ),
          ],
        ),
        rules: const JournalFormatRules(
          journalName: 'Test',
          citationStyle: PublishCitationStyle.ieee,
          lineSpacing: 2,
        ),
      );
      final zip = ZipDecoder().decodeBytes(bytes);
      final doc = XmlDocument.parse(
        utf8.decode(zip.findFile('word/document.xml')!.content as List<int>),
      );
      final picture = doc
          .findAllElements('w:p')
          .firstWhere((p) => p.findAllElements('w:drawing').isNotEmpty);
      final spacing = picture.findAllElements('w:spacing').single;
      expect(spacing.getAttribute('w:lineRule'), 'auto');
      expect(spacing.getAttribute('w:line'), '240');
      expect(
        picture.findAllElements('wp:extent').single.getAttribute('cy'),
        '1000000',
      );
    },
  );
}
