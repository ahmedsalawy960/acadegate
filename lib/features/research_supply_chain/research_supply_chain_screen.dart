import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic_writing/writing_categories.dart';
import '../academic_writing/writing_expert_detail_screen.dart';
import '../academic/academic_models.dart';
import '../academic/supervisor_profile_screen.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import '../guides/section_guide_catalog.dart';
import '../guides/section_guide_screen.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import '../store/product_detail_screen.dart';
import '../store/product_list_screen.dart';
import '../research_fund/industry_challenge_detail_screen.dart';
import '../research_fund/research_fund_screen.dart';
import '../research_marketplace/research_topic_claim_service.dart';
import '../lab_import/nbsle_university_cities.dart';
import 'research_goal.dart';
import 'research_path_ai_service.dart';
import 'research_path_pdf_service.dart';
import '../ai_advisor/advisor_branding.dart';
import 'research_path_branding.dart';
import 'research_supply_chain_engine.dart';
import 'research_supply_chain_models.dart';

class ResearchSupplyChainScreen extends StatefulWidget {
  final String? initialGoal;

  const ResearchSupplyChainScreen({super.key, this.initialGoal});

  @override
  State<ResearchSupplyChainScreen> createState() =>
      _ResearchSupplyChainScreenState();
}

class _ResearchSupplyChainScreenState extends State<ResearchSupplyChainScreen> {
  static const _brand = Color(0xFF006064);

  final _topicController = TextEditingController();
  bool _loading = false;
  bool _aiLoading = false;
  bool _claimLoading = false;
  ResearchSupplyBundle? _bundle;
  AcademicProfile? _profile;

  @override
  void initState() {
    super.initState();
    _topicController.addListener(() {
      if (mounted) setState(() {});
    });
    final seed = widget.initialGoal?.trim() ?? '';
    if (seed.isNotEmpty) {
      _topicController.text = seed;
    }
    _loadProfile();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      if (profile != null &&
          profile.researchInterest.isNotEmpty &&
          _topicController.text.isEmpty &&
          (widget.initialGoal == null || widget.initialGoal!.trim().isEmpty)) {
        _topicController.text = profile.researchInterest;
      }
    });
    if ((widget.initialGoal?.trim().isNotEmpty ?? false) && _bundle == null) {
      await _buildChain();
    }
  }

  Future<void> _buildChain() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'اكتب موضوع بحثك أو اهتمامك أولاً',
            'Enter your research topic or interest first',
          )),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _aiLoading = false;
      _bundle = null;
    });

    try {
      final bundle = await ResearchSupplyChainEngine.instance.buildBundle(
        topic: topic,
        profile: _profile,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
        _aiLoading = true;
      });

      final insight = await ResearchPathAiService.instance.enrich(
        bundle: bundle,
        profile: _profile,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle.copyWith(
          aiInsight: insight,
          degreePlan: insight.stages.isNotEmpty
              ? insight.stages
              : bundle.degreePlan,
        );
        _aiLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _aiLoading = false;
        });
      }
    }
  }

  Future<void> _claimMyTopic() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() => _claimLoading = true);
    try {
      await ResearchTopicClaimService.instance.claimCustomTopic(
        topicTitle: topic,
        university: _profile?.university ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تم حجز الموضوع — لن يستطيع طالب آخر في جامعتك اختيار نفس العنوان',
            'Topic claimed — another student at your university cannot claim the same title',
          )),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimLoading = false);
    }
  }

  Future<void> _releaseMyTopic() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() => _claimLoading = true);
    try {
      await ResearchTopicClaimService.instance.releaseCustomTopic(
        topicTitle: topic,
        university: _profile?.university ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تم إلغاء حجز الموضوع',
            'Topic claim released',
          )),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimLoading = false);
    }
  }

  Widget _topicClaimPanel() {
    final topic = _topicController.text.trim();
    if (topic.length < 3) return const SizedBox.shrink();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _hintBanner(
          context.t(
            'سجّل الدخول لحجز موضوع بحثك وحمايته من التكرار',
            'Sign in to claim and protect your research topic from duplication',
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: StreamBuilder<ResearchTopicClaim?>(
        stream: ResearchTopicClaimService.instance.watchCustomTopic(
          topicTitle: topic,
          university: _profile?.university ?? '',
        ),
        builder: (context, snapshot) {
          final claim = snapshot.data;
          final isMine = claim?.claimedBy == uid;
          final isTaken = claim != null && !isMine;

          if (isTaken) {
            return _hintBanner(
              context.t(
                'هذا الموضوع محجوز لـ ${claim.claimedByName}',
                'This topic is claimed by ${claim.claimedByName}',
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMine)
                _hintBanner(
                  context.t(
                    'أنت من اختار هذا الموضوع — يظهر للآخرين كـ «محجوز»',
                    'You claimed this topic — others will see it as taken',
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _claimLoading
                    ? null
                    : (isMine ? _releaseMyTopic : _claimMyTopic),
                icon: _claimLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isMine ? Icons.lock_open : Icons.bookmark_add),
                label: Text(
                  isMine
                      ? context.t('إلغاء حجز الموضوع', 'Release topic claim')
                      : context.t('حجز هذا الموضوع لي', 'Claim this topic for me'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openProfile() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AcademicProfileScreen()),
    );
    if (saved == true) await _loadProfile();
  }

  Future<void> _exportOrPrint() async {
    final bundle = _bundle;
    if (bundle == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(ctx.t('طباعة', 'Print')),
              onTap: () => Navigator.pop(ctx, 'print'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(ctx.t('حفظ / مشاركة PDF', 'Save / share PDF')),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'print') {
        await ResearchPathPdfService.instance.printBundle(
          bundle,
          profile: _profile,
        );
      } else {
        await ResearchPathPdfService.instance.shareBundle(
          bundle,
          profile: _profile,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تعذّر إنشاء PDF: $error',
              'Could not create PDF: $error',
            ),
          ),
        ),
      );
    }
  }

  bool _labInCity(AcademicLab lab) {
    final city = _profile?.city ?? '';
    return NbsleUniversityCities.isSameCity(lab.city, city) ||
        NbsleUniversityCities.isSameCity(lab.location, city);
  }

  bool _productInCity(SupplyChainProduct product) {
    return NbsleUniversityCities.isSameCity(product.city, _profile?.city ?? '');
  }

  Widget _cityGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Color(0xFF006064),
        ),
      ),
    );
  }

  List<Widget> _labTiles(BuildContext context, ResearchSupplyBundle bundle) {
    final city = _profile?.city.trim() ?? '';
    final local = city.isEmpty
        ? const <MatchResult<AcademicLab>>[]
        : bundle.labs.where((m) => _labInCity(m.item)).toList();
    final other = city.isEmpty
        ? bundle.labs
        : bundle.labs.where((m) => !_labInCity(m.item)).toList();
    return [
      if (local.isNotEmpty)
        _cityGroupHeader(
          context.t('في مدينتك ($city)', 'In your city ($city)'),
        ),
      for (final match in local) _labTile(context, match),
      if (other.isNotEmpty && local.isNotEmpty)
        _cityGroupHeader(context.t('مدن أخرى', 'Other cities')),
      for (final match in other) _labTile(context, match),
    ];
  }

  Widget _labTile(BuildContext context, MatchResult<AcademicLab> match) {
    final lab = match.item;
    final city = lab.city.isNotEmpty ? lab.city : lab.location;
    final tools = lab.equipment.trim().isNotEmpty
        ? lab.equipment.trim()
        : lab.equipmentNameHints.take(3).join('، ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.science_outlined, size: 20),
      title: Text(lab.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        [
          city,
          if (lab.university.trim().isNotEmpty) lab.university,
          if (tools.isNotEmpty) tools,
          context.t('توافق ${match.score}%', 'match ${match.score}%'),
        ].join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SmartLabDetailScreen(lab: lab),
        ),
      ),
    );
  }

  List<Widget> _productTiles(BuildContext context, ResearchSupplyBundle bundle) {
    final city = _profile?.city.trim() ?? '';
    final local = city.isEmpty
        ? const <SupplyChainProduct>[]
        : bundle.products.where(_productInCity).toList();
    final other = city.isEmpty
        ? bundle.products
        : bundle.products.where((p) => !_productInCity(p)).toList();
    return [
      if (local.isNotEmpty)
        _cityGroupHeader(
          context.t('في مدينتك ($city)', 'In your city ($city)'),
        ),
      for (final p in local) _productTile(context, p),
      if (other.isNotEmpty && local.isNotEmpty)
        _cityGroupHeader(context.t('مدن أخرى', 'Other cities')),
      for (final p in other) _productTile(context, p),
    ];
  }

  Widget _productTile(BuildContext context, SupplyChainProduct p) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.inventory_2, size: 20),
      title: Text(p.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        context.t(
          '${p.price} ج.م • ${p.category}${p.city.isNotEmpty ? ' • ${p.city}' : ''} • توافق ${p.score}%',
          '${p.price} EGP • ${p.category}${p.city.isNotEmpty ? ' • ${p.city}' : ''} • match ${p.score}%',
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: p.id == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    name: p.name,
                    price: context.t('${p.price} ج.م', '${p.price} EGP'),
                    description: context.t(
                      'منتج مقترح ضمن مسار البحث الذكي.',
                      'Product suggested within the Smart Research Path.',
                    ),
                    storeName: p.storeName.isNotEmpty ? p.storeName : p.category,
                    contact: '',
                    productId: p.id,
                    createdBy: p.createdBy,
                    priceValue: p.price,
                    imageUrl: p.imageUrl,
                  ),
                ),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(ResearchPathBranding.title),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          const SectionGuideAppBarButton(
            guideId: SectionGuideCatalog.researchPath,
            accent: _brand,
          ),
          if (_bundle != null)
            IconButton(
              tooltip: context.t('PDF / طباعة المسار', 'PDF / print path'),
              onPressed: _exportOrPrint,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          IconButton(
            tooltip: context.t('الملف الأكاديمي', 'Academic profile'),
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionGuideBanner(
            guideId: SectionGuideCatalog.researchPath,
            accent: _brand,
          ),
          const SizedBox(height: 12),
          _headerCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _topicController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.t(
                'اكتب هدفك البحثي',
                'Write your research goal',
              ),
              hintText: context.t(
                'مثال: أريد ماجستير في الكيمياء التحليلية لتطوير مصنع زيوت',
                'e.g. I want a master’s in analytical chemistry to improve an oil factory',
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.edit_note, color: _brand),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _loading || _aiLoading ? null : _buildChain,
              icon: _loading || _aiLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _loading
                    ? context.t('جارٍ المطابقة...', 'Matching...')
                    : _aiLoading
                        ? context.t(
                            'جارٍ التحليل بالذكاء الاصطناعي...',
                            'Analyzing with AI...',
                          )
                        : ResearchPathBranding.buildButton,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          _topicClaimPanel(),
          if (_profile != null && !_profile!.isComplete) ...[
            const SizedBox(height: 12),
            _hintBanner(
              context.t(
                'أكمل ملفك الأكاديمي لمطابقة أدق — أو تابع بالموضوع فقط.',
                'Complete your academic profile for better matching — or continue with topic only.',
              ),
              onTap: _openProfile,
            ),
          ],
          if (_bundle != null) ...[
            const SizedBox(height: 24),
            _bundleOverview(_bundle!),
            if (_bundle!.goal != null) ...[
              const SizedBox(height: 12),
              _goalChips(_bundle!.goal!),
            ],
            if (_bundle!.degreePlan.isNotEmpty) ...[
              const SizedBox(height: 16),
              _degreePlanCard(_bundle!),
            ],
            if (_bundle!.literature.isNotEmpty || _bundle!.goal != null) ...[
              const SizedBox(height: 16),
              _literatureCard(_bundle!),
            ],
            if (_bundle!.institutionalNotes.isNotEmpty ||
                _bundle!.fundingFits.isNotEmpty) ...[
              const SizedBox(height: 16),
              _impactCard(_bundle!),
            ],
            if (_aiLoading) ...[
              const SizedBox(height: 16),
              _aiLoadingCard(),
            ],
            if (_bundle!.aiInsight != null) ...[
              const SizedBox(height: 16),
              _aiInsightCard(_bundle!.aiInsight!),
            ],
            const SizedBox(height: 20),
            _chainTimeline(_bundle!),
          ],
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Card(
      color: _brand,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_tree, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ResearchPathBranding.tagline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ResearchPathBranding.description,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalChips(ResearchGoal goal) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text(goal.degreeLabel)),
        if (goal.field.isNotEmpty) Chip(label: Text(goal.field)),
        if (goal.fieldEn.isNotEmpty) Chip(label: Text(goal.fieldEn)),
        Chip(label: Text('${goal.years} ${context.t('سنوات', 'years')}')),
        Chip(label: Text(goal.institutionLabel)),
      ],
    );
  }

  Widget _degreePlanCard(ResearchSupplyBundle bundle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('خطة العمل طوال الدرجة', 'Degree-long work plan'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                bundle.goal?.fieldEn.isNotEmpty == true
                    ? 'خطة على نقطة: ${bundle.goal!.field} (${bundle.goal!.fieldEn})'
                    : 'مراحل مرتبطة بنقطة بحثك — إن كانت عامة أعد التشغيل بعد تسجيل الدخول للذكاء الاصطناعي.',
                bundle.goal?.fieldEn.isNotEmpty == true
                    ? 'Plan on: ${bundle.goal!.field} (${bundle.goal!.fieldEn})'
                    : 'Stages tied to your topic — if they look generic, sign in and rebuild so Gemini can specialize them.',
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 12),
            ...bundle.degreePlan.map(
              (stage) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.period,
                      style: const TextStyle(
                        color: _brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      stage.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...stage.outcomes.map(
                      (o) => Text('• $o', style: const TextStyle(height: 1.4)),
                    ),
                    ...stage.platformActions.map(
                      (a) => Text(
                        '→ $a',
                        style: TextStyle(height: 1.4, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _literatureCard(ResearchSupplyBundle bundle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'دراسات سابقة مؤكدة (${bundle.literature.length})',
                'Confirmed prior studies (${bundle.literature.length})',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                [
                  if (bundle.goal?.fieldEn.isNotEmpty == true)
                    'بُحث إنجليزياً: ${bundle.goal!.fieldEn}',
                  if (bundle.goal?.searchQueries.isNotEmpty == true)
                    bundle.goal!.searchQueries.take(3).join(' · '),
                  bundle.literature.length >= 15
                      ? 'OpenAlex + Crossref + Semantic Scholar، مع استبعاد العناوين البعيدة عن النقطة.'
                      : 'ظهر ${bundle.literature.length} عملاً على النقطة بـ DOI مؤكد. لم نختلق البقية.',
                ].join(' '),
                [
                  if (bundle.goal?.fieldEn.isNotEmpty == true)
                    'English search: ${bundle.goal!.fieldEn}',
                  if (bundle.goal?.searchQueries.isNotEmpty == true)
                    bundle.goal!.searchQueries.take(3).join(' · '),
                  bundle.literature.length >= 15
                      ? 'OpenAlex + Crossref + Semantic Scholar; off-topic titles were dropped.'
                      : '${bundle.literature.length} on-topic works with a confirmed DOI. The rest were not invented.',
                ].join(' '),
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 8),
            if (bundle.literature.isEmpty)
              Text(
                context.t(
                  'لا دراسات مؤكدة لهذا النص بعد. جرّب مصطلحاً أدق أو إنجليزياً شائعاً في المجال.',
                  'No confirmed studies for this text yet. Try a more specific or common English term in the field.',
                ),
              )
            else
              ...bundle.literature.map(
                (work) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(work.title, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    [
                      if (work.year != null) '${work.year}',
                      if (work.authors.isNotEmpty) work.authors,
                      work.source,
                    ].join(' • '),
                    maxLines: 2,
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openDoi(work.doiUrl),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _impactCard(ResearchSupplyBundle bundle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'الأثر المؤسسي والتمويل',
                'Institutional impact and funding',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...bundle.institutionalNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $note', style: const TextStyle(height: 1.4)),
              ),
            ),
            if (bundle.fundingFits.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...bundle.fundingFits.map(
                (fit) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    fit.kind == 'industry_challenge'
                        ? Icons.factory_outlined
                        : Icons.savings_outlined,
                    color: _brand,
                  ),
                  title: Text(fit.title),
                  subtitle: Text(
                    [
                      fit.why,
                      if (fit.budget > 0) '${fit.budget} ${fit.currency}',
                    ].join(' · '),
                  ),
                  onTap: () {
                    if (fit.kind == 'industry_challenge' &&
                        fit.challengeId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IndustryChallengeDetailScreen(
                            challengeId: fit.challengeId!,
                          ),
                        ),
                      );
                      return;
                    }
                    if (fit.kind == 'research_fund') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResearchFundScreen(),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDoi(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تعذّر فتح الدراسة', 'Could not open the study')),
        ),
      );
    }
  }

  Widget _hintBanner(String text, {VoidCallback? onTap}) {
    return Material(
      color: Colors.amber.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
              if (onTap != null) const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bundleOverview(ResearchSupplyBundle bundle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'حزمة: ${bundle.topic}',
                'Bundle: ${bundle.topic}',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: bundle.overallScore / 100,
              backgroundColor: Colors.grey[200],
              color: _brand,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'توافق عام: ${bundle.overallScore}% • ${bundle.literature.length} دراسة مؤكدة',
                'Overall match: ${bundle.overallScore}% • ${bundle.literature.length} confirmed studies',
              ),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (!bundle.hasAnyMatch) ...[
              const SizedBox(height: 12),
              Text(context.t(
                'جرّب وصفاً أوسع أو أكمل ملفك الأكاديمي.',
                'Try a broader description or complete your academic profile.',
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _aiLoadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ResearchPathBranding.aiSectionTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      'الذكاء السحابي يحلّل ملفك ويربط عناصر الحزمة بخطة بحثية...',
                      'Cloud AI analyzes your profile and links bundle items to a research plan...',
                    ),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiInsightCard(ResearchPathAiInsight insight) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology_alt_outlined,
                  color: Colors.purple[700],
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ResearchPathBranding.aiSectionTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.purple[900],
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    insight.fromGemini
                        ? AdvisorBranding.cloudBadge
                        : context.t('تحليل أساسي', 'Basic analysis'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: insight.fromGemini
                      ? Colors.purple.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                ),
              ],
            ),
            if (insight.fromGemini && insight.modelUsed != null) ...[
              const SizedBox(height: 4),
              Text(
                context.t('النموذج: ${insight.modelUsed}', 'Model: ${insight.modelUsed}'),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              context.t('لماذا هذه الحزمة؟', 'Why this bundle?'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _brand,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              insight.analysis,
              style: const TextStyle(height: 1.55, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Text(
              ResearchPathBranding.aiPlanTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _brand,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              insight.researchPlan,
              style: const TextStyle(height: 1.55, fontSize: 14),
            ),
            if (insight.nextStep != null && insight.nextStep!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.play_arrow, color: _brand, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('الخطوة التالية', 'Next step'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _brand,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            insight.nextStep!,
                            style: const TextStyle(height: 1.4, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!insight.fromGemini &&
                insight.error != null &&
                insight.error!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                insight.error!,
                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chainTimeline(ResearchSupplyBundle bundle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ResearchPathBranding.timelineTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            'نعرض فقط ما يشارك كلمات نقطة بحثك. القائمة الفارغة أفضل من توافق 100% بلا صلة.',
            'Only items that share your topic words are shown. An empty list is better than a 100% mismatch.',
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (bundle.ideas.isEmpty)
          _chainStep(
            icon: Icons.lightbulb,
            color: Colors.orange,
            title: context.t('1. أفكار بحثية (0)', '1. Research ideas (0)'),
            subtitle: context.t(
              'لا فكرة في الكتالوج تشارك عنوانها كلمات موضوعك',
              'No catalog idea title shares your topic words',
            ),
            score: 0,
            reasons: [
              context.t(
                'لن نعرض أفكار طب نفسي أو إعلام لأن كليتك واحدة',
                'Psychology or media ideas are not shown just because you share a faculty',
              ),
            ],
          )
        else
          _chainStep(
            icon: Icons.lightbulb,
            color: Colors.orange,
            title: context.t(
              '1. أفكار بحثية (${bundle.ideas.length})',
              '1. Research ideas (${bundle.ideas.length})',
            ),
            subtitle: bundle.ideas.first.item.title,
            score: bundle.ideas.first.score,
            reasons: bundle.ideas.first.reasons,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResearchIdeaMarketplaceDetailScreen(
                  idea: bundle.ideas.first.item,
                ),
              ),
            ),
            children: [
              for (final match in bundle.ideas)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lightbulb_outline, size: 20),
                  title: Text(
                    match.item.title,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    context.t(
                      'توافق ${match.score}%${match.reasons.isEmpty ? '' : ' — ${match.reasons.first}'}',
                      'Match ${match.score}%${match.reasons.isEmpty ? '' : ' — ${match.reasons.first}'}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ResearchIdeaMarketplaceDetailScreen(
                        idea: match.item,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (bundle.supervisors.isNotEmpty)
          _chainStep(
            icon: Icons.person,
            color: Colors.blue,
            title: context.t(
              '2. مشرفون أكاديميون (${bundle.supervisors.length})',
              '2. Academic supervisors (${bundle.supervisors.length})',
            ),
            subtitle: bundle.supervisors.first.item.name,
            score: bundle.supervisors.first.score,
            reasons: bundle.supervisors.first.reasons,
            onTap: () {
              final s = bundle.supervisors.first.item;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SupervisorProfileScreen(
                    supervisor: s,
                  ),
                ),
              );
            },
            children: [
              for (final match in bundle.supervisors)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline, size: 20),
                  title: Text(
                    match.item.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    context.t(
                      '${match.item.speciality} • توافق ${match.score}%',
                      '${match.item.speciality} • match ${match.score}%',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupervisorProfileScreen(
                        supervisor: match.item,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (bundle.labs.isEmpty)
          _chainStep(
            icon: Icons.science,
            color: Colors.purple,
            title: context.t('3. مختبرات ذكية (0)', '3. Smart labs (0)'),
            subtitle: context.t(
              'لا مختبر يشارك اسمه أو أجهزته كلمات موضوعك',
              'No lab name or equipment shares your topic words',
            ),
            score: 0,
            reasons: [
              context.t(
                'لن نعرض جيولوجيا أو أمن سيبراني لأن المختبر في نفس الكلية',
                'Geology or cybersecurity labs are not shown just because they share your faculty',
              ),
            ],
          )
        else
          _chainStep(
            icon: Icons.science,
            color: Colors.purple,
            title: context.t(
              '3. مختبرات ذكية — مدينتك أولاً (${bundle.labs.length})',
              '3. Smart labs — your city first (${bundle.labs.length})',
            ),
            subtitle: bundle.labs.first.item.name,
            score: bundle.labs.first.score,
            reasons: bundle.labs.first.reasons,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SmartLabDetailScreen(lab: bundle.labs.first.item),
              ),
            ),
            children: [
              ..._labTiles(context, bundle),
            ],
          ),
        _chainStep(
          icon: Icons.storefront,
          color: Colors.green,
            title: context.t(
            '4. متجر — مدينتك أولاً ثم باقي المدن (${bundle.products.length})',
            '4. Store — your city first, then others (${bundle.products.length})',
          ),
          subtitle: bundle.storeCategories.isNotEmpty
              ? bundle.storeCategories
                  .map((c) => L10nLookup.storeCategoryTitle(c.id))
                  .join(' · ')
              : (bundle.storeCategory != null
                  ? L10nLookup.storeCategoryTitle(bundle.storeCategory!.id)
                  : context.t('منتجات مقترحة', 'Suggested products')),
          score: bundle.products.isNotEmpty ? bundle.products.first.score : 0,
          reasons: bundle.products.isNotEmpty
              ? bundle.products.first.reasons
              : [
                  context.t(
                    'لن نملأ المتجر بمفك أو كاميرا حرارية بلا كلمة من موضوعك',
                    'The store is not filled with screwdrivers or thermal cameras that lack a topic word',
                  ),
                ],
          onTap: bundle.storeCategory != null
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductListScreen(
                        categoryTitle: bundle.storeCategory!.title,
                      ),
                    ),
                  )
              : null,
          children: _productTiles(context, bundle),
        ),
        if (bundle.writingExperts.isNotEmpty)
          _chainStep(
            icon: Icons.edit_note,
            color: const Color(0xFF5D4037),
            title: context.t(
              '5. كتابة / إحصاء (${bundle.writingExperts.length})',
              '5. Writing / statistics (${bundle.writingExperts.length})',
            ),
            subtitle: bundle.writingExperts.first.item.name,
            score: bundle.writingExperts.first.score,
            reasons: bundle.writingExperts.first.reasons,
            onTap: () {
              final expert = bundle.writingExperts.first.item;
              final category = writingCategoryByTitle(expert.category) ??
                  writingCategories.first;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WritingExpertDetailScreen(
                    expert: expert,
                    category: category,
                  ),
                ),
              );
            },
            children: [
              for (final match in bundle.writingExperts)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined, size: 20),
                  title: Text(
                    match.item.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    context.t(
                      '${match.item.category} • توافق ${match.score}%',
                      '${match.item.category} • match ${match.score}%',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {
                    final category =
                        writingCategoryByTitle(match.item.category) ??
                            writingCategories.first;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WritingExpertDetailScreen(
                          expert: match.item,
                          category: category,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _chainStep({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required int score,
    required List<String> reasons,
    VoidCallback? onTap,
    List<Widget> children = const [],
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Expanded(
                child: Container(width: 2, color: color.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          if (score > 0)
                            Chip(
                              label: Text('$score%'),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (reasons.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          reasons.join(' • '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (onTap != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.t('اضغط للتفاصيل ←', 'Tap for details ←'),
                            style: TextStyle(fontSize: 12, color: color),
                          ),
                        ),
                      ],
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
