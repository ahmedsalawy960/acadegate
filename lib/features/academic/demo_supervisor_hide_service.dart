import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/locale/l10n_lookup.dart';
import '../auth/user_account_service.dart';
import 'academic_models.dart';

/// يخفي المشرفين التجريبيين (بدون مستند Firestore) عند حذفهم من قبل المدير.
class DemoSupervisorHideService {
  DemoSupervisorHideService._();

  static final DemoSupervisorHideService instance = DemoSupervisorHideService._();

  static const _prefsKey = 'hidden_demo_supervisor_ids';
  static const _settingsDoc = 'app_settings/supervisor_demos';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> canHide() async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    return account?.isAdmin == true;
  }

  Stream<Set<String>> watchHiddenIds() async* {
    yield await _loadLocal();

    try {
      await for (final snapshot in _db.doc(_settingsDoc).snapshots()) {
        final remote = _parseIds(snapshot.data());
        await _saveLocal(remote);
        yield remote;
      }
    } catch (_) {
      yield await _loadLocal();
    }
  }

  Future<Set<String>> loadHiddenIds() async {
    try {
      final snapshot = await _db.doc(_settingsDoc).get();
      final remote = _parseIds(snapshot.data());
      await _saveLocal(remote);
      return remote;
    } catch (_) {
      return _loadLocal();
    }
  }

  List<AcademicSupervisor> filterVisible(
    List<AcademicSupervisor> supervisors,
    Set<String> hiddenIds,
  ) {
    if (hiddenIds.isEmpty) return supervisors;
    return supervisors
        .where((supervisor) {
          final id = supervisor.id;
          if (id == null || id.isEmpty) return true;
          return !hiddenIds.contains(id);
        })
        .toList();
  }

  Future<bool> confirmAndHide(
    BuildContext context, {
    required String demoId,
    required String itemLabel,
  }) async {
    if (!await canHide()) return false;
    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10nLookup.confirmDelete),
        content: Text(L10nLookup.deleteConfirmMessage(itemLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L10nLookup.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L10nLookup.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await _db.doc(_settingsDoc).set(
        {
          'hiddenIds': FieldValue.arrayUnion([demoId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // يُكمل بالتخزين المحلي عند فشل الشبكة.
    }

    await _addLocal(demoId);
    return true;
  }

  Set<String> _parseIds(Map<String, dynamic>? data) {
    final raw = data?['hiddenIds'];
    if (raw is! List) return {};
    return raw.map((item) => item.toString()).where((id) => id.isNotEmpty).toSet();
  }

  Future<Set<String>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey)?.toSet() ?? {};
  }

  Future<void> _saveLocal(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, ids.toList());
  }

  Future<void> _addLocal(String demoId) async {
    final ids = await _loadLocal();
    ids.add(demoId);
    await _saveLocal(ids);
  }
}
