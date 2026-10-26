import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// One paper returned by the Consensus Cloud Function.
class ConsensusPaper {
  final String title;
  final String doi;
  final int? year;
  final String authors;
  final String journal;
  final String abstractText;
  final String takeaway;
  final String url;

  const ConsensusPaper({
    required this.title,
    this.doi = '',
    this.year,
    this.authors = '',
    this.journal = '',
    this.abstractText = '',
    this.takeaway = '',
    this.url = '',
  });

  String get groundedAbstract {
    final abstract = abstractText.trim();
    final note = takeaway.trim();
    if (note.isEmpty || abstract.contains(note)) return abstract;
    if (abstract.isEmpty) return note;
    return '$abstract\n\n$note';
  }
}

/// Consensus search via Cloud Function. The API key stays in Firebase Secrets.
class ConsensusClient {
  ConsensusClient._();

  static final ConsensusClient instance = ConsensusClient._();

  static const _fnUrl =
      'https://us-central1-acadegate-new.cloudfunctions.net/consensusSearchHttp';

  Future<List<ConsensusPaper>> search(
    String query, {
    int limit = 8,
    int? fromYear,
  }) async {
    final q = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (q.length < 3) return const [];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const [];

    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return const [];
      final uri = Uri.parse(_fnUrl).replace(
        queryParameters: {
          'q': q,
          'num': '${limit.clamp(1, 20)}',
          if (fromYear != null && fromYear > 1900) 'year_min': '$fromYear',
        },
      );
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) return const [];
      return papersFromBody(response.body);
    } catch (_) {
      return const [];
    }
  }

  static List<ConsensusPaper> papersFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final rows = decoded['papers'];
    if (rows is! List) return const [];
    final papers = <ConsensusPaper>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final title = row['title']?.toString().trim() ?? '';
      if (title.isEmpty) continue;
      final yearRaw = row['year'];
      final year = yearRaw is int ? yearRaw : int.tryParse('$yearRaw');
      papers.add(
        ConsensusPaper(
          title: title,
          doi: row['doi']?.toString().trim() ?? '',
          year: year,
          authors: row['authors']?.toString().trim() ?? '',
          journal: row['journal']?.toString().trim() ?? '',
          abstractText: row['abstract']?.toString().trim() ?? '',
          takeaway: row['takeaway']?.toString().trim() ?? '',
          url: row['url']?.toString().trim() ?? '',
        ),
      );
    }
    return papers;
  }
}
