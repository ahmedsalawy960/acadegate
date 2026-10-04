import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'literary_instrument_models.dart';
import 'survey_models.dart';

class ResearchToolsStorage {
  ResearchToolsStorage._();
  static final ResearchToolsStorage instance = ResearchToolsStorage._();

  static const _kInstrument = 'research_tools_survey_v1';
  static const _kFace = 'research_tools_face_validity_v1';
  static const _kInterview = 'research_tools_interview_v1';
  static const _kContent = 'research_tools_content_v1';
  static const _kCorpus = 'research_tools_corpus_v1';

  Future<SurveyInstrument?> loadInstrument() async {
    final prefs = await SharedPreferences.getInstance();
    return SurveyInstrument.tryDecode(prefs.getString(_kInstrument));
  }

  Future<void> saveInstrument(SurveyInstrument instrument) async {
    instrument.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInstrument, instrument.encode());
  }

  Future<List<FaceValidityCheck>> loadFaceChecks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFace);
    if (raw == null || raw.isEmpty) return FaceValidityCheck.defaults();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .whereType<Map>()
          .map((e) => FaceValidityCheck.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (parsed.isEmpty) return FaceValidityCheck.defaults();
      return parsed;
    } catch (_) {
      return FaceValidityCheck.defaults();
    }
  }

  Future<void> saveFaceChecks(List<FaceValidityCheck> checks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kFace,
      jsonEncode(checks.map((e) => e.toJson()).toList()),
    );
  }

  Future<InterviewProtocol?> loadInterview() async {
    final prefs = await SharedPreferences.getInstance();
    return InterviewProtocol.tryDecode(prefs.getString(_kInterview));
  }

  Future<void> saveInterview(InterviewProtocol protocol) async {
    protocol.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInterview, protocol.encode());
  }

  Future<ContentAnalysisSheet?> loadContentSheet() async {
    final prefs = await SharedPreferences.getInstance();
    return ContentAnalysisSheet.tryDecode(prefs.getString(_kContent));
  }

  Future<void> saveContentSheet(ContentAnalysisSheet sheet) async {
    sheet.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kContent, sheet.encode());
  }

  Future<CorpusDocumentCard?> loadCorpus() async {
    final prefs = await SharedPreferences.getInstance();
    return CorpusDocumentCard.tryDecode(prefs.getString(_kCorpus));
  }

  Future<void> saveCorpus(CorpusDocumentCard card) async {
    card.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCorpus, card.encode());
  }
}
