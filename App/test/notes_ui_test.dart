import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/note_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('note-search')), 200,
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
    final container = designContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(app(
        container,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    child: const Text('Review'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => ReviewTasksScreen(drafts: [
                                  TaskDraft.fromJson({
                                    'kind': 'note',
                                    'title': 'Reference',
                                    'notes': 'Friday at 17:00',
                                    'priority': 1,
                                    'transcript': 'Friday at 17:00',
                                    'questions': []
                                  })
                                ]))))))));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review note'), findsOneWidget);
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
