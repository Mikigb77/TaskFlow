// Round 1 of 2026-10-13-app (b9), P25 (UX-407, UX-321) and P27 (UX-320):
// the header's Activity button shows only to people who share something,
// with a people icon; Activity rows lead with who did what; a failed load
// says so and offers Reintentar.
import 'dart:async';
import 'dart:io';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/screens/activity_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda/models/task.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/task_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/design_fixtures.dart';
import 'support/hanging_sync.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));

  Widget app(
    ProviderContainer container,
    Widget home, {
    String language = 'es',
    double textScale = 1,
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: textScale == 1
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
      home: home,
    ),
  );

  const header = Scaffold(
    appBar: CustomAppBar(title: 'Calendario', isRoot: true),
    body: SizedBox(),
  );

  test(
    'UX-407: the Activity button is called Updates (UX-1524) in each language',
    () {
      expect(es.groupActivity, 'Novedades');
      expect(
        lookupAppLocalizations(const Locale('en')).groupActivity,
        'Updates',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).groupActivity,
        'Novetats',
      );
    },
  );

  testWidgets(
    'UX-407: an account with no group and no shared project has no Activity button in the header',
    (tester) async {
      final container = designContainer(
        projects: [TaskListInfo(id: 'casa', name: 'Casa')],
        overrides: [collaborationUnreadProvider.overrideWith((ref) async => 2)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(app(container, header));
      await tester.pumpAndSettle();
      expect(find.byTooltip(es.groupActivity), findsNothing);
      expect(find.byTooltip(es.activity), findsNothing);
      expect(find.byIcon(Icons.groups_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      // The account button stays.
      expect(find.byTooltip(es.account), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-407: with a shared project the header button shows a people icon, the tooltip Novedades and the unread badge, and opens Activity',
    (tester) async {
      final container = designContainer(
        projects: [
          TaskListInfo(id: 'casa', name: 'Casa', version: 2, shared: true),
        ],
        overrides: [
          collaborationUnreadProvider.overrideWith((ref) async => 3),
          collaborationActivityProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(app(container, header));
      await tester.pumpAndSettle();
      final button = find.byTooltip(es.groupActivity);
      expect(button, findsOneWidget);
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.groups_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.notifications_outlined),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: button, matching: find.text('3')),
        findsOneWidget,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX-321: who did what, then where and when ----

  final created = DateTime.utc(2026, 10, 12, 11);

  Future<ProviderContainer> openActivity(
    WidgetTester tester,
    Future<List<Map<String, dynamic>>> Function() items, {
    String language = 'es',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      overrides: [
        collaborationActivityProvider.overrideWith((ref) => items()),
        collaborationUnreadProvider.overrideWith((ref) async => 0),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      app(container, const ActivityScreen(), language: language),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'UX-321: an activity row reads Ana ha completado: Comprar pan with Física · 12 oct; the unread row is bold and says No leída, the read one neither',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openActivity(
        tester,
        () async => [
          {
            'id': 'n1',
            'action': 'completed',
            'actor_name': 'Ana',
            'task_title': 'Comprar pan',
            'project_name': 'Física',
            'created_at': created.toIso8601String(),
            'read_at': null,
          },
          {
            'id': 'n2',
            'action': 'created',
            'actor_name': 'Luis',
            'task_title': 'Repasar tema 3',
            'project_name': 'Física',
            'created_at': created.toIso8601String(),
            'read_at': created.toIso8601String(),
          },
        ],
      );
      final context = tester.element(find.byType(ActivityScreen));
      final date = context.shortDate(created.toLocal());
      expect(date, '12 oct');

      final unread = find.text('Ana ha completado: Comprar pan');
      expect(unread, findsOneWidget);
      expect(find.text('Física · 12 oct'), findsNWidgets(2));
      expect(tester.widget<Text>(unread).style?.fontWeight, FontWeight.w700);
      expect(tester.getSemantics(unread).label, contains(es.activityUnread));

      final read = find.text('Luis ha creado: Repasar tema 3');
      expect(read, findsOneWidget);
      expect(
        tester.widget<Text>(read).style?.fontWeight,
        isNot(FontWeight.w700),
      );
      expect(
        tester.getSemantics(read).label,
        isNot(contains(es.activityUnread)),
      );

      // No help line on top of a list.
      expect(find.text(es.activityHelp), findsNothing);
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  test('UX-321: every action reads as a whole sentence in each language', () {
    for (final language in ['es', 'en', 'ca']) {
      final l = lookupAppLocalizations(Locale(language));
      for (final action in [
        'created',
        'assigned',
        'unassigned',
        'completed',
        'reopened',
        'deleted',
        'shared',
        'updated',
      ]) {
        final text = l.activityEntry(action, 'Ana', 'Comprar pan');
        expect(text, startsWith('Ana '), reason: '$language $action');
        expect(text, endsWith(': Comprar pan'), reason: '$language $action');
      }
    }
    expect(
      es.activityEntry('completed', 'Ana', 'Comprar pan'),
      'Ana ha completado: Comprar pan',
    );
    expect(
      lookupAppLocalizations(
        const Locale('en'),
      ).activityEntry('completed', 'Ana', 'Buy bread'),
      'Ana completed: Buy bread',
    );
    expect(
      lookupAppLocalizations(
        const Locale('ca'),
      ).activityEntry('completed', 'Ana', 'Comprar pa'),
      'Ana ha completat: Comprar pa',
    );
    expect(es.activityUnread, 'No leída');
    expect(lookupAppLocalizations(const Locale('en')).activityUnread, 'Unread');
    expect(
      lookupAppLocalizations(const Locale('ca')).activityUnread,
      'No llegida',
    );
  });

  testWidgets('UX-321: an empty Activity says its sentence once', (
    tester,
  ) async {
    await openActivity(tester, () async => []);
    expect(find.text(es.activityEmpty), findsOneWidget);
    expect(find.text(es.activityHelp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---- UX-320: a failed load says so, with Reintentar ----

  testWidgets(
    'UX-320: a failed Activity load shows No se ha podido cargar. Revisa la conexión. and Reintentar, which loads again',
    (tester) async {
      expect(es.loadFailed, 'No se ha podido cargar. Revisa la conexión.');
      var calls = 0;
      await openActivity(tester, () async {
        calls++;
        if (calls == 1) throw ApiException(0, 'offline');
        return [];
      });
      expect(find.text(es.loadFailed), findsOneWidget);
      expect(find.text(es.groupActionError), findsNothing);
      final retry = find.widgetWithText(TextButton, es.retry);
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(es.loadFailed), findsNothing);
      expect(find.text(es.activityEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 (b9) · P115 (UX-628): the button and the screen share a name ----

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-628: the header’s Novedades button opens a screen titled with the same name ($language)',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final container = designContainer(
          projects: [
            TaskListInfo(id: 'casa', name: 'Casa', version: 2, shared: true),
          ],
          overrides: [
            collaborationUnreadProvider.overrideWith((ref) async => 0),
            collaborationActivityProvider.overrideWith((ref) async => []),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(app(container, header, language: language));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(l.groupActivity));
        await tester.pumpAndSettle();
        final screen = find.byType(ActivityScreen);
        expect(screen, findsOneWidget);
        final bar = find.descendant(of: screen, matching: find.byType(AppBar));
        expect(
          find.descendant(of: bar, matching: find.text(l.groupActivity)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: bar, matching: find.text(l.activity)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'UX-628: the screen’s title reads as the plan says in each language',
    () {
      expect(es.groupActivity, 'Novedades');
      expect(
        lookupAppLocalizations(const Locale('en')).groupActivity,
        'Updates',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).groupActivity,
        'Novetats',
      );
    },
  );

  testWidgets(
    'UX-628: at 2x text on 320x568 in Catalan the Activity screen’s app bar shows Novetats without overflow',
    (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = designContainer(
        overrides: [
          collaborationActivityProvider.overrideWith((ref) async => []),
          collaborationUnreadProvider.overrideWith((ref) async => 0),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        app(container, const ActivityScreen(), language: 'ca'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.text(ca.groupActivity),
      );
      expect(title, findsOneWidget);
      final rect = tester.getRect(title);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(
        rect.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-19-app, round 1 · P183 (UX-1514, UX-1524, UX-1510) ----

  Map<String, dynamic> assigned({String? name, bool? you}) => {
    'id': 'n-${name ?? you ?? 'old'}',
    'action': 'assigned',
    'actor_name': 'Paul',
    'task_title': 'Reservar el autobús',
    'project_name': 'Excursión',
    'created_at': created.toIso8601String(),
    'read_at': created.toIso8601String(),
    if (name != null || you != null) 'assignee_name': name,
    if (you != null) 'assignee_is_you': you,
  };

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-1514: ($language) an assignment says who has it now: «you» when assignee_is_you, the name with assignee_name, and today’s sentence without either',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final (you, ana, old) = switch (language) {
          'es' => (
            'Paul te ha asignado: Reservar el autobús',
            'Paul ha asignado a Ana: Reservar el autobús',
            'Paul ha cambiado el responsable de: Reservar el autobús',
          ),
          'en' => (
            'Paul assigned you: Reservar el autobús',
            'Paul assigned Ana: Reservar el autobús',
            'Paul changed who’s responsible for: Reservar el autobús',
          ),
          _ => (
            'Paul t’ha assignat: Reservar el autobús',
            'Paul ha assignat Ana: Reservar el autobús',
            'Paul ha canviat el responsable de: Reservar el autobús',
          ),
        };
        expect(l.activityAssignedYou('Paul', 'Reservar el autobús'), you);
        expect(l.activityAssignedTo('Paul', 'Ana', 'Reservar el autobús'), ana);
        expect(l.activityEntry('assigned', 'Paul', 'Reservar el autobús'), old);
        await openActivity(
          tester,
          () async => [
            // Assigned to this account, with its name too: «you» wins.
            assigned(name: 'María', you: true),
            assigned(name: 'Ana', you: false),
            // Everyone's or nobody's now, or an older server: as before.
            assigned(you: false),
            assigned(),
          ],
          language: language,
        );
        expect(find.text(you), findsOneWidget);
        expect(find.text(ana), findsOneWidget);
        expect(find.text(old), findsNWidgets(2));
        expect(find.textContaining('María'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1524: a task’s history says Ha quitado el responsable for an unassigned entry, as Activity does',
    (tester) async {
      expect(es.activityUnassigned, 'Ha quitado el responsable');
      expect(
        lookupAppLocalizations(const Locale('en')).activityUnassigned,
        'Removed the assignee',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).activityUnassigned,
        'Ha tret el responsable',
      );
      final container = designContainer(
        overrides: [
          taskHistoryProvider(1).overrideWith(
            (ref) async => [
              {
                'action': 'unassigned',
                'actor_name': 'Ana',
                'created_at': created.toIso8601String(),
              },
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        app(container, const Scaffold(body: TaskActivity(taskId: 1))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.activity));
      await tester.pumpAndSettle();
      expect(find.text(es.activityUnassigned), findsOneWidget);
      expect(find.text(es.assignmentNeeded), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('UX-1510: an Activity tap answers at once', () {
    late Directory directory;
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      // The phone's tasks, in a temporary folder.
      directory = await Directory.systemTemp.createTemp('taskflow-activity-');
      await databaseFactory.setDatabasesPath(directory.path);
    });
    tearDown(() async {
      await TaskDatabase().close();
      await directory.delete(recursive: true);
    });

    Map<String, dynamic> completed(String taskId) => {
      'id': 'n-$taskId',
      'action': 'completed',
      'actor_name': 'Ana',
      'task_id': taskId,
      'task_title': 'Review the new designs',
      'project_name': 'Física',
      'created_at': created.toIso8601String(),
      'read_at': null,
    };

    /// Puts task [id] on the phone as [syncId]; a test may call it while a
    /// sync waits, before completing `tasks.sync`.
    Future<void> insert(
      WidgetTester tester, {
      required int id,
      required String syncId,
      String title = 'Review the new designs',
    }) => tester.runAsync(() async {
      final db = await TaskDatabase().database;
      await db.insert('tasks', {
        ...Task(id: id, title: title, priority: 2).toMap(),
        'owner_key': MemoryTasks().ownerKey,
        'sync_id': syncId,
      });
    });

    /// Activity with [item], over tasks whose sync completes only when the
    /// test completes `tasks.sync`, and read receipts that never complete;
    /// the phone has task 2 as `srv-2`. [others] follow [item] in the list.
    Future<(HangingSyncTasks, _HangingApi)> open(
      WidgetTester tester,
      Map<String, dynamic> item, {
      List<Map<String, dynamic>> others = const [],
      String language = 'es',
      double textScale = 1,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await insert(tester, id: 2, syncId: 'srv-2');
      final tasks = HangingSyncTasks();
      final api = _HangingApi();
      final container = designContainer(
        tasks: () => tasks,
        api: api,
        overrides: [
          collaborationActivityProvider.overrideWith(
            (ref) async => [item, ...others],
          ),
          collaborationUnreadProvider.overrideWith((ref) async => 1),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        app(
          container,
          const ActivityScreen(),
          language: language,
          textScale: textScale,
        ),
      );
      await tester.pumpAndSettle();
      return (tasks, api);
    }

    /// Frames, with real time for the phone's database, until [done].
    Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 50 && !done(); i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets(
      'with a sync that never completes, tapping an entry opens its task',
      (tester) async {
        final (tasks, api) = await open(tester, completed('srv-2'));
        await tester.tap(
          find.text('Ana ha completado: Review the new designs'),
        );
        final detail = find.byType(TaskDetailScreen);
        await settleUntil(tester, () => detail.evaluate().isNotEmpty);
        expect(detail, findsOneWidget);
        expect(tester.widget<TaskDetailScreen>(detail).taskId, 2);
        expect(
          find.descendant(
            of: detail,
            matching: find.text('Review the new designs'),
          ),
          findsWidgets,
        );
        expect(tasks.syncs, greaterThan(0), reason: 'the sync runs behind');
        expect(api.reads, [
          'notifications/n-srv-2/read/',
        ], reason: 'marking it read runs behind');
        expect(find.text(es.taskRemoved), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'an entry whose task isn’t on the phone says Es posible que esta tarea se haya eliminado.',
      (tester) async {
        expect(es.taskRemoved, 'Es posible que esta tarea se haya eliminado.');
        final (tasks, _) = await open(tester, completed('srv-gone'));
        await tester.tap(
          find.text('Ana ha completado: Review the new designs'),
        );
        final message = find.text(es.taskRemoved);
        // UX-1640: it waits for the sync before saying so.
        await settleUntil(tester, () => message.evaluate().isNotEmpty);
        expect(tasks.syncs, greaterThan(0));
        expect(message, findsNothing, reason: 'the sync hasn’t completed');
        tasks.sync.complete();
        await settleUntil(tester, () => message.evaluate().isNotEmpty);
        expect(message, findsOneWidget);
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(find.byType(ActivityScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    // ---- Run 2026-10-19-app, round 2 · P210 (UX-1640): a task not on the
    // phone yet waits for the sync before saying it may be deleted ----

    /// «Lucía ha creado: Comprar pan», unread, for task `srv-7`, which the
    /// phone hasn't got yet.
    Map<String, dynamic> lucia({String action = 'created'}) => {
      'id': 'n-lucia',
      'action': action,
      'actor_name': 'Lucía',
      'task_id': 'srv-7',
      'task_title': 'Comprar pan',
      'project_name': 'Casa',
      'created_at': created.toIso8601String(),
      'read_at': null,
    };

    final luciaRow = es.activityEntry('created', 'Lucía', 'Comprar pan');

    /// Activity at 360×800 with [item] (and [others]), as P210 measures it.
    Future<(HangingSyncTasks, _HangingApi)> open360(
      WidgetTester tester,
      Map<String, dynamic> item, {
      List<Map<String, dynamic>> others = const [],
      String language = 'es',
      double textScale = 1,
    }) async {
      final opened = await open(
        tester,
        item,
        others: others,
        language: language,
        textScale: textScale,
      );
      tester.view.physicalSize = const Size(360, 800);
      await tester.pump();
      return opened;
    }

    /// The waiting bar along the bottom of [row] (UX-1647: no trailing
    /// spinner, so the text keeps its width).
    Finder spinnerOn(String row) => find.descendant(
      of: find
          .ancestor(
            of: find.widgetWithText(ListTile, row),
            matching: find.byType(MergeSemantics),
          )
          .first,
      matching: find.byType(LinearProgressIndicator),
    );

    /// The sync brings task 7, «Comprar pan», to the phone: it's in the
    /// database and in the tasks the detail screen reads.
    Future<void> syncBringsPan(
      WidgetTester tester,
      HangingSyncTasks tasks,
    ) async {
      await insert(tester, id: 7, syncId: 'srv-7', title: 'Comprar pan');
      tasks.finishSync([
        ...DesignTaskNotifier.samples(),
        Task(id: 7, title: 'Comprar pan', priority: 1, listId: 'casa'),
      ]);
    }

    testWidgets(
      'UX-1640: tapping «Lucía ha creado: Comprar pan» before the phone has the task spins on that row, says nothing, and opens the task once the sync brings it',
      (tester) async {
        expect(luciaRow, 'Lucía ha creado: Comprar pan');
        final (tasks, api) = await open360(tester, lucia());
        await tester.tap(find.text(luciaRow));
        await settleUntil(
          tester,
          () => spinnerOn(luciaRow).evaluate().isNotEmpty,
        );
        expect(spinnerOn(luciaRow), findsOneWidget);
        expect(find.text(es.taskRemoved), findsNothing);
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(tasks.syncs, greaterThan(0));
        expect(api.reads, ['notifications/n-lucia/read/']);

        await syncBringsPan(tester, tasks);
        final detail = find.byType(TaskDetailScreen);
        await settleUntil(tester, () => detail.evaluate().isNotEmpty);
        expect(detail, findsOneWidget);
        expect(tester.widget<TaskDetailScreen>(detail).taskId, 7);
        expect(
          find.descendant(of: detail, matching: find.text('Comprar pan')),
          findsWidgets,
        );
        expect(find.text(es.taskRemoved), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1640: with a sync that never completes, 5 s after the tap there is no «Es posible que esta tarea se haya eliminado.», the row still spins, and a second tap opens nothing',
      (tester) async {
        final (tasks, _) = await open360(tester, lucia());
        await tester.tap(find.text(luciaRow));
        await settleUntil(
          tester,
          () => spinnerOn(luciaRow).evaluate().isNotEmpty,
        );
        for (var second = 0; second < 5; second++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text(es.taskRemoved), findsNothing);
        expect(spinnerOn(luciaRow), findsOneWidget);
        expect(tasks.sync.isCompleted, isFalse);

        final activityRoute = ModalRoute.of(
          tester.element(find.byType(ActivityScreen)),
        )!;
        await tester.tap(find.text(luciaRow), warnIfMissed: false);
        await settleUntil(
          tester,
          () => find.byType(TaskDetailScreen).evaluate().isNotEmpty,
        );
        expect(
          find.byType(TaskDetailScreen, skipOffstage: false),
          findsNothing,
        );
        expect(activityRoute.isCurrent, isTrue, reason: 'nothing was pushed');
        expect(find.text(es.taskRemoved), findsNothing);
        expect(spinnerOn(luciaRow), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1640: when the sync completes and the task is still missing, «Es posible que esta tarea se haya eliminado.» shows only then, and Activity stays',
      (tester) async {
        final (tasks, _) = await open360(tester, lucia());
        await tester.tap(find.text(luciaRow));
        final message = find.text(es.taskRemoved);
        await settleUntil(tester, () => message.evaluate().isNotEmpty);
        expect(message, findsNothing, reason: 'the sync hasn’t completed');
        expect(spinnerOn(luciaRow), findsOneWidget);

        tasks.finishSync();
        await settleUntil(tester, () => message.evaluate().isNotEmpty);
        expect(message, findsOneWidget);
        expect(spinnerOn(luciaRow), findsNothing);
        expect(
          find.byType(TaskDetailScreen, skipOffstage: false),
          findsNothing,
        );
        expect(find.byType(ActivityScreen), findsOneWidget);
        expect(
          ModalRoute.of(tester.element(find.byType(ActivityScreen)))!.isCurrent,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1640: a deleted entry whose task isn’t on the phone says «Es posible que esta tarea se haya eliminado.» at once, before the sync completes',
      (tester) async {
        final deletedRow = es.activityEntry('deleted', 'Lucía', 'Comprar pan');
        final (tasks, _) = await open360(tester, lucia(action: 'deleted'));
        await tester.tap(find.text(deletedRow));
        final message = find.text(es.taskRemoved);
        await settleUntil(tester, () => message.evaluate().isNotEmpty);
        expect(message, findsOneWidget);
        expect(tasks.sync.isCompleted, isFalse, reason: 'it didn’t wait');
        expect(spinnerOn(deletedRow), findsNothing);
        expect(
          find.byType(TaskDetailScreen, skipOffstage: false),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1640: an entry whose task is on the phone still opens at once, before the sync completes, and is marked read',
      (tester) async {
        final (tasks, api) = await open360(tester, completed('srv-2'));
        await tester.tap(
          find.text('Ana ha completado: Review the new designs'),
        );
        final detail = find.byType(TaskDetailScreen);
        await settleUntil(tester, () => detail.evaluate().isNotEmpty);
        expect(detail, findsOneWidget);
        expect(tester.widget<TaskDetailScreen>(detail).taskId, 2);
        expect(tasks.sync.isCompleted, isFalse);
        expect(api.reads, ['notifications/n-srv-2/read/']);
        expect(find.text(es.taskRemoved), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1640: while one row waits, tapping another whose task is on the phone opens it; the first sync completing afterwards pushes nothing and says nothing',
      (tester) async {
        const anaRow = 'Ana ha completado: Review the new designs';
        final (tasks, _) = await open360(
          tester,
          lucia(),
          others: [completed('srv-2')],
        );
        await tester.tap(find.text(luciaRow));
        await settleUntil(
          tester,
          () => spinnerOn(luciaRow).evaluate().isNotEmpty,
        );
        expect(spinnerOn(luciaRow), findsOneWidget);

        await tester.tap(find.text(anaRow));
        final detail = find.byType(TaskDetailScreen);
        await settleUntil(tester, () => detail.evaluate().isNotEmpty);
        expect(detail, findsOneWidget);
        expect(tester.widget<TaskDetailScreen>(detail).taskId, 2);

        // Now the sync brings Lucía's task: too late, the person moved on.
        await syncBringsPan(tester, tasks);
        await settleUntil(tester, () => false);
        final details = find.byType(TaskDetailScreen, skipOffstage: false);
        expect(details, findsOneWidget, reason: 'no second screen');
        expect(tester.widget<TaskDetailScreen>(details).taskId, 2);
        expect(find.text(es.taskRemoved), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    // ---- Run 2026-10-19-app, round 3 · P213 (UX-1646, UX-1647): the
    // waiting row says «Buscando la tarea…» to TalkBack, and its words stay
    // where they were ----

    /// What TalkBack reads for the row showing [row]: its merged label.
    String spoken(WidgetTester tester, String row) =>
        tester.getSemantics(find.text(row)).getSemanticsData().label;

    /// The live region that announces [label] once, when the bar appears.
    Finder liveRegion(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.liveRegion == true &&
          widget.properties.label == label,
    );

    /// Taps [row] and pumps until its waiting bar shows.
    Future<void> tapAndWait(WidgetTester tester, String row) async {
      await tester.tap(find.text(row));
      await settleUntil(tester, () => spinnerOn(row).evaluate().isNotEmpty);
    }

    testWidgets(
      'UX-1646: after tapping «Lucía ha creado: Comprar pan» with a hanging sync, the row reads «Buscando la tarea…» from a live region, and no deletion message shows',
      (tester) async {
        expect(es.activityFindingTask, 'Buscando la tarea…');
        final semantics = tester.ensureSemantics();
        await open360(tester, lucia());
        expect(
          spoken(tester, luciaRow),
          isNot(contains(es.activityFindingTask)),
        );
        expect(liveRegion(es.activityFindingTask), findsNothing);

        await tapAndWait(tester, luciaRow);
        final label = spoken(tester, luciaRow);
        expect(label, contains(luciaRow));
        expect(label, contains(es.activityFindingTask));
        expect(
          label.indexOf(luciaRow),
          lessThan(label.indexOf(es.activityFindingTask)),
          reason: 'the entry first, then «Buscando la tarea…»',
        );
        expect(liveRegion(es.activityFindingTask), findsOneWidget);
        expect(find.text(es.taskRemoved), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-1647: while «Lucía ha creado: Comprar pan» waits, it shows a thin bar and no spinner, its ListTile has no trailing widget, and the other rows show neither',
      (tester) async {
        const anaRow = 'Ana ha completado: Review the new designs';
        await open360(tester, lucia(), others: [completed('srv-2')]);
        await tapAndWait(tester, luciaRow);

        expect(spinnerOn(luciaRow), findsOneWidget);
        expect(
          find.byType(LinearProgressIndicator),
          findsOneWidget,
          reason: 'only the waiting row shows the bar',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          tester
              .widget<ListTile>(find.widgetWithText(ListTile, luciaRow))
              .trailing,
          isNull,
        );
        expect(spinnerOn(anaRow), findsNothing);
        expect(
          tester
              .widget<ListTile>(find.widgetWithText(ListTile, anaRow))
              .trailing,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['en', 'ca']) {
      testWidgets(
        'UX-1646: in ${language.toUpperCase()}, the waiting row reads its own words for «Buscando la tarea…»',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          expect(
            l.activityFindingTask,
            language == 'en' ? 'Finding the task…' : 'S’està cercant la tasca…',
          );
          final row = l.activityEntry('created', 'Lucía', 'Comprar pan');
          final semantics = tester.ensureSemantics();
          await open360(tester, lucia(), language: language);
          await tapAndWait(tester, row);
          expect(spoken(tester, row), contains(l.activityFindingTask));
          expect(liveRegion(l.activityFindingTask), findsOneWidget);
          expect(find.text(l.taskRemoved), findsNothing);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }

    testWidgets(
      'UX-1646: when the sync brings the task, its detail opens; back on Activity no row reads «Buscando la tarea…» and no bar shows',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final (tasks, _) = await open360(tester, lucia());
        await tapAndWait(tester, luciaRow);
        expect(spoken(tester, luciaRow), contains(es.activityFindingTask));

        await syncBringsPan(tester, tasks);
        final detail = find.byType(TaskDetailScreen);
        await settleUntil(tester, () => detail.evaluate().isNotEmpty);
        expect(detail, findsOneWidget);
        expect(tester.widget<TaskDetailScreen>(detail).taskId, 7);

        await tester.binding.handlePopRoute();
        // The page transition back, on the test clock.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(
          find.byType(TaskDetailScreen, skipOffstage: false),
          findsNothing,
        );
        expect(
          ModalRoute.of(tester.element(find.byType(ActivityScreen)))!.isCurrent,
          isTrue,
        );
        expect(find.text(luciaRow), findsOneWidget);
        expect(
          spoken(tester, luciaRow),
          isNot(contains(es.activityFindingTask)),
        );
        expect(liveRegion(es.activityFindingTask), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-1646: when the sync completes without the task, «Es posible que esta tarea se haya eliminado.» shows, and the bar and «Buscando la tarea…» are gone',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final (tasks, _) = await open360(tester, lucia());
        await tapAndWait(tester, luciaRow);
        expect(liveRegion(es.activityFindingTask), findsOneWidget);

        tasks.finishSync();
        final message = find.text(es.taskRemoved);
        await settleUntil(tester, () => message.evaluate().isNotEmpty);
        expect(message, findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(liveRegion(es.activityFindingTask), findsNothing);
        expect(
          spoken(tester, luciaRow),
          isNot(contains(es.activityFindingTask)),
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-1647: at 2× text in Manrope on 360 dp, Paul’s two-line entry keeps its title size, its row height and the next row’s top while it waits',
      (tester) async {
        await tester.runAsync(
          () => (FontLoader(
            'Manrope',
          )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load(),
        );
        const title = 'Llamar al fontanero por lo de la cocina';
        final paulRow = es.activityAssignedYou('Paul', title);
        expect(
          paulRow,
          'Paul te ha asignado: Llamar al fontanero por lo de la cocina',
        );
        final paul = {
          'id': 'n-paul',
          'action': 'assigned',
          'actor_name': 'Paul',
          'task_id': 'srv-fontanero',
          'task_title': title,
          'project_name': 'Casa',
          'created_at': created.toIso8601String(),
          'read_at': null,
          'assignee_name': 'María',
          'assignee_is_you': true,
        };
        final (tasks, _) = await open360(
          tester,
          paul,
          others: [completed('srv-2')],
          textScale: 2,
        );
        const nextRow = 'Ana ha completado: Review the new designs';
        final titleText = find.text(paulRow);
        final row = find
            .ancestor(of: titleText, matching: find.byType(MergeSemantics))
            .first;
        final next = find.widgetWithText(ListTile, nextRow);

        final lines = tester
            .renderObject<RenderParagraph>(titleText)
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: paulRow.length),
            )
            .map((box) => box.top)
            .toSet()
            .length;
        expect(
          lines,
          greaterThanOrEqualTo(2),
          reason: 'the entry wraps before the tap',
        );
        final titleBefore = tester.getSize(titleText);
        final rowBefore = tester.getSize(row);
        final nextBefore = tester.getTopLeft(next);

        await tapAndWait(tester, paulRow);
        expect(spinnerOn(paulRow), findsOneWidget);
        expect(tasks.sync.isCompleted, isFalse);
        expect(tester.getSize(titleText), titleBefore);
        expect(tester.getSize(row).height, rowBefore.height);
        expect(tester.getTopLeft(next).dy, nextBefore.dy);
        // The bar sits inside the row, along its bottom edge, below the text.
        final bar = tester.getRect(spinnerOn(paulRow));
        expect(bar.bottom, tester.getRect(row).bottom);
        expect(bar.height, 2);
        expect(bar.top, greaterThanOrEqualTo(tester.getRect(titleText).bottom));
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('UX-628: a task’s own history keeps the word Actividad', (
    tester,
  ) async {
    final container = designContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      app(container, const Scaffold(body: TaskActivity(taskId: 1))),
    );
    await tester.pumpAndSettle();
    expect(es.activity, 'Actividad');
    expect(find.text(es.activity), findsOneWidget);
    expect(find.text(es.groupActivity), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// A server that never answers: each read receipt is recorded and waits.
class _HangingApi extends OfflineApiClient {
  final reads = <String>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) {
    if (path.startsWith('notifications/')) reads.add(path);
    return Completer<dynamic>().future;
  }
}
