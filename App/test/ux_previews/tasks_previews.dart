// The Tareas tab, a project's page (a shared one with its person filter and
// «Creada por»), a task's details and the projects list.
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'lib/widgets/project_scope_control.dart',
    'lib/widgets/project_preferences.dart',
    'lib/widgets/task_tile.dart',
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

Future<void> _openProject(PreviewApp app, String id) async {
  await app.tab(app.p.l.tasks);
  await app.pushPage(HomeScreen(isRoot: false, listId: id));
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
        final app = await PreviewApp.open(p, tasks: busyDay(), projects: allProjects);
        await app.tab(p.l.tasks);
        await p.shoot();
      },
    );

    preview(
      tasksTab,
      'empty',
      'No tasks at all.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p);
        await app.tab(p.l.tasks);
        await p.shoot();
      },
    );

    preview(
      tasksTab,
      'inbox',
      'The tasks with no date (`/inbox`, Tareas filtered to Sin fecha).',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: busyDay(), projects: allProjects);
        await app.push('/inbox');
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
      'A personal project, «Casa»: no people.',
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
              checklist: [
                ChecklistItem(id: 'p1', title: 'Apuntar la tensión'),
              ],
            ),
          ],
          projects: allProjects,
        );
        await app.push('/taskDetails', arguments: 75);
        await p.shoot();
      },
    );

    // ---------------------------------------------------------- projects
    preview(
      projects,
      'list',
      'Every project, shared and not.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ...sharedProjectTasks(), ..._excursionTasks()],
          projects: allProjects,
        );
        await app.push('/lists');
        await p.shoot();
      },
    );

    preview(
      projects,
      'empty',
      'No projects yet.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/lists');
        await p.shoot();
      },
    );
  });
}
