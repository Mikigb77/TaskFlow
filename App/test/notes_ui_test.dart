import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:flutter/semantics.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/note_text.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';

Widget app(ProviderContainer container, Widget home,
        {bool dark = false, String language = 'en'}) =>
    UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: home));

/// Notes typed in the capture sheet, without Pro, and saved in memory.
ProviderContainer typingContainer(
    {TaskNotifier Function()? tasks, List<TaskListInfo>? projects}) {
  final captures = MemoryCaptures();
  final container = designContainer(
      tasks: tasks,
      projects: projects,
      pro: false,
      overrides: [captureStoreProvider.overrideWithValue(captures)]);
  captures.tasks = container;
  return container;
}

void main() {
  testWidgets(
      'note create, search and links work at 2x text in light/dark and English/Spanish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in ['en', 'es']) {
      for (final dark in [false, true]) {
        final container = typingContainer();
        await tester.pumpWidget(app(container, const NotesScreen(),
            dark: dark, language: language));
        await tester.pumpAndSettle();
        expect(find.text('Doctor appointment'), findsNothing);
        // Its date words stay words: a note never gets a date.
        await typeCapture(
            tester,
            language == 'en' ? 'Add a note' : 'Añadir nota',
            'Reference Friday at 17:00\n'
                'Opening hours and directions https://example.org/long-reference-information-for-visiting');
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(CaptureResult),
                matching: find.byIcon(Icons.calendar_today_outlined)),
            findsNothing);
        await saveCapture(tester);
        final note = container
            .read(taskProvider)
            .requireValue
            .singleWhere((item) => item.isNote);
        expect(note.dueDate, isNull);
        expect(note.title, 'Reference Friday at 17:00');
        expect(find.byType(NotesScreen), findsOneWidget);
        // The save message, with its Deshacer, is done with.
        ScaffoldMessenger.of(tester.element(find.byType(NotesScreen)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        // The new note was brought into view; the search is back up.
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('note-search')), -200,
            scrollable: find.byType(Scrollable).first);
        await tester.enterText(
            find.byKey(const ValueKey('note-search')), 'directions');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.text('Reference Friday at 17:00'), 180,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reference Friday at 17:00'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Reschedule'), findsNothing);
        await tester.scrollUntilVisible(find.byType(NoteText), 180,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.byType(SelectableText), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
  });

  testWidgets(
      'note review keeps type and omits task scheduling or priority controls',
      (tester) async {
    final captures = MemoryCaptures();
    final container = designContainer(overrides: [
      captureStoreProvider.overrideWithValue(captures),
      ...captureSheetOverrides(),
    ]);
    captures.tasks = container;
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container, const Scaffold(body: SizedBox())));
    captures.current = CaptureSession(
        id: 'note',
        ownerKey: container.read(captureOwnerProvider),
        timezone: 'UTC',
        capturedAt: DateTime.now().toUtc(),
        status: 'ready',
        kind: 'note',
        transcript: 'Friday at 17:00',
        drafts: [
          CaptureDraft.fromAI(TaskDraft.fromJson({
            'kind': 'note',
            'title': 'Reference',
            'notes': 'Friday at 17:00',
            'priority': 1,
            'transcript': 'Friday at 17:00',
            'questions': []
          }))
        ]);
    await openCaptureResult(tester, 'note');
    expect(find.widgetWithText(FilledButton, 'Save note'), findsOneWidget);
    expect(find.text('Add time'), findsNothing);
    expect(find.text('Planning'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(
        container
            .read(taskProvider)
            .requireValue
            .singleWhere((item) => item.isNote)
            .notes,
        'Friday at 17:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared view-only note offers no editing actions',
      (tester) async {
    final container = ProviderContainer(overrides: [
      taskProvider.overrideWith((ref) => _Viewer()),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskListsProvider.overrideWith((ref) async => [
            TaskListInfo(
                id: 'group', name: 'Reference', role: 'viewer', shared: true)
          ]),
      attachmentEntriesProvider.overrideWith((ref, id) async => []),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container, const TaskDetailScreen(taskId: 1)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit note'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
    expect(find.textContaining('View-only note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'UX-303 / UX-425: searching medico, collegi or a half-typed col· lists the note (2x text, 320 dp, both themes, es/ca/en)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in ['es', 'ca', 'en']) {
      for (final dark in [false, true]) {
        final l10n = lookupAppLocalizations(Locale(language));
        final container = ProviderContainer(overrides: [
          taskProvider.overrideWith((ref) => _AccentNotes()),
          taskRepositoryProvider.overrideWithValue(MemoryTasks()),
          taskListsProvider.overrideWith((ref) async => []),
          pendingCapturesProvider.overrideWith((ref) async => []),
          attachmentEntriesProvider.overrideWith((ref, id) async => []),
          themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        ]);
        await tester.pumpWidget(app(container, const NotesScreen(),
            dark: dark, language: language));
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('note-search'));
        final list = find.byType(Scrollable).first;
        Future<void> searchFor(String query) async {
          // Back to the top, then down to the search field.
          await tester.drag(list, const Offset(0, 3000));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(search, 200, scrollable: list);
          await tester.enterText(search, query);
          await tester.pumpAndSettle();
        }

        await searchFor('medico');
        await tester.scrollUntilVisible(find.text('Médico'), 180,
            scrollable: list);
        expect(find.text('Médico'), findsOneWidget,
            reason: '$language dark=$dark');
        expect(find.text('Comprar pan'), findsNothing);
        expect(find.text(l10n.noteNoMatches), findsNothing);

        await searchFor('collegi');
        await tester.scrollUntilVisible(find.text('Reunió al col·legi'), 180,
            scrollable: list);
        expect(find.text('Reunió al col·legi'), findsOneWidget);
        expect(find.text('Médico'), findsNothing);

        // UX-425: one keystroke into `col·legi` the query is `col·`; the
        // note must stay listed while the user looks for the next key.
        await searchFor('col·');
        expect(find.text(l10n.noteNoMatches), findsNothing,
            reason: '$language dark=$dark: `col·` says nothing matches');
        await tester.scrollUntilVisible(find.text('Reunió al col·legi'), 180,
            scrollable: list);
        expect(find.text('Reunió al col·legi'), findsOneWidget,
            reason: '$language dark=$dark: `col·`');
        expect(find.text('Médico'), findsNothing);

        await searchFor('dentista');
        await tester.scrollUntilVisible(find.text(l10n.noteNoMatches), 180,
            scrollable: list);
        expect(find.text(l10n.noteNoMatches), findsOneWidget);
        expect(find.text('Médico'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
  });

  for (final language in ['es', 'en']) {
    testWidgets(
        'UX-428: Notas uses the Notas tab’s description_outlined icon for its empty state and every note row ($language)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l10n = lookupAppLocalizations(Locale(language));
      ProviderContainer notes(TaskNotifier Function() tasks) =>
          ProviderContainer(overrides: [
            taskProvider.overrideWith((ref) => tasks()),
            taskRepositoryProvider.overrideWithValue(MemoryTasks()),
            taskListsProvider.overrideWith((ref) async => []),
            pendingCapturesProvider.overrideWith((ref) async => []),
            attachmentEntriesProvider.overrideWith((ref, id) async => []),
            themeStoreProvider.overrideWithValue(MemoryThemeStore()),
          ]);

      final empty = notes(_NoNotes.new);
      await tester.pumpWidget(
          app(empty, const NotesScreen(), language: language));
      await tester.pumpAndSettle();
      expect(find.text(l10n.notesEmpty), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(EmptyState),
              matching: find.byIcon(Icons.description_outlined)),
          findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      empty.dispose();

      final full = notes(_AccentNotes.new);
      await tester.pumpWidget(
          app(full, const NotesScreen(), language: language));
      await tester.pumpAndSettle();
      for (final title in ['Médico', 'Reunió al col·legi', 'Comprar pan']) {
        final row = find.ancestor(
            of: find.text(title), matching: find.byType(ListTile));
        expect(row, findsOneWidget, reason: title);
        expect(tester.widget<ListTile>(row).leading, isA<Icon>());
        expect((tester.widget<ListTile>(row).leading! as Icon).icon,
            Icons.description_outlined,
            reason: title);
      }
      expect(find.byIcon(Icons.notes_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      full.dispose();
    });
  }

  // ---- P16: notes, newest first, saved where you are ----

  testWidgets(
      'UX-304: three notes saved in turn appear newest first, each at the top, in view and highlighted',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final l10n = lookupAppLocalizations(const Locale('es'));
    final container = typingContainer(tasks: _ManyNotes.new);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    Finder row(String title) => find.ancestor(
        of: find.text(title, skipOffstage: false),
        matching: find.byType(ListTile, skipOffstage: false));
    // Twelve notes, the newest (12) first.
    expect(tester.getRect(row('Nota 12')).top,
        lessThan(tester.getRect(row('Nota 11')).top));
    for (final title in ['Nota uno', 'Nota dos', 'Nota tres']) {
      // Scrolled down the list, as after looking for something.
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await typeCapture(tester, l10n.addNote, title);
      await saveCapture(tester);
      expect(find.byType(NotesScreen), findsOneWidget);
      final saved = find.ancestor(
          of: find.text(title), matching: find.byType(ListTile));
      expect(saved.hitTestable(), findsOneWidget, reason: title);
      final top = tester.getRect(saved).top;
      for (final other
          in find.byType(ListTile, skipOffstage: false).evaluate()) {
        final box = other.renderObject! as RenderBox;
        if (other.widget == tester.widget(saved)) continue;
        expect(box.localToGlobal(Offset.zero).dy, greaterThan(top),
            reason: '$title is above every other note');
      }
      final colors = Theme.of(tester.element(saved)).colorScheme;
      expect(
          tester
              .widget<AppSurface>(find.ancestor(
                  of: find.text(title), matching: find.byType(AppSurface)))
              .color,
          colors.primaryContainer,
          reason: '$title is highlighted');
    }
    // Newest first.
    final tres = tester.getRect(row('Nota tres')).top;
    final dos = tester.getRect(row('Nota dos')).top;
    final uno = tester.getRect(row('Nota uno')).top;
    expect(tres, lessThan(dos));
    expect(dos, lessThan(uno));
    expect(uno, lessThan(tester.getRect(row('Nota 12')).top));
    expect(tester.takeException(), isNull);
  });

  // ---- P62 (UX-459): a new note the list doesn't show leaves it alone ----

  /// Notas scrolled down, then `Añadir nota` saves [title]: returns the
  /// list's scroll offset before and after.
  Future<(double, double)> saveScrolledDown(
      WidgetTester tester, String title) async {
    final l10n = lookupAppLocalizations(const Locale('es'));
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(list).position.pixels;
    expect(before, greaterThan(0), reason: 'scrolled down');
    await typeCapture(tester, l10n.addNote, title);
    await saveCapture(tester);
    expect(find.byType(NotesScreen), findsOneWidget);
    final after = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    return (before, after);
  }

  void expectNothingHighlighted(WidgetTester tester) {
    final colors =
        Theme.of(tester.element(find.byType(NotesScreen))).colorScheme;
    for (final surface in tester.widgetList<AppSurface>(
        find.descendant(
            of: find.byType(NotesScreen),
            matching: find.byType(AppSurface, skipOffstage: false)))) {
      expect(surface.color, isNot(colors.primaryContainer));
    }
  }

  testWidgets(
      'UX-459: on Notas filtered to a view-only project, scrolled down, a note saved with Añadir nota (to Personal) leaves the scroll where it was and lights no row',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = typingContainer(tasks: _ProjectNotes.new, projects: [
      TaskListInfo(id: 'group', name: 'Recetas', role: 'viewer', shared: true)
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        app(container, const NotesScreen(listId: 'group'), language: 'es'));
    await tester.pumpAndSettle();
    final (before, after) = await saveScrolledDown(tester, 'Nota nueva');
    // Saved, but to Personal: not in this project's list.
    expect(
        container
            .read(taskProvider)
            .requireValue
            .where((t) => t.title == 'Nota nueva')
            .single
            .listId,
        isNull);
    expect(find.text('Nota nueva', skipOffstage: false), findsNothing);
    expect(after, before);
    expectNothingHighlighted(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-459: with a search the new note doesn’t match, scrolled down, saving a note leaves the scroll where it was and lights no row',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = typingContainer(tasks: _ManyNotes.new);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-search')), 'Nota');
    await tester.pumpAndSettle();
    expect(find.text('Nota 12'), findsOneWidget);
    final (before, after) = await saveScrolledDown(tester, 'Comprar pan');
    expect(
        container
            .read(taskProvider)
            .requireValue
            .where((t) => t.title == 'Comprar pan'),
        hasLength(1));
    expect(find.text('Comprar pan', skipOffstage: false), findsNothing);
    expect(after, before);
    expectNothingHighlighted(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-313: in a project’s notes, Añadir nota opens capture with that projectId',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final messenger = tester.binding.defaultBinaryMessenger;
    const timezone = MethodChannel('flutter_timezone');
    messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
    addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(l10n.addNote, 'Añadir nota');
    final captures = MemoryCaptures();
    final container = designContainer(
      tasks: _AccentNotes.new,
      projects: [TaskListInfo(id: 'casa', name: 'Casa')],
      overrides: [
        captureStoreProvider.overrideWithValue(captures),
        nativeSpeechProvider.overrideWithValue(ListeningSpeech()),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(app(
        container, const NotesScreen(listId: 'casa', isRoot: false),
        language: 'es'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.addNote));
    await tester.pumpAndSettle();
    final capture = tester.widget<VoiceTaskScreen>(find.byType(VoiceTaskScreen));
    expect(capture.kind, 'note');
    expect(capture.projectId, 'casa');
    if (captures.current != null) {
      expect(captures.current!.projectId, 'casa');
    }
    await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceTaskScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (language, noMatch, label, all) in [
    ('es', 'No hay notas que coincidan', 'Proyecto', 'Todas las notas'),
    ('ca', 'No hi ha notes que coincideixin', 'Projecte', 'Totes les notes'),
    ('en', 'No matching notes', 'Project', 'All notes'),
  ]) {
    testWidgets(
        'UX-312 / UX-323: no results say $noMatch; the filter is labelled $label, with $all ($language)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l10n = lookupAppLocalizations(Locale(language));
      expect(l10n.noteNoMatches, noMatch);
      expect(l10n.list, label);
      expect(l10n.allNotes, all);
      final container = designContainer(
          tasks: _AccentNotes.new,
          projects: [TaskListInfo(id: 'casa', name: 'Casa')]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
          app(container, const NotesScreen(), language: language));
      await tester.pumpAndSettle();
      final filter = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(filter);
      await tester.pumpAndSettle();
      expect(find.descendant(of: filter, matching: find.text(label)),
          findsOneWidget);
      expect(find.descendant(of: filter, matching: find.text(all)),
          findsOneWidget);
      // The 'all' option no longer reads Notas.
      expect(find.descendant(of: filter, matching: find.text(l10n.notes)),
          findsNothing);
      final search = find.byKey(const ValueKey('note-search'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(search, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(search, 'dentista');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(noMatch), 180,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(noMatch), findsOneWidget);
      expect(find.text(l10n.noMatches), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'UX-312: the note editor asks for a title in note words, with a note example',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(l10n.noteTitleHint, 'p. ej., Clave del wifi');
    expect(l10n.noteTitleRequired, 'Ponle un título a la nota');
    final container = designContainer(tasks: _AccentNotes.new);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    // The form edits a saved note: emptied, its title asks in note words.
    Navigator.of(tester.element(find.byType(NotesScreen))).push(
        MaterialPageRoute<void>(
            builder: (_) => TaskEditor(
                task: Task(
                    id: 99, kind: 'note', title: 'Clave', priority: 1))));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('task-title'));
    await tester.enterText(title, '');
    await tester.pumpAndSettle();
    expect(find.descendant(of: title, matching: find.text(l10n.noteTitleHint)),
        findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.noteTitleRequired), findsOneWidget);
    expect(find.text(l10n.titleRequiredField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UX-312: a failed load says the notes are still on the phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(l10n.notesSavedOnDevice, 'Tus notas siguen en este teléfono.');
    final container = designContainer(tasks: _FailedNotes.new);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.notesSavedOnDevice), findsOneWidget);
    expect(find.text(l10n.savedOnDevice), findsNothing);
  });

  testWidgets(
      'UX-337, UX-1520: the note-versus-task help shows only when there are no notes, once',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final l10n = lookupAppLocalizations(const Locale('es'));
    final none = designContainer(tasks: _NoNotes.new);
    await tester.pumpWidget(app(none, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.notesEmptyHelp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    none.dispose();
    // Tasks only, still no notes.
    final tasksOnly = designContainer();
    await tester.pumpWidget(app(tasksOnly, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.notesEmptyHelp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    tasksOnly.dispose();
    final some = designContainer(tasks: _AccentNotes.new);
    addTearDown(some.dispose);
    await tester.pumpWidget(app(some, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    expect(find.text('Médico'), findsOneWidget);
    expect(find.text(l10n.notesEmptyHelp, skipOffstage: false), findsNothing);
  });

  // ---- P38 (UX-118) and P10 (UX-309) ----

  for (final pro in [true, false]) {
    testWidgets(
        'UX-118: ${pro ? 'with' : 'without'} Pro, Notas shows one Añadir nota button (${pro ? 'mic' : 'add'} icon) and no Dictar una nota or Nueva nota',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l10n = lookupAppLocalizations(const Locale('es'));
      final container = designContainer(tasks: _AccentNotes.new, pro: pro);
      addTearDown(container.dispose);
      await tester.pumpWidget(app(container, const NotesScreen(), language: 'es'));
      await tester.pumpAndSettle();
      expect(l10n.addNote, 'Añadir nota');
      final add = find.widgetWithText(FilledButton, l10n.addNote);
      expect(add.hitTestable(), findsOneWidget);
      expect(
          find.descendant(
              of: add,
              matching:
                  find.byIcon(pro ? Icons.mic_none_rounded : Icons.add_rounded)),
          findsOneWidget);
      expect(find.text('Dictar una nota'), findsNothing);
      expect(find.text('Nueva nota'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      // One way to add a note: no second mic or add button.
      final adds = find.byWidgetPredicate((w) =>
          w is Icon &&
          [Icons.mic_none_rounded, Icons.add_rounded, Icons.edit_note_rounded]
              .contains(w.icon));
      expect(adds.hitTestable(), findsOneWidget,
          reason: 'one way to add a note');
      expect(tester.takeException(), isNull);
    });
  }

  /// The app in Spanish, on the detail of one note with a body.
  Future<ProviderContainer> openNote(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
        tasks: _OneNote.new,
        regionalStore:
            MemoryRegionalStore(const RegionalPreferences(language: 'es')));
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed('/taskDetails', arguments: 1);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    return container;
  }

  testWidgets('UX-309: tapping a note’s body opens the note editor',
      (tester) async {
    final l10n = lookupAppLocalizations(const Locale('es'));
    await openNote(tester);
    await tester.tap(find.textContaining('Abre de 9 a 14'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text(l10n.editNote)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-309: a note’s detail has Editar nota at the bottom, which opens the editor, and no ✏ in the app bar; Eliminar stays there',
      (tester) async {
    final l10n = lookupAppLocalizations(const Locale('es'));
    await openNote(tester);
    expect(l10n.editNote, 'Editar nota');
    final edit = find.widgetWithText(FilledButton, l10n.editNote);
    expect(edit.hitTestable(), findsOneWidget);
    final bar = find.byType(AppBar);
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.edit_outlined)),
        findsNothing);
    expect(
        find.descendant(of: bar, matching: find.byTooltip(l10n.editNote)),
        findsNothing);
    expect(find.descendant(of: bar, matching: find.byTooltip(l10n.delete)),
        findsOneWidget);
    // At the bottom: under the note's body, in the screen's lower part.
    final screen = tester.getRect(find.byType(TaskDetailScreen));
    expect(tester.getRect(edit).top,
        greaterThan(tester.getRect(find.textContaining('Abre de 9 a 14')).bottom));
    expect(tester.getRect(edit).center.dy, greaterThan(screen.height * 0.75));
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---- Run 2026-10-19-app, round 1 · P185 (UX-1517, UX-1520, UX-1521) ----

  final es = lookupAppLocalizations(const Locale('es'));

  /// Notas in Spanish at 1× on 360×800, with [notes] and [projects].
  Future<void> openNotes(WidgetTester tester, List<Task> notes,
      {List<TaskListInfo> projects = const []}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container =
        designContainer(tasks: () => _Given(notes), projects: projects);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const NotesScreen())));
    await tester.pumpAndSettle();
  }

  Finder noteRow(String title) => find.ancestor(
      of: find.text(title), matching: find.byType(ListTile));

  testWidgets(
      'UX-1517: a note said in the sheet shows only the words after its title: preguntar por el comedor y por la excursión de primavera, with no leading «:» or space; a note whose words are its title has no preview line',
      (tester) async {
    await openNotes(tester, [
      Task(
          id: 1,
          kind: 'note',
          title: 'Para la reunión del cole',
          priority: 1,
          notes: 'Para la reunión del cole: preguntar por el comedor y por la '
              'excursión de primavera'),
      Task(
          id: 2,
          kind: 'note',
          title: 'Comprar pan',
          priority: 1,
          notes: 'Comprar pan'),
    ]);
    final school = noteRow('Para la reunión del cole');
    expect(school, findsOneWidget);
    final texts = tester
        .widgetList<Text>(find.descendant(of: school, matching: find.byType(Text)))
        .map((text) => text.data)
        .toList();
    expect(texts, [
      'Para la reunión del cole',
      'preguntar por el comedor y por la excursión de primavera',
    ]);
    final bread = noteRow('Comprar pan');
    expect(
        tester
            .widgetList<Text>(
                find.descendant(of: bread, matching: find.byType(Text)))
            .map((text) => text.data)
            .toList(),
        ['Comprar pan'],
        reason: 'no preview line repeating the title');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1520: at 1× an empty Notas shows one help text, Guarda ideas y datos que quieras recordar. Para algo que hacer, usa una tarea., and no search; with one note the search shows',
      (tester) async {
    expect(es.notesEmptyHelp,
        'Guarda ideas y datos que quieras recordar. Para algo que hacer, usa una tarea.');
    expect(lookupAppLocalizations(const Locale('en')).notesEmptyHelp,
        'Keep ideas and things to remember. For something to do, use a task.');
    expect(lookupAppLocalizations(const Locale('ca')).notesEmptyHelp,
        'Desa idees i dades que vulguis recordar. Per a una cosa per fer, fes servir una tasca.');
    await openNotes(tester, []);
    expect(find.text(es.notesEmptyHelp), findsOneWidget);
    expect(find.textContaining('Guarda información'), findsNothing);
    expect(find.textContaining('Escribe o dicta una nota'), findsNothing);
    // One explanation only: besides the empty state's title and line, and
    // Añadir nota, nothing else is written on the page.
    final words = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(ListView), matching: find.byType(Text)))
        .map((text) => text.data)
        .whereType<String>()
        .where((text) =>
            text != es.notes && text != es.notesEmpty && text != es.addNote)
        .toList();
    expect(words, [es.notesEmptyHelp]);
    expect(find.byKey(const ValueKey('note-search')), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await openNotes(tester, [
      Task(id: 1, kind: 'note', title: 'Médico', priority: 1),
    ]);
    expect(find.byKey(const ValueKey('note-search')), findsOneWidget);
    expect(find.text(es.notesEmptyHelp), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1520: a note row with 1 of 3 steps done reads Pasos · 1/3; a note in Casa shows the folder icon before Casa',
      (tester) async {
    expect(es.checklistCount(1, 3), 'Pasos · 1/3');
    await openNotes(tester, [
      Task(
          id: 1,
          kind: 'note',
          title: 'Mudanza',
          priority: 1,
          listId: 'casa',
          checklist: [
            ChecklistItem(title: 'Cajas', completed: true),
            ChecklistItem(title: 'Cinta'),
            ChecklistItem(title: 'Furgoneta'),
          ]),
    ], projects: [
      TaskListInfo(id: 'casa', name: 'Casa', color: 'blue')
    ]);
    final row = noteRow('Mudanza');
    expect(find.descendant(of: row, matching: find.text('Pasos · 1/3')),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('Lista de pasos')),
        findsNothing);
    expect(find.descendant(of: row, matching: find.text('1/3 · Lista de pasos')),
        findsNothing);
    final casa = find.descendant(of: row, matching: find.text('Casa'));
    final folder =
        find.descendant(of: row, matching: find.byIcon(Icons.folder_outlined));
    expect(casa, findsOneWidget);
    expect(folder, findsOneWidget);
    final icon = tester.getRect(folder);
    final name = tester.getRect(casa);
    expect(icon.right, lessThanOrEqualTo(name.left), reason: 'before Casa');
    expect(icon.center.dy, closeTo(name.center.dy, 4), reason: 'same line');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1521: a note’s body is one button for TalkBack, «Tu nota» with its words and the hint Editar nota, and no unnamed text field',
      (tester) async {
    final handle = tester.ensureSemantics();
    expect(es.noteBody, 'Tu nota');
    await openNote(tester);
    final body = find.semantics.byLabel(es.noteBody);
    expect(body, findsOne);
    final data = body.evaluate().single.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.value, contains('Abre de 9 a 14'));
    expect(body.evaluate().single.hintOverrides?.onTapHint, es.editNote);
    expect(
        find.semantics.byPredicate(
            (node) => node.getSemanticsData().flagsCollection.isTextField),
        findsNothing,
        reason: 'no «text field (no label)»');
    // Its tap opens the editor, as a finger's does.
    tester.semantics.tap(body);
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets(
      'UX-1521: a long press on a note’s words still selects them',
      (tester) async {
    await openNote(tester);
    final words = find.textContaining('Abre de 9 a 14');
    // On «Abre», the first word.
    await tester.longPressAt(tester.getTopLeft(words) + const Offset(12, 10));
    await tester.pumpAndSettle();
    final selectable = tester.state<EditableTextState>(find.descendant(
        of: find.byType(SelectableText), matching: find.byType(EditableText)));
    expect(selectable.textEditingValue.selection.isCollapsed, isFalse,
        reason: 'a word is selected');
    expect(find.byType(TaskEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Twelve notes, then each added note gets the next id, as the database does.
class _ManyNotes extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    if (state.hasValue) return;
    state = AsyncData([
      for (var id = 1; id <= 12; id++)
        Task(id: id, kind: 'note', title: 'Nota $id', priority: 1),
    ]);
  }

  @override
  Future<int> addTask(Task task) async {
    final id = state.requireValue
            .fold<int>(0, (max, item) => item.id! > max ? item.id! : max) +
        1;
    state = AsyncData([...state.requireValue, task.copyWith(id: id)]);
    return id;
  }
}

/// Twelve notes in the shared project `group`; each added note gets the
/// next id, as the database does.
class _ProjectNotes extends _ManyNotes {
  @override
  Future<void> loadTasks() async {
    if (state.hasValue) return;
    state = AsyncData([
      for (var id = 1; id <= 12; id++)
        Task(
            id: id,
            kind: 'note',
            title: 'Nota $id',
            priority: 1,
            listId: 'group'),
    ]);
  }
}

class _FailedNotes extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = AsyncError(StateError('Synthetic read failure'), StackTrace.empty);
  }
}

class _NoNotes extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = const AsyncData(<Task>[]);
  }
}

class _AccentNotes extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = AsyncData([
      Task(id: 1, kind: 'note', title: 'Médico', priority: 1,
          notes: 'Análisis de sangre'),
      Task(id: 2, kind: 'note', title: 'Reunió al col·legi', priority: 1),
      Task(id: 3, kind: 'note', title: 'Comprar pan', priority: 1),
    ]);
  }
}

class _Viewer extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = AsyncData([
      Task(
          id: 1,
          kind: 'note',
          title: 'Shared reference',
          priority: 1,
          listId: 'group',
          notes: 'Information')
    ]);
  }
}

class _OneNote extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    if (state.hasValue) return;
    state = AsyncData([
      Task(
          id: 1,
          kind: 'note',
          title: 'Horario del centro de salud',
          priority: 1,
          notes: 'Abre de 9 a 14 entre semana.'),
    ]);
  }
}

/// Exactly [given] on the phone.
class _Given extends DesignTaskNotifier {
  _Given(this.given);
  final List<Task> given;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(given);
  }
}
