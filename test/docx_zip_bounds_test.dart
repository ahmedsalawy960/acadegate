import 'dart:typed_data';

import 'package:acadegate/features/acadegate_publish/manuscript_document_parser.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zip(int entries) {
  final a = Archive();
  for (var i = 0; i < entries; i++) {
    a.addFile(ArchiveFile('f$i.txt', 1, [65]));
  }
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

void main() {
  test('ordinary small zip passes the bounds check', () {
    expect(() => ManuscriptDocumentParser.checkDocxZipBounds(_zip(5)),
        returnsNormally);
  });

  test('zip with too many entries is refused', () {
    expect(() => ManuscriptDocumentParser.checkDocxZipBounds(_zip(5001)),
        throwsFormatException);
  });

  test('zip declaring huge uncompressed size is refused', () {
    final bytes = _zip(2);
    final d = ByteData.sublistView(bytes);
    // Rewrite the first central-directory entry's uncompressed size.
    for (var i = bytes.length - 22; i >= 0; i--) {
      if (d.getUint32(i, Endian.little) == 0x06054b50) {
        final pos = d.getUint32(i + 16, Endian.little);
        d.setUint32(pos + 24, 300 * 1024 * 1024, Endian.little);
        break;
      }
    }
    expect(() => ManuscriptDocumentParser.checkDocxZipBounds(bytes),
        throwsFormatException);
  });

  test('file over 32MB is refused without reading it', () {
    expect(
        () => ManuscriptDocumentParser.checkDocxZipBounds(
            Uint8List(33 * 1024 * 1024)),
        throwsFormatException);
  });
}
