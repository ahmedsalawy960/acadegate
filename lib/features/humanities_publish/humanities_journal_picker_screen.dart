import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import 'humanities_journal_catalog.dart';
import 'humanities_publish_branding.dart';
import 'humanities_publish_models.dart';
import 'humanities_publish_storage.dart';

class HumanitiesJournalPickerScreen extends StatefulWidget {
  final String? initialFacultyId;

  const HumanitiesJournalPickerScreen({super.key, this.initialFacultyId});

  @override
  State<HumanitiesJournalPickerScreen> createState() =>
      _HumanitiesJournalPickerScreenState();
}

class _HumanitiesJournalPickerScreenState
    extends State<HumanitiesJournalPickerScreen> {
  static const _brand = Color(HumanitiesPublishBranding.brand);

  HumanitiesPublishDraft? _draft;
  bool _loading = true;
  String _faculty = 'Education';
  HumanitiesOutletKind? _kindFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await HumanitiesPublishStorage.instance.loadOrCreate(
      facultyId: widget.initialFacultyId,
    );
    if (!mounted) return;
    setState(() {
      _draft = d;
      _faculty = widget.initialFacultyId?.isNotEmpty == true
          ? widget.initialFacultyId!
          : d.facultyId;
      _loading = false;
    });
  }

  List<HumanitiesPublishOutlet> get _filtered {
    var list = humanitiesOutletsForFaculty(_faculty);
    if (_kindFilter != null) {
      list = list.where((o) => o.kind == _kindFilter).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (o) =>
                o.nameAr.toLowerCase().contains(q) ||
                o.nameEn.toLowerCase().contains(q) ||
                o.publisherAr.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  String _kindAr(HumanitiesOutletKind k) => switch (k) {
        HumanitiesOutletKind.facultyAnnals => 'حوليات',
        HumanitiesOutletKind.supremeCouncilJournal => 'معتمدة ترقية',
        HumanitiesOutletKind.peerReviewedArabic => 'محكمة عربية',
        HumanitiesOutletKind.conference => 'مؤتمر',
        HumanitiesOutletKind.indexedMandumah => 'منظومة',
      };

  String _kindEn(HumanitiesOutletKind k) => switch (k) {
        HumanitiesOutletKind.facultyAnnals => 'Annals',
        HumanitiesOutletKind.supremeCouncilJournal => 'Promotion-list style',
        HumanitiesOutletKind.peerReviewedArabic => 'Arabic PR',
        HumanitiesOutletKind.conference => 'Conference',
        HumanitiesOutletKind.indexedMandumah => 'Mandumah',
      };

  Future<void> _select(HumanitiesPublishOutlet o) async {
    final d = _draft;
    if (d == null) return;
    d.outletId = o.id;
    d.facultyId = _faculty;
    await HumanitiesPublishStorage.instance.save(d);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('تم اختيار «${o.nameAr}»', 'Selected “${o.nameEn}”'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('اختيار مجلة عربية', 'Pick an Arabic journal')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final selectedId = _draft?.outletId;
    final items = _filtered;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('اختيار مجلة عربية', 'Pick an Arabic journal')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t(
                  'حوليات · مجلات محكمة · مؤتمرات · اكتشاف عبر دار المنظومة. '
                  'Scopus اختياري وليس المسار الوحيد للتربية/الآداب/الحقوق.',
                  'Annals · peer-reviewed journals · conferences · Mandumah discovery. '
                  'Scopus is optional — not the only path for Education/Arts/Law.',
                ),
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: context.t('بحث باسم المجلة…', 'Search journal name…'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            context.t('الكلية', 'Faculty'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in [
                ('Education', 'تربية', 'Education'),
                ('Arts', 'آداب', 'Arts'),
                ('Law', 'حقوق', 'Law'),
                ('MassCommunication', 'إعلام', 'Media'),
                ('General', 'عام', 'General'),
              ])
                ChoiceChip(
                  label: Text(context.t(e.$2, e.$3)),
                  selected: _faculty == e.$1,
                  selectedColor: _brand.withValues(alpha: 0.22),
                  onSelected: (_) => setState(() => _faculty = e.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t('نوع المنفذ', 'Outlet type'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(context.t('الكل', 'All')),
                selected: _kindFilter == null,
                onSelected: (_) => setState(() => _kindFilter = null),
              ),
              for (final k in HumanitiesOutletKind.values)
                FilterChip(
                  label: Text(context.t(_kindAr(k), _kindEn(k))),
                  selected: _kindFilter == k,
                  onSelected: (_) => setState(() => _kindFilter = k),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.t('${items.length} منفذ', '${items.length} outlets'),
            style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          for (final o in items)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: selectedId == o.id
                  ? _brand.withValues(alpha: 0.08)
                  : null,
              child: ExpansionTile(
                leading: Icon(
                  switch (o.kind) {
                    HumanitiesOutletKind.facultyAnnals =>
                      Icons.account_balance_outlined,
                    HumanitiesOutletKind.conference => Icons.groups_outlined,
                    HumanitiesOutletKind.indexedMandumah => Icons.travel_explore,
                    _ => Icons.menu_book_outlined,
                  },
                  color: _brand,
                ),
                title: Text(
                  context.t(o.nameAr, o.nameEn),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${context.t(o.kindLabelAr(), o.kindLabelEn())}'
                  '${o.mandumahIndexed ? ' · ${context.t('منظومة', 'Mandumah')}' : ''}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Text(
                    context.t(o.publisherAr, o.publisherEn),
                    style: TextStyle(color: const Color(0xFFB7C3D6)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'الاقتباس: ${o.citationLabelAr()}',
                      'Citation: ${o.citationLabelEn()}',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(context.t(o.citationNotesAr, o.citationNotesEn)),
                  const SizedBox(height: 10),
                  Text(
                    context.t('شروط شائعة', 'Common requirements'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (var i = 0; i < o.requirementsAr.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• ${context.t(o.requirementsAr[i], o.requirementsEn[i])}',
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    context.t(o.portalHintAr, o.portalHintEn),
                    style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _select(o),
                          icon: Icon(
                            selectedId == o.id
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                          ),
                          label: Text(
                            selectedId == o.id
                                ? context.t('مختار', 'Selected')
                                : context.t('اختيار', 'Select'),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brand,
                          ),
                        ),
                      ),
                      if (o.submissionUrl.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openUrl(o.submissionUrl),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(context.t('الموقع', 'Site')),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
