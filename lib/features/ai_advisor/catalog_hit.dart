enum CatalogHitKind { lab, supervisor }

class CatalogHit {
  final CatalogHitKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String reason;
  final String matchedEquipmentId;
  final String matchedEquipmentName;
  final bool canBook;
  final bool canContact;

  const CatalogHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    this.reason = '',
    this.matchedEquipmentId = '',
    this.matchedEquipmentName = '',
    this.canBook = false,
    this.canContact = false,
  });

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'reason': reason,
        'matchedEquipmentId': matchedEquipmentId,
        'matchedEquipmentName': matchedEquipmentName,
        'canBook': canBook,
        'canContact': canContact,
      };

  factory CatalogHit.fromMap(Map<String, dynamic> map) {
    final kindRaw = map['kind']?.toString() ?? 'lab';
    return CatalogHit(
      kind: kindRaw == 'supervisor'
          ? CatalogHitKind.supervisor
          : CatalogHitKind.lab,
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      matchedEquipmentId: map['matchedEquipmentId']?.toString() ?? '',
      matchedEquipmentName: map['matchedEquipmentName']?.toString() ?? '',
      canBook: map['canBook'] == true,
      canContact: map['canContact'] == true,
    );
  }
}

class CatalogSearchSnapshot {
  final CatalogIntentSummary intent;
  final List<CatalogHit> labs;
  final List<CatalogHit> supervisors;

  const CatalogSearchSnapshot({
    required this.intent,
    this.labs = const [],
    this.supervisors = const [],
  });

  bool get isEmpty => labs.isEmpty && supervisors.isEmpty;
  List<CatalogHit> get allHits => [...labs, ...supervisors];

  Map<String, dynamic> toMap() => {
        'intent': intent.toMap(),
        'labs': labs.map((h) => h.toMap()).toList(),
        'supervisors': supervisors.map((h) => h.toMap()).toList(),
      };

  factory CatalogSearchSnapshot.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const CatalogSearchSnapshot(
        intent: CatalogIntentSummary.empty,
      );
    }
    return CatalogSearchSnapshot(
      intent: CatalogIntentSummary.fromMap(
        Map<String, dynamic>.from(map['intent'] as Map? ?? const {}),
      ),
      labs: _hits(map['labs']),
      supervisors: _hits(map['supervisors']),
    );
  }

  static List<CatalogHit> _hits(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => CatalogHit.fromMap(Map<String, dynamic>.from(item)))
        .where((hit) => hit.id.isNotEmpty)
        .toList();
  }
}

class CatalogIntentSummary {
  final bool wantsLabs;
  final bool wantsSupervisors;
  final String city;
  final String equipmentQuery;
  final String supervisorQuery;

  const CatalogIntentSummary({
    required this.wantsLabs,
    required this.wantsSupervisors,
    this.city = '',
    this.equipmentQuery = '',
    this.supervisorQuery = '',
  });

  static const empty = CatalogIntentSummary(
    wantsLabs: false,
    wantsSupervisors: false,
  );

  Map<String, dynamic> toMap() => {
        'wantsLabs': wantsLabs,
        'wantsSupervisors': wantsSupervisors,
        'city': city,
        'equipmentQuery': equipmentQuery,
        'supervisorQuery': supervisorQuery,
      };

  factory CatalogIntentSummary.fromMap(Map<String, dynamic> map) {
    return CatalogIntentSummary(
      wantsLabs: map['wantsLabs'] == true,
      wantsSupervisors: map['wantsSupervisors'] == true,
      city: map['city']?.toString() ?? '',
      equipmentQuery: map['equipmentQuery']?.toString() ?? '',
      supervisorQuery: map['supervisorQuery']?.toString() ?? '',
    );
  }
}
