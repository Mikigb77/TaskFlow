import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_list_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/billing_fixtures.dart';
import 'support/design_fixtures.dart';

final shared = TaskListInfo(
  id: 'physics',
  name: 'Physics',
  groupId: 'master',
  groupName: 'Master',
  shared: true,
  people: const [
    ProjectMember(id: 1, name: 'Miki', role: 'owner'),
    ProjectMember(id: 2, name: 'Ana', role: 'editor'),
    ProjectMember(id: 3, name: 'Alex', role: 'viewer'),
  ],
);

Widget localized(
  Widget home, {
  String language = 'en',
  bool dark = false,
  double scale = 1,
}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: dark ? AppTheme.dark : AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  testWidgets(
    'assignment picker exposes audience and excludes viewers from responsibility',
    (tester) async {
      var task = Task(
        title: 'Exercise three',
        priority: 1,
        listId: shared.id,
        assignment: 'group',
      );
      final api = OfflineApiClient();
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
            taskListsProvider.overrideWith((ref) async => [shared]),
          ],
          child: localized(
            Scaffold(
              body: StatefulBuilder(
                builder: (context, change) => TaskAssignmentPicker(
                  task: task,
                  onChanged: (value) => change(() => task = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Visible to everyone in Master'), findsOneWidget);
      await tester.tap(find.text('Everyone'));
      await tester.pumpAndSettle();
      expect(find.text('Alex'), findsNothing);
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      expect(task.assignment, 'member');
      expect(task.assigneeId, 2);
      expect(find.text('Visible to everyone in Master'), findsOneWidget);
      await tester.tap(find.text('Physics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal inbox'));
      await tester.pumpAndSettle();
      expect(task.assignment, 'personal');
      expect(task.assigneeId, isNull);
      expect(task.listId, isNull);
      expect(find.text('Only you can see this.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'es', 'ca']) {
    for (final dark in [false, true]) {
      testWidgets(
        'assignment review and members fit $language, dark=$dark, large text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 680);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = OfflineApiClient();
          addTearDown(api.close);
          final controller = SubscriptionController(
            FakeRevenueCat(),
            const BillingConfiguration(apiKey: 'test_fixture', supported: true),
          );
          await controller.setIdentity(
            'fixture',
            () async => 'billing-fixture',
          );
          final overrides = [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
            taskListsProvider.overrideWith((ref) async => [shared]),
            subscriptionProvider.overrideWith((ref) => controller),
            groupDetailsProvider('master').overrideWith(
              (ref) async => {
                'group': {
                  'id': 'master',
                  'name': 'Master',
                  'owner_id': 1,
                  'version': 1,
                  'role': 'viewer',
                  'project_count': 1,
                  'people': shared.people.map((p) => p.toJson()).toList(),
                },
              },
            ),
          ];
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: localized(
                Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: TaskAssignmentPicker(
                      task: Task(
                        title: 'Exercise',
                        priority: 1,
                        listId: shared.id,
                        assignment: 'unassigned',
                      ),
                      needsReview: true,
                      hints: const {'member_name': 'Alex'},
                      onChanged: (_) {},
                      onReviewed: () {},
                    ),
                  ),
                ),
                language: language,
                dark: dark,
                scale: 1.8,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: localized(
                const GroupScreen(groupId: 'master'),
                language: language,
                dark: dark,
                scale: 1.8,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final text = lookupAppLocalizations(Locale(language));
          expect(find.text(text.invitePerson), findsNothing);
          expect(find.byIcon(Icons.manage_accounts_outlined), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'unpaid shortcut and recovered capture cannot initialize a microphone',
    (tester) async {
      final controller = SubscriptionController(
        FakeRevenueCat(),
        const BillingConfiguration(apiKey: 'test_fixture', supported: true),
      );
      await controller.setIdentity('fixture', () async => 'billing-fixture');
      var recorderCreated = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionProvider.overrideWith((ref) => controller),
            captureRecorderFactoryProvider.overrideWithValue(() {
              recorderCreated = true;
              throw StateError('Must not create a recorder');
            }),
          ],
          child: localized(
            const VoiceTaskScreen(
              startListening: true,
              captureId: 'retained-capture',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The time zone lookup gives up after 5 s.
      await tester.pump(const Duration(seconds: 6));
      // Without Pro the sheet types: no Pro wall, and no recorder.
      expect(
        find.text('Voice capture is included with TaskFlow Pro.'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('capture-words')), findsOneWidget);
      expect(recorderCreated, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  group('P12: moving a task into a project is safe and findable', () {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () =>
          platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
    );
    tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    final es = lookupAppLocalizations(const Locale('es'));
    final home = TaskListInfo(id: 'home', name: 'Casa');

    Future<Task Function()> pickFor(
      WidgetTester tester,
      Task initial, {
      bool dark = false,
      bool needsReview = false,
      VoidCallback? onReviewed,
    }) async {
      var task = initial;
      final api = OfflineApiClient();
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
            taskListsProvider.overrideWith((ref) async => [shared, home]),
            groupsProvider.overrideWith((ref) async => []),
          ],
          child: localized(
            Scaffold(
              body: StatefulBuilder(
                // As the task's detail screen uses it: the task exists.
                builder: (context, change) => TaskAssignmentPicker(
                  task: task,
                  lockShared: true,
                  needsReview: needsReview,
                  onReviewed: onReviewed,
                  onChanged: (value) => change(() => task = value),
                ),
              ),
            ),
            language: 'es',
            dark: dark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return () => task;
    }

    testWidgets(
      'UX-302: choosing a shared project for a personal task asks first; Cancelar leaves it, Compartir moves it',
      (tester) async {
        final task = await pickFor(
          tester,
          Task(id: 1, title: 'Comprar pan', priority: 1),
        );
        // UX-324: the chip reads as a control.
        final chip = find.widgetWithText(ActionChip, es.noList);
        expect(
          find.descendant(
            of: chip,
            matching: find.byIcon(Icons.arrow_drop_down_rounded),
          ),
          findsOneWidget,
        );
        Future<void> choosePhysics() async {
          await tester.tap(find.widgetWithText(ActionChip, es.noList));
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          // UX-308: titled Proyecto, without the old subtitle.
          expect(
            find.descendant(of: sheet, matching: find.text(es.list)),
            findsOneWidget,
          );
          // UX-324: a shared row's subtitle is just the group's name.
          final row = find.widgetWithText(ListTile, 'Physics');
          expect(
            find.descendant(of: row, matching: find.text('Master')),
            findsOneWidget,
          );
          await tester.tap(row);
          await tester.pumpAndSettle();
        }

        await choosePhysics();
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(es.shareTaskConfirm('Master')),
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, es.shareTask), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(task().listId, isNull);
        expect(task().assignment, isNot('group'));

        await choosePhysics();
        await tester.tap(find.widgetWithText(FilledButton, es.shareTask));
        await tester.pumpAndSettle();
        expect(task().listId, shared.id);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-302: moving a personal task into a personal project asks nothing',
      (tester) async {
        final task = await pickFor(
          tester,
          Task(id: 1, title: 'Comprar pan', priority: 1),
        );
        await tester.tap(find.widgetWithText(ActionChip, es.noList));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Casa'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(task().listId, home.id);
        expect(tester.takeException(), isNull);
      },
    );

    for (final dark in [false, true]) {
      testWidgets(
        'UX-302: a shared task’s project chip is drawn enabled, and a tap says it stays in its project (dark=$dark)',
        (tester) async {
          final task = await pickFor(
            tester,
            Task(
              id: 1,
              title: 'Ejercicio tres',
              priority: 1,
              listId: shared.id,
              assignment: 'group',
            ),
            dark: dark,
          );
          final chip = find.widgetWithText(ActionChip, 'Physics');
          expect(chip, findsOneWidget);
          expect(tester.widget<ActionChip>(chip).isEnabled, isTrue);
          final label = find.descendant(
            of: chip,
            matching: find.text('Physics'),
          );
          final colors = Theme.of(tester.element(chip)).colorScheme;
          final color = tester
              .renderObject<RenderParagraph>(label)
              .text
              .style
              ?.color;
          expect(color, colors.onSurface);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(find.text(es.sharedTaskStays), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          expect(task().listId, shared.id);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final dark in [false, true]) {
      testWidgets(
        'UX-325: when the assistant isn’t sure, it asks ¿Es correcto? with one Sí, in no error colour (dark=$dark)',
        (tester) async {
          var reviewed = 0;
          await pickFor(
            tester,
            Task(
              id: 1,
              title: 'Ejercicio',
              priority: 1,
              listId: shared.id,
              assignment: 'group',
            ),
            dark: dark,
            needsReview: true,
            onReviewed: () => reviewed++,
          );
          final question = find.text(es.assignmentIsRight);
          expect(question, findsOneWidget);
          final yes = find.widgetWithText(TextButton, es.yes);
          expect(yes, findsOneWidget);
          final colors = Theme.of(tester.element(question)).colorScheme;
          expect(
            tester.renderObject<RenderParagraph>(question).text.style?.color,
            isNot(colors.error),
          );
          for (final element
              in find
                  .descendant(
                    of: find.byType(TaskAssignmentPicker),
                    matching: find.byType(RichText),
                  )
                  .evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(
              paragraph.text.style?.color,
              isNot(colors.error),
              reason: paragraph.text.toPlainText(),
            );
          }
          await tester.tap(yes);
          await tester.pumpAndSettle();
          expect(reviewed, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-443: the project sheet marks a project shared person by person as Compartido, a group project with its group, a personal one with nothing ($language)',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final byPerson = TaskListInfo(
          id: 'trip',
          name: 'Viaje',
          shared: true,
          people: const [
            ProjectMember(id: 1, name: 'Miki', role: 'owner'),
            ProjectMember(id: 2, name: 'Ana', role: 'editor'),
          ],
        );
        final personal = TaskListInfo(id: 'home', name: 'Casa');
        final api = OfflineApiClient();
        addTearDown(api.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
              taskListsProvider.overrideWith(
                (ref) async => [byPerson, shared, personal],
              ),
            ],
            child: localized(
              Scaffold(body: TaskListPicker(listId: null, onChanged: (_) {})),
              language: language,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionChip, l.noList));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        ListTile row(String name) => tester.widget<ListTile>(
          find.descendant(
            of: sheet,
            matching: find.widgetWithText(ListTile, name),
          ),
        );
        String? subtitle(String name) => (row(name).subtitle as Text?)?.data;
        expect(subtitle('Viaje'), l.sharedProject);
        expect(subtitle('Physics'), 'Master');
        expect(subtitle('Casa'), isNull);
        expect(
          find.descendant(of: sheet, matching: find.text(l.sharedProject)),
          findsOneWidget,
        );
        expect(
          l.sharedProject,
          {'es': 'Compartido', 'en': 'Shared', 'ca': 'Compartit'}[language],
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
