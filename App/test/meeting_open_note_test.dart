// A tapped "Your meeting notes are ready" (MN-11) opens its note in the app
// for the account that recorded it, and marks it seen; one for another
// account on this phone opens nothing.
import 'dart:io';

import 'package:agenda/main.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/design_fixtures.dart';
import 'support/meeting_screen_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  setUpAll(() => databaseFactory = databaseFactoryFfi);

  setUp(() async {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => null);
    directory = await Directory.systemTemp.createTemp('taskflow-meeting-open-');
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDown(() async {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    TaskReminders.openNote.value = null;
    await TaskDatabase().close();
    await directory.delete(recursive: true);
  });

  Future<(ProviderContainer, ScriptedMeetings)> app(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final meetings = ScriptedMeetings();
    final container = designContainer(overrides: [meetingsOverride(meetings)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);
    return (container, meetings);
  }

  testWidgets('this account’s notes open, and are marked seen', (tester) async {
    final (container, meetings) = await app(tester);
    TaskReminders.openNote.value = MeetingNoteReference(
      90,
      container.read(captureOwnerProvider),
      'meeting-1',
    );
    await tester.pumpAndSettle();
    final detail = tester.widget<TaskDetailScreen>(
      find.byType(TaskDetailScreen),
    );
    expect(detail.taskId, 90);
    expect(meetings.calls.seen, ['meeting-1']);
    expect(TaskReminders.openNote.value, isNull);
  });

  testWidgets('another account’s notes open nothing', (tester) async {
    final (_, meetings) = await app(tester);
    TaskReminders.openNote.value = const MeetingNoteReference(
      90,
      'https://api.example.invalid/users/999',
      'meeting-1',
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsNothing);
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(meetings.calls.seen, isEmpty);
    expect(TaskReminders.openNote.value, isNull);
  });

  group('P325 · meeting notifications', () {
    testWidgets('UX-2811: the note the notification opens removes it', (
      tester,
    ) async {
      final opened = <int>[];
      final hook = MeetingHooks.noteOpened;
      MeetingHooks.noteOpened = (id) async => opened.add(id);
      addTearDown(() => MeetingHooks.noteOpened = hook);
      final (container, meetings) = await app(tester);
      TaskReminders.openNote.value = MeetingNoteReference(
        90,
        container.read(captureOwnerProvider),
        'meeting-1',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TaskDetailScreen>(find.byType(TaskDetailScreen)).taskId,
        90,
      );
      expect(opened, [90]);
      expect(meetings.calls.seen, ['meeting-1']);
    });
  });
}
