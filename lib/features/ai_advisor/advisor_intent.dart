import 'advisor_query_parser.dart';

enum AdvisorIntent {
  thesisTitles,
  researchQuestion,
  summarize,
  supervisorMatch,
  general,
}

AdvisorIntent detectAdvisorIntent(String message) {
  final text = message.toLowerCase();

  if (_matchesAny(text, [
    'عناوين',
    'عنوان',
    'اقترح لي',
    'اقترح',
    'مواضيع رسالة',
    'موضوع رسالة',
  ])) {
    return AdvisorIntent.thesisTitles;
  }

  if (_matchesAny(text, [
    'سؤال بحثي',
    'حوّل فكرتي',
    'حول فكرتي',
    'صياغة سؤال',
    'صيغ سؤال',
  ])) {
    return AdvisorIntent.researchQuestion;
  }

  if (_matchesAny(text, [
    'لخّص',
    'لخص',
    'ملخص',
    'تلخيص',
    'abstract',
  ])) {
    return AdvisorIntent.summarize;
  }

  if (_matchesAny(text, [
    'مشرف',
    'الأنسب',
    'الانسب',
    'من يشرف',
    'أشرفني',
  ])) {
    return AdvisorIntent.supervisorMatch;
  }

  return AdvisorIntent.general;
}

bool _matchesAny(String text, List<String> keywords) {
  return keywords.any(text.contains);
}

String? extractAdvisorTopic(String message) {
  final parsed = AcademicQueryParser.parse(message);
  if (parsed.hasClearSubject) return parsed.subject;
  return null;
}

String extractIdeaText(String message) {
  final parsed = AcademicQueryParser.parse(message);
  if (parsed.hasClearSubject) return parsed.subject;
  return parsed.rawMessage;
}
