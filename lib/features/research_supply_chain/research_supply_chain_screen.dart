import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic_writing/writing_categories.dart';
import '../academic_writing/writing_expert_detail_screen.dart';
import '../academic/supervisor_profile_screen.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import '../store/product_detail_screen.dart';
import '../store/product_list_screen.dart';
import '../research_marketplace/research_topic_claim_service.dart';
import 'research_path_ai_service.dart';
import '../ai_advisor/advisor_branding.dart';
import 'research_path_branding.dart';
import 'research_supply_chain_engine.dart';
import 'research_supply_chain_models.dart';

class ResearchSupplyChainScreen extends StatefulWidget {
  const ResearchSupplyChainScreen({super.key});

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
          _topicController.text.isEmpty) {
        _topicController.text = profile.researchInterest;
      }
    });
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
        _bundle = bundle.copyWith(aiInsight: insight);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(ResearchPathBranding.title),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
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
          _headerCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _topicController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.t('موضوع / مجال بحثك', 'Research topic / field'),
              hintText: context.t(
                'مثال: طاقة متجددة، تحليل كمي، كيمياء حيوية...',
                'e.g. renewable energy, quantitative analysis, biochemistry...',
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.search, color: _brand),
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
                'توافق عام: ${bundle.overallScore}% • ${bundle.completedSteps}/5 خطوات',
                'Overall match: ${bundle.overallScore}% • ${bundle.completedSteps}/5 steps',
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
        const SizedBox(height: 12),
        if (bundle.idea != null)
          _chainStep(
            icon: Icons.lightbulb,
            color: Colors.orange,
            title: context.t('1. فكرة بحثية', '1. Research idea'),
            subtitle: bundle.idea!.item.title,
            score: bundle.idea!.score,
            reasons: bundle.idea!.reasons,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResearchIdeaMarketplaceDetailScreen(
                  idea: bundle.idea!.item,
                ),
              ),
            ),
          ),
        if (bundle.supervisor != null)
          _chainStep(
            icon: Icons.person,
            color: Colors.blue,
            title: context.t('2. مشرف أكاديمي', '2. Academic supervisor'),
            subtitle: bundle.supervisor!.item.name,
            score: bundle.supervisor!.score,
            reasons: bundle.supervisor!.reasons,
            onTap: () {
              final s = bundle.supervisor!.item;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SupervisorProfileScreen(
                    supervisor: s,
                  ),
                ),
              );
            },
          ),
        if (bundle.lab != null)
          _chainStep(
            icon: Icons.science,
            color: Colors.purple,
            title: context.t('3. مختبر ذكي', '3. Smart lab'),
            subtitle: bundle.lab!.item.name,
            score: bundle.lab!.score,
            reasons: bundle.lab!.reasons,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SmartLabDetailScreen(lab: bundle.lab!.item),
              ),
            ),
          ),
        _chainStep(
          icon: Icons.storefront,
          color: Colors.green,
          title: context.t('4. متجر — مواد وأدوات', '4. Store — supplies & tools'),
          subtitle: bundle.storeCategory != null
              ? L10nLookup.storeCategoryTitle(bundle.storeCategory!.id)
              : context.t('منتجات مقترحة', 'Suggested products'),
          score: bundle.products.isNotEmpty ? bundle.products.first.score : 0,
          reasons: bundle.products.isNotEmpty
              ? bundle.products.first.reasons
              : [context.t('تصفح المتجر', 'Browse store')],
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
          children: bundle.products
              .map(
                (p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2, size: 20),
                  title: Text(p.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(context.t('${p.price} ج.م', '${p.price} EGP')),
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
                                storeName: p.category,
                                contact: '',
                                productId: p.id,
                                createdBy: p.createdBy,
                                priceValue: p.price,
                                imageUrl: p.imageUrl,
                              ),
                            ),
                          ),
                ),
              )
              .toList(),
        ),
        if (bundle.writingExpert != null)
          _chainStep(
            icon: Icons.edit_note,
            color: const Color(0xFF5D4037),
            title: context.t('5. خدمة كتابة / إحصاء', '5. Writing / statistics service'),
            subtitle: bundle.writingExpert!.item.name,
            score: bundle.writingExpert!.score,
            reasons: bundle.writingExpert!.reasons,
            onTap: () {
              final expert = bundle.writingExpert!.item;
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
