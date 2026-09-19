import '../../core/locale/app_translate.dart';
import 'citation_style_converter.dart';
import 'manuscript_document_parser.dart';
import 'manuscript_upload_service.dart';
import 'publish_models.dart';

class ManuscriptStyleResult {
  final PublishManuscript manuscript;
  final int referenceCount;
  final int inTextCount;
  final String sourceName;
  final bool fromFile;

  const ManuscriptStyleResult({
    required this.manuscript,
    required this.referenceCount,
    required this.inTextCount,
    required this.sourceName,
    required this.fromFile,
  });
}

/// Re-reads the uploaded manuscript from Introduction onward, recognizes
/// in-text citations and the reference list, then restyles them.
class ManuscriptReferenceStyler {
  ManuscriptReferenceStyler._();

  static Future<ManuscriptStyleResult> restyle({
    required PublishManuscript manuscript,
    required PublishCitationStyle style,
  }) async {
    var next = manuscript;
    var fromFile = false;
    var sourceName = '';

    final files = next.attachments.where((a) => a.isWord || a.isPdf).toList();
    if (files.isEmpty) {
      throw Exception(appTr(
        'ارفع ملف Word الأصلي من جهازك أولاً، ثم اضغط «تنسيق المراجع الآن». المسودة الحالية ليست الملف الأصلي.',
        'Upload the original Word file from your computer first, then tap Format references now. The current draft is not the original file.',
      ));
    }
    final attachment = preferredSourceDocx(next.attachments) ?? files.last;
    sourceName = attachment.name;
    try {
      final parsed = await ManuscriptDocumentParser.parseFromUrl(
        url: attachment.url,
        filename: attachment.name,
        manuscriptId: next.id,
      );
      final fileRefs =
          ManuscriptDocumentParser.parseReferencesFromText(parsed.fullText);
      final parsedForStyle = parsed.copyWith(
        references: fileRefs.isNotEmpty ? fileRefs : parsed.references,
      );
      final parsedHasProse =
          ManuscriptDocumentParser.blocksHaveBodyProse(parsedForStyle.bodyBlocks);
      final existingHasProse =
          ManuscriptDocumentParser.blocksHaveBodyProse(next.bodyBlocks);
      next = await ManuscriptDocumentParser.applyParseResult(
        manuscript: next,
        parsed: parsedForStyle,
        replaceReferences: true,
        replaceBody: parsedHasProse || !existingHasProse,
      );
      fromFile = true;
    } catch (e) {
      throw Exception(appTr(
        'تعذر قراءة ملف Word الأصلي. أوقف التطبيق (q) وشغّله من جديد، ثم ارفع الملف الأصلي من جهازك — لا تستخدم مسودة سبق تنسيقها.',
        'Could not read the original Word file. Quit the app (q), run it again, and upload the original file from your computer — not a previously formatted draft.',
      ));
    }

    next = CitationStyleConverter.apply(manuscript: next, style: style);

    return ManuscriptStyleResult(
      manuscript: next,
      referenceCount: next.references.length,
      inTextCount: _countCiteMarkers(next),
      sourceName: sourceName,
      fromFile: fromFile,
    );
  }

  static int _countCiteMarkers(PublishManuscript manuscript) {
    final re = RegExp(r'\{\{cite:[^}]+\}\}');
    var n = re.allMatches(manuscript.abstractText).length;
    n += re.allMatches(manuscript.body).length;
    for (final block in manuscript.bodyBlocks) {
      n += re.allMatches(block.text).length;
      if (block.caption != null) {
        n += re.allMatches(block.caption!).length;
      }
    }
    return n;
  }
}
