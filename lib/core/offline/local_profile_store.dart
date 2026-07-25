import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/profile/academic_profile.dart';

/// Offline cache for [AcademicProfile] and journey prefs (works without network).
class LocalProfileStore {
  LocalProfileStore._();

  static final LocalProfileStore instance = LocalProfileStore._();

  static const _profileKey = 'offline_academic_profile';
  static const _onboardingDoneKey = 'journey_onboarding_done';
  static const _journeyStageKey = 'journey_stage';
  static const _thesisProgressKey = 'offline_thesis_progress';
  static const _lastMatchAlertKey = 'last_smart_match_alert_ms';
  static const _notifiedSupervisorIdsKey = 'smart_match_notified_supervisor_ids';
  static const _sampleSlaRemindersKey = 'sample_sla_reminders_sent';

  Future<void> saveProfile(AcademicProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toMap()));
  }

  Future<AcademicProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AcademicProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  Future<void> setOnboardingDone({required bool done, String? stage}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, done);
    if (stage != null) {
      await prefs.setString(_journeyStageKey, stage);
    }
  }

  Future<String?> journeyStage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_journeyStageKey);
  }

  Future<void> saveThesisProgressJson(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_thesisProgressKey, json);
  }

  Future<String?> loadThesisProgressJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_thesisProgressKey);
  }

  Future<DateTime?> lastSmartMatchAlertAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastMatchAlertKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastSmartMatchAlertAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastMatchAlertKey, time.millisecondsSinceEpoch);
  }

  Future<bool> wasSmartMatchSupervisorNotified(String supervisorId) async {
    if (supervisorId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_notifiedSupervisorIdsKey) ?? const [];
    return raw.contains(supervisorId);
  }

  Future<void> markSmartMatchSupervisorNotified(String supervisorId) async {
    if (supervisorId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_notifiedSupervisorIdsKey) ?? const [];
    if (raw.contains(supervisorId)) return;
    final next = [...raw, supervisorId];
    if (next.length > 100) {
      next.removeRange(0, next.length - 100);
    }
    await prefs.setStringList(_notifiedSupervisorIdsKey, next);
  }

  Future<bool> wasSampleSlaReminderSent(String requestKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sampleSlaRemindersKey) ?? const [];
    return raw.contains(requestKey);
  }

  Future<void> markSampleSlaReminderSent(String requestKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sampleSlaRemindersKey) ?? const [];
    if (raw.contains(requestKey)) return;
    final next = [...raw, requestKey];
    if (next.length > 200) {
      next.removeRange(0, next.length - 200);
    }
    await prefs.setStringList(_sampleSlaRemindersKey, next);
  }
}
