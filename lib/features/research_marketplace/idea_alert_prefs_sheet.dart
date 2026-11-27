import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/faculty_categories.dart';

/// ورقة اختيار تنبيهات الأفكار الجديدة لكل كلية.
/// تكتب idea_alert_subscriptions/{uid} — وظيفة التنبيهات اليومية تقرأه
/// وترسل إشعارًا داخل التطبيق + Push للمشتركين.
class IdeaAlertPrefsSheet extends StatefulWidget {
  const IdeaAlertPrefsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const IdeaAlertPrefsSheet(),
    );
  }

  @override
  State<IdeaAlertPrefsSheet> createState() => _IdeaAlertPrefsSheetState();
}

class _IdeaAlertPrefsSheetState extends State<IdeaAlertPrefsSheet> {
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('idea_alert_subscriptions')
          .doc(uid)
          .get();
      final raw = doc.data()?['faculties'];
      if (raw is List) {
        _selected.addAll(raw.map((e) => e.toString()));
      }
    } catch (_) {
      // الوثيقة غير موجودة بعد — تبدأ فارغة.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    final ref = FirebaseFirestore.instance
        .collection('idea_alert_subscriptions')
        .doc(uid);
    try {
      if (_selected.isEmpty) {
        await ref.delete();
      } else {
        await ref.set({
          'faculties': _selected.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selected.isEmpty
                ? context.t('تم إيقاف تنبيهات الأفكار', 'Idea alerts turned off')
                : context.t(
                    'تم حفظ التنبيهات — ستصلك الأفكار الجديدة داخل التطبيق وخارجه',
                    'Alerts saved — new ideas will reach you in and out of the app',
                  ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'تنبيهات الأفكار الجديدة',
              'New idea alerts',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'اختر كلياتك — يصلك إشعار (داخل التطبيق وPush على الهاتف) عند نشر فكرة جديدة فيها.',
              'Pick your faculties — get a notification (in-app and phone push) when a new idea is published in them.',
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFFB7C3D6)),
          ),
          const SizedBox(height: 12),
          if (uid == null)
            Text(
              context.t('سجّل الدخول أولاً', 'Sign in first'),
              style: const TextStyle(color: Color(0xFFB7C3D6)),
            )
          else if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.select_all, size: 16),
                      label: Text(context.t('كل الكليات', 'All faculties')),
                      selected: _selected.contains('all'),
                      onSelected: (v) => setState(() {
                        _selected.clear();
                        if (v) _selected.add('all');
                      }),
                    ),
                    for (final id in facultyCategoryIds())
                      FilterChip(
                        label: Text(L10nLookup.facultyTitleStatic(id)),
                        selected:
                            _selected.contains('all') || _selected.contains(id),
                        onSelected: _selected.contains('all')
                            ? null
                            : (v) => setState(() {
                                  if (v) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                }),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (uid != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(context.t('حفظ التنبيهات', 'Save alerts')),
              ),
            ),
        ],
      ),
    );
  }
}
