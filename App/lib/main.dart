import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Manrope'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(
        tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
  } catch (_) {/* UTC fallback. */}
  if (Platform.isAndroid || Platform.isIOS) {
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('app_icon'),
      iOS: DarwinInitializationSettings(),
    ));
    final android = notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }
  final appearance = ThemeController(ThemePreferenceStore());
  await appearance.ready;
  runApp(ProviderScope(
    overrides: [themeModeProvider.overrideWith((ref) => appearance)],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountId =
        ref.watch(authProvider.select((value) => value.account?.id));
    return MaterialApp(
      // Clear forms and navigation when accounts change; never show another account's task.
      key: ValueKey('account-$accountId'),
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 220),
      initialRoute: '/',
      routes: {
        '/': (_) => const MainShell(),
        '/home': (_) => const MainShell(initialIndex: 1),
        '/inbox': (_) => const HomeScreen(initialFilter: 3, isRoot: false),
        '/calendar': (_) => const MainShell(),
        '/settings': (_) => const MainShell(initialIndex: 2),
        '/completedTasks': (_) => const CompletedTasksScreen(),
        '/createTask': (_) => const CreateTaskScreen(),
        '/account': (_) => const AccountScreen(),
        '/voiceTask': (_) => const VoiceTaskScreen(),
        '/captures': (_) => const CapturesScreen(),
        '/captureDiagnostics': (_) => const CaptureDiagnosticsScreen(),
      },
      onGenerateRoute: (settings) {
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
