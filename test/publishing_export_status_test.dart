import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadegate/features/acadegate_publish/publish_models.dart';
import 'package:acadegate/features/acadegate_publish/publish_services.dart';

void main() {
  for (final stored in ['readyToSubmit', 'submitted']) {
    test('legacy export-only $stored reads and serializes as formatted', () {
      final m = PublishManuscript.fromMap({
        'userId': 'qa',
        'status': stored,
        'title': 'QA paper',
        'body': 'Original scientific text.',
        'journalId': 'journal-qa',
        'journalName': 'QA Journal',
      }, id: 'qa');
      expect(m.status, ManuscriptStatus.formatted);
      expect(m.toMap()['status'], 'formatted');
      expect(m.body, 'Original scientific text.');
      expect(m.journalId, 'journal-qa');
      expect(m.toMap().containsKey('submittedAt'), isFalse);
      expect(m.toMap().containsKey('readyToSubmitAt'), isFalse);
    });
  }
  test('draft, formatted and unknown stored values keep safe defaults', () {
    expect(manuscriptStatusFromStored('draft'), ManuscriptStatus.draft);
    expect(manuscriptStatusFromStored('formatted'), ManuscriptStatus.formatted);
    expect(manuscriptStatusFromStored('unknown'), ManuscriptStatus.draft);
    expect(manuscriptStatusFromStored(null), ManuscriptStatus.draft);
  });
  test('direct legacy enum construction cannot write readiness either', () {
    for (final status in [
      ManuscriptStatus.readyToSubmit,
      ManuscriptStatus.submitted,
    ]) {
      expect(
        PublishManuscript(
          userId: 'qa',
          title: 'QA',
          status: status,
        ).toMap()['status'],
        'formatted',
      );
    }
  });
  test(
    'completed Word save update records action and deletes false timestamps',
    () {
      final update = journalWordExportUpdate(
        journalId: 'j-qa',
        journalName: 'QA Journal',
      );
      expect(update['status'], 'formatted');
      expect(update['journalId'], 'j-qa');
      expect(update['journalName'], 'QA Journal');
      expect(update['wordExportedAt'], FieldValue.serverTimestamp());
      expect(update['updatedAt'], FieldValue.serverTimestamp());
      expect(update['readyToSubmitAt'], FieldValue.delete());
      expect(update['submittedAt'], FieldValue.delete());
      expect(update.keys.toSet(), {
        'status',
        'journalId',
        'journalName',
        'wordExportedAt',
        'updatedAt',
        'readyToSubmitAt',
        'submittedAt',
      });
    },
  );
  test(
    'only successful Word save records export; no pre-export state change',
    () {
      final screen = File(
        'lib/features/acadegate_publish/journal_format_apply_screen.dart',
      ).readAsStringSync();
      expect(screen, isNot(contains('markReadyToSubmit(')));
      expect(screen, isNot(contains('submitToJournal(')));
      expect(screen, isNot(contains('markFormatted(')));
      final cancelled = screen.indexOf('if (!export.saved)');
      final record = screen.indexOf(
        'ManuscriptService.instance.recordJournalWordExport(',
      );
      expect(cancelled, greaterThanOrEqualTo(0));
      expect(record, greaterThan(cancelled));
      expect(screen.substring(cancelled, record), contains('return;'));
      expect(screen, contains('submission readiness has not been verified'));
      final service = File(
        'lib/features/acadegate_publish/publish_services.dart',
      ).readAsStringSync();
      expect(service, isNot(contains('ManuscriptStatus.readyToSubmit.name')));
      expect(service, isNot(contains('ManuscriptStatus.submitted.name')));
      expect(
        service,
        contains(
          'journalWordExportUpdate(journalId: journalId, journalName: journalName)',
        ),
      );
    },
  );
  test('all export-only display states require review in both languages', () {
    expect(
      manuscriptStatusLabel(ManuscriptStatus.draft, isEnglish: true),
      'Draft',
    );
    for (final status in ManuscriptStatus.values.where(
      (s) => s != ManuscriptStatus.draft,
    )) {
      expect(
        manuscriptStatusLabel(status, isEnglish: true),
        'Formatted - review required',
      );
      expect(
        manuscriptStatusLabel(status, isEnglish: false),
        'منسّق - يحتاج مراجعة',
      );
    }
    final hub = File(
      'lib/features/acadegate_publish/publish_hub_screen.dart',
    ).readAsStringSync();
    expect(hub.replaceAll(RegExp(r'\s+'), ''), contains('manuscriptStatusLabel(m.status,'));
    expect(hub, isNot(contains('Icons.task_alt')));
    expect(hub, isNot(contains('Ready to submit')));
  });
  testWidgets('review labels remain readable in list-card preview', (
    tester,
  ) async {
    final screenshot = Platform.environment['QA_EXPORT_STATUS_SCREENSHOT'];
    if (screenshot != null) {
      await tester.runAsync(() async {
        final font = FontLoader('QAReadable')
          ..addFont(
            File(
              '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await font.load();
      });
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: screenshot == null ? null : 'QAReadable'),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('QA Journal manuscript'),
                      subtitle: Text(
                        manuscriptStatusLabel(
                          ManuscriptStatus.formatted,
                          isEnglish: true,
                        ),
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: ListTile(
                        title: const Text('مسودة البحث'),
                        subtitle: Text(
                          manuscriptStatusLabel(
                            ManuscriptStatus.formatted,
                            isEnglish: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Formatted - review required'), findsOneWidget);
    expect(find.text('منسّق - يحتاج مراجعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (screenshot != null) {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(screenshot).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
