import 'package:cloud_firestore/cloud_firestore.dart';

/// أنواع أقسام الصفحة الرئيسية القابلة للترتيب من Firestore.
enum HomeSectionType {
  heroCarousel,
  journey,
  forYou,
  servicesGrid,
  adSlot,
  matchPromo,
  footer,
  unknown;

  static HomeSectionType fromString(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'hero_carousel':
      case 'hero':
        return HomeSectionType.heroCarousel;
      case 'journey':
      case 'thesis_progress':
        return HomeSectionType.journey;
      case 'for_you':
      case 'personalized':
        return HomeSectionType.forYou;
      case 'services_grid':
      case 'services':
        return HomeSectionType.servicesGrid;
      case 'ad_slot':
      case 'ad':
        return HomeSectionType.adSlot;
      case 'match_promo':
      case 'smart_match':
        return HomeSectionType.matchPromo;
      case 'footer':
        return HomeSectionType.footer;
      default:
        return HomeSectionType.unknown;
    }
  }

  String get firestoreValue {
    switch (this) {
      case HomeSectionType.heroCarousel:
        return 'hero_carousel';
      case HomeSectionType.journey:
        return 'journey';
      case HomeSectionType.forYou:
        return 'for_you';
      case HomeSectionType.servicesGrid:
        return 'services_grid';
      case HomeSectionType.adSlot:
        return 'ad_slot';
      case HomeSectionType.matchPromo:
        return 'match_promo';
      case HomeSectionType.footer:
        return 'footer';
      case HomeSectionType.unknown:
        return 'unknown';
    }
  }
}

class HomeSection {
  final String id;
  final HomeSectionType type;
  final int order;
  final bool enabled;
  final String placement;
  final int? offset;
  final int? limit;
  final List<String> serviceKeys;
  /// بعد كم بطاقة خدمة يُدرج إعلان (مثلاً [4, 8]).
  final List<int> adBreaks;
  /// مقابلات لـ [adBreaks]: mid_1 ثم mid_2…
  final List<String> adPlacements;

  const HomeSection({
    required this.id,
    required this.type,
    this.order = 0,
    this.enabled = true,
    this.placement = '',
    this.offset,
    this.limit,
    this.serviceKeys = const [],
    this.adBreaks = const [],
    this.adPlacements = const [],
  });

  factory HomeSection.fromMap(String id, Map<String, dynamic> map) {
    final rawKeys = map['serviceKeys'] ?? map['services'];
    final keys = rawKeys is List
        ? rawKeys.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final breaks = map['adBreaks'] is List
        ? (map['adBreaks'] as List)
            .map((e) => _asInt(e))
            .where((e) => e > 0)
            .toList()
        : const <int>[];
    final placements = map['adPlacements'] is List
        ? (map['adPlacements'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    return HomeSection(
      id: id,
      type: HomeSectionType.fromString(map['type']?.toString()),
      order: _asInt(map['order']),
      enabled: map['enabled'] as bool? ?? true,
      placement: map['placement']?.toString() ?? '',
      offset: map['offset'] == null ? null : _asInt(map['offset']),
      limit: map['limit'] == null ? null : _asInt(map['limit']),
      serviceKeys: keys,
      adBreaks: breaks,
      adPlacements: placements,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.firestoreValue,
        'order': order,
        'enabled': enabled,
        if (placement.isNotEmpty) 'placement': placement,
        if (offset != null) 'offset': offset,
        if (limit != null) 'limit': limit,
        if (serviceKeys.isNotEmpty) 'serviceKeys': serviceKeys,
        if (adBreaks.isNotEmpty) 'adBreaks': adBreaks,
        if (adPlacements.isNotEmpty) 'adPlacements': adPlacements,
      };
}

class HomePromoBanner {
  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final String imageUrl;
  final String linkType;
  final String linkTarget;
  final String placement;
  final int weight;
  final bool active;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<String> audiences;
  final String ctaAr;
  final String ctaEn;
  final int accentColor;
  /// `feature` = ترويج قسم (للـ hero) · `sponsored` = إعلان مستقل (للوسط)
  final String kind;

  const HomePromoBanner({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.subtitleAr = '',
    this.subtitleEn = '',
    this.imageUrl = '',
    this.linkType = 'route',
    this.linkTarget = '',
    this.placement = 'hero',
    this.weight = 1,
    this.active = true,
    this.startAt,
    this.endAt,
    this.audiences = const ['all'],
    this.ctaAr = 'اعرف المزيد',
    this.ctaEn = 'Learn more',
    this.accentColor = 0xFF1A237E,
    this.kind = 'feature',
  });

  bool get isSponsoredAd => kind == 'sponsored' || kind == 'ad';

  bool get isLive {
    if (!active) return false;
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  String title(bool arabic) => arabic ? titleAr : titleEn;
  String subtitle(bool arabic) => arabic ? subtitleAr : subtitleEn;
  String cta(bool arabic) => arabic ? ctaAr : ctaEn;

  factory HomePromoBanner.fromMap(String id, Map<String, dynamic> map) {
    final audiencesRaw = map['audiences'];
    final audiences = audiencesRaw is List
        ? audiencesRaw.map((e) => e.toString()).toList()
        : const <String>['all'];
    return HomePromoBanner(
      id: id,
      titleAr: map['titleAr']?.toString() ?? map['title']?.toString() ?? '',
      titleEn: map['titleEn']?.toString() ?? map['title']?.toString() ?? '',
      subtitleAr: map['subtitleAr']?.toString() ?? map['subtitle']?.toString() ?? '',
      subtitleEn: map['subtitleEn']?.toString() ?? map['subtitle']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      linkType: map['linkType']?.toString() ?? 'route',
      linkTarget: map['linkTarget']?.toString() ?? map['route']?.toString() ?? '',
      placement: map['placement']?.toString() ?? 'hero',
      weight: _asInt(map['weight'], fallback: 1).clamp(1, 100),
      active: map['active'] as bool? ?? true,
      startAt: _asDate(map['startAt']),
      endAt: _asDate(map['endAt']),
      audiences: audiences.isEmpty ? const ['all'] : audiences,
      ctaAr: map['ctaAr']?.toString() ?? 'اعرف المزيد',
      ctaEn: map['ctaEn']?.toString() ?? 'Learn more',
      accentColor: _asInt(map['accentColor'], fallback: 0xFF1A237E),
      kind: map['kind']?.toString() ??
          (map['placement']?.toString().startsWith('mid') == true
              ? 'sponsored'
              : 'feature'),
    );
  }

  Map<String, dynamic> toMap() => {
        'titleAr': titleAr,
        'titleEn': titleEn,
        'subtitleAr': subtitleAr,
        'subtitleEn': subtitleEn,
        'imageUrl': imageUrl,
        'linkType': linkType,
        'linkTarget': linkTarget,
        'placement': placement,
        'weight': weight,
        'active': active,
        if (startAt != null) 'startAt': startAt!.toIso8601String(),
        if (endAt != null) 'endAt': endAt!.toIso8601String(),
        'audiences': audiences,
        'ctaAr': ctaAr,
        'ctaEn': ctaEn,
        'accentColor': accentColor,
        'kind': kind,
        'approvalStatus': 'approved',
      };
}

class HomeFeedSnapshot {
  final List<HomeSection> sections;
  final List<HomePromoBanner> banners;
  final bool fromRemote;

  const HomeFeedSnapshot({
    required this.sections,
    required this.banners,
    this.fromRemote = false,
  });

  List<HomePromoBanner> bannersFor(String placement) {
    final list = banners
        .where((b) => b.isLive && b.placement == placement)
        .toList();
    list.sort((a, b) => b.weight.compareTo(a.weight));
    return list;
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
