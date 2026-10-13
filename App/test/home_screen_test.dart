import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

final _project = TaskListInfo(id: 'school', name: 'Col·legi');

Widget _app(ProviderContainer container, Widget home, String language) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );

void main() {
  for (final language in ['es', 'en']) {
    for (final (name, screen) in [
      ('Tareas', const HomeScreen()),
      ('a project page', const HomeScreen(listId: 'school', isRoot: false)),
    ]) {
      testWidgets(
        'UX-428: an empty list on $name shows the Tareas tab’s check_box_outlined icon ($language)',
        (tester) async {
          final l10n = lookupAppLocalizations(Locale(language));
          final container = designContainer(
            tasks: _NoTasks.new,
            projects: [_project],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(_app(container, screen, language));
          await tester.pumpAndSettle();
          final empty = find.byType(EmptyState);
          expect(empty, findsOneWidget);
          expect(
            find.descendant(of: empty, matching: find.text(l10n.freshStart)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: empty,
              matching: find.byIcon(Icons.check_box_outlined),
            ),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.checklist_rounded), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-428: a project page’s Notas button shows the Notas tab’s description_outlined icon ($language)',
      (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        final container = designContainer(projects: [_project]);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _app(
            container,
            const HomeScreen(listId: 'school', isRoot: false),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final button = find.ancestor(
          of: find.text(l10n.notes),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        );
        expect(button, findsOneWidget);
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(Icons.description_outlined),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.notes_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _NoTasks extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = const AsyncData(<Task>[]);
  }
}
