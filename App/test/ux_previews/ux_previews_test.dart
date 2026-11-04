// TaskFlow's rendered screen previews, for the UX reviewer: every route and
// tab in its key states, as PNGs in build/ux/<area>/, with build/ux/INDEX.md
// (what each PNG shows) and build/ux/AUDIT.md (measured accessibility,
// clipping and target evidence for each one).
//
// Skipped unless asked for, so the normal suite stays as fast:
//
//   flutter test --no-pub --dart-define=WRITE_UX_PREVIEWS=true test/ux_previews/ux_previews_test.dart
//
// One area or screen: add --plain-name "capture/" or --plain-name "capture/sheet.".
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_previews.dart';
import 'calendar_previews.dart';
import 'capture_previews.dart';
import 'commands_previews.dart';
import 'delete_previews.dart';
import 'first_run_previews.dart';
import 'form_previews.dart';
import 'meeting_previews.dart';
import 'notes_previews.dart';
import 'reminders_previews.dart';
import 'settings_previews.dart';
import 'sharing_previews.dart';
import 'support/audit_check.dart';
import 'support/preview.dart';
import 'tasks_previews.dart';
import 'support/report.dart';

const _command =
    'flutter test --no-pub --dart-define=WRITE_UX_PREVIEWS=true test/ux_previews/ux_previews_test.dart';

/// Where each route of lib/main.dart, each tab and each screen pushed
/// without a route is previewed.
const _routes = <String, String>{
  '/': 'signed in: `calendar/agenda.*` (the Calendario tab); signed out: `auth/sign-in.*`; while the session is read: `auth/opening.*`',
  '/calendar': '`calendar/agenda.*`',
  '/home': '`tasks/tasks-tab.*` (the Tareas tab)',
  '/inbox': '`tasks/tasks-tab.inbox.*`',
  '/notes': '`notes/notes-tab.*` (the Notas tab)',
  '/settings': '`settings/settings-tab.*` (the Ajustes tab)',
  '/lists': '`tasks/projects.*`',
  '/timeline': '`calendar/timeline.*`',
  '/completedTasks': '`calendar/completed.*`',
  '/taskDetails': '`tasks/detail.*`, `notes/note.*`',
  '/editTask': '`form/edit-task.*`',
  '/newTask': '`form/new-task.*`',
  '/account': '`settings/account.*`',
  '/deleteAccount': '`delete/delete-account.*`, then `delete/after-deletion.*`',
  '/subscription': '`settings/pro.*`',
  '/notifications': '`settings/reminders.*`',
  '/region': '`settings/region.*`',
  '/voiceSettings': '`settings/voice.*`',
  '/otherSettings': '`settings/other.*`',
  '/deviceCalendars': '`first-run/phone-calendars.*`',
  '/dataTransfer': '`settings/data-transfer.*`',
  '/captures': '`settings/pending-captures.*`',
  '/captureDiagnostics': '`settings/capture-diagnostics.*`',
  'The capture sheet (Añadir tarea, Añadir nota, resumed captures)':
      '`capture/sheet.*`, `capture/result.*`, `commands/*`, `notes/note-capture.*`',
  'A project\'s page (pushed, no route)': '`tasks/project.*`',
  'Sharing, invitations, groups, activity (pushed, no route)':
      '`sharing/*`',
  'Email confirmation (pushed after sign-up)': '`auth/verify-email.*`',
  'Meeting notes: the recording screen and what follows Stop (pushed, no route)':
      '`meetings/recording.*`, `meetings/after-stop.*`; Notas\'s meeting lines `meetings/notes-lines.*`, the meeting\'s note and its Crear tarea `meetings/note.*`, the Pro reason `meetings/pro.*`, the sign-out question `meetings/sign-out.*`',
  'Sign-in again over open screens': '`auth/sign-in.sign-in-again.*`',
  'Sheets and dialogs':
      'the used-up notice `capture/used-up-notice.*`, the reminder question `first-run/reminder-question.*`, the reminder sheet with its plans `reminders/sheet.*`, the plan offer `reminders/offer.*`, keep-or-discard `capture/sheet.keep-question.*`, the series deletion `commands/cards.delete-series.*`, the view menu `calendar/agenda.view-menu.*`, the invite dialog `sharing/project-sharing.invite.*`',
  'Reminder plans on a task and on the capture\'s card':
      '`reminders/task-line.*`, `reminders/capture-card.*`',
};

/// What the previews can't show, and why.
const _notCovered = <String, String>{
  'Launcher shortcuts:':
      'drawn by the Android launcher from the shortcuts `CaptureShortcuts.kt` publishes, with their labels in `strings.xml`; nothing Flutter renders. Check their labels there and on a phone.',
  'The home-screen widget:':
      'a native Android widget (`CaptureWidget.kt` and its layout), outside Flutter. Phone only.',
  'Notifications and reminders in the shade:':
      'Android draws them; their text comes from `lib/services/reminder_copy.dart` and `notification_service.dart` (the meeting\'s «Las notas de la reunión están listas» there too, under its note\'s title, and its ongoing «Grabando una reunión» from `meeting_copy.dart`, drawn by the recorder\'s foreground service), a reminder plan\'s too («Faltan 12 días · jue, 12 nov», «Es mañana a las 17:00», «Fecha límite: hoy», «Era para ayer», «Venció ayer»), from `planBody`. Read the copy there; check delivery, actions and grouping on a phone.',
  'System permission dialogs:':
      'the microphone, notification, exact-alarm and calendar prompts are Android\'s. The app\'s own explanations before and after them are covered (the reminder question sheet, the blocked-microphone message).',
  'The share sheet:':
      'sharing text into TaskFlow starts in Android\'s chooser. What the app shows after it (the capture sheet with the shared words) is the same sheet covered here.',
  'TalkBack\'s speech:':
      'AUDIT.md lists the semantics tree TalkBack reads, in order, with roles and actions; what TalkBack actually says, its focus moves and announcements need a phone.',
  'The real keyboard:':
      'a grey stand-in marks the space; the keyboard itself, its suggestions and the field it scrolls into view need a phone.',
  'Real speech:':
      'the recognizer, the microphone level, latency, calls interrupting listening and words arriving over time. The previews feed words in as the recognizer would.',
  'RevenueCat\'s paywall and customer centre:':
      'native views from purchases_ui_flutter. The app\'s own Pro screen and its states are covered; the purchase sheet is not.',
  'Google sign-in\'s account chooser:':
      'system UI from Google Play services; the app\'s button and its errors are covered.',
  'File and image pickers, opening attachments:':
      'system pickers and other apps.',
  'The launch screen:':
      'Android\'s splash before Flutter draws; the app\'s own loading screen is covered.',
  'Ways in from outside the app:':
      'the widget, the launcher shortcuts and share open the same capture sheet covered here. The one variant they alone reach — the sheet opened to speak on an account without the mic, with its «Dictar una tarea es parte de TaskFlow Pro» line — is not rendered.',
  'Purchase results:':
      'pending and awaiting-entitlement messages follow RevenueCat\'s native purchase sheet; the Pro screen before them is covered.',
  'Copy and import past the first screen:':
      'the export result, the import preview and its results need the system file picker and the archive store. Fakes for both exist in `test/data_transfer_screen_test.dart` and could be added.',
  'Attachments:':
      'task details are rendered with no files attached; files come from the phone\'s pickers and storage.',
  'Android-only reminder help:':
      'the test host is not Android (`Platform.isAndroid` is false), so the Reminders screen\'s «Detalles» shows its non-Android text. Rendering Android\'s would need the platform injected (a seam in `notification_settings_screen.dart`).',
  'Tablets and landscape:':
      'phones in portrait only, at 360 and 393 dp.',
  'Motion:':
      'each PNG is one settled frame; transitions, the listening level and spinners are frozen.',
  'One fixed date:':
      'the clock seam is fixed, but app code that reads `DateTime.now()` directly (for example `dayLabel` in `lib/l10n/region.dart`, the Tareas filters in `home_screen.dart`, deadlines in `task_tile.dart`, the timeline\'s now line) follows the real clock, so renders use the day of the run. A fully fixed date would need those to read `calendarClockProvider`.',
};

void main() {
  if (!writeUxPreviews) {
    test(
      'UX previews (run with --dart-define=WRITE_UX_PREVIEWS=true)',
      () {},
      skip: 'Renders only on request: --dart-define=WRITE_UX_PREVIEWS=true',
    );
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDownAll(
    () => writeReports(
      command: _command,
      notCovered: _notCovered,
      routes: _routes,
    ),
  );

  // First: the audit still finds what it should.
  auditSelfCheck();
  capturePreviews();
  commandPreviews();
  formPreviews();
  calendarPreviews();
  tasksPreviews();
  remindersPreviews();
  sharingPreviews();
  notesPreviews();
  meetingPreviews();
  authPreviews();
  settingsPreviews();
  deletePreviews();
  firstRunPreviews();
}
