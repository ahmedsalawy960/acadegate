import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/app_translate.dart';
import '../../../core/locale/locale_extensions.dart';
import '../../../core/widgets/acadegate_app_bar.dart';
import '../../auth/auth_guard.dart';
import '../store_catalog_service.dart';
import '../store_product_navigation.dart';
import '../store_theme.dart';
import 'store_product_discover_models.dart';
import 'store_product_discover_service.dart';

/// بحث بالوصف عبر كتالوج التطبيق + متاجر الموردين + الإنترنت.
class StoreProductDiscoverScreen extends StatefulWidget {
  final String? initialQuery;

  const StoreProductDiscoverScreen({super.key, this.initialQuery});

  @override
  State<StoreProductDiscoverScreen> createState() =>
      _StoreProductDiscoverScreenState();
}

class _StoreProductDiscoverScreenState
    extends State<StoreProductDiscoverScreen> {
  late final TextEditingController _ctrl;
  bool _loading = false;
  ProductDiscoverResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery ?? '');
    if ((widget.initialQuery ?? '').trim().length >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await StoreProductDiscoverService.instance.discover(
        description: _ctrl.text,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = result.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(
            context.t('بحث بالمواصفات', 'Search by specs'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              context.t(
                'اكتب وصفاً قصيراً أو كلمات إنجليزية للمنتج. نبحث في كتالوج AcadeGate ومتاجر WooCommerce المرتبطة فقط؛ '
                'باقي الموردين المستوردين دليل اتصال. الإنترنت = روابط بحث عامة وليست مسحاً لكل المواقع.',
                'Type a short description or English product keywords. We search the AcadeGate catalog and linked WooCommerce stores only; '
                'other imported suppliers are contact listings. The web step opens public search links — not a crawl of every site.',
              ),
              style: const TextStyle(
                color: StoreTheme.muted,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: context.t('الوصف / المواصفات', 'Description / specs'),
                hintText: context.t(
                  'مثال: مرشح 0.22 ميكرون PTFE متوافق مع حقنة، أو حامل عينة SEM…',
                  'e.g. 0.22 µm PTFE syringe filter, or SEM sample holder…',
                ),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _run,
              style: FilledButton.styleFrom(
                backgroundColor: StoreTheme.accent,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.travel_explore),
              label: Text(
                _loading
                    ? context.t('جارٍ المسح…', 'Scanning…')
                    : context.t(
                        'امسح المتاجر والإنترنت',
                        'Scan stores & the web',
                      ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: StoreTheme.danger)),
            ],
            if (r != null) ...[
              if (r.note != null) ...[
                const SizedBox(height: 14),
                Text(
                  r.note!,
                  style: const TextStyle(fontSize: 12.5, color: StoreTheme.muted),
                ),
              ],
              if (r.keywords.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: r.keywords
                      .take(8)
                      .map(
                        (k) => Chip(
                          label: Text(k, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: StoreTheme.accentSoft,
                        ),
                      )
                      .toList(),
                ),
              ],
              _sectionTitle(
                context.t(
                  'من كتالوج AcadeGate (${r.appHits.length})',
                  'From AcadeGate catalog (${r.appHits.length})',
                ),
              ),
              if (r.appHits.isEmpty)
                Text(context.t('لا نتائج داخل التطبيق', 'No in-app matches'))
              else
                ...r.appHits.map((h) => _ProductTile(hit: h)),
              _sectionTitle(
                context.t(
                  'من متاجر الموردين على الإنترنت (${r.supplierHits.length})',
                  'From supplier stores online (${r.supplierHits.length})',
                ),
              ),
              if (r.supplierHits.isEmpty)
                Text(
                  context.t(
                    'لا نتائج حية من الموردين حالياً — يمكن استخدام روابط البحث أدناه.',
                    'No live supplier hits right now — use the web search links below.',
                  ),
                )
              else
                ...r.supplierHits.map((h) => _ProductTile(hit: h)),
              if (r.webHints.isNotEmpty) ...[
                _sectionTitle(context.t('إشارات من الويب', 'Web hints')),
                ...r.webHints.map(
                  (l) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.title),
                    subtitle: l.snippet.isEmpty ? null : Text(l.snippet),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openUrl(l.url),
                  ),
                ),
              ],
              _sectionTitle(
                context.t('بحث أوسع على الإنترنت', 'Broader web search'),
              ),
              ...r.webSearchLinks.map(
                (l) => Card(
                  child: ListTile(
                    title: Text(l.title),
                    subtitle: l.snippet.isEmpty ? null : Text(l.snippet),
                    trailing: const Icon(Icons.search),
                    onTap: () => _openUrl(l.url),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductDiscoverHit hit;
  const _ProductTile({required this.hit});

  Future<void> _open(BuildContext context) async {
    if (hit.fromAppCatalog &&
        hit.productId != null &&
        hit.productId!.isNotEmpty) {
      try {
        final bundle =
            await StoreCatalogService.instance.loadPublicCatalog();
        StoreCatalogProduct? product;
        for (final p in bundle.products) {
          if (p.id == hit.productId) {
            product = p;
            break;
          }
        }
        if (product != null && context.mounted) {
          await openStoreProductDetail(context, product);
          return;
        }
      } catch (_) {}
    }
    final url = (hit.sourceUrl ?? '').isNotEmpty ? hit.sourceUrl! : hit.website;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceLabel = hit.price > 0
        ? '${hit.price} ${appTr('ج.م', 'EGP')}'
        : context.t('السعر عند المورد', 'Price via supplier');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: hit.imageUrl != null && hit.imageUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  hit.imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) =>
                      const Icon(Icons.inventory_2_outlined),
                ),
              )
            : const Icon(Icons.inventory_2_outlined),
        title: Text(
          hit.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          '${hit.storeName}${hit.category.isNotEmpty ? ' · ${hit.category}' : ''}\n$priceLabel',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, height: 1.3),
        ),
        isThreeLine: true,
        trailing: Icon(
          hit.fromAppCatalog ? Icons.storefront : Icons.public,
          color: StoreTheme.muted,
          size: 20,
        ),
        onTap: () => _open(context),
      ),
    );
  }
}
