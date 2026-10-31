// The task form: a new task (`/newTask`, how an account without Pro adds
// one) and editing an existing task (`/editTask`).
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_previews.dart' show hear, openSheet;
import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const _editorSources = [
  'lib/widgets/task_editor.dart',
  'lib/widgets/schedule_editor.dart',
  'lib/widgets/reminder_control.dart',
  'lib/widgets/repeat_rule_control.dart',
  'lib/widgets/task_planning_control.dart',
  'lib/widgets/task_list_picker.dart',
  'lib/widgets/checklist_editor.dart',
  'lib/widgets/custom_app_bar.dart',
];

const newTask = Screen(
  'form',
  'new-task',
  'The new-task form (`/newTask`), from Calendar\'s Nueva tarea',
  sources: [
    'lib/screens/edit_task_screen.dart',
    'lib/widgets/task_form_entry.dart',
    ..._editorSources,
  ],
);

const editTask = Screen(
  'form',
  'edit-task',
  'Editing an existing task (`/editTask`)',
  sources: ['lib/screens/edit_task_screen.dart', ..._editorSources],
);

final _club = TaskListInfo(
  id: 'club',
  name: 'Club de lectura',
  color: 'violet',
  version: 1,
  role: 'viewer',
  shared: true,
  ownerId: lucia,
  people: const [
    ProjectMember(id: lucia, name: 'Lucía', role: 'owner'),
    ProjectMember(id: me, name: 'María', role: 'viewer'),
  ],
);

/// A task with everything filled in: day and time, reminder, project,
/// notes and steps.
Task _pickup() => Task(
  id: 60,
  title: 'Recoger a los niños del colegio',
  dueDate: day(1, 17),
  priority: 3,
  reminderMinutes: 30,
  listId: 'casa',
  notes: 'Los martes salen antes por la excursión. Llevar las meriendas.',
  checklist: [
    ChecklistItem(id: 'm1', title: 'Meriendas', completed: true),
    ChecklistItem(id: 'm2', title: 'Chaquetas'),
  ],
);

Task _long() => Task(
  id: 61,
  title:
      'Pedir cita en el ayuntamiento para renovar el padrón y llevar el '
      'libro de familia, el DNI de los dos y el contrato del piso',
  dueDate: day(2, 9, 30),
  priority: 2,
  notes:
      'La sede de la calle Mayor abre de 9 a 14. Si piden el certificado '
      'de empadronamiento colectivo, hay que pedirlo aparte en la web. '
      'Llevar fotocopias de todo por si acaso.',
);

/// Opens the form from Calendar's Nueva tarea: an account without Pro and
/// without free dictations from the server.
Future<PreviewApp> _openForm(Preview p) async {
  final app = await PreviewApp.open(
    p,
    pro: false,
    tasks: normalDay(),
    projects: allProjects,
  );
  await app.tap(p.l.newTask);
  return app;
}

Future<void> _keyboardDown(Preview p) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await p.tester.pumpAndSettle();
}

Future<void> _title(Preview p, String words) async {
  await p.tester.enterText(find.byKey(const ValueKey('task-title')), words);
  await p.tester.pumpAndSettle();
}

void formPreviews() {
  previewArea('form', 'Task form', () {
    preview(
      newTask,
      'empty',
      'Just opened: the title has the focus, so the keyboard is up.',
      [es1, es2, ca2],
      (p) async {
        await _openForm(p);
        await p.showKeyboard();
        await p.shoot();
      },
    );

    preview(
      newTask,
      'filled',
      'A title and Mañana chosen; the keyboard is down.',
      [...mainScreen, ca2],
      (p) async {
        await _openForm(p);
        await _title(p, 'Llamar al médico');
        await p.tester.tap(find.byKey(const ValueKey('new-task-tomorrow')));
        await p.tester.pumpAndSettle();
        await _keyboardDown(p);
        await p.shoot();
      },
    );

    preview(
      newTask,
      'details',
      'Más detalles opened: reminder, repeat, project, notes and steps.',
      [es1, es2, ca2],
      (p) async {
        await _openForm(p);
        await _title(p, 'Llamar al médico');
        await p.tester.tap(find.byKey(const ValueKey('new-task-tomorrow')));
        await p.tester.pumpAndSettle();
        await _keyboardDown(p);
        final more = find.byKey(const ValueKey('task-more-details'));
        await p.tester.ensureVisible(more);
        await p.tester.pumpAndSettle();
        await p.tester.tap(more);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      newTask,
      'from-dictation',
      'A free account with dictations left heard «Médico el viernes a las 5 de la tarde» and tapped Escribir: the form opens on Friday at 17:00, titled Médico.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          pro: false,
          freeLeft: 5,
          tasks: normalDay(),
          projects: allProjects,
        );
        await openSheet(app);
        await hear(app, 'Médico el viernes a las 5 de la tarde');
        await p.tester.tap(
          find
              .ancestor(
                of: find.text(p.l.captureTypeInstead),
                matching: find.byWidgetPredicate(
                  (widget) => widget is TextButton,
                ),
              )
              .first,
        );
        await p.tester.pumpAndSettle();
        await _keyboardDown(p);
        await p.shoot();
      },
    );

    preview(
      newTask,
      'long-title',
      'A very long title, as someone might type it.',
      [es2, ca2],
      (p) async {
        await _openForm(p);
        await _title(p, _long().title);
        await p.tester.tap(find.byKey(const ValueKey('new-task-today')));
        await p.tester.pumpAndSettle();
        await _keyboardDown(p);
        await p.shoot();
      },
    );

    preview(
      newTask,
      'keyboard',
      'Typing the title with the keyboard up: what stays in view above it.',
      [es1, es2, ca2],
      (p) async {
        await _openForm(p);
        await _title(p, 'Recoger las gafas en la óptica');
        await p.tester.tap(find.byKey(const ValueKey('new-task-today')));
        await p.tester.pumpAndSettle();
        await p.tester.tap(find.byKey(const ValueKey('task-title')));
        await p.tester.pumpAndSettle();
        await p.showKeyboard();
        await p.shoot();
      },
    );

    preview(
      editTask,
      'existing',
      'A task with a day and time, reminder, project, notes and steps.',
      [es1, es2, esDark, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _pickup()],
          projects: allProjects,
        );
        await app.push('/editTask', arguments: 60);
        await p.shoot();
      },
    );

    preview(
      editTask,
      'long',
      'A long title and long notes at large text.',
      [es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _long()],
          projects: allProjects,
        );
        await app.push('/editTask', arguments: 61);
        await p.shoot();
      },
    );

    preview(
      editTask,
      'read-only',
      'A task in a project shared with you as a reader: it can\'t be edited.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 62,
              title: 'Leer los capítulos 3 y 4',
              dueDate: day(4),
              hasTime: false,
              priority: 1,
              listId: 'club',
              assignment: 'group',
            ),
          ],
          projects: [...allProjects, _club],
        );
        await app.push('/editTask', arguments: 62);
        await p.shoot();
      },
    );
  });
}
