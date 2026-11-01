// The Tareas tab, a project's page (a shared one with its person filter and
// «Creada por»), a task's details, the projects list and the tasks with files.
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_attachment.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/tasks_with_files_screen.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/design_fixtures.dart';
import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const tasksTab = Screen(
  'tasks',
  'tasks-tab',
  'Tareas, the second tab: every task by filter',
  sources: [
    'lib/screens/home_screen.dart',
    'lib/screens/main_shell.dart',
    'lib/widgets/task_tile.dart',
    'lib/widgets/task_list.dart',
    'lib/widgets/task_actions.dart',
    'lib/widgets/project_scope_control.dart',
  ],
);

const projectPage = Screen(
  'tasks',
  'project',
  'A project\'s page (Tareas filtered to one project)',
  sources: [
    'lib/screens/home_screen.dart',
    'lib/screens/task_lists_screen.dart',
    'lib/widgets/project_scope_control.dart',
    'lib/widgets/project_preferences.dart',
    'lib/widgets/task_tile.dart',
    'lib/widgets/task_list.dart',
    'lib/widgets/task_actions.dart',
  ],
);

const detail = Screen(
  'tasks',
  'detail',
  'A task\'s details (`/taskDetails`)',
  sources: [
    'lib/screens/task_detail_screen.dart',
    'lib/screens/activity_screen.dart',
    'lib/widgets/task_schedule_label.dart',
    'lib/widgets/checklist_editor.dart',
    'lib/widgets/attachment_panel.dart',
    'lib/widgets/task_assignment_picker.dart',
    'lib/widgets/task_list_picker.dart',
    'lib/widgets/reminder_control.dart',
  ],
);

const projects = Screen(
  'tasks',
  'projects',
  'Projects (`/lists`)',
  sources: [
    'lib/screens/task_lists_screen.dart',
    'lib/widgets/project_preferences.dart',
    'lib/widgets/invitation_cards.dart',
  ],
);

const tasksWithFiles = Screen(
  'tasks',
  'tasks-with-files',
  'Tareas con archivos: the tasks whose files use a free account’s full file space',
  sources: [
    'lib/screens/tasks_with_files_screen.dart',
    'lib/services/attachment_store.dart',
  ],
);

const _megabyte = 1024 * 1024;

/// A signed-in account's tasks, whose files the phone has counted.
class _FileTasks extends MemoryTasks {
  _FileTasks(this.usage);
  final Map<int, TaskFileUsage> usage;
  @override
  String get ownerKey => 'https://preview/users/1';
  @override
  AttachmentStore get attachments => _FileUsage(usage);
}

class _FileUsage extends AttachmentStore {
  _FileUsage(this.usage) : super(TaskDatabase(), 'https://preview/users/1');
  final Map<int, TaskFileUsage> usage;
  @override
  Future<Map<int, TaskFileUsage>> usageByTask() async => usage;
}

/// Someone else's shared project: its files use its owner's space.
final _choir = TaskListInfo(
  id: 'coro',
  name: 'Coro',
  color: 'rose',
  version: 1,
  role: 'editor',
  shared: true,
);

/// Ana's shared project, which this account can only view.
final _choirToView = TaskListInfo(
  id: 'coro',
  name: 'Coro',
  color: 'rose',
  version: 1,
  role: 'viewer',
  shared: true,
  ownerId: ana,
  people: const [
    ProjectMember(id: ana, name: 'Ana', role: 'owner'),
    ProjectMember(id: me, name: 'María', role: 'viewer'),
  ],
);

/// Tasks and a note holding files; the choir's isn't this account's.
List<Task> _fileTasks() => [
  Task(
    id: 80,
    title: 'Viaje a Lisboa',
    dueDate: day(9),
    hasTime: false,
    priority: 2,
  ),
  Task(id: 81, title: 'Recetas de la abuela', kind: 'note', priority: 1),
  Task(
    id: 82,
    title: 'Factura del seguro del coche',
    priority: 2,
    listId: 'casa',
  ),
  Task(id: 83, title: 'Partituras del concierto', priority: 1, listId: 'coro'),
];

final _fileUsage = {
  80: TaskFileUsage(3, (12.4 * _megabyte).round()),
  81: TaskFileUsage(1, (0.3 * _megabyte).round()),
  82: TaskFileUsage(2, (4.1 * _megabyte).round()),
  83: const TaskFileUsage(5, 30 * _megabyte),
};

Future<void> _openProject(PreviewApp app, String id) async {
  await app.tab(app.p.l.tasks);
  await app.pushPage(HomeScreen(isRoot: false, listId: id));
}

/// «Pagar la luz», today at 09:50 with «10 minutos antes», opened at 09:41:
/// its alert rang at 09:40, or, [snoozed] then, rings again at 09:51.
Future<void> _rangAlert(Preview p, {bool snoozed = false}) async {
  final due = day(0, 9, 50);
  final rang = day(0, 9, 40);
  final again = day(0, 9, 51);
  final app = await PreviewApp.open(
    p,
    tasks: [
      ...normalDay(),
      Task(
        id: 78,
        title: 'Pagar la luz',
        dueDate: due,
        hasTime: true,
        priority: 1,
        reminderMinutes: 10,
      ),
    ],
    projects: allProjects,
    reminders: const ReminderPreferences(enabled: true, asked: true),
    // As the reminder engine keeps it: a snooze sets the alert again at its
    // own time.
    phoneAlerts: [
      {
        'identity': 'owner/task/78/once',
        'task_id': 78,
        'occurrence': null,
        'due_at': due.toIso8601String(),
        'fire_at': (snoozed ? again : rang).toUtc().toIso8601String(),
        'status': snoozed ? 'scheduled' : 'elapsed',
        'error': null,
        'snooze_at': snoozed ? again.toUtc().toIso8601String() : null,
      },
    ],
  );
  await app.push('/taskDetails', arguments: 78);
  // The chip in view, below the date at large text.
  await p.tester.scrollUntilVisible(
    find.byType(ReminderChip),
    200,
    scrollable: app.mainScroll(),
  );
  await p.tester.pumpAndSettle();
  await p.shoot();
}

/// Tasks for the many-people project, given to several of them.
List<Task> _excursionTasks() => [
  Task(
    id: 70,
    title: 'Reservar el autobús',
    dueDate: day(2, 10),
    priority: 3,
    listId: 'excursion',
    assignment: 'member',
    assigneeId: jordi,
    assigneeName: 'Jordi',
    createdBy: me,
    createdByName: 'María',
  ),
  Task(
    id: 71,
    title: 'Recoger las autorizaciones firmadas',
    dueDate: day(4),
    hasTime: false,
    priority: 2,
    listId: 'excursion',
    assignment: 'member',
    assigneeId: lucia,
    assigneeName: 'Lucía',
    createdBy: ana,
    createdByName: 'Ana',
  ),
  Task(
    id: 72,
    title: 'Lista de comida para el día',
    priority: 1,
    listId: 'excursion',
    assignment: 'group',
    createdBy: paul,
    createdByName: 'Paul',
    checklist: [
      ChecklistItem(id: 'e1', title: 'Bocadillos'),
      ChecklistItem(id: 'e2', title: 'Agua', completed: true),
    ],
  ),
  Task(
    id: 73,
    title: 'Avisar a las familias',
    dueDate: day(1, 9),
    priority: 2,
    listId: 'excursion',
    assignment: 'unassigned',
    createdBy: me,
    createdByName: 'María',
  ),
];

void tasksPreviews() {
  previewArea('tasks', 'Tareas and projects', () {
    // ----------------------------------------------------------- the tab
    preview(
      tasksTab,
      'normal',
      'Today\'s filter on an ordinary day with projects shared and not.',
      [...mainScreen, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: busyDay(),
          projects: allProjects,
        );
        await app.tab(p.l.tasks);
        await p.shoot();
      },
    );

    preview(tasksTab, 'empty', 'No tasks at all.', everywhere, (p) async {
      final app = await PreviewApp.open(p);
      await app.tab(p.l.tasks);
      await p.shoot();
    });

    preview(
      tasksTab,
      'inbox',
      'The tasks with no date (`/inbox`, Tareas filtered to Sin fecha).',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: busyDay(),
          projects: allProjects,
        );
        await app.push('/inbox');
        await p.shoot();
      },
    );

    preview(
      tasksTab,
      'deadline-passed',
      'An overdue row whose deadline passed three days ago, among today\'s: it reads «Venció el <date>» once, in the row\'s usual grey, with «Prioridad alta».',
      [es1, es2, ca1, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 90,
              title: 'Entregar la declaración de la renta',
              dueDate: day(-4),
              hasTime: false,
              deadline: day(-3),
              priority: 3,
            ),
          ],
          projects: allProjects,
        );
        await app.tab(p.l.tasks);
        // The row at the top of the view: at 2× the header fills the screen.
        final row = find.widgetWithText(
          TaskTile,
          'Entregar la declaración de la renta',
        );
        await p.tester.scrollUntilVisible(
          row,
          200,
          scrollable: app.mainScroll(),
        );
        await Scrollable.ensureVisible(p.tester.element(row));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      tasksTab,
      'no-match',
      'A search that finds nothing, «dentista»: «No hay tareas que coincidan…», and the ✕ at the search\'s end that empties it in one tap.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: busyDay(),
          projects: allProjects,
        );
        await app.tab(p.l.tasks);
        await p.tester.enterText(
          find.widgetWithText(TextField, p.l.findTask),
          'dentista',
        );
        await p.tester.pumpAndSettle();
        // The keyboard down, so the empty state shows under the search.
        FocusManager.instance.primaryFocus?.unfocus();
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    // ------------------------------------------------------ project page
    preview(
      projectPage,
      'shared',
      '«Matemáticas», shared with Ana and Paul: Todas · Para mí · Ana · Paul, and every task.',
      [es1, es2, esDark, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ...sharedProjectTasks()],
          projects: allProjects,
        );
        await _openProject(app, 'matematicas');
        await p.shoot();
      },
    );

    preview(
      projectPage,
      'person-filter',
      'Ana chosen: only the tasks given to Ana.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ...sharedProjectTasks()],
          projects: allProjects,
        );
        await _openProject(app, 'matematicas');
        await p.tester.tap(find.widgetWithText(ChoiceChip, 'Ana').first);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      projectPage,
      'person-form',
      'Ana chosen, then Nueva tarea (an account without Pro): the form opens with the task given to Ana, «Matemáticas · Ana ▾» (D7).',
      [es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          pro: false,
          tasks: [...normalDay(), ...sharedProjectTasks()],
          projects: allProjects,
        );
        await _openProject(app, 'matematicas');
        await p.tester.tap(find.widgetWithText(ChoiceChip, 'Ana').first);
        await p.tester.pumpAndSettle();
        await app.tap(p.l.newTask);
        FocusManager.instance.primaryFocus?.unfocus();
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      projectPage,
      'many-people',
      '«Excursión de fin de curso», with seven people: the person chips scroll sideways.',
      [es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._excursionTasks()],
          projects: allProjects,
        );
        await _openProject(app, 'excursion');
        await p.shoot();
      },
    );

    preview(
      projectPage,
      'personal',
      'A personal project, «Casa»: no people; its ⋮ («Gestionar Casa») open, with what Proyectos ⋮ offers for it but «Compartir proyecto», the page’s own button, and «Fijar proyecto», which only reorders Proyectos: Editar, Archivar and Eliminar proyecto.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 74,
              title: 'Cambiar la bombilla del pasillo',
              priority: 1,
              listId: 'casa',
            ),
          ],
          projects: allProjects,
        );
        await _openProject(app, 'casa');
        await p.tester.tap(find.byTooltip(p.l.manageItem('Casa')));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      projectPage,
      'empty',
      'A new personal project, «Huerto», with nothing in it yet: no search, only what to do next and «Añadir tarea».',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          projects: [
            ...allProjects,
            TaskListInfo(
              id: 'huerto',
              name: 'Huerto',
              color: 'amber',
              version: 1,
            ),
          ],
        );
        await _openProject(app, 'huerto');
        await p.shoot();
      },
    );

    preview(
      projectPage,
      'archived',
      'An archived personal project, «Huerto», of this account: in place of «Añadir tarea», the bar says it’s archived, with «Restaurar proyecto».',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 78,
              title: 'Plantar los tomates',
              priority: 1,
              listId: 'huerto',
            ),
          ],
          projects: [
            ...allProjects,
            TaskListInfo(
              id: 'huerto',
              name: 'Huerto',
              color: 'amber',
              version: 1,
              archived: true,
            ),
          ],
        );
        await _openProject(app, 'huerto');
        await p.shoot();
      },
    );

    preview(
      projectPage,
      'viewer',
      'Ana’s «Coro», which this account can only view: rows with no circle, each one button that opens the task.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 76,
              title: 'Comer con Ana',
              dueDate: day(0, 13, 30),
              priority: 1,
              listId: 'coro',
              assignment: 'group',
            ),
            Task(
              id: 77,
              title: 'Ensayo general del concierto',
              dueDate: day(3, 19),
              priority: 2,
              listId: 'coro',
              assignment: 'member',
              assigneeId: ana,
              assigneeName: 'Ana',
            ),
          ],
          projects: [...allProjects, _choirToView],
        );
        await _openProject(app, 'coro');
        await p.shoot();
      },
    );

    // ------------------------------------------------------------ detail
    preview(
      detail,
      'created-by',
      'A task in a shared project: given to Ana, «Creada por Paul».',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ...sharedProjectTasks()],
          projects: allProjects,
        );
        await app.push('/taskDetails', arguments: 31);
        await p.shoot();
      },
    );

    preview(
      detail,
      'full',
      'A task with a day and time, repeat, reminder, notes and steps.',
      [es1, esDark],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 75,
              title: 'Tomar la pastilla de la tensión',
              dueDate: day(0, 21),
              priority: 3,
              recurrence: 'daily',
              reminderMinutes: 0,
              notes: 'Después de cenar, con un vaso de agua.',
              checklist: [ChecklistItem(id: 'p1', title: 'Apuntar la tensión')],
            ),
          ],
          projects: allProjects,
        );
        await app.push('/taskDetails', arguments: 75);
        await p.shoot();
      },
    );

    preview(
      detail,
      'file-space-full',
      'A free account’s file space is full: a refused file says so, with «Ver Pro» and «Ver tareas con archivos».',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._fileTasks()],
          projects: [...allProjects, _choir],
          pro: false,
          user: account(storageMb: 100),
          overrides: [
            taskRepositoryProvider.overrideWithValue(_FileTasks(_fileUsage)),
            attachmentEntriesProvider.overrideWith(
              (ref, taskId) async => [
                if (taskId == 80)
                  const AttachmentEntry(
                    'Billetes de avión.pdf',
                    '/preview/billetes.pdf',
                    true,
                    item: TaskAttachment(
                      id: 'refused',
                      taskId: 'viaje',
                      name: 'Billetes de avión.pdf',
                      size: 2 * _megabyte,
                      sha256: '',
                      uploadPending: true,
                      error: TaskAttachment.storageFull,
                    ),
                  ),
              ],
            ),
          ],
        );
        await app.push('/taskDetails', arguments: 80);
        // The file's message and its buttons, the removal last.
        await p.tester.scrollUntilVisible(
          find.text(p.l.fileRemove),
          200,
          scrollable: app.mainScroll(),
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      detail,
      'from-files-list',
      'Opened from «Tareas con archivos»: a task with notes and steps opens with its Archivos section in view.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            for (final task in _fileTasks())
              task.id == 80
                  ? task.copyWith(
                      notes:
                          'Llevar el pasaporte y el cargador.\nReservar el traslado al hotel.',
                      checklist: [
                        ChecklistItem(id: 'l1', title: 'Facturar la maleta'),
                        ChecklistItem(id: 'l2', title: 'Cambiar dinero'),
                        ChecklistItem(id: 'l3', title: 'Imprimir la reserva'),
                      ],
                    )
                  : task,
          ],
          projects: [...allProjects, _choir],
          pro: false,
          user: account(storageMb: 100),
          overrides: [
            taskRepositoryProvider.overrideWithValue(_FileTasks(_fileUsage)),
            attachmentEntriesProvider.overrideWith(
              (ref, taskId) async => [
                if (taskId == 80)
                  const AttachmentEntry(
                    'Billetes de avión.pdf',
                    '/preview/billetes.pdf',
                    true,
                    item: TaskAttachment(
                      id: 'refused',
                      taskId: 'viaje',
                      name: 'Billetes de avión.pdf',
                      size: 2 * _megabyte,
                      sha256: '',
                      uploadPending: true,
                      error: TaskAttachment.storageFull,
                    ),
                  ),
              ],
            ),
          ],
        );
        await app.pushPage(const TasksWithFilesScreen());
        await app.tap('Viaje a Lisboa');
        await p.shoot();
      },
    );

    preview(
      detail,
      'notes-steps',
      'A task with notes, a reminder and three steps: the notes come right after the date.',
      [es1, es13, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 76,
              title: 'Ir al médico',
              dueDate: day(1, 9),
              priority: 1,
              reminderMinutes: 60,
              notes: 'Ir en ayunas. Llevar la tarjeta sanitaria y el volante.',
              checklist: [
                ChecklistItem(id: 's1', title: 'Pedir el volante'),
                ChecklistItem(id: 's2', title: 'Cenar ligero la noche antes'),
                ChecklistItem(id: 's3', title: 'Recoger los resultados'),
              ],
            ),
          ],
          projects: allProjects,
        );
        await app.push('/taskDetails', arguments: 76);
        await p.shoot();
      },
    );

    preview(
      detail,
      'alert-passed',
      'A task for today with no time, opened at 09:41 with reminders on: its 9:00 alert has passed, so the chip says there’s no reminder.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 77,
              title: 'Llamar a Marta',
              dueDate: day(0),
              hasTime: false,
              priority: 1,
            ),
          ],
          projects: allProjects,
          reminders: const ReminderPreferences(
            enabled: true,
            dateOnlyTime: 540,
            asked: true,
          ),
        );
        await app.push('/taskDetails', arguments: 77);
        // The chip in view, below the date at large text.
        await p.tester.scrollUntilVisible(
          find.text(p.l.noReminderTimePassed),
          200,
          scrollable: app.mainScroll(),
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      detail,
      'alert-rang',
      'Opened from its notice at 09:41: «Pagar la luz», today at 09:50 with «10 minutos antes», rang at 09:40. The chip, with the usual bell, reads «Recordatorio enviado: hoy, 09:40»; a tap opens the reminder choices.',
      [es1, ca2],
      (p) async {
        await _rangAlert(p);
      },
    );

    preview(
      detail,
      'alert-snoozed',
      'The same task after «Posponer 10 min» at 09:41: the chip, with the usual bell, reads «Recordatorio pospuesto: hoy, 09:51» until the snoozed notice rings.',
      [es1, ca2],
      (p) async {
        await _rangAlert(p, snoozed: true);
      },
    );

    preview(
      detail,
      'reader',
      'A «Todos» task in Ana’s «Coro», where this account is «lector», as it opens: «Solo puedes ver esta tarea y elegir tus recordatorios.», no ✏, 🗑 or bottom bar, and (in view at 1×) the chip «Recordatorio: 10 minutos antes», which opens this account’s own reminder choices.',
      [es1, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 79,
              title: 'Ensayo del coro',
              dueDate: day(1, 19),
              priority: 1,
              listId: 'coro',
              assignment: 'group',
              reminderMinutes: 10,
            ),
          ],
          projects: [...allProjects, _choirToView],
          reminders: const ReminderPreferences(enabled: true, asked: true),
        );
        await app.push('/taskDetails', arguments: 79);
        await p.shoot();
        // The chip in view, below the date at large text.
        await p.tester.scrollUntilVisible(
          find.byType(ReminderChip),
          200,
          scrollable: app.mainScroll(),
        );
        await p.tester.pumpAndSettle();
        await p.shoot('reader-chip');
      },
      then: {
        'reader-chip':
            'The same page scrolled to its reminder chip, «Recordatorio: 10 minutos antes», drawn as a button with its outline.',
      },
    );

    preview(
      detail,
      'labels',
      'A task with two labels and a day but no time: the labels read as one grey line, «#casa · #recados», with no outline; the day is one row, «Planificado para» over the date, with no «Hora» row.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 78,
              title: 'Comprar bombillas',
              dueDate: day(2),
              hasTime: false,
              priority: 1,
              labels: ['casa', 'recados'],
            ),
          ],
          projects: allProjects,
        );
        await app.push('/taskDetails', arguments: 78);
        await p.shoot();
      },
    );

    // --------------------------------------------------- tasks with files
    preview(
      tasksWithFiles,
      'list',
      'Three of this account’s tasks hold files, largest first; a shared project’s, whose owner is someone else, isn’t listed.',
      [es1, es2, esDark, const Variant('es', true, 2), ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._fileTasks()],
          projects: [...allProjects, _choir],
          pro: false,
          user: account(storageMb: 100),
          overrides: [
            taskRepositoryProvider.overrideWithValue(_FileTasks(_fileUsage)),
          ],
        );
        await app.pushPage(const TasksWithFilesScreen());
        await p.shoot();
      },
    );

    preview(tasksWithFiles, 'empty', 'No task holds files.', [es1, es2], (
      p,
    ) async {
      final app = await PreviewApp.open(
        p,
        tasks: normalDay(),
        projects: allProjects,
        pro: false,
        user: account(storageMb: 100),
        overrides: [
          taskRepositoryProvider.overrideWithValue(_FileTasks(const {})),
        ],
      );
      await app.pushPage(const TasksWithFilesScreen());
      await p.shoot();
    });

    // ---------------------------------------------------------- projects
    preview(
      projects,
      'list',
      'Every project, shared and not.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            ...sharedProjectTasks(),
            ..._excursionTasks(),
          ],
          projects: allProjects,
        );
        await app.push('/lists');
        await p.shoot();
      },
    );

    preview(
      projects,
      'empty',
      'No projects yet: no «Grupos» until something is shared.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/lists');
        await p.shoot();
      },
    );
  });
}
