import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../academic/academic_models.dart';
import '../profile/academic_profile_service.dart';
import 'research_marketplace_service.dart';

class SubmitProposalScreen extends StatefulWidget {
  final AcademicResearchIdea idea;

  const SubmitProposalScreen({super.key, required this.idea});

  @override
  State<SubmitProposalScreen> createState() => _SubmitProposalScreenState();
}

class _SubmitProposalScreenState extends State<SubmitProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _summaryController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (profile != null) {
      _nameController.text = profile.fullName;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      _emailController.text = user!.email!;
    }
    if (mounted) setState(() {});
  }

  int get _wordCount {
    final text = _summaryController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_wordCount > 500) return;

    setState(() => _isSaving = true);

    try {
      await ResearchMarketplaceService.instance.submitProposal(
        idea: widget.idea,
        authorName: _nameController.text.trim(),
        authorEmail: _emailController.text.trim(),
        summary: _summaryController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقديم مقترح بحثي'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'فكرة: ${widget.idea.title}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                decoration: const InputDecoration(
                  labelText: 'اسمك',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summaryController,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  if (_wordCount > 500) {
                    return 'تجاوزت 500 كلمة ($_wordCount)';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'ملخص المقترح (حتى 500 كلمة)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'عدد الكلمات: $_wordCount / 500',
                style: TextStyle(
                  color: _wordCount > 500 ? Colors.red : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving || !widget.idea.isOpen ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إرسال المقترح'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
