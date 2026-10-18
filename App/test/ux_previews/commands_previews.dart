// The voice-command cards in a dictation's result: a project to create, a
// search, a change and a deletion with their before and after, a mix of
// tasks and commands, the questions they ask, and what Deshacer brings back.
// Contract: Backend/docs/VOICE_COMMANDS.md.
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_previews.dart' show resume;
import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const cards = Screen(
  'commands',
  'cards',
  'Voice commands in the capture sheet\'s result',
  sources: [
    'lib/widgets/capture_command_cards.dart',
    'lib/screens/voice_task_screen.dart',
    'lib/services/command_plan.dart',
    'lib/services/command_runner.dart',
    'lib/widgets/capture_review_editor.dart',
  ],
);

const landed = Screen(
  'commands',
  'applied',
  'After a command is applied: back on Calendar with what changed and Deshacer',
  sources: [
    'lib/screens/voice_task_screen.dart',
    'lib/screens/calendar_screen.dart',
    'lib/widgets/task_interactions.dart',
    'lib/widgets/app_components.dart',
  ],
);

final _mathsTwo = TaskListInfo(id: 'matematicas2', name: 'Matemáticas II');

/// «Ir a la peluquería» in three days at ten, with notes and a step: the
/// only task with that word, so a change or a deletion finds just it.
Task _haircut() => Task(
  id: 40,
  title: 'Ir a la peluquería',
  priority: 1,
  dueDate: day(3, 10),
  notes: 'Pedir cita para mamá también',
  checklist: [ChecklistItem(id: 's1', title: 'Llevar la tarjeta')],
  reminderMinutes: 30,
);

Map<String, dynamic> _moveHaircut() => {
  'kind': 'update',
  'target': {
    'words': ['peluquería'],
    'date': key(day(3)),
  },
  'changes': {'date': key(day(7))},
};

Map<String, dynamic> _deleteHaircut() => {
  'kind': 'delete',
  'target': {
    'words': ['peluquería'],
  },
};

Future<void> _apply(PreviewApp app) async {
  await app.tester.tap(find.byKey(const ValueKey('save-drafts')));
  await app.tester.pumpAndSettle();
}

void commandPreviews() {
  previewArea('commands', 'Voice commands', () {
    // ------------------------------------------------------------ projects
    preview(
      cards,
      'project-new',
      '«Crea el proyecto Física y apunta estudiar el tema 2 el jueves»: the new project\'s card, and the task in it.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay(), projects: allProjects);
        await resume(
          app,
          [draft('Estudiar el tema 2', date: day(4), newProject: 'Física')],
          commands: [command({'kind': 'project', 'name': 'Física'})],
          transcript: 'Crea el proyecto Física y apunta estudiar el tema 2 el jueves',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'project-exists',
      'A project said that already exists: «Ya tienes «Matemáticas»», and the task goes to it.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay(), projects: allProjects);
        await resume(
          app,
          [draft('Repasar fracciones', listId: 'matematicas')],
          commands: [
            command({
              'kind': 'project',
              'name': 'Matemáticas',
              'existing_list_id': 'matematicas',
            }),
          ],
          transcript: 'En Matemáticas, repasar fracciones',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'project-question',
      'Two projects match «Mates»: a question card to create it or take one; nothing is added until answered.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: [...allProjects, _mathsTwo],
        );
        await resume(
          app,
          [draft('Ejercicio 4', newProject: 'Mates')],
          commands: [
            command({
              'kind': 'project',
              'name': 'Mates',
              'issues': ['ambiguous_project'],
            }),
          ],
          transcript: 'En Mates, ejercicio 4',
        );
        await p.shoot();
      },
    );

    // --------------------------------------------------------------- find
    preview(
      cards,
      'find-results',
      '«Busca introducción en Física»: the results, newest first, with Abrir «Física» and only Cerrar.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          projects: [...allProjects, fisica],
          tasks: [
            ...normalDay(),
            Task(
              id: 41,
              title: 'Hacer la introducción',
              priority: 1,
              listId: 'fisica',
              isCompleted: true,
            ),
            Task(
              id: 42,
              title: 'Introducción al tema 3',
              priority: 1,
              listId: 'fisica',
              dueDate: day(5),
              hasTime: false,
            ),
          ],
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'find',
              'words': ['introducción'],
              'list_id': 'fisica',
            }),
          ],
          transcript: 'Busca introducción en Física',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'find-none',
      'Searches that find nothing: a word, a project and a person not found, each said plainly.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay(), projects: allProjects);
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'find',
              'words': ['dentista'],
            }),
            command({
              'kind': 'find',
              'words': ['médico'],
              'project_name': 'Geografía',
              'issues': ['project_not_available'],
            }),
            command({
              'kind': 'find',
              'words': [],
              'person_name': 'Pol',
              'issues': ['member_not_available'],
            }),
          ],
          transcript: 'Busca dentista, médico en Geografía y lo de Pol',
        );
        await p.shoot();
      },
    );

    // ------------------------------------------------------------- change
    preview(
      cards,
      'change',
      '«Pasa la peluquería a la semana que viene»: the task and its day before → after, with Cambiar fecha.',
      [es1, es2, ca2, esDark],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _haircut()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [command(_moveHaircut())],
          transcript: 'Pasa la peluquería a la semana que viene',
        );
        await p.shoot();
      },
    );

    preview(
      landed,
      'change-applied',
      'Cambiar fecha tapped: Calendar with the moved task\'s message and Deshacer.',
      [es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _haircut()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [command(_moveHaircut())],
          transcript: 'Pasa la peluquería a la semana que viene',
        );
        await _apply(app);
        await p.shoot();
      },
    );

    preview(
      cards,
      'change-which',
      'A change that matches two tasks: tap the one to change; nothing waits on a guess.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          projects: allProjects,
          tasks: [
            ...normalDay(),
            Task(id: 43, title: 'Llamar a Ana', priority: 1, dueDate: day(2, 9)),
            Task(
              id: 44,
              title: 'Llamar a Ana por el viaje',
              priority: 1,
              dueDate: day(4, 9),
            ),
          ],
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['llamar', 'ana'],
              },
              'changes': {'time': '18:00'},
            }),
          ],
          transcript: 'Lo de llamar a Ana, a las seis de la tarde',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'change-day-question',
      'A time for a task with no day: «¿Qué día?» first, with Hoy, Mañana and another day.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          projects: allProjects,
          tasks: [
            ...normalDay(),
            Task(id: 45, title: 'Recoger las gafas', priority: 1),
          ],
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['gafas'],
              },
              'changes': {'time': '18:00'},
            }),
          ],
          transcript: 'Recoger las gafas a las seis',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'change-details',
      'Changes besides the day: title, person, priority and notes before → after; a person not in the project is said, and left as it was.',
      [es1, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          projects: allProjects,
          tasks: [
            ...normalDay(),
            Task(
              id: 46,
              title: 'Informe del trimestre',
              priority: 1,
              listId: 'matematicas',
              assignment: 'group',
            ),
            Task(
              id: 47,
              title: 'Presupuesto de la excursión',
              priority: 2,
              listId: 'matematicas',
              assignment: 'group',
              notes: 'Revisar con dirección',
            ),
          ],
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['informe'],
              },
              'changes': {
                'title': 'Informe final del trimestre',
                'assignee_id': paul,
                'assignee_name': 'Paul',
              },
            }),
            command({
              'kind': 'update',
              'target': {
                'words': ['presupuesto'],
              },
              'changes': {
                'priority': 3,
                'notes_append': 'Con IVA',
                'assignee_name': 'Pol',
              },
              'issues': ['member_not_available'],
            }),
          ],
          transcript:
              'El informe se llama informe final del trimestre y es para Paul; el presupuesto urgente, con IVA, para Pol',
        );
        await p.shoot();
      },
    );

    // ------------------------------------------------------------- delete
    preview(
      cards,
      'delete',
      '«Borra lo de la peluquería»: «Se eliminará…» in the warning colour, and Eliminar.',
      [es1, es2, ca2, esDark],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _haircut()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [command(_deleteHaircut())],
          transcript: 'Borra lo de la peluquería',
        );
        await p.shoot();
      },
    );

    preview(
      landed,
      'delete-applied',
      'Eliminar tapped: Calendar with «Tarea eliminada» and Deshacer.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _haircut()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [command(_deleteHaircut())],
          transcript: 'Borra lo de la peluquería',
        );
        await _apply(app);
        await p.shoot();
        await p.tester.tap(find.text(p.l.undo).hitTestable());
        await p.tester.pumpAndSettle();
        await p.shoot('delete-undone');
      },
      then: {
        'delete-undone':
            'Deshacer tapped: the task is back, and so is the result, ready to apply again.',
      },
    );

    preview(
      cards,
      'delete-series',
      'Deleting a whole repeating series asks first, with Conservar tarea as the filled button.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          projects: allProjects,
          tasks: [
            ...normalDay(),
            Task(
              id: 48,
              title: 'Clase de natación',
              priority: 1,
              dueDate: day(1, 19),
              recurrence: 'weekly',
            ),
          ],
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'delete',
              'target': {
                'words': ['natación'],
              },
            }),
          ],
          transcript: 'Borra la clase de natación',
        );
        await _apply(app);
        await p.shoot();
      },
    );

    // -------------------------------------------------------------- mixed
    preview(
      cards,
      'mixed',
      'A task, a change and a deletion said at once: the task first, then the change and the deletion; one button does all three.',
      [es1, es2, ca2, en2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          projects: allProjects,
          tasks: [
            ...normalDay(),
            _haircut(),
            Task(id: 49, title: 'Dentista', priority: 1, dueDate: day(5, 9)),
          ],
        );
        await resume(
          app,
          [draft('Comprar pan', date: day(1))],
          commands: [
            command(_moveHaircut()),
            command({
              'kind': 'delete',
              'target': {
                'words': ['dentista'],
              },
            }),
          ],
          transcript:
              'Comprar pan mañana, pasa la peluquería a la semana que viene y borra el dentista',
        );
        await p.shoot();
      },
    );

    preview(
      landed,
      'mixed-applied',
      'All three applied: Calendar says what was added, moved and deleted, with one Deshacer.',
      [es1, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          projects: allProjects,
          tasks: [
            ...normalDay(),
            _haircut(),
            Task(id: 49, title: 'Dentista', priority: 1, dueDate: day(5, 9)),
          ],
        );
        await resume(
          app,
          [draft('Comprar pan', date: day(1))],
          commands: [
            command(_moveHaircut()),
            command({
              'kind': 'delete',
              'target': {
                'words': ['dentista'],
              },
            }),
          ],
          transcript:
              'Comprar pan mañana, pasa la peluquería a la semana que viene y borra el dentista',
        );
        await _apply(app);
        await p.shoot();
      },
    );

    preview(
      cards,
      'not-found',
      'A change that found no task: it says so, and offers Guardar tal cual to keep the words as a task.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay(), projects: allProjects);
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['aceite', 'coche'],
              },
              'changes': {'date': key(next(DateTime.saturday))},
            }),
          ],
          transcript: 'Cambia el aceite del coche el sábado',
        );
        await p.shoot();
      },
    );
  });
}
