import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import 'writer_match_engine.dart';
import 'writing_categories.dart';
import 'writing_expert_detail_screen.dart';
import 'writing_models.dart';
import 'writing_service.dart';

class WriterMatchScreen extends StatefulWidget {
  const WriterMatchScreen({super.key});

  @override
  State<WriterMatchScreen> createState() => _WriterMatchScreenState();
}

class _WriterMatchScreenState extends State<WriterMatchScreen> {
  static const _brand = Color(0xFF5D4037);

  bool _loading = true;
  String? _error;
  String? _categoryFilter;
  List<({WritingExpert expert, int score, List<String> reasons})> _matches =
      const [];

  @override
  void initState() {
    super.initState();
    _runMatch();
  }

  Future<void> _runMatch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!await ensureLoggedIn(context)) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final profile = await AcademicProfileService.instance.loadProfile();
      if (profile == null || !profile.isComplete) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'incomplete_profile';
        });
        return;
      }

      final experts = await WritingService.instance.fetchAllExperts();
      final results = WriterMatchEngine.matchWriters(
        profile,
        experts,
        preferredCategoryTitle: _categoryFilter,
      );

      if (!mounted) return;
      setState(() {
        _matches = results
            .map((r) => (expert: r.item, score: r.score, reasons: r.reasons))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مطابقة كاتب', 'Match a writer')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('تحديث', 'Refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _runMatch,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String?>(
              initialValue: _categoryFilter,
              decoration: InputDecoration(
                labelText: context.t(
                  'تفضيل نوع الخدمة (اختياري)',
                  'Preferred service type (optional)',
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(context.t('كل الأنواع', 'All types')),
                ),
                ...writingCategories.map(
                  (c) => DropdownMenuItem(
                    value: c.title,
                    child: Text(c.localizedTitle),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _categoryFilter = v);
                _runMatch();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error == 'incomplete_profile') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t(
                  'أكمل ملفك الأكاديمي أولاً لمطابقة الكتّاب حسب تخصصك ولغتك.',
                  'Complete your academic profile first to match writers by specialty and language.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AcademicProfileScreen(),
                    ),
                  );
                  _runMatch();
                },
                child: Text(context.t('الملف الأكاديمي', 'Academic profile')),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_matches.isEmpty) {
      return Center(
        child: Text(
          context.t(
            'لا يوجد كتّاب متاحون للمطابقة حالياً',
            'No writers available to match yet',
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _matches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final m = _matches[i];
        final expert = m.expert;
        final cat = writingCategoryByTitle(expert.category);
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: (cat?.color ?? _brand).withValues(alpha: 0.15),
              child: Text(
                '${m.score}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cat?.color ?? _brand,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(expert.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expert.speciality),
                const SizedBox(height: 4),
                Text(
                  m.reasons.take(3).join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              if (cat == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WritingExpertDetailScreen(
                    expert: expert,
                    category: cat,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
