import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/project_preferences.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'support/design_fixtures.dart';
import 'support/search_clear.dart';
import 'support/button_label.dart' show loadManrope;
import 'package:agenda/widgets/task_list_picker.dart';

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
                // From 8 projects the sheet has a search (UX-1522).
                TaskListInfo(id: 'home', name: 'Casa'),
                TaskListInfo(id: 'work', name: 'Trabajo'),
                TaskListInfo(id: 'trip', name: 'Viaje'),
                TaskListInfo(id: 'garden', name: 'Huerto'),
                TaskListInfo(id: 'gym', name: 'Gimnasio'),
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

  // ---- Run 2026-10-19-app, round 1 · P184 (UX-1522 f, g) ----

  /// Todos los proyectos in Spanish over [projects], at [scale] on 360×800.
  Future<void> openScope(WidgetTester tester, List<TaskListInfo> projects,
      {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        overrides: [taskListsProvider.overrideWith((ref) async => projects)],
        child: MaterialApp(
            locale: const Locale('es'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const Scaffold(
                body: SafeArea(child: ProjectScopeControl())))));
    await tester.pumpAndSettle();
  }

  for (final (count, search) in [(3, false), (7, false), (8, true)]) {
    testWidgets(
        'UX-1522: the Todos los proyectos sheet with $count projects ${search ? 'has a search' : 'has no search'}',
        (tester) async {
      final es = lookupAppLocalizations(const Locale('es'));
      await openScope(tester, [
        for (var i = 1; i <= count; i++)
          TaskListInfo(id: 'p$i', name: 'Proyecto $i'),
      ]);
      await tester.tap(find.widgetWithText(ActionChip, es.projectsAll));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(
          find.descendant(of: sheet, matching: find.byType(TextField)),
          search ? findsOneWidget : findsNothing);
      expect(
          find.descendant(
              of: sheet, matching: find.widgetWithText(ListTile, 'Proyecto 1')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'UX-1522: at 2× on 360×800 in Spanish, with a shared project, the chip reads Todos los proyectos whole',
      (tester) async {
    // The app's own font, so the label measures as on the phone.
    await tester.runAsync(() async {
      await (FontLoader('Manrope')
            ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
          .load();
    });
    final es = lookupAppLocalizations(const Locale('es'));
    expect(es.projectsAll, 'Todos los proyectos');
    await openScope(tester, [shared, TaskListInfo(id: 'huerto', name: 'Huerto')],
        scale: 2);
    final label = find.descendant(
        of: find.byType(ActionChip), matching: find.text(es.projectsAll));
    expect(label, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
        of: label, matching: find.byType(RichText), matchRoot: true));
    expect(paragraph.didExceedMaxLines, isFalse,
        reason: '«Todos los proyectos» is not cut');
    expect(paragraph.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(paragraph.size.width + 0.5),
        reason: 'it fits its line');
    final rect = tester.getRect(label);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  // ---- P288 (UX-2509): every search clears in one tap ----

  group('P288 · «Todos los proyectos» sheet search clears in one tap', () {
    const names = [
      'Col·legi', 'Dentista', 'Compras', 'Casa', 'Trabajo', 'Viaje',
      'Huerto', 'Gimnasio',
    ];

    Future<ProviderContainer> show(WidgetTester tester, String language) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // From 8 projects the sheet has a search (UX-1522).
      final container = ProviderContainer(overrides: [
        taskListsProvider.overrideWith((ref) async =>
            [for (final name in names) TaskListInfo(id: name, name: name)]),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: Locale(language),
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                  body: SafeArea(child: ProjectScopeControl())))));
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(language));
      await tester.tap(find.widgetWithText(ActionChip, l.projectsAll));
      await tester.pumpAndSettle();
      return container;
    }

    Finder sheet() => find.byType(BottomSheet);
    Finder row(String name) => find.descendant(
        of: sheet(), matching: find.widgetWithText(ListTile, name));

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
          'UX-2509: ($language, 1×, 360×800) the «Todos los proyectos» sheet: an empty search has no ✕; typing «dent» shows a 48 dp ✕ read as «Borrar búsqueda»; one tap clears it, every project comes back and the sheet stays open',
          (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final semantics = tester.ensureSemantics();
        final container = await show(tester, language);
        final field = searchField(within: sheet());
        expect(field, findsOneWidget);
        expectNoClear(field, l);

        await tester.enterText(field, 'dent');
        await tester.pumpAndSettle();
        expect(row('Dentista'), findsOneWidget);
        expect(row('Compras'), findsNothing);
        expectClear(tester, field, l);

        await tapClear(tester, field, l);
        expect(sheet(), findsOneWidget, reason: 'clearing keeps the sheet');
        expect(searchText(tester, field), isEmpty);
        expect(row('Dentista'), findsOneWidget);
        expect(row('Compras', ), findsOneWidget);
        expectNoClear(field, l);
        expect(container.read(projectScopeProvider).projectId, isNull,
            reason: 'clearing picks nothing');
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }

    testWidgets(
        'UX-2509: (es, 1×, 360×800) the sheet with no match: the ✕ is in view and brings the projects back',
        (tester) async {
      final es = lookupAppLocalizations(const Locale('es'));
      final semantics = tester.ensureSemantics();
      await show(tester, 'es');
      final field = searchField(within: sheet());
      await tester.enterText(field, 'zanahorias');
      await tester.pumpAndSettle();
      expect(find.text(es.projectsNoneFound), findsOneWidget);
      expectClear(tester, field, es);

      await tapClear(tester, field, es);
      expect(find.text(es.projectsNoneFound), findsNothing);
      expect(row('Dentista'), findsOneWidget);
      expectNoClear(field, es);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  // ---- UX loop 2026-10-28-app, round 1 · P294 (UX-2514): pickers mark the
  // current choice with ✓, not colour alone ----
  group('P294 · pickers mark the current choice with ✓', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final casa = TaskListInfo(id: 'casa', name: 'Casa');
    final trabajo = TaskListInfo(id: 'trabajo', name: 'Trabajo');
    final mates = TaskListInfo(
      id: 'mates',
      name: 'Matemáticas',
      shared: true,
      role: 'owner',
      ownerId: 1,
      notifications: 'assigned',
      people: const [
        ProjectMember(id: 1, name: 'Miki', role: 'owner'),
        ProjectMember(id: 2, name: 'Ana', role: 'editor'),
      ],
    );

    Finder sheet() => find.byType(BottomSheet);
    Finder checks() => find.descendant(
      of: sheet(),
      matching: find.byIcon(Icons.check_rounded),
    );

    /// The only ✓ in the open sheet is on the row reading [label].
    void expectOnlyCheckOn(WidgetTester tester, String label) {
      expect(checks(), findsOneWidget, reason: 'one ✓, on «$label»');
      final row = find.ancestor(of: checks(), matching: find.byType(ListTile));
      expect(
        find.descendant(of: row.first, matching: find.text(label)),
        findsOneWidget,
        reason: 'the ✓ is on «$label»',
      );
      expect(tester.widget<ListTile>(row.first).selected, isTrue);
    }

    Future<Task Function()> pick(WidgetTester tester, Task initial) async {
      var task = initial;
      final api = OfflineApiClient();
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
            taskListsProvider.overrideWith(
              (ref) async => [casa, trabajo, mates],
            ),
            groupsProvider.overrideWith((ref) async => []),
            taskRepositoryProvider.overrideWithValue(MemoryTasks()),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, change) => TaskAssignmentPicker(
                  task: task,
                  lockShared: true,
                  onChanged: (value) => change(() => task = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return () => task;
    }

    for (final (listId, chip, selected) in [
      ('casa', 'Casa', 'Casa'),
      (null, es.noList, es.noList),
    ]) {
      testWidgets(
        'UX-2514: the project sheet (task in ${listId ?? 'no project'}) has a drag handle, its «Proyecto» title is a heading, and only «$selected» shows a ✓',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await pick(
            tester,
            Task(id: 1, title: 'Comprar pan', priority: 1, listId: listId),
          );
          await tester.tap(find.widgetWithText(ActionChip, chip));
          await tester.pumpAndSettle();
          expect(sheet(), findsOneWidget);
          expect(tester.widget<BottomSheet>(sheet()).showDragHandle, isTrue);
          final title = find.descendant(
            of: sheet(),
            matching: find.text(es.list),
          );
          expect(title, findsOneWidget);
          expect(es.list, 'Proyecto');
          expect(
            find.ancestor(of: title, matching: find.byType(ListTile)),
            findsNothing,
            reason: 'not drawn as a plain row',
          );
          expect(
            tester.getSemantics(title).flagsCollection.isHeader,
            isTrue,
          );
          expectOnlyCheckOn(tester, selected);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2514: «Todos los proyectos»: only the scope chosen shows a ✓, first «Todos los proyectos», then «Casa» once chosen',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            taskListsProvider.overrideWith((ref) async => [casa, trabajo]),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SafeArea(child: ProjectScopeControl()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionChip, es.projectsAll));
        await tester.pumpAndSettle();
        expectOnlyCheckOn(tester, es.projectsAll);
        await tester.tap(
          find.descendant(
            of: sheet(),
            matching: find.widgetWithText(ListTile, 'Casa'),
          ),
        );
        await tester.pumpAndSettle();
        expect(container.read(projectScopeProvider).projectId, 'casa');
        await tester.tap(find.widgetWithText(ActionChip, 'Casa'));
        await tester.pumpAndSettle();
        expectOnlyCheckOn(tester, 'Casa');
        expect(tester.takeException(), isNull);
      },
    );

    for (final (notifications, label) in [
      ('all', es.updatesAll),
      ('assigned', es.updatesAssigned),
      ('muted', es.updatesMuted),
    ]) {
      testWidgets(
        'UX-2514: «Novedades del proyecto» set to $notifications: only «$label» shows a ✓',
        (tester) async {
          final project = TaskListInfo(
            id: 'mates',
            name: 'Matemáticas',
            shared: true,
            notifications: notifications,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                taskRepositoryProvider.overrideWithValue(MemoryTasks()),
              ],
              child: MaterialApp(
                locale: const Locale('es'),
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) => TextButton(
                      onPressed: () =>
                          showProjectPreferences(context, ref, project),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text(es.projectNotifications), findsOneWidget);
          expectOnlyCheckOn(tester, label);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final (assignment, assignee, label) in [
      ('member', 2, 'Ana'),
      ('group', null, es.assignedToGroup),
    ]) {
      testWidgets(
        'UX-2514: «¿Quién es responsable?» for a task ${assignment == 'group' ? 'for everyone' : 'given to Ana'}: only its row shows a ✓',
        (tester) async {
          await pick(
            tester,
            Task(
              id: 1,
              title: 'Terminar la presentación',
              priority: 1,
              listId: 'mates',
              assignment: assignment,
              assigneeId: assignee,
              assigneeName: assignee == null ? null : 'Ana',
            ),
          );
          final chip = find.descendant(
            of: find.byType(TaskAssignmentPicker),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ActionChip &&
                  (widget.avatar as Icon?)?.icon !=
                      Icons.folder_outlined &&
                  ((widget.avatar as Icon?)?.icon == Icons.groups_outlined ||
                      (widget.avatar as Icon?)?.icon == Icons.person_outline),
            ),
          );
          expect(chip, findsOneWidget);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: sheet(),
              matching: find.text(es.assignmentChoose),
            ),
            findsOneWidget,
          );
          expect(checks(), findsOneWidget);
          final row = find.ancestor(
            of: checks(),
            matching: find.byType(ListTile),
          );
          expect(tester.widget<ListTile>(row.first).selected, isTrue);
          expect(
            find.descendant(
              of: row.first,
              matching: find.textContaining(label),
            ),
            findsOneWidget,
            reason: 'the ✓ is on «$label»',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // ---- UX loop 2026-10-28-app, round 2 · P311 (UX-2639): the project
  // sheet shows its last row whole ----
  group('P311 · project sheet height', () {
    final es = lookupAppLocalizations(const Locale('es'));
    List<TaskListInfo> projects(int count) => [
      for (var i = 0; i < count; i++)
        i < 2
            ? TaskListInfo(
                id: 'p$i',
                name: 'Proyecto compartido $i',
                shared: true,
                role: 'owner',
                ownerId: 1,
                groupName: 'Familia',
              )
            : TaskListInfo(id: 'p$i', name: 'Proyecto $i'),
    ];

    /// The project sheet, opened on 360×800 at [textScale], with [lists].
    Future<void> openSheet(
      WidgetTester tester,
      List<TaskListInfo> lists, {
      double textScale = 1,
    }) async {
      await loadManrope();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = OfflineApiClient();
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
            taskListsProvider.overrideWith((ref) async => lists),
            groupsProvider.overrideWith((ref) async => []),
            taskRepositoryProvider.overrideWithValue(MemoryTasks()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(taskListsProvider);
                  return Center(
                    child: TextButton(
                      onPressed: () => chooseTaskList(context, ref),
                      child: const Text('open'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    }

    Finder newProject() => find.ancestor(
      of: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(es.newList),
      ),
      matching: find.byType(ListTile),
    );
    Finder list() => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );

    bool contains(Rect outer, Rect inner) =>
        inner.top >= outer.top - 0.5 &&
        inner.bottom <= outer.bottom + 0.5 &&
        inner.left >= outer.left - 0.5 &&
        inner.right <= outer.right + 0.5;

    testWidgets(
      'UX-2639: five projects, ES 1× on 360×800: «Nuevo proyecto» is a whole 360 × 56 dp row inside the sheet, with no scrolling',
      (tester) async {
        await openSheet(tester, projects(5));
        final row = newProject();
        expect(row, findsOneWidget);
        final rect = tester.getRect(row);
        expect(rect.width, closeTo(360, 0.5));
        expect(rect.height, greaterThanOrEqualTo(56));
        expect(
          contains(tester.getRect(list()), rect),
          isTrue,
          reason: 'whole in the list: $rect in ${tester.getRect(list())}',
        );
        expect(
          contains(tester.getRect(find.byType(BottomSheet)), rect),
          isTrue,
        );
        expect(rect.bottom, lessThanOrEqualTo(800));
        expect(
          tester.state<ScrollableState>(list()).position.pixels,
          0,
          reason: 'seen without scrolling',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2639: one project, ES 1×: the sheet hugs its content, shorter than half the screen',
      (tester) async {
        await openSheet(tester, projects(5).sublist(4));
        final sheet = tester.getRect(find.byType(BottomSheet));
        expect(sheet.height, lessThan(400), reason: 'sheet $sheet');
        expect(sheet.bottom, closeTo(800, 0.5));
        expect(contains(sheet, tester.getRect(newProject())), isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2639: twelve projects, ES 2× on 360×800: the list is no taller than 70% of the screen and scrolls to «Nuevo proyecto»',
      (tester) async {
        await openSheet(tester, projects(12), textScale: 2);
        final viewport = tester.getRect(list());
        expect(
          viewport.height,
          lessThanOrEqualTo(800 * .7 + 0.5),
          reason: 'list $viewport',
        );
        final sheet = tester.getRect(find.byType(BottomSheet));
        // Room above it: the screen isn't covered to the top.
        expect(sheet.top, greaterThan(0), reason: 'sheet $sheet');
        await tester.scrollUntilVisible(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(es.newList),
          ),
          200,
          scrollable: list(),
        );
        await tester.pumpAndSettle();
        expect(
          contains(tester.getRect(list()), tester.getRect(newProject())),
          isTrue,
          reason: '«Nuevo proyecto» whole in view once scrolled',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
