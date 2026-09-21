// Requires the local Docker backend and its configured Google models.
// Creates one synthetic account/task; never records the user's microphone.
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/create_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android account, AI review, task backup and re-login',
      (tester) async {
    tzdata.initializeTimeZones();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await waitFor(tester, () => !container.read(authProvider).loading);
    await container.read(authProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);

    final email =
        'android-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
    const password = 'Android-testing-7!only';
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('account-email')), email);
    await tester.enterText(
        find.byKey(const ValueKey('account-password')), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final register = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(register);
    await tester.tap(register);
    await waitFor(tester, () => container.read(authProvider).account != null);
    expect(container.read(authProvider).account!.email, email);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Create task with voice'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first,
        'On Friday at 5 p.m. I have an appointment with the doctor. '
        'I need to bring my blood test results from last month.');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final generate =
        find.widgetWithText(OutlinedButton, 'Create draft from text');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await waitFor(
        tester, () => find.byType(CreateTaskScreen).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 120));
    await tester.pumpAndSettle();
    final screen =
        tester.widget<CreateTaskScreen>(find.byType(CreateTaskScreen));
    final draft = screen.initialDraft!;
    expect(draft.title.toLowerCase(), contains('doctor'));
    expect(draft.dueDate!.weekday, DateTime.friday);
    expect(draft.dueDate!.hour, 17);
    expect(draft.priority, 3);
    expect(draft.notes.toLowerCase(), contains('blood'));
    expect(
        (await container
            .read(apiClientProvider)
            .request('GET', 'tasks/'))['count'],
        0);
    final save = find.widgetWithText(ElevatedButton, 'Create Task');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await waitFor(
        tester, () => find.byType(CreateTaskScreen).evaluate().isEmpty);
    await container.read(taskProvider.notifier).loadTasks();
    expect(container.read(taskRepositoryProvider).syncError, isNull);
    final saved =
        await container.read(apiClientProvider).request('GET', 'tasks/');
    expect(saved['count'], 1);
    expect(saved['results'][0]['title'], draft.title);
    expect(DateTime.parse(saved['results'][0]['due_date']).toLocal(),
        draft.dueDate);

    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    expect(find.text(draft.title), findsOneWidget);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await waitFor(tester, () => container.read(authProvider).account == null);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(container.read(taskProvider).valueOrNull ?? [], isEmpty);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('account-email')), email);
    await tester.enterText(
        find.byKey(const ValueKey('account-password')), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final login = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(login);
    await tester.tap(login);
    await waitFor(tester, () => container.read(authProvider).account != null);
    await container.read(taskProvider.notifier).loadTasks();
    expect(container.read(taskProvider).requireValue.single.title, draft.title);
    await container.read(authProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> waitFor(WidgetTester tester, bool Function() condition,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final watch = Stopwatch()..start();
  while (!condition() && watch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(condition(), isTrue,
      reason: 'The expected app state was not reached.');
}
