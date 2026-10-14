import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'support/design_fixtures.dart';

void main() {
  testWidgets(
      'UX-303: the project picker search ignores accents and picks the match '
      '(es/ca, 2x text, 320 dp, both themes)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in ['es', 'ca']) {
      for (final dark in [false, true]) {
        final l10n = lookupAppLocalizations(Locale(language));
        final container = ProviderContainer(overrides: [
          taskListsProvider.overrideWith((ref) async => [
                TaskListInfo(id: 'school', name: 'Col·legi'),
                TaskListInfo(id: 'doctor', name: 'Médico'),
                TaskListInfo(id: 'food', name: 'Compras'),
              ]),
        ]);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                locale: Locale(language),
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: const Scaffold(
                    body: SafeArea(child: ProjectScopeControl())))));
        await tester.pumpAndSettle();
        final reason = '$language dark=$dark';
        await tester.tap(find.widgetWithText(ActionChip, l10n.projectsAll));
        await tester.pumpAndSettle();
        final search = find.widgetWithText(TextField, l10n.projectsFind);
        final sheet = find.byType(BottomSheet);
        // At 2x text the sheet's list is short: scroll it to reach a row.
        final results = find
            .descendant(
                of: find.descendant(of: sheet, matching: find.byType(ListView)),
                matching: find.byType(Scrollable))
            .first;
        Future<void> reveal(Finder row) =>
            tester.scrollUntilVisible(row, 60, scrollable: results);
        Future<void> toEnd() async {
          await tester.drag(results, const Offset(0, -3000));
          await tester.pumpAndSettle();
        }

        await tester.enterText(search, 'medico');
        await tester.pumpAndSettle();
        final doctor = find.descendant(
            of: sheet, matching: find.widgetWithText(ListTile, 'Médico'));
        await reveal(doctor);
        expect(doctor, findsOneWidget, reason: reason);
        await toEnd();
        expect(find.descendant(of: sheet, matching: find.text('Compras')),
            findsNothing);
        expect(find.descendant(of: sheet, matching: find.text('Col·legi')),
            findsNothing);
        expect(find.text(l10n.projectsNoneFound), findsNothing);

        await tester.enterText(search, 'dentista');
        await tester.pumpAndSettle();
        expect(find.text(l10n.projectsNoneFound), findsOneWidget,
            reason: reason);

        await tester.enterText(search, 'collegi');
        await tester.pumpAndSettle();
        final match = find.descendant(
            of: sheet, matching: find.widgetWithText(ListTile, 'Col·legi'));
        await reveal(match);
        expect(match, findsOneWidget, reason: reason);
        await toEnd();
        expect(find.descendant(of: sheet, matching: find.text('Médico')),
            findsNothing);
        await reveal(match);
        await tester.tap(match);
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(container.read(projectScopeProvider).projectId, 'school');
        expect(find.widgetWithText(ActionChip, 'Col·legi'), findsOneWidget,
            reason: reason);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
  });

  // ---- P13 (UX-316): one word for "the other people" ----

  final shared = TaskListInfo(
      id: 'casa',
      name: 'Casa',
      version: 1,
      shared: true,
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Ana', role: 'editor'),
      ]);

  Widget localized(Widget child, String language) => MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SafeArea(child: child)));

  for (final (language, all) in [('es', 'Todas'), ('ca', 'Totes'), ('en', 'All')]) {
    testWidgets('UX-316: the scope chips read For me and $all ($language)',
        (tester) async {
      final l10n = lookupAppLocalizations(Locale(language));
      expect(l10n.forTeam, all);
      await tester.pumpWidget(ProviderScope(
          overrides: [taskListsProvider.overrideWith((ref) async => [shared])],
          child: localized(const ProjectScopeControl(), language)));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, l10n.forMe), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, l10n.forTeam), findsOneWidget);
      expect(find.text('Equipo'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (language, everyone) in [
    ('es', 'Todos'),
    ('ca', 'Tothom'),
    ('en', 'Everyone'),
  ]) {
    testWidgets(
        'UX-316: a task for the whole project reads $everyone ($language)',
        (tester) async {
      final l10n = lookupAppLocalizations(Locale(language));
      expect(l10n.assignedToGroup, everyone);
      final api = OfflineApiClient();
      addTearDown(api.close);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
            taskListsProvider.overrideWith((ref) async => [shared]),
          ],
          child: localized(
              TaskAssignmentPicker(
                  task: Task(
                      title: 'Comprar pan',
                      priority: 1,
                      listId: 'casa',
                      assignment: 'group'),
                  onChanged: (_) {}),
              language)));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, everyone), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, everyone));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.text(everyone)),
          findsOneWidget);
      expect(find.text('Todo el grupo'), findsNothing);
      expect(find.text('Tot el grup'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  // ---- Round 1 (b9) · P24 (UX-429): the sheet stays above the keyboard ----

  for (final language in ['es', 'ca']) {
    for (final dark in [false, true]) {
      testWidgets(
          'UX-429: at 320×568, 2× text and a 280 dp keyboard, typing a project’s name in Todos los proyectos leaves its row and the search above the keyboard ($language, dark=$dark)',
          (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.reset);
        final container = ProviderContainer(overrides: [
          taskListsProvider.overrideWith((ref) async => [
                for (final name in [
                  'Casa',
                  'Trabajo',
                  'Compras',
                  'Gimnasio',
                  'Viajes',
                  'Lectura',
                  'Col·legi',
                  'Jardín',
                  'Coche',
                  'Médico',
                ])
                  TaskListInfo(id: name, name: name),
              ]),
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                locale: Locale(language),
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: const Scaffold(
                    resizeToAvoidBottomInset: false,
                    body: SafeArea(child: ProjectScopeControl())))));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionChip, l10n.projectsAll));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        final search = find.descendant(
            of: sheet, matching: find.widgetWithText(TextField, l10n.projectsFind));
        expect(search, findsOneWidget);
        await tester.enterText(search, 'medico');
        await tester.pumpAndSettle();
        const keyboardTop = 568.0 - 280;
        final row = find.descendant(
            of: sheet, matching: find.widgetWithText(ListTile, 'Médico'));
        expect(row, findsOneWidget);
        final rowRect = tester.getRect(row);
        final searchRect = tester.getRect(search);
        expect(searchRect.top, greaterThanOrEqualTo(0));
        expect(searchRect.bottom, lessThanOrEqualTo(keyboardTop),
            reason: 'the search shows above the keyboard: $searchRect');
        expect(rowRect.top, greaterThanOrEqualTo(0));
        expect(rowRect.bottom, lessThanOrEqualTo(keyboardTop),
            reason: 'the match shows above the keyboard: $rowRect');
        expect(row.hitTestable(), findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(container.read(projectScopeProvider).projectId, 'Médico');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
