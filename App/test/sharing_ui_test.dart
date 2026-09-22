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
      'sharing and invitation form remain usable at 2x text in both themes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final dark in [false, true]) {
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
      await tester.tap(find.text('Create invitation'));
      await tester.pumpAndSettle();
      expect(
          api.payload, {'email': 'friend@example.invalid', 'role': 'editor'});
      expect(find.byKey(const ValueKey('invitation-code')), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      api.close();
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
