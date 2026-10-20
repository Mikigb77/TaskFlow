// Notas, the third tab: empty, with notes, one note open, and a note said
// in the capture sheet.
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_previews.dart' show hear;
import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const notesTab = Screen(
  'notes',
  'notes-tab',
  'Notas, the third tab',
  sources: [
    'lib/screens/notes_screen.dart',
    'lib/widgets/note_text.dart',
    'lib/widgets/app_components.dart',
  ],
);

const noteOpen = Screen(
  'notes',
  'note',
  'A note opened (task details for a note)',
  sources: [
    'lib/screens/task_detail_screen.dart',
    'lib/widgets/note_text.dart',
    'lib/widgets/checklist_editor.dart',
  ],
);

const noteSaid = Screen(
  'notes',
  'note-capture',
  'Añadir nota: the capture sheet for a note',
  sources: [
    'lib/screens/voice_task_screen.dart',
    'lib/widgets/capture_review_editor.dart',
    'lib/screens/notes_screen.dart',
  ],
);

List<Task> _notes() => [
  Task(
    id: 80,
    kind: 'note',
    title: 'Ideas para el cumpleaños de Lucía',
    notes:
        'Ideas para el cumpleaños de Lucía\nTarta de chocolate, globos y una '
        'piñata. Invitar a sus amigas del colegio y a los primos.',
    priority: 1,
  ),
  Task(
    id: 81,
    kind: 'note',
    title: 'Receta de la abuela: croquetas de jamón',
    notes: 'Bechamel espesa, reposar toda la noche en la nevera.',
    priority: 1,
    checklist: [
      ChecklistItem(id: 'n1', title: 'Jamón serrano', completed: true),
      ChecklistItem(id: 'n2', title: 'Leche entera'),
      ChecklistItem(id: 'n3', title: 'Pan rallado'),
    ],
  ),
  Task(
    id: 82,
    kind: 'note',
    title: 'Medidas de la ventana del salón',
    notes: '1,20 × 1,45 m. La cortina, de 2,60 m de ancho.',
    priority: 1,
    listId: 'casa',
  ),
  // Said in the capture sheet: titled by the start of its words.
  Task(
    id: 84,
    kind: 'note',
    title: 'Para la reunión del cole',
    notes:
        'Para la reunión del cole: preguntar por el comedor y por la '
        'excursión de primavera',
    priority: 1,
  ),
  Task(
    id: 83,
    kind: 'note',
    title: 'Libros que me recomendó Ana',
    notes: 'El infinito en un junco. Patria. La sombra del viento.',
    priority: 1,
  ),
];

void notesPreviews() {
  previewArea('notes', 'Notas', () {
    preview(
      notesTab,
      'empty',
      'No notes yet: one line on what notes are for, no search, and Añadir nota.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.tab(p.l.notes);
        await p.shoot();
      },
    );

    preview(
      notesTab,
      'list',
      'Five notes: one said in the sheet (its preview starts after its title), one with steps and one in a project.',
      [...mainScreen, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._notes()],
          projects: allProjects,
        );
        await app.tab(p.l.notes);
        await p.shoot();
      },
    );

    preview(
      noteOpen,
      'with-steps',
      'The croquetas note opened: its text and steps.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), ..._notes()],
          projects: allProjects,
        );
        await app.tab(p.l.notes);
        await app.tap('Receta de la abuela: croquetas de jamón');
        await p.shoot();
      },
    );

    preview(
      noteSaid,
      'listening',
      'Añadir nota with the mic: listening for a note.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: [...normalDay(), ..._notes()]);
        await app.tab(p.l.notes);
        await p.tester.tap(find.text(p.l.addNote).hitTestable());
        await p.tester.pumpAndSettle();
        await hear(
          app,
          'Para la reunión del cole: preguntar por el comedor y por la '
          'excursión de primavera',
        );
        await p.shoot();
        // Listo: a note is understood on the phone, with no server.
        await p.tester.tap(find.widgetWithText(FilledButton, p.l.done).first);
        await p.frames();
        await p.tester.pumpAndSettle();
        await p.shoot('result');
      },
      then: {'result': 'Listo: the note as it will be saved, with Guardar nota.'},
    );

    preview(
      noteSaid,
      'typing-free-0',
      'A free account with no dictations left: Añadir nota (+) types, with no used-up line and no Ver Pro.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          pro: false,
          freeLeft: 0,
          tasks: [...normalDay(), ..._notes()],
        );
        await app.tab(p.l.notes);
        await p.tester.tap(find.text(p.l.addNote).hitTestable());
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );
  });
}
