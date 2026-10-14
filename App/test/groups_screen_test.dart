// P15 (UX-301, UX-317, UX-340) on a group's page: archiving says it hides
// the group for everyone and offers Deshacer; leaving asks in red and says
// so after the page closes.
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));

  testWidgets(
    'UX-301: archiving a group says «Familia» archivado para todos: ya no aparece en el calendario ni avisará. with Deshacer, which unarchives it',
    (tester) async {
      expect(
        es.groupArchivedForEveryone('Familia'),
        '«Familia» archivado para todos: ya no aparece en el calendario ni avisará.',
      );
      final api = await _open(tester, role: 'owner');
      final archive = find.text(es.groupArchive);
      await tester.scrollUntilVisible(
        archive,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(archive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.calls.last, [
        'PUT',
        'groups/familia/',
        {'name': 'Familia', 'archived': true, 'version': 1},
      ]);
      expect(find.text(es.groupArchivedForEveryone('Familia')), findsOneWidget);
      final undo = find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(es.undo),
      );
      expect(undo, findsOneWidget);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(api.calls.last, [
        'PUT',
        'groups/familia/',
        {'name': 'Familia', 'archived': false, 'version': 2},
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-340 / UX-317: leaving a group asks with a red button, closes its page and says Has salido de Familia',
    (tester) async {
      final api = await _open(tester, role: 'editor');
      final leave = find.text(es.groupLeave);
      await tester.scrollUntilVisible(
        leave,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final error = Theme.of(tester.element(leave)).colorScheme.error;
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, es.groupLeave))
            .textColor,
        error,
      );
      await tester.tap(leave);
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.groupLeave),
      );
      expect(
        tester
            .widget<FilledButton>(confirm)
            .style!
            .backgroundColor!
            .resolve({}),
        error,
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(api.calls.last.take(2), ['POST', 'groups/familia/leave/']);
      expect(find.byType(GroupScreen), findsNothing);
      expect(find.text(es.youLeft('Familia')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-485: ($language) deleting an empty group from its page lands on the previous screen with Grupo eliminado',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final api = await _open(
          tester,
          role: 'owner',
          projectCount: 0,
          language: language,
        );
        final delete = find.widgetWithText(ListTile, l.delete);
        await tester.scrollUntilVisible(
          delete,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, l.delete),
          ),
        );
        await tester.pumpAndSettle();
        expect(api.calls.last.take(2), ['DELETE', 'groups/familia/']);
        expect(find.byType(GroupScreen), findsNothing);
        expect(find.byKey(const ValueKey('open-group')), findsOneWidget);
        final message = find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(l.groupDeleted),
        );
        expect(message, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-490: deleting a group in Catalan with Suprimeix lands on the screen underneath with Grup suprimit, the catalog’s word for delete',
    (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(ca.delete, 'Suprimeix');
      expect(ca.groupDeleted, 'Grup suprimit');
      // The same verb as deleting a project.
      expect(ca.groupDeleted, contains('suprimit'));
      expect(ca.groupDeleted, isNot(contains('eliminat')));
      final api = await _open(
        tester,
        role: 'owner',
        projectCount: 0,
        language: 'ca',
      );
      final delete = find.widgetWithText(ListTile, ca.delete);
      await tester.scrollUntilVisible(
        delete,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, ca.delete),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls.last.take(2), ['DELETE', 'groups/familia/']);
      expect(find.byType(GroupScreen), findsNothing);
      expect(find.byKey(const ValueKey('open-group')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(ca.groupDeleted),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('eliminat'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('UX-485: Grupo eliminado reads right in each language', () {
    expect(es.groupDeleted, 'Grupo eliminado');
    expect(
      lookupAppLocalizations(const Locale('en')).groupDeleted,
      'Group deleted',
    );
    expect(
      lookupAppLocalizations(const Locale('ca')).groupDeleted,
      'Grup suprimit',
    );
  });
}

/// Group `Familia` in Spanish, where this account has [role], opened from a
/// page underneath so closing it can be seen.
Future<_Groups> _open(
  WidgetTester tester, {
  required String role,
  int projectCount = 1,
  String language = 'es',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _Groups();
  var version = 1;
  var archived = false;
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      taskListsProvider.overrideWith((ref) async => []),
      groupsProvider.overrideWith((ref) async => []),
      groupDetailsProvider('familia').overrideWith(
        (ref) async => {
          'group': {
            'id': 'familia',
            'name': 'Familia',
            'owner_id': role == 'owner' ? 1 : 2,
            'version': version,
            'role': role,
            'archived': archived,
            'project_count': projectCount,
            'people': [
              {'user_id': 1, 'name': 'Yo', 'role': role},
              if (role != 'owner')
                {'user_id': 2, 'name': 'Ana', 'role': 'owner'},
            ],
          },
          'invitations': [],
        },
      ),
    ],
  );
  api.onPut = (data) {
    version++;
    archived = data?['archived'] == true;
    return {'version': version};
  };
  addTearDown(container.dispose);
  addTearDown(api.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(language),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-group'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const GroupScreen(groupId: 'familia'),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-group')));
  await tester.pumpAndSettle();
  return api;
}

/// Records each call as [method, path, body].
class _Groups extends OfflineApiClient {
  final calls = <List<Object?>>[];
  Map<String, dynamic> Function(Map<String, dynamic>? data)? onPut;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    calls.add([method, path, data]);
    if (method == 'PUT') return onPut?.call(data) ?? {};
    return {};
  }
}
