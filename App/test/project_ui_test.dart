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
import 'package:flutter/material.dart';
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
              startRecording: true,
              captureId: 'retained-capture',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Voice capture is included with TaskFlow Pro.'),
        findsOneWidget,
      );
      expect(recorderCreated, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
