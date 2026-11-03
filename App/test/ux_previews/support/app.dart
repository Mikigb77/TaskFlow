// Opens the real app (MyApp) for a preview: signed in or out, with Pro or
// free dictations, tasks and projects in memory, the phone faked.
import 'package:agenda/providers/no_retry.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_group.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/first_task_provider.dart';
import 'package:agenda/providers/free_voice_notice_provider.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/other_settings_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/billing_fixtures.dart';
import '../../support/capture_fixtures.dart' show SilentRecorder;
import '../../support/design_fixtures.dart';
import '../../support/reminder_fixtures.dart';
import 'fakes.dart';
import 'fixtures.dart';
import 'preview.dart';

/// The app running in a preview, with its stand-ins.
class PreviewApp {
  PreviewApp._(
    this.p,
    this.container,
    this.api,
    this.tasks,
    this.lists,
    this.captures,
    this.speech,
    this.reminders,
    this.reminderAccess,
  );
  final Preview p;
  final ProviderContainer container;
  final PreviewApi api;
  final PreviewTasks tasks;
  final PreviewLists lists;
  final PreviewCaptures captures;
  final PreviewSpeech speech;
  final MemoryReminderStore reminders;
  final FakeReminderAccess reminderAccess;

  WidgetTester get tester => p.tester;

  /// Opens the app in the preview's language and theme, on Calendar.
  /// [user] null is signed out; [freeLeft] gives an account without Pro its
  /// free dictations this month.
  static Future<PreviewApp> open(
    Preview p, {
    Map<String, dynamic>? user,
    bool signedIn = true,
    bool pro = true,
    int? freeLeft,
    bool billingLoading = false,
    List<Task> tasks = const [],
    List<TaskListInfo> projects = const [],
    bool hadTask = true,
    bool privacyShown = true,
    // «A tu manera» has shown its privacy line on this phone.
    bool reminderPrivacyShown = true,
    SpeechPermission mic = SpeechPermission.granted,
    bool notificationsAllowed = true,
    bool exactAlarms = true,
    // The alerts the phone keeps, as `reminder_state` rows with `snooze_at`:
    // a reminder that has rung, or is snoozed.
    List<Map<String, Object?>> phoneAlerts = const [],
    // The saved session is still being read.
    bool restoring = false,
    // The app's language has on-device speech on this phone.
    bool speechInstalled = true,
    // Capture diagnostics' recorded timings, read from the phone.
    List<Map<String, Object?>>? diagnostics,
    // A returning user said yes to reminders. First runs pass the default
    // `ReminderPreferences()`: off, and not asked yet.
    ReminderPreferences reminders = const ReminderPreferences(
      enabled: true,
      asked: true,
    ),
    List<CaptureSession> captures = const [],
    List<TaskGroupInfo> groups = const [],
    List<PendingInvitation> invitations = const [],
    List<Map<String, dynamic>> activity = const [],
    int unread = 0,
    // The phone's calendars: their permission, events, and whether Calendar
    // shows them.
    CalendarAccess calendarAccess = CalendarAccess.denied,
    List<DeviceCalendarEvent> phoneEvents = const [],
    CalendarPreferences phoneCalendars = const CalendarPreferences(),
    String? syncError,
    // Billing as the Pro screen reads it: the store (RevenueCat) answering
    // [billing]. Without it the app's own controller runs, unconfigured.
    FakeRevenueCat? billing,
    bool complimentary = false,
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    final api = PreviewApi();
    final memory = PreviewTasks(tasks);
    final lists = PreviewLists(projects);
    final store = PreviewCaptures(
      memory,
      database: diagnostics == null
          ? null
          : TaskDatabase.forTesting(DiagnosticsDatabase(diagnostics)),
    );
    for (final session in captures) {
      store.sessions[session.id] = session;
    }
    final speech = PreviewSpeech(
      access: mic,
      installed: speechInstalled,
      language: switch (p.variant.lang) {
        'ca' => 'ca-ES',
        'en' => 'en-GB',
        _ => 'es-ES',
      },
    );
    SubscriptionController? subscription;
    if (billing != null) {
      // A Play Store key, as in a release build: no test-store banner.
      subscription = SubscriptionController(
        billing,
        const BillingConfiguration(apiKey: 'goog_preview', supported: true),
      );
      await subscription.setIdentity(
        'owner',
        () async => 'owner-id',
        complimentary: complimentary,
      );
    }
    final reminderStore = MemoryReminderStore(reminders);
    final phone = PreviewDeviceCalendars(access: calendarAccess)
      ..data = phoneEvents;
    final access = FakeReminderAccess(
      allowed: notificationsAllowed,
      exact: exactAlarms,
    )..kept = [...phoneAlerts];
    // Secure storage (the session, an address waiting for its code) answers
    // from memory: start-up waits for it before showing a signed-out screen.
    FlutterSecureStorage.setMockInitialValues({});
    final container = ProviderContainer(
      retry: noRetry,
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(pro),
        billingLoadingProvider.overrideWithValue(billingLoading),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith(
          (ref) => PreviewAuth(
            api,
            !signedIn ? null : (user ?? account(freeLeft: freeLeft)),
            restoring: restoring,
          ),
        ),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(
            RegionalPreferences(
              language: p.variant.lang,
              clock: ClockFormat.twentyFour,
              weekStart: 1,
              privacyShown: privacyShown,
              reminderPrivacyShown: reminderPrivacyShown,
            ),
          ),
        ),
        taskListStoreProvider.overrideWithValue(lists),
        taskListsProvider.overrideWith((ref) {
          ref.watch(taskProvider);
          return lists.all();
        }),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => memory),
        themeStoreProvider.overrideWithValue(
          MemoryThemeStore(p.variant.dark ? 'dark' : 'light'),
        ),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(speech),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
        calendarClockProvider.overrideWithValue(() => previewNow),
        firstTaskStoreProvider.overrideWithValue(
          MemoryFirstTaskStore([if (hadTask) MemoryTasks().ownerKey]),
        ),
        freeVoiceNoticeStoreProvider.overrideWithValue(MemoryNotices()),
        ...reminderOverrides(reminderStore, access),
        // The server's collaboration lists, answered at once.
        groupsProvider.overrideWith((ref) async => groups),
        pendingInvitationsProvider.overrideWith((ref) async => invitations),
        collaborationActivityProvider.overrideWith((ref) async => activity),
        collaborationUnreadProvider.overrideWith((ref) async => unread),
        deviceCalendarsProvider.overrideWithValue(phone),
        googleSignInServiceProvider.overrideWithValue(PreviewGoogle()),
        appVersionProvider.overrideWith((ref) async => '1.0.5 (4007)'),
        if (subscription != null) ...[
          subscriptionProvider.overrideWith((ref) => subscription!),
          billingConfigurationProvider.overrideWithValue(
            subscription.configuration,
          ),
        ],
        calendarPreferenceStoreProvider.overrideWithValue(
          PreviewCalendarPreferences(phoneCalendars),
        ),
        // The preview's own, last: they win.
        ...overrides,
      ],
    );
    // What the last sync left, as the repository reports it.
    container.read(taskRepositoryProvider).syncError = syncError;
    p.onTearDown(() async {
      api.release();
      await p.tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      api.close();
      phone.close();
    });
    await p.tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: p.frame(const MyApp()),
      ),
    );
    if (settle) {
      await p.tester.pumpAndSettle();
    } else {
      await p.frames(5, const Duration(milliseconds: 100));
    }
    return PreviewApp._(
      p,
      container,
      api,
      memory,
      lists,
      store,
      speech,
      reminderStore,
      access,
    );
  }

  /// The app's navigator, for routes the app opens by name.
  NavigatorState get navigator =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  /// A context inside the app, under its MaterialApp.
  BuildContext get context => tester.element(find.byType(Scaffold).first);

  /// Scrolls the text [label] into view, taps it, and settles.
  Future<void> tap(String label) async {
    final text = find.text(label);
    if (text.hitTestable().evaluate().isEmpty) {
      if (text.evaluate().isEmpty) {
        // Not built yet: further down a lazy list.
        await tester.scrollUntilVisible(text, 200, scrollable: mainScroll());
      } else {
        await tester.ensureVisible(text.first);
      }
      await tester.pumpAndSettle();
    }
    await tester.tap(text.hitTestable().first);
    await tester.pumpAndSettle();
  }

  /// The screen's main vertical list: the largest one on stage.
  Finder mainScroll() {
    final lists = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axis == Axis.vertical,
    );
    Element? largest;
    var area = 0.0;
    for (final element in lists.evaluate()) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.hasSize) continue;
      final size = box.size.width * box.size.height;
      if (size > area) {
        area = size;
        largest = element;
      }
    }
    return largest == null
        ? lists.first
        : find.byElementPredicate((element) => identical(element, largest));
  }

  /// Pushes [route] by name, and settles.
  Future<void> push(String route, {Object? arguments}) async {
    navigator.pushNamed(route, arguments: arguments);
    await tester.pumpAndSettle();
  }

  /// Pushes a page built by [builder], and settles.
  Future<void> pushPage(Widget page) async {
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  /// One of the tabs: Calendario, Tareas, Notas, Ajustes.
  Future<void> tab(String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }
}
