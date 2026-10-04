import 'dart:convert';

import 'package:http/http.dart' as http;

import 'egypt_academic_books_seed.dart';
import 'open_library_books_service.dart';

/// كتب عربية مفتوحة من Internet Archive (مشروع قانوني للملكية العامة/الإتاحة).
class InternetArchiveBooksService {
  InternetArchiveBooksService._();
  static final InternetArchiveBooksService instance =
      InternetArchiveBooksService._();

  static const _pageSize = 48;
  static const _base = 'https://archive.org/advancedsearch.php';

  static const Map<String, String> facultyArabicQueries = {
    'Education':
        '(تربية OR مناهج OR تعليم OR "علم النفس" OR pedagogy OR education OR curriculum)',
    'Law': '(قانون OR حقوق OR تشريع OR قضاء OR law OR jurisprudence)',
    'Arts': '(أدب OR نقد OR لغة OR شعر OR رواية OR literature OR arabic)',
    'Business': '(إدارة OR اقتصاد OR محاسبة OR تسويق OR economics OR management)',
    'MassCommunication':
        '(إعلام OR صحافة OR إذاعة OR journalism OR media OR communication)',
    'Medicine': '(طب OR طبي OR جراحة OR medicine OR medical OR anatomy)',
    'Pharmacy': '(صيدلة OR أدوية OR pharmacy OR pharmacology)',
    'Dentistry': '(أسنان OR "طب أسنان" OR dentistry OR dental)',
    'Nursing': '(تمريض OR nursing OR midwifery)',
    'Veterinary': '(بيطري OR بيطرة OR veterinary)',
    'Engineering': '(هندسة OR ميكانيكا OR engineering OR electrical OR civil)',
    'Science': '(علوم OR كيمياء OR فيزياء OR أحياء OR biology OR chemistry OR physics)',
    'CS':
        '(حاسبات OR برمجة OR حاسوب OR "ذكاء اصطناعي" OR "computer science" OR programming)',
    'Agriculture': '(زراعة OR محاصيل OR agriculture OR agronomy)',
    'Architecture': '(عمارة OR معماري OR architecture OR urban)',
    'Tourism': '(سياحة OR فنادق OR آثار OR tourism OR egyptology)',
    'FineArts': '(فنون OR رسم OR نحت OR "fine arts" OR painting)',
    'PhysicalEducation':
        '("تربية رياضية" OR رياضة OR sport OR "physical education")',
    'ProfessionalStudies':
        '("دراسات مهنية" OR دبلوم OR "higher education" OR vocational)',
  };

  Future<OpenLibraryPage> fetchFacultyPage({
    required String facultyId,
    int page = 1,
    String? searchText,
  }) async {
    final topic = facultyArabicQueries[facultyId] ??
        '(كتاب OR دراسة OR بحث OR book OR research)';
    final userQ = searchText?.trim();
    final qParts = <String>[
      'mediatype:texts',
      '(language:ara OR language:arabic OR language:"Arabic")',
      topic,
    ];
    if (userQ != null && userQ.isNotEmpty) {
      qParts.add('($userQ)');
    }

    final manual = Uri.parse(
      '$_base?q=${Uri.encodeQueryComponent(qParts.join(' AND '))}'
      '&fl[]=identifier&fl[]=title&fl[]=creator&fl[]=year'
      '&rows=$_pageSize&page=$page&output=json&sort[]=${Uri.encodeQueryComponent('downloads desc')}',
    );

    final res = await http.get(manual, headers: {
      'User-Agent': 'AcadeGate/1.0 (academic research app)',
      'Accept': 'application/json',
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Internet Archive HTTP ${res.statusCode}');
    }

    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final response = map['response'] as Map<String, dynamic>? ?? const {};
    final numFound = (response['numFound'] as num?)?.toInt() ?? 0;
    final docs =
        (response['docs'] as List<dynamic>? ?? const []).whereType<Map>();
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
    final id = (doc['identifier'] ?? '').toString().trim();
    final title = (doc['title'] ?? '').toString().trim();
    if (id.isEmpty || title.isEmpty) return null;
    final creator = doc['creator'];
    final author = creator is List
        ? creator.map((e) => e.toString()).take(2).join(', ')
        : (creator?.toString() ?? '');
    final year = (doc['year'] ?? '').toString();
    return SeedAcademicBook(
      id: 'ia_${facultyId}_$id'.toLowerCase(),
      facultyId: facultyId,
      titleAr: title,
      titleEn: title,
      author: author.isEmpty ? 'Internet Archive' : author,
      publisher: 'Internet Archive',
      year: year,
      isbn: '',
      coverUrl: 'https://archive.org/services/img/$id',
      sourceUrl: 'https://archive.org/details/$id',
      noteAr: 'نص عربي/رقمي عبر Internet Archive (إتاحة مشروعة حسب حالة كل عمل).',
      noteEn: 'Arabic/digital text via Internet Archive (availability depends on each item).',
    );
  }
}
