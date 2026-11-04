import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Uses the local Docker backend with explicit fixture AI. Real paid AI is covered by projects_flow_test.
// Uses synthetic accounts/tasks; never records the user's microphone.
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android account, AI review, task backup and re-login',
    (tester) async {
      expect(
        const bool.fromEnvironment('FIXTURE_AI'),
        isTrue,
        reason:
            'Use FIXTURE_AI=true here; run projects_flow_test for real paid extraction.',
      );
      FlutterSecureStorage.setMockInitialValues({});
      tzdata.initializeTimeZones();
      final container = ProviderContainer(
        retry: noRetry,
        overrides: [
          hasProProvider.overrideWithValue(true),
          if (const bool.fromEnvironment('FIXTURE_AI'))
            apiClientProvider.overrideWith((ref) {
              final api = _FixtureAiClient();
              ref.onDispose(api.close);
              return api;
            }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await waitFor(tester, () => !container.read(authProvider).loading);
      await container.read(authProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();

      final email =
          'android-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
      const password = 'Android-testing-7!only';
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        email,
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        password,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final register = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(register);
      await tester.tap(register);
      await waitFor(tester, () => container.read(authProvider).account != null);
      expect(container.read(authProvider).account!.email, email);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);

      // Signed-in capture exercises resumable account-scoped persistence.
      final owner = container.read(captureOwnerProvider);
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        startListening: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Type instead'));
      await tester.pumpAndSettle();
      final captureTitle =
          'Buy coffee ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(
        find.byKey(const ValueKey('capture-words')),
        '$captureTitle sometime. Pay my electricity bill on Friday.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      // Leave the route and resume from the real Android SQLite capture store.
      final captureStore = container.read(captureStoreProvider);
      final persisted = Stopwatch()..start();
      while (!(await captureStore.pending(owner)).any(
        (s) =>
            s.text ==
            '$captureTitle sometime. Pay my electricity bill on Friday.',
      )) {
        if (persisted.elapsed > const Duration(seconds: 10)) {
          fail('The typed capture was not durably saved.');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      final unfinished = (await captureStore.pending(
        owner,
      )).firstWhere((s) => s.text.startsWith(captureTitle));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        captureId: unfinished.id,
        startListening: false,
      );
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => find
            .text('$captureTitle sometime. Pay my electricity bill on Friday.')
            .evaluate()
            .isNotEmpty,
      );
      final captureGenerate = find.widgetWithText(FilledButton, 'Done');
      await tester.ensureVisible(captureGenerate);
      await tester.tap(captureGenerate);
      await waitFor(
        tester,
        () => find.byType(CaptureResult).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 120),
      );
      await tester.pumpAndSettle();
      final captureDrafts = tester
          .widget<CaptureResult>(find.byType(CaptureResult))
          .session
          .remaining
          .map((d) => d.task)
          .toList();
      expect(captureDrafts.length, 2);
      expect(captureDrafts.where((draft) => draft.dueDate == null).length, 1);
      expect(captureDrafts.every((draft) => !draft.hasTime), isTrue);
      await binding.takeScreenshot('flexible-inbox-review');
      final beforeCapture =
          (container.read(taskProvider).value ?? <Task>[])
              .map((t) => t.id)
              .toSet();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await waitFor(
        tester,
        () => find.byType(CaptureResult).evaluate().isEmpty,
      );
      await container.read(taskProvider.notifier).loadTasks();
      final addedCapture = container
          .read(taskProvider)
          .requireValue
          .where((t) => !beforeCapture.contains(t.id))
          .toList();
      expect(addedCapture.length, 2);
      for (final task in addedCapture) {
        await container.read(taskProvider.notifier).deleteTask(task.id!);
      }
      await container.read(taskProvider.notifier).loadTasks();
      await tester.pumpAndSettle();

      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        startListening: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Type instead'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-words')),
        'On Friday at 5 p.m. I have an appointment with the doctor. '
        'I need to bring my blood test results from last month. Also buy coffee sometime. '
        'Water the plants every Sunday at 9 a.m.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final generate = find.widgetWithText(FilledButton, 'Done');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await waitFor(
        tester,
        () => find.byType(CaptureResult).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 120),
      );
      await tester.pumpAndSettle();
      final screen = tester.widget<CaptureResult>(
        find.byType(CaptureResult),
      );
      final drafts = screen.session.remaining.map((d) => d.task).toList();
      expect(drafts.length, 3);
      final draft = drafts.firstWhere(
        (d) => d.title.toLowerCase().contains('doctor'),
      );
      expect(drafts.any((d) => d.dueDate == null), isTrue);
      expect(drafts.any((d) => d.recurrence == 'weekly'), isTrue);
      expect(draft.title.toLowerCase(), contains('doctor'));
      expect(draft.dueDate!.weekday, DateTime.friday);
      expect(draft.dueDate!.hour, 17);
      expect(draft.priority, 3);
      expect(draft.notes!.toLowerCase(), contains('blood'));
      await binding.takeScreenshot('flexible-batch-review');
      expect(
        (await container
            .read(apiClientProvider)
            .request('GET', 'tasks/'))['count'],
        0,
      );
      final save = find.byKey(const ValueKey('save-drafts'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await waitFor(
        tester,
        () => find.byType(CaptureResult).evaluate().isEmpty,
      );
      await container.read(taskProvider.notifier).loadTasks();
      expect(container.read(taskRepositoryProvider).syncError, isNull);
      final saved = await container
          .read(apiClientProvider)
          .request('GET', 'tasks/');
      expect(saved['count'], 3);
      final doctor = (saved['results'] as List).firstWhere(
        (t) => t['title'] == draft.title,
      );
      expect(DateTime.parse(doctor['due_date']).toLocal(), draft.dueDate);

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text(draft.title), findsOneWidget);
      await binding.takeScreenshot('flexible-tasks');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Inbox'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('flexible-inbox');
      final plants = container
          .read(taskProvider)
          .requireValue
          .firstWhere((t) => t.recurrence == 'weekly');
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/editTask', arguments: plants.id);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('flexible-repeat-editor');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await waitFor(tester, () => container.read(authProvider).account == null);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CalendarScreen), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        email,
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        password,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final login = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(login);
      await tester.tap(login);
      await waitFor(tester, () => container.read(authProvider).account != null);
      await container.read(taskProvider.notifier).loadTasks();
      expect(container.read(taskProvider).requireValue.length, 3);
      expect(
        container
            .read(taskProvider)
            .requireValue
            .any((t) => t.title == draft.title),
        isTrue,
      );
      await container.read(authProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final watch = Stopwatch()..start();
  while (!condition() && watch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 250));
    final errors = tester
        .widgetList<MessageBanner>(find.byType(MessageBanner))
        .where((banner) => banner.isError)
        .map((banner) => banner.message)
        .toList();
    if (errors.isNotEmpty) fail('The app reported: ${errors.join(' | ')}');
  }
  expect(
    condition(),
    isTrue,
    reason: 'The expected app state was not reached.',
  );
}

// Only AI is substituted in this optional mode. Auth, SQLite, HTTP sync,
// PostgreSQL persistence and restoration still use the real running backend.
class _FixtureAiClient extends ApiClient {
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (path != 'ai/drafts/') {
      return super.request(
        method,
        path,
        data: data,
        audioPath: audioPath,
        authenticated: authenticated,
        accountId: accountId,
      );
    }
    expect(authenticated, isTrue);
    expect(account, isNotNull);
    final now = DateTime.now();
    DateTime next(int weekday, int hour) {
      var date = DateTime(
        now.year,
        now.month,
        now.day + (weekday - now.weekday + 7) % 7,
        hour,
      );
      if (date.isBefore(now)) date = date.add(const Duration(days: 7));
      return date;
    }

    final friday = next(DateTime.friday, 17);
    Map<String, dynamic> task(
      String title, {
      DateTime? due,
      String? day,
      String repeat = 'none',
      String notes = '',
      int priority = 1,
    }) => {
      'title': title,
      'due_date': due?.toUtc().toIso8601String(),
      'scheduled_date': day,
      'recurrence': repeat,
      'priority': priority,
      'notes': notes,
      'questions': <String>[],
    };
    return {
      'transcript': data!['text'],
      'tasks': (data['text'] as String).contains('electricity bill')
          ? [
              task('Buy coffee'),
              task('Pay electricity bill', day: Task.dateKey(friday)),
            ]
          : [
              task(
                'Doctor appointment',
                due: friday,
                priority: 3,
                notes: 'Bring blood test results from last month.',
              ),
              task('Buy coffee'),
              task(
                'Water plants',
                due: next(DateTime.sunday, 9),
                repeat: 'weekly',
              ),
            ],
    };
  }
}
