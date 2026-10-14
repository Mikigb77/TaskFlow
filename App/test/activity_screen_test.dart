// Round 1 of 2026-10-13-app (b9), P25 (UX-407, UX-321) and P27 (UX-320):
// the header's Activity button shows only to people who share something,
// with a people icon; Activity rows lead with who did what; a failed load
// says so and offers Reintentar.
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/screens/activity_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_fixtures.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));

  Widget app(ProviderContainer container, Widget home, {String language = 'es'}) =>
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

  const header = Scaffold(
    appBar: CustomAppBar(title: 'Calendario', isRoot: true),
    body: SizedBox(),
  );

  test('UX-407: the Activity button is called Group activity in each language', () {
    expect(es.groupActivity, 'Actividad del grupo');
    expect(lookupAppLocalizations(const Locale('en')).groupActivity, 'Group activity');
    expect(lookupAppLocalizations(const Locale('ca')).groupActivity, 'Activitat del grup');
  });

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
    'UX-407: with a shared project the header button shows a people icon, the tooltip Actividad del grupo and the unread badge, and opens Activity',
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
        find.descendant(of: button, matching: find.byIcon(Icons.groups_outlined)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.notifications_outlined)),
        findsNothing,
      );
      expect(find.descendant(of: button, matching: find.text('3')), findsOneWidget);
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
    await tester.pumpWidget(app(container, const ActivityScreen(), language: language));
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
      expect(tester.widget<Text>(read).style?.fontWeight, isNot(FontWeight.w700));
      expect(tester.getSemantics(read).label, isNot(contains(es.activityUnread)));

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
    expect(es.activityEntry('completed', 'Ana', 'Comprar pan'), 'Ana ha completado: Comprar pan');
    expect(
      lookupAppLocalizations(const Locale('en')).activityEntry('completed', 'Ana', 'Buy bread'),
      'Ana completed: Buy bread',
    );
    expect(
      lookupAppLocalizations(const Locale('ca')).activityEntry('completed', 'Ana', 'Comprar pa'),
      'Ana ha completat: Comprar pa',
    );
    expect(es.activityUnread, 'No leída');
    expect(lookupAppLocalizations(const Locale('en')).activityUnread, 'Unread');
    expect(lookupAppLocalizations(const Locale('ca')).activityUnread, 'No llegida');
  });

  testWidgets('UX-321: an empty Activity says its sentence once', (tester) async {
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
      'UX-628: the header’s Actividad del grupo button opens a screen titled with the same name ($language)',
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

  test('UX-628: the screen’s title reads as the plan says in each language', () {
    expect(es.groupActivity, 'Actividad del grupo');
    expect(lookupAppLocalizations(const Locale('en')).groupActivity, 'Group activity');
    expect(lookupAppLocalizations(const Locale('ca')).groupActivity, 'Activitat del grup');
  });

  testWidgets(
    'UX-628: at 2x text on 320x568 in Catalan the Activity screen’s app bar shows Activitat del grup without overflow',
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
      await tester.pumpWidget(app(container, const ActivityScreen(), language: 'ca'));
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
      expect(rect.bottom, lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-628: a task’s own history keeps the word Actividad',
    (tester) async {
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
    },
  );
}
