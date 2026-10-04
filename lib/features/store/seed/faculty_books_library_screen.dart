import 'package:flutter/material.dart';
import '../store_theme.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../academic/faculty_categories.dart';
import 'egypt_academic_books_seed.dart';
import 'internet_archive_books_service.dart';
import 'open_library_books_service.dart';

const _booksInk = Color(0xFF18181B);
const _booksMuted = Color(0xFF57534E);

/// مكتبة كتب لكلية — جلب حي من Open Library (عربي أولاً) ببطاقات صغيرة.
class FacultyBooksLibraryScreen extends StatefulWidget {
  final String facultyId;

  const FacultyBooksLibraryScreen({super.key, required this.facultyId});

  @override
  State<FacultyBooksLibraryScreen> createState() =>
      _FacultyBooksLibraryScreenState();
}

class _FacultyBooksLibraryScreenState extends State<FacultyBooksLibraryScreen> {
  static const _brand = Color(0xFF4E342E);

  /// ~3 سم تقريباً على معظم الشاشات.
  static const double _coverSide = 78;

  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final _books = <SeedAcademicBook>[];
  final _seenIds = <String>{};

  int _page = 0;
  int _numFound = 0;
  bool _freeOnly = false;
  bool _arabicOnly = true;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _books.clear();
      _seenIds.clear();
      _hasMore = true;
      _numFound = 0;
    });
    await _loadMore(reset: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final OpenLibraryPage result;
      if (_arabicOnly) {
        result = await InternetArchiveBooksService.instance.fetchFacultyPage(
          facultyId: widget.facultyId,
          page: nextPage,
          searchText: _searchCtrl.text,
        );
      } else {
        result = await OpenLibraryBooksService.instance.fetchFacultyPage(
          facultyId: widget.facultyId,
          page: nextPage,
          freeOpenOnly: _freeOnly,
          arabicOnly: false,
          searchText: _searchCtrl.text,
        );
      }
      if (!mounted) return;
      for (final b in result.books) {
        if (_seenIds.add(b.id)) _books.add(b);
      }
      setState(() {
        _page = nextPage;
        _numFound = result.numFound;
        _hasMore = result.hasMore;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final faculty = facultyById(widget.facultyId);
    final title = faculty?.titleAr ?? widget.facultyId;

    return Theme(
      data: StoreTheme.overlay(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF7F3EE),
      ),
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AcadeGateAppBar(
        title: Text(context.t('مكتبة $title', '$title library')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: _booksInk),
                  cursorColor: _booksInk,
                  decoration: InputDecoration(
                    hintText: context.t(
                      'ابحث داخل كتب الكلية…',
                      'Search within faculty books…',
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20, color: _booksInk),
                    hintStyle: const TextStyle(color: _booksMuted),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _reload(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      selected: _arabicOnly,
                      label: Text(context.t('عربي', 'Arabic')),
                      visualDensity: VisualDensity.compact,
                      onSelected: (v) {
                        setState(() => _arabicOnly = v);
                        _reload();
                      },
                    ),
                    FilterChip(
                      selected: !_arabicOnly,
                      label: Text(context.t('كل اللغات', 'All languages')),
                      visualDensity: VisualDensity.compact,
                      onSelected: (v) {
                        if (!v) return;
                        setState(() => _arabicOnly = false);
                        _reload();
                      },
                    ),
                    FilterChip(
                      selected: _freeOnly,
                      label: Text(context.t('مفتوح/مجاني', 'Free/open')),
                      visualDensity: VisualDensity.compact,
                      onSelected: _arabicOnly
                          ? null
                          : (v) {
                              setState(() => _freeOnly = v);
                              _reload();
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _loading && _books.isEmpty
                      ? context.t(
                          _arabicOnly
                              ? 'جاري جلب كتب عربية من Internet Archive…'
                              : 'جاري جلب الكتب من Open Library…',
                          _arabicOnly
                              ? 'Loading Arabic books from Internet Archive…'
                              : 'Loading books from Open Library…',
                        )
                      : context.t(
                          '≈ ${_formatCount(_numFound)} · معروض ${_books.length}'
                          '${_arabicOnly ? ' · عربي (Archive.org)' : ' · Open Library'}'
                          '${(!_arabicOnly && _freeOnly) ? ' · مفتوح' : ''}',
                          '≈ ${_formatCount(_numFound)} · showing ${_books.length}'
                          '${_arabicOnly ? ' · Arabic (Archive.org)' : ' · Open Library'}'
                          '${(!_arabicOnly && _freeOnly) ? ' · open' : ''}',
                        ),
                  style: TextStyle(fontSize: 12.5, color: _booksMuted),
                ),
                Text(
                  context.t(
                    'مصادر مشروعة فقط. لا نستخدم LibGen / Z-Library / Anna’s Archive.',
                    'Legitimate sources only. We do not use LibGen / Z-Library / Anna’s Archive.',
                  ),
                  style: TextStyle(fontSize: 11.5, color: _booksMuted, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _body(context)),
        ],
      ),
    ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t(
                  'تعذر الاتصال بـ Open Library. تحقق من الإنترنت ثم أعد المحاولة.',
                  'Could not reach Open Library. Check your connection and retry.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _reload,
                child: Text(context.t('إعادة المحاولة', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (_books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            context.t(
              'لا نتائج عربية كافية — جرّب «كل اللغات» أو إلغاء «مفتوح/مجاني».',
              'Not enough Arabic hits — try “All languages” or clear “Free/open”.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: _books.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _books.length) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final book = _books[index];
        return _MiniBookTile(
          book: book,
          coverSide: _coverSide,
          onTap: () => _showBook(context, book),
        );
      },
    );
  }

  String _formatCount(int n) {
    if (n <= 0) return '0';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  void _showBook(BuildContext context, SeedAcademicBook book) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(book.titleAr, book.titleEn),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              if (book.author.isNotEmpty)
                Text(book.author, style: TextStyle(color: _booksMuted)),
              const SizedBox(height: 4),
              Text(
                [
                  if (book.publisher.isNotEmpty) book.publisher,
                  if (book.year.isNotEmpty) book.year,
                  if (book.isbn.isNotEmpty) 'ISBN ${book.isbn}',
                ].join(' · '),
                style: TextStyle(fontSize: 12.5, color: _booksMuted),
              ),
              const SizedBox(height: 12),
              Text(
                context.t(book.noteAr, book.noteEn),
                style: TextStyle(height: 1.45, color: _booksMuted),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _brand),
                  onPressed: () async {
                    final uri = Uri.tryParse(book.sourceUrl);
                    if (uri == null) return;
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(
                    context.t(
                      _arabicOnly ? 'فتح على Internet Archive' : 'فتح على Open Library',
                      _arabicOnly ? 'Open on Internet Archive' : 'Open on Open Library',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniBookTile extends StatelessWidget {
  final SeedAcademicBook book;
  final double coverSide;
  final VoidCallback onTap;

  const _MiniBookTile({
    required this.book,
    required this.coverSide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          SizedBox(
            width: coverSide,
            height: coverSide * 1.25,
            child: _Cover(url: book.coverUrl),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              context.t(book.titleAr, book.titleEn),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: _booksInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String url;

  const _Cover({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E0D8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.menu_book, color: Color(0xFF8D6E63), size: 22),
    );

    if (url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder;
        },
      ),
    );
  }
}
