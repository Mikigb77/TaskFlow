// P15 (UX-301, UX-317, UX-340) on a group's page: archiving says it hides
// the group for everyone and offers Deshacer; leaving asks in red and says
// so after the page closes.
import 'dart:async';

import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_fixtures.dart';
import 'support/hanging_sync.dart';
import 'support/address_wrap.dart';
import 'support/no_counter.dart';

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
        final delete = find.widgetWithText(ListTile, l.groupDeleteAction);
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
            matching: find.widgetWithText(FilledButton, l.groupDeleteAction),
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
      final delete = find.widgetWithText(ListTile, ca.groupDeleteAction);
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
          matching: find.widgetWithText(FilledButton, ca.groupDeleteAction),
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

  // ---- Round 1 (b9) · P27 (UX-319, UX-320, UX-328, UX-330, UX-336) ----

  /// [home] in Spanish, signed in as account 1, with [details] for group
  /// `familia` (or a failure when [details] throws) and [api] answering.
  Future<ProviderContainer> pumpGroups(
    WidgetTester tester,
    Widget home, {
    Future<Map<String, dynamic>> Function()? details,
    _Groups? api,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = api ?? _Groups();
    final container = ProviderContainer(
      retry: noRetry,
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(client)),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        taskListsProvider.overrideWith((ref) async => []),
        groupsProvider.overrideWith((ref) async => []),
        pendingInvitationsProvider.overrideWith((ref) async => []),
        if (details != null)
          groupDetailsProvider('familia').overrideWith((ref) => details()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Group `Familia` owned by account [ownerId]; account 1 has [role].
  Map<String, dynamic> familia({
    required String role,
    int ownerId = 1,
    List<Map<String, dynamic>> people = const [],
    List<Map<String, dynamic>> invitations = const [],
  }) => {
    'group': {
      'id': 'familia',
      'name': 'Familia',
      'owner_id': ownerId,
      'version': 1,
      'role': role,
      'archived': false,
      'project_count': 1,
      'people': people,
    },
    'invitations': invitations,
  };

  testWidgets(
    'UX-319: the create-group dialog’s button reads Crear grupo, and an empty name says Escribe un nombre.',
    (tester) async {
      expect(es.createGroup, 'Crear grupo');
      expect(es.enterName, 'Escribe un nombre.');
      await pumpGroups(tester, const GroupsScreen());
      await tester.tap(find.text(es.newGroup));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final create = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, es.createGroup),
      );
      expect(create, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text(es.save)),
        findsNothing,
      );
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: dialog, matching: find.text(es.enterName)),
        findsOneWidget,
      );
      expect(
        find.text('Revisa los datos antes de añadirlos al calendario.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-328: a failed group creation keeps the dialog open with the typed name and the error inside it',
    (tester) async {
      final failure = ApiException(0, 'offline');
      final api = _Groups()..onPost = (_) => throw failure;
      await pumpGroups(tester, const GroupsScreen(), api: api);
      await tester.tap(find.text(es.newGroup));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final field = find.descendant(
        of: dialog,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(field, 'Familia');
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, es.createGroup),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls.last.take(2), ['POST', 'groups/']);
      expect(dialog, findsOneWidget, reason: 'the dialog stays open');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        'Familia',
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(
            requestProblemText(es, failure, keptNote: false),
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(GroupScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-319 / UX-1513: the invite dialog’s button reads Enviar invitación, and a bad email says Introduce un correo electrónico.',
    (tester) async {
      await pumpGroups(
        tester,
        const GroupScreen(groupId: 'familia'),
        details: () async => familia(
          role: 'owner',
          people: [
            {'user_id': 1, 'name': 'Yo', 'role': 'owner'},
          ],
        ),
      );
      final invite = find.widgetWithText(FilledButton, es.invitePerson);
      await tester.ensureVisible(invite);
      await tester.tap(invite);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final next = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, es.sendInvitation),
      );
      expect(es.sendInvitation, 'Enviar invitación');
      expect(next, findsOneWidget);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextFormField)),
        'ana@',
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: dialog, matching: find.text(es.enterEmailAddress)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-319: the role sheet for Ana is titled ¿Qué puede hacer Ana? with her current role selected',
    (tester) async {
      expect(es.groupRoleQuestion('Ana'), '¿Qué puede hacer Ana?');
      await pumpGroups(
        tester,
        const GroupScreen(groupId: 'familia'),
        details: () async => familia(
          role: 'owner',
          people: [
            {'user_id': 1, 'name': 'Yo', 'role': 'owner'},
            {'user_id': 2, 'name': 'Ana', 'role': 'viewer'},
          ],
        ),
      );
      final manage = find.byTooltip(es.manageItem('Ana'));
      await tester.ensureVisible(manage);
      await tester.tap(manage);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('¿Qué puede hacer Ana?')),
        findsOneWidget,
      );
      final viewer = find.descendant(
        of: sheet,
        matching: find.widgetWithText(ListTile, es.roleViewer),
      );
      final editor = find.descendant(
        of: sheet,
        matching: find.widgetWithText(ListTile, es.roleEditor),
      );
      expect(tester.widget<ListTile>(viewer).selected, isTrue);
      expect(tester.widget<ListTile>(editor).selected, isFalse);
      expect(
        find.descendant(of: viewer, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-330 / UX-336: a member’s group page is titled Familia, lists Invitados with Pendiente rows, and has the voice name only in their own row menu',
    (tester) async {
      expect(es.groupInvited, 'Invitados');
      expect(es.invitationPending, 'Pendiente');
      expect(es.groupVoiceName, 'Nombre para asignarte por voz');
      await pumpGroups(
        tester,
        const GroupScreen(groupId: 'familia'),
        details: () async => familia(
          role: 'admin',
          ownerId: 2,
          people: [
            {'user_id': 2, 'name': 'Ana', 'role': 'owner'},
            {'user_id': 1, 'name': 'Yo', 'role': 'admin'},
          ],
          invitations: [
            {'id': 'i1', 'email': 'luis@example.invalid', 'role': 'editor'},
          ],
        ),
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Familia')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(es.groups)),
        findsNothing,
      );
      expect(find.text(es.groupInvited), findsOneWidget);
      final invited = find.widgetWithText(
        ListTile,
        breakableAddress('luis@example.invalid'),
      );
      expect(
        find.descendant(of: invited, matching: find.text(es.invitationPending)),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text(es.groupInvited)).dy,
        lessThan(tester.getTopLeft(invited).dy),
      );
      // No prominent button: the voice name is in this member's own menu.
      expect(find.text(es.groupVoiceName), findsNothing);
      expect(find.text('Tu nombre para voz'), findsNothing);
      final mine = find.byTooltip(es.manageItem('Yo'));
      expect(
        find.ancestor(
            of: mine,
            matching: find.widgetWithText(ListTile, es.personYou('Yo'))),
        findsOneWidget,
      );
      await tester.tap(mine);
      await tester.pumpAndSettle();
      expect(find.text(es.groupVoiceName), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-330: the group owner gets no voice name action anywhere',
    (tester) async {
      await pumpGroups(
        tester,
        const GroupScreen(groupId: 'familia'),
        details: () async => familia(
          role: 'owner',
          people: [
            {'user_id': 1, 'name': 'Yo', 'role': 'owner'},
            {'user_id': 2, 'name': 'Ana', 'role': 'editor'},
          ],
        ),
      );
      expect(find.text(es.groupVoiceName), findsNothing);
      expect(find.byTooltip(es.manageItem('Yo')), findsNothing);
      // Ana's row opens her role sheet, which has no voice name either.
      await tester.tap(find.byTooltip(es.manageItem('Ana')));
      await tester.pumpAndSettle();
      expect(find.text(es.groupVoiceName), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-320: a group page that fails to load says No se ha podido cargar. Revisa la conexión. with Reintentar, not that a change wasn’t saved',
    (tester) async {
      var calls = 0;
      await pumpGroups(
        tester,
        const GroupScreen(groupId: 'familia'),
        details: () async {
          calls++;
          if (calls == 1) throw ApiException(0, 'offline');
          return familia(
            role: 'owner',
            people: [
              {'user_id': 1, 'name': 'Yo', 'role': 'owner'},
            ],
          );
        },
      );
      expect(find.text(es.loadFailed), findsOneWidget);
      expect(find.text(es.groupActionError), findsNothing);
      final retry = find.widgetWithText(TextButton, es.retry);
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(es.loadFailed), findsNothing);
      expect(find.text(es.groupMembers), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 (b9) · P115: no lone role word on top of a group's page ----

  for (final (role, others) in [('editor', 'Ana'), ('owner', null)]) {
    testWidgets(
      'UX-627: at 360x740 a group page where you are $role shows your role only under Miembros, in your own row, and nothing above the heading',
      (tester) async {
        await _open(tester, role: role);
        tester.view.physicalSize = const Size(360, 740);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(GroupScreen));
        final label = groupRoleLabel(context, role);
        expect(label, role == 'editor' ? 'Editor' : 'Propietario');
        final heading = find.text(es.groupMembers);
        expect(heading, findsOneWidget);
        final mine = find.widgetWithText(ListTile, es.personYou('Yo'));
        expect(mine, findsOneWidget);
        expect(
          find.descendant(of: mine, matching: find.text(label)),
          findsOneWidget,
          reason: 'your own row says your role',
        );
        // Exactly once on the page: Ana, the owner when you're an editor,
        // has Propietario in her own row, never Editor.
        expect(find.text(label), findsOneWidget);
        final headingTop = tester.getRect(heading).top;
        for (final element in find.byType(Text).evaluate()) {
          final text = element.widget as Text;
          if (text.data == groupRoleLabel(context, 'editor') ||
              text.data == groupRoleLabel(context, 'owner')) {
            expect(
              tester.getRect(find.byWidget(text)).top,
              greaterThan(headingTop),
              reason: 'no role word above Miembros',
            );
          }
        }
        if (others != null) {
          final row = find.widgetWithText(ListTile, others);
          expect(
            find.descendant(
              of: row,
              matching: find.text(groupRoleLabel(context, 'owner')),
            ),
            findsOneWidget,
          );
        }
        // With no error and nothing in progress the heading leads the page,
        // right under the app bar's padding; for the owner, right under
        // Invitar a una persona, which comes first (P285, UX-2520).
        final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
        final invite = find.widgetWithText(FilledButton, es.invitePerson);
        final above = role == 'owner'
            ? tester.getRect(invite).bottom
            : appBarBottom;
        if (role == 'owner') {
          expect(tester.getRect(invite).top - appBarBottom,
              lessThanOrEqualTo(32));
        } else {
          expect(invite, findsNothing);
        }
        expect(headingTop - above, lessThanOrEqualTo(32));
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- Run 2026-10-19-app, round 1 · P181 (UX-1503, UX-1513) and P183
  // (UX-1510) on a group's page ----

  /// Familia's page, owned by this account, with Ana as an editor.
  Future<_Groups> openOwnGroup(
    WidgetTester tester, {
    List<Map<String, dynamic>> invitations = const [],
    _Groups? api,
    TaskNotifier Function()? tasks,
  }) async {
    final client = api ?? _Groups();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: noRetry,
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(client)),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith(
          (ref) => tasks?.call() ?? DesignTaskNotifier(),
        ),
        taskListsProvider.overrideWith((ref) async => []),
        groupsProvider.overrideWith((ref) async => []),
        pendingInvitationsProvider.overrideWith((ref) async => []),
        groupDetailsProvider('familia').overrideWith(
          (ref) async => familia(
            role: 'owner',
            people: [
              {'user_id': 1, 'name': 'Yo', 'role': 'owner'},
              {'user_id': 2, 'name': 'Ana', 'role': 'editor'},
            ],
            invitations: invitations,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GroupScreen(groupId: 'familia'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return client;
  }

  Future<void> openInvite(WidgetTester tester) async {
    final invite = find.widgetWithText(FilledButton, es.invitePerson);
    await tester.ensureVisible(invite);
    await tester.pumpAndSettle();
    await tester.tap(invite);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-1503: the group invite dialog reads ¿A quién invitas a Familia? with the field labelled Correo',
    (tester) async {
      expect(es.inviteWho('Familia'), '¿A quién invitas a Familia?');
      expect(es.email, 'Correo');
      await openOwnGroup(tester);
      await openInvite(tester);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(es.inviteWho('Familia')),
        ),
        findsOneWidget,
      );
      final field = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).decoration!.labelText, es.email);
      expect(find.textContaining('Correo de su cuenta'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1503: typing your own address in the group invite, trimmed and in capitals, shows Ese es tu correo. Escribe el de la persona que invitas. and sends nothing',
    (tester) async {
      final api = await openOwnGroup(tester);
      await openInvite(tester);
      final dialog = find.byType(AlertDialog);
      // The account is design@example.invalid.
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextFormField)),
        ' Design@EXAMPLE.invalid  ',
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, es.sendInvitation),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: dialog, matching: find.text(es.inviteOwnEmail)),
        findsOneWidget,
      );
      expect(
        es.inviteOwnEmail,
        'Ese es tu correo. Escribe el de la persona que invitas.',
      );
      expect(
        api.calls.where((call) => '${call[1]}'.endsWith('invite/')),
        isEmpty,
        reason: 'no invitation is sent',
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1513: a group invite sends role editor with no role sheet from Enviar invitación, and ends on the project’s dialog: Invitación enviada, Si no le llega el correo, envíale este código: and the code',
    (tester) async {
      const code = 'synthetic-group-code-2026';
      final api = _Groups()..onPost = (_) => {'code': code};
      await openOwnGroup(tester, api: api);
      await openInvite(tester);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, es.sendInvitation),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextFormField)),
        'luis@example.invalid',
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, es.sendInvitation),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls.last, [
        'POST',
        'groups/familia/invite/',
        {'email': 'luis@example.invalid', 'role': 'editor'},
      ]);
      expect(find.byType(BottomSheet), findsNothing, reason: 'no role step');
      expect(find.text(es.groupRoleQuestion('luis@example.invalid')),
          findsNothing);
      // The same dialog as a project's.
      final sent = find.byType(AlertDialog);
      expect(sent, findsOneWidget);
      final texts = tester
          .widgetList<Text>(find.descendant(of: sent, matching: find.byType(Text)))
          .map((text) => text.data)
          .toSet();
      expect(texts, {
        es.invitationSent,
        es.invitationCodeFallback,
        es.copyCode,
        es.done,
      });
      expect(
        find.descendant(
          of: sent,
          matching: find.byKey(const ValueKey('invitation-code')),
        ),
        findsOneWidget,
      );
      expect(find.text(code), findsOneWidget);
      expect(find.textContaining('Reemplazar una invitación'), findsNothing);
      expect(find.textContaining('invalida'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1513: a group’s pending invitation has a ⋮ named for its address, with Reenviar and a red Anular invitación, and no Revocar invitación',
    (tester) async {
      final api = await openOwnGroup(
        tester,
        invitations: [
          {'id': 'i1', 'email': 'luis@example.invalid', 'role': 'editor'},
        ],
      );
      expect(find.byTooltip('Revocar invitación'), findsNothing);
      final menu = find.byTooltip(es.manageItem('luis@example.invalid'));
      expect(menu, findsOneWidget);
      expect(
        find.ancestor(
          of: menu,
          matching: find.widgetWithText(
            ListTile,
            breakableAddress('luis@example.invalid'),
          ),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text(es.sendInvitationAgain), findsOneWidget);
      final cancel = find.text(es.cancelInvitation);
      expect(cancel, findsOneWidget);
      expect(
        tester.widget<Text>(cancel).style?.color,
        Theme.of(tester.element(cancel)).colorScheme.error,
      );
      await tester.tap(find.text(es.sendInvitationAgain));
      await tester.pumpAndSettle();
      expect(api.calls.last.take(2), ['POST', 'groups/familia/invite/']);
      expect(
        (api.calls.last[2] as Map)['email'],
        'luis@example.invalid',
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.cancelInvitation));
      await tester.pumpAndSettle();
      expect(api.calls.last, [
        'POST',
        'groups/familia/revoke_invite/',
        {'invitation_id': 'i1'},
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1513: a member’s row still opens the role sheet: Editor and Lector, plus Administrador for the owner',
    (tester) async {
      await openOwnGroup(tester);
      await tester.tap(find.byTooltip(es.manageItem('Ana')));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      for (final role in [es.roleEditor, es.roleViewer, es.groupAdmin]) {
        expect(
          find.descendant(
            of: sheet,
            matching: find.widgetWithText(ListTile, role),
          ),
          findsOneWidget,
          reason: role,
        );
      }
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // An administrator who isn't the owner: no Administrador to give.
      await tester.pumpWidget(const SizedBox());
      await pumpGroups(
        tester,
        const GroupScreen(groupId: 'familia'),
        details: () async => familia(
          role: 'admin',
          ownerId: 3,
          people: [
            {'user_id': 3, 'name': 'Lucía', 'role': 'owner'},
            {'user_id': 1, 'name': 'Yo', 'role': 'admin'},
            {'user_id': 2, 'name': 'Ana', 'role': 'editor'},
          ],
        ),
      );
      await tester.tap(find.byTooltip(es.manageItem('Ana')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(ListTile, es.roleViewer),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(es.groupAdmin),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1510: with a sync that never completes, a group invite shows Invitación enviada right after its POST returns',
    (tester) async {
      final tasks = HangingSyncTasks();
      final api = _Groups()..onPost = (_) => {'code': 'synthetic-group-code'};
      await openOwnGroup(tester, api: api, tasks: () => tasks);
      await openInvite(tester);
      final dialog = find.byType(AlertDialog);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextFormField)),
        'luis@example.invalid',
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, es.sendInvitation),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.calls.last.take(2), ['POST', 'groups/familia/invite/']);
      expect(tasks.syncs, greaterThan(0), reason: 'a sync is under way');
      expect(find.widgetWithText(AlertDialog, es.invitationSent), findsOneWidget);
      expect(find.text('synthetic-group-code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-19-app, round 2 · P212 (UX-1644, UX-1645): «(tú)» on
  // the group, and one invite wording ----

  /// Group `Familia` as its owner María (account 1), with Ana and Luis, in
  /// [language] at [scale] on 360×800.
  Future<void> openMariasGroup(
    WidgetTester tester, {
    String language = 'es',
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _Groups();
    final container = ProviderContainer(
      retry: noRetry,
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(client)),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        taskListsProvider.overrideWith((ref) async => []),
        groupsProvider.overrideWith((ref) async => []),
        pendingInvitationsProvider.overrideWith((ref) async => []),
        groupDetailsProvider('familia').overrideWith(
          (ref) async => familia(
            role: 'owner',
            people: [
              {'user_id': 1, 'name': 'María', 'role': 'owner'},
              {'user_id': 2, 'name': 'Ana', 'role': 'editor'},
              {'user_id': 3, 'name': 'Luis', 'role': 'viewer'},
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(language),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const GroupScreen(groupId: 'familia'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-1644: at 1× on 360×800 the group page as its owner María reads María (tú) on her row; Ana and Luis by name alone; no raw member',
    (tester) async {
      expect(es.personYou('María'), 'María (tú)');
      await openMariasGroup(tester);
      final mine = find.widgetWithText(ListTile, es.personYou('María'));
      expect(mine, findsOneWidget);
      expect(
        find.descendant(of: mine, matching: find.text(es.roleOwner)),
        findsOneWidget,
      );
      expect(find.text('María'), findsNothing, reason: 'her row says (tú)');
      for (final name in ['Ana', 'Luis']) {
        final row = find.widgetWithText(ListTile, name);
        expect(row, findsOneWidget, reason: name);
        expect(
          find.descendant(of: row, matching: find.text(es.personYou(name))),
          findsNothing,
        );
        // The menu still names the person plainly.
        expect(find.byTooltip(es.manageItem(name)), findsOneWidget);
      }
      expect(find.textContaining('member'), findsNothing);
      expect(find.textContaining('(tú)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-1645: the group invite help reads as one wording in each language',
    () {
      expect(
        es.groupInviteHelp,
        'Esa persona verá todos los proyectos de este grupo. Le enviaremos una invitación por correo.',
      );
      expect(
        lookupAppLocalizations(const Locale('en')).groupInviteHelp,
        'They’ll see every project in this group. We’ll email them an invitation.',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).groupInviteHelp,
        'Aquesta persona veurà tots els projectes d’aquest grup. Li enviarem una invitació per correu.',
      );
    },
  );

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-1645: ($language) the group invite dialog shows the help under ¿A quién invitas a Familia?, above the email field',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        await openMariasGroup(tester, language: language);
        final invite = find.widgetWithText(FilledButton, l.invitePerson);
        await tester.ensureVisible(invite);
        await tester.pumpAndSettle();
        await tester.tap(invite);
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        final title = find.descendant(
          of: dialog,
          matching: find.text(l.inviteWho('Familia')),
        );
        final help = find.descendant(
          of: dialog,
          matching: find.text(l.groupInviteHelp),
        );
        expect(title, findsOneWidget);
        expect(help, findsOneWidget);
        final field = find.descendant(
          of: dialog,
          matching: find.byType(TextFormField),
        );
        expect(
          tester.getRect(help).top,
          greaterThanOrEqualTo(tester.getRect(title).bottom),
        );
        expect(
          tester.getRect(help).bottom,
          lessThanOrEqualTo(tester.getRect(field).top),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1645: at 2× on 360×800 in Spanish the group invite help shows whole, with no clipping',
    (tester) async {
      await openMariasGroup(tester, scale: 2);
      final invite = find.widgetWithText(FilledButton, es.invitePerson);
      await tester.ensureVisible(invite);
      await tester.pumpAndSettle();
      await tester.tap(invite);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final help = find.descendant(
        of: dialog,
        matching: find.text(es.groupInviteHelp),
      );
      expect(help, findsOneWidget);
      await tester.ensureVisible(help);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(help);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.textScaler, const TextScaler.linear(2));
      // Every line is laid out: the paragraph is as tall as its text.
      final full = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      expect(paragraph.size.height, closeTo(full.height, 0.5));
      full.dispose();
      final rect = tester.getRect(help);
      final box = tester.getRect(
        find.descendant(of: dialog, matching: find.byType(Material)).first,
      );
      expect(rect.left, greaterThanOrEqualTo(box.left));
      expect(rect.right, lessThanOrEqualTo(box.right));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(800));
      // Shown, not cut by the dialog's scroll area.
      expect(help.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  group('P284 · group page answers where you tapped', () {
    // Measure wrapping in the app's own font, not the square test font.
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    });

    const network =
        'No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.';
    Finder inPage(Finder finder) =>
        find.descendant(of: find.byType(GroupScreen), matching: finder);
    Finder bar() => inPage(find.byType(LinearProgressIndicator));
    Finder scrollable() => inPage(find.byType(Scrollable)).first;
    Future<void> frames(WidgetTester tester, [int count = 10]) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets(
      'UX-2502: (es, 2x, 360x800) offline, «Archivar grupo» keeps the page and its members and says the network message as a floating message, never «No se ha podido cargar»',
      (tester) async {
        expect(es.requestError('network'), network);
        final api = await _openLiveGroup(tester, scale: 2);
        final archive = find.text(es.groupArchive);
        await tester.scrollUntilVisible(
          archive,
          200,
          scrollable: scrollable(),
        );
        await tester.pumpAndSettle();
        final before = tester.getRect(archive);
        api.offline = true;
        await tester.tap(archive);
        await tester.pump();
        await frames(tester);
        expect(
          api.calls.where((call) => call[0] == 'GET').length,
          greaterThanOrEqualTo(2),
          reason: 'the page asked again after the failure, and that failed',
        );
        final snack = find.byType(SnackBar);
        expect(snack, findsOneWidget);
        expect(
          tester.widget<SnackBar>(snack).behavior,
          SnackBarBehavior.floating,
        );
        expect(
          find.descendant(of: snack, matching: find.text(network)),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tus tareas siguen guardadas'),
          findsNothing,
        );
        expect(find.text(es.loadFailed), findsNothing);
        expect(find.byType(LoadFailed), findsNothing);
        expect(inPage(find.byType(MessageBanner)), findsNothing);
        expect(archive, findsOneWidget, reason: 'the page stays');
        expect(tester.getRect(archive), before, reason: 'where it was');
        expect(bar(), findsNothing);
        // The members are still there above.
        await tester.scrollUntilVisible(
          find.text(es.personYou('Yo')),
          -200,
          scrollable: scrollable(),
        );
        expect(find.text(es.personYou('Yo')), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2502: (es, 2x, 360x800) while «Archivar grupo» runs, scrolled to the bottom, a 2 dp bar sits under the app bar in view and nothing below it moves',
      (tester) async {
        final api = await _openLiveGroup(tester, scale: 2);
        final archive = find.text(es.groupArchive);
        await tester.drag(scrollable(), const Offset(0, -5000));
        await tester.pumpAndSettle();
        expect(archive, findsOneWidget);
        final before = tester.getRect(archive);
        expect(before.bottom, lessThanOrEqualTo(800));
        api.hold = Completer<void>();
        await tester.tap(archive);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(api.calls.last.take(2), ['PUT', 'groups/familia/']);
        expect(bar(), findsOneWidget);
        final appBar = tester.getRect(inPage(find.byType(AppBar)));
        final rect = tester.getRect(bar());
        expect(rect.height, moreOrLessEquals(2, epsilon: 0.01));
        expect(rect.top, moreOrLessEquals(appBar.bottom, epsilon: 0.5));
        expect(rect.bottom, lessThanOrEqualTo(800));
        expect(tester.getRect(archive), before, reason: 'nothing moves');
        api.hold!.complete();
        await frames(tester);
        expect(bar(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2502: with the sync held open, a rename and an archive show on the page as soon as the server answers',
      (tester) async {
        final tasks = HangingSyncTasks();
        final api = await _openLiveGroup(tester, tasks: tasks);
        Finder titled(String name) => find.descendant(
          of: inPage(find.byType(AppBar)),
          matching: find.text(name),
        );
        expect(titled('Familia'), findsOneWidget);
        final rename = find.text(es.groupRename);
        await tester.scrollUntilVisible(rename, 200, scrollable: scrollable());
        await tester.pumpAndSettle();
        await tester.tap(rename);
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        await tester.enterText(
          find.descendant(of: dialog, matching: find.byType(TextFormField)),
          'Casa',
        );
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, es.save),
          ),
        );
        await tester.pump();
        await frames(tester);
        expect(api.name, 'Casa');
        expect(tasks.syncs, greaterThan(0), reason: 'a sync is under way');
        expect(tasks.sync.isCompleted, isFalse, reason: 'and still running');
        expect(dialog, findsNothing);
        expect(titled('Casa'), findsOneWidget);
        expect(inPage(find.byType(CircularProgressIndicator)), findsNothing);
        final archive = find.text(es.groupArchive);
        await tester.scrollUntilVisible(archive, 200, scrollable: scrollable());
        await tester.pumpAndSettle();
        await tester.tap(archive);
        await tester.pump();
        await frames(tester);
        expect(api.archived, isTrue);
        expect(tasks.sync.isCompleted, isFalse);
        expect(find.text(es.groupRestore), findsOneWidget);
        expect(find.text(es.groupArchive), findsNothing);
        expect(bar(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final voice in [false, true]) {
      testWidgets(
        voice
            ? 'UX-2502: a failed spoken name keeps its dialog open with the typed name and the network message inside it'
            : 'UX-2502: a failed group rename keeps its dialog open with the typed name and the network message inside it',
        (tester) async {
            final api = await _openLiveGroup(
            tester,
            role: voice ? 'editor' : 'owner',
          );
          if (voice) {
            final menu = find.byTooltip(es.manageItem('Yo'));
            await tester.tap(menu);
            await tester.pumpAndSettle();
            await tester.tap(
              find.descendant(
                of: find.byType(PopupMenuItem<String>),
                matching: find.text(es.groupVoiceName),
              ),
            );
          } else {
            final rename = find.text(es.groupRename);
            await tester.scrollUntilVisible(
              rename,
              200,
              scrollable: scrollable(),
            );
            await tester.pumpAndSettle();
            await tester.tap(rename);
          }
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget);
          final field = find.descendant(
            of: dialog,
            matching: find.byType(TextFormField),
          );
          final typed = voice ? 'Mamá' : 'Casa de verano';
          await tester.enterText(field, typed);
          api.offline = true;
          await tester.tap(
            find.descendant(
              of: dialog,
              matching: find.widgetWithText(FilledButton, es.save),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            api.calls.last.take(2),
            voice
                ? ['POST', 'groups/familia/profile/']
                : ['PUT', 'groups/familia/'],
          );
          expect(dialog, findsOneWidget, reason: 'the dialog stays open');
          expect(
            tester
                .widget<EditableText>(
                  find.descendant(of: field, matching: find.byType(EditableText)),
                )
                .controller
                .text,
            typed,
          );
          expect(
            find.descendant(of: dialog, matching: find.text(network)),
            findsOneWidget,
          );
          expect(
            find.textContaining('Tus tareas siguen guardadas'),
            findsNothing,
          );
          expect(find.text(es.loadFailed), findsNothing);
          // The dialog's buttons work again.
          final save = tester.widget<FilledButton>(
            find.descendant(
              of: dialog,
              matching: find.widgetWithText(FilledButton, es.save),
            ),
          );
          expect(save.onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'UX-2513: (es, ${scale}x, 360x800) an invited person’s address wraps only after «@» or «.», and TalkBack reads it whole',
        (tester) async {
            final semantics = tester.ensureSemantics();
          await _openLiveGroup(tester, scale: scale);
          const address = 'carmen.lopez@example.com';
          final text = find.text(breakableAddress(address));
          await tester.scrollUntilVisible(text, 100, scrollable: scrollable());
          await tester.pumpAndSettle();
          expect(text, findsOneWidget);
          expectAddressWrapsWhole(tester, text, address);
          expect(spokenLabel(tester, text), contains(address));
          expect(tester.getRect(text).right, lessThanOrEqualTo(360.5));
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2518: (es, 2x, 360x800) the group invite dialog’s stacked «Cancelar» and «Enviar invitación» stand 8 dp or more apart',
      (tester) async {
        await _openLiveGroup(tester, scale: 2);
        final invite = find.text(es.invitePerson);
        await tester.scrollUntilVisible(invite, 200, scrollable: scrollable());
        await tester.pumpAndSettle();
        await tester.tap(invite);
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        final cancel = tester.getRect(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextButton, es.cancel),
          ),
        );
        final send = tester.getRect(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, es.sendInvitation),
          ),
        );
        final (upper, lower) = cancel.top <= send.top
            ? (cancel, send)
            : (send, cancel);
        expect(
          lower.top,
          greaterThanOrEqualTo(upper.bottom - 0.5),
          reason: 'stacked at 2x: $cancel, $send',
        );
        expect(
          lower.top - upper.bottom,
          greaterThanOrEqualTo(7.99),
          reason: 'the buttons stand apart',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('P285 · group page: delete, transfer, invite first, headings, no counters', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));

    test('UX-2504: the delete and transfer copy reads as the plan wrote it', () {
      expect(es.groupDeleteAction, 'Eliminar grupo');
      expect(en.groupDeleteAction, 'Delete group');
      expect(ca.groupDeleteAction, 'Suprimeix el grup');
      expect(
        es.groupDeleteConfirm('Familia'),
        '¿Eliminar «Familia»? Sus miembros dejarán de verlo. No se puede deshacer.',
      );
      expect(
        en.groupDeleteConfirm('Familia'),
        'Delete “Familia”? Its members will lose it. This can’t be undone.',
      );
      expect(
        ca.groupDeleteConfirm('Familia'),
        'Vols suprimir «Familia»? Els membres el deixaran de veure. No es pot desfer.',
      );
      expect(es.groupTransferConfirm('Familia', 'Ana'),
          '¿Transferir «Familia» a Ana?');
      expect(en.groupTransferConfirm('Familia', 'Ana'),
          'Transfer “Familia” to Ana?');
      expect(ca.groupTransferConfirm('Familia', 'Ana'),
          'Vols transferir «Familia» a Ana?');
      expect(es.groupTransferAction('Ana'), 'Transferir a Ana');
      expect(en.groupTransferAction('Ana'), 'Transfer to Ana');
      expect(ca.groupTransferAction('Ana'), 'Transfereix a Ana');
    });

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-2504: ($language) an empty group’s row reads Eliminar grupo with no subtitle; its confirmation says what deleting does, with a red Eliminar grupo button',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final api = await _openP285(tester, language: language, projects: 0);
          final row = find.widgetWithText(ListTile, l.groupDeleteAction);
          await tester.scrollUntilVisible(
            row,
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(tester.widget<ListTile>(row).subtitle, isNull);
          expect(find.text(l.groupDeleteHelp), findsNothing);
          expect(find.widgetWithText(ListTile, l.delete), findsNothing);
          await tester.tap(row);
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          expect(
            find.descendant(
              of: dialog,
              matching: find.text(l.groupDeleteConfirm('Familia')),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: dialog, matching: find.text(l.groupDeleteHelp)),
            findsNothing,
          );
          final confirm = find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, l.groupDeleteAction),
          );
          expect(confirm, findsOneWidget);
          final error = Theme.of(tester.element(confirm)).colorScheme.error;
          expect(
            tester
                .widget<FilledButton>(confirm)
                .style!
                .backgroundColor!
                .resolve({}),
            error,
          );
          // Nothing is sent before the confirmation.
          expect(api.calls.where((c) => c[0] == 'DELETE'), isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2504: a group with projects keeps its delete row off, with Solo puedes eliminar un grupo vacío… as its subtitle',
      (tester) async {
        await _openP285(tester, projects: 2);
        final row = find.widgetWithText(ListTile, es.groupDeleteAction);
        await tester.scrollUntilVisible(
          row,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        final tile = tester.widget<ListTile>(row);
        expect(tile.onTap, isNull, reason: 'the row is off');
        expect(
          find.descendant(of: row, matching: find.text(es.groupDeleteHelp)),
          findsOneWidget,
        );
        await tester.tap(row, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-2504: ($language) transferring to Ana: the sheet’s header is Transferir propiedad alone; the confirmation asks ¿Transferir «Familia» a Ana? with the help and Transferir a Ana',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final api = await _openP285(tester, language: language);
          final row = find.widgetWithText(ListTile, l.groupTransfer);
          await tester.scrollUntilVisible(
            row,
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          await tester.tap(row);
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          expect(sheet, findsOneWidget);
          final header = find.descendant(
            of: sheet,
            matching: find.widgetWithText(ListTile, l.groupTransfer),
          );
          expect(header, findsOneWidget);
          expect(tester.widget<ListTile>(header).subtitle, isNull);
          expect(
            find.descendant(of: sheet, matching: find.text(l.groupTransferHelp)),
            findsNothing,
          );
          await tester.tap(
            find.descendant(of: sheet, matching: find.text('Ana')),
          );
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          final title = tester.widget<AlertDialog>(dialog).title as Text;
          expect(title.data, l.groupTransferConfirm('Familia', 'Ana'));
          expect(
            find.descendant(
              of: dialog,
              matching: find.text(l.groupTransferHelp),
            ),
            findsOneWidget,
          );
          final confirm = find.descendant(
            of: dialog,
            matching: find.widgetWithText(
              FilledButton,
              l.groupTransferAction('Ana'),
            ),
          );
          expect(confirm, findsOneWidget);
          // The title isn't repeated as the button, nor the old «X: Ana».
          expect(
            find.descendant(
              of: dialog,
              matching: find.text(l.groupTransferConfirm('Familia', 'Ana')),
            ),
            findsOneWidget,
          );
          expect(find.text('${l.groupTransfer}: Ana'), findsNothing);
          expect(api.calls.where((c) => '${c[1]}'.contains('transfer')),
              isEmpty);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          final sent = api.calls.lastWhere(
            (c) => '${c[1]}'.contains('transfer'),
          );
          expect(sent.take(2), ['POST', 'groups/familia/transfer/']);
          expect((sent[2] as Map)['user_id'], 2);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'UX-2520: at ES ${scale}x on 360x800, for the owner Invitar a una persona is a filled button first, under the app bar and above Miembros, on screen without scrolling',
        (tester) async {
          await _openP285(tester, scale: scale, invited: true);
          final invite = find.widgetWithText(FilledButton, es.invitePerson);
          expect(invite, findsOneWidget);
          expect(find.widgetWithText(OutlinedButton, es.invitePerson),
              findsNothing);
          final button = tester.getRect(invite);
          final appBar = tester.getRect(find.byType(AppBar));
          final members = tester.getRect(find.text(es.groupMembers));
          expect(button.top, greaterThanOrEqualTo(appBar.bottom));
          expect(button.top - appBar.bottom, lessThanOrEqualTo(32));
          expect(button.bottom, lessThanOrEqualTo(members.top));
          expect(button.bottom, lessThanOrEqualTo(800),
              reason: 'visible on opening, at ${scale}x');
          // It leads the page: no list row or section sits above it.
          for (final above in [
            es.groupInvited,
            es.groupProjects,
            es.personYou('Yo'),
          ]) {
            final found = find.text(above);
            if (found.evaluate().isEmpty) continue;
            expect(tester.getRect(found.first).top,
                greaterThan(button.bottom), reason: above);
          }
          // Tapping it opens the invite dialog.
          await tester.tap(invite);
          await tester.pumpAndSettle();
          expect(find.text(es.inviteWho('Familia')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2520: a member who can’t manage the group has no Invitar a una persona',
      (tester) async {
        await _openP285(tester, role: 'editor');
        expect(find.text(es.invitePerson), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2519: on the group page Miembros, Invitados and Proyectos del grupo are headings',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _openP285(tester, invited: true);
        for (final title in [
          es.groupMembers,
          es.groupInvited,
          es.groupProjects,
        ]) {
          final found = find.text(title);
          await tester.scrollUntilVisible(
            found,
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          final node = tester.getSemantics(found);
          expect(node.label, title);
          expect(
            node.getSemanticsData().flagsCollection.isHeader,
            isTrue,
            reason: '«$title» is a heading',
          );
        }
        // A member's row is not.
        expect(
          tester
              .getSemantics(find.text(es.personYou('Yo')))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isFalse,
        );
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-2519: SectionLabel reads as a heading wherever it is used',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SectionLabel(es.pendingInvitations)),
          ),
        );
        final label = find.text(es.pendingInvitations.toUpperCase());
        expect(label, findsOneWidget);
        expect(
          tester.getSemantics(label).getSemanticsData().flagsCollection.isHeader,
          isTrue,
        );
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-2505: control: a field left with its default counter is caught as «0/80» and «Quedan 80 caracteres»',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AlertDialog(content: TextField(maxLength: 80)),
            ),
          ),
        );
        expect(find.textContaining(counterText), findsOneWidget);
        expect(find.bySemanticsLabel(counterSpeech), findsOneWidget);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-2505: the new group’s name field shows no 0/80 counter and still stops at 80',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpGroups(tester, const GroupsScreen());
        await tester.tap(find.text(es.newGroup));
        await tester.pumpAndSettle();
        await expectNoCounter(tester, 80);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-2505: the group invite’s email field shows no 0/254 counter and no Quedan 254 caracteres, and still stops at 254',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _openP285(tester);
        await tester.tap(find.widgetWithText(FilledButton, es.invitePerson));
        await tester.pumpAndSettle();
        await expectNoCounter(tester, 254);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-2505: renaming the group shows no 0/80 counter and still stops at 80',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _openP285(tester);
        final rename = find.text(es.groupRename);
        await tester.scrollUntilVisible(
          rename,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(rename);
        await tester.pumpAndSettle();
        await expectNoCounter(tester, 80);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-2505: the spoken name field shows no 0/60 counter and still stops at 60',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _openP285(tester, role: 'admin');
        await tester.tap(find.byTooltip(es.manageItem('Yo')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(es.groupVoiceName));
        await tester.pumpAndSettle();
        await expectNoCounter(tester, 60);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  });

  // ---- Run 2026-10-28-app, round 2 · P303 (UX-2627) ----

  group('P303 · an offline refresh on a group page says so', () {
    const network =
        'No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.';
    Finder inPage(Finder finder) =>
        find.descendant(of: find.byType(GroupScreen), matching: finder);

    /// Group `Familia` in Spanish at 1× on a 360×800 view, fed by a
    /// [_LiveGroup] server, with its project «Huerto» on the phone.
    Future<_LiveGroup> openWithProject(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _LiveGroup('owner');
      final container = ProviderContainer(
        retry: noRetry,
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
          taskRepositoryProvider.overrideWithValue(MemoryTasks()),
          taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          taskListsProvider.overrideWith(
            (ref) async => [
              TaskListInfo(
                id: 'huerto',
                name: 'Huerto',
                version: 1,
                groupId: 'familia',
                groupName: 'Familia',
                shared: true,
              ),
            ],
          ),
          groupsProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(api.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('es'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: child!,
            ),
            home: const GroupScreen(groupId: 'familia'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> pullToRefresh(WidgetTester tester) async {
      // From the very top, where a pull refreshes.
      final scrollable = inPage(find.byType(Scrollable)).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.fling(
        scrollable,
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      // The scroll, the indicator's settle and its hide.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets(
      'UX-2627: (es, 1x, 360x800) loaded, then offline, a pull-to-refresh keeps the members and projects on screen and shows the network message as a floating message',
      (tester) async {
        expect(es.requestError('network'), network);
        final api = await openWithProject(tester);
        expect(find.text(es.personYou('Yo')), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Huerto'),
          200,
          scrollable: inPage(find.byType(Scrollable)).first,
        );
        expect(find.text('Huerto'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(es.personYou('Yo')),
          -200,
          scrollable: inPage(find.byType(Scrollable)).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);

        api.offline = true;
        final asked = api.calls.where((call) => call[0] == 'GET').length;
        await pullToRefresh(tester);
        expect(
          api.calls.where((call) => call[0] == 'GET').length,
          greaterThan(asked),
          reason: 'the refresh asked the server again, and that failed',
        );

        final snack = find.byType(SnackBar);
        expect(snack, findsOneWidget);
        expect(
          tester.widget<SnackBar>(snack).behavior,
          SnackBarBehavior.floating,
        );
        expect(
          find.descendant(of: snack, matching: find.text(network)),
          findsOneWidget,
        );
        expect(find.textContaining('Tus tareas siguen guardadas'), findsNothing);
        // The page as it was: no load failure, its members and projects.
        expect(find.text(es.loadFailed), findsNothing);
        expect(find.byType(LoadFailed), findsNothing);
        expect(inPage(find.byType(RefreshIndicator)), findsOneWidget);
        expect(find.text(es.personYou('Yo')), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Huerto'),
          200,
          scrollable: inPage(find.byType(Scrollable)).first,
        );
        expect(find.text(es.groupProjects), findsOneWidget);
        expect(find.text('Huerto'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2627: (es, 1x, 360x800) online, a pull-to-refresh shows no message',
      (tester) async {
        final api = await openWithProject(tester);
        final asked = api.calls.where((call) => call[0] == 'GET').length;
        await pullToRefresh(tester);
        expect(
          api.calls.where((call) => call[0] == 'GET').length,
          greaterThan(asked),
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text(es.personYou('Yo')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// P285: group `Familia` in [language] at [scale] on a 360×800 view, with
/// [projects] projects. This account (Yo) has [role]; Ana is the other
/// member (the owner when Yo isn't). With [invited], Carmen is invited.
Future<_Groups> _openP285(
  WidgetTester tester, {
  String role = 'owner',
  String language = 'es',
  double scale = 1,
  int projects = 1,
  bool invited = false,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _Groups();
  final owner = role == 'owner';
  final container = ProviderContainer(
    retry: noRetry,
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      taskListsProvider.overrideWith((ref) async => []),
      groupsProvider.overrideWith((ref) async => []),
      pendingInvitationsProvider.overrideWith((ref) async => []),
      groupDetailsProvider('familia').overrideWith(
        (ref) async => {
          'group': {
            'id': 'familia',
            'name': 'Familia',
            'owner_id': owner ? 1 : 2,
            'version': 1,
            'role': role,
            'archived': false,
            'project_count': projects,
            'people': [
              {'user_id': 1, 'name': 'Yo', 'role': role},
              {'user_id': 2, 'name': 'Ana', 'role': owner ? 'editor' : 'owner'},
            ],
          },
          'invitations': [
            if (invited)
              {
                'id': 'inv-1',
                'email': 'carmen@example.invalid',
                'role': 'editor',
              },
          ],
        },
      ),
    ],
  );
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const GroupScreen(groupId: 'familia'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// P284: group `Familia` in Spanish at [scale] on a 360×800 view, fed by a
/// [_LiveGroup] server through the app's own provider, where this account
/// (Yo) has [role]; Carmen is invited. Opened from a page underneath.
Future<_LiveGroup> _openLiveGroup(
  WidgetTester tester, {
  String role = 'owner',
  double scale = 1,
  TaskNotifier? tasks,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _LiveGroup(role);
  final container = ProviderContainer(
    retry: noRetry,
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => tasks ?? DesignTaskNotifier()),
      taskListsProvider.overrideWith((ref) async => []),
      groupsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(api.close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('es'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
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

/// P284: the server of group `familia`. A change takes effect at once and
/// the next GET shows it; [hold] keeps a change waiting; [offline] fails
/// every request as a lost connection.
class _LiveGroup extends OfflineApiClient {
  _LiveGroup(this.role);
  final String role;
  final calls = <List<Object?>>[];
  bool offline = false;
  Completer<void>? hold;
  String name = 'Familia';
  bool archived = false;
  int version = 1;
  String voiceName = '';
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
    if (offline) throw ApiException(0, 'offline');
    if (method == 'GET' && path == 'groups/familia/sharing/') {
      return {
        'group': {
          'id': 'familia',
          'name': name,
          'owner_id': role == 'owner' ? 1 : 2,
          'version': version,
          'role': role,
          'archived': archived,
          'project_count': 1,
          'people': [
            {'user_id': 1, 'name': 'Yo', 'role': role, 'voice_name': voiceName},
            if (role == 'owner')
              {'user_id': 2, 'name': 'Ana', 'role': 'editor'}
            else
              {'user_id': 2, 'name': 'Ana', 'role': 'owner'},
          ],
        },
        'invitations': [
          {'id': 'inv-1', 'email': 'carmen.lopez@example.com', 'role': 'editor'},
        ],
      };
    }
    if (hold != null) await hold!.future;
    if (method == 'PUT' && path == 'groups/familia/') {
      name = data?['name'] as String? ?? name;
      archived = data?['archived'] == true;
      version++;
      return {'version': version};
    }
    if (method == 'POST' && path == 'groups/familia/profile/') {
      voiceName = data?['voice_name'] as String? ?? '';
      return {};
    }
    return {};
  }
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
    retry: noRetry,
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
  Map<String, dynamic> Function(Map<String, dynamic>? data)? onPost;
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
    if (method == 'POST' && onPost != null) return onPost!(data);
    return {};
  }
}
