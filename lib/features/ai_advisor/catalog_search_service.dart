import '../../core/locale/app_translate.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../home/home_search_utils.dart';
import '../lab_import/nbsle_university_cities.dart';
import 'catalog_hit.dart';
import 'catalog_intent.dart';

/// Live catalog lookup. New labs/supervisors in Firestore appear automatically.
class CatalogSearchService {
  CatalogSearchService._();

  static final CatalogSearchService instance = CatalogSearchService._();

  static const _labLimit = 5;
  static const _supervisorLimit = 5;

  Future<CatalogSearchSnapshot> search(String message) async {
    final intent = CatalogIntentParser.parse(message);
    if (!intent.isCatalogRequest) {
      return const CatalogSearchSnapshot(intent: CatalogIntentSummary.empty);
    }

    final summary = CatalogIntentSummary(
      wantsLabs: intent.wantsLabs,
      wantsSupervisors: intent.wantsSupervisors,
      city: intent.city ?? '',
      equipmentQuery: intent.equipmentQuery,
      supervisorQuery: intent.supervisorQuery,
    );

    final labs = intent.wantsLabs
        ? await _searchLabs(intent)
        : const <CatalogHit>[];
    final supervisors = intent.wantsSupervisors
        ? await _searchSupervisors(intent)
        : const <CatalogHit>[];

    return CatalogSearchSnapshot(
      intent: summary,
      labs: labs,
      supervisors: supervisors,
    );
  }

  String extraContextForModel(CatalogSearchSnapshot snapshot) {
    if (!snapshot.intent.wantsLabs && !snapshot.intent.wantsSupervisors) {
      return '';
    }
    final buffer = StringBuffer();
    buffer.writeln(
      appTr(
        'نتائج حقيقية من كتالوج AcadeGate. ممنوع اختراع مختبر أو مشرف غير المذكور. '
        'أجب بجملتين ثم أحل المستخدم إلى البطاقات. مختبرات جديدة تُضاف لاحقاً ستظهر هنا تلقائياً.',
        'Real hits from the AcadeGate catalog. Do not invent labs or supervisors. '
        'Answer in two sentences then point to the cards. Labs added later appear here automatically.',
      ),
    );
    if (snapshot.intent.city.isNotEmpty) {
      buffer.writeln(
        appTr(
          'المدينة المطلوبة: ${snapshot.intent.city}',
          'Requested city: ${snapshot.intent.city}',
        ),
      );
    }
    if (snapshot.intent.equipmentQuery.isNotEmpty) {
      buffer.writeln(
        appTr(
          'الجهاز/الخدمة: ${snapshot.intent.equipmentQuery}',
          'Equipment/service: ${snapshot.intent.equipmentQuery}',
        ),
      );
    }
    if (snapshot.labs.isEmpty && snapshot.intent.wantsLabs) {
      buffer.writeln(
        appTr(
          'لا يوجد مختبر مطابق الآن. قل ذلك بوضوح واقترح تصفح المختبرات أو توسيع المدينة.',
          'No matching lab yet. Say so clearly and suggest browsing labs or widening the city.',
        ),
      );
    } else {
      for (var i = 0; i < snapshot.labs.length; i++) {
        final hit = snapshot.labs[i];
        buffer.writeln(
          '${i + 1}. ${hit.title} — ${hit.subtitle}'
          '${hit.matchedEquipmentName.isEmpty ? '' : ' (${hit.matchedEquipmentName})'}',
        );
      }
    }
    if (snapshot.supervisors.isEmpty && snapshot.intent.wantsSupervisors) {
      buffer.writeln(
        appTr(
          'لا يوجد مشرف مطابق للتخصص المطلوب في الكتالوج الحالي.',
          'No matching supervisor for that specialty in the current catalog.',
        ),
      );
    } else {
      for (var i = 0; i < snapshot.supervisors.length; i++) {
        final hit = snapshot.supervisors[i];
        buffer.writeln('${i + 1}. ${hit.title} — ${hit.subtitle}');
      }
    }
    return buffer.toString();
  }

  String localReply(CatalogSearchSnapshot snapshot) {
    if (snapshot.isEmpty) {
      final city = snapshot.intent.city;
      final eq = snapshot.intent.equipmentQuery;
      return appTr(
        'بحثت في كتالوج التطبيق ولم أجد نتيجة مطابقة'
            '${eq.isEmpty ? '' : ' لـ **$eq**'}'
            '${city.isEmpty ? '' : ' في **$city**'}.\n\n'
            'عند إضافة مختبرات أو مشرفين جدد سيظهرون هنا تلقائياً. '
            'يمكنك تصفح قسم المختبرات أو المشرفين يدوياً.',
        'I searched the in-app catalog and found no match'
            '${eq.isEmpty ? '' : ' for **$eq**'}'
            '${city.isEmpty ? '' : ' in **$city**'}.\n\n'
            'Newly added labs and supervisors will show up here automatically. '
            'You can also browse Labs or Supervisors manually.',
      );
    }

    final buffer = StringBuffer(
      appTr(
        'نتائج من كتالوج AcadeGate (ليست اقتراحات عامة):',
        'Results from the AcadeGate catalog (not generic advice):',
      ),
    );
    buffer.writeln();
    if (snapshot.labs.isNotEmpty) {
      buffer.writeln(appTr('\n**مختبرات**', '\n**Labs**'));
      for (final hit in snapshot.labs) {
        buffer.writeln('• **${hit.title}** — ${hit.subtitle}');
        if (hit.reason.isNotEmpty) buffer.writeln('  ${hit.reason}');
      }
    }
    if (snapshot.supervisors.isNotEmpty) {
      buffer.writeln(appTr('\n**مشرفون**', '\n**Supervisors**'));
      for (final hit in snapshot.supervisors) {
        buffer.writeln('• **${hit.title}** — ${hit.subtitle}');
        if (hit.reason.isNotEmpty) buffer.writeln('  ${hit.reason}');
      }
    }
    buffer.writeln(
      appTr(
        '\nاستخدم الأزرار أسفل الرد للحجز أو التواصل داخل التطبيق.',
        '\nUse the buttons below the reply to book or contact inside the app.',
      ),
    );
    return buffer.toString();
  }

  Future<List<CatalogHit>> _searchLabs(CatalogIntent intent) async {
    final query = intent.equipmentQuery.trim();
    final city = intent.city;
    var candidates = await AcademicContentService.instance.searchLabs(
      query: query,
      city: city,
      limit: 80,
    );

    if (candidates.isEmpty && city != null && query.isNotEmpty) {
      candidates = await AcademicContentService.instance.searchLabs(
        query: query,
        limit: 80,
      );
      candidates = candidates
          .where((lab) => NbsleUniversityCities.cityMatches(lab.city, city))
          .toList();
    }

    if (candidates.isEmpty && city != null && query.isNotEmpty) {
      final inCity = await AcademicContentService.instance.searchLabs(
        city: city,
        limit: 80,
      );
      candidates = inCity;
    }

    final scored = <_ScoredLab>[];
    for (final lab in candidates.take(12)) {
      AcademicLab full = lab;
      if (lab.id != null && lab.id!.isNotEmpty && lab.equipmentList.isEmpty) {
        full = await AcademicContentService.instance.fetchLabById(lab.id!) ??
            lab;
      }
      final score = _scoreLab(full, query);
      if (query.isNotEmpty && score <= 0) continue;
      final device = _bestDevice(full, query);
      scored.add(_ScoredLab(lab: full, score: score, device: device));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(_labLimit).map((item) {
      final lab = item.lab;
      final device = item.device;
      final cityLabel = NbsleUniversityCities.canonicalCity(lab.city);
      return CatalogHit(
        kind: CatalogHitKind.lab,
        id: lab.id ?? '',
        title: lab.name,
        subtitle: [
          if (cityLabel.isNotEmpty) cityLabel,
          if (lab.university.isNotEmpty) lab.university,
        ].join(' · '),
        reason: device != null
            ? appTr('جهاز مطابق: ${device.name}', 'Matched device: ${device.name}')
            : (query.isEmpty
                ? appTr('في نطاق المدينة المطلوبة', 'In the requested city')
                : appTr('مطابقة من وصف المختبر', 'Matched from the lab description')),
        matchedEquipmentId: device?.id ?? '',
        matchedEquipmentName: device?.name ?? '',
        canBook: lab.isFromFirebase && device != null,
        canContact: lab.hasLabContact || lab.isFromFirebase,
      );
    }).where((hit) => hit.id.isNotEmpty).toList();
  }

  Future<List<CatalogHit>> _searchSupervisors(CatalogIntent intent) async {
    final query = intent.supervisorQuery.trim();
    if (query.length < 3) return const [];
    final pool = await AcademicContentService.instance.searchSupervisors(
      query: query,
      limit: 80,
    );
    final scored = pool
        .where((s) => !s.isDemo)
        .map((s) => (supervisor: s, score: _scoreSupervisor(s, query)))
        .where((item) => item.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(_supervisorLimit).map((item) {
      final s = item.supervisor;
      return CatalogHit(
        kind: CatalogHitKind.supervisor,
        id: s.id ?? '',
        title: s.name,
        subtitle: [
          if (s.speciality.isNotEmpty) s.speciality,
          if (s.university.isNotEmpty) s.university,
        ].join(' · '),
        reason: appTr('توافق مع التخصص المطلوب', 'Matches the requested specialty'),
        canContact: true,
      );
    }).where((hit) => hit.id.isNotEmpty).toList();
  }

  int _scoreLab(AcademicLab lab, String query) {
    if (query.trim().isEmpty) return 10;
    final q = normalizeSearchText(query);
    var score = 0;
    for (final name in [
      ...lab.equipmentNameHints,
      ...lab.equipmentList.map((e) => e.name),
      lab.equipment,
    ]) {
      final n = normalizeSearchText(name);
      if (n.isEmpty) continue;
      if (n.contains(q) || q.contains(n)) score += 50;
    }
    if (normalizeSearchText(lab.name).contains(q)) score += 12;
    if (normalizeSearchText(lab.description).contains(q)) score += 8;
    if (lab.tags.any((t) => normalizeSearchText(t).contains(q))) score += 10;
    if (lab.sampleServices.any(
      (s) => normalizeSearchText(s.name).contains(q),
    )) {
      score += 20;
    }
    return score;
  }

  LabEquipment? _bestDevice(AcademicLab lab, String query) {
    final devices = lab.devices;
    if (devices.isEmpty) return null;
    if (query.trim().isEmpty) return devices.first;
    final q = normalizeSearchText(query);
    LabEquipment? best;
    var bestScore = 0;
    for (final device in devices) {
      final n = normalizeSearchText('${device.name} ${device.code}');
      var s = 0;
      if (n.contains(q)) s = 40;
      if (q.contains(normalizeSearchText(device.name)) &&
          device.name.trim().length >= 3) {
        s = 50;
      }
      if (s > bestScore) {
        bestScore = s;
        best = device;
      }
    }
    return bestScore > 0 ? best : null;
  }

  int _scoreSupervisor(AcademicSupervisor supervisor, String query) {
    final q = normalizeSearchText(query);
    if (q.isEmpty) return 0;
    final hay = normalizeSearchText([
      supervisor.speciality,
      supervisor.faculty,
      supervisor.category,
      supervisor.bio,
      ...supervisor.tags,
    ].join(' '));
    if (hay.contains(q)) return 40;
    final tokens = q.split(' ').where((t) => t.length >= 3).toList();
    if (tokens.isEmpty) return 0;
    final hits = tokens.where(hay.contains).length;
    if (hits == tokens.length) return 28;
    if (hits >= 1) return 12 * hits;
    return 0;
  }
}

class _ScoredLab {
  final AcademicLab lab;
  final int score;
  final LabEquipment? device;

  _ScoredLab({required this.lab, required this.score, this.device});
}
