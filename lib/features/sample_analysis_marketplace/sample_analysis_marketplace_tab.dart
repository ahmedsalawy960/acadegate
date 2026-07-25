import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/arrow_scroll_view.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../lab_import/crci_catalog.dart';
import '../lab_import/nbsle_university_cities.dart';
import 'sample_analysis_listing_card.dart';
import 'sample_analysis_marketplace_detail_screen.dart';
import 'sample_analysis_marketplace_listing.dart';
import 'sample_analysis_marketplace_service.dart';

/// Embedded tab: browse sample analysis services (marketplace listings).
class SampleAnalysisMarketplaceTab extends StatefulWidget {
  const SampleAnalysisMarketplaceTab({super.key});

  @override
  State<SampleAnalysisMarketplaceTab> createState() =>
      _SampleAnalysisMarketplaceTabState();
}

class _SampleAnalysisMarketplaceTabState
    extends State<SampleAnalysisMarketplaceTab> {
  static const _brand = Color(0xFF00695C);
  static const _allCities = '';
  static const _allUniversities = '';

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<AcademicLab> _labs = const [];
  bool _loading = false;
  String _city = _allCities;
  String _university = _allUniversities;
  String? _facultyId;
  SampleMarketplaceSort _sort = SampleMarketplaceSort.recommended;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasFocus {
    final q = _searchController.text.trim();
    return q.length >= 2 ||
        (_facultyId?.isNotEmpty ?? false) ||
        _city.isNotEmpty ||
        _university.isNotEmpty;
  }

  Future<void> _reload() async {
    if (!_hasFocus) {
      setState(() {
        _labs = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final labs = await AcademicContentService.instance.searchLabs(
        query: _searchController.text.trim(),
        facultyId: _facultyId,
        city: _city.isEmpty ? null : _city,
        university: _university.isEmpty ? null : _university,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _labs = labs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  String _sortLabel(SampleMarketplaceSort sort) {
    return switch (sort) {
      SampleMarketplaceSort.recommended => context.t('الأنسب', 'Recommended'),
      SampleMarketplaceSort.priceAsc => context.t('السعر ↑', 'Price ↑'),
      SampleMarketplaceSort.turnaroundAsc => context.t('الأسرع', 'Fastest'),
      SampleMarketplaceSort.ratingDesc => context.t('التقييم', 'Rating'),
    };
  }

  List<String> get _cityOptions {
    final fromData = _labs
        .map((l) => l.city.trim())
        .where((c) => c.isNotEmpty)
        .toSet();
    final merged = {
      ...NbsleUniversityCities.browseCities,
      ...fromData,
    }.toList()
      ..sort();
    return merged;
  }

  List<String> get _universityOptions {
    final fromData = _labs
        .map((l) => l.university.trim())
        .where((u) => u.isNotEmpty)
        .toSet();
    final merged = {
      ...NbsleUniversityCities.browseUniversities,
      ...fromData,
    }.toList()
      ..sort();
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    var filtered = SampleAnalysisMarketplaceService.instance.buildListings(
      labs: _labs,
      query: query,
      city: _city,
      facultyId: _facultyId ?? '',
    );
    filtered = filtered.where((item) {
      if (_university.isEmpty) return true;
      return NbsleUniversityCities.universityMatches(
        item.university,
        _university,
      );
    }).toList();
    filtered = SampleAnalysisMarketplaceService.instance.filterAndSort(
      listings: filtered,
      query: query,
      city: _city,
      facultyId: _facultyId ?? '',
      sort: _sort,
    );
    final visibleCap = _hasFocus
        ? SampleAnalysisMarketplaceService.maxVisibleListingsFocused
        : SampleAnalysisMarketplaceService.maxVisibleListings;
    final truncated = filtered.length > visibleCap;
    if (truncated) {
      filtered = filtered.take(visibleCap).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _introBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.t(
                'ابحث: XRD، HPLC، جامعة... (حرفان على الأقل)',
                'Search: XRD, HPLC, university... (min 2 chars)',
              ),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) {
              setState(() {});
              _scheduleReload();
            },
          ),
        ),
        _filterBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.t(
              _hasFocus
                  ? truncated
                      ? 'عرض أول ${filtered.length} خدمة — ضيّق الفلاتر للمزيد'
                      : '${filtered.length} خدمة تحليل'
                  : 'اختر الكلية أو الجامعة أو المدينة لتحميل المختبرات',
              _hasFocus
                  ? truncated
                      ? 'Showing first ${filtered.length} services — narrow filters for more'
                      : '${filtered.length} analysis services'
                  : 'Pick faculty, university, or city to load labs',
            ),
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.t(
                            _hasFocus
                                ? 'لا توجد خدمات مطابقة — جرّب فلتراً آخر'
                                : 'لا نحمّل آلاف مختبرات NBSLE دفعة واحدة — اختر كلية أو جامعة أو مدينة',
                            _hasFocus
                                ? 'No matching services — try another filter'
                                : 'We do not load thousands of NBSLE labs at once — pick faculty, university, or city',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ArrowListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final listing = filtered[index];
                        return SampleAnalysisListingCard(
                          listing: listing,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SampleAnalysisMarketplaceDetailScreen(
                                listing: listing,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _introBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brand.withValues(alpha: 0.2)),
      ),
      child: Text(
        context.t(
          'اختر خدمة تحليل جاهزة — أرسل عينتك واستلم تقريراً (SEM، XRD، HPLC، PCR...)',
          'Pick a ready analysis service — send your sample, get a report (SEM, XRD, HPLC, PCR...)',
        ),
        style: const TextStyle(height: 1.45),
      ),
    );
  }

  Widget _filterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
          child: Text(
            context.t('المدن (استخدم الأسهم لرؤية الكل)', 'Cities (use arrows to see all)'),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        ArrowScrollView(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          arrowColor: _brand,
          child: Row(
            children: [
              FilterChip(
                label: Text(context.t('كل المدن', 'All cities')),
                selected: _city.isEmpty,
                onSelected: (_) {
                  setState(() => _city = _allCities);
                  _reload();
                },
              ),
              ..._cityOptions.map(
                (city) => Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: FilterChip(
                    label: Text(city),
                    selected: _city == city,
                    onSelected: (_) {
                      setState(() => _city = city);
                      _reload();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(CrciCatalog.affiliationShortAr),
                selected: _university.contains('CRCI'),
                avatar: const Icon(Icons.apartment, size: 18),
                onSelected: (_) {
                  setState(() {
                    _university = _university.contains('CRCI')
                        ? _allUniversities
                        : CrciCatalog.affiliationAr;
                    _city = _allCities;
                  });
                  _reload();
                },
              ),
              FilterChip(
                label: Text(
                  _university.isEmpty || _university.contains('CRCI')
                      ? context.t('كل الجامعات', 'All universities')
                      : _university,
                ),
                selected: _university.isNotEmpty && !_university.contains('CRCI'),
                onSelected: (_) async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => SizedBox(
                      height: MediaQuery.of(ctx).size.height * 0.7,
                      child: ArrowListView(
                        itemCount: _universityOptions.length + 1,
                        itemBuilder: (ctx, index) {
                          if (index == 0) {
                            return ListTile(
                              title: Text(
                                ctx.t('كل الجامعات', 'All universities'),
                              ),
                              onTap: () => Navigator.pop(ctx, ''),
                            );
                          }
                          final uni = _universityOptions[index - 1];
                          return ListTile(
                            title: Text(uni),
                            onTap: () => Navigator.pop(ctx, uni),
                          );
                        },
                      ),
                    ),
                  );
                  if (picked == null) return;
                  setState(() => _university = picked);
                  _reload();
                },
              ),
              FilterChip(
                label: Text(
                  _facultyId == null
                      ? context.t('كل التخصصات', 'All fields')
                      : L10nLookup.facultyTitleStatic(_facultyId!),
                ),
                selected: _facultyId != null,
                onSelected: (_) async {
                  final ids = facultyCategoryIds().toList();
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    builder: (ctx) => ArrowListView(
                      itemCount: ids.length + 1,
                      itemBuilder: (ctx, index) {
                        if (index == 0) {
                          return ListTile(
                            title: Text(ctx.t('كل التخصصات', 'All fields')),
                            onTap: () => Navigator.pop(ctx, ''),
                          );
                        }
                        final id = ids[index - 1];
                        return ListTile(
                          title: Text(L10nLookup.facultyTitleStatic(id)),
                          onTap: () => Navigator.pop(ctx, id),
                        );
                      },
                    ),
                  );
                  if (picked == null) return;
                  setState(() => _facultyId = picked.isEmpty ? null : picked);
                  _reload();
                },
              ),
              PopupMenuButton<SampleMarketplaceSort>(
                initialValue: _sort,
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (ctx) => SampleMarketplaceSort.values
                    .map(
                      (s) => PopupMenuItem(
                        value: s,
                        child: Text(_sortLabel(s)),
                      ),
                    )
                    .toList(),
                child: Chip(
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Text(_sortLabel(_sort)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}