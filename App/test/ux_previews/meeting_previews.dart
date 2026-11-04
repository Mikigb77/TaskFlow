// Meeting notes (App/docs/MEETING_NOTES.md): «Grabar una reunión» in Notas,
// the recording screen, what follows Stop, the Notas lines for stopped and
// waiting meetings, «Crear tarea» on the note, and the sign-out question.
// The meeting core is scripted: no microphone, server or WorkManager.
import 'dart:async';

import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/billing_fixtures.dart';
import '../support/meeting_screen_fakes.dart';
import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const meetingRecording = Screen(
  'meetings',
  'recording',
  'Grabar una reunión: the recording screen, and before it can start',
  sources: [
    'lib/screens/meeting_screen.dart',
    'lib/l10n/meeting_copy.dart',
    'lib/widgets/meeting_banners.dart',
  ],
);

const meetingAfter = Screen(
  'meetings',
  'after-stop',
  'After Parar: the notes being prepared, waiting for signal, or held back',
  sources: [
    'lib/screens/meeting_screen.dart',
    'lib/widgets/meeting_banners.dart',
  ],
);

const meetingLines = Screen(
  'meetings',
  'notes-lines',
  'Notas with meeting lines: a recording that stopped by itself, meetings waiting for their notes, one recording',
  sources: [
    'lib/screens/notes_screen.dart',
    'lib/widgets/meeting_banners.dart',
  ],
);

const meetingNote = Screen(
  'meetings',
  'note',
  'A note made from a meeting, with Crear tarea, and the review it opens',
  sources: [
    'lib/screens/task_detail_screen.dart',
    'lib/widgets/note_task.dart',
    'lib/widgets/capture_review_editor.dart',
    'lib/screens/voice_task_screen.dart',
  ],
);

const meetingPro = Screen(
  'meetings',
  'pro',
  'Without Pro, from Grabar una reunión or a held-back recording’s Ver Pro: the Pro screen says what Pro gives here',
  sources: ['lib/screens/subscription_screen.dart'],
);

const meetingSignOut = Screen(
  'meetings',
  'sign-out',
  'Cerrar sesión with a meeting waiting: save its notes first, or discard it',
  sources: [
    'lib/screens/account_screen.dart',
    'lib/widgets/meeting_banners.dart',
  ],
);

/// Every meeting screen: Spanish at 1× and 2×, Catalan and English at 2×.
const _all = [...everywhere, ...longText];

/// A meeting's note, as the core saves it: the meeting's date and length,
/// summary, decisions, open questions, parts, and the to-dos as its steps.
Task _meetingNoteTask() => Task(
  id: 120,
  kind: 'note',
  title: 'Precio del piloto con Acme',
  notes:
      'Reunión del martes 3 nov, 10:15 · 52 min\n\n'
      'Acordamos empezar el piloto en diciembre con dos almacenes. Falta '
      'cerrar el precio por usuario y quién firma por parte de Acme.\n\n'
      'Decisiones\n• Empezar el piloto en diciembre\n\n'
      'Preguntas abiertas\n• ¿Quién firma por Acme?\n\n'
      'Partes de la reunión\n\n'
      'Minutos 0–30 · Presentaciones y alcance\nEl alcance son los dos almacenes '
      'de Valencia.\n\n'
      'Minutos 30–52 · Precio del piloto\nDescuento del 20 % los tres primeros '
      'meses.',
  priority: 1,
  checklist: [
    ChecklistItem(id: 'm1', title: 'Enviar el presupuesto · Miki · el viernes'),
    ChecklistItem(id: 'm2', title: 'Reservar la sala para la demo'),
    ChecklistItem(id: 'm3', title: 'Pedir el contacto de compras · Ana'),
  ],
);

/// Without [pro], an account with free dictations, and the store answering
/// with its price for the Pro screen.
Future<PreviewApp> _open(
  Preview p,
  ScriptedMeetings meetings, {
  bool pro = true,
  List<Task> tasks = const [],
  bool notificationsAllowed = true,
}) => PreviewApp.open(
  p,
  pro: pro,
  user: pro ? null : account(freeLeft: 4),
  billing: pro ? null : (FakeRevenueCat()..info = billingInfo()),
  tasks: [...normalDay(), ...tasks],
  notificationsAllowed: notificationsAllowed,
  overrides: [meetingsOverride(meetings)],
);

/// Notas, then «Grabar una reunión».
Future<PreviewApp> _record(
  Preview p,
  ScriptedMeetings meetings, {
  bool notificationsAllowed = true,
}) async {
  final app = await _open(
    p,
    meetings,
    notificationsAllowed: notificationsAllowed,
  );
  await app.tab(p.l.notes);
  // The last thing in Notas (UX-2707): below the fold at large text.
  await p.tester.scrollUntilVisible(
    find.byKey(const ValueKey('record-meeting')),
    200,
    scrollable: find
        .descendant(
          of: find.byType(NotesScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await p.tester.pumpAndSettle();
  await p.tester.tap(find.text(p.l.meetingRecord).hitTestable());
  await p.tester.pumpAndSettle();
  return app;
}

/// After Parar: the spinner never settles.
Future<void> _stop(Preview p) async {
  await p.tester.tap(find.text(p.l.meetingStop).hitTestable());
  await p.frames(10, const Duration(milliseconds: 100));
}

void meetingPreviews() {
  previewArea('meetings', 'Notas de reuniones', () {
    preview(
      meetingRecording,
      'listening',
      'Recording 12:03: the level ring (at 2×, smaller and beside the time), «Grabando», the time (read by TalkBack as «12 minutos y 3 segundos grabados»), that leaving or locking the phone keeps it recording until Parar, a large Parar and a smaller Descartar.',
      [...mainScreen, ...longText],
      (p) async {
        await _record(p, ScriptedMeetings());
        await p.shoot();
        await p.tester.tap(find.text(p.l.discard).hitTestable());
        await p.tester.pumpAndSettle();
        await p.shoot('discard-question');
      },
      then: {
        'discard-question':
            'Descartar asks first; «Seguir grabando» is the safe choice.',
      },
    );

    preview(
      meetingRecording,
      'microphone-refused',
      'The microphone permission was refused and Android no longer asks: how to allow it, and Abrir Ajustes.',
      _all,
      (p) async {
        await _record(
          p,
          ScriptedMeetings(refuse: MeetingStartProblem.microphoneBlocked),
        );
        await p.shoot();
      },
    );

    preview(
      meetingRecording,
      'microphone-askable',
      'The microphone permission was refused once and Android still asks: TaskFlow needs the microphone, and a filled «Permitir el micrófono» that asks again.',
      [es1],
      (p) async {
        await _record(
          p,
          ScriptedMeetings(refuse: MeetingStartProblem.permission),
        );
        await p.shoot();
      },
    );

    preview(
      meetingRecording,
      'allowance-used',
      'Recording after this month’s meeting time was used: under the time and the line about leaving, that it records and the notes come next month; Parar stays in view.',
      [es2],
      (p) async {
        final meetings = ScriptedMeetings(
          initial: const MeetingsState(loaded: true, allowanceUsed: true),
        );
        await _record(p, meetings);
        await p.shoot();
      },
    );

    preview(
      meetingRecording,
      'low-space',
      'Under about 100 MB free: the recording can’t start.',
      _all,
      (p) async {
        await _record(
          p,
          ScriptedMeetings(refuse: MeetingStartProblem.lowSpace),
        );
        await p.shoot();
      },
    );

    preview(
      meetingRecording,
      'space-low',
      'Under about 300 MB free: it records, and says the recording stops by itself if the phone fills up.',
      _all,
      (p) async {
        await _record(
          p,
          ScriptedMeetings(freeBytes: () async => 200 * 1024 * 1024),
        );
        await p.shoot();
      },
    );

    preview(
      meetingRecording,
      'start-failed',
      'The recording couldn’t start (the microphone is busy, or it failed): a filled Reintentar tries again.',
      [es2, ca2],
      (p) async {
        await _record(
          p,
          ScriptedMeetings(refuse: MeetingStartProblem.signedOut),
        );
        await p.shoot();
      },
    );

    preview(
      meetingAfter,
      'preparing',
      'Parar pressed: «Preparando tus notas…», and that it’s fine to leave.',
      _all,
      (p) async {
        await _record(p, ScriptedMeetings());
        await _stop(p);
        await p.shoot();
      },
    );

    preview(
      meetingAfter,
      'preparing-no-notifications',
      'Parar with TaskFlow’s notifications off on the phone: «Preparando tus notas…», and that the notes will be in Notas, with no promise of a notice.',
      [es1],
      (p) async {
        await _record(p, ScriptedMeetings(), notificationsAllowed: false);
        await _stop(p);
        await p.shoot();
      },
    );

    preview(
      meetingAfter,
      'waiting-connection',
      'Parar with no signal: «Esperando conexión», the recording safe on the phone, and a notice later.',
      _all,
      (p) async {
        final meetings = ScriptedMeetings();
        await _record(p, meetings);
        await _stop(p);
        meetings.emit(
          meetings.state.copyWith(
            waiting: [
              fakeMeeting('meeting-1', problem: MeetingProblem.offline),
            ],
          ),
        );
        await p.frames();
        await p.shoot();
      },
    );

    preview(
      meetingAfter,
      'out-of-space',
      'The phone ran out of space while recording: it stopped by itself, and the notes are on their way.',
      [es1, es2],
      (p) async {
        final meetings = ScriptedMeetings();
        await _record(p, meetings);
        meetings.emit(meetings.state.copyWith(clearRecording: true));
        await p.frames();
        meetings.recordingEnded(
          fakeMeeting('meeting-1', phase: MeetingPhase.recording),
          MeetingRecorderEnd.lowSpace,
        );
        meetings.emit(
          meetings.state.copyWith(waiting: [fakeMeeting('meeting-1')]),
        );
        await p.frames(10, const Duration(milliseconds: 100));
        await p.shoot();
      },
    );

    preview(
      meetingAfter,
      'microphone-failed',
      'The microphone failed while recording: it says so once, then Hacer las notas (filled), Seguir grabando, and Descartar apart in red.',
      [es1, es2],
      (p) async {
        final meetings = ScriptedMeetings();
        await _record(p, meetings);
        meetings.emit(meetings.state.copyWith(clearRecording: true));
        await p.frames();
        meetings.recordingEnded(
          fakeMeeting('meeting-1', phase: MeetingPhase.recording),
          MeetingRecorderEnd.failed,
        );
        meetings.emit(
          meetings.state.copyWith(
            stopped: [
              fakeMeeting('meeting-1', phase: MeetingPhase.interrupted),
            ],
          ),
        );
        await p.frames(10, const Duration(milliseconds: 100));
        await p.shoot();
      },
    );

    preview(
      meetingAfter,
      'cant-make-notes',
      'A piece of the audio is lost for good: no notes can be made, only Descartar.',
      _all,
      (p) async {
        final meetings = ScriptedMeetings();
        await _record(p, meetings);
        await _stop(p);
        meetings.emit(
          meetings.state.copyWith(
            waiting: [
              fakeMeeting('meeting-1', problem: MeetingProblem.pieceFailed),
            ],
          ),
        );
        await p.frames();
        await p.shoot();
      },
    );

    for (final (state, problem, says) in [
      (
        'expired',
        MeetingProblem.expired,
        'Kept so long unfinished that the server forgot what it had: no notes, only Descartar.',
      ),
      (
        'pro-required',
        MeetingProblem.proRequired,
        'The account no longer has Pro: the recording waits on the phone, with Descubrir Pro and a red Descartar on one centre line.',
      ),
      (
        'allowance-used',
        MeetingProblem.allowanceUsed,
        'This month’s meeting time is used: the recording waits on the phone until next month, with a red Descartar.',
      ),
    ]) {
      preview(meetingAfter, state, says, [es1, es2, ca2], (p) async {
        final meetings = ScriptedMeetings();
        await _record(p, meetings);
        await _stop(p);
        meetings.emit(
          meetings.state.copyWith(
            waiting: [fakeMeeting('meeting-1', problem: problem)],
          ),
        );
        await p.frames();
        await p.shoot();
      });
    }

    preview(
      meetingLines,
      'held-back',
      'Notas with meetings held back: one needs Pro (Descubrir Pro), one waits for next month’s time, one can’t become notes.',
      [es1, es2, ca2],
      (p) async {
        final app = await _open(
          p,
          ScriptedMeetings(
            initial: MeetingsState(
              loaded: true,
              waiting: [
                fakeMeeting('pro', problem: MeetingProblem.proRequired),
                fakeMeeting(
                  'month',
                  problem: MeetingProblem.allowanceUsed,
                  recorded: const Duration(minutes: 18, seconds: 40),
                ),
                fakeMeeting(
                  'expired',
                  problem: MeetingProblem.expired,
                  recorded: const Duration(minutes: 5, seconds: 2),
                ),
              ],
            ),
          ),
        );
        await app.tab(p.l.notes);
        await p.shoot();
      },
    );

    preview(
      meetingLines,
      'stopped-and-waiting',
      'Notas on opening: a recording that stopped by itself says which (its day and start time) and its 1 h 42 min, with Hacer las notas (filled), Seguir grabando and Descartar apart in red; one waits for signal, with a red Descartar; one is being prepared, with no button.',
      _all,
      (p) async {
        final app = await _open(
          p,
          ScriptedMeetings(
            initial: MeetingsState(
              loaded: true,
              stopped: [
                fakeMeeting(
                  'stopped',
                  phase: MeetingPhase.interrupted,
                  recorded: const Duration(hours: 1, minutes: 42),
                ),
              ],
              waiting: [
                fakeMeeting('offline', problem: MeetingProblem.offline),
                fakeMeeting(
                  'preparing',
                  recorded: const Duration(minutes: 27, seconds: 5),
                ),
              ],
            ),
          ),
          tasks: [_meetingNoteTask()],
        );
        await app.tab(p.l.notes);
        await p.shoot();
      },
    );

    preview(
      meetingLines,
      'recording',
      'The recording screen left while it records: Notas says «Grabando una reunión · 12 min» with Abrir (read as «Abrir la grabación»), and Grabar una reunión gives way.',
      [es1, es2],
      (p) async {
        final app = await _record(p, ScriptedMeetings());
        app.navigator.pop();
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      meetingNote,
      'create-task',
      'The meeting’s note opened: its steps (the to-dos) first, then the note: the meeting’s date and length, summary, decisions, open questions, parts; and Crear tarea beside Editar nota.',
      _all,
      (p) async {
        final app = await _open(
          p,
          ScriptedMeetings(),
          tasks: [_meetingNoteTask()],
        );
        await app.tab(p.l.notes);
        await app.tap('Precio del piloto con Acme');
        await p.shoot();
        await p.tester.tap(find.text(p.l.meetingCreateTask).hitTestable());
        await p.frames(10, const Duration(milliseconds: 100));
        await p.tester.pumpAndSettle();
        await p.shoot('review');
      },
      then: {
        'review':
            'Crear tarea: the review with the meeting’s title and its to-dos as the checklist, to drop some and set a day before saving.',
      },
    );

    preview(
      meetingPro,
      'reason',
      'A free account taps Grabar una reunión: the Pro screen says first, as a heading, «Con Pro, tus reuniones se convierten en notas:», then «un resumen, las decisiones y las cosas por hacer», then the plan with its price, then what else Pro gives (dictation and file space without limit, typed sentences turned into tasks, reminders in your own words), and «Ver suscripción» pinned at the bottom.',
      [es1, ca2],
      (p) async {
        final app = await _open(p, ScriptedMeetings(), pro: false);
        await app.tab(p.l.notes);
        await p.tester.tap(find.text(p.l.meetingRecord).hitTestable());
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      meetingPro,
      'held-back',
      'Pro lapsed with a recording waiting on the phone: its line’s Ver Pro opens the same Pro screen, «Con Pro, tus reuniones se convierten en notas:» and «un resumen, las decisiones y las cosas por hacer», with the price and «Ver suscripción».',
      [es1],
      (p) async {
        final app = await _open(
          p,
          ScriptedMeetings(
            initial: MeetingsState(
              loaded: true,
              waiting: [
                fakeMeeting('pro', problem: MeetingProblem.proRequired),
              ],
            ),
          ),
          pro: false,
        );
        await app.tab(p.l.notes);
        await p.tester.tap(find.text(p.l.voiceProAction).hitTestable());
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      meetingSignOut,
      'question',
      '¿Cerrar sesión? with a meeting’s notes not ready yet: Descartar y cerrar sesión, Cancelar, then Guardar notas y cerrar sesión.',
      _all,
      (p) async {
        final app = await _open(
          p,
          ScriptedMeetings(
            initial: MeetingsState(
              loaded: true,
              waiting: [
                fakeMeeting('offline', problem: MeetingProblem.offline),
              ],
            ),
          ),
        );
        await app.push('/account');
        await app.tap(p.l.signOut);
        await p.shoot();
      },
    );

    preview(
      meetingSignOut,
      'recording',
      '¿Cerrar sesión? while a meeting records: it stops, and its notes are made before signing out.',
      [es2],
      (p) async {
        final meetings = ScriptedMeetings();
        final app = await _open(p, meetings);
        meetings.emit(
          MeetingsState(
            loaded: true,
            recording: meetings.recordingStatus('meeting-1'),
          ),
        );
        await app.push('/account');
        await app.tap(p.l.signOut);
        await p.shoot();
      },
    );

    preview(
      meetingSignOut,
      'sending',
      'Guardar notas y cerrar sesión tapped: the spinner in Cerrar sesión, and the line under it saying the notes are being saved and that signing out follows.',
      [es2],
      (p) async {
        // The server is slow: the send never ends while the preview shoots.
        final meetings = ScriptedMeetings(
          initial: MeetingsState(
            loaded: true,
            waiting: [fakeMeeting('offline', problem: MeetingProblem.offline)],
          ),
        )..uploadGate = Completer<void>();
        final app = await _open(p, meetings);
        await app.push('/account');
        await app.tap(p.l.signOut);
        await p.tester.tap(find.text(p.l.meetingSendFirst).hitTestable());
        await p.frames(10, const Duration(milliseconds: 100));
        await p.tester.ensureVisible(find.text(p.l.meetingSavingNotes));
        await p.frames();
        await p.shoot();
        meetings.uploadGate!.complete();
        await p.tester.pumpAndSettle();
      },
    );

    preview(
      meetingSignOut,
      'blocked',
      '¿Cerrar sesión? with one recording held back for Pro: the reason, and only Descartar y cerrar sesión and Cancelar.',
      [es1],
      (p) async {
        final app = await _open(
          p,
          ScriptedMeetings(
            initial: MeetingsState(
              loaded: true,
              waiting: [
                fakeMeeting('pro', problem: MeetingProblem.proRequired),
              ],
            ),
          ),
        );
        await app.push('/account');
        await app.tap(p.l.signOut);
        await p.shoot();
      },
    );
  });
}
