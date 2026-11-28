import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/l10n_lookup.dart';
import '../academic/faculty_categories.dart';
import 'research_marketplace_service.dart';

class PublishResearchIdeaScreen extends StatefulWidget {
  const PublishResearchIdeaScreen({super.key});

  @override
  State<PublishResearchIdeaScreen> createState() =>
      _PublishResearchIdeaScreenState();
}

class _PublishResearchIdeaScreenState extends State<PublishResearchIdeaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _providerController = TextEditingController();
  final _detailsController = TextEditingController();
  final _budgetController = TextEditingController();
  final _tagsController = TextEditingController();
  String? _categoryId;
  String _degreeLevel = 'both';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _providerController.dispose();
    _detailsController.dispose();
    _budgetController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final tags = _tagsController.text
          .split(RegExp(r'[،,]'))
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      await ResearchMarketplaceService.instance.publishIdea(
        title: _titleController.text.trim(),
        provider: _providerController.text.trim(),
        details: _detailsController.text.trim(),
        budget: _budgetController.text.trim(),
        tags: tags,
        category: _categoryId ?? '',
        degreeLevel: _degreeLevel,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('فشل النشر: $e', 'Publish failed: $e')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('نشر فكرة بحثية', 'Publish research idea')),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.t(
                    'يراجع مشرف المنصة فكرتك قبل نشرها. اكتب مشكلة بحثية حقيقية ومحددة: الفجوة العلمية، ولمن تهم، وما المتوقع من الباحث.',
                    'A platform admin reviews your idea before publishing. Describe a real, specific research problem: the scientific gap, who it matters to, and what you expect from the researcher.',
                  ),
                  style: TextStyle(
                    color: const Color(0xFFB7C3D6),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
              TextFormField(
                controller: _titleController,
                maxLength: 140,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.t('مطلوب', 'Required')
                    : null,
                decoration: InputDecoration(
                  labelText: context.t(
                    'عنوان المشكلة البحثية',
                    'Research problem title',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                menuMaxHeight: 400,
                decoration: InputDecoration(
                  labelText: context.t('الكلية / التخصص', 'Faculty / field'),
                  border: const OutlineInputBorder(),
                ),
                items: facultyCategories
                    .map(
                      (f) => DropdownMenuItem(
                        value: f.id,
                        child: Text(L10nLookup.facultyTitleStatic(f.id)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => (v == null || v.isEmpty)
                    ? context.t('مطلوب', 'Required')
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _degreeLevel,
                decoration: InputDecoration(
                  labelText: context.t('مستوى الدرجة', 'Degree level'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'masters',
                    child: Text(context.t('ماجستير', 'Master\'s')),
                  ),
                  DropdownMenuItem(
                    value: 'phd',
                    child: Text(context.t('دكتوراه', 'PhD')),
                  ),
                  DropdownMenuItem(
                    value: 'both',
                    child: Text(context.t(
                      'ماجستير أو دكتوراه',
                      'Master\'s or PhD',
                    )),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _degreeLevel = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _providerController,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.t('مطلوب', 'Required')
                    : null,
                decoration: InputDecoration(
                  labelText: context.t(
                    'الجهة الناشرة (جامعة / شركة / وزارة)',
                    'Publisher (university / company / ministry)',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsController,
                maxLines: 5,
                maxLength: 2000,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.t('مطلوب', 'Required')
                    : null,
                decoration: InputDecoration(
                  labelText: context.t(
                    'تفاصيل المشكلة البحثية',
                    'Research problem details',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: InputDecoration(
                  labelText: context.t(
                    'المنحة أو الميزانية (اختياري)',
                    'Grant or budget (optional)',
                  ),
                  hintText: context.t('مثال: 10,000 ج.م', 'e.g. 10,000 EGP'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: context.t('الوسوم (اختياري)', 'Tags (optional)'),
                  hintText: context.t(
                    'طاقة، هندسة، ذكاء اصطناعي',
                    'energy, engineering, AI',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(context.t('نشر في السوق', 'Publish to marketplace')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
