import 'package:flutter/material.dart';
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
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل النشر: $e'),
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
      appBar: AppBar(
        title: const Text('نشر فكرة بحثية'),
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                decoration: const InputDecoration(
                  labelText: 'عنوان المشكلة البحثية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _providerController,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                decoration: const InputDecoration(
                  labelText: 'الجهة الناشرة (جامعة / شركة / وزارة)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsController,
                maxLines: 5,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل المشكلة البحثية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'المنحة أو الميزانية (اختياري)',
                  hintText: 'مثال: 10,000 ج.م',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'الوسوم (اختياري)',
                  hintText: 'طاقة، هندسة، ذكاء اصطناعي',
                  border: OutlineInputBorder(),
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
                      : const Text('نشر في السوق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
