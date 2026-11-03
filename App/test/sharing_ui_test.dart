import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/l10n/region.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'support/hanging_sync.dart';
import 'support/address_wrap.dart';
import 'package:flutter/rendering.dart';
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
      final container = ProviderContainer(retry: noRetry, overrides: [
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
    final container = ProviderContainer(retry: noRetry, overrides: [
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
    // Project updates live on the sharing screen, not behind a bell (UX-322).
    final members = find.widgetWithText(TextButton, es.projectMembersCount(2));
    await tester.ensureVisible(members);
    await tester.tap(members);
    await tester.pumpAndSettle();
    final updates = find.text(es.projectNotifications);
    await tester.ensureVisible(updates);
    await tester.tap(updates);
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
    expect(es.inviteWho('Casa'), '¿A quién invitas a Casa?');
    expect(es.email, 'Correo');
    expect(es.shareProjectHelp('Casa'),
        'Esa persona verá todo lo que hay en Casa.');
    expect(es.sendInvitation, 'Enviar invitación');
    final fields =
        find.descendant(of: dialog, matching: find.byType(TextField));
    expect(fields, findsOneWidget);
    expect(tester.widget<TextField>(fields).autofocus, isTrue);
    expect(
        tester.widget<TextField>(fields).decoration!.labelText, es.email);
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
          es.inviteWho('Casa'),
          es.email,
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
    final row =
        find.widgetWithText(ListTile, breakableAddress('ana@example.invalid'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final before = app.api.calls.length;
    await tester.tap(find.text(breakableAddress('ana@example.invalid')));
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
    expect(find.textContaining('Tu rol'), findsNothing);
    expect(find.textContaining('Comparte compras'), findsNothing);
    Finder label(String text) =>
        find.byWidgetPredicate((w) => w is SectionLabel && w.text == text);
    expect(label(es.pendingInvitations), findsNothing);
    expect(es.people, 'Miembros');
    // Shared (no local copy says otherwise): «Miembros» is the app bar's
    // title, so no section label repeats it (UX-1643).
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(es.people)),
        findsOneWidget);
    expect(label(es.people), findsNothing);
    // Not empty: it says nobody else has access yet.
    expect(find.text(es.noOtherMembers), findsOneWidget);
    expect(find.textContaining('Personas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      "UX-339 / UX-1506: someone else's project shows their role on their own row",
      (tester) async {
    await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'editor', 'version': 1},
      'members': [],
      'invitations': []
    }, projects: [
      TaskListInfo(
          id: 'casa',
          name: 'Casa',
          version: 1,
          role: 'editor',
          shared: true,
          people: const [
            ProjectMember(id: 2, name: 'Ana', role: 'owner'),
            ProjectMember(id: 1, name: 'María', role: 'editor'),
          ])
    ]);
    expect(find.widgetWithText(ListTile, es.personYou('María')),
        findsOneWidget);
    expect(find.widgetWithText(ListTile, es.roleEditor), findsOneWidget);
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
      'UX-476: deleting Compras from its page (⋮ → Eliminar proyecto) lands on Projects with Proyecto eliminado, and no Compras page is left',
      (tester) async {
    final api = await openProjectsApp(
        tester, [TaskListInfo(id: 'compras', name: 'Compras', version: 2)],
        'owner');
    await tester.tap(find.widgetWithText(ListTile, 'Compras'));
    await tester.pumpAndSettle();
    expect(projectPage('compras'), findsOneWidget);
    // P286: an unshared project is deleted from its page's ⋮.
    await tester.tap(find.byTooltip(es.manageItem('Compras')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.deleteList));
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
      'UX-476: Projects ⋮ → Miembros → delete stays on Projects (not one screen too far) and says Proyecto eliminado',
      (tester) async {
    // Shared: an unshared project's sharing page has no delete (P286).
    final api = await openProjectsApp(tester, [
      TaskListInfo(id: 'compras', name: 'Compras', version: 2, shared: true)
    ], 'owner');
    await tester.tap(find.byTooltip(es.manageItem('Compras')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.people));
    await tester.pumpAndSettle();
    expect(find.byType(ListSharingScreen), findsOneWidget);
    final delete =
        find.widgetWithText(OutlinedButton, es.deleteListForEveryone);
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
      'UX-477 / P286: the sharing screen of an unshared project you own has no delete button',
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
    expect(find.widgetWithText(OutlinedButton, es.deleteList), findsNothing);
    expect(find.text(es.deleteList), findsNothing);
    expect(find.text(es.deleteListForEveryone), findsNothing);
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
    final container = ProviderContainer(retry: noRetry, overrides: [
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

  // ---- Round 1 (b9) · P25 (UX-322) and P27 (UX-330) ----

  testWidgets(
      'UX-322: a shared project’s page has no bell; its sharing screen has Novedades del proyecto, which opens the update choice',
      (tester) async {
    expect(es.projectNotifications, 'Novedades del proyecto');
    await openProjectPage(
        tester,
        TaskListInfo(
            id: 'casa',
            name: 'Casa',
            version: 3,
            shared: true,
            ownerId: 1,
            people: const [owner, ana]));
    expect(find.byTooltip(es.projectNotifications), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.text(es.projectNotifications), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [],
      'invitations': []
    }, projects: [
      TaskListInfo(
          id: 'casa',
          name: 'Casa',
          version: 1,
          shared: true,
          ownerId: 1,
          people: const [owner, ana])
    ]);
    final row = find.widgetWithText(ListTile, es.projectNotifications);
    await tester.scrollUntilVisible(row, 120,
        scrollable: find.byType(Scrollable).last);
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text(es.updatesMuted)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-330: ListSharingScreen shows each person’s name first and the email second, falling back to the email',
      (tester) async {
    await _SharingApp.open(tester, {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [
        {'user_id': 2, 'user__email': 'ana@example.invalid', 'role': 'editor'},
        {'user_id': 7, 'user__email': 'luis@example.invalid', 'role': 'viewer'},
      ],
      'invitations': []
    }, projects: [
      TaskListInfo(
          id: 'casa',
          name: 'Casa',
          version: 1,
          shared: true,
          ownerId: 1,
          people: const [owner, ana])
    ]);
    final anaRow = find.widgetWithText(ListTile, 'Ana');
    await tester.scrollUntilVisible(anaRow, 120,
        scrollable: find.byType(Scrollable).last);
    final tile = tester.widget<ListTile>(anaRow);
    expect((tile.title as Text).data, 'Ana');
    expect((tile.subtitle as Text).data,
        '${breakableAddress('ana@example.invalid')} · ${es.roleEditor}');
    // Someone the project doesn't name yet: their email.
    final luis =
        find.widgetWithText(ListTile, breakableAddress('luis@example.invalid'));
    await tester.scrollUntilVisible(luis, 120,
        scrollable: find.byType(Scrollable).last);
    expect((tester.widget<ListTile>(luis).title as Text).data,
        breakableAddress('luis@example.invalid'));
    expect(tester.takeException(), isNull);
  });

  // ---- Run 2026-10-19-app, round 1 · P181 (UX-1503, UX-1513, UX-1506) and
  // P183 (UX-1510) on a project's sharing page ----

  const ownerData = {
    'list': {'name': 'Matemáticas', 'role': 'owner', 'version': 1},
    'members': [],
    'invitations': [],
  };

  for (final language in ['es', 'ca']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'UX-1503: ($language, ${scale}x, 360x800) the project invite asks who you are inviting to Matemáticas, labels the field with the plain word for email, whole while it floats, and says that person sees everything',
          (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        if (language == 'es') {
          expect(l.inviteWho('Matemáticas'), '¿A quién invitas a Matemáticas?');
          expect(l.email, 'Correo');
          expect(l.shareProjectHelp('Matemáticas'),
              'Esa persona verá todo lo que hay en Matemáticas.');
        } else {
          expect(l.inviteWho('Matemáticas'), 'A qui convides a Matemáticas?');
          expect(l.email, 'Correu');
          expect(l.shareProjectHelp('Matemáticas'),
              'Aquesta persona veurà tot el que hi ha a Matemáticas.');
        }
        await _openSharing(tester,
            data: ownerData, language: language, scale: scale);
        final invite = find.byKey(const ValueKey('invite-person'));
        await tester.ensureVisible(invite);
        await tester.pumpAndSettle();
        await tester.tap(invite);
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(
            find.descendant(
                of: dialog, matching: find.text(l.inviteWho('Matemáticas'))),
            findsOneWidget);
        expect(
            find.descendant(
                of: dialog,
                matching: find.text(l.shareProjectHelp('Matemáticas'))),
            findsOneWidget);
        // The field has focus, so its label floats above it, whole.
        final field = find.byKey(const ValueKey('invite-email'));
        final label = find.descendant(of: field, matching: find.text(l.email));
        expect(label, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
            of: label, matching: find.byType(RichText), matchRoot: true));
        expect(paragraph.didExceedMaxLines, isFalse,
            reason: '«${l.email}» is not cut');
        expect(paragraph.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.size.width + 0.5),
            reason: '«${l.email}» fits its line');
        // The formal wording is gone.
        expect(find.textContaining('Su correo'), findsNothing);
        expect(find.textContaining('El seu correu'), findsNothing);
        expect(find.textContaining('Correo de su cuenta'), findsNothing);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      });
    }
  }

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
        'UX-1503: ($language) typing your own address in the project invite, trimmed and in capitals, says it is your own email and sends nothing',
        (tester) async {
      final l = lookupAppLocalizations(Locale(language));
      expect(
          l.inviteOwnEmail,
          switch (language) {
            'es' => 'Ese es tu correo. Escribe el de la persona que invitas.',
            'en' => 'That’s your own email. Type the other person’s.',
            _ => 'Aquest és el teu correu. Escriu el de la persona que convides.',
          });
      final (api, _) =
          await _openSharing(tester, data: ownerData, language: language);
      await tester.tap(find.byKey(const ValueKey('invite-person')));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      // The account is owner@example.invalid.
      await tester.enterText(
          find.byKey(const ValueKey('invite-email')), '  OWNER@Example.invalid ');
      await tester.tap(find.widgetWithText(FilledButton, l.sendInvitation));
      await tester.pumpAndSettle();
      expect(find.descendant(of: dialog, matching: find.text(l.inviteOwnEmail)),
          findsOneWidget);
      expect(dialog, findsOneWidget, reason: 'the dialog stays open');
      expect(api.calls.where((call) => call.$2.endsWith('invite/')), isEmpty,
          reason: 'no invitation is sent');
      expect(find.text(l.invitationSent), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'UX-1513: on a project member’s ⋮, an editor’s menu has no Dar permiso de edición; a viewer’s has it and no Dar permiso de lectura',
      (tester) async {
    expect(es.makeEditor, 'Dar permiso de edición');
    expect(es.makeViewer, 'Dar permiso de lectura');
    await _openSharing(tester, data: {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [
        {'user_id': 2, 'user__email': 'ana@example.invalid', 'role': 'editor'},
        {'user_id': 7, 'user__email': 'luis@example.invalid', 'role': 'viewer'},
      ],
      'invitations': [],
    });
    Finder inMenu(String text) => find.descendant(
        of: find.byType(PopupMenuItem<String>), matching: find.text(text));
    final anaMenu = find.byTooltip(es.manageItem('ana@example.invalid'));
    await tester.ensureVisible(anaMenu);
    await tester.pumpAndSettle();
    await tester.tap(anaMenu);
    await tester.pumpAndSettle();
    expect(inMenu(es.makeEditor), findsNothing, reason: 'Ana is an editor');
    expect(inMenu(es.makeViewer), findsOneWidget);
    expect(inMenu(es.removeAccess), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    final luisMenu = find.byTooltip(es.manageItem('luis@example.invalid'));
    await tester.ensureVisible(luisMenu);
    await tester.pumpAndSettle();
    await tester.tap(luisMenu);
    await tester.pumpAndSettle();
    expect(inMenu(es.makeEditor), findsOneWidget);
    expect(inMenu(es.makeViewer), findsNothing, reason: 'Luis is a viewer');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1506: a reader of a person-to-person project with 3 people sees Miembros: the three names with their roles, the owner first, María (tú); no Comparte compras and no Tu rol',
      (tester) async {
    expect(es.people, 'Miembros');
    expect(es.personYou('María'), 'María (tú)');
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(en.personYou('María'), 'María (you)');
    expect(ca.personYou('María'), 'María (tu)');
    // This account (id 1) is María, a reader.
    await _openSharing(tester, data: {
      'list': {'name': 'Club de lectura', 'role': 'viewer', 'version': 1},
      'members': [],
      'invitations': [],
    }, projects: [
      TaskListInfo(
          id: 'casa',
          name: 'Club de lectura',
          version: 1,
          role: 'viewer',
          shared: true,
          ownerId: 2,
          people: const [
            ProjectMember(id: 2, name: 'Lucía', role: 'owner'),
            ProjectMember(id: 1, name: 'María', role: 'viewer'),
            ProjectMember(id: 3, name: 'Jordi', role: 'editor'),
          ])
    ]);
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text(es.people)),
        findsOneWidget);
    final rows = [
      (es.personYou('María'), es.roleViewer),
      ('Lucía', es.roleOwner),
      ('Jordi', es.roleEditor),
    ];
    for (final (name, role) in rows) {
      final row = find.widgetWithText(ListTile, name);
      expect(row, findsOneWidget, reason: name);
      expect(find.descendant(of: row, matching: find.text(role)),
          findsOneWidget,
          reason: '$name reads $role');
    }
    expect(find.text('María'), findsNothing, reason: 'marked as you');
    double top(String name) =>
        tester.getTopLeft(find.widgetWithText(ListTile, name)).dy;
    expect(top('Lucía'), lessThan(top(es.personYou('María'))),
        reason: 'the owner first');
    expect(find.textContaining('Comparte compras'), findsNothing);
    expect(find.textContaining('Tu rol'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1506: the owner’s Miembros · 3 opens Miembros with 3 rows, the owner’s own first, marked (tú)',
      (tester) async {
    const luis = ProjectMember(id: 3, name: 'Luis', role: 'viewer');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final project = TaskListInfo(
        id: 'casa',
        name: 'Casa',
        version: 3,
        shared: true,
        ownerId: 1,
        people: const [owner, ana, luis]);
    final container = designContainer(
      projects: [project],
      regionalStore:
          MemoryRegionalStore(const RegionalPreferences(language: 'es')),
      overrides: [
        listSharingProvider.overrideWith((ref, id) async => {
              'list': {'name': 'Casa', 'role': 'owner', 'version': 3},
              'members': [
                {
                  'user_id': 2,
                  'user__email': 'ana@example.invalid',
                  'role': 'editor'
                },
                {
                  'user_id': 3,
                  'user__email': 'luis@example.invalid',
                  'role': 'viewer'
                },
              ],
              'invitations': [],
            }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(
            builder: (_) => const HomeScreen(isRoot: false, listId: 'casa')));
    await tester.pumpAndSettle();
    final members = find.widgetWithText(TextButton, es.projectMembersCount(3));
    expect(members, findsOneWidget);
    await tester.ensureVisible(members);
    await tester.tap(members);
    await tester.pumpAndSettle();
    expect(find.byType(ListSharingScreen), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text(es.people)),
        findsOneWidget);
    final names = [es.personYou('Yo'), 'Ana', 'Luis'];
    final tops = <double>[];
    for (final name in names) {
      final row = find.widgetWithText(ListTile, name);
      expect(row, findsOneWidget, reason: name);
      tops.add(tester.getTopLeft(row).dy);
    }
    expect(tops, orderedEquals([...tops]..sort()),
        reason: 'the owner’s own row first, then Ana and Luis');
    expect(
        find.descendant(
            of: find.widgetWithText(ListTile, es.personYou('Yo')),
            matching: find.text(es.roleOwner)),
        findsOneWidget);
    expect(find.text(es.noOtherMembers), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1506: an owner’s unshared personal project still opens Compartir proyecto',
      (tester) async {
    expect(es.listSharing, 'Compartir proyecto');
    await openProjectPage(
        tester, TaskListInfo(id: 'casa', name: 'Casa', version: 3));
    final share = find.widgetWithText(TextButton, es.shareProject);
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pumpAndSettle();
    final bar = find.descendant(
        of: find.byType(ListSharingScreen), matching: find.byType(AppBar));
    expect(find.descendant(of: bar, matching: find.text(es.listSharing)),
        findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text(es.people)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ---- Run 2026-10-19-app, round 2 · P212 (UX-1643): «Miembros» once ----

  Finder sectionLabel(String text) =>
      find.byWidgetPredicate((w) => w is SectionLabel && w.text == text);

  testWidgets(
      'UX-1643: at 1× on 360×800 the owner’s page of a shared project with two other members says Miembros once, in the app bar, with no MIEMBROS label, and María (tú) first',
      (tester) async {
    await _openSharing(tester, data: {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 3},
      'members': [
        {'user_id': 2, 'user__email': 'ana@example.invalid', 'role': 'editor'},
        {'user_id': 3, 'user__email': 'luis@example.invalid', 'role': 'viewer'},
      ],
      'invitations': [],
    }, projects: [
      TaskListInfo(
          id: 'casa',
          name: 'Casa',
          version: 3,
          shared: true,
          ownerId: 1,
          people: const [
            ProjectMember(id: 1, name: 'María', role: 'owner'),
            ProjectMember(id: 2, name: 'Ana', role: 'editor'),
            ProjectMember(id: 3, name: 'Luis', role: 'viewer'),
          ]),
    ]);
    final page = find.byType(ListSharingScreen);
    final members = find.descendant(of: page, matching: find.text(es.people));
    expect(members, findsOneWidget);
    expect(
        find.descendant(
            of: find.descendant(of: page, matching: find.byType(AppBar)),
            matching: find.text(es.people)),
        findsOneWidget);
    expect(sectionLabel(es.people), findsNothing);
    expect(find.text(es.people.toUpperCase()), findsNothing);
    final tops = [
      for (final name in [es.personYou('María'), 'Ana', 'Luis'])
        tester.getTopLeft(find.widgetWithText(ListTile, name)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()),
        reason: 'María (tú) first, then Ana and Luis');
    expect(es.personYou('María'), 'María (tú)');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1643: an owner’s unshared personal project’s sharing page reads Compartir proyecto and keeps the MIEMBROS label',
      (tester) async {
    await _openSharing(tester, data: {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
      'members': [],
      'invitations': [],
    }, projects: [
      TaskListInfo(id: 'casa', name: 'Casa', version: 1),
    ]);
    final bar = find.descendant(
        of: find.byType(ListSharingScreen), matching: find.byType(AppBar));
    expect(find.descendant(of: bar, matching: find.text(es.listSharing)),
        findsOneWidget);
    expect(sectionLabel(es.people), findsOneWidget);
    expect(find.text(es.people.toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1510: with a sync that never completes, Invitación enviada and its code show right after the invite’s POST returns',
      (tester) async {
    final tasks = HangingSyncTasks();
    final (api, _) =
        await _openSharing(tester, data: ownerData, tasks: () => tasks);
    await tester.tap(find.byKey(const ValueKey('invite-person')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('invite-email')), 'ana@example.invalid');
    await tester.tap(find.widgetWithText(FilledButton, es.sendInvitation));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.calls.last.$2, 'lists/casa/invite/');
    expect(tasks.syncs, greaterThan(0), reason: 'a sync is under way');
    final sent = find.widgetWithText(AlertDialog, es.invitationSent);
    expect(sent, findsOneWidget);
    expect(
        find.descendant(
            of: sent, matching: find.byKey(const ValueKey('invitation-code'))),
        findsOneWidget);
    expect(find.text(_Recorder.code), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('P260 · reminders aren’t shared', () {
    // Measure wrapping in the app's own font, not the square test font.
    setUpAll(() async {
      await (FontLoader('Manrope')
            ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
          .load();
    });

    // The brief's exact copy for the second paragraph of «Cómo funciona…».
    const expected = {
      'es':
          'Se comparten tareas, notas y archivos subidos. Los editores pueden '
              'modificarlos o eliminarlos; los lectores pueden consultarlos. '
              'Los recordatorios no se comparten: cada persona tiene los suyos.',
      'en': 'Tasks, notes and uploaded files are shared. Editors can change '
          'or remove them; viewers can read them. Reminders aren’t shared: '
          'each person has their own.',
      'ca': 'Les tasques, notes i fitxers pujats es comparteixen. Els editors '
          'els poden canviar o suprimir; els lectors els poden consultar. '
          'Els recordatoris no es comparteixen: cada persona té els seus.',
    };
    const sharedData = {
      'list': {'name': 'Casa', 'role': 'owner', 'version': 3},
      'members': [
        {'user_id': 2, 'user__email': 'ana@example.invalid', 'role': 'editor'},
        {'user_id': 3, 'user__email': 'luis@example.invalid', 'role': 'viewer'},
      ],
      'invitations': [],
    };
    final sharedProjects = [
      TaskListInfo(
          id: 'casa',
          name: 'Casa',
          version: 3,
          shared: true,
          ownerId: 1,
          people: const [
            ProjectMember(id: 1, name: 'María', role: 'owner'),
            ProjectMember(id: 2, name: 'Ana', role: 'editor'),
            ProjectMember(id: 3, name: 'Luis', role: 'viewer'),
          ]),
    ];

    /// Opens the owner's «Miembros» of the shared project «Casa» and
    /// expands «Cómo funciona compartir».
    Future<AppLocalizations> openHelp(WidgetTester tester,
        {required String language, double scale = 1}) async {
      final l = lookupAppLocalizations(Locale(language));
      await _openSharing(tester,
          data: sharedData,
          projects: sharedProjects,
          language: language,
          scale: scale);
      final title = find.text(l.howSharingWorks);
      await tester.scrollUntilVisible(title, 120,
          scrollable: find
              .descendant(
                  of: find.byType(ListSharingScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      return l;
    }

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
          'UX-2029: ($language, 1×, 360×800) on the owner’s Miembros of a shared project, the second paragraph of Cómo funciona compartir says reminders aren’t shared: each person has their own',
          (tester) async {
        final l = await openHelp(tester, language: language);
        expect(l.sharedDataHelp, expected[language],
            reason: 'the catalog holds the brief’s exact text');
        final paragraphs = [
          l.sharingRolesHelp,
          l.sharedDataHelp,
          l.sharingRemovalHelp
        ];
        for (final text in paragraphs) {
          expect(find.text(text), findsOneWidget);
        }
        final tops = [
          for (final text in paragraphs) tester.getTopLeft(find.text(text)).dy
        ];
        expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue,
            reason: 'the sharing paragraph is the second of the three');
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in ['es', 'ca']) {
      testWidgets(
          'UX-2029: ($language, 2×, 360×800) the reminders-aren’t-shared paragraph shows whole, nothing clipped, once scrolled into view',
          (tester) async {
        final l = await openHelp(tester, language: language, scale: 2);
        final paragraph = find.text(l.sharedDataHelp);
        expect(paragraph, findsOneWidget);
        await tester.ensureVisible(paragraph);
        await tester.pumpAndSettle();
        final box = tester.getRect(paragraph);
        final bar = tester.getRect(find
            .descendant(
                of: find.byType(ListSharingScreen),
                matching: find.byType(AppBar))
            .first);
        expect(box.top, greaterThanOrEqualTo(bar.bottom),
            reason: 'its first line is below the app bar');
        expect(box.bottom, lessThanOrEqualTo(800));
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(360));
        final render = tester.renderObject<RenderParagraph>(find.descendant(
            of: paragraph, matching: find.byType(RichText)));
        expect(render.didExceedMaxLines, isFalse);
        expect(render.textScaler, const TextScaler.linear(2));
        // Every line of the text is laid out inside the paragraph's box.
        final end = render.getOffsetForCaret(
            TextPosition(offset: l.sharedDataHelp.length), Rect.zero);
        expect(end.dy, lessThan(render.size.height));
        expect(tester.takeException(), isNull);
      });
    }

    test(
        'UX-2029: no catalog keeps the old sentence that reminder choices are shared, and the generated strings match the catalogs',
        () {
      const old = {
        'es': 'opciones de recordatorio se comparten',
        'en': 'reminder choices are shared',
        'ca': 'opcions dels recordatoris es comparteixen',
      };
      for (final language in ['en', 'es', 'ca']) {
        final raw = File('lib/l10n/app_$language.arb').readAsStringSync();
        expect(raw.contains(old[language]!), isFalse,
            reason: 'app_$language.arb still says “${old[language]}”');
        final arb = jsonDecode(raw) as Map<String, dynamic>;
        expect(arb['sharedDataHelp'], expected[language]);
        // flutter gen-l10n ran: the generated class says what the catalog says.
        expect(lookupAppLocalizations(Locale(language)).sharedDataHelp,
            arb['sharedDataHelp']);
      }
    });

    test('UX-2029: @sharedDataHelp in app_en.arb carries the brief’s description',
        () {
      final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
      expect(arb['@sharedDataHelp'], isA<Map<String, dynamic>>());
      expect(
          (arb['@sharedDataHelp'] as Map<String, dynamic>)['description'],
          'Sharing screen, under “How sharing works”: what a shared project '
          'shares. Reminders are each person’s own (none of their values '
          'reaches anyone else), so the last sentence says they aren’t shared.');
    });
  });

  group('P284 · sharing page answers where you tapped', () {
    // Measure wrapping in the app's own font, not the square test font.
    setUpAll(() async {
      await (FontLoader('Manrope')
            ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
          .load();
    });

    const anaEmail = 'ana.garcia@example.com';
    const carmenEmail = 'carmen.lopez@example.com';
    const luisEmail = 'luis.martinez@example.com';
    Finder inPage(Finder finder) =>
        find.descendant(of: find.byType(ListSharingScreen), matching: finder);
    Finder bar() => inPage(find.byType(LinearProgressIndicator));
    Finder rowOf(String shown) => find.widgetWithText(ListTile, shown);

    testWidgets(
        'UX-2502: with the sync held open, Ana’s row reads Lector as soon as «Dar permiso de lectura» answers, and the page never blanks to a spinner',
        (tester) async {
      final tasks = HangingSyncTasks();
      final api = await _openLiveSharing(tester, tasks: tasks);
      final anaRow = rowOf(breakableAddress(anaEmail));
      expect(find.descendant(of: anaRow, matching: find.text(es.roleEditor)),
          findsOneWidget);
      final menu = find.byTooltip(es.manageItem(anaEmail));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.makeViewer));
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(inPage(find.byType(CircularProgressIndicator)), findsNothing,
            reason: 'the page stays on screen (frame $frame)');
        expect(anaRow, findsOneWidget);
      }
      expect(api.calls, contains(('POST', 'lists/casa/member/')));
      expect(api.calls.last, ('GET', 'lists/casa/sharing/'),
          reason: 'the page fetched its own data again');
      expect(tasks.syncs, greaterThan(0), reason: 'a sync is under way');
      expect(tasks.sync.isCompleted, isFalse, reason: 'and still running');
      expect(find.descendant(of: anaRow, matching: find.text(es.roleViewer)),
          findsOneWidget);
      expect(find.descendant(of: anaRow, matching: find.text(es.roleEditor)),
          findsNothing);
      expect(bar(), findsNothing, reason: 'the change is done');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2502: while a change runs, a 2 dp bar sits under the app bar, in view when scrolled to the bottom, and nothing below it moves (es, 2x, 360x800)',
        (tester) async {
      final api = await _openLiveSharing(tester, scale: 2);
      api.hold = Completer<void>();
      final menu = find.byTooltip(es.manageItem(anaEmail));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      final anaRow = rowOf(breakableAddress(anaEmail));
      final before = tester.getRect(anaRow);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.makeViewer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.calls.last, ('POST', 'lists/casa/member/'),
          reason: 'the request is on its way');
      final appBar = tester.getRect(inPage(find.byType(AppBar)));
      expect(bar(), findsOneWidget);
      var rect = tester.getRect(bar());
      expect(rect.height, moreOrLessEquals(2, epsilon: 0.01));
      expect(rect.top, moreOrLessEquals(appBar.bottom, epsilon: 0.5));
      expect(tester.getRect(anaRow), before, reason: 'nothing moves');
      // Scrolled to the bottom, the bar is still in view.
      await tester.drag(inPage(find.byType(Scrollable)).first,
          const Offset(0, -4000));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final delete = find.text(es.deleteListForEveryone);
      expect(delete, findsOneWidget);
      expect(tester.getRect(delete).bottom, lessThanOrEqualTo(800));
      expect(bar(), findsOneWidget);
      rect = tester.getRect(bar());
      expect(rect.height, moreOrLessEquals(2, epsilon: 0.01));
      expect(rect.top, moreOrLessEquals(appBar.bottom, epsilon: 0.5));
      expect(rect.bottom, lessThanOrEqualTo(800));
      api.hold!.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(bar(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2502 / UX-2511: offline, «Dar permiso de lectura» keeps the members on screen and says the network message as a floating message, with nothing after «inténtalo de nuevo.»',
        (tester) async {
      final api = await _openLiveSharing(tester);
      api.offline = true;
      final menu = find.byTooltip(es.manageItem(anaEmail));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.makeViewer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      const network =
          'No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.';
      expect(es.requestError('network'), network);
      final snack = find.byType(SnackBar);
      expect(snack, findsOneWidget);
      expect(tester.widget<SnackBar>(snack).behavior, SnackBarBehavior.floating);
      expect(find.descendant(of: snack, matching: find.text(network)),
          findsOneWidget);
      expect(find.textContaining('Tus tareas siguen guardadas'), findsNothing);
      expect(inPage(find.byType(MessageBanner)), findsNothing,
          reason: 'the top banner is only for a page that couldn’t load');
      final anaRow = rowOf(breakableAddress(anaEmail));
      expect(anaRow, findsOneWidget, reason: 'the members stay');
      expect(find.descendant(of: anaRow, matching: find.text(es.roleEditor)),
          findsOneWidget);
      expect(inPage(find.byType(CircularProgressIndicator)), findsNothing);
      expect(bar(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2511: a sharing page that can’t load offline says the network message and nothing after it',
        (tester) async {
      await _openLiveSharing(tester, offlineFromStart: true);
      final banner = inPage(find.byType(MessageBanner));
      expect(banner, findsOneWidget);
      expect(
          find.descendant(
              of: banner, matching: find.text(es.requestError('network'))),
          findsOneWidget);
      expect(find.textContaining('Tus tareas siguen guardadas'), findsNothing);
      expect(inPage(find.text(es.retry)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'UX-2513: (es, ${scale}x, 360x800) members’ and pending invitations’ addresses wrap only after «@» or «.», and TalkBack reads them whole',
          (tester) async {
        final semantics = tester.ensureSemantics();
        await _openLiveSharing(tester, scale: scale, named: true);
        final checks = <(String, String)>[
          // Ana is named: her address leads the second line.
          ('${breakableAddress(anaEmail)} · ${es.roleEditor}', anaEmail),
          (breakableAddress(carmenEmail), carmenEmail),
          (breakableAddress(luisEmail), luisEmail),
        ];
        for (final (shown, address) in checks) {
          final text = find.text(shown);
          await tester.scrollUntilVisible(text, 100,
              scrollable: inPage(find.byType(Scrollable)).first);
          await tester.pumpAndSettle();
          expect(text, findsOneWidget, reason: address);
          expectAddressWrapsWhole(tester, text, address);
          final spoken = spokenLabel(tester, text);
          expect(spoken, contains(address));
          expect(tester.getRect(text).right, lessThanOrEqualTo(360.5));
        }
        semantics.dispose();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'UX-2518: (es, 2x, 360x800) the invite dialog’s stacked «Cancelar» and «Enviar invitación» stand 8 dp or more apart',
        (tester) async {
      await _openLiveSharing(tester, scale: 2);
      final invite = find.byKey(const ValueKey('invite-person'));
      await tester.ensureVisible(invite);
      await tester.pumpAndSettle();
      await tester.tap(invite);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expectButtonsApart(
        tester,
        find.descendant(
            of: dialog, matching: find.widgetWithText(TextButton, es.cancel)),
        find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, es.sendInvitation)),
        stacked: true,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('P285 · project sharing headings', () {
    testWidgets(
        'UX-2519: on a project’s sharing page, Miembros and INVITACIONES PENDIENTES are headings',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _SharingApp.open(tester, {
        'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
        'members': [],
        'invitations': [
          {'id': 'inv-1', 'email': 'ana@example.invalid', 'role': 'editor'}
        ]
      }, projects: [
        // Not shared yet: the page shows its own «Miembros» section.
        TaskListInfo(id: 'casa', name: 'Casa', version: 1, role: 'owner'),
      ]);
      for (final title in [es.people, es.pendingInvitations]) {
        final label = find.byWidgetPredicate(
            (w) => w is SectionLabel && w.text == title);
        expect(label, findsOneWidget, reason: title);
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        final text = find.descendant(
            of: label, matching: find.text(title.toUpperCase()));
        final node = tester.getSemantics(text);
        expect(node.label, title.toUpperCase());
        expect(node.getSemanticsData().flagsCollection.isHeader, isTrue,
            reason: '«$title» is a heading');
      }
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  });

  group('P286 · no delete inside an unshared project’s sharing page', () {
    /// Scrolls the sharing page to its last line, «Cómo funciona…».
    Future<void> toTheEnd(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.text(es.howSharingWorks), 200,
          scrollable: find
              .descendant(
                  of: find.byType(ListSharingScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.drag(
          find
              .descendant(
                  of: find.byType(ListSharingScreen),
                  matching: find.byType(Scrollable))
              .first,
          const Offset(0, -2000));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'UX-2503: «Compartir proyecto» for an unshared «Casa» you own has no Eliminar proyecto, even scrolled to its end',
        (tester) async {
      await _SharingApp.open(tester, {
        'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
        'members': [],
        'invitations': []
      }, projects: [
        TaskListInfo(id: 'casa', name: 'Casa', version: 1)
      ]);
      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text(es.listSharing)),
          findsOneWidget);
      await toTheEnd(tester);
      expect(find.text(es.howSharingWorks), findsOneWidget);
      expect(find.text(es.deleteList, skipOffstage: false), findsNothing);
      expect(find.text(es.deleteListForEveryone, skipOffstage: false),
          findsNothing);
      expect(
          find.descendant(
              of: find.byType(ListSharingScreen),
              matching: find.byType(OutlinedButton)),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2503: a shared project’s Miembros page still ends with Eliminar el proyecto para todos for its owner',
        (tester) async {
      await _SharingApp.open(tester, {
        'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
        'members': [
          {'user_id': 2, 'user__email': 'ana@example.invalid', 'role': 'editor'}
        ],
        'invitations': []
      }, projects: [
        TaskListInfo(
            id: 'casa',
            name: 'Casa',
            version: 1,
            shared: true,
            ownerId: 1,
            people: const [owner, ana])
      ]);
      await toTheEnd(tester);
      expect(find.widgetWithText(OutlinedButton, es.deleteListForEveryone),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// UX-2518: [a] and [b] leave at least 8 dp between them, one above the
/// other when [stacked].
void expectButtonsApart(WidgetTester tester, Finder a, Finder b,
    {bool stacked = true}) {
  expect(a, findsOneWidget);
  expect(b, findsOneWidget);
  final first = tester.getRect(a);
  final second = tester.getRect(b);
  final (upper, lower) =
      first.top <= second.top ? (first, second) : (second, first);
  if (stacked) {
    expect(lower.top, greaterThanOrEqualTo(upper.bottom - 0.5),
        reason: 'one above the other: $first, $second');
  }
  final gap = stacked
      ? lower.top - upper.bottom
      : (first.left <= second.left
          ? second.left - first.right
          : first.left - second.right);
  expect(gap, greaterThanOrEqualTo(7.99),
      reason: 'the buttons stand ${gap.toStringAsFixed(1)} dp apart');
}

/// P284: the sharing screen of project `casa`, in Spanish at [scale] on a
/// 360×800 view, fed by a [_LiveSharing] server through the app's own
/// provider: Ana (editor) and Carmen (viewer) have access, and Luis is
/// invited. With [named], the project knows Ana's name. Signed in as
/// account 1, the owner.
Future<_LiveSharing> _openLiveSharing(
  WidgetTester tester, {
  double scale = 1,
  bool named = false,
  bool offlineFromStart = false,
  TaskNotifier? tasks,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _LiveSharing()..offline = offlineFromStart;
  final container = ProviderContainer(retry: noRetry, overrides: [
    apiClientProvider.overrideWithValue(api),
    authProvider.overrideWith((ref) => _Auth(api)),
    taskRepositoryProvider.overrideWithValue(MemoryTasks()),
    taskProvider.overrideWith((ref) => tasks ?? DesignTaskNotifier()),
    themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    taskListsProvider.overrideWith((ref) async => [
          if (named)
            TaskListInfo(
                id: 'casa',
                name: 'Casa',
                version: 1,
                shared: true,
                ownerId: 1,
                people: const [
                  ProjectMember(id: 1, name: 'Yo', role: 'owner'),
                  ProjectMember(id: 2, name: 'Ana', role: 'editor'),
                ]),
        ]),
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
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
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
  return api;
}

/// P284: the sharing server of project `casa`. A role change takes effect
/// at once and the next GET shows it; [hold] keeps a change waiting;
/// [offline] fails every request as a lost connection.
class _LiveSharing extends OfflineApiClient {
  final calls = <(String, String)>[];
  bool offline = false;
  Completer<void>? hold;
  final members = <Map<String, dynamic>>[
    {'user_id': 2, 'user__email': 'ana.garcia@example.com', 'role': 'editor'},
    {'user_id': 3, 'user__email': 'carmen.lopez@example.com', 'role': 'viewer'},
  ];
  final invitations = <Map<String, dynamic>>[
    {'id': 'inv-1', 'email': 'luis.martinez@example.com', 'role': 'editor'},
  ];
  @override
  Account get account => Account.fromJson(
      {'id': 1, 'email': 'owner@example.invalid', 'timezone': 'UTC'});
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    calls.add((method, path));
    if (offline) throw ApiException(0, 'offline');
    if (method == 'GET' && path == 'lists/casa/sharing/') {
      return {
        'list': {'name': 'Casa', 'role': 'owner', 'version': 1},
        'members': [for (final member in members) {...member}],
        'invitations': [for (final invitation in invitations) {...invitation}],
      };
    }
    if (hold != null) await hold!.future;
    if (method == 'POST' && path == 'lists/casa/member/') {
      final member =
          members.firstWhere((member) => member['user_id'] == data!['user_id']);
      if (data!['role'] == 'remove') {
        members.remove(member);
      } else {
        member['role'] = data['role'];
      }
      return {};
    }
    return path.endsWith('invite/') ? {'code': _Recorder.code} : {};
  }
}

/// The sharing screen of project `casa` with [data], in [language] at
/// [scale] on a [size] view, opened from a page underneath. Signed in as
/// account 1, owner@example.invalid.
Future<(_Recorder, ProviderContainer)> _openSharing(
  WidgetTester tester, {
  required Map<String, dynamic> data,
  String language = 'es',
  double scale = 1,
  Size size = const Size(360, 800),
  List<TaskListInfo> projects = const [],
  TaskNotifier Function()? tasks,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _Recorder();
  final container = ProviderContainer(retry: noRetry, overrides: [
    apiClientProvider.overrideWithValue(api),
    authProvider.overrideWith((ref) => _Auth(api)),
    taskRepositoryProvider.overrideWithValue(MemoryTasks()),
    taskProvider.overrideWith((ref) => tasks?.call() ?? DesignTaskNotifier()),
    themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    taskListsProvider.overrideWith((ref) async => projects),
    listSharingProvider.overrideWith((ref, id) async => data),
  ]);
  addTearDown(container.dispose);
  addTearDown(api.close);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          locale: Locale(language),
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
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
  return (api, container);
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
    final container = ProviderContainer(retry: noRetry, overrides: [
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
