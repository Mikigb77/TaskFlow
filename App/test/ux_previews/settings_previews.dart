// Ajustes, the fourth tab, and what it opens: Cuenta, TaskFlow Pro and its
// billing states, reminders, region, voice, other settings, data transfer,
// pending captures and capture diagnostics.
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/screens/account_screen.dart';
import 'package:agenda/screens/other_settings_screen.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../support/billing_fixtures.dart';
import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const settingsTab = Screen(
  'settings',
  'settings-tab',
  'Ajustes, the fourth tab',
  sources: [
    'lib/screens/settings_screen.dart',
    'lib/widgets/language_selector.dart',
    'lib/widgets/app_components.dart',
    'lib/theme/app_theme.dart',
  ],
);

const accountScreen = Screen(
  'settings',
  'account',
  'Cuenta (`/account`), as in a release build',
  sources: [
    'lib/screens/account_screen.dart',
    'lib/widgets/google_login_button.dart',
    'lib/widgets/name_ask_sheet.dart',
  ],
);

const pro = Screen(
  'settings',
  'pro',
  'TaskFlow Pro (`/subscription`): the plan, free dictations and file space',
  sources: [
    'lib/screens/subscription_screen.dart',
    'lib/providers/subscription_provider.dart',
    'lib/services/revenuecat_service.dart',
  ],
);

const remindersScreen = Screen(
  'settings',
  'reminders',
  'Reminders (`/notifications`)',
  sources: [
    'lib/screens/notification_settings_screen.dart',
    'lib/widgets/reminder_control.dart',
    'lib/services/reminder_copy.dart',
  ],
);

const regionScreen = Screen(
  'settings',
  'region',
  'Language and region (`/region`)',
  sources: ['lib/screens/regional_settings_screen.dart', 'lib/l10n/region.dart'],
);

const voiceScreen = Screen(
  'settings',
  'voice',
  'Voz (`/voiceSettings`): how capture listens',
  sources: ['lib/screens/voice_settings_screen.dart', 'lib/services/native_speech.dart'],
);

const otherScreen = Screen(
  'settings',
  'other',
  'Otros ajustes (`/otherSettings`), as in a release build',
  sources: ['lib/screens/other_settings_screen.dart'],
);

const transferScreen = Screen(
  'settings',
  'data-transfer',
  'Copy and import (`/dataTransfer`)',
  sources: ['lib/screens/data_transfer_screen.dart'],
);

const capturesScreen = Screen(
  'settings',
  'pending-captures',
  'Words kept for later (`/captures`)',
  sources: ['lib/screens/captures_screen.dart', 'lib/l10n/capture_messages.dart'],
);

const diagnosticsScreen = Screen(
  'settings',
  'capture-diagnostics',
  'Capture diagnostics (`/captureDiagnostics`), a debug and staging screen',
  sources: ['lib/screens/capture_diagnostics_screen.dart', 'lib/services/capture_diagnostics.dart'],
);

const _owner = 'http://10.0.2.2:8088/users/$me';

List<CaptureSession> _kept({bool recordingOnly = false}) => [
  CaptureSession(
    id: 'kept-recording',
    ownerKey: _owner,
    timezone: 'Europe/Madrid',
    capturedAt: previewNow.subtract(const Duration(hours: 1)).toUtc(),
    status: 'failed',
    source: 'speech',
    audioPath: 'preview/kept-recording.wav',
    error: recordingOnly ? CaptureProblem.freeVoiceUsedUp : CaptureProblem.offline,
  ),
  if (!recordingOnly) ...[
    CaptureSession(
      id: 'kept-typed',
      ownerKey: _owner,
      timezone: 'Europe/Madrid',
      capturedAt: previewNow.subtract(const Duration(hours: 3)).toUtc(),
      status: 'editing',
      source: 'typed',
      text: 'Comprar el regalo para el cumpleaños de Lucía',
    ),
    CaptureSession(
      id: 'kept-result',
      ownerKey: _owner,
      timezone: 'Europe/Madrid',
      capturedAt: previewNow.subtract(const Duration(days: 1)).toUtc(),
      status: 'ready',
      source: 'speech',
      transcript: 'Pedir cita para la ITV y llevar el coche al taller el jueves',
      drafts: [
        draft('Pedir cita para la ITV'),
        draft('Llevar el coche al taller', date: next(DateTime.thursday)),
      ],
    ),
  ],
];

void settingsPreviews() {
  previewArea('settings', 'Ajustes', () {
    preview(
      settingsTab,
      'normal',
      'Ajustes with reminders on.',
      [...mainScreen, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.tab(p.l.settings);
        await p.shoot();
      },
    );

    preview(
      settingsTab,
      'notifications-blocked',
      'Reminders on, but the phone blocks notifications.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          notificationsAllowed: false,
        );
        await app.tab(p.l.settings);
        await p.shoot();
      },
    );

    preview(
      settingsTab,
      'exact-alarms-off',
      'Reminders on, but «Alarmas y recordatorios» is off: they may arrive late.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          exactAlarms: false,
        );
        await app.tab(p.l.settings);
        await p.shoot();
      },
    );

    // ------------------------------------------------------------ account
    preview(
      accountScreen,
      'email',
      'An account that signs in with email and password, without a name: the row Añadir tu nombre.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.pushPage(const AccountScreen(debug: false));
        await p.shoot();
      },
    );

    preview(
      accountScreen,
      'named',
      'An account with a first name: the name as the heading, the email under it, then the row Nombre · María.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          user: account(firstName: 'María'),
        );
        await app.pushPage(const AccountScreen(debug: false));
        await p.shoot();
      },
    );

    preview(
      accountScreen,
      'name-sheet',
      'The name row tapped: the name sheet, filled in with the current name.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          user: account(firstName: 'María'),
        );
        await app.pushPage(const AccountScreen(debug: false));
        await app.tap(p.l.nameAskField);
        await p.shoot();
      },
    );

    preview(
      accountScreen,
      'google-linked',
      'An account linked to Google.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          user: account(google: true),
        );
        await app.pushPage(const AccountScreen(debug: false));
        await p.shoot();
      },
    );

    // ---------------------------------------------------------------- Pro
    preview(
      pro,
      'free',
      'An account without Pro: the price, 4 of 10 free dictations left, 42 of 100 MB used.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          pro: false,
          user: account(freeLeft: 4, storageMb: 42),
          billing: FakeRevenueCat()..info = billingInfo(),
        );
        await app.push('/subscription');
        await p.shoot();
      },
    );

    preview(
      pro,
      'free-used-up',
      'No free dictations left this month, and the file space nearly full.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          pro: false,
          user: account(freeLeft: 0, storageMb: 96),
          billing: FakeRevenueCat()..info = billingInfo(),
        );
        await app.push('/subscription');
        await p.shoot();
      },
    );

    preview(
      pro,
      'file-space-full',
      'The file space full, 100 of 100 MB: «Ver tareas con archivos» under the usage line.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          pro: false,
          user: account(freeLeft: 4, storageMb: 100),
          billing: FakeRevenueCat()..info = billingInfo(),
        );
        await app.push('/subscription');
        // At large text the button sits below the fold: show it with the
        // usage line above it.
        await p.tester.ensureVisible(find.text(p.l.storageSeeTasks));
        await p.tester.pumpAndSettle();
        await p.tester.drag(app.mainScroll(), const Offset(0, 200));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      pro,
      'active',
      'Pro is active and renews.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          billing: FakeRevenueCat()..info = billingInfo(active: true),
        );
        await app.push('/subscription');
        await p.shoot();
      },
    );

    preview(
      pro,
      'complimentary',
      'Pro given by TaskFlow, with nothing to pay or manage.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          user: account(complimentary: true),
          complimentary: true,
          billing: FakeRevenueCat(),
        );
        await app.push('/subscription');
        await p.shoot();
      },
    );

    preview(
      pro,
      'store-error',
      'The store can\'t be reached: no price, and the reason.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          pro: false,
          user: account(freeLeft: 4, storageMb: 42),
          billing: FakeRevenueCat()
            ..offeringsError = PlatformException(
              code: '${PurchasesErrorCode.storeProblemError.index}',
            ),
        );
        await app.push('/subscription');
        await p.shoot();
      },
    );

    // ---------------------------------------------------------- reminders
    preview(
      remindersScreen,
      'on',
      'Reminders on and allowed: the defaults.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/notifications');
        await p.shoot();
      },
    );

    preview(
      remindersScreen,
      'all-day-off-plans',
      '«Tareas sin hora» off, with one open task on Normal: the row says «Hasta la fecha límite» still rings at 9:00.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 90,
              title: 'Presentar el proyecto de empresa',
              dueDate: day(21),
              hasTime: false,
              priority: 2,
              reminderPlan: const ReminderPlan.rhythm(ReminderPlan.normal),
            ),
          ],
        );
        await app.push('/notifications');
        await p.shoot();
      },
    );

    preview(
      remindersScreen,
      'blocked',
      'Reminders on, but the phone blocks notifications: one plain line, and Permitir avisos to TaskFlow\'s notifications page.',
      [...everywhere, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          notificationsAllowed: false,
        );
        await app.push('/notifications');
        await p.shoot();
      },
    );

    preview(
      remindersScreen,
      'off-blocked',
      'Reminders off and the phone blocks notifications: the switch alone, the one way in (it asks the phone, or offers its page).',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          notificationsAllowed: false,
          reminders: const ReminderPreferences(asked: true),
        );
        await app.push('/notifications');
        await p.shoot();
      },
    );

    preview(
      remindersScreen,
      'exact-alarms-off',
      'Notifications allowed, exact alarms not: reminders may come late; one button allows «Alarmas y recordatorios».',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          exactAlarms: false,
        );
        await app.push('/notifications');
        await p.shoot();
      },
    );

    // ------------------------------------------------------ region, voice
    preview(
      regionScreen,
      'normal',
      'Language, 24-hour clock, week from Monday, Madrid time.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/region');
        await p.shoot();
      },
    );

    preview(
      regionScreen,
      'clock-sheet',
      'The time-format row tapped: a sheet of radio rows, like Idioma.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/region');
        await app.tap(p.l.clockFormat);
        await p.shoot();
      },
    );

    preview(
      regionScreen,
      'zone-unknown',
      'The phone doesn\'t give its time zone: new tasks use the account\'s, and the screen says so.',
      [es1],
      (p) async {
        p.tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => 'Not/AZone',
        );
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/region');
        await p.shoot();
      },
    );

    preview(
      voiceScreen,
      'on-phone',
      'Spanish speech is on the phone: words appear as they\'re said.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/voiceSettings');
        await p.shoot();
      },
    );

    preview(
      voiceScreen,
      'not-on-phone',
      'The language isn\'t on the phone: words go online, with the way to set it up.',
      [ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          speechInstalled: false,
        );
        await app.push('/voiceSettings');
        await p.shoot();
      },
    );

    // ------------------------------------------------------- other, data
    preview(
      otherScreen,
      'release',
      'Otros ajustes: phone calendars, the home-screen mic, copies, the app version.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.pushPage(const OtherSettingsScreen(debug: false, staging: false));
        await p.shoot();
      },
    );

    preview(
      transferScreen,
      'start',
      'Save a copy of tasks and notes, or import one.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/dataTransfer');
        await p.shoot();
      },
    );

    // --------------------------------------------------- pending captures
    preview(
      capturesScreen,
      'three',
      'A recording kept offline, typed words, and a result not added yet.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay(), captures: _kept());
        await app.push('/captures');
        await p.shoot();
      },
    );

    preview(
      capturesScreen,
      'free-used-up',
      'A free account with no dictations left: its recording waits for next month.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          pro: false,
          freeLeft: 0,
          captures: _kept(recordingOnly: true),
        );
        await app.push('/captures');
        await p.shoot();
      },
    );

    preview(
      diagnosticsScreen,
      'timings',
      'The capture timings recorded on this phone (debug and staging builds only).',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          diagnostics: [
            for (final (event, ms, count) in [
              ('opened', null, null),
              ('ready', 180, null),
              ('firstPartial', 640, null),
              ('firstPartial', 910, null),
              ('processing', 2840, 2),
              ('processing', 3420, 1),
              ('transcription', 1210, null),
              ('extraction', 1630, null),
            ])
              {'event': event, 'elapsed_ms': ms, 'count': count},
          ],
        );
        await app.push('/captureDiagnostics');
        await p.shoot();
      },
    );
  });
}
