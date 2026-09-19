import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/storage/storage_service.dart';
import '../../core/widgets/acadegate_app_bar.dart';
import '../admin/admin_access_gate.dart';
import 'home_feed_models.dart';
import 'home_feed_service.dart';

/// لوحة أدمن: إضافة/تعديل/حذف إعلانات الصفحة الرئيسية + زرع التخطيط.
class AdminHomeFeedScreen extends StatefulWidget {
  const AdminHomeFeedScreen({super.key});

  @override
  State<AdminHomeFeedScreen> createState() => _AdminHomeFeedScreenState();
}

class _AdminHomeFeedScreenState extends State<AdminHomeFeedScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _seed({required bool overwrite}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await HomeFeedService.instance.seedDefaults(overwrite: overwrite);
      if (!mounted) return;
      setState(() {
        _message = overwrite
            ? context.t(
                'تم استبدال أقسام وبنرات الصفحة بالقيم الافتراضية.',
                'Home sections and banners were reset to defaults.',
              )
            : context.t(
                'تم زرع الأقسام والبنرات الناقصة فقط.',
                'Missing sections and banners were seeded.',
              );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor([HomePromoBanner? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PromoBannerEditorScreen(existing: existing),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم حفظ الإعلان', 'Ad saved'),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(HomePromoBanner banner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('حذف الإعلان؟', 'Delete this ad?')),
        content: Text(banner.titleAr.isNotEmpty ? banner.titleAr : banner.titleEn),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await HomeFeedService.instance.deleteBanner(banner.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('تم الحذف', 'Deleted'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _placementLabel(String p) {
    switch (p) {
      case 'hero':
        return context.t('بنر علوي (Hero)', 'Top hero');
      case 'mid_1':
        return context.t('إعلان وسط 1', 'Mid ad 1');
      case 'mid_2':
        return context.t('إعلان وسط 2', 'Mid ad 2');
      default:
        return p;
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';

    return AdminAccessGate(
      child: Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('إدارة الإعلانات والصفحة الرئيسية', 'Ads & home feed admin'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(context.t('إعلان جديد', 'New ad')),
      ),
      body: StreamBuilder<List<HomePromoBanner>>(
        stream: HomeFeedService.instance.watchBanners(),
        builder: (context, snap) {
          final banners = snap.data ?? const <HomePromoBanner>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Card(
                color: const Color(0xFFE8EAF6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    context.t(
                      'كمسؤول أو معلن: أضف إعلاناً، اختر المكان، ثم ضع '
                      'رابط موقعك/صفحتك (يفتح في المتصفح عند الضغط). '
                      'القسم داخل التطبيق اختياري وليس إجبارياً.\n'
                      'الإعلانات التجريبية القديمة كانت تشير لأقسام داخلية — عدّلها لرابطك.',
                      'As admin/advertiser: add an ad, choose placement, then paste '
                      'your website/page URL (opens in the browser on tap). '
                      'In-app section is optional, not required.\n'
                      'Old demo ads pointed to in-app sections — change them to your URL.',
                    ),
                    style: TextStyle(height: 1.45, color: Colors.grey[900]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('إعلاناتك', 'Your ads'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 8),
              if (snap.connectionState == ConnectionState.waiting &&
                  banners.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (banners.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    context.t(
                      'لا توجد إعلانات بعد. اضغط «إعلان جديد» أو ازرع الافتراضي.',
                      'No ads yet. Tap “New ad” or seed defaults.',
                    ),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                )
              else
                ...banners.map((b) {
                  final title = arabic ? b.titleAr : b.titleEn;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Color(b.accentColor).withValues(alpha: 0.15),
                        backgroundImage: b.imageUrl.isNotEmpty
                            ? NetworkImage(b.imageUrl)
                            : null,
                        child: b.imageUrl.isEmpty
                            ? Icon(Icons.campaign, color: Color(b.accentColor))
                            : null,
                      ),
                      title: Text(
                        title.isEmpty ? b.id : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_placementLabel(b.placement)} · '
                        '${b.linkTarget} · '
                        '${b.active ? context.t('نشط', 'Active') : context.t('متوقف', 'Off')}',
                        maxLines: 2,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _openEditor(b);
                          if (v == 'delete') _confirmDelete(b);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(context.t('تعديل', 'Edit')),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(context.t('حذف', 'Delete')),
                          ),
                        ],
                      ),
                      onTap: () => _openEditor(b),
                    ),
                  );
                }),
              const Divider(height: 36),
              Text(
                context.t('أدوات التخطيط', 'Layout tools'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _seed(overwrite: false),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  context.t(
                    'زرع الافتراضي (بدون استبدال)',
                    'Seed defaults (keep existing)',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _seed(overwrite: true),
                icon: const Icon(Icons.restart_alt),
                label: Text(
                  context.t(
                    'إعادة ضبط كاملة للقيم الافتراضية',
                    'Full reset to defaults',
                  ),
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, style: const TextStyle(color: Color(0xFF1A237E))),
              ],
            ],
          );
        },
      ),
      ),
    );
  }
}

class _PromoBannerEditorScreen extends StatefulWidget {
  final HomePromoBanner? existing;

  const _PromoBannerEditorScreen({this.existing});

  @override
  State<_PromoBannerEditorScreen> createState() =>
      _PromoBannerEditorScreenState();
}

class _PromoBannerEditorScreenState extends State<_PromoBannerEditorScreen> {
  final _titleAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _subtitleAr = TextEditingController();
  final _subtitleEn = TextEditingController();
  final _urlController = TextEditingController();
  final _ctaAr = TextEditingController();
  final _ctaEn = TextEditingController();
  final _weightController = TextEditingController(text: '3');

  String _placement = 'mid_1';
  /// الافتراضي للمعلن: رابط موقعه — القسم الداخلي اختياري فقط.
  String _linkType = 'url';
  String _routeTarget = 'store';
  String _imageUrl = '';
  bool _active = true;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleAr.text = e.titleAr;
      _titleEn.text = e.titleEn;
      _subtitleAr.text = e.subtitleAr;
      _subtitleEn.text = e.subtitleEn;
      _ctaAr.text = e.ctaAr;
      _ctaEn.text = e.ctaEn;
      _weightController.text = '${e.weight}';
      _placement = e.placement;
      _imageUrl = e.imageUrl;
      _active = e.active;
      final target = e.linkTarget.trim();
      final looksLikeUrl =
          e.linkType == 'url' || target.startsWith('http://') || target.startsWith('https://');
      if (looksLikeUrl) {
        _linkType = 'url';
        _urlController.text = target;
      } else {
        _linkType = 'route';
        final known = homeAdRouteOptions.any((o) => o.id == target);
        _routeTarget = known ? target : 'store';
      }
    } else {
      _ctaAr.text = 'اعرف المزيد';
      _ctaEn.text = 'Learn more';
      _linkType = 'url';
    }
  }

  @override
  void dispose() {
    _titleAr.dispose();
    _titleEn.dispose();
    _subtitleAr.dispose();
    _subtitleEn.dispose();
    _urlController.dispose();
    _ctaAr.dispose();
    _ctaEn.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _uploading = true);
    try {
      final file = await StorageService.instance.pickImage();
      if (file == null) return;
      final url = await StorageService.instance.uploadImage(
        file: file,
        folder: 'home_ads',
      );
      if (!mounted) return;
      if (url != null) setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final titleAr = _titleAr.text.trim();
    final titleEn = _titleEn.text.trim();
    if (titleAr.isEmpty && titleEn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('أدخل عنوان الإعلان', 'Enter an ad title'),
          ),
        ),
      );
      return;
    }

    final linkTarget = _linkType == 'url'
        ? _urlController.text.trim()
        : _routeTarget;
    if (linkTarget.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('حدد وجهة الإعلان', 'Set ad destination'),
          ),
        ),
      );
      return;
    }
    if (_linkType == 'url') {
      final uri = Uri.tryParse(linkTarget);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'الرابط يجب أن يبدأ بـ https://',
                'URL must start with https://',
              ),
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final weight = int.tryParse(_weightController.text.trim()) ?? 3;
      final kind = _placement.startsWith('mid') ? 'sponsored' : 'feature';
      final banner = HomePromoBanner(
        id: widget.existing?.id ?? '',
        titleAr: titleAr.isEmpty ? titleEn : titleAr,
        titleEn: titleEn.isEmpty ? titleAr : titleEn,
        subtitleAr: _subtitleAr.text.trim(),
        subtitleEn: _subtitleEn.text.trim(),
        imageUrl: _imageUrl.trim(),
        linkType: _linkType,
        linkTarget: linkTarget,
        placement: _placement,
        weight: weight.clamp(1, 100),
        active: _active,
        ctaAr: _ctaAr.text.trim().isEmpty ? 'اعرف المزيد' : _ctaAr.text.trim(),
        ctaEn: _ctaEn.text.trim().isEmpty ? 'Learn more' : _ctaEn.text.trim(),
        accentColor: widget.existing?.accentColor ?? 0xFF1A237E,
        kind: kind,
      );
      await HomeFeedService.instance.saveBanner(
        banner,
        docId: widget.existing?.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          widget.existing == null
              ? context.t('إعلان جديد', 'New ad')
              : context.t('تعديل الإعلان', 'Edit ad'),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.t('حفظ', 'Save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.t('مكان الظهور', 'Placement'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'hero',
                label: Text(context.t('علوي', 'Hero')),
                icon: const Icon(Icons.view_carousel, size: 18),
              ),
              ButtonSegment(
                value: 'mid_1',
                label: Text(context.t('وسط 1', 'Mid 1')),
                icon: const Icon(Icons.space_bar, size: 18),
              ),
              ButtonSegment(
                value: 'mid_2',
                label: Text(context.t('وسط 2', 'Mid 2')),
                icon: const Icon(Icons.space_bar, size: 18),
              ),
            ],
            selected: {_placement},
            onSelectionChanged: (s) => setState(() => _placement = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleAr,
            decoration: InputDecoration(
              labelText: context.t('العنوان (عربي)', 'Title (Arabic)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleEn,
            decoration: InputDecoration(
              labelText: context.t('العنوان (إنجليزي)', 'Title (English)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subtitleAr,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.t('الوصف (عربي)', 'Subtitle (Arabic)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subtitleEn,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.t('الوصف (إنجليزي)', 'Subtitle (English)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('وجهة الضغط على الإعلان', 'Ad tap destination'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'للمعلنين: ضع رابط موقعك أو صفحتك. القسم داخل التطبيق اختياري فقط.',
              'For advertisers: paste your website/page URL. In-app section is optional.',
            ),
            style: TextStyle(color: Colors.grey[700], height: 1.35, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'url',
                label: Text(context.t('رابط المعلن', 'Advertiser URL')),
                icon: const Icon(Icons.link, size: 18),
              ),
              ButtonSegment(
                value: 'route',
                label: Text(context.t('قسم بالتطبيق', 'In-app (optional)')),
                icon: const Icon(Icons.apps, size: 18),
              ),
            ],
            selected: {_linkType},
            onSelectionChanged: (s) => setState(() => _linkType = s.first),
          ),
          const SizedBox(height: 12),
          if (_linkType == 'url')
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              onChanged: (v) {
                final t = v.trim();
                if (t.startsWith('http://') || t.startsWith('https://')) {
                  if (_linkType != 'url') setState(() => _linkType = 'url');
                }
              },
              decoration: InputDecoration(
                labelText: context.t(
                  'رابط موقع / صفحة المعلن',
                  'Advertiser website / page URL',
                ),
                hintText: 'https://www.example.com',
                helperText: context.t(
                  'يفتح المتصفح عند الضغط على الإعلان',
                  'Opens the browser when the ad is tapped',
                ),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.public),
              ),
            )
          else
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _routeTarget,
              decoration: InputDecoration(
                labelText: context.t(
                  'قسم داخل AcadeGate (اختياري)',
                  'In-app AcadeGate section (optional)',
                ),
                helperText: context.t(
                  'للتوجيه الداخلي فقط — إن كان لديك موقع استخدم «رابط المعلن»',
                  'Internal only — use “Advertiser URL” if you have a website',
                ),
                border: const OutlineInputBorder(),
              ),
              items: homeAdRouteOptions
                  .map(
                    (o) => DropdownMenuItem(
                      value: o.id,
                      child: Text(arabic ? o.labelAr : o.labelEn),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _routeTarget = v);
              },
            ),
          const SizedBox(height: 16),
          Text(
            context.t('صورة الإعلان (اختياري)', 'Ad image (optional)'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(_imageUrl, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _uploading ? null : _pickImage,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(context.t('رفع صورة', 'Upload image')),
              ),
              if (_imageUrl.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _imageUrl = ''),
                  child: Text(context.t('إزالة', 'Remove')),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: context.t('أولوية الظهور (1–100)', 'Weight (1–100)'),
              helperText: context.t(
                'رقم أكبر = ظهور أكثر في التدوير اليومي',
                'Higher = more likely in daily rotation',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('نشط', 'Active')),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(context.t('حفظ الإعلان', 'Save ad')),
          ),
        ],
      ),
    );
  }
}
