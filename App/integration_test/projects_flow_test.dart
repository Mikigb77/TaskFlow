// Real local or cloud API + PostgreSQL + RevenueCat Test Store + Google AI.
// Run after validate_projects.py or validate_staging.py with its private fixture.
// Only session storage and appearance preferences are isolated in memory;
// project/task persistence uses Android SQLite and all requests are real.
import 'dart:convert';
import 'dart:io';
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../test/support/design_fixtures.dart';

const projectId = String.fromEnvironment('PROJECT_E2E_PROJECT');
const groupId = String.fromEnvironment('PROJECT_E2E_GROUP');
const email = String.fromEnvironment('PROJECT_E2E_EMAIL');
const password = String.fromEnvironment('PROJECT_E2E_PASSWORD');
const memberEmail = String.fromEnvironment('PROJECT_E2E_MEMBER_EMAIL');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('projects, reviewed assignments, paid capture and account isolation', (
    tester,
  ) async {
    expect(
      projectId,
      isNotEmpty,
      reason: 'Supply the isolated project-e2e.json fixture.',
    );
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    final prior = await const FlutterSecureStorage().read(
      key: 'taskflow.session',
    );
    final originalBilling = prior == null
        ? null
        : (jsonDecode(prior) as Map)['user']['billing_id'] as String?;
    final gateway = NativeRevenueCatGateway();
    await gateway.configure(
      BillingConfiguration.environment(),
      originalBilling,
    );
    final previousRevenueCatId = await Purchases.appUserID;
    FlutterSecureStorage.setMockInitialValues({});
    final api = _ConnectionApi();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      api.close();
      await gateway.identify(previousRevenueCatId);
      if (originalOwner != null) await TaskReminders.activate(originalOwner);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await waitFor(tester, () => !container.read(authProvider).loading);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('account-email')), email);
    await tester.enterText(
      find.byKey(const ValueKey('account-password')),
      password,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final signIn = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await waitFor(tester, () => container.read(authProvider).account != null);
    await container.read(taskProvider.notifier).loadTasks();
    await container.read(taskListsProvider.future);
    await waitFor(tester, () => container.read(subscriptionProvider).ready);
    await container.read(subscriptionProvider.notifier).refresh();
    expect(
      container.read(hasProProvider),
      isTrue,
      reason: 'A real allowlisted Test Store subscription is required.',
    );
    expect(find.byType(CalendarScreen), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('projects-calendar-light');
    debugPrint(
      'PROJECTS_E2E: real login, native entitlement and Android sync passed',
    );

    NavigatorState navigator() =>
        tester.state<NavigatorState>(find.byType(Navigator).first);
    if (const bool.fromEnvironment('PROJECT_E2E_EXPECT_UNAVAILABLE')) {
      // An opt-in negative live check, never a substitute for extraction.
      // A provider outage must not drop the input or create shared tasks.
      const words =
          'Ana needs to finish exercise three in Physics by Thursday. '
          'We all need to prepare the final presentation in Physics by Friday.';
      final before = await api.request('GET', 'tasks/');
      final store = container.read(captureStoreProvider);
      final owner = container.read(captureOwnerProvider);
      final earlier = (await store.pending(owner)).map((s) => s.id).toSet();
      addTearDown(() async {
        for (final capture in await store.pending(owner)) {
          if (!earlier.contains(capture.id) &&
              capture.text == words &&
              capture.projectId == projectId) {
            await store.discard(capture.id, owner);
          }
        }
      });
      navigator().push(
        MaterialPageRoute<void>(
          builder: (_) => const VoiceTaskScreen(projectId: projectId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-words')),
        words,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final review = find.text('Review tasks from text');
      await tester.ensureVisible(review);
      await tester.tap(review);
      final problem = find.textContaining(
        'The processing service is unavailable.',
      );
      await waitFor(
        tester,
        () =>
            problem.evaluate().isNotEmpty ||
            find.byType(ReviewTasksScreen).evaluate().isNotEmpty,
        seconds: 100,
      );
      expect(
        find.byType(ReviewTasksScreen),
        findsNothing,
        reason: 'The provider recovered. Run the normal live AI check.',
      );
      expect(
        find.textContaining('Your capture is kept on this phone.'),
        findsOneWidget,
      );
      final retained = (await store.pending(
        owner,
      )).where((s) => !earlier.contains(s.id)).single;
      expect(retained.status, 'failed');
      expect(retained.error, CaptureProblem.unavailable);
      expect(retained.text, words);
      expect(retained.projectId, projectId);
      expect(retained.drafts, isEmpty);
      final after = await api.request('GET', 'tasks/');
      expect(after['results'], before['results']);
      await tester.ensureVisible(problem);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('projects-provider-unavailable');
      navigator().pop();
      await tester.pumpAndSettle();
      navigator().push(
        MaterialPageRoute<void>(
          builder: (_) => VoiceTaskScreen(captureId: retained.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('capture-words')))
            .controller!
            .text,
        words,
      );
      expect(problem, findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review tasks from text'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugPrint(
        'PROJECTS_E2E: real provider outage retained the input and project; '
        'reopening allows retry, and no shared tasks were created',
      );
      return;
    }
    navigator().push(
      MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(isRoot: false, listId: projectId),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finish exercise three'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Team'));
    await tester.pumpAndSettle();
    expect(find.text('Finish exercise three'), findsOneWidget);
    await binding.takeScreenshot('projects-team-light');
    await tester.tap(find.text('Finish exercise three'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    await binding.takeScreenshot('projects-task-responsibility');
    navigator().pop();
    await tester.pumpAndSettle();
    navigator().pop();
    await tester.pumpAndSettle();
    navigator().push(
      MaterialPageRoute<void>(
        builder: (_) => const GroupScreen(groupId: groupId),
      ),
    );
    await waitFor(
      tester,
      () => container.read(groupDetailsProvider(groupId)).hasValue,
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('projects-members-light');
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('projects-members-dark');
    await tester.tap(find.widgetWithText(TextButton, 'New project'));
    // Cloud-backed group loading can finish after animations have settled.
    await waitFor(
      tester,
      () => find.byKey(const ValueKey('list-name')).evaluate().isNotEmpty,
    );
    final projectName = 'Chemistry ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(
      find.byKey(const ValueKey('list-name')),
      projectName,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save project'));
    await waitFor(
      tester,
      () => find.byKey(const ValueKey('list-name')).evaluate().isEmpty,
    );
    await container.read(taskProvider.notifier).loadTasks();
    final projects = await api.request('GET', 'lists/access/');
    expect(
      (projects['lists'] as List).singleWhere(
        (p) => p['name'] == projectName,
      )['group_id'],
      groupId,
    );
    navigator().pop();
    await tester.pumpAndSettle();
    navigator().pop();
    await tester.pumpAndSettle();

    var assigned = container
        .read(taskProvider)
        .requireValue
        .firstWhere((t) => t.listId == projectId && t.assignment == 'member');
    if (const bool.fromEnvironment('PROJECT_E2E_AI', defaultValue: true)) {
      const audioUrl = String.fromEnvironment('PROJECT_E2E_AUDIO_URL');
      const audioFile = String.fromEnvironment('PROJECT_E2E_AUDIO_PATH');
      String? audioCaptureId;
      if (audioUrl.isNotEmpty || audioFile.isNotEmpty) {
        // Only a supplied synthetic fixture replaces microphone input. Android
        // private storage, upload, transcription, extraction and review are real.
        late List<int> bytes;
        if (audioFile.isNotEmpty) {
          expect(audioUrl, isEmpty);
          expect(
            audioFile,
            '/data/user/0/com.example.agenda.staging/cache/staging-synthetic.wav',
            reason: 'Only the explicitly installed staging fixture is allowed.',
          );
          bytes = await File(audioFile).readAsBytes();
        } else {
          final uri = Uri.parse(audioUrl);
          expect(
            uri.host,
            '10.0.2.2',
            reason: 'Use a local synthetic audio fixture.',
          );
          final client = HttpClient();
          try {
            final response = await (await client.getUrl(uri)).close();
            expect(response.statusCode, 200);
            bytes = await response.fold<List<int>>(
              [],
              (all, next) => all..addAll(next),
            );
          } finally {
            client.close(force: true);
          }
        }
        expect(bytes.length, lessThanOrEqualTo(6 * 1024 * 1024));
        expect(ascii.decode(bytes.take(4).toList()), 'RIFF');
        final store = container.read(captureStoreProvider);
        final audio = await store.create(
          container.read(captureOwnerProvider),
          'Europe/Madrid',
          audio: true,
          projectId: projectId,
          now: DateTime.parse('2026-10-11T12:00:00+02:00'),
        );
        await File(audio.audioPath!).writeAsBytes(bytes, flush: true);
        audioCaptureId = audio.id;
      }
      navigator().push(
        MaterialPageRoute<void>(
          builder: (_) =>
              VoiceTaskScreen(projectId: projectId, captureId: audioCaptureId),
        ),
      );
      await tester.pumpAndSettle();
      if (audioCaptureId == null) {
        await tester.enterText(
          find.byType(TextField).first,
          'Ana needs to finish exercise three in Physics by Thursday. We all need to prepare the final presentation in Physics by Friday.',
        );
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final review = find.text(
        audioCaptureId == null
            ? 'Review tasks from text'
            : 'Try this recording',
      );
      await tester.ensureVisible(review);
      await tester.tap(review);
      await waitFor(
        tester,
        () =>
            find.byType(ReviewTasksScreen).evaluate().isNotEmpty ||
            find
                .textContaining('The processing service is unavailable.')
                .evaluate()
                .isNotEmpty,
        seconds: 100,
      );
      expect(
        find.byType(ReviewTasksScreen),
        findsOneWidget,
        reason: 'The live provider did not return reviewable task drafts.',
      );
      await tester.pumpAndSettle();
      final draftItems = tester
          .widget<ReviewTasksScreen>(find.byType(ReviewTasksScreen))
          .session!
          .remaining
          .toList();
      expect(draftItems, hasLength(2));
      expect(
        draftItems.every(
          (d) =>
              d.ready &&
              d.task.listId == projectId &&
              d.task.deadline != null &&
              !d.task.deadlineHasTime,
        ),
        isTrue,
      );
      expect(draftItems.map((d) => d.task.assignment).toSet(), {
        'member',
        'group',
      });
      await binding.takeScreenshot('projects-voice-review-dark');
      final before = container
          .read(taskProvider)
          .requireValue
          .map((t) => t.id)
          .toSet();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await waitFor(
        tester,
        () => find.byType(ReviewTasksScreen).evaluate().isEmpty,
      );
      await container.read(taskProvider.notifier).loadTasks();
      final added = container
          .read(taskProvider)
          .requireValue
          .where((t) => !before.contains(t.id))
          .toList();
      expect(added, hasLength(2));
      final remote = await api.request('GET', 'tasks/');
      expect(
        (remote['results'] as List)
            .where((t) => t['list_id'] == projectId)
            .length,
        greaterThanOrEqualTo(3),
      );
      debugPrint(
        'PROJECTS_E2E: real ${audioCaptureId == null ? "text" : "audio transcription and"} AI, member/group review and explicit save passed',
      );

      assigned = added.singleWhere((t) => t.assignment == 'member');
    }
    api.offline = true;
    final ownerAccount = container.read(authProvider).account!;
    await container
        .read(taskProvider.notifier)
        .updateTask(
          assigned.copyWith(
            assigneeId: ownerAccount.id,
            assigneeName: 'Project owner',
          ),
        );
    final sql = await TaskDatabase().database;
    var row = (await sql.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [assigned.id],
    )).single;
    expect(row['sync_pending'], 1);
    api.offline = false;
    await container.read(taskProvider.notifier).loadTasks();
    row = (await sql.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [assigned.id],
    )).single;
    expect(row['sync_pending'], 0);
    final uploaded = await api.request('GET', 'tasks/${row['sync_id']}/');
    expect(uploaded['assignee_id'], ownerAccount.id);
    // Leave the reusable synthetic fixture with its original responsibility.
    await container.read(taskProvider.notifier).updateTask(assigned);
    await container.read(taskProvider.notifier).loadTasks();
    final expectedSharedCount = container
        .read(taskProvider)
        .requireValue
        .where((t) => t.listId == projectId)
        .length;

    await container.read(authProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await container.read(authProvider.notifier).signIn(memberEmail, password);
    await container.read(taskProvider.notifier).loadTasks();
    await container.read(taskListsProvider.future);
    await tester.pumpAndSettle();
    expect(container.read(projectScopeProvider).projectId, isNull);
    expect(container.read(projectScopeProvider).team, isFalse);
    expect(
      container.read(taskRepositoryProvider).ownerKey,
      isNot(contains('/users/${ownerAccount.id}')),
    );
    final memberTasks = container.read(taskProvider).requireValue;
    expect(
      memberTasks.where((t) => t.listId == projectId).length,
      expectedSharedCount,
    );
    final notifications = await api.request('GET', 'notifications/');
    expect(notifications['count'], greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    debugPrint(
      'PROJECTS_E2E: persisted offline assignment, second account and notifications passed',
    );
  });
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() check, {
  int seconds = 45,
}) async {
  final timer = Stopwatch()..start();
  while (!check() && timer.elapsed < Duration(seconds: seconds)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    check(),
    isTrue,
    reason: 'The live workflow did not reach the expected state.',
  );
  await tester.pumpAndSettle();
}

class _ConnectionApi extends ApiClient {
  bool offline = false;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) {
    if (offline) throw ApiException(0, 'Offline integration checkpoint');
    return super.request(
      method,
      path,
      data: data,
      audioPath: audioPath,
      authenticated: authenticated,
      accountId: accountId,
    );
  }
}
