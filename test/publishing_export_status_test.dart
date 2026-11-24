import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';

void main() {
  test('ready-to-submit status round trips and remains editable', () {
    final manuscript = PublishManuscript.fromMap({
      'userId': 'qa',
      'status': 'readyToSubmit',
      'title': 'QA paper',
    }, id: 'qa');
    expect(manuscript.status, ManuscriptStatus.readyToSubmit);
    expect(manuscript.toMap()['status'], 'readyToSubmit');
    expect(manuscript.status, isNot(ManuscriptStatus.submitted));
  });

  test('legacy export-only submitted values read as ready, not submitted', () {
    final manuscript = PublishManuscript.fromMap({
      'userId': 'qa', 'status': 'submitted',
    }, id: 'legacy');
    expect(manuscript.status, ManuscriptStatus.readyToSubmit);
    expect(manuscript.toMap()['status'], 'readyToSubmit');
    expect(manuscript.toMap().containsKey('submittedAt'), isFalse);
  });

  test('draft, formatted and unknown stored values keep safe defaults', () {
    expect(manuscriptStatusFromStored('draft'), ManuscriptStatus.draft);
    expect(manuscriptStatusFromStored('formatted'), ManuscriptStatus.formatted);
    expect(manuscriptStatusFromStored('unknown'), ManuscriptStatus.draft);
    expect(manuscriptStatusFromStored(null), ManuscriptStatus.draft);
  });

  // Wiring guards supplement model tests, not a live Firestore integration test.
  test('only successful Word save marks ready; no pre-export status change', () {
    final screen = File('lib/features/acadegate_publish/journal_format_apply_screen.dart').readAsStringSync();
    expect(screen, isNot(contains('submitToJournal(')));
    expect(screen, isNot(contains('markFormatted(')));
    expect(screen, isNot(contains('status: ManuscriptStatus.formatted')));
    final cancelled = screen.indexOf('if (!export.saved)');
    final ready = screen.indexOf('ManuscriptService.instance.markReadyToSubmit(');
    expect(cancelled, greaterThanOrEqualTo(0));
    expect(ready, greaterThan(cancelled));
    expect(screen.substring(cancelled, ready), contains('return;'));
  });

  test('ready write deletes obsolete submitted timestamp, never creates one', () {
    final service = File('lib/features/acadegate_publish/publish_services.dart').readAsStringSync();
    final start = service.indexOf('Future<void> markReadyToSubmit(');
    final end = service.indexOf('class JournalCatalogService', start);
    final method = service.substring(start, end);
    expect(method, contains("'status': ManuscriptStatus.readyToSubmit.name"));
    expect(method, contains("'readyToSubmitAt': FieldValue.serverTimestamp()"));
    expect(method, contains("'submittedAt': FieldValue.delete()"));
    expect(service, isNot(contains('ManuscriptStatus.submitted.name')));
  });
}
