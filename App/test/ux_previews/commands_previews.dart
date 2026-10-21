// The voice-command cards in a dictation's result: a project to create, a
// search, a change and a deletion with their before and after, a mix of
// tasks and commands, the questions they ask, what Deshacer brings back, and
// a set of tasks changed, marked done or deleted at once.
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
    'lib/services/bulk_plan.dart',
    'lib/services/task_matcher.dart',
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

/// Yesterday's tasks, still to do but one: four to move, the done one stays.
List<Task> _yesterday() => [
  Task(
    id: 60,
    title: 'Llamar al fontanero',
    priority: 1,
    dueDate: day(-1, 9, 30),
  ),
  Task(
    id: 61,
    title: 'Enviar el informe trimestral',
    priority: 2,
    dueDate: day(-1, 12),
    listId: 'trabajo',
  ),
  Task(
    id: 62,
    title: 'Comprar el regalo de Lucía',
    priority: 1,
    dueDate: day(-1),
    hasTime: false,
  ),
  Task(
    id: 63,
    title: 'Pagar la factura del gas',
    priority: 2,
    deadline: day(-1),
    reminderAnchor: 'deadline',
  ),
  Task(
    id: 64,
    title: 'Reservar mesa para la cena',
    priority: 1,
    dueDate: day(-1, 20),
    isCompleted: true,
  ),
];

/// A set (`"all": true`) as the server sends it: open tasks by default,
/// over one day when [from] alone is given.
Map<String, dynamic> _set({
  DateTime? from,
  DateTime? to,
  String status = 'open',
  String? listId,
}) => {
  'all': true,
  'words': [],
  'list_id': listId,
  'project_name': null,
  'person_id': null,
  'person_name': null,
  'status': status,
  'from': from == null ? null : key(from),
  'to': from == null ? null : key(to ?? from),
  'undated': false,
  'date': null,
};

/// «Pasa todas las tareas de ayer a mañana».
Map<String, dynamic> _moveYesterday() => {
  'kind': 'update',
  'target': _set(from: day(-1)),
  'changes': {'date': key(day(1))},
};

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
      [es1, ca2, esDark],
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

    // ----------------------------------------------------------- complete
    preview(
      cards,
      'complete',
      '«Ya he ido a la peluquería»: the task with its day, and «Marcar como hecha».',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _haircut()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'complete',
              'target': {
                'words': ['peluquería'],
              },
            }),
          ],
          transcript: 'Ya he ido a la peluquería',
        );
        await p.shoot();
      },
    );

    // ---------------------------------------------------------------- sets
    preview(
      cards,
      'bulk-move',
      '«Pasa todas las tareas de ayer a mañana»: «Mover 4 tareas a mañana, …», yesterday\'s open tasks with their day, all ticked, and «Mover 4 tareas»; the one already done stays.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._yesterday()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [command(_moveYesterday())],
          transcript: 'Pasa todas las tareas de ayer a mañana',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'bulk-unticked',
      'The same set with one task unticked: the heading and the button count 3.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._yesterday()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [command(_moveYesterday())],
          transcript: 'Pasa todas las tareas de ayer a mañana',
        );
        await app.tap('Comprar el regalo de Lucía');
        await p.shoot();
      },
    );

    preview(
      landed,
      'bulk-applied',
      'Mover 4 tareas tapped: Calendar on tomorrow with the moved tasks lit, «4 tareas movidas» and Deshacer.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._yesterday()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [command(_moveYesterday())],
          transcript: 'Pasa todas las tareas de ayer a mañana',
        );
        await _apply(app);
        await p.shoot();
      },
    );

    preview(
      cards,
      'bulk-delete',
      '«Borra todas las completadas de la semana pasada»: «Eliminar 3 tareas» in the warning colour, the tasks ticked, and the button in the delete style.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 80,
              title: 'Devolver los libros a la biblioteca',
              priority: 1,
              dueDate: day(-8, 17),
              isCompleted: true,
            ),
            Task(
              id: 81,
              title: 'Pedir cita en el dentista',
              priority: 2,
              dueDate: day(-6),
              hasTime: false,
              isCompleted: true,
            ),
            Task(
              id: 82,
              title: 'Renovar el seguro del coche',
              priority: 3,
              dueDate: day(-4, 11),
              isCompleted: true,
            ),
          ],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'delete',
              'target': _set(from: day(-9), to: day(-3), status: 'completed'),
            }),
          ],
          transcript: 'Borra todas las completadas de la semana pasada',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'bulk-complete',
      '«Marca como hechas todas las de hoy»: «Marcar 4 tareas como hechas», today\'s open tasks, the weekly class\'s repetition today among them.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [
            command({'kind': 'complete', 'target': _set(from: day(0))}),
          ],
          transcript: 'Marca como hechas todas las de hoy',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'bulk-left-out',
      '«Asigna a Paul todo lo del viernes»: «Asignar 2 tareas a Paul», and one line for what stays: the repeating class, and a task outside a shared project.',
      [es1, ca2],
      (p) async {
        final friday = next(DateTime.friday);
        DateTime at(int hour) =>
            DateTime(friday.year, friday.month, friday.day, hour);
        final app = await PreviewApp.open(
          p,
          projects: allProjects,
          tasks: [
            ...normalDay(),
            Task(
              id: 70,
              title: 'Preparar el examen del tema 6',
              priority: 2,
              dueDate: at(10),
              listId: 'matematicas',
              assignment: 'member',
              assigneeId: me,
              assigneeName: 'María',
            ),
            Task(
              id: 71,
              title: 'Corregir las redacciones',
              priority: 1,
              dueDate: at(16),
              listId: 'matematicas',
              assignment: 'member',
              assigneeId: me,
              assigneeName: 'María',
            ),
            Task(
              id: 72,
              title: 'Llamar a la gestoría',
              priority: 1,
              dueDate: at(9),
            ),
            Task(
              id: 73,
              title: 'Natación',
              priority: 1,
              dueDate: DateTime(friday.year, friday.month, friday.day - 7, 18),
              recurrence: 'weekly',
            ),
          ],
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'update',
              'target': _set(from: friday),
              'changes': {'assignee_id': paul, 'assignee_name': 'Paul'},
            }),
          ],
          transcript: 'Asigna a Paul todo lo del viernes',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'bulk-none',
      'A set that matched nothing: «No hay tareas pendientes de ayer», and only Cerrar.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [command(_moveYesterday())],
          transcript: 'Pasa todas las tareas de ayer a mañana',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'not-found',
      'A change that found no task: it says so, and offers Guardar como tarea to keep the words as a task.',
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
