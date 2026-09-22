import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  testWidgets(
      'English and Spanish invitations preserve API roles at 2x text in both themes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (language, dark) in [
      ('en', false),
      ('en', true),
      ('es', false),
      ('es', true)
    ]) {
      final spanish = language == 'es';
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
      if (spanish) {
        final role = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(role);
        await tester.pumpAndSettle();
        await tester.tap(role);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lector').last);
        await tester.pumpAndSettle();
      }
      await tester
          .tap(find.text(spanish ? 'Crear invitación' : 'Create invitation'));
      await tester.pumpAndSettle();
      expect(api.payload, {
        'email': 'friend@example.invalid',
        'role': spanish ? 'viewer' : 'editor'
      });
      expect(find.byKey(const ValueKey('invitation-code')), findsOneWidget);
      await tester.tap(find.text(spanish ? 'Listo' : 'Done'));
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
      invitationsProvider.overrideWith((ref) async => [
            {
              'id': 'invitation-fixture',
              'list_name': 'Do not translate my list',
              'role': 'viewer'
            }
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
        home: Scaffold(body: ListView(children: const [ListInvitations()])),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Do not translate my list'), findsOneWidget);
    expect(find.textContaining('rol de Lector'), findsOneWidget);
    await tester.ensureVisible(find.text('Aceptar invitación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar invitación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unirse a la lista'));
    await tester.pumpAndSettle();
    expect(find.text('Pega el código de invitación completo.'), findsOneWidget);
    expect(api.payload, isNull);
    const code = 'Synthetic-Case-Sensitive-Code_2026';
    final field = find.byKey(const ValueKey('accept-invitation-code'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '  $code  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unirse a la lista'));
    await tester.pumpAndSettle();
    expect(api.payload, {'decision': 'accept', 'code': code});
    expect(api.path, 'invitations/invitation-fixture/respond/');
    expect(tester.takeException(), isNull);
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
