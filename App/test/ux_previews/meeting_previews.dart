// Meeting notes (App/docs/MEETING_NOTES.md): «Grabar una reunión» in Notas,
// the recording screen, what follows Stop, the Notas lines for stopped and
// waiting meetings, «Crear tarea» on the note, and the sign-out question.
// The meeting core is scripted: no microphone, server or WorkManager.
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

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
  'Grabar una reunión without Pro: the Pro screen says what Pro gives here',
  sources: ['lib/screens/subscription_screen.dart'],
);

const meetingSignOut = Screen(
  'meetings',
  'sign-out',
  'Cerrar sesión with a recording not sent: send it first, or discard it',
  sources: ['lib/screens/account_screen.dart'],
);

/// Every meeting screen: Spanish at 1× and 2×, Catalan and English at 2×.
const _all = [...everywhere, ...longText];

/// A meeting's note, as the core saves it: summary, decisions, open
/// questions, parts, and the to-dos as its steps.
Task _meetingNoteTask() => Task(
  id: 120,
  kind: 'note',
  title: 'Precio del piloto con Acme',
  notes:
      'Acordamos empezar el piloto en diciembre con dos almacenes. Falta '
      'cerrar el precio por usuario y quién firma por parte de Acme.\n\n'
      'Decisiones\n• Empezar el piloto en diciembre\n\n'
      'Preguntas abiertas\n• ¿Quién firma por Acme?\n\n'
      'Partes de la reunión\n\n'
      '0:00–0:30 Presentaciones y alcance\nEl alcance son los dos almacenes '
      'de Valencia.\n\n'
      '0:30–0:52 Precio del piloto\nDescuento del 20 % los tres primeros '
      'meses.',
  priority: 1,
  checklist: [
    ChecklistItem(id: 'm1', title: 'Enviar el presupuesto · Miki · el viernes'),
    ChecklistItem(id: 'm2', title: 'Reservar la sala para la demo'),
    ChecklistItem(id: 'm3', title: 'Pedir el contacto de compras · Ana'),
  ],
);

Future<PreviewApp> _open(
  Preview p,
  ScriptedMeetings meetings, {
  bool pro = true,
  List<Task> tasks = const [],
}) => PreviewApp.open(
  p,
  pro: pro,
  tasks: [...normalDay(), ...tasks],
  overrides: [meetingsOverride(meetings)],
);

/// Notas, then «Grabar una reunión».
Future<PreviewApp> _record(Preview p, ScriptedMeetings meetings) async {
  final app = await _open(p, meetings);
  await app.tab(p.l.notes);
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
      'Recording 12:03: the level ring, «Grabando», the time, the lock-screen line, a large Parar and a smaller Descartar.',
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
      'The microphone permission was refused: how to allow it, and Abrir Ajustes.',
      _all,
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
      'The recording couldn’t start (the microphone is busy, or it failed): try again.',
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
      'The microphone failed while recording: it says so, then asks Continuar, Terminar or Descartar.',
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
        'The account no longer has Pro: the recording waits on the phone, with Descubrir Pro and Descartar.',
      ),
      (
        'allowance-used',
        MeetingProblem.allowanceUsed,
        'This month’s meeting time is used: the recording waits on the phone until next month.',
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
      'Notas on opening: a recording that stopped at 1:42:00 asks Continuar, Terminar or Descartar; one waits for signal; one is being prepared.',
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
      'The recording screen left while it records: Notas says «Grabando una reunión · 12:03» with Abrir, and Grabar una reunión gives way.',
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
      'The meeting’s note opened: summary, decisions, open questions, parts, the to-dos as steps, and Crear tarea beside Editar nota.',
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
      'A free account taps Grabar una reunión: the Pro screen opens on what Pro gives here.',
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
      meetingSignOut,
      'question',
      'Cerrar sesión with a recording not sent yet: Enviar primero, or Descartar y cerrar sesión.',
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
  });
}
