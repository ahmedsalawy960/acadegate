import '../academic_integrity/openalex_works_client.dart';
import '../ai_advisor/grounded_work.dart';
import '../research_supply_chain/research_goal.dart';
import 'arabic_thesis_catalogs.dart';

/// ترشيح رسائل جامعية للنقطة البحثية داخل استوديو الرسالة.
class ThesisLibraryHit {
  final GroundedWork work;
  final String portalId;
  final String portalLabelAr;
  final String portalLabelEn;

  const ThesisLibraryHit({
    required this.work,
    required this.portalId,
    required this.portalLabelAr,
    required this.portalLabelEn,
  });
}

class ThesisLibraryService {
  ThesisLibraryService._();

  static final ThesisLibraryService instance = ThesisLibraryService._();

  /// بحث حي في OpenAlex (أطروحات) + روابط بحث جاهزة لـ OATD وCORE.
  Future<List<ThesisLibraryHit>> recommendForTopic(
    String rawTopic, {
    int limit = 24,
  }) async {
    final topic = rawTopic.trim();
    if (topic.length < 4) return const [];

    final queries = _topicQueries(topic);
    final byKey = <String, ThesisLibraryHit>{};

    for (final query in queries.take(4)) {
      try {
        final works = await OpenAlexWorksClient.instance.searchDissertations(
          query,
          perPage: (limit / 2).ceil().clamp(8, 40),
        );
        for (final w in works) {
          final grounded = GroundedWork(
            title: w.title,
            doi: w.doi ?? '',
            year: w.year,
            authors: w.authors ?? '',
            source: 'OpenAlex',
            journal: w.journal,
            abstractText: w.abstractText,
            externalUrl: w.url ?? '',
          );
          byKey.putIfAbsent(
            grounded.mergeKey,
            () => ThesisLibraryHit(
              work: grounded,
              portalId: ArabicThesisCatalogs.openAlexTheses.id,
              portalLabelAr: 'OpenAlex',
              portalLabelEn: 'OpenAlex',
            ),
          );
          if (byKey.length >= limit) break;
        }
      } catch (_) {}
      if (byKey.length >= limit) break;
    }

    return byKey.values.take(limit).toList();
  }

  Future<List<ThesisLibraryHit>> recommendForGoal(
    ResearchGoal goal, {
    int limit = 24,
  }) {
    final topic = [
      if (goal.fieldEn.trim().isNotEmpty) goal.fieldEn.trim(),
      if (goal.field.trim().isNotEmpty) goal.field.trim(),
      ...goal.searchQueries.take(2),
      if (goal.raw.trim().isNotEmpty) goal.raw.trim(),
    ].where((s) => s.length >= 4).join(' ');
    return recommendForTopic(
      topic.isNotEmpty ? topic : goal.raw,
      limit: limit,
    );
  }

  Uri browseUri(ArabicThesisCatalog catalog, String topic) =>
      catalog.uriForQuery(topic);

  List<String> _topicQueries(String topic) {
    final cleaned = topic.replaceAll(RegExp(r'\s+'), ' ').trim();
    final out = <String>{cleaned};
    if (cleaned.length > 80) {
      out.add(cleaned.substring(0, 80));
    }
    final words = cleaned
        .split(RegExp(r'[^A-Za-z\u0600-\u06FF0-9]+'))
        .where((w) => w.length >= 4)
        .take(8)
        .toList();
    if (words.length >= 2) {
      out.add(words.take(6).join(' '));
      out.add('${words.take(5).join(' ')} thesis OR dissertation');
    } else {
      out.add('$cleaned dissertation');
      out.add('$cleaned thesis');
    }
    return out.where((q) => q.length >= 4).take(5).toList();
  }
}
