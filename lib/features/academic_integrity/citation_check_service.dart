import '../../core/locale/app_translate.dart';

import 'citation_models.dart';

import 'citation_parser.dart';

import 'crossref_client.dart';

import 'openalex_works_client.dart';

import 'scholar_search_utils.dart';

import 'semantic_scholar_client.dart';



class CitationCheckService {

  CitationCheckService._();



  static final CitationCheckService instance = CitationCheckService._();



  final _parser = CitationParser.instance;

  final _crossref = CrossrefClient.instance;

  final _openAlex = OpenAlexWorksClient.instance;

  final _semantic = SemanticScholarClient.instance;



  Future<CitationCheckReport> checkReferences(String rawBibliography) async {

    final citations = _parser.parse(rawBibliography);

    if (citations.isEmpty) {

      throw Exception(appTr(

        'لم يُعثر على مراجع — الصق قائمة المراجع أو نصاً يحتوي DOI',

        'No references found — paste a bibliography or text containing DOIs',

      ));

    }



    final items = <CitationCheckItem>[];

    var verified = 0;

    var partial = 0;

    var notFound = 0;

    var invalid = 0;

    var errors = 0;



    for (final citation in citations.take(40)) {

      try {

        final match = await _validateCitation(citation);

        items.add(CitationCheckItem(citation: citation, match: match));



        switch (match.status) {

          case CitationValidationStatus.verified:

            verified++;

          case CitationValidationStatus.partial:

            partial++;

          case CitationValidationStatus.notFound:

            notFound++;

          case CitationValidationStatus.invalidDoi:

            invalid++;

          case CitationValidationStatus.error:

            errors++;

        }

      } catch (_) {

        errors++;

        items.add(

          CitationCheckItem(

            citation: citation,

            match: CitationMatch(

              status: CitationValidationStatus.error,

              source: CitationDataSource.crossref,

              matchedTitle: '',

              note: appTr('تعذر التحقق', 'Could not verify'),

              scholarSearchUrl: _scholarUrlFor(citation),

            ),

          ),

        );

      }



      await Future<void>.delayed(const Duration(milliseconds: 300));

    }



    return CitationCheckReport(

      items: items,

      verifiedCount: verified,

      partialCount: partial,

      notFoundCount: notFound,

      invalidCount: invalid,

      errorCount: errors,

    );

  }



  Future<CitationMatch> _validateCitation(ParsedCitation citation) async {

    if (citation.doi != null && citation.doi!.isNotEmpty) {

      final byDoi = await _validateByDoi(citation);

      if (byDoi.status == CitationValidationStatus.verified ||

          byDoi.status == CitationValidationStatus.partial) {

        return byDoi;

      }

      // DOI غير موجود في المصادر — جرّب البحث النصي قبل الحكم.

      final byText = await _validateByTitle(citation);

      if (byText.status != CitationValidationStatus.notFound) {

        return byText.copyWith(

          note: byText.note ??

              appTr(

                'DOI غير مسجّل — لكن وُجد تطابق نصي',

                'DOI not registered — but a text match was found',

              ),

        );

      }

      return byDoi;

    }

    return _validateByTitle(citation);

  }



  Future<CitationMatch> _validateByDoi(ParsedCitation citation) async {

    final doi = citation.doi!;



    try {

      final cross = await _crossref.lookupDoi(doi);

      if (cross != null) {

        return _matchFromCrossref(cross, doi, citation);

      }

    } catch (_) {}



    final openAlex = await _openAlex.lookupDoi(doi);

    if (openAlex != null) {

      return CitationMatch(

        status: CitationValidationStatus.verified,

        source: CitationDataSource.openAlex,

        matchedTitle: openAlex.title,

        matchedAuthors: openAlex.authors,

        year: openAlex.year,

        doi: openAlex.doi ?? doi,

        url: openAlex.url,

      );

    }



    final semantic = await _semantic.lookupDoi(doi);

    if (semantic != null) {

      return CitationMatch(

        status: CitationValidationStatus.verified,

        source: CitationDataSource.semanticScholar,

        matchedTitle: semantic.title,

        matchedAuthors: semantic.authors,

        year: semantic.year,

        doi: semantic.doi ?? doi,

        url: semantic.url,

      );

    }



    return CitationMatch(

      status: CitationValidationStatus.invalidDoi,

      source: CitationDataSource.crossref,

      matchedTitle: '',

      doi: doi,

      note: appTr(

        'DOI غير موجود في Crossref/OpenAlex/Semantic Scholar — '

        'قد يظهر على Google Scholar دون تسجيل DOI',

        'DOI not found in Crossref/OpenAlex/Semantic Scholar — '

        'it may appear on Google Scholar without a registered DOI',

      ),

      scholarSearchUrl: _scholarUrlFor(citation),

    );

  }



  Future<CitationMatch> _validateByTitle(ParsedCitation citation) async {

    final queries = <String>{

      citation.searchQuery,

      citation.titleGuess,

      _trimBibliographic(citation.rawText),

    }.where((q) => q.trim().length >= 8).toList();



    if (queries.isEmpty) {

      return _notFound(citation, appTr(

        'نص المرجع قصير جداً للبحث',

        'Reference text too short to search',

      ));

    }



    for (final query in queries) {

      final crossResults = await _crossref.searchBibliographic(query);

      final crossMatch = _bestTitleMatch(

        citation.titleGuess.isNotEmpty ? citation.titleGuess : query,

        crossResults.map((w) => w.title).toList(),

        expectedYear: citation.yearGuess,

      );

      if (crossMatch != null) {

        final work = crossResults[crossMatch.index];

        return _matchFromCrossref(work, work.doi, citation, score: crossMatch.score);

      }



      final openResults = await _openAlex.searchTitle(query);

      final openMatch = _bestTitleMatch(

        citation.titleGuess.isNotEmpty ? citation.titleGuess : query,

        openResults.map((w) => w.title).toList(),

        expectedYear: citation.yearGuess,

      );

      if (openMatch != null) {

        final work = openResults[openMatch.index];

        return CitationMatch(

          status: openMatch.score >= 0.62

              ? CitationValidationStatus.verified

              : CitationValidationStatus.partial,

          source: CitationDataSource.openAlex,

          matchedTitle: work.title,

          matchedAuthors: work.authors,

          year: work.year,

          doi: work.doi,

          url: work.url,

          note: openMatch.score < 0.62

              ? appTr('تطابق عنوان تقريبي', 'Approximate title match')

              : null,

          scholarSearchUrl: openMatch.score < 0.62 ? _scholarUrlFor(citation) : null,

        );

      }



      final semResults = await _semantic.search(query);

      final semMatch = _bestTitleMatch(

        citation.titleGuess.isNotEmpty ? citation.titleGuess : query,

        semResults.map((p) => p.title).toList(),

        expectedYear: citation.yearGuess,

      );

      if (semMatch != null) {

        final work = semResults[semMatch.index];

        return CitationMatch(

          status: semMatch.score >= 0.62

              ? CitationValidationStatus.verified

              : CitationValidationStatus.partial,

          source: CitationDataSource.semanticScholar,

          matchedTitle: work.title,

          matchedAuthors: work.authors,

          year: work.year,

          doi: work.doi,

          url: work.url,

          note: semMatch.score < 0.62

              ? appTr('تطابق عنوان تقريبي', 'Approximate title match')

              : null,

          scholarSearchUrl: semMatch.score < 0.62 ? _scholarUrlFor(citation) : null,

        );

      }

    }



    return _notFound(

      citation,

      appTr(

        'لم يُعثر في Crossref/OpenAlex/Semantic Scholar — '

        'جرّب البحث على Google Scholar (قد لا يكون للمرجع DOI)',

        'Not found in Crossref/OpenAlex/Semantic Scholar — '

        'try Google Scholar (reference may lack a DOI)',

      ),

    );

  }



  CitationMatch _matchFromCrossref(

    CrossrefWork work,

    String? doi,

    ParsedCitation citation, {

    double score = 1.0,

  }) {

    final status = score >= 0.62

        ? CitationValidationStatus.verified

        : CitationValidationStatus.partial;

    return CitationMatch(

      status: status,

      source: CitationDataSource.crossref,

      matchedTitle: work.title,

      matchedAuthors: work.authors,

      year: work.year,

      doi: work.doi ?? doi,

      url: work.url,

      note: score < 0.62

          ? appTr('تطابق عنوان تقريبي', 'Approximate title match')

          : null,

    );

  }



  CitationMatch _notFound(ParsedCitation citation, String note) {

    return CitationMatch(

      status: CitationValidationStatus.notFound,

      source: CitationDataSource.crossref,

      matchedTitle: '',

      note: note,

      scholarSearchUrl: _scholarUrlFor(citation),

    );

  }



  String _scholarUrlFor(ParsedCitation citation) {

    final query = citation.titleGuess.length >= 8

        ? citation.titleGuess

        : citation.searchQuery;

    return buildGoogleScholarSearchUrl(

      query: query,

      year: citation.yearGuess,

    );

  }



  String _trimBibliographic(String raw) {

    var work = raw.replaceAll(RegExp(r'^\[\d+\]|\d+\.|\d+\)\s*'), '');

    work = work.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (work.length > 300) return work.substring(0, 300);

    return work;

  }



  ({int index, double score})? _bestTitleMatch(

    String query,

    List<String> titles, {

    int? expectedYear,

  }) {

    if (titles.isEmpty) return null;



    final qTokens = _tokenize(query);

    if (qTokens.isEmpty) return null;



    var bestIndex = 0;

    var bestScore = 0.0;



    for (var i = 0; i < titles.length; i++) {

      var score = _jaccardScore(qTokens, _tokenize(titles[i]));

      if (expectedYear != null) {

        final yearInTitle = RegExp('\\b$expectedYear\\b').hasMatch(titles[i]);

        if (yearInTitle) score += 0.08;

      }

      if (score > bestScore) {

        bestScore = score;

        bestIndex = i;

      }

    }



    if (bestScore < 0.32) return null;

    return (index: bestIndex, score: bestScore);

  }



  Set<String> _tokenize(String text) {

    final normalized = text

        .toLowerCase()

        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')

        .replaceAll(RegExp(r'\s+'), ' ')

        .trim();



    return normalized

        .split(' ')

        .where((w) => w.length >= 2)

        .where((w) => !_stopWords.contains(w))

        .toSet();

  }



  static const _stopWords = {

    'the', 'and', 'for', 'with', 'from', 'that', 'this', 'using', 'based',

    'في', 'من', 'على', 'إلى', 'عن', 'مع', 'هذا', 'هذه', 'ذلك', 'التي', 'الذي',

    'vol', 'pp', 'doi', 'issn', 'isbn', 'ed', 'eds', 'et', 'al',

  };



  double _jaccardScore(Set<String> a, Set<String> b) {

    if (a.isEmpty || b.isEmpty) return 0;

    final intersection = a.intersection(b).length;

    final union = a.union(b).length;

    return intersection / union;

  }

}



extension _CitationMatchCopy on CitationMatch {

  CitationMatch copyWith({

    String? note,

    String? scholarSearchUrl,

  }) {

    return CitationMatch(

      status: status,

      source: source,

      matchedTitle: matchedTitle,

      matchedAuthors: matchedAuthors,

      year: year,

      doi: doi,

      url: url,

      note: note ?? this.note,

      scholarSearchUrl: scholarSearchUrl ?? this.scholarSearchUrl,

    );

  }

}


