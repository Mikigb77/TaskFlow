import 'package:agenda/widgets/app_components.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/screens/main_shell.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/screens/completed_tasks_screen.dart';
import 'package:agenda/screens/create_task_screen.dart';
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/account_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/screens/captures_screen.dart';
import 'package:agenda/screens/capture_diagnostics_screen.dart';
import 'package:agenda/screens/notification_settings_screen.dart';
import 'package:agenda/screens/task_lists_screen.dart';
import 'package:agenda/screens/data_transfer_screen.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/screens/day_timeline_screen.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/screens/regional_settings_screen.dart';
import 'package:agenda/screens/device_calendars_screen.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/screens/invitation_review_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  try {
    await TaskReminders.initialize();
  } catch (_) {
    await TaskReminders.recordError('setup_failed');
  }
  final appearance = ThemeController(ThemePreferenceStore());
  final regional = RegionalController(RegionalPreferenceStore());
  await Future.wait([appearance.ready, regional.ready]);
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => appearance),
        regionalProvider.overrideWith((ref) => regional),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  var _navigator = GlobalKey<NavigatorState>();
  String? _navigationSession;
  StreamSubscription<void>? _actions;
  StreamSubscription<void>? _entries;
  bool _openingEntry = false;
  bool _openingInvitation = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(invitationLinkProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInvitation());
    TaskReminders.openRequest.addListener(_openReminder);
    // Scheduling also emits changes; reload only in response to action callbacks.
    _actions = TaskReminders.actionChanges.stream.listen((_) {
      if (mounted && ref.read(authProvider).account != null) {
        ref.read(taskProvider.notifier).loadTasks();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _openReminder());
    _entries = ref
        .read(captureEntriesProvider)
        .changes
        .listen((_) => _openEntries());
    WidgetsBinding.instance.addPostFrameCallback((_) => _openEntries());
  }

  @override
  void dispose() {
    TaskReminders.openRequest.removeListener(_openReminder);
    WidgetsBinding.instance.removeObserver(this);
    _actions?.cancel();
    _entries?.cancel();
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted) setState(() {});
    unawaited(TaskReminders.refreshLanguage());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh the device clock choice after returning from system settings.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      unawaited(TaskReminders.refreshLanguage());
      unawaited(ref.read(subscriptionProvider.notifier).refresh());
      ref.invalidate(collaborationUnreadProvider);
    }
  }

  Future<void> _openEntries() async {
    if (!mounted ||
        _openingEntry ||
        ref.read(authProvider).loading ||
        ref.read(authProvider).account == null ||
        _navigator.currentState == null) {
      return;
    }
    _openingEntry = true;
    final entries = ref.read(captureEntriesProvider);
    try {
      while (mounted &&
          !ref.read(authProvider).loading &&
          ref.read(authProvider).account != null) {
        final pending = await entries.pending();
        if (pending.isEmpty ||
            !mounted ||
            ref.read(authProvider).account == null ||
            ref.read(authProvider).loading) {
          break;
        }
        final entry = pending.first;
        final owner = ref.read(captureOwnerProvider);
        await ref.read(regionalProvider.notifier).ready;
        final zone = await CaptureTimezone.resolve(
          ref.read(regionalProvider),
          accountTimezone: ref.read(authProvider).account?.timezone,
        );
        if (!mounted ||
            ref.read(authProvider).account == null ||
            owner != ref.read(captureOwnerProvider)) {
          break;
        }
        final session = await ref
            .read(captureStoreProvider)
            .acceptEntry(
              entry.id,
              owner,
              zone.identifier,
              text: entry.text,
              capturedAt: entry.capturedAt,
            );
        await entries.acknowledge(entry.id);
        if (!mounted || owner != ref.read(captureOwnerProvider)) continue;
        ref.invalidate(pendingCapturesProvider);
        if (session == null || session.terminal) continue;
        await CaptureInterruption.stop();
        if (!mounted || owner != ref.read(captureOwnerProvider)) continue;
        unawaited(
          showCaptureSheet(
            _navigator.currentContext!,
            captureId: session.id,
            startListening: entry.kind == 'voice',
          ),
        );
      }
    } catch (_) {
      if (mounted && _navigator.currentContext != null) {
        final messenger = ScaffoldMessenger.maybeOf(_navigator.currentContext!);
        if (messenger != null) {
          unawaited(
            showFeedback(
              messenger,
              _navigator.currentContext!.l10n.sharedCaptureRetained,
            ),
          );
        }
      }
    } finally {
      _openingEntry = false;
    }
  }

  Future<void> _openInvitation() async {
    if (!mounted ||
        _openingInvitation ||
        ref.read(authProvider).loading ||
        ref.read(authProvider).account == null ||
        _navigator.currentState == null) {
      return;
    }
    final invitation = ref.read(invitationLinkProvider);
    if (invitation == null) return;
    _openingInvitation = true;
    try {
      final handled = await _navigator.currentState!.push<bool>(
        MaterialPageRoute(
          builder: (_) => InvitationReviewScreen(invitation: invitation),
        ),
      );
      if (mounted && handled == true) {
        ref.read(invitationLinkProvider.notifier).clear(invitation);
      }
    } finally {
      _openingInvitation = false;
    }
  }

  Future<void> _openReminder() async {
    if (!mounted ||
        ref.read(authProvider).loading ||
        ref.read(authProvider).account == null) {
      return;
    }
    final session = _navigationSession;
    final id = TaskReminders.openRequest.value;
    if (id == null) return;
    TaskReminders.openRequest.value = null;
    final task = await TaskReminders.engine.taskForAlert(
      id.id,
      token: id.token,
    );
    if (!mounted || session != _navigationSession) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          session == _navigationSession &&
          ref.read(authProvider).account != null &&
          _navigator.currentState != null) {
        _navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => task == null
                ? const MainShell()
                : TaskDetailScreen(
                    taskId: task.id!,
                    occurrenceDate: task.occurrenceDate,
                    occurrenceKey: task.occurrenceId,
                  ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep the SDK identity listener alive without rebuilding for every billing update.
    ref.watch(subscriptionProvider.select((_) => null));
    ref.listen(hasProProvider, (previous, active) {
      if (active && previous != true) {
        final accountId = ref.read(authProvider).account?.id;
        if (accountId != null) {
          // Clear a recent negative server lookup after purchase or restore.
          // The server independently rechecks the account's RevenueCat identity.
          unawaited(
            ref
                .read(apiClientProvider)
                .request('POST', 'billing/access/', accountId: accountId)
                .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
          );
        }
      }
    });
    ref.listen(authProvider, (previous, next) {
      if (!next.loading && next.account != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openReminder());
        WidgetsBinding.instance.addPostFrameCallback((_) => _openEntries());
        WidgetsBinding.instance.addPostFrameCallback((_) => _openInvitation());
      }
    });
    ref.listen(invitationLinkProvider, (_, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openInvitation());
      }
    });
    final auth = ref.watch(authProvider);
    final signedIn = auth.account != null;
    final session = auth.restoring
        ? 'restoring'
        : signedIn
        ? '${ref.read(apiClientProvider).baseUrl}/users/${auth.account!.id}'
        : 'signed-out';
    if (session != _navigationSession) {
      _navigationSession = session;
      // A fresh navigator prevents Back from restoring protected routes after logout.
      _navigator = GlobalKey<NavigatorState>();
    }
    final regional = ref.watch(regionalProvider);
    final system24Hour =
        !kIsWeb &&
            [
              TargetPlatform.android,
              TargetPlatform.iOS,
            ].contains(defaultTargetPlatform)
        ? WidgetsBinding.instance.platformDispatcher.alwaysUse24HourFormat
        : null;
    return MaterialApp(
      // Clear forms and navigation when accounts change; never show another account's task.
      key: ValueKey(session),
      navigatorKey: _navigator,
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: regional.localeFor(
        WidgetsBinding.instance.platformDispatcher.locales,
      ),
      localeListResolutionCallback: (devices, supported) =>
          regional.localeFor(devices),
      localizationsDelegates: [
        RegionalMaterialDelegate(
          regional,
          WidgetsBinding.instance.platformDispatcher.locales.firstOrNull ??
              const Locale('en'),
          system24Hour: system24Hour,
        ),
        ...AppLocalizations.localizationsDelegates,
      ],
      builder: (context, child) =>
          regionalMedia(regional, context, child, system24Hour: system24Hour),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 220),
      initialRoute: '/',
      routes: !signedIn
          ? {
              '/': (_) => auth.restoring
                  ? const SessionLoadingScreen()
                  : const LoginScreen(),
            }
          : {
              '/': (_) => const MainShell(),
              '/home': (_) => const MainShell(initialIndex: 1),
              '/inbox': (_) =>
                  const HomeScreen(initialFilter: 3, isRoot: false),
              '/lists': (_) => const TaskListsScreen(),
              '/dataTransfer': (_) => const DataTransferScreen(),
              '/region': (_) => const RegionalSettingsScreen(),
              '/deviceCalendars': (_) => const DeviceCalendarsScreen(),
              '/calendar': (_) => const MainShell(),
              '/notes': (_) => const MainShell(initialIndex: 2),
              '/settings': (_) => const MainShell(initialIndex: 3),
              '/completedTasks': (_) => const CompletedTasksScreen(),
              '/createTask': (_) => const CreateTaskScreen(),
              '/account': (_) => const AccountScreen(),
              '/subscription': (_) => const SubscriptionScreen(),
              '/captures': (_) => const CapturesScreen(),
              '/captureDiagnostics': (_) => const CaptureDiagnosticsScreen(),
              '/notifications': (_) => const NotificationSettingsScreen(),
            },
      onGenerateRoute: (settings) {
        if (!signedIn) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => auth.restoring
                ? const SessionLoadingScreen()
                : const LoginScreen(),
          );
        }
        if (settings.name == '/timeline') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => DayTimelineScreen(
              day: settings.arguments as DateTime? ?? DateTime.now(),
            ),
          );
        }
        if (settings.name == '/taskDetails') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => TaskDetailScreen(taskId: settings.arguments as int),
          );
        }
        if (settings.name == '/editTask') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => EditTaskScreen(taskId: settings.arguments as int),
          );
        }
        return null;
      },
    );
  }
}
