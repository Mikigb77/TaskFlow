import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/task_form_entry.dart';
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
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/account_screen.dart';
import 'package:agenda/screens/delete_account_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/screens/captures_screen.dart';
import 'package:agenda/screens/capture_diagnostics_screen.dart';
import 'package:agenda/screens/notification_settings_screen.dart';
import 'package:agenda/screens/task_lists_screen.dart';
import 'package:agenda/screens/data_transfer_screen.dart';
import 'package:agenda/services/app_language.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/screens/day_timeline_screen.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/screens/regional_settings_screen.dart';
import 'package:agenda/screens/other_settings_screen.dart';
import 'package:agenda/screens/voice_settings_screen.dart';
import 'package:agenda/screens/device_calendars_screen.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/pending_verification.dart';
import 'package:agenda/screens/invitation_review_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final appearance = ThemeController(ThemePreferenceStore());
  final regional = RegionalController(RegionalPreferenceStore());
  // The phone's languages as last reported, so the first frame already
  // reads the phone's week start; AppLanguageBridge.apply refreshes them.
  final phone = AppLanguageBridge.readSavedPhoneLocales();
  await Future.wait([appearance.ready, regional.ready, phone]);
  AppLanguageBridge.phoneLocales ??= await phone;
  runApp(
    ProviderScope(
      retry: noRetry,
      overrides: [
        themeModeProvider.overrideWith((ref) => appearance),
        regionalProvider.overrideWith((ref) => regional),
      ],
      child: const MyApp(),
    ),
  );
  // Reminder setup never holds back the first frame.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(
      TaskReminders.initialize().catchError(
        (Object _) => TaskReminders.recordError('setup_failed'),
      ),
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

  /// Sign-in shown over the open screens after the session expired.
  Route<void>? _signInAgain;
  StreamSubscription<void>? _actions;
  StreamSubscription<void>? _entries;
  bool _openingEntry = false;
  // Capture sheets opened by the widget or a shortcut, still open.
  int _entrySheets = 0;
  bool _openingInvitation = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // «Como el teléfono» reads the phone's languages once Android reports them.
    AppLanguageBridge.phone.addListener(_phoneLocalesChanged);
    // Idioma's choice for the widget, the shortcuts and the share messages too.
    unawaited(AppLanguageBridge.apply(ref.read(regionalProvider).language));
    ref.read(invitationLinkProvider);
    // Read with the session restore, so a waiting address opens at once.
    ref.read(pendingVerificationLoadProvider);
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
    AppLanguageBridge.phone.removeListener(_phoneLocalesChanged);
    WidgetsBinding.instance.removeObserver(this);
    _actions?.cancel();
    _entries?.cancel();
    super.dispose();
  }

  void _phoneLocalesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted) setState(() {});
    // Ask Android for the phone's new languages first, then rewrite the
    // reminders in them. Re-asking can't loop: the bridge sets the per-app
    // language only when it differs.
    unawaited(AppLanguageBridge.apply(ref.read(regionalProvider).language)
        .then((_) => TaskReminders.refreshLanguage()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh the device clock choice after returning from system settings.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      unawaited(TaskReminders.refreshLanguage());
      // A changed accessibility timeout applies to the next Undo.
      unawaited(TaskReminders.rememberUndoTimeout());
      unawaited(ref.read(subscriptionProvider.notifier).refresh());
      ref.invalidate(collaborationUnreadProvider);
    }
  }

  Future<void> _openEntries() async {
    if (!mounted ||
        _openingEntry ||
        ref.read(authProvider).loading ||
        ref.read(authProvider).expired ||
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
        // Only shared text brings words to keep. The widget and the shortcuts
        // open an empty sheet, which keeps nothing until something is said or
        // typed.
        final shared = entry.kind == 'share';
        final voice = entry.kind == 'voice';
        // A tap on the widget or a shortcut while what it would open already
        // waits on top, empty, opens nothing more: a second tap stacks no
        // second sheet or form (UX-2110). A form or used-up notice counts
        // only if an entry opened it, and a tap that asks to speak only one
        // that says why the mic is missing (UX-2642). Otherwise what is as it
        // opened closes first, so one sheet or form shows, in the mode asked
        // for: an empty sheet of the other mode, so the mic never lands on
        // the keyboard (UX-2637), unless it keeps a recording (UX-2641); an
        // entry's form with nothing typed, picked or chosen and Más detalles
        // closed (UX-2643). What that close uncovers may take the entry in
        // turn, and then nothing more opens (UX-2644). Anything else stays,
        // and the entry opens over it: a sheet with words or a recording, a
        // form with a day, project, person, words or anything chosen in it.
        // Shared words always open their own.
        if (!shared) {
          final navigator = _navigator.currentState!;
          final asked = voice ? CaptureMode.voice : CaptureMode.typing;
          bool takes() =>
              (_entrySheets > 0 ? emptyCaptureSheetOnTop(navigator) : null) ==
                  asked ||
              (captureOpensForm(
                    ProviderScope.containerOf(context, listen: false),
                    typing: !voice,
                  ) &&
                  emptyTaskFormOnTop(navigator, askedToSpeak: voice));
          if (takes()) {
            await entries.acknowledge(entry.id);
            continue;
          }
          final sheet = _entrySheets > 0
              ? emptyCaptureSheetOnTop(navigator)
              : null;
          final recorded =
              sheet != null && emptyCaptureSheetOnTopRecorded(navigator);
          if ((sheet != null && !recorded) ||
              untouchedEntryFormOnTop(navigator)) {
            navigator.pop();
            if (takes()) {
              await entries.acknowledge(entry.id);
              continue;
            }
          }
        }
        CaptureSession? session;
        if (shared) {
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
          session = await ref
              .read(captureStoreProvider)
              .acceptEntry(
                entry.id,
                owner,
                zone.identifier,
                text: entry.text,
                capturedAt: entry.capturedAt,
              );
        }
        await entries.acknowledge(entry.id);
        if (!mounted || owner != ref.read(captureOwnerProvider)) continue;
        if (shared) {
          ref.invalidate(pendingCapturesProvider);
          if (session == null || session.terminal) continue;
        }
        await CaptureInterruption.stop();
        if (!mounted || owner != ref.read(captureOwnerProvider)) continue;
        final navigator = _navigator;
        _entrySheets++;
        unawaited(
          showCaptureSheet(
            _navigator.currentContext!,
            captureId: session?.id,
            startListening: voice,
            askedToSpeak: voice,
            typing: !voice,
            // Saved tasks land on Calendar, in view, whichever tab shows.
            showCalendar: true,
          ).whenComplete(() {
            // A sign-out's fresh navigator started the count again.
            if (navigator == _navigator) _entrySheets--;
          }),
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
        ref.read(authProvider).expired ||
        ref.read(authProvider).account == null ||
        _navigator.currentState == null) {
      return;
    }
    final invitation = ref.read(invitationLinkProvider);
    if (invitation == null ||
        ref.read(invitationLinkProvider.notifier).isPostponed(invitation)) {
      return;
    }
    _openingInvitation = true;
    try {
      final handled = await _navigator.currentState!.push<bool>(
        MaterialPageRoute(
          builder: (_) => InvitationReviewScreen(invitation: invitation),
        ),
      );
      if (!mounted) return;
      final links = ref.read(invitationLinkProvider.notifier);
      if (handled == true) {
        links.clear(invitation);
      } else {
        // Kept: Calendar's card offers it again, with its code.
        links.postpone(invitation);
      }
    } finally {
      _openingInvitation = false;
    }
  }

  Future<void> _openReminder() async {
    if (!mounted ||
        ref.read(authProvider).loading ||
        ref.read(authProvider).expired ||
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
        if (task == null) {
          // The task is gone, or the alert is stale: stay where the user is.
          final context = _navigator.currentContext!;
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger != null) {
            unawaited(showFeedback(messenger, context.l10n.taskRemoved));
          }
          return;
        }
        _navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(
              taskId: task.id!,
              occurrenceDate: task.occurrenceDate,
              occurrenceKey: task.occurrenceId,
            ),
          ),
        );
      }
    });
  }

  /// Covers the open screens with sign-in, so nothing typed in them is lost.
  void _showSignInAgain() {
    final navigator = _navigator.currentState;
    if (!mounted ||
        _signInAgain != null ||
        navigator == null ||
        !ref.read(authProvider).expired) {
      return;
    }
    final route = MaterialPageRoute<void>(
      builder: (_) => const PopScope(
        canPop: false,
        child: LoginScreen(signInAgain: true),
      ),
    );
    _signInAgain = route;
    unawaited(navigator.push(route));
  }

  /// The same account signed back in: return to where the user was.
  void _closeSignInAgain() {
    final route = _signInAgain;
    _signInAgain = null;
    final navigator = _navigator.currentState;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
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
          // Then send again the files refused for a full file space.
          unawaited(
            ref
                .read(apiClientProvider)
                .request('POST', 'billing/access/', accountId: accountId)
                .then<void>((_) {}, onError: (Object _, StackTrace _) {})
                .then((_) async {
                  if (!mounted) return;
                  final repository = ref.read(taskRepositoryProvider);
                  if (repository.ownerKey == 'local') return;
                  await repository.attachments.retryRefused();
                  if (mounted) await ref.read(taskProvider.notifier).loadTasks();
                })
                .catchError((Object _) {}),
          );
        }
      }
    });
    ref.listen(authProvider, (previous, next) {
      if (next.expired) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showSignInAgain());
        return;
      }
      if (_signInAgain != null && !next.loading) _closeSignInAgain();
      // Signed in, nobody waits for a code.
      final account = next.loading ? null : next.account;
      if (account != null && previous?.account?.id != account.id) {
        unawaited(ref.read(pendingVerificationProvider).forget());
      }
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
    // Signed out, sign-in waits for the stored address, which may open
    // «Confirma tu correo» instead.
    final restoring =
        auth.restoring ||
        (!signedIn &&
            ref.watch(
              pendingVerificationLoadProvider.select(
                (load) => !load.hasValue && !load.hasError,
              ),
            ));
    final session = restoring
        ? 'restoring'
        : signedIn
        ? '${ref.read(apiClientProvider).baseUrl}/users/${auth.account!.id}'
        : 'signed-out';
    if (session != _navigationSession) {
      _navigationSession = session;
      // A fresh navigator prevents Back from restoring protected routes after logout.
      _navigator = GlobalKey<NavigatorState>();
      _signInAgain = null;
      _entrySheets = 0;
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
    // Under a per-app language Flutter's locales are the app's; «Como el
    // teléfono» means the phone's.
    final phone = AppLanguageBridge.phoneOr(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    return MaterialApp(
      // Clear forms and navigation when accounts change; never show another account's task.
      key: ValueKey(session),
      navigatorKey: _navigator,
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: regional.localeFor(phone),
      localeListResolutionCallback: (devices, supported) =>
          regional.localeFor(devices),
      localizationsDelegates: [
        RegionalMaterialDelegate(
          regional,
          phone.firstOrNull ?? const Locale('en'),
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
              '/': (_) => restoring
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
              '/otherSettings': (_) => const OtherSettingsScreen(),
              '/voiceSettings': (_) => const VoiceSettingsScreen(),
              '/deviceCalendars': (_) => const DeviceCalendarsScreen(),
              '/calendar': (_) => const MainShell(),
              '/notes': (_) => const MainShell(initialIndex: 2),
              '/settings': (_) => const MainShell(initialIndex: 3),
              '/completedTasks': (_) => const CompletedTasksScreen(),
              '/account': (_) => const AccountScreen(),
              '/deleteAccount': (_) => const DeleteAccountScreen(),
              '/subscription': (context) => SubscriptionScreen(
                reason: switch (ModalRoute.of(context)?.settings.arguments) {
                  final ProReason reason => reason,
                  _ => null,
                },
              ),
              '/captures': (_) => const CapturesScreen(),
              '/captureDiagnostics': (_) => const CaptureDiagnosticsScreen(),
              '/notifications': (_) => const NotificationSettingsScreen(),
            },
      onGenerateRoute: (settings) {
        if (!signedIn) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => restoring
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
        // The task form for a new task: how an account without Pro creates
        // tasks. Open it with openTaskForm.
        if (settings.name == '/newTask') {
          return NewTaskRoute(
            settings: settings,
            builder: (_) => NewTaskScreen(
              arguments:
                  settings.arguments as NewTaskArguments? ??
                  const NewTaskArguments(),
            ),
          );
        }
        return null;
      },
    );
  }
}
