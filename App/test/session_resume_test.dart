// Round 1 of 2026-10-13-app, P30 (UX-424, UX-419): the signed-in app never
// waits for reminder setup, and an expired session shows sign-in over the
// open screens, so what was being typed survives signing back in.
import 'dart:async';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/screens/main_shell.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezoneChannel = MethodChannel('flutter_timezone');
  setUp(() {
    // Signed out, the app waits for the stored address waiting for its code.
    FlutterSecureStorage.setMockInitialValues({});
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => null);
    platform.setMockMethodCallHandler(
      timezoneChannel,
      (_) async => 'Europe/Madrid',
    );
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezoneChannel, null);
  });

  final es = lookupAppLocalizations(const Locale('es'));

  /// The app with a stand-in server and a reminder setup that waits for
  /// [reminders], in Spanish.
  Future<(ProviderContainer, _SessionApi)> openApp(
    WidgetTester tester,
    _SlowReminders reminders, {
    bool signedIn = true,
    String language = 'es',
    Size size = const Size(390, 844),
    // Google sign-in on this phone, when a test sets one up.
    GoogleSignInService? google,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _SessionApi(signedIn: signedIn);
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(true),
        billingLoadingProvider.overrideWithValue(false),
        authProvider.overrideWith(
          (ref) => AuthNotifier(api, activateReminders: reminders.activate),
        ),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(RegionalPreferences(language: language)),
        ),
        pendingCapturesProvider.overrideWith((ref) async => []),
        taskListsProvider.overrideWith((ref) async => []),
        apiClientProvider.overrideWithValue(api),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        if (google != null) googleSignInServiceProvider.overrideWithValue(google),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    // No pumpAndSettle: a spinner waiting on reminders would never settle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return (container, api);
  }

  // ---- UX-424: start fast ----

  testWidgets(
    'UX-424: with a reminder setup that has not finished, the signed-in Calendar already shows, with no loading screen',
    (tester) async {
      final reminders = _SlowReminders();
      final (container, _) = await openApp(tester, reminders);
      expect(reminders.owners, hasLength(1), reason: 'reminders were started');
      expect(reminders.owners.single, endsWith('/users/1'));
      expect(reminders.pending, isTrue, reason: 'setup has not finished');
      expect(container.read(authProvider).loading, isFalse);
      expect(container.read(authProvider).account?.id, 1);
      expect(find.byType(SessionLoadingScreen), findsNothing);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      // Once setup finishes, nothing on screen changes.
      reminders.finish();
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX-419: keep what you typed when the session ends ----

  Future<void> editTask(WidgetTester tester, String typed) async {
    final task = DesignTaskNotifier.samples()[1];
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(builder: (_) => TaskEditor(task: task)),
          ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('task-title')), typed);
    await tester.pump();
  }

  String titleText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('task-title'), skipOffstage: false),
          matching: find.byType(EditableText, skipOffstage: false),
        ),
      )
      .controller
      .text;

  Future<void> signIn(WidgetTester tester) async {
    final email = find.byKey(const ValueKey('account-email'));
    final password = find.byKey(const ValueKey('account-password'));
    final submit = find.byKey(const ValueKey('account-submit'));
    await tester.ensureVisible(email);
    await tester.enterText(email, 'design@example.invalid');
    await tester.ensureVisible(password);
    await tester.enterText(password, 'Synthetic-only-password!');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-419: a session that ends while editing shows sign-in on top; signing back in as the same account returns to the editor with the text',
    (tester) async {
      final reminders = _SlowReminders();
      final (container, api) = await openApp(tester, reminders);
      const typed = 'Llamar al dentista para cambiar la cita';
      await editTask(tester, typed);
      expect(titleText(tester), typed);

      api.expire();
      await tester.pumpAndSettle();
      // Sign-in covers the editor; the editor and its text are kept under it.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(LoginScreen).hitTestable(), findsWidgets);
      expect(find.byType(TaskEditor, skipOffstage: false), findsOneWidget);
      expect(find.byType(TaskEditor).hitTestable(), findsNothing);
      expect(titleText(tester), typed);
      // System Back does not drop the user into a signed-out app.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen).hitTestable(), findsWidgets);

      api.nextAccount = 1;
      await signIn(tester);
      expect(api.signIns, 1);
      expect(container.read(authProvider).expired, isFalse);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(TaskEditor).hitTestable(), findsWidgets);
      expect(find.text(typed), findsOneWidget);
      expect(titleText(tester), typed);
      // Saving still works from here: the editor is the same one.
      expect(find.text(es.editTask), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-419: if a different account signs in after the session ends, the screens start fresh and the earlier text is gone',
    (tester) async {
      final reminders = _SlowReminders();
      final (container, api) = await openApp(tester, reminders);
      const typed = 'Texto de otra cuenta';
      await editTask(tester, typed);

      api.expire();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      api.nextAccount = 2;
      await signIn(tester);
      expect(container.read(authProvider).account?.id, 2);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(TaskEditor, skipOffstage: false), findsNothing);
      expect(find.text(typed, skipOffstage: false), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 (b8) · P111 (UX-623): sign-in again says why ----

  String emailText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('account-email')),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  /// Signed in as ana@example.com, editing a task with [typed] in its title,
  /// when the server ends the session.
  Future<void> expireWhileEditing(
    WidgetTester tester, {
    String typed = 'Llamar al dentista',
    String language = 'es',
    Size size = const Size(390, 844),
  }) async {
    final (_, api) = await openApp(
      tester,
      _SlowReminders(),
      language: language,
      size: size,
    );
    await editTask(tester, typed);
    api.expire();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  testWidgets(
    'UX-623: after the session ends, the Spanish sign-in route says Tu sesión se ha cerrado… and the email field holds ana@example.com',
    (tester) async {
      await expireWhileEditing(tester);
      expect(
        es.signInAgainReason,
        'Tu sesión se ha cerrado. Vuelve a entrar y seguirás donde lo dejaste.',
      );
      expect(find.text(es.signInAgainReason), findsOneWidget);
      expect(emailText(tester), 'ana@example.com');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-623: system Back on the sign-in-again route keeps the route, the reason line, the email and the editor underneath with its text',
    (tester) async {
      const typed = 'Comprar regalo para Marta';
      await expireWhileEditing(tester, typed: typed);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(LoginScreen).hitTestable(), findsWidgets);
      expect(find.text(es.signInAgainReason), findsOneWidget);
      expect(emailText(tester), 'ana@example.com');
      expect(find.byType(TaskEditor, skipOffstage: false), findsOneWidget);
      expect(titleText(tester), typed);
      // A second Back changes nothing either.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(es.signInAgainReason), findsOneWidget);
      expect(emailText(tester), 'ana@example.com');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-623: typing a password on the sign-in-again route keeps the reason line',
    (tester) async {
      await expireWhileEditing(tester);
      final password = find.byKey(const ValueKey('account-password'));
      await tester.ensureVisible(password);
      await tester.enterText(password, 'algo');
      await tester.pump();
      await tester.enterText(password, 'algo-más');
      await tester.pumpAndSettle();
      expect(find.text(es.signInAgainReason), findsOneWidget);
      expect(emailText(tester), 'ana@example.com');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-623: the sign-in-again route shows neither the session error sentence nor the sales pitch',
    (tester) async {
      await expireWhileEditing(tester);
      final session = es.requestError('session');
      expect(
        session,
        'Vuelve a iniciar sesión para continuar. Tus tareas locales se conservan.',
      );
      expect(
        es.authPitch,
        'Apunta lo que tienes que hacer y TaskFlow lo pone en tu calendario.',
      );
      expect(find.text(session, skipOffstage: false), findsNothing);
      expect(find.text(es.authPitch, skipOffstage: false), findsNothing);
      // Nor after Back.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(session, skipOffstage: false), findsNothing);
      expect(find.text(es.authPitch, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-623: the cold-start sign-in still shows the pitch with an empty email, and Back in create mode returns to sign-in',
    (tester) async {
      await openApp(tester, _SlowReminders(), signedIn: false);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(es.authPitch), findsOneWidget);
      expect(find.text(es.signInAgainReason), findsNothing);
      expect(emailText(tester), isEmpty);

      final create = find.text(es.createAnAccount);
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text(es.registerHeading), findsOneWidget);
      expect(find.text(es.authPitch), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(find.text(es.registerHeading), findsNothing);
      expect(find.text(es.authPitch), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-623: in Catalan at 2× text on 320×640, the sign-in-again route shows S’ha tancat la sessió… with no overflow',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        ca.signInAgainReason,
        'S’ha tancat la sessió. Torna a entrar i continuaràs on ho havies deixat.',
      );
      await expireWhileEditing(
        tester,
        typed: 'Trucar al dentista',
        language: 'ca',
        size: const Size(320, 640),
      );
      final reason = find.text(ca.signInAgainReason);
      expect(reason, findsOneWidget);
      await tester.ensureVisible(reason);
      await tester.pumpAndSettle();
      final rect = tester.getRect(reason);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(find.text(ca.authPitch, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-623: signInAgainReason has the exact copy in English, Spanish and Catalan',
    () {
      expect(
        lookupAppLocalizations(const Locale('en')).signInAgainReason,
        'You were signed out. Sign in again to pick up where you left off.',
      );
      expect(
        es.signInAgainReason,
        'Tu sesión se ha cerrado. Vuelve a entrar y seguirás donde lo dejaste.',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).signInAgainReason,
        'S’ha tancat la sessió. Torna a entrar i continuaràs on ho havies deixat.',
      );
    },
  );
  // ---- UX loop 2026-10-19-app, round 1 · P193 (UX-1603): sign-in again
  // keeps the email form open, even where Google can sign in ----

  testWidgets(
    'UX-1603: with Google set up, sign-in again opens with the email form showing and ana@example.com filled, with no Continuar con mi correo',
    (tester) async {
      final (_, api) = await openApp(
        tester,
        _SlowReminders(),
        google: _ConfiguredGoogle(),
      );
      await editTask(tester, 'Llamar al dentista');
      api.expire();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(es.signInAgainReason), findsOneWidget);
      expect(find.byKey(const ValueKey('google-sign-in')), findsOneWidget);
      expect(find.byKey(const ValueKey('continue-with-email')), findsNothing);
      expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-password')), findsOneWidget);
      expect(emailText(tester), 'ana@example.com');
      expect(tester.takeException(), isNull);
    },
  );
}

/// Reminder setup that waits until [finish], as on a phone where a
/// background job holds the reminder lease.
class _SlowReminders {
  final owners = <String>[];
  final _done = Completer<void>();
  bool get pending => !_done.isCompleted;
  Future<void> activate(String owner) {
    owners.add(owner);
    return _done.future;
  }

  void finish() => _done.complete();
}

/// A stand-in server: account 1 is signed in until [expire]; signing in
/// gives [nextAccount].
class _SessionApi extends OfflineApiClient {
  _SessionApi({this.signedIn = true});

  /// Whether a saved session is restored at start; otherwise the app opens
  /// on the cold-start sign-in.
  final bool signedIn;
  final _invalidated = StreamController<void>.broadcast();
  Account? _account;
  int nextAccount = 1;
  int signIns = 0;

  static Account _user(int id) => Account.fromJson({
    'id': id,
    'email': id == 1 ? 'ana@example.com' : 'design$id@example.invalid',
    'timezone': 'Europe/Madrid',
  });

  @override
  Account? get account => _account;

  @override
  Stream<void> get sessionInvalidated => _invalidated.stream;

  @override
  Future<void> restore() async {
    _account = signedIn ? _user(1) : null;
  }

  /// The server ends the session, as a refused refresh does.
  void expire() {
    _account = null;
    _invalidated.add(null);
  }

  @override
  Future<Account> refreshAccount() async =>
      _account ?? (throw ApiException(401, 'Sign in to continue.'));

  @override
  Future<void> setServer(String value) async {}

  @override
  Future<void> signIn(
    String email,
    String password, {
    bool register = false,
    String timezone = 'UTC',
    String? language,
  }) async {
    signIns++;
    _account = _user(nextAccount);
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async => {};

  @override
  void close() {
    unawaited(_invalidated.close());
    super.close();
  }
}

/// P193: Google sign-in set up on this phone.
class _ConfiguredGoogle extends GoogleSignInService {
  @override
  bool get supported => true;
  @override
  bool get configured => true;
}
