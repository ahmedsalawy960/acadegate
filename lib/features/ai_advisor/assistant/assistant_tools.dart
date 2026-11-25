import '../../../core/locale/app_translate.dart';
import '../../academic_integrity/consensus_client.dart';
import '../../academic_integrity/europe_pmc_client.dart';
import '../../academic_integrity/unpaywall_client.dart';
import '../../acadegate_publish/manuscript_draft_chat_service.dart';
import '../../acadegate_publish/publish_services.dart';
import '../../research_journey/research_file.dart';
import '../../store/import/store_product_search_service.dart';
import '../catalog_hit.dart';
import '../catalog_search_service.dart';
import '../grounded_reference_service.dart';
import '../grounded_work.dart';

/// Gemini function declarations + their execution against app data.
///
/// One instance per user turn: it accumulates what the tools found so the
/// final answer can be checked (DOIs) and decorated (lab/supervisor cards).
class AssistantToolbox {
  /// Injectable for tests; defaults to the live evidence-answer index.
  final Future<List<ConsensusPaper>> Function(String query, {int? limit})
      _consensusSearch;

  /// Injectable for tests; defaults to the open-access full-text index.
  final Future<String> Function(String doi) _fullTextForDoi;

  /// Injectable for tests; defaults to the open-access location index.
  final Future<OaLocation> Function(String doi) _oaLocationForDoi;

  AssistantToolbox({
    Future<List<ConsensusPaper>> Function(String query, {int? limit})?
        consensusSearch,
    Future<String> Function(String doi)? fullTextForDoi,
    Future<OaLocation> Function(String doi)? oaLocationForDoi,
  })  : _consensusSearch = consensusSearch ??
            ((query, {limit}) =>
                ConsensusClient.instance.search(query, limit: limit ?? 8)),
        _fullTextForDoi =
            fullTextForDoi ?? EuropePmcClient.instance.fullTextForDoi,
        _oaLocationForDoi =
            oaLocationForDoi ?? UnpaywallClient.instance.bestLocationForDoi;

  final List<GroundedWork> _works = [];
  final List<CatalogHit> _labs = [];
  final List<CatalogHit> _supervisors = [];
  final List<String> _usedLabels = [];
  String _lastCity = '';
  String _lastEquipment = '';
  String _lastSpecialty = '';

  static const _maxAbstract = 500;

  static List<Map<String, dynamic>> get declarations => [
        {
          'name': 'search_scientific_literature',
          'description':
              'Search real scholarly works (OpenAlex, Crossref, Semantic Scholar). '
                  'Use for references, literature reviews, research gaps, or evidence. '
                  'Returns verified citations with DOI and abstract.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Precise English search query (key concepts, no filler words).',
              },
              'limit': {
                'type': 'integer',
                'description': 'Max results, 3-12. Default 8.',
              },
            },
            'required': ['query'],
          },
        },
        {
          'name': 'check_research_evidence',
          'description':
              'Check what published research concludes about a specific effect or yes/no question '
                  '(e.g. "does X improve Y"). Returns short evidence statements with citations. '
                  'Use for evidence-direction questions; if it returns nothing, answer from verified literature.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Precise English research question.',
              },
              'limit': {
                'type': 'integer',
                'description': 'Max results, 3-12. Default 8.',
              },
            },
            'required': ['query'],
          },
        },
        {
          'name': 'read_paper_text',
          'description':
              'Read the open-access full text of one paper by DOI (methods, results, details beyond the abstract). '
                  'Use when the user asks about a specific paper in depth. Not every paper has a free full text; '
                  'if unavailable you get an open-access link or a note instead.',
          'parameters': {
            'type': 'object',
            'properties': {
              'doi': {
                'type': 'string',
                'description': 'The paper DOI, e.g. "10.1000/xyz123".',
              },
              'max_chars': {
                'type': 'integer',
                'description': 'Max characters to return, 1000-12000. Default 6000.',
              },
            },
            'required': ['doi'],
          },
        },
        {
          'name': 'verify_references',
          'description':
              'Check DOIs in a reference list against OpenAlex/Crossref and return which exist.',
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {'type': 'string', 'description': 'Reference list text containing DOIs.'},
            },
            'required': ['text'],
          },
        },
        {
          'name': 'search_labs_and_equipment',
          'description':
              'Find labs registered on the platform that have a device or offer an analysis '
                  '(e.g. HPLC, SEM, XRD, PCR), optionally in a city/governorate in Egypt.',
          'parameters': {
            'type': 'object',
            'properties': {
              'equipment': {
                'type': 'string',
                'description': 'Device or analysis name, e.g. "HPLC" or "XRD".',
              },
              'city': {
                'type': 'string',
                'description': 'City or governorate in Arabic or English. Empty for anywhere.',
              },
            },
            'required': ['equipment'],
          },
        },
        {
          'name': 'find_supervisors',
          'description':
              'Find real professors/supervisors on the platform matching a specialty or research topic.',
          'parameters': {
            'type': 'object',
            'properties': {
              'specialty': {
                'type': 'string',
                'description': 'Specialty or topic, Arabic or English, e.g. "كيمياء تحليلية".',
              },
            },
            'required': ['specialty'],
          },
        },
        {
          'name': 'read_my_research_file',
          'description':
              "Read the researcher's thesis file: title, aim, questions, and chapter titles. "
                  'Use when they ask about their thesis plan and the system prompt has no thesis file.',
        },
        {
          'name': 'ask_my_draft',
          'description':
              "Search the researcher's latest uploaded manuscript draft and return matching passages, "
                  'tables, or figures with their location.',
          'parameters': {
            'type': 'object',
            'properties': {
              'question': {'type': 'string', 'description': 'What to look for in the draft.'},
            },
            'required': ['question'],
          },
        },
        {
          'name': 'search_store_products',
          'description':
              'Search products (chemicals, lab supplies, tools) available for purchase in the platform store.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Product name, Arabic or English.'},
            },
            'required': ['query'],
          },
        },
      ];

  static String statusLabel(String toolName) => switch (toolName) {
        'search_scientific_literature' => appTr('يبحث في المراجع العلمية…', 'Searching scholarly literature…'),
        'check_research_evidence' => appTr('يفحص الأدلة البحثية…', 'Checking research evidence…'),
        'read_paper_text' => appTr('يقرأ نص الورقة…', 'Reading the paper text…'),
        'verify_references' => appTr('يتحقق من المراجع…', 'Verifying references…'),
        'search_labs_and_equipment' => appTr('يبحث في المختبرات والأجهزة…', 'Searching labs and equipment…'),
        'find_supervisors' => appTr('يبحث عن مشرفين…', 'Finding supervisors…'),
        'read_my_research_file' => appTr('يقرأ ملف الرسالة…', 'Reading the thesis file…'),
        'ask_my_draft' => appTr('يقرأ مسودتك…', 'Reading your draft…'),
        'search_store_products' => appTr('يبحث في المتجر…', 'Searching the store…'),
        _ => appTr('يعمل…', 'Working…'),
      };

  static String _chipLabel(String toolName) => switch (toolName) {
        'search_scientific_literature' => appTr('مراجع موثّقة', 'Verified references'),
        'check_research_evidence' => appTr('أدلة بحثية', 'Research evidence'),
        'read_paper_text' => appTr('نص الورقة', 'Paper text'),
        'verify_references' => appTr('تحقق المراجع', 'Reference check'),
        'search_labs_and_equipment' => appTr('المختبرات', 'Labs'),
        'find_supervisors' => appTr('المشرفون', 'Supervisors'),
        'read_my_research_file' => appTr('ملف الرسالة', 'Thesis file'),
        'ask_my_draft' => appTr('مسودتك', 'Your draft'),
        'search_store_products' => appTr('المتجر', 'Store'),
        _ => toolName,
      };

  List<String> get usedLabels => List.unmodifiable(_usedLabels);

  GroundedReferenceBundle get foundReferences =>
      GroundedReferenceBundle(topic: '', works: List.unmodifiable(_works));

  CatalogSearchSnapshot get catalog => CatalogSearchSnapshot(
        intent: CatalogIntentSummary(
          wantsLabs: _labs.isNotEmpty,
          wantsSupervisors: _supervisors.isNotEmpty,
          city: _lastCity,
          equipmentQuery: _lastEquipment,
          supervisorQuery: _lastSpecialty,
        ),
        labs: List.unmodifiable(_labs),
        supervisors: List.unmodifiable(_supervisors),
      );

  /// Never throws: failures are reported to the model as `{error: ...}`.
  Future<Map<String, dynamic>> execute(String name, Map<String, dynamic> args) async {
    final label = _chipLabel(name);
    if (!_usedLabels.contains(label)) _usedLabels.add(label);
    try {
      return switch (name) {
        'search_scientific_literature' => await _literature(args),
        'check_research_evidence' => await _evidence(args),
        'read_paper_text' => await _paperText(args),
        'verify_references' => await _verify(args),
        'search_labs_and_equipment' => await _labsSearch(args),
        'find_supervisors' => await _supervisorsSearch(args),
        'read_my_research_file' => await _researchFile(),
        'ask_my_draft' => await _draft(args),
        'search_store_products' => await _store(args),
        _ => {'error': 'unknown tool $name'},
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static String _str(Map<String, dynamic> args, String key) => (args[key] ?? '').toString().trim();

  Future<Map<String, dynamic>> _literature(Map<String, dynamic> args) async {
    final query = _str(args, 'query');
    if (query.length < 3) return {'error': 'query too short'};
    final limit = (int.tryParse('${args['limit'] ?? ''}') ?? 8).clamp(3, 12);
    final bundle = await GroundedReferenceService.instance.searchTopic(
      query,
      limit: limit,
      byRelevance: true,
    );
    final known = {for (final w in _works) w.doi.toLowerCase()};
    for (final w in bundle.works) {
      if (w.doi.isEmpty || !known.contains(w.doi.toLowerCase())) _works.add(w);
    }
    if (bundle.isEmpty) {
      return {
        'results': <Object>[],
        'note': 'No indexed works found. Try a broader or differently worded English query; do not invent references.',
      };
    }
    return {
      'results': [
        for (final w in bundle.works)
          {
            'citation_apa': w.apaLine,
            if (w.doi.isNotEmpty) 'doi': w.doi,
            if (w.year != null) 'year': w.year,
            'source_index': w.source,
            if (w.citationCount != null) 'citation_count': w.citationCount,
            if (w.tldr.trim().isNotEmpty) 'tldr': w.tldr,
            if (w.abstractText.trim().isNotEmpty)
              'abstract': w.abstractText.length > _maxAbstract
                  ? '${w.abstractText.substring(0, _maxAbstract)}…'
                  : w.abstractText,
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _evidence(Map<String, dynamic> args) async {
    final query = _str(args, 'query');
    if (query.length < 3) return {'error': 'query too short'};
    final limit = (int.tryParse('${args['limit'] ?? ''}') ?? 8).clamp(3, 12);
    final papers = await _consensusSearch(query, limit: limit);
    if (papers.isEmpty) {
      return {
        'results': <Object>[],
        'note': 'No direct evidence statements available for this question. '
            'Answer from verified literature instead and say the evidence could not be checked directly.',
      };
    }
    final known = {for (final w in _works) w.mergeKey};
    final results = <Map<String, dynamic>>[];
    for (final p in papers) {
      final work = GroundedWork(
        title: p.title,
        source: 'Consensus',
        doi: p.doi,
        year: p.year,
        authors: p.authors,
        journal: p.journal.isEmpty ? null : p.journal,
        abstractText: p.groundedAbstract,
        externalUrl: p.url,
      );
      if (!known.contains(work.mergeKey)) {
        known.add(work.mergeKey);
        _works.add(work);
      }
      final abstract = p.abstractText.trim();
      final takeaway = p.takeaway.trim();
      results.add({
        'citation_apa': work.apaLine,
        if (work.hasDoi) 'doi': work.doi,
        if (p.year != null) 'year': p.year,
        if (takeaway.isNotEmpty) 'evidence': takeaway,
        if (abstract.isNotEmpty)
          'abstract': abstract.length > _maxAbstract
              ? '${abstract.substring(0, _maxAbstract)}…'
              : abstract,
      });
    }
    return {'results': results};
  }

  Future<Map<String, dynamic>> _paperText(Map<String, dynamic> args) async {
    final doi = _str(args, 'doi')
        .replaceAll(RegExp(r'^https?://(dx\.)?doi\.org/', caseSensitive: false), '');
    if (doi.length < 6) return {'error': 'doi too short'};
    final maxChars =
        (int.tryParse('${args['max_chars'] ?? ''}') ?? 6000).clamp(1000, 12000);
    final text = await _fullTextForDoi(doi);
    if (text.trim().isNotEmpty) {
      final trimmed = text.trim();
      return {
        'doi': doi,
        'full_text': trimmed.length > maxChars
            ? '${trimmed.substring(0, maxChars)}…'
            : trimmed,
        'truncated': trimmed.length > maxChars,
        'note': 'Open-access full text. Answer from it and cite the paper.',
      };
    }
    final oa = await _oaLocationForDoi(doi);
    if (oa.bestUrl.isNotEmpty) {
      return {
        'doi': doi,
        'open_access_url': oa.bestUrl,
        'note': 'No machine-readable full text, but a free open-access copy exists at this link. '
            'Answer from the abstract and verified literature, and share the link.',
      };
    }
    return {
      'doi': doi,
      'note': 'No open-access full text found for this DOI. '
          'Answer from the abstract and verified literature, and say the full text is not freely available.',
    };
  }

  Future<Map<String, dynamic>> _verify(Map<String, dynamic> args) async {
    final text = _str(args, 'text');
    if (text.isEmpty) return {'error': 'text is empty'};
    final report = await GroundedReferenceService.instance.verifyPastedBibliography(text);
    return {'report': report};
  }

  Map<String, dynamic> _hitJson(CatalogHit h) => {
        'name': h.title,
        if (h.subtitle.isNotEmpty) 'details': h.subtitle,
        if (h.matchedEquipmentName.isNotEmpty) 'matched_device': h.matchedEquipmentName,
        if (h.reason.isNotEmpty) 'why': h.reason,
        'bookable_in_app': h.canBook,
      };

  void _mergeHits(List<CatalogHit> into, List<CatalogHit> hits) {
    final ids = {for (final h in into) h.id};
    into.addAll(hits.where((h) => ids.add(h.id)));
  }

  Future<Map<String, dynamic>> _labsSearch(Map<String, dynamic> args) async {
    final equipment = _str(args, 'equipment');
    final city = _str(args, 'city');
    final snap = await CatalogSearchService.instance.searchStructured(
      equipment: equipment,
      city: city,
    );
    _lastEquipment = equipment;
    _lastCity = snap.intent.city;
    _mergeHits(_labs, snap.labs);
    return {
      'labs': snap.labs.map(_hitJson).toList(),
      if (snap.labs.isEmpty)
        'note': 'No matching lab on the platform yet. Say so; suggest widening the city or browsing labs.',
      'ui': 'Matching labs are shown to the user as cards with booking/contact buttons below your answer.',
    };
  }

  Future<Map<String, dynamic>> _supervisorsSearch(Map<String, dynamic> args) async {
    final specialty = _str(args, 'specialty');
    if (specialty.length < 3) return {'error': 'specialty too short'};
    final snap = await CatalogSearchService.instance.searchStructured(specialty: specialty);
    _lastSpecialty = specialty;
    _mergeHits(_supervisors, snap.supervisors);
    return {
      'supervisors': snap.supervisors.map(_hitJson).toList(),
      if (snap.supervisors.isEmpty) 'note': 'No matching supervisor on the platform. Do not invent names.',
      'ui': 'Matching supervisors are shown to the user as cards with a contact button below your answer.',
    };
  }

  Future<Map<String, dynamic>> _researchFile() async {
    final file = await ResearchFileService.instance.watchMine().first;
    if (file == null || !file.hasContent) {
      return {
        'available': false,
        'note': 'No thesis file yet. Ask for the title and aim, then continue.',
      };
    }
    return {
      'available': true,
      'title': file.title,
      'field': file.field,
      'aim': file.aim,
      'questions': file.questions,
      'chapters': file.chapters,
      if (file.supervisorName.isNotEmpty) 'supervisor': file.supervisorName,
    };
  }

  Future<Map<String, dynamic>> _draft(Map<String, dynamic> args) async {
    final question = _str(args, 'question');
    final draft = await ManuscriptService.instance.latestWithContent();
    if (draft == null) {
      return {
        'available': false,
        'note': 'The user has not uploaded a draft. Tell them to upload a PDF/Word file from Publish → Draft.',
      };
    }
    final reply = await ManuscriptDraftChatService.instance.ask(
      manuscript: draft,
      question: question.isEmpty ? 'summary' : question,
      allowCloud: false,
    );
    return {
      'available': true,
      'draft_title': draft.title,
      'findings': reply.text,
      'passages': [
        for (final h in reply.hits.take(8))
          {
            'title': h.title,
            'location': h.location,
            if (h.quote.isNotEmpty) 'quote': h.quote,
            if (h.tablePreview.isNotEmpty) 'table_preview': h.tablePreview.take(6).toList(),
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _store(Map<String, dynamic> args) async {
    final query = _str(args, 'query');
    if (query.length < 2) return {'error': 'query too short'};
    final result = await StoreProductSearchService.instance.search(query, localLimit: 10);
    final hits = result.local
        .where((h) => !h.isDirectoryListing && !h.fromRemoteSite)
        .take(8)
        .toList();
    return {
      'products': [
        for (final h in hits)
          {
            'name': h.name,
            if (h.price > 0) 'price_egp': h.price,
            if (h.storeName.isNotEmpty) 'store': h.storeName,
            if (h.category.isNotEmpty) 'category': h.category,
          },
      ],
      if (hits.isEmpty) 'note': 'Not available in the store now. Suggest an RFQ (request for quotation) in the store.',
    };
  }
}
