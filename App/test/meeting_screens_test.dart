// The meeting screens (App/docs/MEETING_NOTES.md, package A2): «Record a
// meeting» in Notes, the recording screen and what follows Stop, the
// Notes tab's lines for stopped and waiting meetings, «Create task» on a
// note with steps, the sign-out question, and the "notes ready"
// notification's words. The meeting core is scripted (ScriptedMeetings).
import 'dart:async';
import 'dart:convert';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/meeting_copy.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/account_screen.dart';
import 'package:agenda/screens/meeting_screen.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/capture_review_editor.dart';
import 'package:agenda/widgets/meeting_banners.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/meeting_screen_fakes.dart';

Widget _app(
  ProviderContainer container,
  Widget home, {
  String language = 'en',
  double scale = 1,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: AppTheme.light,
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
    routes: {
      '/subscription': (context) => SubscriptionScreen(
        reason: ModalRoute.of(context)?.settings.arguments as ProReason?,
      ),
    },
  ),
);

class _Tasks extends TaskNotifier {
  _Tasks(this.items) : super(MemoryTasks());
  final List<Task> items;
  @override
  Future<void> loadTasks() async => state = AsyncValue.data(items);
  @override
  Future<void> showLocal() => loadTasks();
}

final _meetingNote = Task(
  id: 90,
  kind: 'note',
  title: 'Pilot pricing with Acme',
  notes: 'We agreed the pilot.',
  priority: 1,
  checklist: [
    ChecklistItem(id: 's1', title: 'Send the pilot quote · Miki · Friday'),
    ChecklistItem(id: 's2', title: 'Book the room'),
    ChecklistItem(id: 's3', title: 'Already done', completed: true),
  ],
);

ProviderContainer _container(
  ScriptedMeetings meetings, {
  bool pro = true,
  List<Task>? tasks,
  List<Override> overrides = const [],
  RegionalPreferences regional = const RegionalPreferences(),
}) {
  final container = designContainer(
    pro: pro,
    tasks: tasks == null ? null : () => _Tasks(tasks),
    regionalStore: MemoryRegionalStore(regional),
    overrides: [meetingsOverride(meetings), ...overrides],
  );
  addTearDown(container.dispose);
  return container;
}

/// Notes with the scripted meetings, signed in, at [scale] on a small
/// phone.
Future<void> _notes(
  WidgetTester tester,
  ProviderContainer container, {
  String language = 'en',
  double scale = 1,
  Size size = const Size(360, 740),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(container, const NotesScreen(), language: language, scale: scale),
  );
  await tester.pumpAndSettle();
}

/// Frames enough for a route or a dialog, while a spinner spins.
Future<void> _pumpSpinning(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => TaskReminders.meetingsOnScreen.clear());

  group('Record a meeting', () {
    testWidgets('records, stops, prepares the notes and opens them', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings, tasks: [_meetingNote]);
      await _notes(tester, container);
      expect(find.text('Add a note'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();

      // Recording: listening, the elapsed time, a large Stop, Discard.
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(meetings.calls.started.single.title, 'Recording a meeting');
      expect(meetings.calls.started.single.channelName, 'Meeting recording');
      expect(meetings.calls.projects.single, isNull);
      expect(find.text('Recording'), findsOneWidget);
      expect(find.text('12:03'), findsOneWidget);
      final stop = tester.getSize(find.byKey(const ValueKey('meeting-stop')));
      final discard = tester.getSize(
        find.byKey(const ValueKey('meeting-discard')),
      );
      expect(stop.height, greaterThanOrEqualTo(72));
      expect(stop.width, greaterThan(discard.width));

      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await _pumpSpinning(tester);
      expect(meetings.calls.stops, 1);
      expect(find.text('Preparing your notes…'), findsOneWidget);
      expect(TaskReminders.meetingsOnScreen, {'meeting-1'});

      // No signal: it says so, and that the recording is safe.
      meetings.emit(
        meetings.state.copyWith(
          waiting: [fakeMeeting('meeting-1', problem: MeetingProblem.offline)],
        ),
      );
      await tester.pump();
      expect(find.text('Waiting for connection'), findsOneWidget);
      expect(find.textContaining('safe on this phone'), findsOneWidget);

      // The notes arrive: the note opens in the screen's place.
      meetings.notesSaved('meeting-1', 90);
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(find.text('Pilot pricing with Acme'), findsWidgets);
      expect(meetings.calls.seen, ['meeting-1']);
      expect(TaskReminders.meetingsOnScreen, isEmpty);
      // Back returns to Notes.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(NotesScreen), findsOneWidget);
    });

    testWidgets('without Pro, the Pro screen says what Pro gives here', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings, pro: false);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(
        find.text('With Pro, record a meeting and get its notes:'),
        findsOneWidget,
      );
      expect(
        find.text('a summary, the decisions and the to-dos'),
        findsOneWidget,
      );
      expect(meetings.calls.started, isEmpty);
    });

    testWidgets('Discard asks first: keep recording, or discard', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meeting-discard')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Discard this recording?'), findsOneWidget);
      await tester.tap(find.text('Keep recording'));
      await tester.pumpAndSettle();
      expect(meetings.calls.discardedRecordings, 0);
      expect(find.byType(MeetingScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meeting-discard')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Discard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(meetings.calls.discardedRecordings, 1);
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(NotesScreen), findsOneWidget);
    });

    testWidgets('Discard goes straight back: no «Preparing your notes…»', (
      tester,
    ) async {
      final meetings = ScriptedMeetings()..discardGate = Completer<void>();
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meeting-discard')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Discard'),
        ),
      );
      // The recording is gone; the discard hasn't finished yet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(meetings.calls.discardedRecordings, 1);
      expect(find.text('Preparing your notes…'), findsNothing);
      expect(find.byKey(const ValueKey('meeting-status')), findsNothing);
      meetings.discardGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(NotesScreen), findsOneWidget);
    });

    testWidgets('only silence: nothing is kept, and it says so', (
      tester,
    ) async {
      final meetings = ScriptedMeetings(silent: true);
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsNothing);
      expect(
        find.text('Nothing was heard, so there’s nothing to save.'),
        findsOneWidget,
      );
    });

    testWidgets('a refused microphone and a full phone say what to do', (
      tester,
    ) async {
      final meetings = ScriptedMeetings(refuse: MeetingStartProblem.permission);
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Permissions › Microphone'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting-stop')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('meeting-close')));
      await tester.pumpAndSettle();
      meetings.refuse = MeetingStartProblem.lowSpace;
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.textContaining('almost full'), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('leaving keeps it recording: Notes says so and reopens it', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(meetings.calls.stops, 0);
      expect(find.text('Recording a meeting · 12:03'), findsOneWidget);
      // One recording at a time: the entry gives way to its line.
      expect(find.byKey(const ValueKey('record-meeting')), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.text('12:03'), findsOneWidget);
      expect(meetings.calls.started, hasLength(1));
    });

    testWidgets('the notification: a tap, Stop and Discard come to the '
        'recording (MN-1, MN-25)', (tester) async {
      // The notification's buttons, as Android hands them to the app.
      Future<MeetingNoticeAction?> tapped(String? action) async {
        TaskReminders.meetingAction.value = null;
        await TaskReminders.respond(
          NotificationResponse(
            notificationResponseType: action == null
                ? NotificationResponseType.selectedNotification
                : NotificationResponseType.selectedNotificationAction,
            actionId: action,
            payload: jsonEncode({'meeting_recording': 1}),
          ),
        );
        return TaskReminders.meetingAction.value;
      }

      expect(await tapped(meetingStopAction), MeetingNoticeAction.stop);
      expect(await tapped(meetingDiscardAction), MeetingNoticeAction.discard);
      expect(await tapped(null), MeetingNoticeAction.open);
      TaskReminders.meetingAction.value = null;

      final l = lookupAppLocalizations(const Locale('es'));
      final android = meetingRecordingNotificationDetails(
        meetingNotice(l),
      ).android!;
      expect(android.channelId, meetingRecordingChannel);
      expect(android.ongoing, isTrue);
      expect(android.silent, isTrue);
      expect(android.actions!.map((action) => (action.id, action.title)), [
        (meetingStopAction, 'Parar'),
        (meetingDiscardAction, 'Descartar'),
      ]);
      // The buttons open the app, and leave the notification to the
      // recording: a Discard taken back keeps recording.
      expect(
        android.actions!.every(
          (action) => action.showsUserInterface && !action.cancelNotification,
        ),
        isTrue,
      );

      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      // Discard, with the recording screen in front: it asks first.
      unawaited(
        openMeetingNoticeAction(navigator, MeetingNoticeAction.discard),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Discard this recording?'), findsOneWidget);
      await tester.tap(find.text('Keep recording'));
      await tester.pumpAndSettle();
      expect(meetings.calls.discardedRecordings, 0);
      expect(find.byType(MeetingScreen), findsOneWidget);

      // A tap, with Notes in front: the recording opens, once.
      await tester.pageBack();
      await tester.pumpAndSettle();
      unawaited(openMeetingNoticeAction(navigator, MeetingNoticeAction.open));
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.text('12:03'), findsOneWidget);
      expect(meetings.calls.stops, 0);

      // Stop, with another screen over the recording's: the recording
      // screen comes to the front, once, and stops; the notes are prepared.
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Elsewhere')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsNothing);
      unawaited(openMeetingNoticeAction(navigator, MeetingNoticeAction.stop));
      await _pumpSpinning(tester);
      expect(meetings.calls.stops, 1);
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.text('Preparing your notes…'), findsOneWidget);
      await tester.pageBack();
      await _pumpSpinning(tester);
      expect(find.text('Elsewhere'), findsOneWidget);
      navigator.pop();
      await _pumpSpinning(tester);
      expect(find.byType(NotesScreen), findsOneWidget);
      expect(meetings.calls.started, hasLength(1));
    });

    testWidgets('the notification after the recording ended: nothing starts', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(openMeetingNoticeAction(navigator, MeetingNoticeAction.stop));
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(NotesScreen), findsOneWidget);
      expect(meetings.calls.started, isEmpty);
      expect(meetings.calls.stops, 0);
    });

    testWidgets('little space left: it says so and records on (MN-6)', (
      tester,
    ) async {
      final meetings = ScriptedMeetings(
        freeBytes: () async => 200 * 1024 * 1024,
      );
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Low on space: the recording stops by itself if the phone fills up.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
      expect(meetings.calls.started, hasLength(1));
    });

    testWidgets('enough space: no warning', (tester) async {
      final meetings = ScriptedMeetings(
        freeBytes: () async => 2 * 1024 * 1024 * 1024,
      );
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('meeting-space-low')), findsNothing);
    });

    testWidgets('the recording ends by itself on a full phone: notes follow', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      meetings.emit(meetings.state.copyWith(clearRecording: true));
      await tester.pump();
      meetings.recordingEnded(
        fakeMeeting('meeting-1', phase: MeetingPhase.recording),
        MeetingRecorderEnd.lowSpace,
      );
      meetings.emit(
        meetings.state.copyWith(waiting: [fakeMeeting('meeting-1')]),
      );
      await _pumpSpinning(tester);
      expect(
        find.text('Your phone ran out of space, so the recording stopped.'),
        findsOneWidget,
      );
      expect(find.text('Preparing your notes…'), findsOneWidget);
    });

    testWidgets('the microphone fails: it says so, and asks what to do', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      meetings.emit(meetings.state.copyWith(clearRecording: true));
      await tester.pump();
      meetings.recordingEnded(
        fakeMeeting('meeting-1', phase: MeetingPhase.recording),
        MeetingRecorderEnd.failed,
      );
      meetings.emit(
        meetings.state.copyWith(
          stopped: [fakeMeeting('meeting-1', phase: MeetingPhase.interrupted)],
        ),
      );
      await _pumpSpinning(tester);
      expect(
        find.text('The microphone stopped working, so the recording stopped.'),
        findsOneWidget,
      );
      expect(find.textContaining('ran out of space'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('it ends by itself with only silence: closes and says so', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      meetings.emit(meetings.state.copyWith(clearRecording: true));
      await tester.pump();
      expect(find.text('Preparing your notes…'), findsOneWidget);
      // Out of space, and nothing but silence: the meeting is gone.
      meetings.recordingEnded(
        fakeMeeting('meeting-1', phase: MeetingPhase.recording),
        MeetingRecorderEnd.empty,
      );
      meetings.emit(meetings.state.copyWith());
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsNothing);
      expect(
        find.text('Nothing was heard, so there’s nothing to save.'),
        findsOneWidget,
      );
    });

    testWidgets('notes ready under another screen open once it’s in front', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings, tasks: [_meetingNote]);
      await _notes(tester, container);
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await _pumpSpinning(tester);
      unawaited(
        Navigator.of(tester.element(find.byType(MeetingScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('On top')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      meetings.notesSaved('meeting-1', 90);
      await tester.pumpAndSettle();
      // Not closed under it, and still waiting to be seen.
      expect(find.text('On top'), findsOneWidget);
      expect(find.byType(MeetingScreen, skipOffstage: false), findsOneWidget);
      expect(meetings.calls.seen, isEmpty);
      expect(meetings.state.ready.single.id, 'meeting-1');
      Navigator.of(tester.element(find.text('On top'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen, skipOffstage: false), findsNothing);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(meetings.calls.seen, ['meeting-1']);
    });

    testWidgets('at 2× text in Catalan and Spanish on a small phone', (
      tester,
    ) async {
      for (final language in ['ca', 'es']) {
        final meetings = ScriptedMeetings();
        final container = _container(meetings);
        await _notes(
          tester,
          container,
          language: language,
          scale: 2,
          size: const Size(320, 568),
        );
        final l = lookupAppLocalizations(Locale(language));
        expect(find.text(l.meetingRecord), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('record-meeting')));
        await tester.pumpAndSettle();
        expect(find.text(l.meetingStop), findsOneWidget);
        expect(find.text(l.discard), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('meeting-stop')));
        await _pumpSpinning(tester);
        expect(find.text(l.meetingPreparing), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Notes tab lines', () {
    testWidgets('a recording that stopped: continue, finish or discard', (
      tester,
    ) async {
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          stopped: [
            fakeMeeting(
              'stopped-1',
              phase: MeetingPhase.interrupted,
              recorded: const Duration(hours: 1, minutes: 42),
            ),
            fakeMeeting(
              'stopped-2',
              phase: MeetingPhase.interrupted,
              recorded: const Duration(minutes: 3, seconds: 7),
            ),
          ],
        ),
      );
      final container = _container(meetings);
      await _notes(tester, container);
      expect(
        find.text(
          'Your recording stopped at 1:42:00. Continue, finish or discard?',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your recording stopped at 3:07. Continue, finish or discard?',
        ),
        findsOneWidget,
      );

      // Finish: its notes are made from what it has.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-stopped-stopped-1')),
          matching: find.text('Finish'),
        ),
      );
      await tester.pumpAndSettle();
      expect(meetings.calls.finished, ['stopped-1']);
      expect(find.text('Preparing your notes…'), findsOneWidget);

      // Discard asks first.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-stopped-stopped-2')),
          matching: find.text('Discard'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(meetings.calls.discarded, isEmpty);

      // Continue goes on in the same meeting.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-stopped-stopped-2')),
          matching: find.text('Continue'),
        ),
      );
      await tester.pumpAndSettle();
      expect(meetings.calls.continued, ['stopped-2']);
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.text('Recording'), findsOneWidget);
    });

    testWidgets('waiting meetings say why, and can be discarded', (
      tester,
    ) async {
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          waiting: [
            fakeMeeting('w-offline', problem: MeetingProblem.offline),
            fakeMeeting('w-lost', problem: MeetingProblem.pieceFailed),
            fakeMeeting('w-pro', problem: MeetingProblem.proRequired),
            fakeMeeting('w-month', problem: MeetingProblem.allowanceUsed),
            fakeMeeting('w-expired', problem: MeetingProblem.expired),
          ],
        ),
      );
      final container = _container(meetings);
      await _notes(tester, container, size: const Size(360, 1700));
      expect(find.text('Waiting for connection'), findsOneWidget);
      expect(
        find.text(
          'Part of this recording couldn’t be sent, so no notes can be made from it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('part of TaskFlow Pro'), findsOneWidget);
      expect(find.text('Explore Pro'), findsOneWidget);
      expect(find.textContaining('this month’s meeting time'), findsOneWidget);
      // Its pieces were sent: the server kept them too long, not lost here.
      expect(
        find.text(
          'This recording was kept too long without being finished, so no notes can be made from it.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-waiting-w-lost')),
          matching: find.text('Discard'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Discard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(meetings.calls.discarded, ['w-lost']);
      expect(
        find.byKey(const ValueKey('meeting-waiting-w-lost')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('TalkBack: each button names its meeting; a line is read '
        'out when it changes, not when Notes opens', (tester) async {
      final handle = tester.ensureSemantics();
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          stopped: [
            fakeMeeting(
              'stopped-1',
              phase: MeetingPhase.interrupted,
              recorded: const Duration(hours: 1, minutes: 42),
            ),
          ],
          waiting: [
            fakeMeeting(
              'w-1',
              recorded: const Duration(minutes: 3, seconds: 7),
            ),
          ],
        ),
      );
      final container = _container(meetings);
      await _notes(tester, container, size: const Size(360, 1200));
      expect(
        find.bySemanticsLabel('Discard the recording of 1:42:00'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Finish the recording of 1:42:00'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Continue the recording of 1:42:00'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Discard the recording of 3:07'),
        findsOneWidget,
      );
      bool live(String text) =>
          tester.getSemantics(find.text(text)).flagsCollection.isLiveRegion;
      expect(live('Preparing your notes…'), isFalse);
      expect(
        live('Your recording stopped at 1:42:00. Continue, finish or discard?'),
        isFalse,
      );
      meetings.emit(
        meetings.state.copyWith(
          waiting: [
            fakeMeeting(
              'w-1',
              recorded: const Duration(minutes: 3, seconds: 7),
              problem: MeetingProblem.offline,
            ),
          ],
        ),
      );
      await tester.pump();
      expect(live('Waiting for connection'), isTrue);
      expect(
        live('Your recording stopped at 1:42:00. Continue, finish or discard?'),
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('at 2× text the stopped line stacks Continue first', (
      tester,
    ) async {
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          stopped: [fakeMeeting('s', phase: MeetingPhase.interrupted)],
        ),
      );
      final container = _container(meetings);
      await _notes(tester, container, language: 'ca', scale: 2);
      final card = find.byKey(const ValueKey('meeting-stopped-s'));
      double top(String text) => tester
          .getTopLeft(find.descendant(of: card, matching: find.text(text)))
          .dy;
      final l = lookupAppLocalizations(const Locale('ca'));
      expect(top(l.meetingContinue), lessThan(top(l.meetingFinish)));
      expect(top(l.meetingFinish), lessThan(top(l.discard)));
      final left = tester.getTopLeft(card).dx;
      for (final text in [l.meetingContinue, l.meetingFinish, l.discard]) {
        // Stacked at the start, not a ragged column.
        expect(
          tester
                  .getTopLeft(
                    find.descendant(
                      of: card,
                      matching: find.ancestor(
                        of: find.text(text),
                        matching: find.byType(TextButton),
                      ),
                    ),
                  )
                  .dx -
              left,
          lessThan(24),
        );
      }
      expect(tester.takeException(), isNull);
    });

    test('signed out, there are no meeting lines', () {
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          stopped: [fakeMeeting('s', phase: MeetingPhase.interrupted)],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          meetingsOverride(meetings),
          authProvider.overrideWith((ref) => _SignedOut(OfflineApiClient())),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(meetingsProvider).stopped, isEmpty);
    });
  });

  group('Create task from a note', () {
    testWidgets('opens the review with the title and the open steps', (
      tester,
    ) async {
      final captures = MemoryCaptures();
      final meetings = ScriptedMeetings();
      final container = _container(
        meetings,
        tasks: [_meetingNote],
        regional: const RegionalPreferences(
          captureTimezone: 'America/New_York',
        ),
        overrides: [
          captureStoreProvider.overrideWithValue(captures),
          ...captureSheetOverrides(),
        ],
      );
      captures.tasks = container;
      final messenger = tester.binding.defaultBinaryMessenger;
      const timezone = MethodChannel('flutter_timezone');
      messenger.setMockMethodCallHandler(
        timezone,
        (_) async => 'Europe/Madrid',
      );
      addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(container, const TaskDetailScreen(taskId: 90)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit note'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-create-task')));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(find.byType(CaptureReviewEditor), findsOneWidget);
      final draft = captures.current!.drafts.single;
      expect(captures.current!.status, 'ready');
      expect(draft.task.kind, 'task');
      expect(draft.task.title, 'Pilot pricing with Acme');
      expect(draft.task.checklist.map((s) => s.title), [
        'Send the pilot quote · Miki · Friday',
        'Book the room',
      ]);
      expect(draft.task.checklist.every((s) => !s.completed), isTrue);
      expect(find.text('Send the pilot quote · Miki · Friday'), findsWidgets);
      // The zone chosen in Settings, as the task form uses.
      expect(captures.current!.timezone, 'America/New_York');

      // Leaving asks, as for any capture: Discard leaves nothing in
      // Unsaved.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Discard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CaptureReviewEditor), findsNothing);
      expect(captures.current!.status, 'discarded');
    });

    testWidgets('a note without open steps has no Create task', (tester) async {
      final container = _container(
        ScriptedMeetings(),
        tasks: [
          Task(
            id: 91,
            kind: 'note',
            title: 'Plain',
            notes: 'Words',
            priority: 1,
          ),
        ],
      );
      await tester.pumpWidget(
        _app(container, const TaskDetailScreen(taskId: 91)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit note'), findsOneWidget);
      expect(find.byKey(const ValueKey('note-create-task')), findsNothing);
    });
  });

  group('Signing out with recordings waiting', () {
    Future<_Auth> account(
      WidgetTester tester,
      ScriptedMeetings meetings,
    ) async {
      late _Auth auth;
      void signedOut() => meetings.calls.order.add('signOut');
      // As designContainer, with an account that counts its sign-outs.
      final container = ProviderContainer(
        overrides: [
          meetingsOverride(meetings),
          hasProProvider.overrideWithValue(true),
          billingLoadingProvider.overrideWithValue(false),
          authProvider.overrideWith(
            (ref) =>
                auth = _Auth(ref.read(apiClientProvider), onSignOut: signedOut),
          ),
          regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
          apiClientProvider.overrideWith((ref) {
            final client = OfflineApiClient();
            ref.onDispose(client.close);
            return client;
          }),
          taskRepositoryProvider.overrideWithValue(MemoryTasks()),
          taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(360, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(container, const AccountScreen()));
      await tester.pumpAndSettle();
      return auth;
    }

    ScriptedMeetings waitingOne({bool uploaded = true}) => ScriptedMeetings(
      uploaded: uploaded,
      initial: MeetingsState(
        loaded: true,
        stopped: [fakeMeeting('s', phase: MeetingPhase.interrupted)],
      ),
    );

    testWidgets('send first: finished, sent, then signed out', (tester) async {
      final meetings = waitingOne();
      final auth = await account(tester, meetings);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A meeting recording hasn’t been sent yet.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Send first'));
      await _pumpSpinning(tester);
      expect(meetings.calls.finished, ['s']);
      expect(meetings.calls.uploads, 1);
      expect(auth.signedOut, 1);
    });

    testWidgets('send first without signal: the account stays', (tester) async {
      final meetings = waitingOne(uploaded: false);
      final auth = await account(tester, meetings);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send first'));
      await tester.pumpAndSettle();
      expect(auth.signedOut, 0);
      expect(
        find.textContaining('Not everything could be sent'),
        findsOneWidget,
      );
    });

    testWidgets('discard: deleted here, then signed out', (tester) async {
      final meetings = waitingOne();
      final auth = await account(tester, meetings);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard and sign out'));
      await _pumpSpinning(tester);
      expect(meetings.calls.discardedAll, 1);
      expect(auth.signedOut, 1);
      // The server hears of the discard before the account's token goes.
      expect(meetings.calls.order, ['discardAll', 'upload', 'signOut']);
    });

    testWidgets('the question also says reminders stop', (tester) async {
      await account(tester, waitingOne());
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'or discard it? Reminders on this phone stop until you sign in again.',
        ),
        findsOneWidget,
      );
    });

    for (final (problem, says) in [
      (MeetingProblem.proRequired, 'can’t be sent without TaskFlow Pro'),
      (MeetingProblem.allowanceUsed, 'can’t be sent until next month'),
      (MeetingProblem.pieceFailed, 'Discard it to sign out'),
      (MeetingProblem.expired, 'Discard it to sign out'),
      (MeetingProblem.offline, 'Try again with a connection'),
    ]) {
      testWidgets('send first, held back ($problem): it says why', (
        tester,
      ) async {
        final meetings = ScriptedMeetings(
          uploaded: false,
          initial: MeetingsState(
            loaded: true,
            waiting: [fakeMeeting('w', problem: problem)],
          ),
        );
        final auth = await account(tester, meetings);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send first'));
        await tester.pumpAndSettle();
        expect(auth.signedOut, 0);
        expect(find.textContaining(says), findsOneWidget);
      });
    }

    testWidgets('notes just saved: the server hears before signing out', (
      tester,
    ) async {
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          ready: [fakeMeeting('r', phase: MeetingPhase.saved, noteId: 90)],
        ),
      );
      final auth = await account(tester, meetings);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Send first'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign out'),
        ),
      );
      await _pumpSpinning(tester);
      expect(auth.signedOut, 1);
      expect(meetings.calls.order, ['upload', 'signOut']);
    });

    testWidgets('right after launch: recordings not read yet still ask', (
      tester,
    ) async {
      final read = Completer<void>();
      final meetings = ScriptedMeetings(
        loading: read,
        initial: MeetingsState(
          loaded: true,
          stopped: [fakeMeeting('s', phase: MeetingPhase.interrupted)],
        ),
      );
      await account(tester, meetings);
      expect(meetings.state.loaded, isFalse);
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      read.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A meeting recording hasn’t been sent yet.'),
        findsOneWidget,
      );
    });

    testWidgets('nothing waiting: the usual question', (tester) async {
      final meetings = ScriptedMeetings();
      await account(tester, meetings);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Reminders on this phone stop'),
        findsOneWidget,
      );
      expect(find.text('Send first'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign out'),
        ),
      );
      await _pumpSpinning(tester);
      // Nothing for the server to hear: no wait before signing out.
      expect(meetings.calls.order, ['signOut']);
    });
  });

  group('Words', () {
    test('the note’s labels in the meeting’s language, else English', () {
      expect(meetingNoteLabels('es').decisions, 'Decisiones');
      expect(meetingNoteLabels('ca-ES').openQuestions, 'Preguntes obertes');
      expect(meetingNoteLabels('en').chapters, 'Parts of the meeting');
      expect(meetingNoteLabels('de').decisions, 'Decisions');
      expect(meetingNoteLabels(null).untitled, 'Meeting notes');
      // The hooks the uploader calls are these.
      expect(MeetingHooks.labels('es').untitled, 'Notas de la reunión');
    });

    test('elapsed time as a clock', () {
      expect(meetingElapsed(const Duration(seconds: 7)), '0:07');
      expect(meetingElapsed(const Duration(minutes: 12, seconds: 3)), '12:03');
      expect(
        meetingElapsed(const Duration(hours: 1, minutes: 4, seconds: 5)),
        '1:04:05',
      );
    });

    test('the "notes ready" notification: its channel and its tap', () async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      final details = meetingNotesNotificationDetails(ca).android!;
      expect(details.channelId, 'taskflow_meeting_notes');
      expect(details.channelName, 'Notes de reunions');
      expect(ca.meetingNotesReady, 'Les notes de la reunió ja són a punt');
      expect(meetingNotesNotificationId, isNot(1));
      await TaskReminders.respond(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: jsonEncode({
            'meeting_note': 90,
            'owner': meetingOwner,
            'meeting': 'meeting-1',
          }),
        ),
      );
      final opened = TaskReminders.openNote.value!;
      expect(opened.noteId, 90);
      expect(opened.ownerKey, meetingOwner);
      expect(opened.meetingId, 'meeting-1');
      TaskReminders.openNote.value = null;
    });

    test('"notes ready" is quiet only while that meeting is on screen', () {
      expect(
        TaskReminders.meetingNotesNotified('m', AppLifecycleState.resumed),
        isTrue,
      );
      TaskReminders.meetingsOnScreen.add('m');
      expect(
        TaskReminders.meetingNotesNotified('m', AppLifecycleState.resumed),
        isFalse,
      );
      // Another meeting's notes, or the app in the background: shown.
      expect(
        TaskReminders.meetingNotesNotified('other', AppLifecycleState.resumed),
        isTrue,
      );
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        null,
      ]) {
        expect(TaskReminders.meetingNotesNotified('m', state), isTrue);
      }
    });

    test('every meeting string is in all three languages', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        final notice = meetingNotice(l);
        expect(notice.title, isNotEmpty);
        expect(notice.channelName, isNotEmpty);
        expect(l.meetingSignOutQuestion(2), contains('2'));
      }
    });
  });
}

class _SignedOut extends AuthNotifier {
  _SignedOut(super.api);
  @override
  Future<void> restore() async => state = const AuthState();
}

class _Auth extends SignedInFixtureAuth {
  _Auth(super.api, {this.onSignOut});
  final void Function()? onSignOut;
  int signedOut = 0;
  @override
  Future<void> signOut() async {
    signedOut++;
    onSignOut?.call();
  }
}
