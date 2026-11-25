import 'advisor_branding.dart';

/// Prepares an assistant/user message body for the plain-text chat bubble.
///
/// The bubble renders a [Text] widget, not a markdown widget, so markers
/// that survive to the screen read as literal characters (a reply heading
/// showed as "### ..."). Strip the markers the model emits: **bold**,
/// ``` fences, and leading heading hashes. Pure function, unit-tested in
/// test/advisor_agent_selection_test.dart.
String formatAdvisorMessageContent(String content) {
  return content
      .replaceAll(AdvisorBranding.planMarker, '')
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), ''))
      .join('\n')
      .replaceAll('**', '')
      .replaceAll('```', '');
}
