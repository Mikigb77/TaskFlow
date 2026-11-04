// The meeting screens (App/docs/MEETING_NOTES.md, package A2): «Record a
// meeting» in Notes, the recording screen and what follows Stop, the
// Notes tab's lines for stopped and waiting meetings, «Create task» on a
// note with steps, the sign-out question, and the "notes ready"
// notification's words. The meeting core is scripted (ScriptedMeetings).
import 'dart:async';
import 'dart:convert';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/meeting_copy.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/first_task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
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
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/capture_review_editor.dart';
import 'package:agenda/widgets/meeting_banners.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/billing_fixtures.dart';
import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/button_label.dart';
import 'support/meeting_screen_fakes.dart';
import 'support/reminder_fixtures.dart';

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
        find.text('With Pro, your meetings become notes:'),
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
      final meetings = ScriptedMeetings(
        refuse: MeetingStartProblem.microphoneBlocked,
      );
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
      expect(find.text('Recording a meeting · 12 min'), findsOneWidget);
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
      expect(find.text('Keep recording'), findsOneWidget);
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
        // The last thing in Notas, after the empty line (UX-2707).
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('record-meeting')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
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
    testWidgets('a recording that stopped: make the notes, keep recording '
        'or discard', (tester) async {
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
        find.textContaining(
          ' · 1 h 42 min. It stopped before you pressed Stop.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(' · 3 min. It stopped before you pressed Stop.'),
        findsOneWidget,
      );

      // Make the notes: they're made from what it has.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-stopped-stopped-1')),
          matching: find.text('Make the notes'),
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

      // Keep recording goes on in the same meeting.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-stopped-stopped-2')),
          matching: find.text('Keep recording'),
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
        find.bySemanticsLabel('Discard the recording of 1 h 42 min'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Make the notes from the recording of 1 h 42 min',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Keep recording, 1 h 42 min so far'),
        findsOneWidget,
      );
      // «Preparando tus notas…» lasts seconds: no Discard there (UX-2714).
      expect(
        find.bySemanticsLabel('Discard the recording of 3 min'),
        findsNothing,
      );
      bool live(String text) =>
          tester.getSemantics(find.text(text)).flagsCollection.isLiveRegion;
      final stoppedLine = tester
          .widget<Text>(find.textContaining('It stopped before you pressed'))
          .data!;
      expect(live('Preparing your notes…'), isFalse);
      expect(live(stoppedLine), isFalse);
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
      expect(live(stoppedLine), isFalse);
      handle.dispose();
    });

    testWidgets('at 2× text the stopped line stacks Make the notes first', (
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
      expect(top(l.meetingMakeNotes), lessThan(top(l.meetingKeepRecording)));
      expect(top(l.meetingKeepRecording), lessThan(top(l.discard)));
      final left = tester.getTopLeft(card).dx;
      for (final text in [
        l.meetingMakeNotes,
        l.meetingKeepRecording,
        l.discard,
      ]) {
        // Stacked at the start, not a ragged column.
        expect(
          tester
                  .getTopLeft(
                    find.descendant(
                      of: card,
                      matching: find.ancestor(
                        of: find.text(text),
                        matching: find.byWidgetPredicate(
                          (w) => w is ButtonStyleButton,
                        ),
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
        find.textContaining(
          'A meeting’s notes aren’t ready yet, and its recording is only on this phone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Save notes and sign out'));
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
      await tester.tap(find.text('Save notes and sign out'));
      await tester.pumpAndSettle();
      expect(auth.signedOut, 0);
      expect(
        find.textContaining('No connection, so the notes couldn’t be made.'),
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
          'only on this phone. Reminders on this phone stop until you sign in again.',
        ),
        findsOneWidget,
      );
    });

    for (final (problem, says) in [
      (MeetingProblem.proRequired, 'can’t be sent without TaskFlow Pro'),
      (MeetingProblem.allowanceUsed, 'can’t be sent until next month'),
      (MeetingProblem.pieceFailed, 'Discard it to sign out'),
      (MeetingProblem.expired, 'Discard it to sign out'),
    ]) {
      // P320 (UX-2806): known to be held back, the question says why and
      // offers no send that can only fail.
      testWidgets('held back ($problem): the question says why', (
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
        expect(find.textContaining(says), findsOneWidget);
        expect(find.text('Save notes and sign out'), findsNothing);
        expect(auth.signedOut, 0);
      });
    }

    testWidgets('save notes, offline: it says so', (tester) async {
      final meetings = ScriptedMeetings(
        uploaded: false,
        initial: MeetingsState(
          loaded: true,
          waiting: [fakeMeeting('w', problem: MeetingProblem.offline)],
        ),
      );
      final auth = await account(tester, meetings);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save notes and sign out'));
      await tester.pumpAndSettle();
      expect(auth.signedOut, 0);
      expect(
        find.textContaining('tap Sign out again once you’re online'),
        findsOneWidget,
      );
    });

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
      expect(find.text('Save notes and sign out'), findsNothing);
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
        find.textContaining(
          'A meeting’s notes aren’t ready yet, and its recording is only on this phone.',
        ),
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
      expect(find.text('Save notes and sign out'), findsNothing);
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

  group('P321 · lengths in words, the meeting’s date, to-dos first, '
      'TalkBack names', () {
    // A length or a time on a clock, such as «1:42:00» or «12:03».
    final clockLike = RegExp(r'\d:\d\d');
    final es = lookupAppLocalizations(const Locale('es'));
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));

    test('UX-2705: a meeting’s length in words in Spanish, English and '
        'Catalan', () {
      const underMinute = Duration(seconds: 45);
      const twelve = Duration(minutes: 12, seconds: 3);
      const long = Duration(hours: 1, minutes: 42);
      const two = Duration(hours: 2);
      expect(meetingLength(es, underMinute), 'menos de 1 min');
      expect(meetingLength(en, underMinute), 'under 1 min');
      expect(meetingLength(ca, underMinute), 'menys d’1 min');
      for (final l in [es, en, ca]) {
        expect(meetingLength(l, twelve), '12 min', reason: l.localeName);
        expect(meetingLength(l, long), '1 h 42 min', reason: l.localeName);
        expect(meetingLength(l, two), '2 h', reason: l.localeName);
      }
    });

    testWidgets('UX-2705: the Notes recording line says «Grabando una '
        'reunión · 12 min», with no clock in its text or TalkBack names', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      // Android's Back: the recording goes on.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Grabando una reunión · 12 min'), findsOneWidget);
      expect(find.textContaining(clockLike), findsNothing);
      expect(find.bySemanticsLabel(clockLike), findsNothing);
      handle.dispose();
    });

    testWidgets('UX-2705: stopped and waiting lines give lengths in words, '
        'in their text and TalkBack names', (tester) async {
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
              problem: MeetingProblem.offline,
            ),
            fakeMeeting('w-2', recorded: const Duration(seconds: 40)),
          ],
        ),
      );
      final container = _container(meetings);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 1400),
      );
      expect(find.byType(MeetingStoppedCard), findsOneWidget);
      expect(find.textContaining('1 h 42 min'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('3 min')), findsWidgets);
      // The stopped line starts with when it started, a time of day
      // («Grabación de hoy, 10:15», P322); its length is in words.
      expect(find.textContaining('· 1 h 42 min. Se cortó'), findsOneWidget);
      final noStart = RegExp(r'^(?!.*Se cortó).*\d:\d\d', dotAll: true);
      expect(find.textContaining(noStart), findsNothing);
      expect(find.bySemanticsLabel(noStart), findsNothing);
      handle.dispose();
    });

    MeetingResult chaptered(String language) => MeetingResult(
      title: 'Pilot',
      summary: 'Summary.',
      language: language,
      chapters: const [
        MeetingChapter(startMinute: 0, endMinute: 30, title: 'Alcance'),
        MeetingChapter(startMinute: 30, endMinute: 52, title: 'Precio'),
        MeetingChapter(startMinute: 90, endMinute: 120, title: 'Cierre'),
      ],
    );

    test('UX-2705: chapter lines give minutes, and lengths past the first '
        'hour', () {
      List<String> lines(String language) => meetingNote(
        chaptered(language),
        labels: meetingNoteLabels(language),
      ).notes!.split('\n');
      final spanish = lines('es');
      expect(spanish, contains('Minutos 0–30 · Alcance'));
      expect(spanish, contains('Minutos 30–52 · Precio'));
      expect(spanish, contains('1 h 30 min – 2 h · Cierre'));
      expect(spanish.where(clockLike.hasMatch), isEmpty);
      final catalan = lines('ca');
      expect(catalan, contains('Minuts 0–30 · Alcance'));
      expect(catalan, contains('Minuts 30–52 · Precio'));
      expect(catalan, contains('1 h 30 min – 2 h · Cierre'));
      final english = lines('en');
      expect(english, contains('Minutes 0–30 · Alcance'));
      expect(english, contains('Minutes 30–52 · Precio'));
      expect(english, contains('1 h 30 min – 2 h · Cierre'));
    });

    test('UX-2710: a meeting’s note opens with when it was and how long, in '
        'the meeting’s language', () {
      // Tuesday 3 November 2026, 10:15 on the phone's clock, 52 minutes.
      final startedAt = DateTime(2026, 11, 3, 10, 15);
      const length = Duration(minutes: 52, seconds: 20);
      String first(String language) => meetingNote(
        MeetingResult(
          title: 'Pilot',
          summary: 'We agreed the pilot.',
          language: language,
          startMissing: true,
          todos: const [MeetingTodo(text: 'Send the quote', when: 'Friday')],
        ),
        labels: meetingNoteLabels(language),
        startedAt: startedAt,
        length: length,
      ).notes!.split('\n').first;
      final spanish = first('es');
      // The weekday in full: an abbreviated «mar» reads as "the sea".
      expect(spanish, 'Reunión del martes 3 nov, 10:15 · 52 min');
      expect(first('ca'), 'Reunió del dimarts 3 de nov., 10:15 · 52 min');
      expect(first('en'), 'Meeting on Tuesday, Nov 3, 10:15 · 52 min');
      // The date line comes before the «start missing» line and the summary.
      final note = meetingNote(
        const MeetingResult(
          title: 'Pilot',
          summary: 'Hablamos del piloto.',
          startMissing: true,
        ),
        labels: meetingNoteLabels('es'),
        startedAt: startedAt,
        length: length,
      ).notes!;
      expect(
        note.indexOf('Reunión del'),
        lessThan(note.indexOf(es.meetingNoteStartMissing)),
      );
      expect(
        note.indexOf(es.meetingNoteStartMissing),
        lessThan(note.indexOf('Hablamos del piloto.')),
      );
    });

    testWidgets('UX-2708: a meeting note’s first step shows without '
        'scrolling, above «Tu nota»', (tester) async {
      await loadManrope();
      final startedAt = DateTime(2026, 11, 3, 10, 15);
      final saved = meetingNote(
        const MeetingResult(
          title: 'Precio del piloto con Acme',
          summary:
              'Acordamos empezar el piloto en diciembre con dos almacenes. '
              'Falta cerrar el precio por usuario y quién firma por parte de '
              'Acme.',
          decisions: ['Empezar el piloto en diciembre'],
          openQuestions: ['¿Quién firma por Acme?'],
          chapters: [
            MeetingChapter(
              startMinute: 0,
              endMinute: 30,
              title: 'Presentaciones y alcance',
              notes: 'El alcance son los dos almacenes de Valencia.',
            ),
            MeetingChapter(
              startMinute: 30,
              endMinute: 52,
              title: 'Precio del piloto',
              notes: 'Descuento del 20 % los tres primeros meses.',
            ),
          ],
          todos: [
            MeetingTodo(
              text: 'Enviar el presupuesto del piloto',
              who: 'Miki',
              when: 'el viernes',
            ),
            MeetingTodo(text: 'Reservar la sala para la firma'),
            MeetingTodo(text: 'Pedir los datos de los almacenes'),
          ],
        ),
        labels: meetingNoteLabels('es'),
        startedAt: startedAt,
        length: const Duration(minutes: 52),
      );
      final note = saved.copyWith(
        id: 120,
        checklist: [
          for (final (i, step) in saved.checklist.indexed)
            ChecklistItem(id: 'p321-$i', title: step.title),
        ],
      );
      final container = _container(ScriptedMeetings(), tasks: [note]);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(container, const TaskDetailScreen(taskId: 120), language: 'es'),
      );
      await tester.pumpAndSettle();
      final step = find.text(
        'Enviar el presupuesto del piloto · Miki · el '
        'viernes',
      );
      expect(step, findsOneWidget);
      final stepRect = tester.getRect(step);
      expect(stepRect.top, greaterThanOrEqualTo(0));
      expect(stepRect.bottom, lessThanOrEqualTo(800));
      // Not under the bottom bar's buttons either.
      final bar = find.byKey(const ValueKey('note-create-task'));
      if (bar.evaluate().isNotEmpty) {
        expect(stepRect.bottom, lessThanOrEqualTo(tester.getRect(bar).top));
      }
      final body = find.text(es.noteBody.toUpperCase());
      expect(body, findsOneWidget);
      expect(stepRect.bottom, lessThan(tester.getRect(body).top));
      expect(
        tester.getRect(find.text(es.checklistCount(0, 3).toUpperCase())).top,
        lessThan(tester.getRect(body).top),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-2708: a task’s page still has its notes before its '
        'steps', (tester) async {
      final task = Task(
        id: 121,
        title: 'Preparar la cena',
        notes: 'Para seis personas',
        priority: 1,
        checklist: [
          ChecklistItem(id: 't1', title: 'Comprar pan'),
          ChecklistItem(id: 't2', title: 'Poner la mesa'),
        ],
      );
      final container = _container(ScriptedMeetings(), tasks: [task]);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(container, const TaskDetailScreen(taskId: 121), language: 'es'),
      );
      await tester.pumpAndSettle();
      final notes = find.text('Para seis personas');
      final steps = find.text(es.checklistCount(0, 2).toUpperCase());
      expect(notes, findsOneWidget);
      expect(steps, findsOneWidget);
      expect(tester.getRect(notes).bottom, lessThan(tester.getRect(steps).top));
      expect(
        tester.getRect(notes).top,
        lessThan(tester.getRect(find.text('Comprar pan')).top),
      );
    });

    testWidgets('UX-2718: TalkBack reads the recording time in words; the '
        'screen still shows «12:03» large', (tester) async {
      final handle = tester.ensureSemantics();
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsOneWidget);
      final time = find.byKey(const ValueKey('meeting-elapsed'));
      expect(find.text('12:03'), findsOneWidget);
      expect(
        tester.getSemantics(time).label,
        '12 minutos y 3 segundos grabados',
      );
      expect(
        find.bySemanticsLabel('12 minutos y 3 segundos grabados'),
        findsOneWidget,
      );
      // Large: the display size, well above body text.
      expect(tester.getSize(time).height, greaterThanOrEqualTo(40));
      // Read on demand, not announced as it ticks.
      expect(tester.getSemantics(time).flagsCollection.isLiveRegion, isFalse);
      handle.dispose();
    });

    test('UX-2718: the time’s TalkBack words with hours, and singulars', () {
      const short = Duration(minutes: 12, seconds: 3);
      const long = Duration(hours: 1, minutes: 4, seconds: 5);
      expect(
        meetingElapsedLabel(es, short),
        '12 minutos y 3 segundos grabados',
      );
      expect(meetingElapsedLabel(en, short), '12 minutes 3 seconds recorded');
      expect(
        meetingElapsedLabel(ca, short),
        '12 minuts i 3 segons enregistrats',
      );
      expect(
        meetingElapsedLabel(es, long),
        '1 hora, 4 minutos y 5 segundos grabados',
      );
      expect(
        meetingElapsedLabel(en, long),
        '1 hour 4 minutes 5 seconds recorded',
      );
      expect(
        meetingElapsedLabel(ca, long),
        '1 hora, 4 minuts i 5 segons enregistrats',
      );
      expect(
        meetingElapsedLabel(es, const Duration(minutes: 1, seconds: 1)),
        '1 minuto y 1 segundo grabados',
      );
    });

    testWidgets('UX-2718: the recording line’s «Abrir» is named «Abrir la '
        'grabación»', (tester) async {
      final handle = tester.ensureSemantics();
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      // Android's Back: the recording goes on.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final open = find.descendant(
        of: find.byKey(const ValueKey('meeting-recording')),
        matching: find.byType(TextButton),
      );
      expect(open, findsOneWidget);
      expect(
        find.descendant(of: open, matching: find.text(es.meetingOpen)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Abrir la grabación'), findsOneWidget);
      expect(tester.getSemantics(open).label, 'Abrir la grabación');
      expect(find.bySemanticsLabel(es.meetingOpen), findsNothing);
      handle.dispose();
    });
  });

  group('P325 · meeting notifications', () {
    testWidgets('UX-2811: a note’s page removes its "notes ready"; a task’s doesn’t', (
      tester,
    ) async {
      final opened = <int>[];
      final hook = MeetingHooks.noteOpened;
      MeetingHooks.noteOpened = (id) async => opened.add(id);
      addTearDown(() => MeetingHooks.noteOpened = hook);
      final container = _container(
        ScriptedMeetings(),
        tasks: [
          _meetingNote,
          Task(id: 7, title: 'Call the dentist', priority: 1),
        ],
      );
      await tester.pumpWidget(
        _app(container, const TaskDetailScreen(taskId: 90)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit note'), findsOneWidget);
      expect(opened, [90]);

      await tester.pumpWidget(
        KeyedSubtree(
          key: const ValueKey('task'),
          child: _app(container, const TaskDetailScreen(taskId: 7)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Call the dentist'), findsWidgets);
      expect(opened, [90]);
    });
  });
  group('P320 · Signing out with a meeting', () {
    AppLocalizations words(String language) =>
        lookupAppLocalizations(Locale(language));

    /// Cuenta pushed over a home that shows sign-in once signed out, as the
    /// app's gate does, with the scripted meetings, at [scale] on a
    /// 360×800 phone.
    Future<_GateAuth> cuenta(
      WidgetTester tester,
      ScriptedMeetings meetings, {
      String language = 'es',
      double scale = 1,
    }) async {
      late _GateAuth auth;
      final container = ProviderContainer(
        overrides: [
          meetingsOverride(meetings),
          hasProProvider.overrideWithValue(true),
          billingLoadingProvider.overrideWithValue(false),
          authProvider.overrideWith(
            (ref) => auth = _GateAuth(ref.read(apiClientProvider)),
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
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          container,
          Consumer(
            builder: (context, ref, _) =>
                ref.watch(authProvider).account == null
                ? const Scaffold(body: Text('SIGN-IN'))
                : Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AccountScreen(),
                          ),
                        ),
                        child: const Text('OPEN-CUENTA'),
                      ),
                    ),
                  ),
          ),
          language: language,
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN-CUENTA'));
      await tester.pumpAndSettle();
      return auth;
    }

    Future<void> askSignOut(WidgetTester tester, AppLocalizations l) async {
      // Cuenta is a lazy list: at 2× Cerrar sesión is built once scrolled to.
      await tester.scrollUntilVisible(
        find.text(l.signOut),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.signOut).hitTestable().first);
      await tester.pumpAndSettle();
    }

    Finder inDialog(String text) =>
        find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

    String dialogBody(WidgetTester tester) {
      final content = tester.widget<AlertDialog>(find.byType(AlertDialog));
      return (content.content! as Text).data!;
    }

    ScriptedMeetings stoppedOne({bool uploaded = true}) => ScriptedMeetings(
      uploaded: uploaded,
      initial: MeetingsState(
        loaded: true,
        stopped: [fakeMeeting('s', phase: MeetingPhase.interrupted)],
      ),
    );

    test('UX-2804, UX-2802, UX-2806: the copy is the brief’s, in all three '
        'languages', () {
      final es = words('es'), en = words('en'), ca = words('ca');
      expect(es.meetingSignOutTitle, '¿Cerrar sesión?');
      expect(en.meetingSignOutTitle, 'Sign out?');
      expect(ca.meetingSignOutTitle, 'Vols tancar la sessió?');
      expect(
        es.meetingSignOutRecording,
        'Estás grabando una reunión. Se parará y se harán sus notas antes de '
        'cerrar sesión.',
      );
      expect(
        en.meetingSignOutRecording,
        'You’re recording a meeting. It stops, and its notes are made before '
        'you sign out.',
      );
      expect(
        ca.meetingSignOutRecording,
        'Estàs enregistrant una reunió. S’aturarà i se’n faran les notes '
        'abans de tancar la sessió.',
      );
      expect(
        es.meetingSignOutQuestion(1),
        'Las notas de una reunión aún no están listas, y su grabación solo '
        'está en este teléfono.',
      );
      expect(
        es.meetingSignOutQuestion(3),
        'Las notas de 3 reuniones aún no están listas, y sus grabaciones solo '
        'están en este teléfono.',
      );
      expect(
        en.meetingSignOutQuestion(1),
        'A meeting’s notes aren’t ready yet, and its recording is only on '
        'this phone.',
      );
      expect(
        en.meetingSignOutQuestion(3),
        'The notes of 3 meetings aren’t ready yet, and their recordings are '
        'only on this phone.',
      );
      expect(
        ca.meetingSignOutQuestion(1),
        'Les notes d’una reunió encara no estan a punt, i l’enregistrament '
        'només és en aquest telèfon.',
      );
      expect(
        ca.meetingSignOutQuestion(3),
        'Les notes de 3 reunions encara no estan a punt, i els '
        'enregistraments només són en aquest telèfon.',
      );
      expect(es.meetingSendFirst, 'Guardar notas y cerrar sesión');
      expect(en.meetingSendFirst, 'Save notes and sign out');
      expect(ca.meetingSendFirst, 'Desa les notes i tanca la sessió');
      expect(es.meetingDiscardAndSignOut, 'Descartar y cerrar sesión');
      expect(
        es.meetingSavingNotes,
        'Guardando las notas de la reunión… Puede tardar unos minutos. '
        'Después se cerrará la sesión.',
      );
      expect(
        en.meetingSavingNotes,
        'Saving your meeting’s notes… This can take a few minutes. Then '
        'you’ll be signed out.',
      );
      expect(
        ca.meetingSavingNotes,
        'Desant les notes de la reunió… Pot trigar uns minuts. Després es '
        'tancarà la sessió.',
      );
      expect(
        es.meetingSendFailed,
        'Sin conexión, no se pudieron hacer las notas. Sigues con la sesión '
        'abierta; vuelve a tocar Cerrar sesión cuando tengas conexión.',
      );
      expect(
        en.meetingSendFailed,
        'No connection, so the notes couldn’t be made. You’re still signed '
        'in; tap Sign out again once you’re online.',
      );
      expect(
        ca.meetingSendFailed,
        'Sense connexió, no s’han pogut fer les notes. Continues amb la '
        'sessió oberta; torna a tocar Tanca la sessió quan tinguis connexió.',
      );
      expect(
        es.meetingSendSlow,
        'Las notas están tardando más de lo normal. Sigues con la sesión '
        'abierta; vuelve a probar Cerrar sesión en unos minutos.',
      );
      expect(
        en.meetingSendSlow,
        'The notes are taking longer than usual. You’re still signed in; try '
        'Sign out again in a few minutes.',
      );
      expect(
        ca.meetingSendSlow,
        'Les notes estan trigant més del normal. Continues amb la sessió '
        'oberta; torna a provar Tanca la sessió d’aquí a uns minuts.',
      );
      expect(
        es.meetingDiscardDeletesAll(2),
        'Descartar y cerrar sesión borra las 2 grabaciones que esperan.',
      );
      expect(
        en.meetingDiscardDeletesAll(2),
        'Discard and sign out deletes all 2 waiting recordings.',
      );
      expect(
        ca.meetingDiscardDeletesAll(2),
        'Descarta i tanca la sessió esborra els 2 enregistraments que '
        'esperen.',
      );
    });

    for (final (language, scale) in [('es', 1.0), ('es', 2.0), ('ca', 2.0)]) {
      testWidgets(
        'UX-2804: one stopped recording, $language ${scale}x: titled '
        'question read first, the count, reminders last, Save notes as the '
        'primary; nothing cut',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final l = words(language);
          await cuenta(tester, stoppedOne(), language: language, scale: scale);
          await askSignOut(tester, l);
          expect(inDialog(l.meetingSignOutTitle), findsOneWidget);
          final body = dialogBody(tester);
          expect(body, startsWith(l.meetingSignOutQuestion(1)));
          expect(body, endsWith(l.meetingSignOutReminders));
          expect(
            find.descendant(
              of: find.byType(FilledButton),
              matching: find.text(l.meetingSendFirst),
            ),
            findsOneWidget,
          );
          // TalkBack opens on the question: the dialog's route is named by
          // the title, and the title is the first thing read in it.
          SemanticsNode? named;
          bool seek(SemanticsNode n) {
            if (n.flagsCollection.namesRoute &&
                n.label == l.meetingSignOutTitle) {
              named = n;
              return false;
            }
            n.visitChildren(seek);
            return named == null;
          }

          seek(
            tester.binding.renderViews.first.owner!.semanticsOwner!
                .rootSemanticsNode!,
          );
          expect(named, isNotNull, reason: 'the dialog is named by its title');
          final node = named!;
          final labels = <String>[];
          void walk(SemanticsNode n) {
            if (n.label.isNotEmpty) labels.add(n.label);
            for (final child in n.debugListChildrenInOrder(
              DebugSemanticsDumpOrder.traversalOrder,
            )) {
              walk(child);
            }
          }

          for (final child in node.debugListChildrenInOrder(
            DebugSemanticsDumpOrder.traversalOrder,
          )) {
            walk(child);
          }
          expect(labels.first, l.meetingSignOutTitle);
          // Nothing cut: every line of the dialog fits the phone's width and
          // no text is clipped or overflows.
          expect(tester.takeException(), isNull);
          for (final text in [
            l.meetingSignOutTitle,
            l.meetingDiscardAndSignOut,
            l.cancel,
            l.meetingSendFirst,
          ]) {
            final found = inDialog(text);
            await tester.ensureVisible(found);
            await tester.pumpAndSettle();
            final rect = tester.getRect(found);
            expect(rect.left, greaterThanOrEqualTo(0), reason: text);
            expect(rect.right, lessThanOrEqualTo(360.5), reason: text);
            final paragraph = tester.renderObject<RenderParagraph>(found);
            expect(paragraph.didExceedMaxLines, isFalse, reason: text);
          }
          semantics.dispose();
        },
      );
    }

    testWidgets('UX-2804: a meeting recording now: the body starts with it, '
        'and other waiting meetings follow it as a count', (tester) async {
      final l = words('es');
      final meetings = ScriptedMeetings();
      await cuenta(tester, meetings);
      meetings.emit(
        MeetingsState(
          loaded: true,
          recording: meetings.recordingStatus('r'),
        ),
      );
      await tester.pump();
      await askSignOut(tester, l);
      expect(
        dialogBody(tester),
        '${l.meetingSignOutRecording} ${l.meetingSignOutReminders}',
      );
      expect(inDialog(l.meetingSendFirst), findsOneWidget);
      await tester.tap(inDialog(l.cancel));
      await tester.pumpAndSettle();

      meetings.emit(
        MeetingsState(
          loaded: true,
          recording: meetings.recordingStatus('r'),
          stopped: [fakeMeeting('s', phase: MeetingPhase.interrupted)],
        ),
      );
      await tester.pump();
      await askSignOut(tester, l);
      expect(
        dialogBody(tester),
        '${l.meetingSignOutRecording} ${l.meetingSignOutQuestion(1)} '
        '${l.meetingSignOutReminders}',
      );
    });

    testWidgets('UX-2804: three waiting and none recording: «Las notas de 3 '
        'reuniones…»', (tester) async {
      final l = words('es');
      await cuenta(
        tester,
        ScriptedMeetings(
          initial: MeetingsState(
            loaded: true,
            stopped: [fakeMeeting('a', phase: MeetingPhase.interrupted)],
            waiting: [
              fakeMeeting('b', problem: MeetingProblem.offline),
              fakeMeeting('c'),
            ],
          ),
        ),
      );
      await askSignOut(tester, l);
      final body = dialogBody(tester);
      expect(body, startsWith(l.meetingSignOutQuestion(3)));
      expect(body, startsWith('Las notas de 3 reuniones'));
      expect(body, isNot(contains(l.meetingSignOutRecording)));
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('UX-2805: ES ${scale}x: Descartar, Cancelar, then the '
          'primary, with Cancel between the red one and the primary', (
        tester,
      ) async {
        final l = words('es');
        await cuenta(tester, stoppedOne(), scale: scale);
        await askSignOut(tester, l);
        final discard = tester.getRect(inDialog(l.meetingDiscardAndSignOut));
        final cancel = tester.getRect(inDialog(l.cancel));
        final primary = tester.getRect(inDialog(l.meetingSendFirst));
        Rect button(String text) => tester.getRect(
          find.ancestor(
            of: inDialog(text),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        );
        final stacked = (discard.center.dy - primary.center.dy).abs() > 1;
        if (stacked) {
          expect(discard.center.dy, lessThan(cancel.center.dy));
          expect(cancel.center.dy, lessThan(primary.center.dy));
          final gap = button(l.meetingSendFirst).top -
              button(l.meetingDiscardAndSignOut).bottom;
          expect(
            gap,
            greaterThanOrEqualTo(button(l.cancel).height + 8),
            reason: 'Cancel and the spacing sit between them',
          );
          expect(gap, greaterThanOrEqualTo(56));
        } else {
          expect(discard.center.dx, lessThan(cancel.center.dx));
          expect(cancel.center.dx, lessThan(primary.center.dx));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('UX-2802: a slow send: within 1 s the saving line shows under '
        'Cerrar sesión, the spinner keeps its label, and the line goes once '
        'signed out', (tester) async {
      final semantics = tester.ensureSemantics();
      final l = words('es');
      final meetings = stoppedOne()..uploadGate = Completer<void>();
      final auth = await cuenta(tester, meetings);
      await askSignOut(tester, l);
      await tester.tap(inDialog(l.meetingSendFirst));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final line = find.text(l.meetingSavingNotes);
      expect(line, findsOneWidget);
      final signOut = tester.getRect(find.text(l.signOut));
      final rect = tester.getRect(line);
      expect(rect.top, greaterThanOrEqualTo(signOut.bottom));
      expect(rect.bottom, lessThanOrEqualTo(800));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360.5));
      final style = tester.widget<Text>(line).style;
      expect(
        style?.color,
        Theme.of(tester.element(line)).colorScheme.onSurfaceVariant,
      );
      final spinner = find.byType(CircularProgressIndicator);
      expect(spinner, findsOneWidget);
      expect(
        tester.widget<CircularProgressIndicator>(spinner).semanticsLabel,
        l.meetingSending,
      );
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(l.meetingSending))),
        findsWidgets,
      );
      expect(auth.signedOut, 0);
      meetings.uploadGate!.complete();
      await tester.pumpAndSettle();
      // Signed out: the app's gate shows sign-in (here behind Cuenta, which
      // the harness keeps pushed), and the line has gone.
      expect(auth.signedOut, 1);
      expect(find.text('SIGN-IN', skipOffstage: false), findsOneWidget);
      expect(find.text(l.meetingSavingNotes), findsNothing);
      semantics.dispose();
    });

    testWidgets('UX-2802: the saving line goes when the send fails', (
      tester,
    ) async {
      final l = words('es');
      final meetings = stoppedOne(uploaded: false)
        ..uploadGate = Completer<void>();
      final auth = await cuenta(tester, meetings);
      await askSignOut(tester, l);
      await tester.tap(inDialog(l.meetingSendFirst));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(l.meetingSavingNotes), findsOneWidget);
      meetings.uploadGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(l.meetingSavingNotes), findsNothing);
      expect(find.textContaining(l.meetingSendFailed), findsOneWidget);
      expect(auth.signedOut, 0);
    });

    testWidgets('UX-2803: Save notes, then Back while it sends: once the '
        'notes are saved the app still signs out', (tester) async {
      final l = words('es');
      final meetings = stoppedOne()..uploadGate = Completer<void>();
      final auth = await cuenta(tester, meetings);
      await askSignOut(tester, l);
      await tester.tap(inDialog(l.meetingSendFirst));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsNothing);
      expect(auth.signedOut, 0);
      meetings.uploadGate!.complete();
      await tester.pumpAndSettle();
      expect(auth.signedOut, 1);
      expect(find.text('SIGN-IN'), findsOneWidget);
      expect(meetings.calls.finished, ['s']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-2803: Discard, then Back while the server hears: the app '
        'still signs out', (tester) async {
      final l = words('es');
      final meetings = stoppedOne()..uploadGate = Completer<void>();
      final auth = await cuenta(tester, meetings);
      await askSignOut(tester, l);
      await tester.tap(inDialog(l.meetingDiscardAndSignOut));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsNothing);
      meetings.uploadGate!.complete();
      await tester.pumpAndSettle();
      expect(meetings.calls.discardedAll, 1);
      expect(auth.signedOut, 1);
      expect(find.text('SIGN-IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-2803: the plain sign-out that waits for the server, then '
        'Back: the app still signs out', (tester) async {
      final l = words('es');
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          ready: [fakeMeeting('r', phase: MeetingPhase.saved, noteId: 90)],
        ),
      )..uploadGate = Completer<void>();
      final auth = await cuenta(tester, meetings);
      await askSignOut(tester, l);
      expect(inDialog(l.meetingSendFirst), findsNothing);
      await tester.tap(inDialog(l.signOut));
      await tester.pump(const Duration(milliseconds: 300));
      expect(meetings.calls.uploads, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsNothing);
      meetings.uploadGate!.complete();
      await tester.pumpAndSettle();
      expect(auth.signedOut, 1);
      expect(find.text('SIGN-IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-2806, MN-13: offline after the send: the offline text, '
        'still signed in, the recording kept', (tester) async {
      final l = words('es');
      final meetings = stoppedOne(uploaded: false)
        ..unsent = MeetingSendResult.offline;
      final auth = await cuenta(tester, meetings);
      await askSignOut(tester, l);
      await tester.tap(inDialog(l.meetingSendFirst));
      await tester.pumpAndSettle();
      expect(find.text(l.meetingSendFailed), findsOneWidget);
      expect(find.text(l.meetingSendSlow), findsNothing);
      expect(auth.signedOut, 0);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(meetings.calls.discardedAll, 0);
      expect(meetings.state.waiting.map((m) => m.id), ['s']);
    });

    testWidgets('UX-2806, MN-13: the 2-minute cap reached while online: the '
        'slow text, still signed in, the recording kept', (tester) async {
      final l = words('es');
      final meetings = stoppedOne(uploaded: false)
        ..unsent = MeetingSendResult.slow;
      final auth = await cuenta(tester, meetings);
      await askSignOut(tester, l);
      await tester.tap(inDialog(l.meetingSendFirst));
      await tester.pumpAndSettle();
      expect(find.text(l.meetingSendSlow), findsOneWidget);
      expect(find.text(l.meetingSendFailed), findsNothing);
      expect(auth.signedOut, 0);
      expect(meetings.calls.discardedAll, 0);
      expect(meetings.state.waiting.map((m) => m.id), ['s']);
    });

    for (final (problem, reason) in [
      (MeetingProblem.pieceFailed, (AppLocalizations l) => l.meetingSendFailedLost),
      (MeetingProblem.expired, (AppLocalizations l) => l.meetingSendFailedLost),
      (MeetingProblem.proRequired, (AppLocalizations l) => l.meetingSendFailedPro),
      (
        MeetingProblem.allowanceUsed,
        (AppLocalizations l) => l.meetingSendFailedAllowance,
      ),
    ]) {
      testWidgets('UX-2806, MN-13: one recording held back ($problem): the '
          'question gives the reason and offers only Descartar and a filled '
          'Cancelar', (tester) async {
        final l = words('es');
        final meetings = ScriptedMeetings(
          initial: MeetingsState(
            loaded: true,
            waiting: [fakeMeeting('w', problem: problem)],
          ),
        );
        final auth = await cuenta(tester, meetings);
        await askSignOut(tester, l);
        expect(inDialog(l.meetingSignOutTitle), findsOneWidget);
        expect(
          dialogBody(tester),
          '${reason(l)} ${l.meetingSignOutReminders}',
        );
        expect(inDialog(l.meetingSendFirst), findsNothing);
        expect(inDialog(l.meetingDiscardAndSignOut), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.text(l.cancel),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
          findsNWidgets(2),
        );
        await tester.tap(inDialog(l.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(auth.signedOut, 0);
        expect(meetings.calls.uploads, 0);
        expect(meetings.calls.discardedAll, 0);
        expect(meetings.state.waiting.map((m) => m.id), ['w']);
      });
    }

    testWidgets('UX-2806: two waiting and both lost: the question says Discard '
        'deletes both', (tester) async {
      final l = words('es');
      await cuenta(
        tester,
        ScriptedMeetings(
          initial: MeetingsState(
            loaded: true,
            waiting: [
              fakeMeeting('a', problem: MeetingProblem.pieceFailed),
              fakeMeeting('b', problem: MeetingProblem.expired),
            ],
          ),
        ),
      );
      await askSignOut(tester, l);
      final body = dialogBody(tester);
      expect(body, startsWith(l.meetingSendFailedLost));
      expect(
        body,
        contains('Descartar y cerrar sesión borra las 2 grabaciones que '
            'esperan.'),
      );
      expect(body, contains(l.meetingDiscardDeletesAll(2)));
      expect(inDialog(l.meetingSendFirst), findsNothing);
    });

    testWidgets('UX-2806, MN-13: two waiting, one lost: after the send the '
        'lost message says Discard deletes both, and nothing is dropped', (
      tester,
    ) async {
      final l = words('es');
      final meetings = ScriptedMeetings(
        uploaded: false,
        initial: MeetingsState(
          loaded: true,
          waiting: [
            fakeMeeting('a', problem: MeetingProblem.pieceFailed),
            fakeMeeting('b', problem: MeetingProblem.offline),
          ],
        ),
      )..unsent = MeetingSendResult.blocked;
      final auth = await cuenta(tester, meetings);
      await askSignOut(tester, l);
      await tester.tap(inDialog(l.meetingSendFirst));
      await tester.pumpAndSettle();
      expect(find.textContaining(l.meetingSendFailedLost), findsOneWidget);
      expect(
        find.textContaining(
          'Descartar y cerrar sesión borra las 2 grabaciones que esperan.',
        ),
        findsOneWidget,
      );
      expect(auth.signedOut, 0);
      expect(meetings.calls.discardedAll, 0);
      expect(meetings.state.waiting.map((m) => m.id), ['a', 'b']);
    });
  });

  group('P322 · the stopped card: which meeting, one main choice and '
      'Discard apart; a quieter Record a meeting; no promise of a notice', () {
    final es = lookupAppLocalizations(const Locale('es'));
    const long = Duration(hours: 1, minutes: 42);

    DateTime at1015(int daysAgo) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - daysAgo, 10, 15);
    }

    /// A recording that stopped by itself, started at [startedAt].
    Meeting stoppedAt(
      String id,
      DateTime startedAt, {
      Duration recorded = long,
    }) => Meeting(
      id: id,
      ownerKey: meetingOwner,
      phase: MeetingPhase.interrupted,
      startedAt: startedAt,
      format: MeetingAudioFormat.opus,
      recorded: recorded,
      nextIndex: 9,
    );

    Finder button(Finder within, String text) => find.descendant(
      of: within,
      matching: find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

    Color? colorOf(WidgetTester tester, Finder within, String text) => tester
        .renderObject<RenderParagraph>(
          find.descendant(
            of: find.descendant(of: within, matching: find.text(text)),
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        )
        .text
        .style
        ?.color;

    Color errorColor(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.error;

    /// Every line of text in [within] shows whole.
    void nothingCut(WidgetTester tester, Finder within) {
      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.descendant(of: within, matching: find.byType(RichText)),
      )) {
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: paragraph.text.toPlainText(),
        );
      }
    }

    ProviderContainer withNotifications(
      ScriptedMeetings meetings, {
      required bool allowed,
    }) => _container(
      meetings,
      overrides: [
        reminderAccessProvider.overrideWithValue(
          FakeReminderAccess(allowed: allowed),
        ),
      ],
    );

    testWidgets('UX-2703: a recording cut today says which and how long; '
        'Make the notes (filled), Keep recording, then Discard in red, and '
        'each does its part', (tester) async {
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          stopped: [stoppedAt('s', at1015(0))],
        ),
      );
      final container = _container(meetings);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 800),
      );
      final card = find.byKey(const ValueKey('meeting-stopped-s'));
      final ctx = tester.element(card);
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            es.meetingStoppedCut(
              es.meetingRecordingToday(ctx.clockTime(at1015(0))),
              meetingLength(es, long),
            ),
          ),
        ),
        findsOneWidget,
      );
      // The brief's words, in Spanish.
      expect(
        find.text(
          'Grabación de hoy, 10:15 · 1 h 42 min. Se cortó antes de que '
          'pulsaras Parar.',
        ),
        findsOneWidget,
      );
      // No question, and none of the old words.
      for (final old in ['Terminar', 'Continuar']) {
        expect(
          find.descendant(of: card, matching: find.text(old)),
          findsNothing,
        );
      }
      expect(
        find.descendant(of: card, matching: find.textContaining('?')),
        findsNothing,
      );

      final make = button(card, es.meetingMakeNotes);
      final keep = button(card, es.meetingKeepRecording);
      final discard = button(card, es.discard);
      expect(make, findsOneWidget);
      expect(tester.widget(make), isA<FilledButton>());
      expect(keep, findsOneWidget);
      expect(tester.widget(keep), isNot(isA<FilledButton>()));
      expect(discard, findsOneWidget);
      expect(tester.widget(discard), isNot(isA<FilledButton>()));
      expect(colorOf(tester, card, es.discard), errorColor(tester));
      expect(
        colorOf(tester, card, es.meetingKeepRecording),
        isNot(errorColor(tester)),
      );

      // In reading order: Make the notes, Keep recording, then Discard
      // set apart below the main one.
      final makeBox = tester.getRect(make);
      final keepBox = tester.getRect(keep);
      final discardBox = tester.getRect(discard);
      expect(
        makeBox.top < keepBox.top ||
            (makeBox.top == keepBox.top && makeBox.left < keepBox.left),
        isTrue,
      );
      expect(discardBox.top, greaterThanOrEqualTo(makeBox.bottom + 8));
      expect(discardBox.top, greaterThanOrEqualTo(keepBox.bottom));

      // Discard asks first.
      await tester.tap(discard);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(meetings.calls.discarded, isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(es.keep),
        ),
      );
      await tester.pumpAndSettle();
      expect(meetings.calls.discarded, isEmpty);

      // Make the notes finishes the meeting into notes.
      await tester.tap(make);
      await tester.pumpAndSettle();
      expect(meetings.calls.finished, ['s']);
      expect(meetings.calls.continued, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-2703: Keep recording opens the recorder on the same '
        'meeting', (tester) async {
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          stopped: [stoppedAt('s', at1015(0))],
        ),
      );
      final container = _container(meetings);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 800),
      );
      await tester.tap(
        button(
          find.byKey(const ValueKey('meeting-stopped-s')),
          es.meetingKeepRecording,
        ),
      );
      await tester.pumpAndSettle();
      expect(meetings.calls.continued, ['s']);
      expect(meetings.calls.finished, isEmpty);
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
    });

    testWidgets('UX-2703: yesterday’s recording says «ayer»; an older one '
        'its weekday date', (tester) async {
      final older = at1015(5);
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          stopped: [stoppedAt('y', at1015(1)), stoppedAt('o', older)],
        ),
      );
      final container = _container(meetings);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 1200),
      );
      final ctx = tester.element(find.byType(NotesScreen));
      final time = ctx.clockTime(older);
      expect(time, '10:15');
      // The weekday in full, as in the note's title: «martes 3 nov», not
      // «mar, 3 nov» (R1-P322-3).
      final day = meetingDay(ctx.localeName, es, older);
      expect(day, isNot(contains(',')));
      expect(day, isNot(ctx.weekdayDate(older)));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-stopped-y')),
          matching: find.text(
            es.meetingStoppedCut(
              es.meetingRecordingYesterday(time),
              meetingLength(es, long),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Grabación de ayer, 10:15 · '),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-stopped-o')),
          matching: find.text(
            es.meetingStoppedCut(
              es.meetingRecordingOn(day, time),
              meetingLength(es, long),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Grabación del $day, 10:15'), findsOneWidget);
      expect(find.textContaining('Grabación de hoy'), findsNothing);
    });

    for (final language in ['es', 'ca']) {
      testWidgets('UX-2703: at 2× in $language nothing on the stopped card '
          'is cut, and Discard is last, apart from the filled button', (
        tester,
      ) async {
        final l = lookupAppLocalizations(Locale(language));
        final meetings = ScriptedMeetings(
          initial: MeetingsState(
            loaded: true,
            stopped: [stoppedAt('s', at1015(5))],
          ),
        );
        final container = _container(meetings);
        await _notes(
          tester,
          container,
          language: language,
          scale: 2,
          size: const Size(360, 800),
        );
        final card = find.byKey(const ValueKey('meeting-stopped-s'));
        nothingCut(tester, card);
        final cardBox = tester.getRect(card);
        final make = tester.getRect(button(card, l.meetingMakeNotes));
        final keep = tester.getRect(button(card, l.meetingKeepRecording));
        final discard = tester.getRect(button(card, l.discard));
        for (final box in [make, keep, discard]) {
          expect(box.left, greaterThanOrEqualTo(cardBox.left));
          expect(box.right, lessThanOrEqualTo(cardBox.right));
          expect(box.bottom, lessThanOrEqualTo(cardBox.bottom));
        }
        expect(discard.top, greaterThanOrEqualTo(make.bottom + 8));
        expect(discard.top, greaterThanOrEqualTo(keep.bottom));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('UX-2703: TalkBack names on the stopped card carry the '
        'length in words', (tester) async {
      final handle = tester.ensureSemantics();
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          stopped: [stoppedAt('s', at1015(0))],
        ),
      );
      final container = _container(meetings);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 800),
      );
      final length = meetingLength(es, long);
      expect(
        find.bySemanticsLabel(es.meetingFinishNamed(length)),
        findsOneWidget,
      );
      expect(
        es.meetingFinishNamed(length),
        'Hacer las notas de la grabación de 1 h 42 min',
      );
      expect(
        find.bySemanticsLabel(es.meetingContinueNamed(length)),
        findsOneWidget,
      );
      expect(
        es.meetingContinueNamed(length),
        'Seguir grabando, 1 h 42 min hasta ahora',
      );
      expect(
        find.bySemanticsLabel(es.meetingDiscardNamed(length)),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('UX-2703: after a microphone failure the meeting screen says '
        'why once, then the same three buttons, with no «it stopped» line', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 800),
      );
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      meetings.emit(meetings.state.copyWith(clearRecording: true));
      await tester.pump();
      meetings.recordingEnded(
        fakeMeeting('meeting-1', phase: MeetingPhase.recording),
        MeetingRecorderEnd.failed,
      );
      meetings.emit(
        meetings.state.copyWith(stopped: [stoppedAt('meeting-1', at1015(0))]),
      );
      await _pumpSpinning(tester);
      final screen = find.byType(MeetingScreen);
      expect(find.text(es.meetingMicrophoneFailed), findsOneWidget);
      // The card's «Se cortó antes de que pulsaras Parar.» isn't said again.
      final cut = es.meetingStoppedCut('', '');
      final sentence = cut.substring(cut.indexOf('.') + 1).trim();
      expect(sentence, isNotEmpty);
      expect(find.textContaining(sentence), findsNothing);
      expect(find.textContaining('?'), findsNothing);
      final make = button(screen, es.meetingMakeNotes);
      expect(make, findsOneWidget);
      expect(tester.widget(make), isA<FilledButton>());
      expect(button(screen, es.meetingKeepRecording), findsOneWidget);
      final discard = button(screen, es.discard);
      expect(discard, findsOneWidget);
      expect(colorOf(tester, screen, es.discard), errorColor(tester));
      expect(
        tester.getRect(discard).top,
        greaterThanOrEqualTo(tester.getRect(make).bottom + 8),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-2714: «Preparando tus notas…» in Notes has no button; '
        '«Esperando conexión»’s Descartar is red', (tester) async {
      final meetings = ScriptedMeetings(
        initial: MeetingsState(
          loaded: true,
          waiting: [
            fakeMeeting('w-prep'),
            fakeMeeting('w-offline', problem: MeetingProblem.offline),
          ],
        ),
      );
      final container = _container(meetings);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 1000),
      );
      final preparing = find.byKey(const ValueKey('meeting-waiting-w-prep'));
      expect(
        find.descendant(
          of: preparing,
          matching: find.text(es.meetingPreparing),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: preparing,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsNothing,
      );
      final offline = find.byKey(const ValueKey('meeting-waiting-w-offline'));
      expect(button(offline, es.discard), findsOneWidget);
      expect(colorOf(tester, offline, es.discard), errorColor(tester));
    });

    Future<Finder> afterStop(
      WidgetTester tester,
      ScriptedMeetings meetings,
      String problem,
    ) async {
      final container = _container(meetings);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 800),
      );
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await _pumpSpinning(tester);
      meetings.emit(
        meetings.state.copyWith(
          waiting: [fakeMeeting('meeting-1', problem: problem)],
        ),
      );
      await _pumpSpinning(tester);
      return find.byType(MeetingScreen);
    }

    testWidgets('UX-2714: the meeting screen with this month’s time used '
        'offers a red Descartar, which asks first', (tester) async {
      final meetings = ScriptedMeetings();
      final screen = await afterStop(
        tester,
        meetings,
        MeetingProblem.allowanceUsed,
      );
      final discard = button(screen, es.discard);
      expect(discard, findsOneWidget);
      expect(colorOf(tester, screen, es.discard), errorColor(tester));
      await tester.tap(discard);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(meetings.calls.discarded, isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(es.discard),
        ),
      );
      await tester.pumpAndSettle();
      expect(meetings.calls.discarded, ['meeting-1']);
    });

    testWidgets('UX-2714: without Pro, «Ver Pro» and «Descartar» on the '
        'meeting screen share a centre line', (tester) async {
      final screen = await afterStop(
        tester,
        ScriptedMeetings(),
        MeetingProblem.proRequired,
      );
      final pro = button(screen, es.voiceProAction);
      final discard = button(screen, es.discard);
      expect(pro, findsOneWidget);
      expect(discard, findsOneWidget);
      expect(
        (tester.getCenter(pro).dy - tester.getCenter(discard).dy).abs(),
        lessThanOrEqualTo(1),
      );
      expect(colorOf(tester, screen, es.discard), errorColor(tester));
    });

    Future<void> recordInEmptyNotes(WidgetTester tester, double scale) async {
      final container = _container(ScriptedMeetings());
      await _notes(
        tester,
        container,
        language: 'es',
        scale: scale,
        size: const Size(360, 800),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('record-meeting')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    /// Nothing in Notes' list sits below «Grabar una reunión».
    void recordIsLast(WidgetTester tester) {
      final record = tester.getRect(
        find.byKey(const ValueKey('record-meeting')),
      );
      final list = find.byType(ListView).first;
      for (final element
          in find
              .descendant(of: list, matching: find.byType(RichText))
              .evaluate()) {
        final inRecord = find
            .ancestor(
              of: find.byWidget(element.widget),
              matching: find.byKey(const ValueKey('record-meeting')),
            )
            .evaluate()
            .isNotEmpty;
        if (inRecord) continue;
        final box = element.renderObject! as RenderBox;
        final top = box.localToGlobal(Offset.zero).dy;
        expect(
          top,
          lessThan(record.top),
          reason: (box as RenderParagraph).text.toPlainText(),
        );
      }
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('UX-2707: with no notes at $scale×, «Un lugar para tus '
          'ideas» comes first and «Grabar una reunión» is the last item', (
        tester,
      ) async {
        await recordInEmptyNotes(tester, scale);
        final record = find.byKey(const ValueKey('record-meeting'));
        expect(find.text(es.notesEmpty), findsOneWidget);
        expect(
          tester.getRect(find.text(es.notesEmpty)).bottom,
          lessThanOrEqualTo(tester.getRect(record).top),
        );
        expect(
          find.descendant(of: record, matching: find.text(es.meetingRecord)),
          findsOneWidget,
        );
        recordIsLast(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('UX-2707: with notes, the search and the first note come '
        'before «Grabar una reunión»', (tester) async {
      final notes = [
        Task(id: 7, kind: 'note', title: 'Ideas para el cumple', priority: 1),
        Task(id: 8, kind: 'note', title: 'Receta de croquetas', priority: 1),
      ];
      final container = _container(ScriptedMeetings(), tasks: notes);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 800),
      );
      final record = tester.getRect(
        find.byKey(const ValueKey('record-meeting')),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('note-search'))).bottom,
        lessThanOrEqualTo(record.top),
      );
      // Newest first: note 8 is the first.
      expect(
        tester.getRect(find.text('Receta de croquetas')).bottom,
        lessThanOrEqualTo(record.top),
      );
      expect(
        tester.getRect(find.text('Ideas para el cumple')).bottom,
        lessThanOrEqualTo(record.top),
      );
      recordIsLast(tester);
    });

    testWidgets('UX-2707: at 2× the «Grabar una reunión» icon is larger than '
        'at 1×', (tester) async {
      double iconSize() => tester
          .getSize(
            find.descendant(
              of: find.byKey(const ValueKey('record-meeting')),
              matching: find.byType(Icon),
            ),
          )
          .height;
      await recordInEmptyNotes(tester, 1);
      final one = iconSize();
      await tester.pumpWidget(const SizedBox.shrink());
      await recordInEmptyNotes(tester, 2);
      final two = iconSize();
      expect(two, greaterThan(one));
    });

    testWidgets('UX-2801: with notifications off, preparing and offline say '
        'the notes will be in Notas, with no «te avisaremos»', (tester) async {
      expect(
        es.meetingPreparingHelpNoNotice,
        'Tarda unos segundos. Puedes salir de esta pantalla: las notas '
        'aparecerán en Notas.',
      );
      final meetings = ScriptedMeetings();
      final container = withNotifications(meetings, allowed: false);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 800),
      );
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await _pumpSpinning(tester);
      expect(find.text(es.meetingPreparing), findsOneWidget);
      expect(find.text(es.meetingPreparingHelpNoNotice), findsOneWidget);
      expect(find.text(es.meetingPreparingHelp), findsNothing);
      expect(find.textContaining('te avisaremos'), findsNothing);

      meetings.emit(
        meetings.state.copyWith(
          waiting: [fakeMeeting('meeting-1', problem: MeetingProblem.offline)],
        ),
      );
      await _pumpSpinning(tester);
      expect(find.text(es.meetingWaitingConnection), findsOneWidget);
      final help = find.text(es.meetingWaitingConnectionHelpNoNotice);
      expect(help, findsOneWidget);
      expect(
        tester.widget<Text>(help).data,
        endsWith('y aparecerán en Notas.'),
      );
      expect(find.text(es.meetingWaitingConnectionHelp), findsNothing);
      expect(find.textContaining('te avisaremos'), findsNothing);
    });

    testWidgets('UX-2801: with notifications allowed, today’s two texts '
        'show', (tester) async {
      final meetings = ScriptedMeetings();
      final container = withNotifications(meetings, allowed: true);
      await _notes(
        tester,
        container,
        language: 'es',
        size: const Size(360, 800),
      );
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await _pumpSpinning(tester);
      expect(find.text(es.meetingPreparingHelp), findsOneWidget);
      expect(find.text(es.meetingPreparingHelpNoNotice), findsNothing);
      meetings.emit(
        meetings.state.copyWith(
          waiting: [fakeMeeting('meeting-1', problem: MeetingProblem.offline)],
        ),
      );
      await _pumpSpinning(tester);
      expect(find.text(es.meetingWaitingConnectionHelp), findsOneWidget);
      expect(find.text(es.meetingWaitingConnectionHelpNoNotice), findsNothing);
    });
  });

  // ---- UX loop 2026-11-03-screens, round 1 · P326 (UX-2807, UX-2809): the
  // Pro screen opened from a recording held back for Pro ----
  group('P326 · the Pro screen from a held-back recording', () {
    testWidgets(
      'UX-2807: a recording held back for Pro, ES 1× with the priced store: its «Ver Pro» opens the Pro screen headed «Con Pro, tus reuniones se convierten en notas:» then «un resumen, las decisiones y las cosas por hacer», with the price and «Ver suscripción»; it never asks to record a meeting',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        final controller = SubscriptionController(
          FakeRevenueCat()..info = billingInfo(),
          const BillingConfiguration(apiKey: 'goog_fixture', supported: true),
        );
        await controller.setIdentity('owner', () async => 'owner-id');
        final meetings = ScriptedMeetings(
          initial: MeetingsState(
            loaded: true,
            waiting: [
              fakeMeeting('w-pro', problem: MeetingProblem.proRequired),
            ],
          ),
        );
        final container = _container(
          meetings,
          pro: false,
          overrides: [
            subscriptionProvider.overrideWith((_) => controller),
            billingConfigurationProvider.overrideWithValue(
              controller.configuration,
            ),
          ],
        );
        await _notes(
          tester,
          container,
          language: 'es',
          size: const Size(360, 800),
        );
        final line = find.byKey(const ValueKey('meeting-waiting-w-pro'));
        expect(line, findsOneWidget);
        await tester.tap(
          find.descendant(of: line, matching: find.text(es.voiceProAction)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SubscriptionScreen), findsOneWidget);
        final heading = find.byKey(const ValueKey('subscription-reason'));
        final example = find.byKey(
          const ValueKey('subscription-reason-example'),
        );
        expect(
          es.billingReasonMeetingNotes,
          'Con Pro, tus reuniones se convierten en notas:',
        );
        expect(
          es.billingReasonMeetingNotesExample,
          'un resumen, las decisiones y las cosas por hacer',
        );
        expect(tester.widget<Text>(heading).data, es.billingReasonMeetingNotes);
        expect(
          tester.widget<Text>(example).data,
          es.billingReasonMeetingNotesExample,
        );
        expect(
          tester.getRect(example).top,
          greaterThanOrEqualTo(tester.getRect(heading).bottom),
        );
        expect(find.textContaining('graba una reunión'), findsNothing);
        expect(find.textContaining('Graba una reunión'), findsNothing);
        // Priced: the monthly price and the pinned «Ver suscripción», not
        // the store-error line.
        expect(find.text(es.billingMonthlyPrice('€4.99')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('subscription-paywall')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('subscription-error')), findsNothing);
        // Meeting notes is the reason, so it isn't listed again as a benefit.
        expect(find.text(es.proBenefitMeetingNotes), findsNothing);
        expect(find.text(es.proBenefitReminders), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('P323 · opening and starting a recording: at once, Pro goes on, '
      'the microphone can be allowed, it says what keeps going', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));

    // Billing the test moves: still loading, then Pro or not.
    final billing = StateProvider<({bool pro, bool loading})>(
      (ref) => (pro: false, loading: false),
    );

    /// As designContainer, with billing the test changes.
    ProviderContainer billed(
      ScriptedMeetings meetings, {
      bool pro = false,
      bool loading = false,
    }) {
      final container = ProviderContainer(
        overrides: [
          firstTaskStoreProvider.overrideWithValue(MemoryFirstTaskStore()),
          invitationLinkProvider.overrideWith(
            (ref) => InvitationLinks(listen: false),
          ),
          meetingsOverride(meetings),
          billing.overrideWith((ref) => (pro: pro, loading: loading)),
          hasProProvider.overrideWith((ref) => ref.watch(billing).pro),
          billingLoadingProvider.overrideWith(
            (ref) => ref.watch(billing).loading,
          ),
          authProvider.overrideWith(
            (ref) => SignedInFixtureAuth(ref.read(apiClientProvider)),
          ),
          attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
          regionalStoreProvider.overrideWithValue(
            MemoryRegionalStore(const RegionalPreferences()),
          ),
          pendingCapturesProvider.overrideWith((ref) async => const []),
          taskListsProvider.overrideWith((ref) async => []),
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
      return container;
    }

    Finder meetingScreens() => find.byType(MeetingScreen, skipOffstage: false);

    /// Android's Back.
    Future<void> back(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    /// Away to Android's Settings and back.
    Future<void> leaveAndResume(WidgetTester tester) async {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
    }

    test('the brief’s words in Spanish, English and Catalan', () {
      expect(
        es.meetingMicrophoneNeeded,
        'Para grabar una reunión, TaskFlow necesita el micrófono.',
      );
      expect(
        en.meetingMicrophoneNeeded,
        'To record a meeting, TaskFlow needs the microphone.',
      );
      expect(
        ca.meetingMicrophoneNeeded,
        'Per enregistrar una reunió, TaskFlow necessita el micròfon.',
      );
      expect(es.meetingAllowMicrophone, 'Permitir el micrófono');
      expect(en.meetingAllowMicrophone, 'Allow the microphone');
      expect(ca.meetingAllowMicrophone, 'Permet el micròfon');
      expect(es.tryAgain, 'Reintentar');
      expect(en.tryAgain, 'Try again');
      expect(ca.tryAgain, 'Torna-ho a provar');
      expect(
        es.meetingAllowanceUsedStart,
        'Has usado el tiempo de reuniones de este mes: puedes grabar, y las '
        'notas llegarán el mes que viene.',
      );
      expect(
        en.meetingAllowanceUsedStart,
        'You’ve used this month’s meeting time: you can record, and the '
        'notes come next month.',
      );
      expect(
        ca.meetingAllowanceUsedStart,
        'Has fet servir el temps de reunions d’aquest mes: pots enregistrar, '
        'i les notes arribaran el mes que ve.',
      );
      expect(
        es.meetingListeningHelp,
        'Puedes salir o bloquear el teléfono: sigue grabando hasta que '
        'pulses Parar.',
      );
      expect(
        en.meetingListeningHelp,
        'You can leave or lock the phone: it keeps recording until you press '
        'Stop.',
      );
      expect(
        ca.meetingListeningHelp,
        'Pots sortir o bloquejar el telèfon: continua enregistrant fins que '
        'premis Atura.',
      );
      // The line under the time while recording starts as the brief says.
      expect(
        es.meetingAllowanceUsed,
        startsWith('Has usado el tiempo de reuniones de este mes'),
      );
    });

    testWidgets('UX-2715: with billing still loading, «Grabar una reunión» '
        'shows the meeting screen’s spinner in the first frame; two quick '
        'taps open one screen', (tester) async {
      final meetings = ScriptedMeetings();
      final container = billed(meetings, pro: false, loading: true);
      await _notes(tester, container, language: 'es');
      final record = find.byKey(const ValueKey('record-meeting'));

      await tester.tap(record);
      await tester.pump();
      expect(meetingScreens(), findsOneWidget);
      expect(
        find.descendant(
          of: meetingScreens(),
          matching: find.byType(CircularProgressIndicator, skipOffstage: false),
        ),
        findsOneWidget,
      );
      // A second and a third tap, before and while it opens.
      await tester.tap(record, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(record, warnIfMissed: false);
      await _pumpSpinning(tester);
      expect(meetingScreens(), findsOneWidget);
      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(meetings.calls.started, isEmpty);

      // Billing finds Pro: it records, still one screen.
      container.read(billing.notifier).state = (pro: true, loading: false);
      await tester.pumpAndSettle();
      expect(meetingScreens(), findsOneWidget);
      expect(meetings.calls.started, hasLength(1));
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
      expect(find.byType(SubscriptionScreen), findsNothing);
    });

    testWidgets('UX-2715: two taps in the same frame open one meeting '
        'screen', (tester) async {
      final meetings = ScriptedMeetings();
      final container = billed(meetings, pro: true, loading: true);
      await _notes(tester, container, language: 'es');
      final record = find.byKey(const ValueKey('record-meeting'));
      await tester.tap(record);
      await tester.tap(record, warnIfMissed: false);
      await tester.pump();
      expect(meetingScreens(), findsOneWidget);
      container.read(billing.notifier).state = (pro: true, loading: false);
      await tester.pumpAndSettle();
      expect(meetingScreens(), findsOneWidget);
      expect(meetings.calls.started, hasLength(1));
      // Back once: Notes, with no second meeting screen under it.
      await tester.tap(find.byKey(const ValueKey('meeting-discard')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(es.discard),
        ),
      );
      await tester.pumpAndSettle();
      expect(meetingScreens(), findsNothing);
      expect(find.byType(NotesScreen), findsOneWidget);
    });

    testWidgets('UX-2808: a free account buys Pro on the Pro screen: back '
        'from it, the recording starts with no second tap', (tester) async {
      final meetings = ScriptedMeetings();
      final container = billed(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      final pro = find.byType(SubscriptionScreen);
      expect(pro, findsOneWidget);
      expect(
        tester.widget<SubscriptionScreen>(pro).reason,
        ProReason.meetingNotes,
      );
      expect(meetings.calls.started, isEmpty);

      // The purchase goes through.
      container.read(billing.notifier).state = (pro: true, loading: false);
      await tester.pump();
      await back(tester);
      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(meetings.calls.started, hasLength(1));
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
      expect(find.text(es.meetingListening), findsOneWidget);
    });

    testWidgets('UX-2808: a free account that leaves the Pro screen without '
        'buying: one Back shows Notas, with no meeting screen left', (
      tester,
    ) async {
      final meetings = ScriptedMeetings();
      final container = billed(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      await back(tester);
      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(meetingScreens(), findsNothing);
      expect(find.byType(NotesScreen), findsOneWidget);
      expect(meetings.calls.started, isEmpty);
      // Notas answers a new tap: the Pro screen again, once.
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(meetingScreens(), findsOneWidget);
    });

    testWidgets('UX-2712: a microphone refused that Android still asks for: '
        '«Permitir el micrófono» asks again, and a grant records', (
      tester,
    ) async {
      final meetings = _Starts(refuse: MeetingStartProblem.permission);
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(meetings.attempts, 1);
      expect(find.text(es.meetingMicrophoneNeeded), findsOneWidget);
      final allow = filledButtonWithText(es.meetingAllowMicrophone);
      expect(allow, findsOneWidget);
      expect(find.text(es.captureOpenSettings), findsNothing);
      expect(find.text(es.meetingMicrophoneBlocked), findsNothing);

      // Refused again: it asked, and says the same.
      await tester.tap(allow);
      await tester.pumpAndSettle();
      expect(meetings.attempts, 2);
      expect(find.text(es.meetingMicrophoneNeeded), findsOneWidget);
      expect(meetings.calls.started, isEmpty);

      // Allowed: it records.
      meetings.refuse = null;
      await tester.tap(filledButtonWithText(es.meetingAllowMicrophone));
      await tester.pumpAndSettle();
      expect(meetings.attempts, 3);
      expect(meetings.calls.started, hasLength(1));
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
      expect(find.text(es.meetingMicrophoneNeeded), findsNothing);
    });

    testWidgets('UX-2712: a microphone blocked says to open Ajustes; allowed '
        'there, coming back records with no tap', (tester) async {
      final meetings = _Starts(refuse: MeetingStartProblem.microphoneBlocked);
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.text(es.meetingMicrophoneBlocked), findsOneWidget);
      expect(filledButtonWithText(es.captureOpenSettings), findsOneWidget);
      expect(find.text(es.meetingAllowMicrophone), findsNothing);

      // Back without allowing it: nothing changes.
      await leaveAndResume(tester);
      expect(meetings.calls.started, isEmpty);
      expect(find.text(es.meetingMicrophoneBlocked), findsOneWidget);

      // Allowed in Ajustes: back in the app, it records.
      meetings.refuse = null;
      await leaveAndResume(tester);
      expect(meetings.calls.started, hasLength(1));
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
      expect(find.text(es.meetingMicrophoneBlocked), findsNothing);
    });

    testWidgets('UX-2712: start failed: «Reintentar» starts again, and a '
        'success shows the recording screen', (tester) async {
      final meetings = _Starts(failures: 1);
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(meetings.attempts, 1);
      expect(find.text(es.meetingStartFailed), findsOneWidget);
      final retry = filledButtonWithText(es.tryAgain);
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(meetings.attempts, 2);
      expect(meetings.calls.started, hasLength(1));
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
      expect(find.text(es.meetingStartFailed), findsNothing);
    });

    testWidgets('UX-2711: a piece refused for the month’s time while '
        'recording: the line shows under the time within a frame, and '
        'recording goes on', (tester) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.text(es.meetingAllowanceUsed), findsNothing);
      expect(find.text(es.meetingAllowanceUsedStart), findsNothing);

      meetings.emit(
        meetings.state.copyWith(recordingProblem: MeetingProblem.allowanceUsed),
      );
      await tester.pump();
      final line = find.text(es.meetingAllowanceUsed);
      expect(line, findsOneWidget);
      expect(
        tester.getRect(line).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('meeting-elapsed'))).bottom,
        ),
      );
      // Still recording.
      expect(meetings.calls.stops, 0);
      expect(meetings.state.recording?.meetingId, 'meeting-1');
      expect(find.text(es.meetingListening), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text(es.meetingStop),
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              ),
            )
            .onPressed,
        isNotNull,
      );

      // Held for Pro instead: its Notes line, too.
      meetings.emit(
        meetings.state.copyWith(recordingProblem: MeetingProblem.proRequired),
      );
      await tester.pump();
      expect(find.text(es.meetingProRequired), findsOneWidget);
      expect(find.text(es.meetingAllowanceUsed), findsNothing);
      expect(meetings.state.recording?.meetingId, 'meeting-1');
    });

    testWidgets('UX-2711: this month’s time already used: the start line '
        'shows from the first frame of recording', (tester) async {
      final meetings = ScriptedMeetings(
        initial: const MeetingsState(loaded: true, allowanceUsed: true),
      );
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      final stop = find.byKey(const ValueKey('meeting-stop'));
      var frames = 0;
      while (stop.evaluate().isEmpty && frames < 50) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(stop, findsOneWidget);
      // The first frame with the recording screen already says it.
      expect(find.text(es.meetingAllowanceUsedStart), findsOneWidget);
      expect(
        tester.getRect(find.text(es.meetingAllowanceUsedStart)).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('meeting-elapsed'))).bottom,
        ),
      );
      await tester.pumpAndSettle();
      expect(meetings.calls.started, hasLength(1));
    });

    testWidgets('UX-2716: the recording screen says leaving or locking the '
        'phone keeps it recording', (tester) async {
      final meetings = ScriptedMeetings();
      final container = _container(meetings);
      await _notes(tester, container, language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.text(es.meetingListeningHelp), findsOneWidget);
      expect(
        find.text(
          'Puedes salir o bloquear el teléfono: sigue grabando hasta que '
          'pulses Parar.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('UX-2716: at 2× in Spanish and Catalan on 360×800, with no '
        'warning, the month’s-time lines or low space, the ring, the line, '
        'the whole warning and all of «Parar» show without scrolling', (
      tester,
    ) async {
      await loadManrope();
      const size = Size(360, 800);
      for (final language in ['es', 'ca']) {
        final l = lookupAppLocalizations(Locale(language));
        for (final warning in [null, 'start', 'refused', 'space-low']) {
          final meetings = ScriptedMeetings(
            initial: MeetingsState(
              loaded: true,
              allowanceUsed: warning == 'start',
            ),
            freeBytes: warning == 'space-low'
                ? () async => 200 * 1024 * 1024
                : null,
          );
          final container = _container(meetings);
          await _notes(
            tester,
            container,
            language: language,
            scale: 2,
            size: size,
          );
          await tester.tap(find.byKey(const ValueKey('record-meeting')));
          await tester.pumpAndSettle();
          if (warning == 'refused') {
            meetings.emit(
              meetings.state.copyWith(
                recordingProblem: MeetingProblem.allowanceUsed,
              ),
            );
            await tester.pumpAndSettle();
          }
          final shown = switch (warning) {
            'start' => l.meetingAllowanceUsedStart,
            'refused' => l.meetingAllowanceUsed,
            'space-low' => l.meetingSpaceLowWarning,
            _ => null,
          };
          final help = tester.getRect(find.text(l.meetingListeningHelp));
          final stop = tester.getRect(
            find.byKey(const ValueKey('meeting-stop')),
          );
          final body = tester.getRect(
            find.descendant(
              of: find.byType(MeetingScreen),
              matching: find.byType(SingleChildScrollView),
            ),
          );
          final lines = shown == null ? null : find.text(shown);
          final line = lines == null ? null : tester.getRect(lines);
          final why =
              '$language 2×, warning: $warning; body $body, help $help, '
              'warning $line, Parar $stop';
          // The level ring stays, smaller, at large text.
          expect(
            find.byKey(const ValueKey('meeting-level')),
            findsOneWidget,
            reason: why,
          );
          // Nothing scrolled: the line sits whole in the body's view.
          final scroll = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(MeetingScreen),
              matching: find.byType(Scrollable),
            ),
          );
          expect(scroll.position.pixels, 0, reason: why);
          expect(help.top, greaterThanOrEqualTo(body.top), reason: why);
          expect(help.bottom, lessThanOrEqualTo(body.bottom), reason: why);
          expect(help.bottom, lessThanOrEqualTo(stop.top), reason: why);
          // The whole warning, under the line and above «Parar».
          if (lines != null) {
            expect(lines, findsOneWidget, reason: why);
            expect(line!.top, greaterThanOrEqualTo(help.bottom), reason: why);
            expect(line.bottom, lessThanOrEqualTo(body.bottom), reason: why);
          }
          // The whole of «Parar» on screen.
          expect(stop.top, greaterThanOrEqualTo(0), reason: why);
          expect(stop.bottom, lessThanOrEqualTo(size.height), reason: why);
          expect(tester.takeException(), isNull, reason: why);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    });
  });

  group('P324 · Parar: a failed Stop and a quiet recording', () {
    final es = lookupAppLocalizations(const Locale('es'));
    Finder inDialog(Finder finder) =>
        find.descendant(of: find.byType(AlertDialog), matching: finder);

    /// Notes in Spanish on a small phone, then «Grabar una reunión».
    Future<void> recording(WidgetTester tester, ScriptedMeetings meetings) async {
      await _notes(tester, _container(meetings), language: 'es');
      await tester.tap(find.byKey(const ValueKey('record-meeting')));
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting-stop')), findsOneWidget);
    }

    testWidgets('UX-2713: a Stop that fails says so with its own words, the '
        'recording screen stays without «Grabando», and a second Parar that '
        'works stops it', (tester) async {
      final meetings = _P324StopFails();
      await recording(tester, meetings);
      expect(find.text(es.meetingListening), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();
      expect(meetings.calls.stops, 1);
      expect(find.text(es.meetingStopFailed), findsOneWidget);
      expect(find.text(es.meetingStartFailed), findsNothing);
      // Still the recording screen, no longer claiming to record.
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.text(es.meetingPreparing), findsNothing);
      expect(find.text(es.meetingListening), findsNothing);
      expect(find.text(es.meetingListeningHelp), findsNothing);
      final stop = find.byKey(const ValueKey('meeting-stop'));
      expect(stop.hitTestable(), findsOneWidget);
      expect(
        tester.widget<ButtonStyleButton>(stop).onPressed,
        isNotNull,
        reason: 'Parar works again',
      );

      await tester.tap(stop.hitTestable());
      await _pumpSpinning(tester);
      expect(meetings.calls.stops, 2);
      expect(find.byKey(const ValueKey('meeting-stop')), findsNothing);
      expect(find.text(es.meetingPreparing), findsOneWidget);
    });

    testWidgets('UX-2713: after a failed Stop, the time stays in the middle '
        'of the screen, above Parar, as while recording', (tester) async {
      final meetings = _P324StopFails();
      await recording(tester, meetings);
      final elapsed = find.byKey(const ValueKey('meeting-elapsed'));
      final screen = tester.getRect(find.byType(MeetingScreen)).center.dx;
      expect(tester.getRect(elapsed).center.dx, moreOrLessEquals(screen, epsilon: 1));

      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();
      expect(find.text(es.meetingStopFailed), findsOneWidget);
      final stop = tester.getRect(find.byKey(const ValueKey('meeting-stop')));
      expect(
        tester.getRect(elapsed).center.dx,
        moreOrLessEquals(screen, epsilon: 1),
        reason: 'centred, not pushed to the left once «Grabando» goes',
      );
      expect(stop.center.dx, moreOrLessEquals(screen, epsilon: 1));
    });

    testWidgets('UX-2713: after a failed Stop, Notas doesn’t say it’s '
        'recording; Abrir opens a screen without «Grabando», and Parar there '
        'finishes it', (tester) async {
      final meetings = _P324StopFails();
      await recording(tester, meetings);
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();
      // Back, as Android's: leaving doesn't stop anything.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsNothing);

      final card = find.byKey(const ValueKey('meeting-recording'));
      expect(card, findsOneWidget);
      final length = meetingLength(es, const Duration(minutes: 12, seconds: 3));
      expect(find.text(es.meetingRecordingNow(length)), findsNothing);
      expect(find.text(es.meetingRecordingUnstopped(length)), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.mic_rounded)),
        findsNothing,
      );

      await tester.tap(
        find.descendant(of: card, matching: find.text(es.meetingOpen)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.text(es.meetingListening), findsNothing);
      expect(find.text(es.meetingListeningHelp), findsNothing);
      await tester.tap(find.byKey(const ValueKey('meeting-stop')).hitTestable());
      await _pumpSpinning(tester);
      expect(meetings.calls.stops, 2);
      expect(find.text(es.meetingPreparing), findsOneWidget);
    });

    testWidgets('UX-2717: Parar on ten quiet minutes asks «Casi no se oyó '
        'nada…», with «Hacer las notas» filled and «Descartar» in red, and '
        'nothing is deleted before the answer', (tester) async {
      final meetings = _P324QuietStop();
      await recording(tester, meetings);

      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(inDialog(find.text(es.meetingQuietQuestion)), findsOneWidget);
      expect(
        inDialog(find.widgetWithText(FilledButton, es.meetingMakeNotes)),
        findsOneWidget,
      );
      final discard = inDialog(find.widgetWithText(TextButton, es.discard));
      expect(discard, findsOneWidget);
      final error = Theme.of(tester.element(discard)).colorScheme.error;
      final style = tester.widget<TextButton>(discard).style!;
      expect(style.foregroundColor!.resolve(<WidgetState>{}), error);
      // Not the dropped recording's snackbar: it's kept.
      expect(find.text(es.meetingNothingHeard), findsNothing);
      // Nothing deleted, nothing sent yet.
      expect(meetings.calls.discarded, isEmpty);
      expect(meetings.calls.discardedRecordings, 0);
      expect(meetings.calls.finished, isEmpty);
      expect(meetings.state.stopped.single.id, 'meeting-1');
      expect(find.byType(MeetingScreen), findsOneWidget);
    });

    testWidgets('UX-2717: «Hacer las notas» keeps the recording and goes on to '
        '«Preparando tus notas…»', (tester) async {
      final meetings = _P324QuietStop();
      await recording(tester, meetings);
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();

      await tester.tap(inDialog(find.text(es.meetingMakeNotes)));
      await _pumpSpinning(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(meetings.calls.finished, ['meeting-1']);
      expect(meetings.calls.discarded, isEmpty);
      expect(meetings.state.waiting.single.id, 'meeting-1');
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(find.text(es.meetingPreparing), findsOneWidget);
    });

    testWidgets('UX-2717: «Descartar» deletes the recording and closes the '
        'screen, back to Notas', (tester) async {
      final meetings = _P324QuietStop();
      await recording(tester, meetings);
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();

      await tester.tap(inDialog(find.text(es.discard)));
      await tester.pumpAndSettle();
      expect(meetings.calls.discarded, ['meeting-1']);
      expect(meetings.calls.finished, isEmpty);
      expect(meetings.state.stopped, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(NotesScreen), findsOneWidget);
    });

    testWidgets('UX-2717: dismissed, the question is neither: the stopped '
        'meeting stays, saying almost nothing was heard, with the same '
        'choices', (tester) async {
      final meetings = _P324QuietStop();
      await recording(tester, meetings);
      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(meetings.calls.finished, isEmpty);
      expect(meetings.calls.discarded, isEmpty);
      expect(find.byType(MeetingScreen), findsOneWidget);
      String tail(String line) => line.split('{length}').last;
      final quiet = es.meetingStoppedQuiet('{recording}', '{length}');
      final cut = es.meetingStoppedCut('{recording}', '{length}');
      expect(find.textContaining(tail(quiet)), findsOneWidget);
      expect(find.textContaining(tail(cut)), findsNothing);
      expect(find.text(es.meetingMakeNotes), findsOneWidget);
    });

    testWidgets('UX-2717: thirty silent seconds are still dropped at Parar, '
        'with «No se oyó nada…», as before', (tester) async {
      final meetings = ScriptedMeetings(silent: true);
      await recording(tester, meetings);

      await tester.tap(find.byKey(const ValueKey('meeting-stop')));
      await tester.pumpAndSettle();
      expect(meetings.calls.stops, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(es.meetingQuietQuestion), findsNothing);
      expect(find.text(es.meetingNothingHeard), findsOneWidget);
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(NotesScreen), findsOneWidget);
    });
  });
}

/// Signs out as the app does: sign-in shows once its state has no account.
class _GateAuth extends SignedInFixtureAuth {
  _GateAuth(super.api);
  int signedOut = 0;
  @override
  Future<void> signOut() async {
    signedOut++;
    if (mounted) state = const AuthState();
  }
}

/// Counts every start, and fails the first [failures] of them as a
/// recorder that couldn't open would.
class _Starts extends ScriptedMeetings {
  _Starts({super.refuse, this.failures = 0});
  int failures;
  int attempts = 0;

  @override
  Future<Meeting> start({
    required MeetingNotice notice,
    String? language,
    String? projectId,
  }) async {
    attempts++;
    if (failures > 0) {
      failures--;
      throw StateError('The recorder could not open.');
    }
    return super.start(
      notice: notice,
      language: language,
      projectId: projectId,
    );
  }
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

/// Parar's first press fails once the microphone has stopped (UX-2713): the
/// status stays at the time it reached, with no level, marked as not
/// stopped, as the recorder publishes it.
class _P324StopFails extends ScriptedMeetings {
  int failures = 1;

  @override
  Future<Meeting?> stop() async {
    if (failures == 0) return super.stop();
    failures--;
    calls.stops++;
    final status = state.recording!;
    state = state.copyWith(
      recording: MeetingRecordingStatus(
        meetingId: status.meetingId,
        elapsed: status.elapsed,
        level: 0,
        stopFailed: true,
      ),
    );
    throw StateError('The store failed.');
  }
}

/// Parar on ten minutes judged all silence (UX-2717): kept as a stopped
/// meeting with no piece with sound and two silent pieces held.
class _P324QuietStop extends ScriptedMeetings {
  @override
  Future<Meeting?> stop() async {
    calls.stops++;
    final meeting = Meeting(
      id: state.recording!.meetingId,
      ownerKey: meetingOwner,
      phase: MeetingPhase.interrupted,
      startedAt: DateTime.utc(2026, 11, 3, 9),
      format: MeetingAudioFormat.opus,
      recorded: const Duration(minutes: 10),
      waitingPieces: 2,
    );
    state = state.copyWith(
      clearRecording: true,
      stopped: [...state.stopped, meeting],
    );
    return meeting;
  }
}
