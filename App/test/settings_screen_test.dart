import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/other_settings_screen.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/services/site_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'dart:io';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/notification_settings_screen.dart';
import 'package:agenda/screens/settings_screen.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/widgets/app_components.dart';
import 'support/reminder_fixtures.dart';

/// The launcher's answer to "pin the capture widget".
class _Launcher extends CaptureEntries {
  _Launcher({this.fails = false})
    : super(channel: const MethodChannel('taskflow/capture-entries-test'));
  final bool fails;
  @override
  Future<bool> pinWidget() async {
    if (fails) throw PlatformException(code: 'unavailable');
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    platform.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Europe/Madrid',
    );
    platform.setMockMethodCallHandler(
      const MethodChannel('taskflow/accessibility'),
      (_) async => null,
    );
  });
  tearDown(() {
    platform.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      null,
    );
    platform.setMockMethodCallHandler(
      const MethodChannel('taskflow/accessibility'),
      null,
    );
  });

  Future<void> openWidgetHelp(
    WidgetTester tester,
    String language, {
    required bool fails,
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
      overrides: [
        captureEntriesProvider.overrideWithValue(_Launcher(fails: fails)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/otherSettings');
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(Locale(language));
    final row = find.text(l.homeCapture);
    await tester.scrollUntilVisible(
      row,
      160,
      scrollable: find
          .descendant(
            of: find.byType(OtherSettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  for (final language in ['es', 'ca']) {
    for (final fails in [false, true]) {
      testWidgets(
        'UX-416: home-screen widget instructions stay in a sheet until closed '
        '(${fails ? 'picker fails' : 'pinning unsupported'}, $language, 2x text)',
        (tester) async {
          await openWidgetHelp(tester, language, fails: fails);
          final l = lookupAppLocalizations(Locale(language));
          final text = fails ? l.widgetPickerHelp : l.homeCaptureInstructions;
          final sheet = find.byType(BottomSheet);
          expect(sheet, findsOneWidget);
          expect(
            find.descendant(of: sheet, matching: find.text(text)),
            findsOneWidget,
          );
          expect(find.byType(SnackBar), findsNothing);
          // Long past any snackbar timeout, it is still there to read.
          await tester.pump(const Duration(minutes: 1));
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: sheet, matching: find.text(text)),
            findsOneWidget,
          );
          final done = find.descendant(
            of: sheet,
            matching: find.widgetWithText(FilledButton, l.done),
          );
          await tester.ensureVisible(done);
          await tester.pumpAndSettle();
          expect(done.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(done);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.text(text), findsNothing);
          expect(find.byType(OtherSettingsScreen), findsOneWidget);
        },
      );
    }
  }

  // ---- Run 2026-10-19-app round 3 · P223 (UX-1657) ----
  testWidgets(
    'UX-1657: in English at 2× on 320 dp, the widget help sheet names the widget by its home-screen label, Dictate a task',
    (tester) async {
      await openWidgetHelp(tester, 'en', fails: false);
      final l = lookupAppLocalizations(const Locale('en'));
      final xml = File(
        'android/app/src/main/res/values/strings.xml',
      ).readAsStringSync();
      final label = RegExp(
        r'<string name="capture_widget_label">([^<]*)</string>',
      ).firstMatch(xml)![1]!;
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final text = find.descendant(
        of: sheet,
        matching: find.text(l.homeCaptureInstructions),
      );
      expect(text, findsOneWidget);
      final shown = tester.widget<Text>(text).data!;
      expect(shown, contains('the $label widget'));
      expect(shown, contains('Dictate a task'));
      expect(shown.toLowerCase(), isNot(contains('say a task')));
      // The sheet scrolls, so the whole sentence and Done can be reached.
      expect(tester.getRect(text).top, lessThan(tester.getRect(sheet).bottom));
      final done = find.descendant(
        of: sheet,
        matching: find.widgetWithText(FilledButton, l.done),
      );
      await tester.ensureVisible(done);
      await tester.pumpAndSettle();
      expect(done.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P18 (UX-404, UX-120, UX-418, UX-406): six rows, Otros ajustes ----

  final es = lookupAppLocalizations(const Locale('es'));

  /// The app in Spanish on Calendar, with [reminders] stored for this
  /// account and [theme] as the stored appearance (null: never chosen).
  Future<ProviderContainer> openApp(
    WidgetTester tester, {
    ReminderPreferences reminders = const ReminderPreferences(),
    String? theme = 'light',
    Size size = const Size(390, 844),
    FakeReminderAccess? access,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      store: MemoryThemeStore(theme),
      regionalStore: MemoryRegionalStore(
        const RegionalPreferences(language: 'es'),
      ),
      overrides: reminderOverrides(
        MemoryReminderStore(reminders),
        access ?? FakeReminderAccess(allowed: reminders.enabled),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(es.settings),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inSettings(Finder finder) =>
      find.descendant(of: find.byType(SettingsScreen), matching: finder);

  for (final enabled in [false, true]) {
    testWidgets(
      'UX-404: Settings has exactly six rows in order, Recordatorios first reading ${enabled ? 'Activados · 10 minutos antes' : 'Desactivados'}, with no eyebrow, headline, section label or tagline',
      (tester) async {
        expect(es.reminders, 'Recordatorios');
        expect(es.remindersOff, 'Desactivados');
        expect(es.otherSettings, 'Otros ajustes');
        await openApp(
          tester,
          reminders: ReminderPreferences(enabled: enabled, leadMinutes: 10),
        );
        await openSettings(tester);
        final rows = tester
            .widgetList<ListTile>(inSettings(find.byType(ListTile)))
            .toList();
        expect(rows, hasLength(6));
        expect(rows.every((row) => row.onTap != null), isTrue);
        final titles = [
          es.reminders,
          es.language,
          es.appearance,
          es.account,
          es.taskflowPro,
          es.otherSettings,
        ];
        var above = double.negativeInfinity;
        for (final title in titles) {
          final row = inSettings(find.widgetWithText(ListTile, title));
          expect(row, findsOneWidget, reason: title);
          expect(tester.getRect(row).top, greaterThan(above), reason: title);
          above = tester.getRect(row).top;
          // A chevron says each opens something.
          expect(
            find.descendant(
              of: row,
              matching: find.byIcon(Icons.chevron_right_rounded),
            ),
            findsOneWidget,
            reason: title,
          );
        }
        final context = tester.element(find.byType(SettingsScreen));
        final state = enabled
            ? es.remindersOnLead(context.reminderLead(10))
            : es.remindersOff;
        if (enabled) expect(state, 'Activados · 10 minutos antes');
        expect(
          find.descendant(
            of: inSettings(find.widgetWithText(ListTile, es.reminders)),
            matching: find.text(state),
          ),
          findsOneWidget,
        );
        // Nothing but the rows: no eyebrow, headline, labels or tagline.
        final body = find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(ListView),
        );
        expect(
          find.descendant(of: body, matching: find.text(es.settings)),
          findsNothing,
        );
        expect(inSettings(find.byType(SectionLabel)), findsNothing);
        for (final gone in [
          'A tu gusto',
          'A TU GUSTO',
          'APARIENCIA',
          'TU ESPACIO',
          'Más claridad. Más espacio para vivir.',
        ]) {
          expect(find.text(gone), findsNothing, reason: gone);
        }
        expect(inSettings(find.text(es.completedTasks)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('UX-404: Tareas completadas is still on Tareas', (tester) async {
    await openApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(es.tasks),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextButton, es.completedButton).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(360, 740), 2.0),
  ]) {
    testWidgets(
      'UX-404: from Calendar, reminders are two taps away without scrolling (${size.width.toInt()} dp, ${scale}x text)',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openApp(tester, size: size);
        await openSettings(tester);
        final row = inSettings(find.widgetWithText(ListTile, es.reminders));
        expect(row.hitTestable(), findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(NotificationSettingsScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar).last,
            matching: find.text(es.reminders),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-418 / UX-406: Apariencia opens a sheet of Claro, Oscuro and Como el teléfono; a first run follows the phone; choosing Oscuro applies it',
    (tester) async {
      expect(es.light, 'Claro');
      expect(es.dark, 'Oscuro');
      expect(es.deviceDefault, 'Como el teléfono');
      final container = await openApp(tester, theme: null);
      expect(container.read(themeModeProvider), ThemeMode.system);
      await openSettings(tester);
      final row = inSettings(find.widgetWithText(ListTile, es.appearance));
      expect(
        find.descendant(of: row, matching: find.text(es.deviceDefault)),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final options = [es.light, es.dark, es.deviceDefault];
      for (final option in options) {
        final tile = find.descendant(
          of: sheet,
          matching: find.widgetWithText(RadioListTile<ThemeMode>, option),
        );
        expect(tile, findsOneWidget, reason: option);
        // Full width.
        expect(
          tester.getRect(tile).width,
          closeTo(tester.getRect(sheet).width, 1),
          reason: option,
        );
      }
      await tester.tap(
        find.descendant(of: sheet, matching: find.text(es.dark)),
      );
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.descendant(of: row, matching: find.text(es.dark)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-418: no app bar has a sun–moon button, and the code has no ThemeToggle or showAppearance',
    (tester) async {
      await openApp(tester);
      for (final tab in [es.calendar, es.tasks, es.settings]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('theme-toggle')), findsNothing);
        for (final icon in [
          Icons.dark_mode,
          Icons.dark_mode_outlined,
          Icons.dark_mode_rounded,
          Icons.light_mode,
          Icons.light_mode_outlined,
          Icons.light_mode_rounded,
        ]) {
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byIcon(icon),
            ),
            findsNothing,
            reason: tab,
          );
        }
      }
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') &&
                !file.path.replaceAll(r'\', '/').contains('/l10n/generated/'),
          );
      for (final file in sources) {
        final text = file.readAsStringSync();
        expect(text.contains('ThemeToggle'), isFalse, reason: file.path);
        expect(text.contains('showAppearance'), isFalse, reason: file.path);
      }
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P75 (UX-481, UX-482): blocked reminders say so; one sheet style ----

  Finder remindersRow() =>
      inSettings(find.widgetWithText(ListTile, es.reminders));

  for (final (enabled, allowed) in [
    (true, false),
    (true, true),
    (false, false),
  ]) {
    testWidgets(
      'UX-481: reminders ${enabled ? 'on' : 'off'} and the phone ${allowed ? 'allowing' : 'blocking'} alerts: the Recordatorios row reads ${enabled && !allowed
          ? 'Bloqueados por el teléfono with a red notifications-off icon'
          : enabled
          ? 'Activados · 10 minutos antes'
          : 'Desactivados'}',
      (tester) async {
        expect(es.remindersBlocked, 'Bloqueados por el teléfono');
        // The system dialog would say no: Ajustes must not ask anyway.
        final access = FakeReminderAccess(
          allowed: allowed,
          exact: true,
          grant: false,
        );
        await openApp(
          tester,
          reminders: ReminderPreferences(enabled: enabled, leadMinutes: 10),
          access: access,
        );
        await openSettings(tester);
        final row = remindersRow();
        final context = tester.element(find.byType(SettingsScreen));
        final colors = Theme.of(context).colorScheme;
        final on = es.remindersOnLead(context.reminderLead(10));
        expect(on, 'Activados · 10 minutos antes');
        final blocked = find.descendant(
          of: row,
          matching: find.text(es.remindersBlocked),
        );
        final icon = find.descendant(
          of: row,
          matching: find.byIcon(Icons.notifications_off_outlined),
        );
        if (enabled && !allowed) {
          expect(blocked, findsOneWidget);
          expect(icon, findsOneWidget);
          expect(tester.widget<Icon>(icon).color, colors.error);
          final size = tester.getSize(icon);
          expect(size.width, inInclusiveRange(16, 18));
          expect(
            DefaultTextStyle.of(
              tester.element(blocked),
            ).style.merge(tester.widget<Text>(blocked).style).color,
            colors.error,
          );
          expect(
            find.descendant(of: row, matching: find.text(on)),
            findsNothing,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.textContaining('Activados'),
            ),
            findsNothing,
          );
        } else {
          expect(blocked, findsNothing);
          expect(icon, findsNothing);
          expect(
            find.descendant(
              of: row,
              matching: find.text(enabled ? on : es.remindersOff),
            ),
            findsOneWidget,
          );
        }
        expect(access.permissionRequests, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-481: with Ajustes open and reminders on, the phone blocking alerts and the app resuming turns the row into Bloqueados por el teléfono without leaving',
    (tester) async {
      final access = FakeReminderAccess(allowed: true, grant: false);
      await openApp(
        tester,
        reminders: const ReminderPreferences(enabled: true, leadMinutes: 10),
        access: access,
      );
      await openSettings(tester);
      final row = remindersRow();
      final context = tester.element(find.byType(SettingsScreen));
      final on = es.remindersOnLead(context.reminderLead(10));
      expect(find.descendant(of: row, matching: find.text(on)), findsOneWidget);
      access.allowed = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text(es.remindersBlocked)),
        findsOneWidget,
      );
      expect(find.descendant(of: row, matching: find.text(on)), findsNothing);
      expect(access.permissionRequests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-482: Idioma and Apariencia open the same kind of sheet: RadioListTile rows with Como el teléfono first, no close button; following the phone, Idioma reads Como el teléfono · Español',
    (tester) async {
      expect(es.languageAutomatic, 'Como el teléfono');
      expect(es.languageFollowing('Español'), 'Como el teléfono · Español');
      tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(language: 'system'),
        ),
        overrides: reminderOverrides(
          MemoryReminderStore(),
          FakeReminderAccess(allowed: true),
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      await openSettings(tester);
      final languageRow = inSettings(
        find.widgetWithText(ListTile, es.language),
      );
      expect(
        find.descendant(
          of: languageRow,
          matching: find.text('Como el teléfono · Español'),
        ),
        findsOneWidget,
      );
      await tester.tap(languageRow);
      await tester.pumpAndSettle();
      var sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final rows = tester
          .widgetList<RadioListTile<String>>(
            find.descendant(
              of: sheet,
              matching: find.byType(RadioListTile<String>),
            ),
          )
          .toList();
      expect(rows, hasLength(4));
      Finder option(String code) => find.descendant(
        of: sheet,
        matching: find.byKey(ValueKey('language-$code')),
      );
      String? titleOf(String code) =>
          (tester.widget<RadioListTile<String>>(option(code)).title as Text)
              .data;
      for (final (code, label) in [
        ('system', es.languageAutomatic),
        ('es', 'Español'),
        ('ca', 'Català'),
        ('en', 'English'),
      ]) {
        expect(option(code), findsOneWidget, reason: code);
        expect(titleOf(code), label, reason: code);
      }
      // The phone's language under Como el teléfono.
      expect(
        (tester.widget<RadioListTile<String>>(option('system')).subtitle
                as Text)
            .data,
        'Español',
      );
      // Como el teléfono comes first.
      final first = option('system');
      for (final code in ['es', 'ca', 'en']) {
        expect(
          tester.getRect(first).top,
          lessThan(tester.getRect(option(code)).top),
          reason: code,
        );
      }
      // No close button: the handle and the scrim close it.
      expect(
        find.descendant(of: sheet, matching: find.byType(IconButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.byIcon(Icons.close)),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.byIcon(Icons.check)),
        findsNothing,
      );
      // Full width, like Apariencia's rows.
      expect(
        tester.getRect(first).width,
        closeTo(tester.getRect(sheet).width, 1),
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(
        inSettings(find.widgetWithText(ListTile, es.appearance)),
      );
      await tester.pumpAndSettle();
      sheet = find.byType(BottomSheet);
      expect(
        find.descendant(
          of: sheet,
          matching: find.byType(RadioListTile<ThemeMode>),
        ),
        findsNWidgets(3),
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.widgetWithText(
            RadioListTile<ThemeMode>,
            'Como el teléfono',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  /// Otros ajustes on its own, at version 1.0.5 (4007).
  Future<void> openOther(
    WidgetTester tester, {
    bool debug = false,
    bool staging = false,
    String language = 'es',
    Future<bool> Function(Uri)? openPage,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
      overrides: [
        appVersionProvider.overrideWith((ref) async => '1.0.5 (4007)'),
        if (openPage != null) openWebPageProvider.overrideWithValue(openPage),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OtherSettingsScreen(debug: debug, staging: staging),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-404 / UX-120: Otros ajustes lists Hora y región, Calendarios del teléfono, Botón de dictar en la pantalla de inicio, Exportar e importar, Licencias, Política de privacidad and Términos y condiciones (P158), then TaskFlow 1.0.5 (4007); outside debug builds no Diagnóstico de captura',
    (tester) async {
      expect(es.homeCapture, 'Botón de dictar en la pantalla de inicio');
      expect(es.appVersion('1.0.5 (4007)'), 'TaskFlow 1.0.5 (4007)');
      await openOther(tester);
      final titles = [
        es.regionalFormats,
        // P34: Voz, the speech options moved out of capture.
        es.voiceSettings,
        es.deviceCalendars,
        es.homeCapture,
        es.exportImport,
        es.licenses,
        es.privacyPolicy,
        es.termsAndConditions,
      ];
      expect(es.regionalFormats, 'Hora y región');
      var above = double.negativeInfinity;
      for (final title in titles) {
        final row = find.widgetWithText(ListTile, title);
        expect(row, findsOneWidget, reason: title);
        expect(tester.widget<ListTile>(row).onTap, isNotNull, reason: title);
        expect(tester.getRect(row).top, greaterThan(above), reason: title);
        above = tester.getRect(row).top;
      }
      expect(find.byType(ListTile), findsNWidgets(titles.length));
      final version = find.text(es.appVersion('1.0.5 (4007)'));
      expect(version, findsOneWidget);
      expect(tester.getRect(version).top, greaterThan(above));
      expect(find.text(es.captureDiagnostics), findsNothing);
      // In production a long-press on the version does nothing.
      await tester.longPress(version);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(es.connectionDetails), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-120: debug builds list Diagnóstico de captura last; on staging a long-press on the version opens Diagnóstico de captura and Detalles de conexión',
    (tester) async {
      await openOther(tester, debug: true);
      final diagnostics = find.widgetWithText(ListTile, es.captureDiagnostics);
      expect(diagnostics, findsOneWidget);
      expect(
        tester.getRect(diagnostics).top,
        greaterThan(
          tester.getRect(find.widgetWithText(ListTile, es.licenses)).top,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await openOther(tester, staging: true);
      expect(find.text(es.captureDiagnostics), findsNothing);
      await tester.longPress(find.text(es.appVersion('1.0.5 (4007)')));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text(es.captureDiagnostics)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(es.connectionDetails)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P158 (UX-1222): the Privacy Policy and the Terms ----

  for (final (language, prefix) in [('es', '/es'), ('ca', '/ca'), ('en', '')]) {
    testWidgets(
      'UX-1222: in $language, Otros ajustes’ Política de privacidad and Términos y condiciones come right after Licencias, with their icons, and open the site’s pages in the app’s language',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final opened = <Uri>[];
        await openOther(
          tester,
          language: language,
          openPage: (uri) async {
            opened.add(uri);
            return true;
          },
        );
        final licenses = find.widgetWithText(ListTile, l.licenses);
        final privacy = find.widgetWithText(ListTile, l.privacyPolicy);
        final terms = find.widgetWithText(ListTile, l.termsAndConditions);
        final tiles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .toList();
        final at = tiles.indexOf(tester.widget<ListTile>(licenses));
        expect(tiles[at + 1], same(tester.widget<ListTile>(privacy)));
        expect(tiles[at + 2], same(tester.widget<ListTile>(terms)));
        final colors = Theme.of(tester.element(privacy)).colorScheme;
        for (final (row, icon) in [
          (privacy, Icons.privacy_tip_outlined),
          (terms, Icons.gavel_outlined),
        ]) {
          final leading = find.descendant(of: row, matching: find.byIcon(icon));
          expect(leading, findsOneWidget);
          expect(tester.widget<Icon>(leading).color, colors.primary);
          expect(
            find.descendant(
              of: row,
              matching: find.byIcon(Icons.open_in_new_rounded),
            ),
            findsOneWidget,
          );
        }
        await tester.tap(privacy);
        await tester.pumpAndSettle();
        await tester.tap(terms);
        await tester.pumpAndSettle();
        expect(opened.map((uri) => uri.toString()), [
          'https://taskflow.garbar.tech$prefix/privacy/',
          'https://taskflow.garbar.tech$prefix/terms/',
        ]);
        expect(find.text(l.webPageOpenError), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1222: when nothing can open the page, Otros ajustes says «No se ha podido abrir la página.»',
    (tester) async {
      await openOther(
        tester,
        openPage: (uri) async => throw PlatformException(code: 'none'),
      );
      await tester.tap(find.widgetWithText(ListTile, es.termsAndConditions));
      await tester.pumpAndSettle();
      expect(find.text(es.webPageOpenError), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await openOther(tester, openPage: (uri) async => false);
      await tester.tap(find.widgetWithText(ListTile, es.privacyPolicy));
      await tester.pumpAndSettle();
      expect(find.text(es.webPageOpenError), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P76 (UX-483): tapping the current choice closes the sheet ----

  /// The app in Spanish on Ajustes, with [language] and [theme] stored.
  Future<(ProviderContainer, _CountingRegionalStore, _CountingThemeStore)>
  openAjustes(
    WidgetTester tester, {
    String language = 'es',
    String theme = 'light',
  }) async {
    tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final regional = _CountingRegionalStore(
      RegionalPreferences(language: language),
    );
    final themes = _CountingThemeStore(theme);
    final container = designContainer(
      store: themes,
      regionalStore: regional,
      overrides: reminderOverrides(
        MemoryReminderStore(),
        FakeReminderAccess(allowed: true),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);
    return (container, regional, themes);
  }

  Future<Finder> openSheet(WidgetTester tester, String title) async {
    await tester.tap(inSettings(find.widgetWithText(ListTile, title)));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    return sheet;
  }

  for (final (stored, label) in [
    ('es', 'Español'),
    ('system', 'Como el teléfono'),
  ]) {
    testWidgets(
      'UX-483: with the language set to ${stored == 'es' ? 'Español' : 'follow the phone'}, tapping $label in Idioma closes the sheet, keeps the language and saves nothing',
      (tester) async {
        final (container, regional, _) = await openAjustes(
          tester,
          language: stored,
        );
        final sheet = await openSheet(tester, es.language);
        final row = find.descendant(
          of: sheet,
          matching: find.byKey(ValueKey('language-$stored')),
        );
        expect(row, findsOneWidget);
        expect(
          find.descendant(
            of: row,
            matching: find.text(
              stored == 'system' ? es.languageAutomatic : 'Español',
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byKey(ValueKey('language-$stored')), findsNothing);
        expect(container.read(regionalProvider).language, stored);
        expect(regional.value.language, stored);
        expect(regional.writes, 0);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-483: with the theme set to Claro, tapping Claro in Apariencia closes the sheet and keeps ThemeMode.light',
    (tester) async {
      final (container, _, themes) = await openAjustes(tester);
      expect(container.read(themeModeProvider), ThemeMode.light);
      final sheet = await openSheet(tester, es.appearance);
      final row = find.descendant(
        of: sheet,
        matching: find.byKey(const ValueKey('appearance-light')),
      );
      expect(
        find.descendant(of: row, matching: find.text(es.light)),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('appearance-light')), findsNothing);
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(themes.value, 'light');
      expect(themes.writes, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-483: choosing another option still works: Català in Idioma switches to ca, Oscuro in Apariencia switches to dark, and each sheet closes',
    (tester) async {
      final (container, regional, themes) = await openAjustes(tester);
      var sheet = await openSheet(tester, es.language);
      await tester.tap(
        find.descendant(
          of: sheet,
          matching: find.byKey(const ValueKey('language-ca')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(container.read(regionalProvider).language, 'ca');
      expect(regional.value.language, 'ca');
      expect(regional.writes, 1);
      // The app now speaks Catalan.
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        inSettings(find.widgetWithText(ListTile, ca.appearance)),
        findsOneWidget,
      );

      sheet = await openSheet(tester, ca.appearance);
      await tester.tap(
        find.descendant(
          of: sheet,
          matching: find.byKey(const ValueKey('appearance-dark')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(themes.value, 'dark');
      expect(themes.writes, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-483: the open sheets still show the current choice as selected: Español in Idioma, Claro in Apariencia (radio checked, semantics checked)',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openAjustes(tester);
      var sheet = await openSheet(tester, es.language);
      for (final code in ['system', 'es', 'ca', 'en']) {
        final row = find.descendant(
          of: sheet,
          matching: find.byKey(ValueKey('language-$code')),
        );
        final tile = tester.widget<RadioListTile<String>>(row);
        expect(tile.toggleable, isTrue, reason: code);
        expect(
          tester.getSemantics(row),
          isSemantics(
            isChecked: code == 'es',
            isInMutuallyExclusiveGroup: true,
          ),
          reason: code,
        );
      }
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      sheet = await openSheet(tester, es.appearance);
      for (final mode in ThemeMode.values) {
        final row = find.descendant(
          of: sheet,
          matching: find.byKey(ValueKey('appearance-${mode.name}')),
        );
        final tile = tester.widget<RadioListTile<ThemeMode>>(row);
        expect(tile.toggleable, isTrue, reason: mode.name);
        expect(
          tester.getSemantics(row),
          isSemantics(
            isChecked: mode == ThemeMode.light,
            isInMutuallyExclusiveGroup: true,
          ),
          reason: mode.name,
        );
      }
      // Neither sheet has a close button.
      expect(
        find.descendant(of: sheet, matching: find.byType(IconButton)),
        findsNothing,
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-19-app · P187 (UX-1606 e): on, but reminders may be late ----

  for (final (exact, label) in [
    (false, 'Activados · pueden llegar tarde'),
    (true, 'Activados · 10 minutos antes'),
  ]) {
    testWidgets(
      'UX-1606: reminders on and exact alarms ${exact ? 'allowed' : 'off'}: the Recordatorios row reads $label',
      (tester) async {
        final access = FakeReminderAccess(
          allowed: true,
          exact: exact,
          grant: false,
        );
        await openApp(
          tester,
          reminders: const ReminderPreferences(enabled: true, leadMinutes: 10),
          access: access,
        );
        await openSettings(tester);
        final row = remindersRow();
        final context = tester.element(find.byType(SettingsScreen));
        final expected = exact
            ? es.remindersOnLead(context.reminderLead(10))
            : es.remindersOnLate;
        expect(expected, label);
        expect(
          find.descendant(of: row, matching: find.text(expected)),
          findsOneWidget,
        );
        if (!exact) {
          expect(
            find.descendant(
              of: row,
              matching: find.text(
                es.remindersOnLead(context.reminderLead(10)),
              ),
            ),
            findsNothing,
          );
        }
        expect(
          find.descendant(of: row, matching: find.text(es.remindersBlocked)),
          findsNothing,
        );
        expect(access.permissionRequests, 0);
        expect(access.exactRequests, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- UX loop 2026-10-28-app, round 1 · P290 (UX-2605): the Pro row
  // shows your plan ----
  group('P290 · Ajustes shows your plan', () {
    /// Ajustes in [language] at [scale] on 360×800, for an account with Pro
    /// when [pro], else with [freeLeft] free dictations left (null: the
    /// count isn't known yet).
    Future<void> openPlan(
      WidgetTester tester, {
      required bool pro,
      int? freeLeft,
      String language = 'es',
      double scale = 1,
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = designContainer(
        pro: pro,
        regionalStore: MemoryRegionalStore(
          RegionalPreferences(language: language),
        ),
        overrides: [
          ...reminderOverrides(
            MemoryReminderStore(const ReminderPreferences()),
            FakeReminderAccess(allowed: false),
          ),
          if (!pro) freeVoiceLeftProvider.overrideWithValue(freeLeft),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(language));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(l.settings),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder proRow(AppLocalizations l) => find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.widgetWithText(ListTile, l.taskflowPro),
    );

    test('UX-2605: the plan lines read as planned in ES, EN and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(es.freeVoiceLeft(4), 'Te quedan 4 dictados gratis este mes');
      expect(es.freeVoiceLeft(0), 'Ya no te quedan dictados gratis este mes');
      expect(es.billingStatus('active'), 'Pro está activo');
      expect(en.billingStatus('active'), 'Pro is active');
      expect(ca.billingStatus('active'), 'Pro està actiu');
    });

    for (final (language, scale) in [('es', 1.0), ('es', 2.0), ('ca', 2.0)]) {
      final l = lookupAppLocalizations(Locale(language));
      for (final (what, pro, left, line) in [
        ('a free account with 4 left', false, 4, l.freeVoiceLeft(4)),
        ('a free account with 0 left', false, 0, l.freeVoiceLeft(0)),
        ('Pro', true, null, l.billingStatus('active')),
        ('a free account whose count isn’t known yet', false, null, null),
      ]) {
        testWidgets(
          'UX-2605: Ajustes, $language at ${scale.toInt()}× on 360×800, for $what: the TaskFlow Pro row reads ${line == null ? 'no subtitle' : '«$line»'}, whole; «Suscripción, compras y facturación» shows nowhere',
          (tester) async {
            await openPlan(
              tester,
              pro: pro,
              freeLeft: left,
              language: language,
              scale: scale,
            );
            final row = proRow(l);
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            expect(row, findsOneWidget);
            final tile = tester.widget<ListTile>(row);
            if (line == null) {
              expect(tile.subtitle, isNull, reason: 'nothing until it’s known');
            } else {
              final subtitle = find.descendant(
                of: row,
                matching: find.text(line),
              );
              expect(subtitle, findsOneWidget);
              final rect = tester.getRect(subtitle);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(360.5));
            }
            for (final gone in [
              'Suscripción, compras y facturación',
              'Subscription, purchases and billing',
              'Subscripció, compres i facturació',
            ]) {
              expect(find.text(gone, skipOffstage: false), findsNothing);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  // ---- UX loop 2026-10-28-app, round 1 · P295 (UX-2613): the Spanish
  // widget help names the widget ----
  group('P295 · the Spanish widget help names the widget', () {
    testWidgets(
      'UX-2613: Ajustes › Otros ajustes’ help in Spanish reads the new sentence, naming the widget exactly as capture_widget_label does in values-es/strings.xml',
      (tester) async {
        await openWidgetHelp(tester, 'es', fails: false);
        final label = RegExp(
          r'<string name="capture_widget_label"[^>]*>([^<]*)</string>',
        ).firstMatch(
          File(
            'android/app/src/main/res/values-es/strings.xml',
          ).readAsStringSync(),
        )![1]!;
        expect(label, 'Dictar una tarea');
        const sentence =
            'En Android, mantén pulsado el icono de TaskFlow para ver los '
            'accesos directos, o añade el widget Dictar una tarea desde la '
            'pantalla de inicio. Comparte texto con TaskFlow desde otra '
            'aplicación.';
        expect(es.homeCaptureInstructions, sentence);
        expect(sentence, contains('el widget $label desde'));
        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(of: sheet, matching: find.text(sentence)),
          findsOneWidget,
        );
        expect(find.textContaining('widget de micrófono'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

}

class _CountingRegionalStore extends MemoryRegionalStore {
  _CountingRegionalStore(super.value);
  int writes = 0;
  @override
  Future<void> write(RegionalPreferences value) async {
    writes++;
    await super.write(value);
  }
}

class _CountingThemeStore extends MemoryThemeStore {
  _CountingThemeStore(super.value);
  int writes = 0;
  @override
  Future<void> write(String mode) async {
    writes++;
    await super.write(mode);
  }
}
