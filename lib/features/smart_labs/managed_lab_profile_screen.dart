import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/directory/directory_trust_service.dart';
import '../../core/directory/directory_trust_status.dart';
import '../../core/locale/locale_extensions.dart';

/// After Managed Verified: arrange lab contacts, description, services notes.
class ManagedLabProfileScreen extends StatefulWidget {
  const ManagedLabProfileScreen({super.key, required this.labId});

  final String labId;

  @override
  State<ManagedLabProfileScreen> createState() =>
      _ManagedLabProfileScreenState();
}

class _ManagedLabProfileScreenState extends State<ManagedLabProfileScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _contactName = TextEditingController();
  final _location = TextEditingController();
  final _servicesNote = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _status = DirectoryTrustStatus.unverified;
  String? _lastManagedIso;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _email.dispose();
    _phone.dispose();
    _contactName.dispose();
    _location.dispose();
    _servicesNote.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snap =
        await FirebaseFirestore.instance.collection('labs').doc(widget.labId).get();
    final d = snap.data() ?? {};
    _name.text = d['name']?.toString() ?? '';
    _description.text = d['description']?.toString() ?? '';
    _email.text = d['contactEmail']?.toString() ?? '';
    _phone.text = d['contactPhone']?.toString() ?? '';
    _contactName.text = d['contactName']?.toString() ?? '';
    _location.text = d['location']?.toString() ?? '';
    _servicesNote.text = d['servicesNote']?.toString() ?? '';
    _status = DirectoryTrustStatus.normalize(d['directoryStatus']?.toString());
    _lastManagedIso = d['lastManagedIso']?.toString();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    setState(() => _saving = true);
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;
      await FirebaseFirestore.instance.collection('labs').doc(widget.labId).set({
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'contactEmail': _email.text.trim(),
        'contactPhone': _phone.text.trim(),
        'contactName': _contactName.text.trim(),
        'location': _location.text.trim(),
        'servicesNote': _servicesNote.text.trim(),
        'lastManagedAt': FieldValue.serverTimestamp(),
        'lastManagedIso': nowIso,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await DirectoryTrustService.instance.touchLastManaged(
        targetType: 'lab',
        targetId: widget.labId,
      );
      if (!mounted) return;
      setState(() => _lastManagedIso = nowIso);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('تم الحفظ', 'Saved'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('إدارة ملف المختبر', 'Manage lab profile')),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DirectoryTrustChip(
                  status: _status,
                  lastManagedLabel: _lastManagedIso,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: context.t('اسم المختبر', 'Lab name'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.t('الوصف المنشور', 'Published description'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _servicesNote,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.t(
                      'الخدمات (نص)',
                      'Services (text)',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _location,
                  decoration: InputDecoration(
                    labelText: context.t('الموقع', 'Location'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contactName,
                  decoration: InputDecoration(
                    labelText: context.t('جهة التواصل', 'Contact name'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phone,
                  decoration: InputDecoration(
                    labelText: context.t('هاتف', 'Phone'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(context.t('حفظ الترتيب', 'Save arrangement')),
                ),
              ],
            ),
    );
  }
}
