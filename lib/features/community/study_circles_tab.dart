import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/faculty_categories.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_screen.dart';
import 'research_room_navigator.dart';
import 'research_room_service.dart';
import 'study_circle_models.dart';
import 'study_circle_service.dart';

class StudyCirclesTab extends StatefulWidget {
  const StudyCirclesTab({super.key});

  @override
  State<StudyCirclesTab> createState() => _StudyCirclesTabState();
}

class _StudyCirclesTabState extends State<StudyCirclesTab> {
  AcademicProfile? _profile;
  List<StudyCircle> _suggested = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await StudyCircleService.instance.currentProfile();
    final suggested =
        await StudyCircleService.instance.suggestForProfile(profile);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _suggested = suggested;
      _loading = false;
    });
  }

  Future<void> _createCircle() async {
    final profile = _profile;
    if (profile == null || !profile.isComplete) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('الملف الأكاديمي', 'Academic profile')),
          content: Text(context.t(
            'أكمل ملفك الأكاديمي أولاً لنقترح دائرة دراسة مناسبة.',
            'Complete your academic profile first for a better study circle.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('لاحقاً', 'Later')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.t('فتح الملف', 'Open profile')),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AcademicProfileScreen()),
        );
        await _load();
      }
      return;
    }

    final titleController = TextEditingController(
      text: context.t(
        'دائرة ${profile.specialization}',
        '${profile.specialization} circle',
      ),
    );
    final descController = TextEditingController(
      text: profile.researchInterest,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('إنشاء دائرة دراسة', 'Create study circle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: context.t('اسم الدائرة', 'Circle name'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.t('الوصف', 'Description'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('إنشاء', 'Create')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = await StudyCircleService.instance.createCircle(
      title: titleController.text,
      description: descController.text,
      facultyCategory: profile.resolvedFacultyCategory ?? '',
      specialization: profile.specialization,
      researchInterest: profile.researchInterest,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t(
          'تم إنشاء دائرة الدراسة وغرفة مرتبطة',
          'Study circle and linked room created',
        )),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Future<void> _join(StudyCircle circle) async {
    final error = await StudyCircleService.instance.joinCircle(circle);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final roomId = circle.researchRoomId;
    if (roomId != null && roomId.isNotEmpty) {
      final room = await ResearchRoomService.instance.getRoom(roomId);
      if (!mounted) return;
      if (room != null) {
        await openResearchRoom(context, room);
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('انضممت للدائرة', 'Joined the circle')),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final faculty = _profile?.resolvedFacultyCategory;
    final facultyTitle = faculty == null || faculty.isEmpty
        ? null
        : facultyTitleForCategory(faculty);

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00695C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            facultyTitle == null
                ? context.t(
                    'دوائر دراسة تُطابق تخصصك واهتمامك البحثي، مع غرفة شات مرتبطة.',
                    'Study circles matched to your field and research interest, with a linked chat room.',
                  )
                : context.t(
                    'مقترحات لـ $facultyTitle — ${_profile?.specialization ?? ''}',
                    'Suggestions for $facultyTitle — ${_profile?.specialization ?? ''}',
                  ),
            style: const TextStyle(height: 1.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: _createCircle,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00695C),
              ),
              icon: const Icon(Icons.groups_outlined),
              label: Text(context.t('إنشاء دائرة', 'Create circle')),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _suggested.isEmpty
              ? Center(
                  child: Text(
                    context.t(
                      'لا دوائر بعد — أنشئ الأولى لمجالك.',
                      'No circles yet — create the first for your field.',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _suggested.length,
                  itemBuilder: (context, index) {
                    final circle = _suggested[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1A00695C),
                          child: Icon(Icons.school, color: Color(0xFF00695C)),
                        ),
                        title: Text(
                          circle.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            if (circle.facultyCategory.isNotEmpty)
                              StudyCircleService.instance
                                  .facultyLabel(circle.facultyCategory),
                            context.t(
                              '${circle.membersCount} أعضاء',
                              '${circle.membersCount} members',
                            ),
                            if (circle.specialization.isNotEmpty)
                              circle.specialization,
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FilledButton(
                          onPressed: () => _join(circle),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                          ),
                          child: Text(context.t('انضم', 'Join')),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
