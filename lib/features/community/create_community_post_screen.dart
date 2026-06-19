import 'package:flutter/material.dart';

import 'community_data.dart';
import 'community_service.dart';

class CreateCommunityPostScreen extends StatefulWidget {
  final CommunityRoom room;
  final String initialType;

  const CreateCommunityPostScreen({
    super.key,
    required this.room,
    required this.initialType,
  });

  @override
  State<CreateCommunityPostScreen> createState() =>
      _CreateCommunityPostScreenState();
}

class _CreateCommunityPostScreenState extends State<CreateCommunityPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _universityController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _tagsController = TextEditingController();

  late String _type;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _universityController.dispose();
    _eventDateController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final tags = _tagsController.text
        .split('،')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final error = await CommunityService.instance.createPost(
      roomId: widget.room.id,
      type: _type,
      title: _titleController.text,
      body: _bodyController.text,
      tags: tags,
      university: _universityController.text,
      eventDate: _eventDateController.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final showEventDate = _type == CommunityPostType.announcement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('منشور جديد'),
        backgroundColor: widget.room.color,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'نوع المنشور',
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
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _type = value);
                    },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'المحتوى',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 4,
              maxLines: 8,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _universityController,
              decoration: const InputDecoration(
                labelText: 'الجامعة (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            if (showEventDate) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _eventDateController,
                decoration: const InputDecoration(
                  labelText: 'تاريخ المناقشة (مثال: 2026-06-25)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'وسوم (مفصولة بفاصلة عربية ،)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: widget.room.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'جاري الإرسال...' : 'إرسال للمراجعة'),
            ),
          ],
        ),
      ),
    );
  }
}
