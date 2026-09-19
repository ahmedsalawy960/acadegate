import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/directory/directory_trust_service.dart';
import '../../core/directory/directory_trust_status.dart';
import '../../core/locale/locale_extensions.dart';
import '../store/add_product_screen.dart';

/// After Managed Verified: arrange supplier directory data + add products.
class ManagedSupplierProfileScreen extends StatefulWidget {
  const ManagedSupplierProfileScreen({
    super.key,
    required this.supplierId,
  });

  final String supplierId;

  @override
  State<ManagedSupplierProfileScreen> createState() =>
      _ManagedSupplierProfileScreenState();
}

class _ManagedSupplierProfileScreenState
    extends State<ManagedSupplierProfileScreen> {
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _website = TextEditingController();
  final _about = TextEditingController();
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
    _nameAr.dispose();
    _nameEn.dispose();
    _email.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _city.dispose();
    _address.dispose();
    _website.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('store_suppliers')
        .doc(widget.supplierId)
        .get();
    final d = snap.data() ?? {};
    _nameAr.text = d['nameAr']?.toString() ?? d['name']?.toString() ?? '';
    _nameEn.text = d['nameEn']?.toString() ?? '';
    _email.text = d['email']?.toString() ?? '';
    _phone.text = d['phone']?.toString() ?? '';
    _whatsapp.text = d['whatsapp']?.toString() ?? '';
    _city.text = d['city']?.toString() ?? '';
    _address.text = d['address']?.toString() ?? '';
    _website.text = d['website']?.toString() ?? '';
    _about.text = d['about']?.toString() ?? d['description']?.toString() ?? '';
    _status = DirectoryTrustStatus.normalize(d['directoryStatus']?.toString());
    _lastManagedIso = d['lastManagedIso']?.toString();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String().split('T').first;
      await FirebaseFirestore.instance
          .collection('store_suppliers')
          .doc(widget.supplierId)
          .set({
        'nameAr': _nameAr.text.trim(),
        'nameEn': _nameEn.text.trim(),
        'name': _nameAr.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'city': _city.text.trim(),
        'address': _address.text.trim(),
        'website': _website.text.trim(),
        'about': _about.text.trim(),
        'lastManagedAt': FieldValue.serverTimestamp(),
        'lastManagedIso': nowIso,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await DirectoryTrustService.instance.touchLastManaged(
        targetType: 'supplier',
        targetId: widget.supplierId,
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
        title: Text(context.t('إدارة ملف المورد', 'Manage supplier profile')),
        backgroundColor: const Color(0xFF1A237E),
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
                  controller: _nameAr,
                  decoration: InputDecoration(
                    labelText: context.t('الاسم بالعربية', 'Name (AR)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameEn,
                  decoration: InputDecoration(
                    labelText: context.t('الاسم بالإنجليزية', 'Name (EN)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _about,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.t('نبذة / منشور', 'About / published blurb'),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _whatsapp,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _city,
                  decoration: InputDecoration(
                    labelText: context.t('المدينة', 'City'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _address,
                  decoration: InputDecoration(
                    labelText: context.t('العنوان', 'Address'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _website,
                  decoration: InputDecoration(
                    labelText: context.t('الموقع', 'Website'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(context.t('حفظ الترتيب', 'Save arrangement')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final storeName = _nameAr.text.trim().isNotEmpty
                        ? _nameAr.text.trim()
                        : _nameEn.text.trim();
                    final contact = [
                      if (_phone.text.trim().isNotEmpty) _phone.text.trim(),
                      if (_whatsapp.text.trim().isNotEmpty)
                        _whatsapp.text.trim(),
                      if (_email.text.trim().isNotEmpty) _email.text.trim(),
                    ].join(' · ');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddProductScreen(
                          categoryTitle: 'مستلزمات عامة',
                          supplierId: widget.supplierId,
                          storeNameHint: storeName,
                          contactHint: contact,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_box_outlined),
                  label: Text(
                    context.t('إضافة منتج / صور', 'Add product / images'),
                  ),
                ),
              ],
            ),
    );
  }
}
