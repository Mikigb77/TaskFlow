import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task.dart';
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

void main() {
  testWidgets(
      'note create, search and links work at 2x text in light/dark and English/Spanish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in ['en', 'es']) {
      for (final dark in [false, true]) {
        final container = designContainer();
        await tester.pumpWidget(app(container, const NotesScreen(),
            dark: dark, language: language));
        await tester.pumpAndSettle();
        expect(find.text('Doctor appointment'), findsNothing);
        await tester.tap(find.widgetWithText(
            FilledButton, language == 'en' ? 'New note' : 'Nueva nota'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('task-title')),
            'Reference Friday at 17:00');
        await tester.ensureVisible(find.byKey(const ValueKey('note-body')));
        await tester.enterText(find.byKey(const ValueKey('note-body')),
            'Opening hours and directions https://example.org/long-reference-information-for-visiting');
        expect(find.byKey(const ValueKey('task-date')), findsNothing);
        expect(find.byKey(const ValueKey('schedule-suggestion')), findsNothing);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();
        final note = container
            .read(taskProvider)
            .requireValue
            .singleWhere((item) => item.isNote);
        expect(note.dueDate, isNull);
        expect(note.reminderMinutes, -1);
        expect(find.byType(NotesScreen), findsOneWidget);
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
    final container = designContainer(tasks: _ManyNotes.new);
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
      await tester.tap(find.widgetWithText(FilledButton, l10n.newNote));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('task-title')), title);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
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

  /// Notas scrolled down, then `Nueva nota` saves [title]: returns the
  /// list's scroll offset before and after.
  Future<(double, double)> saveScrolledDown(
      WidgetTester tester, String title) async {
    final l10n = lookupAppLocalizations(const Locale('es'));
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(list).position.pixels;
    expect(before, greaterThan(0), reason: 'scrolled down');
    await tester.tap(find.widgetWithText(FilledButton, l10n.newNote));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('task-title')), title);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
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
      'UX-459: on Notas filtered to a view-only project, scrolled down, a note saved with Nueva nota (to Personal) leaves the scroll where it was and lights no row',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = designContainer(tasks: _ProjectNotes.new, projects: [
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
    final container = designContainer(tasks: _ManyNotes.new);
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
      'UX-313: in a project’s notes, Dictar una nota opens capture with that projectId',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final messenger = tester.binding.defaultBinaryMessenger;
    const timezone = MethodChannel('flutter_timezone');
    messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
    addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(l10n.recordNote, 'Dictar una nota');
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
    await tester.tap(find.widgetWithText(OutlinedButton, l10n.recordNote));
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
    await tester.tap(find.widgetWithText(FilledButton, l10n.newNote));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('task-title'));
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
      'UX-337: the note-versus-task help shows only when there are no notes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final l10n = lookupAppLocalizations(const Locale('es'));
    final none = designContainer(tasks: _NoNotes.new);
    await tester.pumpWidget(app(none, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.notesHelp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    none.dispose();
    // Tasks only, still no notes.
    final tasksOnly = designContainer();
    await tester.pumpWidget(app(tasksOnly, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.notesHelp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    tasksOnly.dispose();
    final some = designContainer(tasks: _AccentNotes.new);
    addTearDown(some.dispose);
    await tester.pumpWidget(app(some, const NotesScreen(), language: 'es'));
    await tester.pumpAndSettle();
    expect(find.text('Médico'), findsOneWidget);
    expect(find.text(l10n.notesHelp, skipOffstage: false), findsNothing);
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
