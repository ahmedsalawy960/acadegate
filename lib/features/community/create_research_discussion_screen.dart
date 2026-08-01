import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
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
  final _linkController = TextEditingController();
  final _linkTitleController = TextEditingController();

  String _type = CommunityPostType.discussion;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    _linkController.dispose();
    _linkTitleController.dispose();
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
      academicLink: _linkController.text,
      academicTitle: _linkTitleController.text,
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
      appBar: AcadeGateAppBar(
        title: Text(context.t(
          'مناقشة بحثية جديدة',
          'New research discussion',
        )),
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
                decoration: InputDecoration(
                  labelText: context.t('نوع المناقشة', 'Discussion type'),
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
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.t('عنوان المناقشة *', 'Discussion title *'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.t('مطلوب', 'Required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: context.t('محتوى المناقشة *', 'Discussion content *'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.t('مطلوب', 'Required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: context.t(
                    'كلمات مفتاحية (للبحث)',
                    'Keywords (for search)',
                  ),
                  hintText: context.t(
                    'مثال: ماجستير، SPSS، طاقة',
                    'e.g. master\'s, SPSS, energy',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _linkTitleController,
                decoration: InputDecoration(
                  labelText: context.t(
                    'عنوان مرجع أكاديمي (اختياري)',
                    'Academic reference title (optional)',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _linkController,
                decoration: InputDecoration(
                  labelText: context.t(
                    'رابط DOI / URL (اختياري)',
                    'DOI / URL link (optional)',
                  ),
                  border: const OutlineInputBorder(),
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
                    : Text(context.t('نشر المناقشة', 'Publish discussion')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
