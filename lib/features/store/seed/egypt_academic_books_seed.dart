import 'dart:convert';

import 'package:flutter/services.dart';

import '../../academic/faculty_categories.dart';

/// كتاب حقيقي من Open Library — يُعرض داخل مكتبة كل كلية.
class SeedAcademicBook {
  final String id;
  final String facultyId;
  final String titleAr;
  final String titleEn;
  final String author;
  final String publisher;
  final String year;
  final String isbn;
  final String coverUrl;
  final String sourceUrl;
  final String noteAr;
  final String noteEn;

  const SeedAcademicBook({
    required this.id,
    required this.facultyId,
    required this.titleAr,
    required this.titleEn,
    required this.author,
    required this.publisher,
    required this.year,
    this.isbn = '',
    this.coverUrl = '',
    required this.sourceUrl,
    this.noteAr = '',
    this.noteEn = '',
  });

  factory SeedAcademicBook.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString().trim();
    return SeedAcademicBook(
      id: (json['id'] ?? '').toString(),
      facultyId: (json['facultyId'] ?? '').toString(),
      titleAr: title,
      titleEn: title,
      author: (json['author'] ?? '').toString(),
      publisher: (json['publisher'] ?? '').toString(),
      year: (json['year'] ?? '').toString(),
      isbn: (json['isbn'] ?? '').toString(),
      coverUrl: (json['coverUrl'] ?? '').toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
      noteAr: 'سجل ببليوجرافي من Open Library',
      noteEn: 'Bibliographic record from Open Library',
    );
  }

  String facultyTitleAr() =>
      facultyById(facultyId)?.titleAr ?? facultyId;
}

/// كتالوج كتب Open Library حسب الكلية (يُحمَّل مرة واحدة من الأصول).
class AcademicBooksCatalog {
  AcademicBooksCatalog._();

  static final AcademicBooksCatalog instance = AcademicBooksCatalog._();

  /// مسارات بديلة — Flutter Web يفشل أحياناً إن لم يُدرَج الملف صراحة في pubspec.
  static const _assetPaths = <String>[
    'assets/seed_data/books/open_library_faculty_books.json',
    'seed_data/books/open_library_faculty_books.json',
  ];

  List<SeedAcademicBook>? _cache;
  Future<List<SeedAcademicBook>>? _loading;
  String? lastError;

  List<SeedAcademicBook> get booksOrEmpty => _cache ?? const [];

  int get count => booksOrEmpty.length;

  Future<List<SeedAcademicBook>> ensureLoaded() async {
    if (_cache != null) return _cache!;
    if (_loading != null) return _loading!;
    final future = _loadSafe();
    _loading = future;
    return future;
  }

  Future<List<SeedAcademicBook>> _loadSafe() async {
    try {
      final list = await _load();
      _cache = list;
      lastError = null;
      return list;
    } catch (e) {
      lastError = e.toString();
      _cache = const [];
      _loading = null;
      return _cache!;
    }
  }

  Future<List<SeedAcademicBook>> _load() async {
    Object? last;
    for (final path in _assetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return (map['books'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => SeedAcademicBook.fromJson(Map<String, dynamic>.from(e)))
            .where((b) => b.id.isNotEmpty && b.titleEn.isNotEmpty)
            .toList(growable: false);
      } catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('Book catalog asset missing');
  }

  List<SeedAcademicBook> booksForFaculty(String? facultyId) {
    final all = booksOrEmpty;
    if (facultyId == null || facultyId.isEmpty) return all;
    return all.where((b) => b.facultyId == facultyId).toList(growable: false);
  }

  /// كليات لها كتب في الكتالوج، أو كل الكليات إن كان التحميل فشل/فارغاً.
  List<String> facultyIds() {
    final ids = <String>{};
    for (final b in booksOrEmpty) {
      ids.add(b.facultyId);
    }
    if (ids.isEmpty) {
      return facultyCategoryIds();
    }
    return facultyCategoryIds().where(ids.contains).toList();
  }
}

List<SeedAcademicBook> booksForFaculty(String? facultyId) =>
    AcademicBooksCatalog.instance.booksForFaculty(facultyId);

List<String> bookFacultyIdsInSeed() => AcademicBooksCatalog.instance.facultyIds();

List<SeedAcademicBook> get egyptAcademicBooksSeed =>
    AcademicBooksCatalog.instance.booksOrEmpty;
