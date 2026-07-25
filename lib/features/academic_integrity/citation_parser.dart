import 'citation_models.dart';



class CitationParser {

  CitationParser._();



  static final CitationParser instance = CitationParser._();



  static final _doiPattern = RegExp(

    r'10\.\d{4,9}/[-._;()/:A-Za-z0-9]+',

    caseSensitive: false,

  );



  static final _referenceHeader = RegExp(

    r'^(references|bibliography|works cited|المراجع|قائمة المراجع|المصادر)\s*$',

    caseSensitive: false,

  );



  List<ParsedCitation> parse(String raw) {

    final text = raw.trim();

    if (text.isEmpty) return const [];



    final lines = _splitIntoReferenceLines(text);

    final citations = <ParsedCitation>[];



    for (var i = 0; i < lines.length; i++) {

      final line = lines[i].trim();

      if (line.length < 12) continue;



      final doiMatch = _doiPattern.firstMatch(line);

      final doi = doiMatch?.group(0)?.replaceAll(RegExp(r'[.,;)\]]+$'), '');

      final year = _guessYear(line);

      final title = _guessTitle(line, doi);



      citations.add(

        ParsedCitation(

          index: i + 1,

          rawText: line,

          doi: doi,

          titleGuess: title,

          yearGuess: year,

          searchQuery: _buildSearchQuery(line, doi, title),

        ),

      );

    }



    return citations;

  }



  List<String> _splitIntoReferenceLines(String text) {

    final normalized = text.replaceAll('\r\n', '\n');

    final sections = normalized.split('\n');

    var inRefs = false;

    final buffer = <String>[];

    final lines = <String>[];



    for (final line in sections) {

      final trimmed = line.trim();

      if (trimmed.isEmpty) {

        if (buffer.isNotEmpty) {

          lines.add(buffer.join(' '));

          buffer.clear();

        }

        continue;

      }



      if (!inRefs && _referenceHeader.hasMatch(trimmed)) {

        inRefs = true;

        continue;

      }



      if (_looksLikeNewReference(trimmed) && buffer.isNotEmpty) {

        lines.add(buffer.join(' '));

        buffer

          ..clear()

          ..add(trimmed);

      } else {

        buffer.add(trimmed);

      }

    }



    if (buffer.isNotEmpty) {

      lines.add(buffer.join(' '));

    }



    if (lines.length >= 2) return lines;



    return normalized

        .split(RegExp(r'\n(?=\[\d+\]|\d+\.|\d+\))'))

        .map((s) => s.replaceAll(RegExp(r'^\[\d+\]|\d+\.|\d+\)\s*'), '').trim())

        .where((s) => s.length >= 12)

        .toList();

  }



  bool _looksLikeNewReference(String line) {

    return RegExp(r'^(\[\d+\]|\d+\.|\d+\))\s+').hasMatch(line);

  }



  String _buildSearchQuery(String line, String? doi, String title) {

    var work = line;

    if (doi != null) {

      work = work.replaceAll(RegExp('doi[:\\s]*$doi', caseSensitive: false), '');

      work = work.replaceAll(doi, '');

    }

    work = work.replaceAll(_doiPattern, '');

    work = work.replaceAll(RegExp(r'^\[\d+\]|\d+\.|\d+\)\s*'), '');

    work = work.replaceAll(RegExp(r'\s+'), ' ').trim();



    if (title.length >= 12 && title.length <= 220) {

      return title;

    }

    if (work.length > 280) {

      return work.substring(0, 280).trim();

    }

    return work;

  }



  int? _guessYear(String line) {

    final parenYear = RegExp(r'\(\s*((?:19|20)\d{2})\s*\)').firstMatch(line);

    if (parenYear != null) {

      return int.tryParse(parenYear.group(1)!);

    }

    final plainYear = RegExp(r'\b((?:19|20)\d{2})\b').firstMatch(line);

    return plainYear != null ? int.tryParse(plainYear.group(1)!) : null;

  }



  String _guessTitle(String line, String? doi) {

    var work = line;

    if (doi != null) {

      work = work.replaceAll(RegExp('doi[:\\s]*$doi', caseSensitive: false), '');

      work = work.replaceAll(doi, '');

    }



    work = work.replaceAll(_doiPattern, '');

    work = work.replaceAll(RegExp(r'^\[\d+\]|\d+\.|\d+\)\s*'), '');



    // عناوين بين علامات اقتباس «» أو ""

    final quoted = RegExp(

      r'[«""„]([^»""]+)[»""]',

      dotAll: true,

    ).firstMatch(work);

    if (quoted != null) {

      final title = quoted.group(1)!.trim();

      if (title.length >= 8) return title;

    }



    // APA / Chicago: (2020). Title of work.

    final apa = RegExp(

      r'\(\s*(?:19|20)\d{2}\s*\)\s*[.:]\s*(.+?)\s*\.',

      dotAll: true,

    ).firstMatch(work);

    if (apa != null) {

      final title = apa.group(1)!.trim();

      if (title.length >= 8 && !_looksLikeAuthorFragment(title)) {

        return title;

      }

    }



    // Author, 2020. Title.

    final yearDot = RegExp(

      r'(?:^|[\s,])(?:19|20)\d{2}\s*\.\s*(.+?)\s*\.',

      dotAll: true,

    ).firstMatch(work);

    if (yearDot != null) {

      final title = yearDot.group(1)!.trim();

      if (title.length >= 8 && !_looksLikeAuthorFragment(title)) {

        return title;

      }

    }



    // IEEE: Title. In Proc. / vol.

    final ieee = RegExp(

      r'^[^.]+\.\s+(.+?)\s*\.\s+(?:In\s|Proc\.|IEEE|Journal|Vol\.|pp\.)',

      caseSensitive: false,

      dotAll: true,

    ).firstMatch(work);

    if (ieee != null) {

      final title = ieee.group(1)!.trim();

      if (title.length >= 8) return title;

    }



    // عنوان بعد أول نقطة (مؤلفون) وقبل السنة

    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(work);

    if (yearMatch != null && yearMatch.start > 10) {

      final beforeYear = work.substring(0, yearMatch.start).trim();

      final afterAuthors = beforeYear.replaceFirst(RegExp(r'^[^.]+\.\s*'), '');

      if (afterAuthors.length >= 8 && afterAuthors != beforeYear) {

        final cleaned = afterAuthors.replaceAll(RegExp(r'^\(\s*|\s*\)$'), '');

        if (cleaned.length >= 8) return cleaned;

      }

    }



    if (work.length > 200) {

      return work.substring(0, 200).trim();

    }

    return work.trim();

  }



  bool _looksLikeAuthorFragment(String text) {

    if (text.length > 80) return false;

    return RegExp(r'^[A-Z][a-z]+,\s*[A-Z]\.').hasMatch(text) ||

        RegExp(r'^[أ-ي]{2,}\s+[أ-ي]').hasMatch(text);

  }

}


