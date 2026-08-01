import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
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
  final _linkController = TextEditingController();
  final _linkTitleController = TextEditingController();
  final _specializationController = TextEditingController();

  late String _type;
  late String _audienceScope;
  bool _submitting = false;
  AcademicProfile? _profile;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _audienceScope = widget.room.id == 'general'
        ? PostAudienceScope.app
        : PostAudienceScope.faculty;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      if (_specializationController.text.trim().isEmpty &&
          (profile?.specialization.trim().isNotEmpty ?? false)) {
        _specializationController.text = profile!.specialization.trim();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _universityController.dispose();
    _eventDateController.dispose();
    _tagsController.dispose();
    _linkController.dispose();
    _linkTitleController.dispose();
    _specializationController.dispose();
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
      academicLink: _linkController.text,
      academicTitle: _linkTitleController.text,
      audienceScope: _audienceScope,
      facultyCategory: widget.room.facultyCategoryId ??
          _profile?.resolvedFacultyCategory,
      targetSpecialization: _specializationController.text,
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

  Widget _audienceOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _audienceScope == value;
    return InkWell(
      onTap: _submitting ? null : () => setState(() => _audienceScope = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? widget.room.color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? widget.room.color.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              PostAudienceScope.icon(value),
              color: selected ? widget.room.color : Colors.grey[700],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? widget.room.color : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? widget.room.color : Colors.grey[500],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEventDate = _type == CommunityPostType.announcement;
    final english = Localizations.localeOf(context).languageCode == 'en';

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
            const SizedBox(height: 18),
            Text(
              context.t('من يصل إليه المنشور؟', 'Who can see this post?'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            _audienceOption(
              value: PostAudienceScope.faculty,
              title: PostAudienceScope.label(
                PostAudienceScope.faculty,
                english: english,
              ),
              subtitle: context.t(
                'كل من يفتح غرفة هذه الكلية',
                'Anyone who opens this faculty room',
              ),
            ),
            _audienceOption(
              value: PostAudienceScope.specialization,
              title: PostAudienceScope.label(
                PostAudienceScope.specialization,
                english: english,
              ),
              subtitle: context.t(
                'فقط من تخصصهم يطابق ما تحدده',
                'Only viewers whose specialization matches',
              ),
            ),
            _audienceOption(
              value: PostAudienceScope.app,
              title: PostAudienceScope.label(
                PostAudienceScope.app,
                english: english,
              ),
              subtitle: context.t(
                'للأسئلة العامة عن الماجستير/الدكتوراه — يظهر للجميع',
                'General master’s/PhD topics — visible to everyone',
              ),
            ),
            if (_audienceScope == PostAudienceScope.specialization) ...[
              const SizedBox(height: 6),
              TextFormField(
                controller: _specializationController,
                decoration: InputDecoration(
                  labelText: context.t(
                    'التخصص المستهدف',
                    'Target specialization',
                  ),
                  hintText: context.t(
                    'مثال: ذكاء اصطناعي، شبكات…',
                    'e.g. AI, networks…',
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_audienceScope != PostAudienceScope.specialization) {
                    return null;
                  }
                  return value == null || value.trim().isEmpty
                      ? context.t('مطلوب', 'Required')
                      : null;
                },
              ),
            ],
            if (_audienceScope == PostAudienceScope.app) ...[
              const SizedBox(height: 6),
              Text(
                context.t(
                  'سيُحفظ في غرفة «عام» ويظهر أيضاً داخل غرف التخصص.',
                  'Saved in the General room and also shown in faculty rooms.',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
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
                labelText:
                    context.t('الجامعة (اختياري)', 'University (optional)'),
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
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
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
