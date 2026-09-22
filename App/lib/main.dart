import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/main_shell.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/screens/completed_tasks_screen.dart';
import 'package:agenda/screens/create_task_screen.dart';
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/account_screen.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Manrope'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  try {
    await TaskReminders.initialize();
  } catch (_) {
    await TaskReminders.recordError('setup_failed');
  }
  final appearance = ThemeController(ThemePreferenceStore());
  final regional = RegionalController(RegionalPreferenceStore());
  await Future.wait([appearance.ready, regional.ready]);
  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => appearance),
      regionalProvider.overrideWith((ref) => regional)
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _actions;
  StreamSubscription<void>? _entries;
  bool _openingEntry = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TaskReminders.openRequest.addListener(_openReminder);
    // Scheduling also emits changes; reload only in response to action callbacks.
    _actions = TaskReminders.actionChanges.stream.listen((_) {
      if (mounted) ref.read(taskProvider.notifier).loadTasks();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _openReminder());
    _entries =
        ref.read(captureEntriesProvider).changes.listen((_) => _openEntries());
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh the device clock choice after returning from system settings.
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<void> _openEntries() async {
    if (!mounted ||
        _openingEntry ||
        ref.read(authProvider).loading ||
        _navigator.currentState == null) {
      return;
    }
    _openingEntry = true;
    final entries = ref.read(captureEntriesProvider);
    try {
      while (mounted && !ref.read(authProvider).loading) {
        final pending = await entries.pending();
        if (pending.isEmpty || !mounted) break;
        final entry = pending.first;
        final owner = ref.read(captureOwnerProvider);
        await ref.read(regionalProvider.notifier).ready;
        final zone = await CaptureTimezone.resolve(ref.read(regionalProvider),
            accountTimezone: ref.read(authProvider).account?.timezone);
        final session = await ref.read(captureStoreProvider).acceptEntry(
            entry.id, owner, zone.identifier,
            text: entry.text, capturedAt: entry.capturedAt);
        await entries.acknowledge(entry.id);
        if (!mounted || owner != ref.read(captureOwnerProvider)) continue;
        ref.invalidate(pendingCapturesProvider);
        if (session == null || session.terminal) continue;
        await CaptureInterruption.stop();
        if (!mounted || owner != ref.read(captureOwnerProvider)) continue;
        unawaited(_navigator.currentState!.push(MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/voiceTask'),
            builder: (_) => VoiceTaskScreen(
                captureId: session.id,
                startRecording: entry.kind == 'voice'))));
      }
    } catch (_) {
      if (mounted && _navigator.currentContext != null) {
        ScaffoldMessenger.maybeOf(_navigator.currentContext!)?.showSnackBar(
            const SnackBar(
                content: Text(
                    'Your shared capture is retained. Reopen TaskFlow to try again.')));
      }
    } finally {
      _openingEntry = false;
    }
  }

  Future<void> _openReminder() async {
    if (!mounted || ref.read(authProvider).loading) return;
    final id = TaskReminders.openRequest.value;
    if (id == null) return;
    TaskReminders.openRequest.value = null;
    final task =
        await TaskReminders.engine.taskForAlert(id.id, token: id.token);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _navigator.currentState != null) {
        _navigator.currentState!.push(MaterialPageRoute<void>(
            builder: (_) => task == null
                ? const MainShell()
                : TaskDetailScreen(
                    taskId: task.id!,
                    occurrenceDate: task.occurrenceDate,
                    occurrenceKey: task.occurrenceId)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (!next.loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openReminder());
        WidgetsBinding.instance.addPostFrameCallback((_) => _openEntries());
      }
    });
    final accountId =
        ref.watch(authProvider.select((value) => value.account?.id));
    final regional = ref.watch(regionalProvider);
    final system24Hour = !kIsWeb &&
            [TargetPlatform.android, TargetPlatform.iOS]
                .contains(defaultTargetPlatform)
        ? WidgetsBinding.instance.platformDispatcher.alwaysUse24HourFormat
        : null;
    return MaterialApp(
      // Clear forms and navigation when accounts change; never show another account's task.
      key: ValueKey('account-$accountId'),
      navigatorKey: _navigator,
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: regional
          .localeFor(WidgetsBinding.instance.platformDispatcher.locales),
      localeListResolutionCallback: (devices, supported) =>
          regional.localeFor(devices),
      localizationsDelegates: [
        RegionalMaterialDelegate(
            regional,
            WidgetsBinding.instance.platformDispatcher.locales.firstOrNull ??
                const Locale('en'),
            system24Hour: system24Hour),
        ...AppLocalizations.localizationsDelegates
      ],
      builder: (context, child) =>
          regionalMedia(regional, context, child, system24Hour: system24Hour),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 220),
      initialRoute: '/',
      routes: {
        '/': (_) => const MainShell(),
        '/home': (_) => const MainShell(initialIndex: 1),
        '/inbox': (_) => const HomeScreen(initialFilter: 3, isRoot: false),
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
        '/voiceTask': (_) => const VoiceTaskScreen(),
        '/captures': (_) => const CapturesScreen(),
        '/captureDiagnostics': (_) => const CaptureDiagnosticsScreen(),
        '/notifications': (_) => const NotificationSettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/timeline') {
          return MaterialPageRoute(
              settings: settings,
              builder: (_) => DayTimelineScreen(
                  day: settings.arguments as DateTime? ?? DateTime.now()));
        }
        if (settings.name == '/taskDetails') {
          return MaterialPageRoute(
              settings: settings,
              builder: (_) =>
                  TaskDetailScreen(taskId: settings.arguments as int));
        }
        if (settings.name == '/editTask') {
          return MaterialPageRoute(
              settings: settings,
              builder: (_) =>
                  EditTaskScreen(taskId: settings.arguments as int));
        }
        return null;
      },
    );
  }
}
