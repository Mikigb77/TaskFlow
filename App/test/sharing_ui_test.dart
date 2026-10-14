import 'package:agenda/screens/task_lists_screen.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/invitation_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets(
      'All languages invite as an editor at 2x text in both themes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (language, dark) in [
      ('en', false),
      ('en', true),
      ('es', false),
      ('es', true),
      ('ca', false),
      ('ca', true)
    ]) {
      final strings = lookupAppLocalizations(Locale(language));
      final api = _Api();
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _Auth(api)),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        listSharingProvider.overrideWith((ref, id) async => {
              'list': {'name': 'Household', 'role': 'owner', 'version': 1},
              'members': [],
              'invitations': []
            }),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: Locale(language),
              theme: dark ? AppTheme.dark : AppTheme.light,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const ListSharingScreen(listId: 'household'))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('invite-person')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invite-person')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('invite-email'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'friend@example.invalid');
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.sendInvitation));
      await tester.pumpAndSettle();
      // Everyone joins as an editor.
      expect(api.payload,
          {'email': 'friend@example.invalid', 'role': 'editor'});
      expect(find.byKey(const ValueKey('invitation-code')), findsOneWidget);
      await tester.tap(find.text(strings.done));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      api.close();
    }
  });

  testWidgets('Spanish invitation validation keeps the exact accepted code',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Api();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => _Auth(api)),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      pendingInvitationsProvider.overrideWith((ref) async => [
            PendingInvitation.fromJson('list', {
              'id': 'invitation-fixture',
              'list_name': 'Do not translate my list',
              'role': 'viewer'
            })
          ]),
    ]);
    addTearDown(container.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(body: ListView(children: const [PendingInvitations()])),
      ),
    ));
    await tester.pumpAndSettle();
    final card = find.text('Te han invitado a Do not translate my list · Ver');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(find.text('Pega el código de invitación completo.'), findsOneWidget);
    expect(api.payload, isNull);
    const code = 'Synthetic-Case-Sensitive-Code_2026';
    final field = find.byKey(const ValueKey('accept-invitation-code'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '  $code  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(api.payload, {'decision': 'accept', 'code': code});
    expect(api.path, 'invitations/invitation-fixture/respond/');
    // Let the joined message finish waiting for its timeout.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  // ---- P13 / P15: sharing from the project, shorter invitations ----

  final es = lookupAppLocalizations(const Locale('es'));
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  setUp(() =>
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000));
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));

  const owner = ProjectMember(id: 1, name: 'Yo', role: 'owner');
  const ana = ProjectMember(id: 2, name: 'Ana', role: 'editor');

  /// The app in Spanish on [project]'s own page.
  Future<ProviderContainer> openProjectPage(
      WidgetTester tester, TaskListInfo project) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      projects: [project],
      regionalStore:
          MemoryRegionalStore(const RegionalPreferences(language: 'es')),
      overrides: [
        listSharingProvider.overrideWith((ref, id) async => {
              'list': {'name': project.name, 'role': 'owner', 'version': 1},
              'members': [],
              'invitations': []
            }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(
            builder: (_) => HomeScreen(isRoot: false, listId: project.id)));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
      'UX-305: an unshared project of your own shows Compartir on its page, which opens sharing',
      (tester) async {
    expect(es.shareProject, 'Compartir');
    await openProjectPage(
        tester, TaskListInfo(id: 'casa', name: 'Casa', version: 3));
    final share = find.widgetWithText(TextButton, es.shareProject);
    expect(share, findsOneWidget);
    expect(find.textContaining('Miembros ·'), findsNothing);
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(find.byType(ListSharingScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-person')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-305 / UX-301: once shared, the page reads Miembros · 2 (owner included); the mute choice reads Silenciado: sin novedades ni recordatorios',
      (tester) async {
    await openProjectPage(
        tester,
        TaskListInfo(
            id: 'casa',
            name: 'Casa',
            version: 3,
            shared: true,
            ownerId: 1,
            people: const [owner, ana]));
    expect(es.projectMembersCount(2), 'Miembros · 2');
    expect(find.widgetWithText(TextButton, es.projectMembersCount(2)),
        findsOneWidget);
    expect(find.widgetWithText(TextButton, es.shareProject), findsNothing);
    final bell = find.byTooltip(es.projectNotifications);
    await tester.ensureVisible(bell);
    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(es.updatesMuted, 'Silenciado: sin novedades ni recordatorios');
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text(es.updatesMuted)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-305: the invite dialog is a title, one autofocused email field, one sentence and Enviar invitación, with no access choice; the code dialog is Invitación enviada plus one line',
      (tester) async {
    final app = await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [],
      'invitations': []
    });
    await tester.tap(find.byKey(const ValueKey('invite-person')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(es.shareProjectTitle('Casa'), 'Compartir Casa');
    expect(es.theirEmail, 'Su correo');
    expect(es.shareProjectHelp('Casa'), 'Verá todo lo que hay en Casa.');
    expect(es.sendInvitation, 'Enviar invitación');
    final fields =
        find.descendant(of: dialog, matching: find.byType(TextField));
    expect(fields, findsOneWidget);
    expect(tester.widget<TextField>(fields).autofocus, isTrue);
    expect(
        tester.widget<TextField>(fields).decoration!.labelText, es.theirEmail);
    // No access choice: no dropdown, no Editor or Lector.
    expect(
        find.descendant(
            of: dialog,
            matching: find.byWidgetPredicate((w) =>
                w is DropdownButton ||
                w is DropdownButtonFormField ||
                w is DropdownMenu ||
                w is RadioListTile ||
                w is SegmentedButton)),
        findsNothing);
    expect(find.descendant(of: dialog, matching: find.text(es.roleEditor)),
        findsNothing);
    expect(find.descendant(of: dialog, matching: find.text(es.roleViewer)),
        findsNothing);
    final texts = tester
        .widgetList<Text>(
            find.descendant(of: dialog, matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(
        texts.toSet(),
        {
          es.shareProjectTitle('Casa'),
          es.theirEmail,
          es.shareProjectHelp('Casa'),
          es.cancel,
          es.sendInvitation,
        },
        reason:
            'only the title, the label, one sentence and the buttons: $texts');
    await tester.enterText(fields, 'ana@example.invalid');
    await tester.tap(find.widgetWithText(FilledButton, es.sendInvitation));
    await tester.pumpAndSettle();
    expect(app.api.calls.last.$2, 'lists/casa/invite/');
    expect(app.api.calls.last.$3,
        {'email': 'ana@example.invalid', 'role': 'editor'});

    final sent = find.byType(AlertDialog);
    expect(es.invitationSent, 'Invitación enviada');
    expect(es.invitationCodeFallback,
        'Si no le llega el correo, envíale este código:');
    final sentTexts = tester
        .widgetList<Text>(
            find.descendant(of: sent, matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(
        sentTexts.toSet(),
        {
          es.invitationSent,
          es.invitationCodeFallback,
          es.copyCode,
          es.done,
        },
        reason: 'the title, one line, Copiar código and Listo: $sentTexts');
    expect(
        find.descendant(
            of: sent, matching: find.byKey(const ValueKey('invitation-code'))),
        findsOneWidget);
    expect(find.text(_Recorder.code), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-305: a project not yet synced says Conéctate a internet para compartir. instead of offering the invite',
      (tester) async {
    expect(es.connectToShare, 'Conéctate a internet para compartir.');
    await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [],
      'invitations': []
    }, projects: [
      TaskListInfo(id: 'casa', name: 'Casa', version: 0)
    ]);
    expect(find.text(es.connectToShare), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-person')), findsNothing);
    expect(find.text(es.invitePerson), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-318: tapping a pending invitation does nothing; its ⋮ offers Reenviar and Anular invitación',
      (tester) async {
    expect(es.sendInvitationAgain, 'Reenviar');
    expect(es.cancelInvitation, 'Anular invitación');
    final app = await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [],
      'invitations': [
        {'id': 'inv-1', 'email': 'ana@example.invalid', 'role': 'editor'}
      ]
    });
    final row = find.widgetWithText(ListTile, 'ana@example.invalid');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final before = app.api.calls.length;
    await tester.tap(find.text('ana@example.invalid'));
    await tester.pumpAndSettle();
    expect(app.api.calls.length, before, reason: 'no request on tap');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.widget<ListTile>(row).onTap, isNull);
    // The help line about tapping to replace the code is gone.
    expect(find.textContaining('invitación pendiente para'), findsNothing);

    final menu = find.byTooltip(es.manageItem('ana@example.invalid'));
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text(es.sendInvitationAgain), findsOneWidget);
    expect(find.text(es.cancelInvitation), findsOneWidget);
    // Cancelling is destructive: it reads in the error colour.
    final error = Theme.of(tester.element(row)).colorScheme.error;
    expect(tester.widget<Text>(find.text(es.cancelInvitation)).style?.color,
        error);
    await tester.tap(find.text(es.sendInvitationAgain));
    await tester.pumpAndSettle();
    expect(app.api.calls.last.$2, 'lists/casa/invite/');
    expect(app.api.calls.last.$3?['email'], 'ana@example.invalid');
    await tester.tap(find.text(es.done));
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.cancelInvitation));
    await tester.pumpAndSettle();
    expect(app.api.calls.last.$2, 'lists/casa/revoke_invite/');
    expect(app.api.calls.last.$3, {'invitation_id': 'inv-1'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      "UX-339 / UX-316: the owner's sharing screen has no Tu rol line, no sync help and no empty heading; people with access are Miembros",
      (tester) async {
    await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [],
      'invitations': []
    });
    expect(find.textContaining(es.yourRole('').trim()), findsNothing);
    expect(find.text(es.sharingHelp), findsNothing);
    Finder label(String text) =>
        find.byWidgetPredicate((w) => w is SectionLabel && w.text == text);
    expect(label(es.pendingInvitations), findsNothing);
    expect(es.people, 'Miembros');
    expect(label(es.people), findsOneWidget);
    // Not empty: it says nobody else has access yet.
    expect(find.text(es.noOtherMembers), findsOneWidget);
    expect(find.textContaining('Personas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("UX-339: someone else's project still says their role",
      (tester) async {
    await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'editor', 'version': 1},
      'members': [],
      'invitations': []
    });
    expect(find.text(es.yourRole(es.roleEditor)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-340 / UX-317: leaving a project asks in red, closes sharing and says Has salido de Casa',
      (tester) async {
    expect(es.youLeft('Casa'), 'Has salido de Casa');
    final app = await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'editor', 'version': 1},
      'members': [],
      'invitations': []
    });
    final leave = find.widgetWithText(OutlinedButton, es.leaveList);
    await tester.ensureVisible(leave);
    await tester.pumpAndSettle();
    final error = Theme.of(tester.element(leave)).colorScheme.error;
    expect(
        tester.widget<OutlinedButton>(leave).style!.foregroundColor!.resolve({}),
        error);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.leaveList));
    expect(
        tester.widget<FilledButton>(confirm).style!.backgroundColor!.resolve({}),
        error);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(app.api.calls.last.$2, 'lists/casa/leave/');
    expect(find.byType(ListSharingScreen), findsNothing);
    expect(find.text(es.youLeft('Casa')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-340 / UX-317: deleting a project from sharing asks in red, closes it and says Proyecto eliminado',
      (tester) async {
    expect(es.projectDeleted, 'Proyecto eliminado');
    final app = await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 4},
      'members': [
        {'user_id': 2, 'user__email': 'ana@example.invalid', 'role': 'editor'}
      ],
      'invitations': []
    });
    // Removing a member is destructive too.
    await tester.tap(find.byTooltip(es.manageItem('ana@example.invalid')));
    await tester.pumpAndSettle();
    final error = Theme.of(tester.element(find.byType(ListSharingScreen)))
        .colorScheme
        .error;
    expect(tester.widget<Text>(find.text(es.removeAccess)).style?.color, error);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    final delete =
        find.widgetWithText(OutlinedButton, es.deleteListForEveryone);
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(delete)
            .style!
            .foregroundColor!
            .resolve({}),
        error);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.deleteList)));
    await tester.pumpAndSettle();
    expect(app.api.calls.last.$1, 'DELETE');
    expect(app.api.calls.last.$2, 'lists/casa/');
    expect(find.byType(ListSharingScreen), findsNothing);
    expect(find.text(es.projectDeleted), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---- P73 (UX-476, UX-477): removing a project closes its page ----

  /// The app in Spanish on Projects, with [projects] on the phone and a
  /// server whose deletes and leaves succeed (and remove the project).
  Future<_RemovingApi> openProjectsApp(
      WidgetTester tester, List<TaskListInfo> projects, String role) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _RemovingApi(projects);
    final container = designContainer(
      projects: projects,
      api: api,
      regionalStore:
          MemoryRegionalStore(const RegionalPreferences(language: 'es')),
      overrides: [
        pendingInvitationsProvider.overrideWith((ref) async => []),
        groupsProvider.overrideWith((ref) async => []),
        listSharingProvider.overrideWith((ref, id) async => {
              'list': {
                'name': projects.firstWhere((p) => p.id == id).name,
                'role': role,
                'version': 2
              },
              'members': [],
              'invitations': []
            }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/lists');
    await tester.pumpAndSettle();
    return api;
  }

  Finder projectPage(String id) =>
      find.byWidgetPredicate((w) => w is HomeScreen && w.listId == id,
          skipOffstage: false);

  bool projectsOnTop(WidgetTester tester) =>
      ModalRoute.of(tester.element(find.byType(TaskListsScreen)))!.isCurrent;

  testWidgets(
      'UX-476: deleting Compras from its page (Compartir → Eliminar proyecto) lands on Projects with Proyecto eliminado, and no Compras page is left',
      (tester) async {
    final api = await openProjectsApp(
        tester, [TaskListInfo(id: 'compras', name: 'Compras', version: 2)],
        'owner');
    await tester.tap(find.widgetWithText(ListTile, 'Compras'));
    await tester.pumpAndSettle();
    expect(projectPage('compras'), findsOneWidget);
    final share = find.widgetWithText(TextButton, es.shareProject);
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pumpAndSettle();
    final delete = find.widgetWithText(OutlinedButton, es.deleteList);
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.deleteList)));
    await tester.pumpAndSettle();
    expect(api.calls, [('DELETE', 'lists/compras/')]);
    expect(find.byType(ListSharingScreen), findsNothing);
    expect(projectPage('compras'), findsNothing,
        reason: 'no HomeScreen for the deleted project is left anywhere');
    expect(projectsOnTop(tester), isTrue);
    expect(find.text(es.projectDeleted).hitTestable(), findsOneWidget);
    // Shown once.
    expect(find.text(es.projectDeleted), findsOneWidget);
    // Back doesn't return to an empty Proyecto page.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(projectPage('compras'), findsNothing);
    expect(find.text(es.list), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-476: an editor leaving Casa from its page (Miembros · 2 → Salir del proyecto) closes the page and says Has salido de Casa below',
      (tester) async {
    final api = await openProjectsApp(
        tester,
        [
          TaskListInfo(
              id: 'casa',
              name: 'Casa',
              version: 2,
              shared: true,
              role: 'editor',
              ownerId: 1,
              people: const [owner, ana])
        ],
        'editor');
    await tester.tap(find.widgetWithText(ListTile, 'Casa'));
    await tester.pumpAndSettle();
    final members = find.widgetWithText(TextButton, es.projectMembersCount(2));
    expect(es.projectMembersCount(2), 'Miembros · 2');
    await tester.ensureVisible(members);
    await tester.tap(members);
    await tester.pumpAndSettle();
    final leave = find.widgetWithText(OutlinedButton, es.leaveList);
    await tester.ensureVisible(leave);
    await tester.pumpAndSettle();
    await tester.tap(leave);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.leaveList)));
    await tester.pumpAndSettle();
    expect(api.calls, [('POST', 'lists/casa/leave/')]);
    expect(find.byType(ListSharingScreen), findsNothing);
    expect(projectPage('casa'), findsNothing);
    expect(projectsOnTop(tester), isTrue);
    expect(find.text(es.youLeft('Casa')).hitTestable(), findsOneWidget);
    expect(find.text(es.youLeft('Casa')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-476: Projects ⋮ → Compartir → delete stays on Projects (not one screen too far) and says Proyecto eliminado',
      (tester) async {
    final api = await openProjectsApp(
        tester, [TaskListInfo(id: 'compras', name: 'Compras', version: 2)],
        'owner');
    await tester.tap(find.byTooltip(es.manageItem('Compras')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.shareProject));
    await tester.pumpAndSettle();
    expect(find.byType(ListSharingScreen), findsOneWidget);
    final delete = find.widgetWithText(OutlinedButton, es.deleteList);
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.deleteList)));
    await tester.pumpAndSettle();
    expect(api.calls, [('DELETE', 'lists/compras/')]);
    expect(find.byType(ListSharingScreen), findsNothing);
    expect(find.byType(TaskListsScreen), findsOneWidget);
    expect(projectsOnTop(tester), isTrue);
    expect(find.text(es.projectDeleted).hitTestable(), findsOneWidget);
    expect(find.text(es.projectDeleted), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-477: on the sharing screen of an unshared project you own, the button reads Eliminar proyecto and asks with «Casa» and no para todas',
      (tester) async {
    expect(es.deleteList, 'Eliminar proyecto');
    expect(es.deleteListPrivateHelp('Casa'),
        '¿Eliminar «Casa» con todas sus tareas, notas y archivos? No se puede deshacer.');
    await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [],
      'invitations': []
    }, projects: [
      TaskListInfo(id: 'casa', name: 'Casa', version: 1)
    ]);
    final delete = find.widgetWithText(OutlinedButton, es.deleteList);
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    expect(delete, findsOneWidget);
    expect(find.text(es.deleteListForEveryone), findsNothing);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(es.deleteListPrivateHelp('Casa'))),
        findsOneWidget);
    expect(find.textContaining('para todas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-477: on the sharing screen of a shared project, the button reads Eliminar el proyecto para todos and asks with deleteListHelp',
      (tester) async {
    expect(es.deleteListForEveryone, 'Eliminar el proyecto para todos');
    await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [],
      'invitations': []
    }, projects: [
      TaskListInfo(id: 'casa', name: 'Casa', version: 1, shared: true)
    ]);
    final delete =
        find.widgetWithText(OutlinedButton, es.deleteListForEveryone);
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    expect(delete, findsOneWidget);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(es.deleteListHelp)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'UX-480: the member-limit message names Anular invitación in every language, never revoke',
      () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(es.sharingProblem('memberLimit'),
        'Este proyecto admite hasta 20 miembros y 20 invitaciones pendientes. Primero elimina a alguien o anula una invitación.');
    expect(en.sharingProblem('memberLimit'),
        'This project supports up to 20 members and 20 pending invitations. Remove someone or cancel an invitation first.');
    expect(ca.sharingProblem('memberLimit'),
        'Aquest projecte admet fins a 20 membres i 20 invitacions pendents. Primer elimina algú o anul·la una invitació.');
    for (final strings in [es, en, ca]) {
      final text = strings.sharingProblem('memberLimit').toLowerCase();
      expect(text.contains('revoca'), isFalse, reason: text);
      expect(text.contains('revoke'), isFalse, reason: text);
    }
  });

  testWidgets('viewer sees task and checklist with disabled editing controls',
      (tester) async {
    final api = _Api();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => _Auth(api)),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => _ViewerTask()),
      taskListsProvider.overrideWith((ref) async => [
            TaskListInfo(
                id: 'household',
                name: 'Household',
                shared: true,
                role: 'viewer',
                version: 1)
          ]),
      attachmentEntriesProvider.overrideWith((ref, id) async => []),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(container.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TaskDetailScreen(taskId: 1))));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.byTooltip('Edit task'), findsNothing);
    expect(find.byTooltip('Delete task'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 180);
    expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull);
    expect(tester.takeException(), isNull);
  });
}

class _Api extends OfflineApiClient {
  Map<String, dynamic>? payload;
  String? path;
  @override
  Account get account => Account.fromJson(
      {'id': 1, 'email': 'owner@example.invalid', 'timezone': 'UTC'});
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    payload = data;
    this.path = path;
    return {'code': 'synthetic-invitation-code-only'};
  }
}

class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {
    state = AuthState(account: api.account);
  }
}

class _ViewerTask extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = AsyncData([
      Task(
          id: 1,
          title: 'Milk',
          priority: 1,
          listId: 'household',
          checklist: [ChecklistItem(title: 'Two cartons')])
    ]);
  }
}

/// Every request, with a code for invitations.
class _Recorder extends OfflineApiClient {
  static const code = 'synthetic-invitation-code-only';
  final calls = <(String, String, Map<String, dynamic>?)>[];
  @override
  Account get account => Account.fromJson(
      {'id': 1, 'email': 'owner@example.invalid', 'timezone': 'UTC'});
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    calls.add((method, path, data));
    return path.endsWith('invite/') ? {'code': code} : {};
  }
}

/// The sharing screen of project `casa` in Spanish, opened from a page
/// underneath so closing it can be seen.
class _SharingApp {
  _SharingApp(this.api, this.container);
  final _Recorder api;
  final ProviderContainer container;

  static Future<_SharingApp> open(
      WidgetTester tester, Map<String, dynamic> data,
      {List<TaskListInfo> projects = const []}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _Recorder();
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => _Auth(api)),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      taskListsProvider.overrideWith((ref) async => projects),
      listSharingProvider.overrideWith((ref, id) async => data),
    ]);
    addTearDown(container.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            locale: const Locale('es'),
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
                builder: (context) => Scaffold(
                    body: Center(
                        child: TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => const ListSharingScreen(
                                        listId: 'casa'))),
                            child: const Text('Abrir'))))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    return _SharingApp(api, container);
  }
}

/// The server for P73: deletes and leaves succeed, and the project is gone
/// from the phone's list afterwards. Anything else goes nowhere.
class _RemovingApi extends OfflineApiClient {
  _RemovingApi(this.projects);
  final List<TaskListInfo> projects;
  final calls = <(String, String)>[];
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    final match = RegExp(r'^lists/([^/]+)/(leave/)?$').firstMatch(path);
    if (match != null &&
        ((method == 'DELETE' && match.group(2) == null) ||
            (method == 'POST' && match.group(2) != null))) {
      calls.add((method, path));
      projects.removeWhere((p) => p.id == match.group(1));
      return {};
    }
    return super.request(method, path,
        data: data,
        audioPath: audioPath,
        authenticated: authenticated,
        accountId: accountId);
  }
}
