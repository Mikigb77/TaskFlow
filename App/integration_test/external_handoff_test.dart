// Requires the exact synthetic Calendar Provider fixture in HANDOFF_VALIDATION.
// At HANDOFF_READY the host observes/screenshots the external app, writes that
// phase to the printed private acknowledgement file, then returns to MainActivity.
// Lifecycle return alone cannot prove that an external app displayed the item.
import 'dart:convert';
import 'dart:io';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/device_calendar_events.dart';
import 'package:agenda/widgets/note_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../test/support/design_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const skipCalendar = bool.fromEnvironment('HANDOFF_SKIP_CALENDAR');
  testWidgets('external browser/file handoffs; skip calendar=$skipCalendar',
      (tester) async {
    const calendarId = String.fromEnvironment('HANDOFF_CALENDAR_ID');
    const eventId = String.fromEnvironment('HANDOFF_EVENT_ID');
    expect(calendarId, isNotEmpty);
    expect(eventId, isNotEmpty);
    final bridge = DeviceCalendars();
    expect(await bridge.status(), CalendarAccess.granted);
    final calendar = (await bridge.calendars()).items.singleWhere((c) =>
        c.id == calendarId && c.account == 'taskflow-handoff-fixture-20260922');
    final day = DateTime.now();
    final event = (await bridge.events({calendar.id}, day)).items.singleWhere(
        (e) => e.id == eventId && e.title == 'TaskFlow-handoff-fixture');
    final file = File(p.join((await getApplicationSupportDirectory()).path,
        'taskflow-handoff-fixture-${DateTime.now().microsecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(_pdfFixture(), flush: true);
    final acknowledgement = File(p.join(file.parent.path,
        'taskflow-handoff-ack-${DateTime.now().microsecondsSinceEpoch}.txt'));
    await acknowledgement.writeAsString('');
    debugPrint('HANDOFF_ACK_FILE: ${p.basename(acknowledgement.path)}');
    final task = Task(
        id: -99001,
        title: 'Handoff fixture',
        priority: 1,
        filePaths: [file.path]);
    final api = OfflineApiClient();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      deviceCalendarsProvider.overrideWithValue(bridge),
      calendarPreferenceStoreProvider.overrideWithValue(_TransientCalendarStore(
          CalendarPreferences(
              enabled: true, selected: {calendar.selectionKey}))),
      attachmentEntriesProvider.overrideWith((ref, id) async {
        if (id != task.id) throw StateError('Unexpected fixture task.');
        return [
          AttachmentEntry(
              'TaskFlow handoff fixture.pdf', file.path, await file.exists())
        ];
      }),
    ]);
    addTearDown(() async {
      container.dispose();
      bridge.close();
      api.close();
      if (await file.exists()) await file.delete();
      if (await acknowledgement.exists()) await acknowledgement.delete();
    });
    await container.read(deviceCalendarProvider.notifier).ready;
    expect(await container.read(attachmentEntriesProvider(task.id!).future),
        hasLength(1));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const NoteText('http://10.0.2.2:8088/api/health/'),
                          const SizedBox(height: 24),
                          AttachmentPanel(task: task),
                          const SizedBox(height: 24),
                          DeviceCalendarEvents(day: day),
                        ]))))));
    await tester.pumpAndSettle();
    final strings = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await _handoff(tester, acknowledgement, 'browser',
        find.widgetWithText(TextButton, 'http://10.0.2.2:8088/api/health/'));
    expect(find.text(strings.linkOpenError), findsNothing);
    final attachmentState = container.read(attachmentEntriesProvider(task.id!));
    expect(attachmentState.error, isNull,
        reason: attachmentState.stackTrace.toString());
    await container.read(attachmentEntriesProvider(task.id!).future);
    await tester.pumpAndSettle();
    await _handoff(tester, acknowledgement, 'file',
        find.widgetWithText(TextButton, 'Open'));
    expect(find.text(strings.fileActionError), findsNothing);
    if (!skipCalendar) {
      final tile = find.text(event.title);
      await tester.scrollUntilVisible(tile, 160,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await _handoff(tester, acknowledgement, 'calendar',
          find.text('Open in calendar app'));
      expect(find.text(strings.calendarOpenError), findsNothing);
    }
    expect(await file.exists(), isTrue);
    expect(
        (await bridge.events({calendarId}, day))
            .items
            .singleWhere((e) => e.id == eventId)
            .title,
        event.title);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugPrint('EXTERNAL_HANDOFF_VALIDATED: browser, file'
        '${skipCalendar ? '; calendar explicitly excluded' : ', calendar'}');
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _handoff(WidgetTester tester, File acknowledgement, String name,
    Finder control) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  final observer = _HandoffObserver();
  WidgetsBinding.instance.addObserver(observer);
  try {
    debugPrint('HANDOFF_READY: $name');
    await tester.tap(control);
    final watch = Stopwatch()..start();
    while (!observer.returned ||
        (await acknowledgement.readAsString()).trim() != name) {
      if (watch.elapsed > const Duration(seconds: 45)) {
        fail('The host did not observe and return from the $name handoff.');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    debugPrint('HANDOFF_RETURNED: $name');
  } finally {
    WidgetsBinding.instance.removeObserver(observer);
  }
}

class _HandoffObserver extends WidgetsBindingObserver {
  bool left = false, returned = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) left = true;
    if (state == AppLifecycleState.resumed && left) returned = true;
  }
}

class _TransientCalendarStore extends CalendarPreferenceStore {
  _TransientCalendarStore(this.value) : super('external-handoff-fixture');
  CalendarPreferences value;
  @override
  Future<CalendarPreferences> read() async => value;
  @override
  Future<void> write(CalendarPreferences preferences) async =>
      value = preferences;
}

// One minimal ASCII PDF, with calculated byte offsets and no external assets.
List<int> _pdfFixture() {
  const text = 'BT /F1 20 Tf 72 700 Td (TaskFlow handoff fixture) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${text.length} >>\nstream\n$text\nendstream',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = buffer.length;
  buffer.write('xref\n0 6\n0000000000 65535 f \n');
  for (final offset in offsets) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return ascii.encode(buffer.toString());
}
