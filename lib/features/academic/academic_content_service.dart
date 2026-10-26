import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'academic_models.dart';
import 'demo_supervisor_hide_service.dart';
import '../analytics/kpi_analytics_service.dart';
import '../home/home_search_utils.dart';
import '../lab_import/nbsle_university_cities.dart';

class AcademicContentService {
  AcademicContentService._();

  static final AcademicContentService instance = AcademicContentService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Stream<AcademicContent>? _cachedWatchCore;
  Stream<List<AcademicResearchIdea>>? _ideasBroadcast;
  List<AcademicLab> _cachedLabs = const [];
  int _readsInFlight = 0;
  final List<Completer<void>> _readWaiters = [];
  Future<List<AcademicSupervisor>>? _supervisorsOnceInFlight;
  Future<List<AcademicResearchIdea>>? _ideasOnceInFlight;
  Future<List<AcademicLab>>? _crciInFlight;
  Future<AcademicContent>? _fetchAllInFlight;
  DateTime? _fetchAllCachedAt;
  AcademicContent? _fetchAllCached;
  static const _fetchAllTtl = Duration(minutes: 3);

  /// Last labs from a browse/search call (capped). Never the full NBSLE dump.
  List<AcademicLab> get cachedLabs => _cachedLabs;

  /// Home opens supervisors, ideas, and labs together. On Windows those
  /// parallel Firestore reads stall and every one hits the timeout.
  Future<T> _withReadSlot<T>(Future<T> Function() action) async {
    if (_readsInFlight >= 2) {
      final waiter = Completer<void>();
      _readWaiters.add(waiter);
      await waiter.future;
    }
    _readsInFlight++;
    try {
      return await action();
    } finally {
      _readsInFlight--;
      if (_readWaiters.isNotEmpty) {
        _readWaiters.removeAt(0).complete();
      }
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _serverGet(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      return query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 25));
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _readQuery(
    Query<Map<String, dynamic>> query,
  ) {
    return _withReadSlot(() async {
      try {
        final cached = await query
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 2));
        if (cached.docs.isNotEmpty) {
          unawaited(() async {
            try {
              await _withReadSlot(() => _serverGet(query));
            } catch (_) {}
          }());
          return cached;
        }
      } catch (_) {}
      return _serverGet(query);
    });
  }

  List<AcademicSupervisor> _applyHiddenDemos(
    List<AcademicSupervisor> supervisors,
    Set<String> hiddenIds,
  ) {
    return DemoSupervisorHideService.instance.filterVisible(supervisors, hiddenIds);
  }

  List<AcademicSupervisor> _parseSupervisors(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    String? category,
    bool includePending = false,
  }) {
    if (snapshot.docs.isEmpty) return const [];

    return snapshot.docs
        .map((doc) => AcademicSupervisor.fromMap(doc.data(), id: doc.id))
        .where((item) => item.name.trim().isNotEmpty)
        .where((item) => includePending || item.isPubliclyVisible)
        .where((item) => !item.isDemo)
        .where((item) => category == null || item.category == category)
        .toList();
  }

  List<AcademicResearchIdea> _parseIdeas(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) return const [];

    return snapshot.docs
        .map((doc) => AcademicResearchIdea.fromMap(doc.data(), id: doc.id))
        .where((item) => item.title.trim().isNotEmpty)
        .where((item) => item.isPubliclyVisible)
        .toList();
  }

  List<AcademicLab> _parseLabs(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    bool lightweight = true,
  }) {
    if (snapshot.docs.isEmpty) return const [];

    return snapshot.docs
        .map(
          (doc) => AcademicLab.fromMap(
            doc.data(),
            id: doc.id,
            lightweight: lightweight,
          ),
        )
        .where((item) => item.name.trim().isNotEmpty)
        .where((item) => item.isPubliclyVisible)
        .toList();
  }

  /// Full lab document (equipment + sample services) for detail/booking.
  Future<AcademicLab?> fetchLabById(String labId) async {
    if (labId.isEmpty) return null;
    final snap = await _db.collection('labs').doc(labId).get();
    if (!snap.exists) return null;
    return AcademicLab.fromMap(
      snap.data() ?? {},
      id: snap.id,
      lightweight: false,
    );
  }

  Future<AcademicSupervisor?> fetchSupervisorById(String supervisorId) async {
    if (supervisorId.isEmpty) return null;
    final snap = await _db.collection('supervisors').doc(supervisorId).get();
    if (!snap.exists) return null;
    return AcademicSupervisor.fromMap(snap.data() ?? {}, id: snap.id);
  }

  /// Text match against specialty, tags, faculty, bio. New supervisors appear
  /// as soon as they are stored in Firestore.
  Future<List<AcademicSupervisor>> searchSupervisors({
    String query = '',
    int limit = 40,
  }) async {
    final q = query.trim();
    final pool = await _fetchSupervisorsOnce(limit: 250);
    if (q.length < 2) {
      return pool.take(limit).toList();
    }
    final matches = pool.where((s) {
      return homeSearchMatches(q, [
        s.name,
        s.speciality,
        s.faculty,
        s.category,
        s.university,
        s.bio,
        ...s.tags,
      ]);
    }).toList();
    if (matches.length > limit) {
      final out = matches.take(limit).toList();
      // ignore: unawaited_futures
      KpiAnalyticsService.instance.logSearch(
        kind: 'supervisors',
        query: q,
        resultCount: out.length,
      );
      return out;
    }
    // ignore: unawaited_futures
    KpiAnalyticsService.instance.logSearch(
      kind: 'supervisors',
      query: q,
      resultCount: matches.length,
    );
    return matches;
  }

  Stream<List<AcademicSupervisor>> supervisorsStream({
    String? category,
    bool includePending = false,
  }) {
    final controller = StreamController<List<AcademicSupervisor>>.broadcast();
    Set<String> hiddenIds = {};
    List<AcademicSupervisor> latest = const [];
    StreamSubscription<Set<String>>? hiddenSub;
    StreamSubscription<List<AcademicSupervisor>>? supervisorsSub;

    void emit() {
      if (controller.isClosed) return;
      controller.add(_applyHiddenDemos(latest, hiddenIds));
    }

    controller.onListen = () {
      emit();

      hiddenSub = DemoSupervisorHideService.instance.watchHiddenIds().listen(
        (ids) {
          hiddenIds = ids;
          emit();
        },
        onError: (_) {},
      );

      supervisorsSub = _rawSupervisorsStream(
        category: category,
        includePending: includePending,
      ).listen(
        (data) {
          latest = data;
          emit();
        },
        onError: (_) {
          latest = const [];
          emit();
        },
      );
    };

    controller.onCancel = () async {
      await hiddenSub?.cancel();
      await supervisorsSub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<AcademicSupervisor>> _rawSupervisorsStream({
    String? category,
    bool includePending = false,
  }) async* {
    Query<Map<String, dynamic>> query = _db.collection('supervisors');
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    // Cap home/search listeners — high enough for search, still bounded.
    if (category == null) {
      query = query.limit(200);
    }

    try {
      final first = await _fetchSupervisorsOnce(
        category: category,
        limit: category == null ? 200 : 250,
      );
      yield first;
      await for (final snapshot in query.snapshots()) {
        yield _parseSupervisors(
          snapshot,
          category: category,
          includePending: includePending,
        );
      }
    } catch (error) {
      debugPrint('supervisorsStream error: $error');
      yield const [];
    }
  }

  Future<List<AcademicSupervisor>> _fetchSupervisorsOnce({
    String? category,
    int limit = 250,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection('supervisors');
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    query = query.limit(limit);

    if (category == null && _supervisorsOnceInFlight != null) {
      return _supervisorsOnceInFlight!;
    }
    final run = _loadSupervisorsOnce(query, category);
    if (category != null) return run;
    _supervisorsOnceInFlight = run.whenComplete(() {
      _supervisorsOnceInFlight = null;
    });
    return _supervisorsOnceInFlight!;
  }

  Future<List<AcademicSupervisor>> _loadSupervisorsOnce(
    Query<Map<String, dynamic>> query,
    String? category,
  ) async {
    try {
      final snapshot = await _readQuery(query);
      final hiddenIds = await DemoSupervisorHideService.instance.loadHiddenIds();
      return _applyHiddenDemos(
        _parseSupervisors(snapshot, category: category),
        hiddenIds,
      );
    } catch (error) {
      debugPrint('supervisors once error: $error');
      return const [];
    }
  }

  Future<List<AcademicResearchIdea>> _fetchIdeasOnce({int limit = 200}) async {
    if (_ideasOnceInFlight != null) return _ideasOnceInFlight!;
    final run = () async {
      try {
        final snapshot = await _readQuery(
          _db.collection('research_ideas').limit(limit),
        );
        return _parseIdeas(snapshot);
      } catch (error) {
        debugPrint('ideas once error: $error');
        return const <AcademicResearchIdea>[];
      }
    }();
    _ideasOnceInFlight = run.whenComplete(() {
      _ideasOnceInFlight = null;
    });
    return _ideasOnceInFlight!;
  }

  Stream<List<AcademicResearchIdea>> researchIdeasStream() {
    return _ideasBroadcast ??= _createIdeasBroadcast();
  }

  Stream<List<AcademicResearchIdea>> _createIdeasBroadcast() {
    late StreamController<List<AcademicResearchIdea>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller = StreamController<List<AcademicResearchIdea>>.broadcast(
      onListen: () {
        if (sub != null) return;

        // Unblock StreamBuilders immediately (snapshots often hang on web).
        controller.add(const []);

        // One read first. A live listener on the same collection at the same
        // moment is what makes the Windows client stall.
        () async {
          final once = await _fetchIdeasOnce();
          if (controller.isClosed) return;
          if (once.isNotEmpty) controller.add(once);
          if (sub != null || controller.isClosed) return;
          sub = _db.collection('research_ideas').limit(200).snapshots().listen(
            (snapshot) {
              if (!controller.isClosed) {
                controller.add(_parseIdeas(snapshot));
              }
            },
            onError: (Object error) {
              debugPrint('researchIdeasStream error: $error');
              if (!controller.isClosed) {
                controller.add(const []);
              }
            },
          );
        }();
      },
      onCancel: () async {
        if (controller.hasListener) return;
        await sub?.cancel();
        sub = null;
        _ideasBroadcast = null;
      },
    );
    return controller.stream;
  }

  /// Filtered labs browse. Prefer [searchLabs] for faculty/city/university.
  Stream<List<AcademicLab>> labsStream({
    String? facultyId,
    String? city,
    String? university,
    int limit = 80,
  }) {
    final faculty = facultyId?.trim();
    final cityFilter = city?.trim();
    final uni = university?.trim();
    final hasFilter = (faculty != null && faculty.isNotEmpty && faculty != 'All') ||
        (cityFilter != null && cityFilter.isNotEmpty) ||
        (uni != null && uni.isNotEmpty);
    if (hasFilter) {
      // Paginated one-shot — avoids the old "first 80 nationwide then filter" bug.
      return Stream.fromFuture(
        searchLabs(
          facultyId: faculty,
          city: cityFilter,
          university: uni,
          limit: limit < 200 ? 500 : limit.clamp(1, 800),
        ),
      );
    }
    return _createLabsBrowseStream(
      facultyId: facultyId,
      city: city,
      limit: limit.clamp(1, 150),
    );
  }

  Stream<List<AcademicLab>> _createLabsBrowseStream({
    String? facultyId,
    String? city,
    required int limit,
  }) {
    final cityValues = (city == null || city.trim().isEmpty)
        ? const <String>[]
        : NbsleUniversityCities.cityQueryValues(city);

    if (cityValues.isNotEmpty) {
      return Stream.fromFuture(
        searchLabs(city: city, limit: limit.clamp(80, 500)),
      );
    }

    final controller = StreamController<List<AcademicLab>>.broadcast();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller.onListen = () {
      if (sub != null) return;

      Query<Map<String, dynamic>> query = _db.collection('labs').limit(limit);
      final faculty = facultyId?.trim();
      if (faculty != null && faculty.isNotEmpty && faculty != 'All') {
        query = _db
            .collection('labs')
            .where('facultyId', isEqualTo: faculty)
            .limit(limit);
      }

      sub = query.snapshots().listen(
        (snapshot) {
          final labs = _parseLabs(snapshot, lightweight: true);
          _cachedLabs = labs;
          if (!controller.isClosed) controller.add(labs);
        },
        onError: (Object error) async {
          debugPrint('labsStream error: $error');
          if (!controller.isClosed) controller.add(const []);
        },
      );
    };

    controller.onCancel = () async {
      await sub?.cancel();
      sub = null;
    };

    return controller.stream;
  }

  Future<List<AcademicLab>> _paginateLabsQuery(
    Query<Map<String, dynamic>> baseQuery, {
    required int maxTotal,
    int pageSize = 100,
  }) async {
    final collected = <AcademicLab>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    final size = pageSize.clamp(20, 100);

    while (collected.length < maxTotal) {
      var page = baseQuery.limit(size);
      if (cursor != null) {
        page = page.startAfterDocument(cursor);
      }
      final snap = await _readQuery(page);
      if (snap.docs.isEmpty) break;
      collected.addAll(_parseLabs(snap, lightweight: true));
      cursor = snap.docs.last;
      if (snap.docs.length < size) break;
    }

    if (collected.length > maxTotal) {
      return collected.take(maxTotal).toList();
    }
    return collected;
  }

  Future<List<AcademicLab>> _searchLabsByCityAliases(
    List<String> cityValues, {
    required int limit,
    String? facultyId,
    String? university,
    String query = '',
  }) async {
    final perCity = (limit / cityValues.length).ceil().clamp(50, limit);
    final chunks = await Future.wait(
      cityValues.map((c) async {
        try {
          return await _paginateLabsQuery(
            _db.collection('labs').where('city', isEqualTo: c),
            maxTotal: perCity,
          );
        } catch (e) {
          debugPrint('city alias query ($c) error: $e');
          return const <AcademicLab>[];
        }
      }),
    );
    final byId = <String, AcademicLab>{};
    for (final list in chunks) {
      for (final lab in list) {
        byId[lab.id ?? '${lab.name}|${lab.university}'] = lab;
      }
    }
    return _applyClientLabFilters(
      byId.values.toList(),
      facultyId: facultyId,
      cityValues: cityValues,
      university: university,
      query: query,
      limit: limit,
    );
  }

  List<AcademicLab> _applyClientLabFilters(
    List<AcademicLab> labs, {
    String? facultyId,
    List<String> cityValues = const [],
    String? university,
    String query = '',
    required int limit,
  }) {
    var result = labs;
    final faculty = facultyId?.trim();
    if (faculty != null && faculty.isNotEmpty && faculty != 'All') {
      result = result.where((lab) => lab.matchesFaculty(faculty)).toList();
    }
    if (cityValues.isNotEmpty) {
      result = result
          .where((lab) => cityValues.contains(lab.city.trim()))
          .toList();
    }
    final uni = university?.trim();
    if (uni != null && uni.isNotEmpty) {
      result = result
          .where(
            (lab) => NbsleUniversityCities.universityMatches(lab.university, uni),
          )
          .toList();
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      result = result.where((lab) => _labMatchesQuery(lab, q)).toList();
    }
    if (result.length > limit) result = result.take(limit).toList();
    _cachedLabs = result;
    return result;
  }

  bool _labMatchesQuery(AcademicLab lab, String query) {
    return homeSearchMatches(query, [
      lab.name,
      lab.location,
      lab.university,
      lab.city,
      lab.equipment,
      lab.description,
      lab.facultyId,
      lab.facultyNameAr,
      lab.displayFacultyName,
      lab.labType,
      lab.contactName,
      lab.contactEmail,
      lab.nbsleLabId,
      lab.importSource,
      ...lab.tags,
      ...lab.equipmentNameHints,
      ...lab.equipmentList.map((e) => e.name),
      ...lab.sampleServices.map((s) => s.name),
    ]);
  }

  /// Text search across labs: page through Firestore and keep matches until
  /// [resultLimit] or [scanCap] documents scanned (avoids "first 80 only").
  Future<List<AcademicLab>> _searchLabsByTextQuery(
    String query, {
    required int resultLimit,
    int scanCap = 2500,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final matches = <AcademicLab>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    var scanned = 0;
    const pageSize = 100;

    while (matches.length < resultLimit && scanned < scanCap) {
      var page = _db.collection('labs').limit(pageSize);
      if (cursor != null) {
        page = page.startAfterDocument(cursor);
      }
      final snap = await _readQuery(page);
      if (snap.docs.isEmpty) break;

      scanned += snap.docs.length;
      final labs = _parseLabs(snap, lightweight: true);
      for (final lab in labs) {
        if (_labMatchesQuery(lab, q)) {
          matches.add(lab);
          if (matches.length >= resultLimit) break;
        }
      }

      cursor = snap.docs.last;
      if (snap.docs.length < pageSize) break;
    }

    debugPrint(
      'lab text search: query="$q" matches=${matches.length} scanned=$scanned',
    );
    return matches;
  }

  Future<List<AcademicLab>> fetchCrciCenters({int limit = 40}) {
    if (_crciInFlight != null) return _crciInFlight!;
    final run = _loadCrciCenters(limit);
    _crciInFlight = run.whenComplete(() {
      _crciInFlight = null;
    });
    return _crciInFlight!;
  }

  Future<List<AcademicLab>> _loadCrciCenters(int limit) async {
    try {
      final snap = await _readQuery(
        _db.collection('labs').where('importSource', isEqualTo: 'crci').limit(limit),
      );
      return _parseLabs(snap, lightweight: true);
    } catch (e) {
      debugPrint('fetchCrciCenters error: $e');
      try {
        final snap = await _readQuery(
          _db.collection('labs').where('crciCenterId', isNotEqualTo: '').limit(limit),
        );
        return _parseLabs(snap, lightweight: true)
            .where((l) => l.importSource == 'crci' || l.tags.contains('CRCI'))
            .toList();
      } catch (e2) {
        debugPrint('fetchCrciCenters fallback error: $e2');
        return const [];
      }
    }
  }

  List<AcademicLab> _mergeCrciFirst(
    List<AcademicLab> primary,
    List<AcademicLab> crci,
  ) {
    final byId = <String, AcademicLab>{};
    for (final lab in [...crci, ...primary]) {
      byId[lab.id ?? '${lab.name}|${lab.university}'] = lab;
    }
    // Keep CRCI centers at the top.
    final crciIds = crci.map((l) => l.id ?? l.name).toSet();
    final merged = byId.values.toList();
    merged.sort((a, b) {
      final aCrci = a.importSource == 'crci' || crciIds.contains(a.id ?? a.name);
      final bCrci = b.importSource == 'crci' || crciIds.contains(b.id ?? b.name);
      if (aCrci && !bCrci) return -1;
      if (!aCrci && bCrci) return 1;
      return a.name.compareTo(b.name);
    });
    return merged;
  }

  /// Paginated lab search. When faculty/city/university is set, pages until
  /// results are exhausted (up to [limit], default raised for filters).
  Future<List<AcademicLab>> searchLabs({
    String query = '',
    String? facultyId,
    String? city,
    String? university,
    int limit = 40,
  }) async {
    final q = query.trim();
    final faculty = facultyId?.trim();
    final cityFilter = city?.trim();
    final uni = university?.trim();
    final cityValues = (cityFilter == null || cityFilter.isEmpty)
        ? const <String>[]
        : NbsleUniversityCities.cityQueryValues(cityFilter);

    final wantsCrciOnly = uni != null &&
        (uni.contains('CRCI') ||
            uni.contains('المراكز والمعاهد') ||
            uni.contains('مجلس المراكز'));

    if (wantsCrciOnly) {
      var crci = await fetchCrciCenters();
      return _applyClientLabFilters(
        crci,
        facultyId: faculty,
        cityValues: cityValues,
        university: uni,
        query: q,
        limit: limit.clamp(11, 80),
      );
    }

    final hasScope = (faculty != null && faculty.isNotEmpty && faculty != 'All') ||
        cityValues.isNotEmpty ||
        (uni != null && uni.isNotEmpty) ||
        q.length >= 2;
    // Text-only home search needs a higher result cap; browse stays small.
    final maxTotal = q.length >= 2 &&
            cityValues.isEmpty &&
            (faculty == null || faculty.isEmpty || faculty == 'All') &&
            (uni == null || uni.isEmpty)
        ? limit.clamp(40, 120)
        : (hasScope ? limit.clamp(80, 800) : limit.clamp(1, 80));

    // Always pull the small CRCI set so national centers are not buried
    // under thousands of NBSLE university labs.
    final crciFuture = fetchCrciCenters();

    try {
      List<AcademicLab> labs;
      // Prefer city scope when present so faculty+city is not "80 Science labs
      // from all Egypt then drop other cities".
      if (cityValues.isNotEmpty) {
        labs = await _searchLabsByCityAliases(
          cityValues,
          limit: maxTotal,
          facultyId: faculty,
          university: uni,
          query: q,
        );
      } else if (faculty != null && faculty.isNotEmpty && faculty != 'All') {
        labs = await _paginateLabsQuery(
          _db.collection('labs').where('facultyId', isEqualTo: faculty),
          maxTotal: maxTotal,
        );
        labs = _applyClientLabFilters(
          labs,
          facultyId: faculty,
          university: uni,
          query: q,
          limit: maxTotal,
        );
      } else if (uni != null && uni.isNotEmpty) {
        // University filter: scan more docs then match client-side.
        labs = await _paginateLabsQuery(
          _db.collection('labs'),
          maxTotal: maxTotal.clamp(200, 800),
        );
        labs = _applyClientLabFilters(
          labs,
          university: uni,
          query: q,
          limit: maxTotal,
        );
      } else if (q.length >= 2) {
        // Home/global text search: page until matches found (not first N docs).
        labs = await _searchLabsByTextQuery(
          q,
          resultLimit: maxTotal,
          scanCap: 2500,
        );
      } else {
        labs = await _paginateLabsQuery(
          _db.collection('labs'),
          maxTotal: maxTotal,
        );
        _cachedLabs = labs;
      }

      final crci = await crciFuture;
      final filteredCrci = _applyClientLabFilters(
        crci,
        facultyId: faculty,
        cityValues: cityValues,
        university: uni,
        query: q,
        limit: 40,
      );
      final merged = _mergeCrciFirst(labs, filteredCrci);
      if (merged.length > maxTotal + filteredCrci.length) {
        // Keep all matched CRCI + capped NBSLE slice.
        final crciPart =
            merged.where((l) => l.importSource == 'crci').toList();
        final rest = merged
            .where((l) => l.importSource != 'crci')
            .take(maxTotal)
            .toList();
        _cachedLabs = [...crciPart, ...rest];
        return _cachedLabs;
      }
      _cachedLabs = merged;
      // ignore: unawaited_futures
      KpiAnalyticsService.instance.logSearch(
        kind: 'labs',
        query: q,
        resultCount: merged.length,
      );
      return merged;
    } catch (error) {
      debugPrint('searchLabs error: $error');
      final crci = await crciFuture;
      if (crci.isNotEmpty) return crci;
      return _cachedLabs;
    }
  }

  /// Supervisors + ideas only — safe for home search (no labs dump).
  Stream<AcademicContent> watchCore() {
    return _cachedWatchCore ??= _createWatchCoreStream();
  }

  /// @Deprecated Prefer [watchCore]; labs are no longer included.
  Stream<AcademicContent> watchAll() => watchCore();

  Stream<AcademicContent> _createWatchCoreStream() {
    final controller = StreamController<AcademicContent>.broadcast();
    var supervisors = const <AcademicSupervisor>[];
    var ideas = const <AcademicResearchIdea>[];
    final subscriptions = <StreamSubscription<dynamic>>[];

    void emit() {
      if (controller.isClosed) return;
      controller.add(
        AcademicContent(
          supervisors: supervisors,
          ideas: ideas,
          labs: _cachedLabs,
        ),
      );
    }

    controller.onListen = () {
      emit();

      subscriptions.add(
        supervisorsStream().listen(
          (data) {
            supervisors = data;
            emit();
          },
          onError: (_) {
            supervisors = const [];
            emit();
          },
        ),
      );

      subscriptions.add(
        researchIdeasStream().listen(
          (data) {
            ideas = data;
            emit();
          },
          onError: (_) {
            ideas = const [];
            emit();
          },
        ),
      );
    };

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      subscriptions.clear();
    };

    return controller.stream;
  }

  /// Deduped content fetch. Labs are capped / optional.
  Future<AcademicContent> fetchAll({bool includeLabs = false}) async {
    final now = DateTime.now();
    if (_fetchAllCached != null &&
        _fetchAllCachedAt != null &&
        now.difference(_fetchAllCachedAt!) < _fetchAllTtl &&
        (!includeLabs || _fetchAllCached!.labs.isNotEmpty || _cachedLabs.isNotEmpty)) {
      final cached = _fetchAllCached!;
      if (includeLabs && cached.labs.isEmpty && _cachedLabs.isNotEmpty) {
        return AcademicContent(
          supervisors: cached.supervisors,
          ideas: cached.ideas,
          labs: _cachedLabs,
        );
      }
      return cached;
    }

    if (_fetchAllInFlight != null) {
      final shared = await _fetchAllInFlight!;
      if (!includeLabs) return shared;
      if (shared.labs.isNotEmpty) return shared;
    }

    _fetchAllInFlight = _fetchAllImpl(includeLabs: includeLabs);
    try {
      final result = await _fetchAllInFlight!;
      _fetchAllCached = result;
      _fetchAllCachedAt = DateTime.now();
      return result;
    } finally {
      _fetchAllInFlight = null;
    }
  }

  Future<AcademicContent> _fetchAllImpl({required bool includeLabs}) async {
    final supervisors = await _fetchSupervisorsOnce();
    final ideas = await _fetchIdeasOnce();
    final labs = includeLabs ? await searchLabs(limit: 80) : const <AcademicLab>[];

    return AcademicContent(
      supervisors: supervisors,
      ideas: ideas,
      labs: labs,
    );
  }
}
