import 'dart:convert';

import 'package:http/http.dart' as http;

import 'egypt_academic_books_seed.dart';

/// نتيجة صفحة من Open Library لكلية واحدة.
class OpenLibraryPage {
  final int numFound;
  final int page;
  final List<SeedAcademicBook> books;
  final bool hasMore;

  const OpenLibraryPage({
    required this.numFound,
    required this.page,
    required this.books,
    required this.hasMore,
  });
}

/// جلب حي لكتب حسب الكلية من Open Library (مصادر مشروعة فقط).
class OpenLibraryBooksService {
  OpenLibraryBooksService._();
  static final OpenLibraryBooksService instance = OpenLibraryBooksService._();

  static const _pageSize = 48;
  static const _base = 'https://openlibrary.org/search.json';

  /// استعلامات موضوعية (إنجليزي) لكل كلية.
  static const Map<String, String> facultyQueries = {
    'Education':
        'subject:(education OR pedagogy OR "educational psychology" OR curriculum OR teaching)',
    'Law':
        'subject:(law OR jurisprudence OR "civil law" OR "constitutional law" OR "criminal law")',
    'Arts':
        'subject:(literature OR "literary criticism" OR "arabic literature" OR linguistics OR history)',
    'Business':
        'subject:(management OR "business administration" OR economics OR marketing OR finance)',
    'MassCommunication':
        'subject:(journalism OR "mass communication" OR media OR "public relations")',
    'Medicine': 'subject:(medicine OR "medical sciences" OR physiology OR anatomy)',
    'Pharmacy': 'subject:(pharmacy OR pharmacology OR "pharmaceutical sciences")',
    'Dentistry': 'subject:(dentistry OR "dental medicine" OR orthodontics)',
    'Nursing': 'subject:(nursing OR "nursing care" OR midwifery)',
    'Veterinary': 'subject:("veterinary medicine" OR "animal health")',
    'Engineering':
        'subject:(engineering OR "mechanical engineering" OR "civil engineering" OR "electrical engineering")',
    'Science':
        'subject:(biology OR chemistry OR physics OR mathematics OR geology)',
    'CS':
        'subject:("computer science" OR algorithms OR programming OR "artificial intelligence")',
    'Agriculture':
        'subject:(agriculture OR agronomy OR "soil science" OR horticulture)',
    'Architecture':
        'subject:(architecture OR "architectural design" OR "urban planning")',
    'Tourism':
        'subject:(tourism OR hospitality OR egyptology OR "travel guide")',
    'FineArts':
        'subject:("fine arts" OR painting OR sculpture OR "art history")',
    'PhysicalEducation':
        'subject:("physical education" OR "sports science" OR kinesiology OR athletics)',
    'ProfessionalStudies':
        'subject:("professional development" OR "higher education" OR "vocational education")',
  };

  /// كلمات عربية لتعزيز نتائج اللغة العربية لكل كلية.
  static const Map<String, String> facultyArabicKeywords = {
    'Education': 'تربية OR مناهج OR "علم النفس التربوي" OR تعليم OR معلم',
    'Law': 'قانون OR حقوق OR تشريع OR قضاء OR دستوري',
    'Arts': 'أدب OR نقد OR لغة OR شعر OR رواية OR تاريخ',
    'Business': 'إدارة OR اقتصاد OR محاسبة OR تسويق OR مالية',
    'MassCommunication': 'إعلام OR صحافة OR إذاعة OR تلفزيون OR اتصال',
    'Medicine': 'طب OR طبي OR جراحة OR تشريح OR فسيولوجيا',
    'Pharmacy': 'صيدلة OR أدوية OR فارماكولوجيا',
    'Dentistry': 'أسنان OR طب أسنان OR فم',
    'Nursing': 'تمريض OR ممرض',
    'Veterinary': 'بيطري OR بيطرة',
    'Engineering': 'هندسة OR ميكانيكا OR كهرباء OR مدني',
    'Science': 'علوم OR كيمياء OR فيزياء OR أحياء OR رياضيات',
    'CS': 'حاسبات OR برمجة OR حاسوب OR ذكاء اصطناعي',
    'Agriculture': 'زراعة OR محاصيل OR تربة',
    'Architecture': 'عمارة OR معماري OR تخطيط عمراني',
    'Tourism': 'سياحة OR فنادق OR آثار',
    'FineArts': 'فنون OR رسم OR نحت OR تشكيلية',
    'PhysicalEducation': 'تربية رياضية OR رياضة OR تدريب',
    'ProfessionalStudies': 'دراسات مهنية OR دبلوم OR تدريب',
  };

  Future<OpenLibraryPage> fetchFacultyPage({
    required String facultyId,
    int page = 1,
    bool freeOpenOnly = false,
    bool arabicOnly = true,
    String? searchText,
  }) async {
    final subjectEn =
        facultyQueries[facultyId] ?? 'subject:(education OR science OR literature)';
    final arKeys = facultyArabicKeywords[facultyId] ?? 'بحث OR دراسة OR كتاب';

    final parts = <String>[];
    if (arabicOnly) {
      // لغة عربية + (موضوع إنجليزي أو كلمات عربية في العنوان/النص).
      parts.add('language:ara');
      parts.add('($subjectEn OR title:($arKeys) OR subject:($arKeys))');
    } else {
      parts.add(subjectEn);
    }
    if (freeOpenOnly) {
      parts.add('has_fulltext:true');
    }
    final q = searchText?.trim();
    if (q != null && q.isNotEmpty) {
      parts.add('($q)');
    }

    final uri = Uri.parse(_base).replace(queryParameters: {
      'q': parts.join(' AND '),
      'limit': '$_pageSize',
      'page': '$page',
      'fields':
          'key,title,author_name,first_publish_year,isbn,cover_i,publisher,ebook_access,has_fulltext,ia,edition_count,language',
    });

    final res = await http.get(uri, headers: {
      'User-Agent': 'AcadeGate/1.0 (academic research app; contact@acadegate.local)',
      'Accept': 'application/json',
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Open Library HTTP ${res.statusCode}');
    }

    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final numFound = (map['numFound'] as num?)?.toInt() ??
        (map['num_found'] as num?)?.toInt() ??
        0;
    final docs = (map['docs'] as List<dynamic>? ?? const []).whereType<Map>();
    final books = <SeedAcademicBook>[];
    for (final doc in docs) {
      final book = _mapDoc(doc, facultyId);
      if (book != null) books.add(book);
    }

    final loaded = page * _pageSize;
    return OpenLibraryPage(
      numFound: numFound,
      page: page,
      books: books,
      hasMore: loaded < numFound && books.isNotEmpty,
    );
  }

  SeedAcademicBook? _mapDoc(Map doc, String facultyId) {
    final title = (doc['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;
    final key = (doc['key'] ?? '').toString();
    final authors = (doc['author_name'] is List)
        ? (doc['author_name'] as List).map((e) => e.toString()).take(3).join(', ')
        : 'Unknown';
    final pubs = (doc['publisher'] is List)
        ? (doc['publisher'] as List).map((e) => e.toString()).take(1).join()
        : '';
    String isbn = '';
    if (doc['isbn'] is List && (doc['isbn'] as List).isNotEmpty) {
      final list = (doc['isbn'] as List).map((e) => e.toString()).toList();
      isbn = list.firstWhere((e) => e.length == 13, orElse: () => list.first);
    }
    final year = (doc['first_publish_year'] ?? '').toString();
    final coverId = doc['cover_i'];
    final coverUrl = coverId != null
        ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
        : (isbn.isNotEmpty
            ? 'https://covers.openlibrary.org/b/isbn/$isbn-M.jpg'
            : '');
    final workPath = key.isNotEmpty ? key : '';
    final sourceUrl = workPath.isNotEmpty
        ? 'https://openlibrary.org$workPath'
        : 'https://openlibrary.org/search?q=${Uri.encodeQueryComponent(title)}';
    final hasFull = doc['has_fulltext'] == true;
    final access = (doc['ebook_access'] ?? '').toString();
    final free = hasFull ||
        access == 'public' ||
        access == 'borrowable' ||
        access == 'printdisabled';
    final idBase =
        workPath.replaceAll('/works/', '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return SeedAcademicBook(
      id: '${facultyId}_${idBase.isEmpty ? title.hashCode : idBase}'.toLowerCase(),
      facultyId: facultyId,
      titleAr: title,
      titleEn: title,
      author: authors,
      publisher: pubs.isEmpty ? 'Open Library' : pubs,
      year: year,
      isbn: isbn,
      coverUrl: coverUrl,
      sourceUrl: sourceUrl,
      noteAr: free
          ? 'متاح للاطلاع/استعارة رقمية عبر Open Library أو Archive.org'
          : 'سجل ببليوجرافي من Open Library',
      noteEn: free
          ? 'Readable/borrowable via Open Library or Archive.org'
          : 'Bibliographic record from Open Library',
    );
  }
}
