import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

enum PublishCitationStyle { apa, ieee, vancouver, harvard, chicago, acs }

/// How an in-text citation is rendered for a given marker.
enum InTextCitationForm {
  /// Default for the selected bibliography style.
  auto,
  /// (Author, Year) / (Author et al., Year)
  parenthetical,
  /// Author (Year) / Author et al. (Year)
  narrative,
  /// [n] numbered citation
  numbered,
  /// Superscript n (ACS / some Vancouver variants)
  superscript,
}

enum ManuscriptStatus { draft, formatted, submitted }

enum ReferenceType { journal, book, web, conference }

enum ManuscriptBlockType {
  paragraph,
  heading,
  image,
  table,
  equation,
}

/// Marker: {{cite:REFERENCE_ID}} or {{cite:REFERENCE_ID|form}}
/// form = p | n | num | sup | auto
const citeMarkerPattern = r'\{\{cite:([^}|]+)(?:\|([^}]+))?\}\}';

/// Canonical academic section headings used when structuring imports.
const academicSectionOrder = <String>[
  'Abstract',
  'Introduction',
  'Experimental',
  'Results',
  'Discussion',
  'Conclusion',
];

class PublishReference {
  final String id;
  final ReferenceType type;
  final List<String> authors;
  final String title;
  final String container;
  final String year;
  final String volume;
  final String issue;
  final String pages;
  final String doi;
  final String url;
  final String publisher;
  final String conference;
  /// Original bibliographic line when imported from Word/PDF.
  final String rawText;

  const PublishReference({
    required this.id,
    required this.type,
    this.authors = const [],
    required this.title,
    this.container = '',
    this.year = '',
    this.volume = '',
    this.issue = '',
    this.pages = '',
    this.doi = '',
    this.url = '',
    this.publisher = '',
    this.conference = '',
    this.rawText = '',
  });

  PublishReference copyWith({
    ReferenceType? type,
    List<String>? authors,
    String? title,
    String? container,
    String? year,
    String? volume,
    String? issue,
    String? pages,
    String? doi,
    String? url,
    String? publisher,
    String? conference,
    String? rawText,
  }) {
    return PublishReference(
      id: id,
      type: type ?? this.type,
      authors: authors ?? this.authors,
      title: title ?? this.title,
      container: container ?? this.container,
      year: year ?? this.year,
      volume: volume ?? this.volume,
      issue: issue ?? this.issue,
      pages: pages ?? this.pages,
      doi: doi ?? this.doi,
      url: url ?? this.url,
      publisher: publisher ?? this.publisher,
      conference: conference ?? this.conference,
      rawText: rawText ?? this.rawText,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'authors': authors,
        'title': title,
        'container': container,
        'year': year,
        'volume': volume,
        'issue': issue,
        'pages': pages,
        'doi': doi,
        'url': url,
        'publisher': publisher,
        'conference': conference,
        if (rawText.isNotEmpty) 'rawText': rawText,
      };

  factory PublishReference.fromMap(Map<String, dynamic> map) {
    return PublishReference(
      id: map['id']?.toString() ?? '',
      type: ReferenceType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ReferenceType.journal,
      ),
      authors: map['authors'] is List
          ? (map['authors'] as List).map((e) => e.toString()).toList()
          : const [],
      title: map['title']?.toString() ?? '',
      container: map['container']?.toString() ?? '',
      year: map['year']?.toString() ?? '',
      volume: map['volume']?.toString() ?? '',
      issue: map['issue']?.toString() ?? '',
      pages: map['pages']?.toString() ?? '',
      doi: map['doi']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      publisher: map['publisher']?.toString() ?? '',
      conference: map['conference']?.toString() ?? '',
      rawText: map['rawText']?.toString() ?? '',
    );
  }
}

class ManuscriptBlock {
  final String id;
  final ManuscriptBlockType type;
  final String text;
  final String? imageUrl;
  final String? caption;
  final List<List<String>> rows;
  /// Image URL per table cell (same shape as [rows]); empty = text-only cell.
  final List<List<String>> rowCellImages;
  /// Original Office Math ML for equation blocks (preserves fractions/layout on export).
  final String? ommlXml;

  const ManuscriptBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.imageUrl,
    this.caption,
    this.rows = const [],
    this.rowCellImages = const [],
    this.ommlXml,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (caption != null && caption!.isNotEmpty) 'caption': caption,
        if (ommlXml != null && ommlXml!.isNotEmpty) 'ommlXml': ommlXml,
        if (rows.isNotEmpty)
          'rowCells': rows
              .map((cells) => {'cells': cells})
              .toList(),
        if (rowCellImages.isNotEmpty)
          'rowCellImages': rowCellImages
              .map((cells) => {'cells': cells})
              .toList(),
      };

  static List<List<String>> _rowsFromMap(dynamic rowsRaw) {
    if (rowsRaw == null) return const [];

    if (rowsRaw is String && rowsRaw.isNotEmpty) {
      try {
        return _rowsFromMap(jsonDecode(rowsRaw));
      } catch (_) {
        return const [];
      }
    }

    if (rowsRaw is! List) return const [];

    if (rowsRaw.isNotEmpty && rowsRaw.first is List) {
      return rowsRaw
          .whereType<List>()
          .map((row) => row.map((cell) => cell.toString()).toList())
          .toList();
    }

    return rowsRaw
        .whereType<Map>()
        .map((row) {
          final cellsRaw = row['cells'];
          if (cellsRaw is List) {
            return cellsRaw.map((cell) => cell.toString()).toList();
          }
          return const <String>[];
        })
        .where((row) => row.isNotEmpty)
        .toList();
  }

  /// Pad short rows so Flutter [Table] can render (equal column count per row).
  static List<List<String>> normalizedRows(List<List<String>> rows) {
    if (rows.isEmpty) return rows;
    final maxCols = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    return rows
        .map((row) => [
              ...row,
              ...List.filled(maxCols - row.length, ''),
            ])
        .toList();
  }

  static List<List<String>> normalizedCellImages(
    List<List<String>> images,
    List<List<String>> rows,
  ) {
    if (rows.isEmpty) return const [];
    final maxCols = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    return List.generate(rows.length, (r) {
      final rowImgs = r < images.length ? images[r] : const <String>[];
      return List.generate(
        maxCols,
        (c) => c < rowImgs.length ? rowImgs[c] : '',
      );
    });
  }

  factory ManuscriptBlock.fromMap(Map<String, dynamic> map) {
    final type = ManuscriptBlockType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => ManuscriptBlockType.paragraph,
    );
    var rows = _rowsFromMap(map['rowCells'] ?? map['rows']);
    var cellImages = _rowsFromMap(map['rowCellImages']);
    if (type == ManuscriptBlockType.table) {
      rows = normalizedRows(rows);
      cellImages = normalizedCellImages(cellImages, rows);
    }

    return ManuscriptBlock(
      id: map['id']?.toString() ?? '',
      type: type,
      text: map['text']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      caption: map['caption']?.toString(),
      rows: rows,
      rowCellImages: cellImages,
      ommlXml: map['ommlXml']?.toString(),
    );
  }

  ManuscriptBlock copyWith({
    ManuscriptBlockType? type,
    String? text,
    String? imageUrl,
    String? caption,
    List<List<String>>? rows,
    List<List<String>>? rowCellImages,
    String? ommlXml,
  }) {
    return ManuscriptBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      rows: rows ?? this.rows,
      rowCellImages: rowCellImages ?? this.rowCellImages,
      ommlXml: ommlXml ?? this.ommlXml,
    );
  }
}

class ManuscriptAttachment {
  final String id;
  final String name;
  final String url;
  final String mime;
  final int sizeBytes;

  const ManuscriptAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.mime,
    this.sizeBytes = 0,
  });

  bool get isPdf => mime.contains('pdf');
  bool get isWord =>
      mime.contains('word') || name.toLowerCase().endsWith('.docx');

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'mime': mime,
        'sizeBytes': sizeBytes,
      };

  factory ManuscriptAttachment.fromMap(Map<String, dynamic> map) {
    return ManuscriptAttachment(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      mime: map['mime']?.toString() ?? '',
      sizeBytes: map['sizeBytes'] is int
          ? map['sizeBytes'] as int
          : int.tryParse(map['sizeBytes']?.toString() ?? '') ?? 0,
    );
  }
}

class PublishManuscript {
  final String? id;
  final String userId;
  final String title;
  final String abstractText;
  final String body;
  final List<ManuscriptBlock> bodyBlocks;
  final List<PublishReference> references;
  final List<ManuscriptAttachment> attachments;
  final PublishCitationStyle? citationStyle;
  final String? journalId;
  final String? journalName;
  final ManuscriptStatus status;
  final DateTime? updatedAt;

  const PublishManuscript({
    this.id,
    required this.userId,
    required this.title,
    this.abstractText = '',
    this.body = '',
    this.bodyBlocks = const [],
    this.references = const [],
    this.attachments = const [],
    this.citationStyle,
    this.journalId,
    this.journalName,
    this.status = ManuscriptStatus.draft,
    this.updatedAt,
  });

  PublishCitationStyle get effectiveStyle =>
      citationStyle ?? PublishCitationStyle.apa;

  bool get hasContent =>
      title.trim().isNotEmpty ||
      abstractText.trim().isNotEmpty ||
      bodyBlocks.isNotEmpty ||
      body.trim().isNotEmpty ||
      attachments.isNotEmpty;

  /// Plain-text fallback synthesized from blocks (search / legacy).
  String get plainBodyFromBlocks {
    if (bodyBlocks.isEmpty) return body;
    return bodyBlocks
        .map((b) {
          return switch (b.type) {
            ManuscriptBlockType.paragraph ||
            ManuscriptBlockType.heading ||
            ManuscriptBlockType.equation =>
              b.text,
            ManuscriptBlockType.image => b.caption ?? '[image]',
            ManuscriptBlockType.table =>
              b.rows.map((r) => r.join('\t')).join('\n'),
          };
        })
        .join('\n\n');
  }

  static List<ManuscriptBlock> blocksFromLegacyBody(String body) {
    if (body.trim().isEmpty) return const [];
    return [
      ManuscriptBlock(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ManuscriptBlockType.paragraph,
        text: body,
      ),
    ];
  }

  Map<String, dynamic> toMap() {
    final blocks = bodyBlocks;
    return {
      'userId': userId,
      'title': title.trim(),
      'abstractText': abstractText.trim(),
      'body': plainBodyFromBlocks.trim(),
      'bodyBlocks': blocks.map((b) => b.toMap()).toList(),
      'references': references.map((r) => r.toMap()).toList(),
      'attachments': attachments.map((a) => a.toMap()).toList(),
      if (citationStyle != null) 'citationStyle': citationStyle!.name,
      if (journalId != null) 'journalId': journalId,
      if (journalName != null) 'journalName': journalName,
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PublishManuscript.fromMap(Map<String, dynamic> map, {String? id}) {
    final refsRaw = map['references'];
    final refs = refsRaw is List
        ? refsRaw
            .whereType<Map>()
            .map((e) => PublishReference.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <PublishReference>[];

    final blocksRaw = map['bodyBlocks'];
    var blocks = blocksRaw is List
        ? blocksRaw
            .whereType<Map>()
            .map((e) => ManuscriptBlock.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <ManuscriptBlock>[];

    final legacyBody = map['body']?.toString() ?? '';
    if (blocks.isEmpty && legacyBody.trim().isNotEmpty) {
      blocks = blocksFromLegacyBody(legacyBody);
    }

    final attachRaw = map['attachments'];
    final attachments = attachRaw is List
        ? attachRaw
            .whereType<Map>()
            .map(
              (e) => ManuscriptAttachment.fromMap(Map<String, dynamic>.from(e)),
            )
            .toList()
        : <ManuscriptAttachment>[];

    PublishCitationStyle? style;
    final styleRaw = map['citationStyle']?.toString();
    if (styleRaw != null && styleRaw.isNotEmpty) {
      for (final s in PublishCitationStyle.values) {
        if (s.name == styleRaw) {
          style = s;
          break;
        }
      }
    }

    return PublishManuscript(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      abstractText: map['abstractText']?.toString() ?? '',
      body: legacyBody,
      bodyBlocks: blocks,
      references: refs,
      attachments: attachments,
      citationStyle: style,
      journalId: map['journalId']?.toString(),
      journalName: map['journalName']?.toString(),
      status: ManuscriptStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ManuscriptStatus.draft,
      ),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  PublishManuscript copyWith({
    String? title,
    String? abstractText,
    String? body,
    List<ManuscriptBlock>? bodyBlocks,
    List<PublishReference>? references,
    List<ManuscriptAttachment>? attachments,
    PublishCitationStyle? citationStyle,
    String? journalId,
    String? journalName,
    ManuscriptStatus? status,
  }) {
    return PublishManuscript(
      id: id,
      userId: userId,
      title: title ?? this.title,
      abstractText: abstractText ?? this.abstractText,
      body: body ?? this.body,
      bodyBlocks: bodyBlocks ?? this.bodyBlocks,
      references: references ?? this.references,
      attachments: attachments ?? this.attachments,
      citationStyle: citationStyle ?? this.citationStyle,
      journalId: journalId ?? this.journalId,
      journalName: journalName ?? this.journalName,
      status: status ?? this.status,
      updatedAt: updatedAt,
    );
  }

  int referenceIndex(String refId) {
    final cited = citedReferencesInOrder();
    if (cited.isNotEmpty) {
      final i = cited.indexWhere((r) => r.id == refId);
      if (i >= 0) return i + 1;
    }
    final i = references.indexWhere((r) => r.id == refId);
    return i >= 0 ? i + 1 : 0;
  }

  PublishReference? referenceById(String refId) {
    for (final r in references) {
      if (r.id == refId) return r;
    }
    return null;
  }

  /// References in first-citation order (for numbered styles / end list).
  /// Falls back to the full reference list when no cite markers exist yet.
  List<PublishReference> citedReferencesInOrder() {
    final byId = {for (final r in references) r.id: r};
    final ordered = <PublishReference>[];
    final seen = <String>{};
    final regex = RegExp(citeMarkerPattern);

    void scan(String text) {
      for (final m in regex.allMatches(text)) {
        final id = m.group(1)?.trim() ?? '';
        if (id.isEmpty || seen.contains(id)) continue;
        final ref = byId[id];
        if (ref == null) continue;
        seen.add(id);
        ordered.add(ref);
      }
    }

    scan(abstractText);
    for (final block in bodyBlocks) {
      scan(block.text);
      if (block.caption != null) scan(block.caption!);
    }
    scan(body);

    if (ordered.isEmpty) return List<PublishReference>.from(references);
    // Append uncited refs so nothing is silently dropped from the library.
    for (final r in references) {
      if (!seen.contains(r.id)) ordered.add(r);
    }
    return ordered;
  }

  /// Only references that appear as {{cite:…}} markers (empty if none cited).
  List<PublishReference> onlyCitedReferences() {
    final byId = {for (final r in references) r.id: r};
    final ordered = <PublishReference>[];
    final seen = <String>{};
    final regex = RegExp(citeMarkerPattern);

    void scan(String text) {
      for (final m in regex.allMatches(text)) {
        final id = m.group(1)?.trim() ?? '';
        if (id.isEmpty || seen.contains(id)) continue;
        final ref = byId[id];
        if (ref == null) continue;
        seen.add(id);
        ordered.add(ref);
      }
    }

    scan(abstractText);
    for (final block in bodyBlocks) {
      scan(block.text);
      if (block.caption != null) scan(block.caption!);
    }
    scan(body);
    return ordered;
  }
}

class PublishJournal {
  final String? id;
  final String name;
  final String publisher;
  final String issn;
  final List<String> scopes;
  final bool supportsIeee;
  final bool supportsApa;
  final String submissionUrl;
  final String partnerUniversity;
  final String approvalStatus;
  final String createdBy;

  const PublishJournal({
    this.id,
    required this.name,
    this.publisher = '',
    this.issn = '',
    this.scopes = const [],
    this.supportsIeee = true,
    this.supportsApa = true,
    this.submissionUrl = '',
    this.partnerUniversity = '',
    this.approvalStatus = 'pending',
    this.createdBy = '',
  });

  bool get isApproved => approvalStatus == 'approved';

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'publisher': publisher.trim(),
        'issn': issn.trim(),
        'scopes': scopes,
        'supportsIeee': supportsIeee,
        'supportsApa': supportsApa,
        'submissionUrl': submissionUrl.trim(),
        'partnerUniversity': partnerUniversity.trim(),
        'approvalStatus': approvalStatus,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory PublishJournal.fromMap(Map<String, dynamic> map, {String? id}) {
    return PublishJournal(
      id: id,
      name: map['name']?.toString() ?? '',
      publisher: map['publisher']?.toString() ?? '',
      issn: map['issn']?.toString() ?? '',
      scopes: map['scopes'] is List
          ? (map['scopes'] as List).map((e) => e.toString()).toList()
          : const [],
      supportsIeee: map['supportsIeee'] as bool? ?? true,
      supportsApa: map['supportsApa'] as bool? ?? true,
      submissionUrl: map['submissionUrl']?.toString() ?? '',
      partnerUniversity: map['partnerUniversity']?.toString() ?? '',
      approvalStatus: map['approvalStatus']?.toString() ?? 'pending',
      createdBy: map['createdBy']?.toString() ?? '',
    );
  }
}

String encodeBlocks(List<ManuscriptBlock> blocks) =>
    jsonEncode(blocks.map((b) => b.toMap()).toList());

List<ManuscriptBlock> decodeBlocks(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map>()
        .map((e) => ManuscriptBlock.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return const [];
  }
}
