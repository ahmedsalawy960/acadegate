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
              TextFormField(
                controller: _titleController,
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
