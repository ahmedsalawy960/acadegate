import 'package:flutter/material.dart';

import 'community_data.dart';
import 'research_room_models.dart';
import 'research_room_service.dart';

class CreateResearchDiscussionScreen extends StatefulWidget {
  final ResearchRoom room;

  const CreateResearchDiscussionScreen({super.key, required this.room});

  @override
  State<CreateResearchDiscussionScreen> createState() =>
      _CreateResearchDiscussionScreenState();
}

class _CreateResearchDiscussionScreenState
    extends State<CreateResearchDiscussionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();

  String _type = CommunityPostType.discussion;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final tags = _tagsController.text
        .split(RegExp(r'[،,]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final error = await ResearchRoomService.instance.createDiscussion(
      roomId: widget.room.id,
      type: _type,
      title: _titleController.text,
      body: _bodyController.text,
      tags: tags,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مناقشة بحثية جديدة'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'نوع المناقشة',
                  border: OutlineInputBorder(),
                ),
                items: CommunityPostType.labels.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان المناقشة *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'محتوى المناقشة *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'كلمات مفتاحية (للبحث)',
                  hintText: 'مثال: ماجستير، SPSS، طاقة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('نشر المناقشة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
