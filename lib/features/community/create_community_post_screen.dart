import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
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
      appBar: AcadeGateAppBar(
        title: Text(context.t('منشور جديد', 'New post')),
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
              decoration: InputDecoration(
                labelText: context.t('نوع المنشور', 'Post type'),
                border: const OutlineInputBorder(),
              ),
              items: CommunityPostType.allTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(CommunityPostType.label(type)),
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
              decoration: InputDecoration(
                labelText: context.t('العنوان', 'Title'),
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.t('مطلوب', 'Required')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: context.t('المحتوى', 'Content'),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 4,
              maxLines: 8,
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.t('مطلوب', 'Required')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _universityController,
              decoration: InputDecoration(
                labelText: context.t('الجامعة (اختياري)', 'University (optional)'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (showEventDate) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _eventDateController,
                decoration: InputDecoration(
                  labelText: context.t(
                    'تاريخ المناقشة (مثال: 2026-06-25)',
                    'Seminar date (e.g. 2026-06-25)',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: context.t(
                  'وسوم (مفصولة بفاصلة عربية ،)',
                  'Tags (comma-separated)',
                ),
                border: const OutlineInputBorder(),
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
              label: Text(
                _submitting
                    ? context.t('جاري الإرسال...', 'Sending...')
                    : context.t('إرسال للمراجعة', 'Submit for review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
