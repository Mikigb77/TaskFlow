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

/// Two tasks Today lists under «Atrasadas»: one dated two days ago, one
/// with only a deadline, yesterday.
List<Task> _overdue() => [
  Task(
    id: 65,
    title: 'Devolver el libro a la biblioteca',
    priority: 1,
    dueDate: day(-2),
    hasTime: false,
  ),
  Task(
    id: 66,
    title: 'Pagar la factura del gas',
    priority: 2,
    deadline: day(-1),
    reminderAnchor: 'deadline',
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

/// Last week's completed tasks, from Tuesday 13 to Saturday 17 (from
/// Wednesday 21): what «borra todas las completadas de la semana pasada»
/// deletes.
List<Task> _doneLastWeek() => [
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
];

/// Next week's tasks, one a day from Monday to Friday (from Wednesday 21),
/// one with only a deadline: a week later, they land on five days.
List<Task> _nextWeek() => [
  Task(
    id: 100,
    title: 'Llevar el coche al taller',
    priority: 1,
    dueDate: day(5, 9),
  ),
  Task(
    id: 101,
    title: 'Reunión con la tutora',
    priority: 2,
    dueDate: day(6, 17),
  ),
  Task(
    id: 102,
    title: 'Comprar el regalo de Lucía',
    priority: 1,
    dueDate: day(7),
    hasTime: false,
  ),
  Task(
    id: 103,
    title: 'Pagar el seguro de la casa',
    priority: 2,
    deadline: day(8),
    reminderAnchor: 'deadline',
  ),
  Task(
    id: 104,
    title: 'Cena con los vecinos',
    priority: 1,
    dueDate: day(9, 21),
  ),
];

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
      '«Pasa la peluquería a la semana que viene»: the task and its day before →, the new day a chip with ▾ that opens «Elegir día», and Cambiar fecha.',
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
      'A task, a change and a deletion said at once: the task first, then the change, its new day a chip with ▾, and the deletion; one button does all three.',
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

    preview(
      landed,
      'complete-applied',
      '«Ya he ido a la peluquería», Marcar como hecha tapped: Calendar on the task\'s day, Saturday, with its row ticked and lit, «Completada: Ir a la peluquería» and Deshacer.',
      [es1],
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
        await _apply(app);
        await p.shoot();
      },
    );

    preview(
      cards,
      'complete-not-found',
      '«Ya he llamado al dentista» with no such task: «No encuentro ninguna tarea con «dentista»» beside the search icon, and only Cerrar and Volver a decirlo, no Guardar como tarea.',
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
          commands: [
            command({
              'kind': 'complete',
              'target': {
                'words': ['dentista'],
              },
            }),
          ],
          transcript: 'Ya he llamado al dentista',
        );
        await p.shoot();
      },
    );

    // ---------------------------------------------------------------- sets
    preview(
      cards,
      'bulk-move',
      '«Pasa todas las tareas de ayer a mañana»: «Mover 4 tareas a», then the day as a chip with ▾, «mañana, <tomorrow>», the weekday and its number kept on one line, that opens «Elegir día»; yesterday\'s open tasks with their day and, when they have one, their project, all ticked, and «Mover 4 tareas»; the one already done stays.',
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
      'bulk-move-pick-day',
      'The same set, its day chip tapped: «Elegir día» with Hoy, Mañana (selected) and the calendar, and no «Sin fecha»; a day tapped moves the set there.',
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
        await app.tester.tap(find.byKey(const ValueKey('command-move-day')));
        await app.tester.pumpAndSettle();
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
      'Mover 4 tareas tapped: Calendar on tomorrow with the moved tasks lit, «4 tareas movidas al jue, 22 de oct», naming the day, and Deshacer.',
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
      landed,
      'bulk-shift-applied',
      '«Pasa todo lo de la semana que viene una semana más tarde», Mover 5 tareas tapped: five tasks on five days, one with only a deadline, each a week later; Calendar on the earliest new day with its task lit, and «5 tareas movidas · también en otros 4 días» and Deshacer.',
      [es1, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._nextWeek()],
          projects: allProjects,
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'update',
              'target': _set(from: day(5), to: day(11)),
              'changes': {'shift_days': 7},
            }),
          ],
          transcript:
              'Pasa todo lo de la semana que viene una semana más tarde',
        );
        await _apply(app);
        await p.shoot();
      },
    );

    preview(
      cards,
      'bulk-delete',
      '«Borra todas las completadas de la semana pasada»: «Eliminar 3 tareas» in the warning colour, the tasks ticked, each title struck through with «Completada» after its day, and the button in the delete style; at 2× the sheet opens at the heading.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._doneLastWeek()],
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
      'bulk-delete-mixed',
      '«Apunta comprar pan y borra todas las completadas de la semana pasada»: the new task «Comprar pan» first, then «Eliminar 3 tareas»; nothing asks, so the sheet opens with the set\'s heading and its ✕ at the top, the task card scrolled up above it, and «Añadir y eliminar» below.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._doneLastWeek()],
          projects: allProjects,
        );
        await resume(
          app,
          [draft('Comprar pan', date: day(0))],
          commands: [
            command({
              'kind': 'delete',
              'target': _set(from: day(-9), to: day(-3), status: 'completed'),
            }),
          ],
          transcript:
              'Apunta comprar pan y borra todas las completadas de la semana pasada',
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
        final app = await PreviewApp.open(p, tasks: normalDay(), projects: allProjects);
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
      'bulk-today-overdue',
      '«Marca como hechas todas las de hoy» with two tasks Today lists under «Atrasadas»: «Marcar 6 tareas como hechas», those two first, «… · Atrasada» (one dated two days ago, one with only yesterday\'s deadline, «Vence …»), all ticked, then today\'s open tasks.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._overdue()],
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
      landed,
      'bulk-today-overdue-applied',
      'The same set, Marcar 6 tareas como hechas tapped: Calendar on today with no «Atrasadas», today\'s tasks ticked and lit, and «6 tareas completadas» with Deshacer, no «también».',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._overdue()],
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
        await _apply(app);
        await p.shoot();
      },
    );

    preview(
      cards,
      'bulk-left-out',
      '«Asigna a Paul todo lo del viernes»: «Asignar 2 tareas a Paul», each row with its day, «Matemáticas» and «Yo», and one line for what stays: «Natación se repite: no cambia», and 2 tasks outside a shared project.',
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
      'bulk-view-only',
      '«Pasa las de Matemáticas de hoy a mañana» when Ana shares Matemáticas with the person only to view: the set\'s only matches are there, so the card names the project, «Solo puedes ver «Matemáticas»: sus tareas no cambian.», then Cerrar and Volver a decirlo, with nothing to apply.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 95,
              title: 'Preparar el examen del tema 6',
              priority: 2,
              dueDate: day(0, 17),
              listId: 'matematicas',
            ),
            Task(
              id: 96,
              title: 'Corregir los ejercicios de fracciones',
              priority: 1,
              dueDate: day(0),
              hasTime: false,
              listId: 'matematicas',
            ),
          ],
          projects: [
            TaskListInfo(
              id: 'matematicas',
              name: 'Matemáticas',
              color: 'blue',
              version: 3,
              role: 'viewer',
              shared: true,
              ownerId: ana,
              people: const [
                ProjectMember(id: ana, name: 'Ana', role: 'owner'),
                ProjectMember(id: me, name: 'María', role: 'viewer'),
              ],
            ),
            excursion,
            casa,
            trabajo,
          ],
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'update',
              'target': _set(from: day(0), listId: 'matematicas'),
              'changes': {'date': key(day(1))},
            }),
          ],
          transcript: 'Pasa las de Matemáticas de hoy a mañana',
        );
        await p.shoot();
      },
    );

    preview(
      cards,
      'bulk-ambiguous-project',
      '«Pasa todo lo de mates a mañana» with Matemáticas and Matemáticas II on the phone, both matched: «Tareas de «mates»», then «¿Qué proyecto?» with a chip for each, best first, and the button disabled, reading «Revisa los datos de arriba».',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 90,
              title: 'Corregir los ejercicios de fracciones',
              priority: 1,
              dueDate: day(-1, 17),
              listId: 'matematicas',
              assignment: 'member',
              assigneeId: me,
              assigneeName: 'María',
            ),
            Task(
              id: 91,
              title: 'Preparar el examen del tema 6',
              priority: 2,
              dueDate: day(-1),
              hasTime: false,
              listId: 'matematicas',
              assignment: 'member',
              assigneeId: me,
              assigneeName: 'María',
            ),
          ],
          projects: [...allProjects, _mathsTwo],
        );
        await resume(
          app,
          const [],
          commands: [
            command({
              'kind': 'update',
              'issues': ['ambiguous_project'],
              'target': {
                ..._set(),
                'project_name': 'mates',
                'project_candidates': [
                  {'id': 'matematicas', 'name': 'Matemáticas'},
                  {'id': 'matematicas2', 'name': 'Matemáticas II'},
                ],
              },
              'changes': {'date': key(day(1))},
            }),
          ],
          transcript: 'Pasa todo lo de mates a mañana',
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
