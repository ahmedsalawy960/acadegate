import 'package:flutter/material.dart';

import '../academic_writing/writing_categories.dart';
import '../academic_writing/writing_expert_detail_screen.dart';
import '../home/home_screen.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import '../research_marketplace/research_idea_marketplace_detail_screen.dart';
import '../smart_labs/smart_lab_detail_screen.dart';
import '../store/product_detail_screen.dart';
import '../store/product_list_screen.dart';
import 'research_path_ai_service.dart';
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
  ResearchSupplyBundle? _bundle;
  AcademicProfile? _profile;

  @override
  void initState() {
    super.initState();
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
        const SnackBar(content: Text('اكتب موضوع بحثك أو اهتمامك أولاً')),
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
      appBar: AppBar(
        title: const Text(ResearchPathBranding.title),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'الملف الأكاديمي',
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
              labelText: 'موضوع / مجال بحثك',
              hintText: 'مثال: طاقة متجددة، تحليل كمي، كيمياء حيوية...',
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
                    ? 'جارٍ المطابقة...'
                    : _aiLoading
                        ? 'جارٍ التحليل بالذكاء الاصطناعي...'
                        : ResearchPathBranding.buildButton,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (_profile != null && !_profile!.isComplete) ...[
            const SizedBox(height: 12),
            _hintBanner(
              'أكمل ملفك الأكاديمي لمطابقة أدق — أو تابع بالموضوع فقط.',
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
                const Expanded(
                  child: Text(
                    ResearchPathBranding.tagline,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              ResearchPathBranding.description,
              style: TextStyle(color: Colors.white70, height: 1.5),
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
              'حزمة: ${bundle.topic}',
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
              'توافق عام: ${bundle.overallScore}% • ${bundle.completedSteps}/5 خطوات',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (!bundle.hasAnyMatch) ...[
              const SizedBox(height: 12),
              const Text('جرّب وصفاً أوسع أو أكمل ملفك الأكاديمي.'),
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
                    'Gemini يحلّل ملفك ويربط عناصر الحزمة بخطة بحثية...',
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
                    insight.fromGemini ? 'AcadeGate AI' : 'تحليل أساسي',
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
                'النموذج: ${insight.modelUsed}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'لماذا هذه الحزمة؟',
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
                          const Text(
                            'الخطوة التالية',
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
        const Text(
          ResearchPathBranding.timelineTitle,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        if (bundle.idea != null)
          _chainStep(
            icon: Icons.lightbulb,
            color: Colors.orange,
            title: '1. فكرة بحثية',
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
            title: '2. مشرف أكاديمي',
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
            title: '3. مختبر ذكي',
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
          title: '4. متجر — مواد وأدوات',
          subtitle: bundle.storeCategory != null
              ? bundle.storeCategory!.title
              : 'منتجات مقترحة',
          score: bundle.products.isNotEmpty ? bundle.products.first.score : 0,
          reasons: bundle.products.isNotEmpty
              ? bundle.products.first.reasons
              : const ['تصفح المتجر'],
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
                  subtitle: Text('${p.price} ج.م'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: p.id == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                name: p.name,
                                price: '${p.price} ج.م',
                                description: 'منتج مقترح ضمن مسار البحث الذكي.',
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
            title: '5. خدمة كتابة / إحصاء',
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
                            'اضغط للتفاصيل ←',
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
