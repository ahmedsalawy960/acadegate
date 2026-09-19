import '../../core/locale/app_translate.dart';
import '../academic_integrity/crossref_client.dart';
import '../academic_integrity/europe_pmc_client.dart';
import '../academic_integrity/google_scholar_client.dart';
import '../academic_integrity/openalex_works_client.dart';
import '../academic_integrity/semantic_scholar_client.dart';
import 'advisor_intent.dart';
import 'grounded_work.dart';
import 'literature_relevance.dart';

/// Live bibliography from OpenAlex + Crossref + Semantic Scholar. Never invent a DOI.
class GroundedReferenceService {
  GroundedReferenceService._();

  static final GroundedReferenceService instance = GroundedReferenceService._();

  static final doiPattern = RegExp(
    r'10\.\d{4,9}/[-._;()/:A-Z0-9]+',
    caseSensitive: false,
  );

  static String normalizeDoi(String raw) {
    var doi = raw.trim();
    doi = doi.replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/', caseSensitive: false), '');
    doi = doi.replaceAll(RegExp(r'[.,;)\]]+$'), '');
    return doi.toLowerCase();
  }

  static List<String> extractDois(String text) {
    final found = <String>{};
    for (final match in doiPattern.allMatches(text)) {
      final doi = normalizeDoi(match.group(0) ?? '');
      if (doi.startsWith('10.')) found.add(doi);
    }
    return found.toList();
  }

  static String topicFromMessage(String message) {
    var topic = extractAdvisorTopic(message) ?? message;
    topic = topic.replaceAll(
      RegExp(
        r'(مراجع|مرجع|توثيق|قائمة مصادر|bibliography|references?|citations?|'
        r'doi|apa|ieee|chicago|harvard|رتّب|رتب|ابحث|أعطني|اعطني|اقترح|'
        r'papers?|articles?)',
        caseSensitive: false,
      ),
      ' ',
    );
    topic = topic.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (topic.length > 160) topic = topic.substring(0, 160).trim();
    return topic;
  }

  static bool looksLikeBibliographyPaste(String message) {
    final dois = extractDois(message);
    if (dois.isNotEmpty) return true;
    final years = RegExp(r'\b(19|20)\d{2}\b').allMatches(message).length;
    final lines = message
        .trim()
        .split(RegExp(r'\n+'))
        .where((l) => l.trim().length > 20);
    return message.trim().length > 120 && years >= 2 && lines.length >= 2;
  }

  Future<GroundedReferenceBundle> searchTopic(
    String message, {
    int limit = 8,
    bool byRelevance = false,
    Iterable<String> mustMatchTokens = const [],
  }) async {
    final topic = topicFromMessage(message);
    if (topic.length < 4) {
      return GroundedReferenceBundle(topic: topic);
    }

    final byDoi = <String, GroundedWork>{};

    try {
      final openAlex = await OpenAlexWorksClient.instance.searchTitle(
        topic,
        perPage: limit,
        byRelevance: byRelevance,
      );
      for (final work in openAlex) {
        _offer(
          byDoi,
          work.doi,
          work.title,
          work.year,
          work.authors,
          'OpenAlex',
          journal: work.journal,
          abstractText: work.abstractText,
        );
      }
    } catch (_) {}

    try {
      final crossref = await CrossrefClient.instance.searchBibliographic(
        topic,
        rows: limit,
      );
      for (final work in crossref) {
        _offer(byDoi, work.doi, work.title, work.year, work.authors, 'Crossref');
      }
    } catch (_) {}

    try {
      final semantic = await SemanticScholarClient.instance.search(
        topic,
        limit: limit,
      );
      for (final work in semantic) {
        _offer(
          byDoi,
          work.doi,
          work.title,
          work.year,
          work.authors,
          'Semantic Scholar',
          journal: work.venue,
          abstractText: work.abstractText,
          externalUrl: work.url,
        );
      }
    } catch (_) {}

    try {
      final epmc = await EuropePmcClient.instance.search(topic, pageSize: limit);
      for (final work in epmc) {
        _offer(
          byDoi,
          work.doi,
          work.title,
          work.year,
          work.authors,
          'Europe PMC',
          journal: work.journal,
          abstractText: work.abstractText,
          externalUrl: work.url,
        );
      }
    } catch (_) {}

    try {
      final scholar = await GoogleScholarClient.instance.search(
        topic,
        limit: limit,
      );
      for (final work in scholar) {
        _offer(
          byDoi,
          work.doi,
          work.title,
          work.year,
          work.authors,
          'Google Scholar',
          journal: work.journal,
          abstractText: work.snippet,
          externalUrl: work.url,
        );
      }
    } on ScholarSearchException catch (e) {
      if (e.code != 'quota_exceeded') rethrow;
    } catch (_) {}

    var works = byDoi.values.toList()
      ..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    final tokens = mustMatchTokens
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.length >= 3)
        .toList();
    if (tokens.isNotEmpty) {
      works = works.where((w) {
        final hay = '${w.title} ${w.journal ?? ''} ${w.authors}'.toLowerCase();
        return tokens.any((t) => hay.contains(t));
      }).toList();
    }
    return GroundedReferenceBundle(
      topic: topic,
      works: works.take(limit).toList(),
    );
  }

  /// Global index search (OpenAlex + Semantic Scholar + Crossref + Europe PMC).
  /// DOI is preferred but not required — title/author/year records are kept.
  Future<GroundedReferenceBundle> searchScientific({
    required List<String> queries,
    int limit = 20,
    bool preferEnglish = true,
    int minYear = 1990,
    Iterable<String> corePhrases = const [],
    Iterable<String> strongTokens = const [],
    bool includeTheses = false,
    Iterable<String> disciplineTokens = const [],
    Iterable<String> alienTokens = const [],
    bool requireCoreHit = false,
    bool requireTitleCoreHit = false,
    String commandText = '',
    int minScore = 4,
    bool requireDoi = false,
  }) async {
    final cleaned = queries
        .map((q) => q.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((q) => q.length >= 4)
        .take(6)
        .toList();
    if (cleaned.isEmpty) {
      return const GroundedReferenceBundle(topic: '');
    }

    final byKey = <String, GroundedWork>{};
    final perSource = limit.clamp(16, 50);

    Future<void> harvestOpenAlex(
      String query, {
      bool englishOnly = false,
      bool arabicOnly = false,
    }) async {
      try {
        final openAlex = await OpenAlexWorksClient.instance.searchTitle(
          query,
          perPage: perSource,
          byRelevance: true,
          englishOnly: englishOnly,
          arabicOnly: arabicOnly,
          fromYear: minYear > 0 ? minYear : null,
          includeTheses: includeTheses,
          hasDoi: requireDoi,
        );
        for (final work in openAlex) {
          _offer(
            byKey,
            work.doi,
            work.title,
            work.year,
            work.authors,
            'OpenAlex',
            journal: work.journal,
            abstractText: work.abstractText,
            requireDoi: requireDoi,
            externalUrl: work.url,
          );
        }
      } catch (_) {}
    }

    Future<void> harvest(String query, {required bool englishOnly}) async {
      await harvestOpenAlex(query, englishOnly: englishOnly);

      try {
        final crossref = await CrossrefClient.instance.searchBibliographic(
          query,
          rows: perSource,
          fromYear: minYear > 0 ? minYear : null,
          journalArticlesOnly: !includeTheses,
        );
        for (final work in crossref) {
          _offer(
            byKey,
            work.doi,
            work.title,
            work.year,
            work.authors,
            'Crossref',
            requireDoi: requireDoi,
          );
        }
      } catch (_) {}

      try {
        final semantic = await SemanticScholarClient.instance.search(
          query,
          limit: perSource,
        );
        for (final work in semantic) {
          _offer(
            byKey,
            work.doi,
            work.title,
            work.year,
            work.authors,
            'Semantic Scholar',
            journal: work.venue,
            abstractText: work.abstractText,
            requireDoi: requireDoi,
            externalUrl: work.url,
          );
        }
      } catch (_) {}

      try {
        final epmc = await EuropePmcClient.instance.search(
          query,
          pageSize: perSource,
        );
        for (final work in epmc) {
          _offer(
            byKey,
            work.doi,
            work.title,
            work.year,
            work.authors,
            'Europe PMC',
            journal: work.journal,
            abstractText: work.abstractText,
            requireDoi: requireDoi,
            externalUrl: work.url,
          );
        }
      } catch (_) {}
    }

    for (final query in cleaned) {
      await harvest(query, englishOnly: preferEnglish);
      if (!preferEnglish) {
        await harvestOpenAlex(query, arabicOnly: true);
      }
    }

    // One Scholar request per harvest (quota = harvests/day, not queries/day).
    try {
      final scholar = await GoogleScholarClient.instance.search(
        cleaned.first,
        limit: perSource.clamp(20, 60),
        fromYear: minYear > 0 ? minYear : null,
      );
      for (final work in scholar) {
        _offer(
          byKey,
          work.doi,
          work.title,
          work.year,
          work.authors,
          'Google Scholar',
          journal: work.journal,
          abstractText: work.snippet,
          requireDoi: requireDoi,
          externalUrl: work.url,
        );
      }
    } on ScholarSearchException catch (e) {
      // Free indexes already ran; don't abort the whole harvest on Scholar caps.
      if (e.code != 'quota_exceeded') rethrow;
    } catch (_) {}

    List<GroundedWork> ranked = LiteratureRelevance.rank(
      works: byKey.values.toList(),
      corePhrases: corePhrases,
      strongTokens: strongTokens,
      preferEnglish: preferEnglish,
      minYear: minYear,
      limit: limit,
      minScore: minScore,
      requireCoreHit: requireCoreHit,
      requireTitleCoreHit: requireTitleCoreHit,
      commandText: commandText,
      disciplineTokens: disciplineTokens,
      alienTokens: alienTokens,
    );

    if (ranked.length < 6 && preferEnglish) {
      for (final query in cleaned) {
        await harvest(query, englishOnly: false);
      }
      ranked = LiteratureRelevance.rank(
        works: byKey.values.toList(),
        corePhrases: corePhrases,
        strongTokens: strongTokens,
        preferEnglish: false,
        minYear: minYear,
        limit: limit,
        minScore: minScore,
        requireCoreHit: requireCoreHit,
        requireTitleCoreHit: requireTitleCoreHit,
        commandText: commandText,
        disciplineTokens: disciplineTokens,
        alienTokens: alienTokens,
      );
    }

    if (ranked.length < 4 && !preferEnglish && requireTitleCoreHit) {
      ranked = LiteratureRelevance.rank(
        works: byKey.values.toList(),
        corePhrases: corePhrases,
        strongTokens: strongTokens,
        preferEnglish: false,
        minYear: minYear,
        limit: limit,
        minScore: (minScore - 2).clamp(2, 20),
        requireCoreHit: requireCoreHit,
        requireTitleCoreHit: false,
        commandText: commandText,
        disciplineTokens: disciplineTokens,
        alienTokens: alienTokens,
      );
    }

    if (ranked.isEmpty && byKey.isNotEmpty) {
      ranked = LiteratureRelevance.rank(
        works: byKey.values.toList(),
        corePhrases: corePhrases,
        strongTokens: strongTokens,
        preferEnglish: preferEnglish,
        minYear: minYear,
        limit: limit,
        minScore: 1,
        requireCoreHit: false,
        requireTitleCoreHit: false,
        commandText: commandText,
        disciplineTokens: disciplineTokens,
        alienTokens: alienTokens,
      );
      if (ranked.isEmpty) {
        ranked = byKey.values.take(limit).toList();
      }
    }

    return GroundedReferenceBundle(
      topic: cleaned.first,
      works: ranked,
    );
  }

  /// Drop DOIs that OpenAlex/Crossref cannot confirm. Real DOIs in the text
  /// are looked up even if they were not in the topic search.
  Future<String> enforceVerifiedDois(
    String text, {
    GroundedReferenceBundle? known,
    Future<GroundedWork?> Function(String doi)? lookup,
  }) async {
    final dois = extractDois(text);
    if (dois.isEmpty) return text;

    final allowed = {...?known?.doiSet};
    final dropped = <String>[];
    final resolve = lookup ?? _lookup;

    for (final doi in dois) {
      if (allowed.contains(doi)) continue;
      final verified = await resolve(doi);
      if (verified != null) {
        allowed.add(normalizeDoi(verified.doi));
      } else {
        dropped.add(doi);
      }
    }

    var cleaned = text;
    for (final doi in dropped) {
      cleaned = cleaned.replaceAll(
        RegExp(
          r'(https?://(dx\.)?doi\.org/)?' + RegExp.escape(doi),
          caseSensitive: false,
        ),
        '',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'doi:\s*' + RegExp.escape(doi), caseSensitive: false),
        '',
      );
    }
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();

    if (dropped.isEmpty) return cleaned;

    final note = appTr(
      '\n\n_حُذف ${dropped.length} معرّف DOI غير موجود في OpenAlex أو Crossref._',
      '\n\n_${dropped.length} DOI(s) not found in OpenAlex or Crossref were removed._',
    );
    return '$cleaned$note';
  }

  String promptBlock(GroundedReferenceBundle bundle) {
    if (bundle.isEmpty) {
      return appTr(
        'لا توجد أعمال موثّقة من OpenAlex/Crossref لهذا الموضوع بعد. '
        'لا تكتب قائمة مراجع ولا تخترع DOI. اطلب موضوعاً أدق أو قل إن المصدر غير مؤكد.',
        'No OpenAlex/Crossref works were found for this topic yet. '
        'Do not write a reference list or invent a DOI. Ask for a clearer topic or say the source is unverified.',
      );
    }
    final buffer = StringBuffer(
      appTr(
        'أعمال موثّقة فقط (OpenAlex/Crossref). لا تستشهد بغيرها ولا تخترع DOI:\n',
        'Verified works only (OpenAlex/Crossref). Cite none others and never invent a DOI:\n',
      ),
    );
    for (var i = 0; i < bundle.works.length; i++) {
      final w = bundle.works[i];
      buffer.writeln('${i + 1}. ${w.apaLine} [${w.source}]');
      final abs = w.abstractText.trim();
      if (abs.isNotEmpty) {
        final cut = abs.length > 400 ? '${abs.substring(0, 400)}…' : abs;
        buffer.writeln('   abstract: $cut');
      }
    }
    return buffer.toString();
  }

  String bibliographySection(GroundedReferenceBundle bundle) {
    if (bundle.isEmpty) {
      return appTr(
        'لم يُعثر على مراجع بـ DOI مؤكد في OpenAlex أو Crossref لهذا الموضوع. '
        'لم تُدرج أي مصادر مختلقة.',
        'No references with a confirmed DOI were found in OpenAlex or Crossref for this topic. '
        'No invented sources were added.',
      );
    }
    final buffer = StringBuffer(
      appTr(
        '**مراجع موثّقة (OpenAlex / Crossref فقط)** — موضوع: ${bundle.topic}\n',
        '**Verified references (OpenAlex / Crossref only)** — topic: ${bundle.topic}\n',
      ),
    );
    for (final work in bundle.works) {
      buffer.writeln('• ${work.apaLine}');
    }
    return buffer.toString();
  }

  Future<String> verifyPastedBibliography(String message) async {
    final dois = extractDois(message);
    if (dois.isEmpty) {
      return appTr(
        'لم أجد DOI في النص. أضف معرّفات DOI أو اطلب مراجع لموضوع محدد — لن أرتّب مصادر بلا تحقق.',
        'No DOI was found in the text. Add DOI identifiers or ask for sources on a topic — I will not format unverified sources.',
      );
    }
    final verified = <GroundedWork>[];
    final rejected = <String>[];
    for (final doi in dois.take(20)) {
      final work = await _lookup(doi);
      if (work == null) {
        rejected.add(doi);
      } else {
        verified.add(work);
      }
    }
    final buffer = StringBuffer(
      appTr(
        '**تحقق DOI عبر OpenAlex / Crossref**\n',
        '**DOI check via OpenAlex / Crossref**\n',
      ),
    );
    if (verified.isNotEmpty) {
      buffer.writeln(appTr('مؤكد:', 'Verified:'));
      for (final work in verified) {
        buffer.writeln('• ${work.apaLine}');
      }
    }
    if (rejected.isNotEmpty) {
      buffer.writeln(
        appTr(
          '\nغير موجود (حُذف ولن يُستخدم):\n${rejected.map((d) => '• $d').join('\n')}',
          '\nNot found (removed, will not be used):\n${rejected.map((d) => '• $d').join('\n')}',
        ),
      );
    }
    return buffer.toString();
  }

  String replyForCitations(
    GroundedReferenceBundle bundle, {
    required String message,
  }) {
    final topic = topicFromMessage(message);
    if (topic.length < 4) {
      return appTr(
        'حدد موضوع البحث (مثلاً: adsorption of heavy metals) أو الصق قائمة مراجع فيها DOI '
        'لأتحقق منها عبر OpenAlex وCrossref. لن أختلق مصادر.',
        'Give a research topic (e.g. adsorption of heavy metals) or paste a reference list with DOIs '
        'and I will verify them via OpenAlex and Crossref. I will not invent sources.',
      );
    }
    if (bundle.isEmpty) {
      return appTr(
        'لم يُعثر على أعمال مطابقة في OpenAlex / Crossref / Semantic Scholar / Europe PMC عن «$topic». '
        'لم أختلق أي مرجع. جرّب صياغة أدق أو مصطلحات إنجليزية للمجال. '
        '(ملاحظة: Google Scholar لا يتوفر عبر واجهة رسمية للتطبيق.)',
        'No matching works were found in OpenAlex / Crossref / Semantic Scholar / Europe PMC for «$topic». '
        'No sources were invented. Try a clearer phrasing or English field terms. '
        '(Note: Google Scholar has no official API for apps.)',
      );
    }
    return bibliographySection(bundle);
  }

  void _offer(
    Map<String, GroundedWork> byKey,
    String? doi,
    String title,
    int? year,
    String? authors,
    String source, {
    String? journal,
    String? abstractText,
    String? externalUrl,
    bool requireDoi = false,
  }) {
    if (title.trim().isEmpty) return;
    final normalized = (doi == null || doi.trim().isEmpty)
        ? ''
        : normalizeDoi(doi);
    final hasDoi = normalized.startsWith('10.') && normalized.contains('/');
    if (requireDoi && !hasDoi) return;

    final incoming = GroundedWork(
      title: title.trim(),
      doi: hasDoi ? normalized : '',
      year: year,
      authors: authors ?? '',
      source: source,
      journal: journal,
      abstractText: abstractText?.trim() ?? '',
      externalUrl: (externalUrl ?? '').trim(),
    );
    final key = incoming.mergeKey;
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = incoming;
      return;
    }
    // Prefer the record that already has a DOI / richer metadata.
    final preferIncoming = incoming.hasDoi && !existing.hasDoi;
    final base = preferIncoming ? incoming : existing;
    final other = preferIncoming ? existing : incoming;
    byKey[key] = GroundedWork(
      title: base.title,
      doi: base.hasDoi ? base.doi : other.doi,
      year: base.year ?? other.year,
      authors: base.authors.isNotEmpty ? base.authors : other.authors,
      source: base.source,
      journal: (base.journal != null && base.journal!.trim().isNotEmpty)
          ? base.journal
          : other.journal,
      abstractText: base.abstractText.trim().isNotEmpty
          ? base.abstractText
          : other.abstractText,
      externalUrl: base.externalUrl.trim().isNotEmpty
          ? base.externalUrl
          : other.externalUrl,
    );
  }

  Future<GroundedWork?> _lookup(String doi) async {
    final key = normalizeDoi(doi);
    GroundedWork? best;
    try {
      final openAlex = await OpenAlexWorksClient.instance.lookupDoi(key);
      if (openAlex != null && openAlex.title.trim().isNotEmpty) {
        best = GroundedWork(
          title: openAlex.title,
          doi: normalizeDoi(openAlex.doi ?? key),
          year: openAlex.year,
          authors: openAlex.authors ?? '',
          source: 'OpenAlex',
          journal: openAlex.journal,
          abstractText: openAlex.abstractText,
        );
      }
    } catch (_) {}
    try {
      final semantic = await SemanticScholarClient.instance.lookupDoi(key);
      if (semantic != null && semantic.title.trim().isNotEmpty) {
        final next = GroundedWork(
          title: semantic.title,
          doi: normalizeDoi(semantic.doi ?? key),
          year: semantic.year,
          authors: semantic.authors ?? '',
          source: 'Semantic Scholar',
          journal: semantic.venue,
          abstractText: semantic.abstractText,
        );
        best = best == null ? next : _preferRicher(best, next);
      }
    } catch (_) {}
    try {
      final crossref = await CrossrefClient.instance.lookupDoi(key);
      if (crossref != null && crossref.title.trim().isNotEmpty) {
        final next = GroundedWork(
          title: crossref.title,
          doi: normalizeDoi(crossref.doi ?? key),
          year: crossref.year,
          authors: crossref.authors ?? '',
          source: 'Crossref',
          abstractText: crossref.abstractText,
        );
        best = best == null ? next : _preferRicher(best, next);
      }
    } catch (_) {}
    if ((best?.abstractText.trim().length ?? 0) < 120) {
      try {
        final epmc = await EuropePmcClient.instance.abstractForDoi(key);
        if (epmc.trim().length >= 40 && best != null) {
          best = GroundedWork(
            title: best.title,
            doi: best.doi,
            year: best.year,
            authors: best.authors,
            source: 'Europe PMC',
            journal: best.journal,
            abstractText: epmc.trim(),
          );
        }
      } catch (_) {}
    }
    return best;
  }

  GroundedWork _preferRicher(GroundedWork a, GroundedWork b) {
    return GroundedWork(
      title: a.title.trim().length >= b.title.trim().length ? a.title : b.title,
      doi: a.doi,
      year: a.year ?? b.year,
      authors: a.authors.trim().isNotEmpty ? a.authors : b.authors,
      source: a.abstractText.trim().isNotEmpty ? a.source : b.source,
      journal: (a.journal ?? '').trim().isNotEmpty ? a.journal : b.journal,
      abstractText: a.abstractText.trim().isNotEmpty
          ? a.abstractText
          : b.abstractText,
    );
  }

  /// Resolve pasted DOIs / bibliography lines into confirmed works with abstracts.
  Future<List<GroundedWork>> resolveBibliography(
    String raw, {
    int limit = 40,
  }) async {
    final dois = extractDois(raw);
    if (dois.isEmpty) return const [];
    final out = <GroundedWork>[];
    final seen = <String>{};
    for (final doi in dois) {
      if (out.length >= limit) break;
      final key = normalizeDoi(doi);
      if (!seen.add(key)) continue;
      final work = await _lookup(key);
      if (work != null) out.add(work);
    }
    return out;
  }

  /// Re-lookup DOIs to fill missing/short abstracts (OpenAlex / S2 / Crossref / Europe PMC).
  Future<List<GroundedWork>> enrichAbstracts(
    List<GroundedWork> works, {
    void Function(String label)? onProgress,
    bool arabic = false,
    bool forceRefreshShort = true,
  }) async {
    final out = <GroundedWork>[];
    for (var i = 0; i < works.length; i++) {
      final work = works[i];
      onProgress?.call(
        arabic
            ? 'جلب Abstract من الفهارس ${i + 1}/${works.length}...'
            : 'Fetching Abstract from indexes ${i + 1}/${works.length}...',
      );
      final have = work.abstractText.trim();
      final needLookup = work.doi.trim().isNotEmpty &&
          (have.length < 120 || (forceRefreshShort && have.length < 400));
      if (!needLookup) {
        out.add(work);
        continue;
      }
      final looked = await _lookup(work.doi);
      if (looked == null) {
        out.add(work);
        continue;
      }
      // Prefer longer abstract text even if we already had a short stub.
      final merged = _preferRicher(work, looked);
      final preferLookedAbs = looked.abstractText.trim().length >
          work.abstractText.trim().length;
      out.add(
        preferLookedAbs
            ? GroundedWork(
                title: merged.title,
                doi: merged.doi,
                year: merged.year,
                authors: merged.authors,
                source: looked.abstractText.trim().isNotEmpty
                    ? looked.source
                    : merged.source,
                journal: merged.journal,
                abstractText: looked.abstractText.trim().isNotEmpty
                    ? looked.abstractText
                    : merged.abstractText,
              )
            : merged,
      );
    }
    return out;
  }
}
