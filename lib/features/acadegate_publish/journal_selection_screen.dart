import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import '../home/section_search_field.dart';
import '../supervisor_metrics/scimago_quartile_service.dart';
import 'journal_format_apply_screen.dart';
import 'journal_guidelines_service.dart';
import 'admin_journal_form_screen.dart';
import 'publish_models.dart';
import 'publish_services.dart';

class JournalPickItem {
  final String id;
  final String name;
  final String publisher;
  final String quartile;
  final double? sjr;
  final String categories;
  final String issn;
  final String submissionUrl;
  final bool isPartner;
  final String? partnerUniversity;
  final bool? supportsIeee;
  final bool? supportsApa;

  const JournalPickItem({
    required this.id,
    required this.name,
    this.publisher = '',
    this.quartile = '',
    this.sjr,
    this.categories = '',
    this.issn = '',
    this.submissionUrl = '',
    this.isPartner = false,
    this.partnerUniversity,
    this.supportsIeee,
    this.supportsApa,
  });

  factory JournalPickItem.fromFirebase(PublishJournal journal) {
    return JournalPickItem(
      id: journal.id ?? 'partner:${journal.name}',
      name: journal.name,
      publisher: journal.publisher,
      quartile: '',
      categories: journal.scopes.join(' • '),
      issn: journal.issn,
      submissionUrl: journal.submissionUrl.trim(),
      isPartner: true,
      partnerUniversity: journal.partnerUniversity,
      supportsIeee: journal.supportsIeee,
      supportsApa: journal.supportsApa,
    );
  }

  factory JournalPickItem.fromScimago(ScimagoJournalInfo journal) {
    return JournalPickItem(
      id: 'scimago:${journal.title}',
      name: journal.title,
      publisher: journal.publisher,
      quartile: journal.quartile,
      sjr: journal.sjr,
      categories: journal.categories,
      issn: journal.issn,
    );
  }
}

class JournalSelectionScreen extends StatefulWidget {
  final String manuscriptId;

  const JournalSelectionScreen({super.key, required this.manuscriptId});

  @override
  State<JournalSelectionScreen> createState() => _JournalSelectionScreenState();
}

class _JournalSelectionScreenState extends State<JournalSelectionScreen> {
  static const _brand = Color(0xFF4A148C);

  String _searchQuery = '';
  String? _quartileFilter;
  bool _loadingCatalog = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _loadError = null;
    });
    try {
      await ScimagoQuartileService.instance.ensureLoaded();
      if (!mounted) return;
      setState(() => _loadingCatalog = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _loadError = '$e';
      });
    }
  }

  List<JournalPickItem> _buildItems(List<PublishJournal> partners) {
    final partnerTitles = partners
        .map((j) => j.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();

    final partnerItems = partners
        .map(JournalPickItem.fromFirebase)
        .where((item) {
          if (_searchQuery.trim().isEmpty) return true;
          return _matchesQuery(item);
        })
        .toList();

    final scimagoItems = ScimagoQuartileService.instance
        .searchCatalog(
          query: _searchQuery,
          quartile: _quartileFilter,
          limit: 300,
        )
        .where(
          (journal) => !partnerTitles.contains(journal.title.trim().toLowerCase()),
        )
        .map(JournalPickItem.fromScimago)
        .toList();

    return [...partnerItems, ...scimagoItems];
  }

  bool _matchesQuery(JournalPickItem item) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack =
        '${item.name} ${item.publisher} ${item.categories} ${item.partnerUniversity ?? ''}'
            .toLowerCase();
    return haystack.contains(q) ||
        q.split(RegExp(r'\s+')).every((token) => haystack.contains(token));
  }

  Future<void> _pickJournal(BuildContext context, JournalPickItem item) async {
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalFormatApplyScreen(
          manuscriptId: widget.manuscriptId,
          journal: item,
        ),
      ),
    );
  }

  Future<void> _openResourceLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _quartileColor(String quartile) {
    return switch (quartile) {
      'Q1' => const Color(0xFF1B5E20),
      'Q2' => const Color(0xFF0D47A1),
      'Q3' => const Color(0xFFE65100),
      'Q4' => Colors.grey,
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('اختيار المجلة', 'Choose journal')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (snapshot.data?.isAdmin != true) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: context.t('إضافة مجلة', 'Add journal'),
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminJournalFormScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PublishJournal>>(
        stream: JournalCatalogService.instance.watchApproved(),
        builder: (context, partnerSnapshot) {
          final partners = partnerSnapshot.data ?? [];
          final items = _loadingCatalog ? <JournalPickItem>[] : _buildItems(partners);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SectionSearchField(
                  query: _searchQuery,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onClear: () => setState(() => _searchQuery = ''),
                  hint: context.t(
                    'ابحث باسم المجلة، الناشر، أو التخصص...',
                    'Search by journal, publisher, or field...',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _QuartileChip(
                      label: context.t('الكل', 'All'),
                      selected: _quartileFilter == null,
                      onTap: () => setState(() => _quartileFilter = null),
                    ),
                    for (final q in const ['Q1', 'Q2', 'Q3', 'Q4'])
                      _QuartileChip(
                        label: q,
                        selected: _quartileFilter == q,
                        color: _quartileColor(q),
                        onTap: () => setState(() => _quartileFilter = q),
                      ),
                  ],
                ),
              ),
              if (_loadingCatalog)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _loadError != null
                                ? context.t(
                                    'تعذّر تحميل كتالوج المجلات',
                                    'Could not load journal catalog',
                                  )
                                : context.t(
                                    'لا توجد مجلات مطابقة',
                                    'No matching journals',
                                  ),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_loadError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _loadCatalog,
                              child: Text(context.t('إعادة المحاولة', 'Retry')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          context.t(
                            '${items.length} مجلة — اختر المجلة ثم راجع دليل المؤلفين',
                            '${items.length} journals — pick one then verify author guidelines',
                          ),
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () => _pickJournal(context, item),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          if (item.isPartner)
                                            Chip(
                                              label: Text(
                                                context.t('شريك', 'Partner'),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              backgroundColor: _brand
                                                  .withValues(alpha: 0.12),
                                            )
                                          else if (item.quartile.isNotEmpty)
                                            Chip(
                                              label: Text(
                                                item.quartile,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _quartileColor(
                                                    item.quartile,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                        ],
                                      ),
                                      if (item.publisher.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            item.publisher,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      if (item.partnerUniversity?.isNotEmpty ==
                                          true)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              Icon(Icons.school_outlined,
                                                  size: 15,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  item.partnerUniversity!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (item.categories.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            item.categories,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (item.sjr != null)
                                            Text(
                                              'SJR ${item.sjr!.toStringAsFixed(3)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          const Spacer(),
                                          TextButton.icon(
                                            onPressed: () => _openResourceLink(
                                              JournalGuidelinesService
                                                  .authorGuidelinesSearchUrl(
                                                item.name,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.menu_book_outlined,
                                              size: 16,
                                            ),
                                            label: Text(
                                              context.t(
                                                'دليل المؤلفين',
                                                'Author guide',
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.open_in_new,
                                            size: 18,
                                            color: _brand.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuartileChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _QuartileChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _JournalSelectionScreenState._brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: chipColor.withValues(alpha: 0.18),
        checkmarkColor: chipColor,
      ),
    );
  }
}
