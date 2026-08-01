import 'dart:convert';



import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';



import '../../core/offline/local_profile_store.dart';

import '../profile/academic_profile_service.dart';

import 'thesis_progress_engine.dart';

import 'thesis_progress_templates.dart';



enum ThesisItemKind { chapter, approval, deadline }



class ThesisProgressItem {

  final String id;

  final String title;

  final ThesisItemKind kind;

  final bool done;

  final DateTime? dueDate;

  final String? activityId;

  final bool autoTracked;

  final bool isCustom;



  const ThesisProgressItem({

    required this.id,

    required this.title,

    required this.kind,

    this.done = false,

    this.dueDate,

    this.activityId,

    this.autoTracked = false,

    this.isCustom = false,

  });



  ThesisProgressItem copyWith({

    bool? done,

    DateTime? dueDate,

    bool? autoTracked,

  }) {

    return ThesisProgressItem(

      id: id,

      title: title,

      kind: kind,

      done: done ?? this.done,

      dueDate: dueDate ?? this.dueDate,

      activityId: activityId,

      autoTracked: autoTracked ?? this.autoTracked,

      isCustom: isCustom,

    );

  }



  Map<String, dynamic> toMap() => {

        'id': id,

        'title': title,

        'kind': kind.name,

        'done': done,

        'dueDate': dueDate?.toIso8601String(),

        if (activityId != null) 'activityId': activityId,

        'autoTracked': autoTracked,

        'isCustom': isCustom,

      };



  factory ThesisProgressItem.fromMap(Map<String, dynamic> map) {

    DateTime? due;

    final raw = map['dueDate']?.toString();

    if (raw != null && raw.isNotEmpty) {

      due = DateTime.tryParse(raw);

    }

    return ThesisProgressItem(

      id: map['id']?.toString() ?? '',

      title: map['title']?.toString() ?? '',

      kind: ThesisItemKind.values.firstWhere(

        (k) => k.name == map['kind'],

        orElse: () => ThesisItemKind.chapter,

      ),

      done: map['done'] == true,

      dueDate: due,

      activityId: map['activityId']?.toString(),

      autoTracked: map['autoTracked'] == true,

      isCustom: map['isCustom'] == true,

    );

  }

}



class ThesisProgress {

  final List<ThesisProgressItem> items;

  final String templateId;

  final Map<String, String> activityLog;



  const ThesisProgress({

    required this.items,

    this.templateId = ThesisProgressTemplates.masterStandard,

    this.activityLog = const {},

  });



  int get completedCount => items.where((i) => i.done).length;



  double get percent =>

      items.isEmpty ? 0 : (completedCount / items.length) * 100;



  Map<String, dynamic> toMap() => {

        'items': items.map((e) => e.toMap()).toList(),

        'templateId': templateId,

        'activityLog': activityLog,

        'updatedAt': DateTime.now().toIso8601String(),

      };



  factory ThesisProgress.fromMap(Map<String, dynamic> map) {

    final raw = map['items'];

    final items = raw is List

        ? raw

            .whereType<Map>()

            .map((e) => ThesisProgressItem.fromMap(

                  Map<String, dynamic>.from(e),

                ))

            .toList()

        : <ThesisProgressItem>[];



    final logRaw = map['activityLog'];

    final activityLog = <String, String>{};

    if (logRaw is Map) {

      logRaw.forEach((key, value) {

        activityLog[key.toString()] = value.toString();

      });

    }



    return ThesisProgress(

      items: items,

      templateId: map['templateId']?.toString() ??

          ThesisProgressTemplates.masterStandard,

      activityLog: activityLog,

    );

  }



  ThesisProgress copyWithItems(List<ThesisProgressItem> items) {

    return ThesisProgress(

      items: items,

      templateId: templateId,

      activityLog: activityLog,

    );

  }



  ThesisProgress copyWith({

    List<ThesisProgressItem>? items,

    String? templateId,

    Map<String, String>? activityLog,

  }) {

    return ThesisProgress(

      items: items ?? this.items,

      templateId: templateId ?? this.templateId,

      activityLog: activityLog ?? this.activityLog,

    );

  }

}



class ThesisProgressService {

  ThesisProgressService._();



  static final ThesisProgressService instance = ThesisProgressService._();



  final _local = LocalProfileStore.instance;

  final _engine = ThesisProgressEngine.instance;



  Future<ThesisProgress> load({bool sync = true}) async {
    ThesisProgress? progress;

    final user = FirebaseAuth.instance.currentUser;

    // Prefer cloud progress for the signed-in user so device-wide offline
    // cache from a previous account cannot leak (e.g. fake 9%).
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('thesis_progress')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          progress = ThesisProgress.fromMap(doc.data()!);
        }
      } catch (_) {}
    }

    if (progress == null) {
      final cached = await _local.loadThesisProgressJson();
      if (cached != null) {
        try {
          progress = ThesisProgress.fromMap(
            jsonDecode(cached) as Map<String, dynamic>,
          );
        } catch (_) {}
      }
    }

    progress ??= await _initialProgress();

    if (progress.items.isEmpty) {
      progress = await _initialProgress();
    }

    if (sync) {
      progress = await _engine.syncFromApp(progress);
      await _persist(progress, remote: false);
    } else {
      await _persistLocal(progress);
    }

    return progress;
  }



  Future<ThesisProgress> _initialProgress() async {

    var templateId = ThesisProgressTemplates.masterStandard;

    final profile = await AcademicProfileService.instance.loadProfile();

    if (profile?.degree.contains('دكت') == true ||

        profile?.degree.toLowerCase().contains('phd') == true) {

      templateId = ThesisProgressTemplates.phdStandard;

    }

    return ThesisProgress(

      templateId: templateId,

      items: ThesisProgressTemplates.build(templateId),

    );

  }



  Future<void> save(ThesisProgress progress) async {

    await _persist(progress, remote: true);

  }



  Future<void> recordActivity(String activityId) async {

    final current = await load(sync: false);

    final log = Map<String, String>.from(current.activityLog);

    log[activityId] = DateTime.now().toIso8601String();

    var updated = current.copyWith(activityLog: log);

    updated = await _engine.syncFromApp(updated);

    await save(updated);

  }



  Future<void> applyTemplate(String templateId) async {

    final current = await load(sync: false);

    final custom = ThesisProgressTemplates.customItemsFrom(current.items);

    final merged = ThesisProgressTemplates.mergeSavedState(

      template: ThesisProgressTemplates.build(templateId),

      saved: current.items,

      customOnly: custom,

    );

    var next = current.copyWith(

      templateId: templateId,

      items: merged,

    );

    next = await _engine.syncFromApp(next);

    await save(next);

  }



  Future<void> addCustomItem(String title) async {

    final trimmed = title.trim();

    if (trimmed.isEmpty) return;



    final current = await load(sync: false);

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';

    final item = ThesisProgressItem(

      id: id,

      title: trimmed,

      kind: ThesisItemKind.chapter,

      isCustom: true,

    );

    await save(current.copyWith(items: [...current.items, item]));

  }



  Future<void> removeCustomItem(String id) async {

    final current = await load(sync: false);

    final next = current.items.where((i) => i.id != id || !i.isCustom).toList();

    await save(current.copyWith(items: next));

  }



  Future<void> refreshFromApp() async {

    final current = await load(sync: false);

    final synced = await _engine.syncFromApp(current);

    await save(synced);

  }



  Future<void> _persist(ThesisProgress progress, {required bool remote}) async {

    await _persistLocal(progress);

    if (!remote) return;



    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;



    try {

      await FirebaseFirestore.instance

          .collection('thesis_progress')

          .doc(user.uid)

          .set(progress.toMap(), SetOptions(merge: true));

    } catch (_) {}

  }



  Future<void> _persistLocal(ThesisProgress progress) async {

    await _local.saveThesisProgressJson(jsonEncode(progress.toMap()));

  }

}


