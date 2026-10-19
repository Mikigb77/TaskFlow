import 'dart:io';
import 'dart:ui' as ui;
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/login_screen.dart';
import 'package:agenda/screens/main_shell.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/site_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/widgets/app_components.dart';

class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {} // The test controls when restoration finishes.
  void finish({bool signedIn = false}) {
    state = AuthState(
      account: signedIn
          ? Account.fromJson({
              'id': 1,
              'email': 'fixture@example.invalid',
              'timezone': 'Europe/Madrid',
            })
          : null,
    );
  }

  @override
  Future<void> signOut() async => finish();
}

class _Google extends GoogleSignInService {
  @override
  bool get supported => true;
  @override
  bool get configured => true;
}

Future<(ProviderContainer, _Auth)> _open(
  WidgetTester tester, {
  ThemeMode theme = ThemeMode.light,
  Key? previewKey,
  OfflineApiClient? client,
  String language = 'en',
  Size size = const Size(390, 844),
  Future<bool> Function(Uri)? openPage,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = client ?? OfflineApiClient();
  final auth = _Auth(api);
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => auth),
      googleSignInServiceProvider.overrideWithValue(_Google()),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      pendingCapturesProvider.overrideWith((ref) async => []),
      themeStoreProvider.overrideWithValue(MemoryThemeStore(theme.name)),
      regionalStoreProvider.overrideWithValue(
        MemoryRegionalStore(RegionalPreferences(language: language)),
      ),
      if (openPage != null) openWebPageProvider.overrideWithValue(openPage),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(api.close);
  await container.read(themeModeProvider.notifier).ready;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(key: previewKey, child: const MyApp()),
    ),
  );
  await tester.pump();
  return (container, auth);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  // Signed out, the app waits for the stored address waiting for its code.
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('restoration exposes neither login nor tasks until it finishes', (
    tester,
  ) async {
    final (_, auth) = await _open(tester);
    expect(find.byType(SessionLoadingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MainShell), findsNothing);
    auth.finish();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('signed-out named routes cannot open protected screens', (
    tester,
  ) async {
    final (_, auth) = await _open(tester);
    auth.finish();
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final route in [
      '/calendar',
      '/captures',
      '/taskDetails',
      '/voiceTask',
      '/settings',
      '/subscription',
    ]) {
      navigator.pushNamed(route, arguments: 1);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget, reason: route);
      expect(find.byType(MainShell), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'a restored account opens Calendar; logout clears protected back history',
    (tester) async {
      final (_, auth) = await _open(tester);
      auth.finish(signedIn: true);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      final previous = tester.state<NavigatorState>(find.byType(Navigator));
      previous.pushNamed('/captures');
      await tester.pumpAndSettle();
      expect(previous.canPop(), isTrue);
      await auth.signOut();
      await tester.pumpAndSettle();
      final current = tester.state<NavigatorState>(find.byType(Navigator));
      expect(current, isNot(same(previous)));
      expect(current.canPop(), isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell, skipOffstage: false), findsNothing);
      auth.finish(signedIn: true);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'login has Google above email and supports appearance controls: $theme',
      (tester) async {
        final preview = GlobalKey();
        final (_, auth) = await _open(
          tester,
          theme: theme,
          previewKey: preview,
        );
        auth.finish();
        await tester.pumpAndSettle();
        final email = find.byKey(const ValueKey('account-email'));
        final google = find.byKey(const ValueKey('google-sign-in'));
        expect(
          tester.getBottomLeft(google).dy,
          lessThan(tester.getTopLeft(email).dy),
        );
        expect(google.hitTestable(), findsOneWidget);
        expect(find.byTooltip('Language'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('WRITE_AUTH_PREVIEWS')) {
          final boundary =
              preview.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final file = File('artifacts/auth/login-${theme.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.enterText(
          find.byKey(const ValueKey('account-email')),
          'preserved@example.invalid',
        );
        await tester.ensureVisible(find.text('Create an account'));
        await tester.tap(find.text('Create an account'));
        await tester.pumpAndSettle();
        expect(find.text('preserved@example.invalid'), findsOneWidget);
        expect(find.byKey(const ValueKey('google-sign-in')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- P17 (UX-402, UX-403, UX-415, U14) and P18 (UX-418) ----

  final es = lookupAppLocalizations(const Locale('es'));
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timezone = MethodChannel('flutter_timezone');
  setUp(
    () => platform.setMockMethodCallHandler(
      timezone,
      (_) async => 'Europe/Madrid',
    ),
  );
  tearDown(() => platform.setMockMethodCallHandler(timezone, null));

  final email = find.byKey(const ValueKey('account-email'));
  final password = find.byKey(const ValueKey('account-password'));
  final submit = find.byKey(const ValueKey('account-submit'));
  final google = find.byKey(const ValueKey('google-sign-in'));
  String typed(WidgetTester tester, Finder field) =>
      tester.widget<TextFormField>(field).controller!.text;

  /// The sign-in screen in Spanish, with the server answering through [api].
  Future<_LoginApi> openSpanish(
    WidgetTester tester, {
    _LoginApi? api,
    Size size = const Size(390, 844),
  }) async {
    final client = api ?? _LoginApi();
    final (_, auth) = await _open(
      tester,
      client: client,
      language: 'es',
      size: size,
    );
    auth.finish();
    await tester.pumpAndSettle();
    return client;
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-402: unknown credentials show the message and Crear una cuenta con este correo; tapping it lands in create mode with both fields filled',
    (tester) async {
      expect(
        es.requestError('credentials'),
        'No encontramos esa cuenta o la contraseña no es correcta.',
      );
      expect(es.createAccountWithEmail, 'Crear una cuenta con este correo');
      final api = await openSpanish(
        tester,
        api: _LoginApi(
          signInError: ApiException(
            401,
            'No active account found with the given credentials',
          ),
        ),
      );
      await tester.enterText(email, 'nueva@example.invalid');
      await tester.enterText(password, 'una-clave-larga-2026');
      await tapVisible(tester, submit);
      expect(api.signIns.single, ('nueva@example.invalid', false));
      expect(find.text(es.requestError('credentials')), findsOneWidget);
      final create = find.byKey(const ValueKey('create-account-with-email'));
      expect(
        find.descendant(
          of: create,
          matching: find.text(es.createAccountWithEmail),
        ),
        findsOneWidget,
      );
      await tapVisible(tester, create);
      expect(find.text(es.registerHeading), findsOneWidget);
      expect(typed(tester, email), 'nueva@example.invalid');
      expect(typed(tester, password), 'una-clave-larga-2026');
      expect(
        find.descendant(of: submit, matching: find.text(es.createAccount)),
        findsOneWidget,
      );
      expect(find.text(es.requestError('credentials')), findsNothing);
      // Creating the account sends both, in create mode.
      api.signInError = null;
      await tapVisible(tester, submit);
      expect(api.signIns.last, ('nueva@example.invalid', true));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-402: in Spanish the headings read Inicia sesión, Crea tu cuenta and Recupera tu contraseña',
    (tester) async {
      expect(es.signInHeading, 'Inicia sesión');
      expect(es.registerHeading, 'Crea tu cuenta');
      expect(es.recoveryHeading, 'Recupera tu contraseña');
      await openSpanish(tester);
      expect(find.text(es.signInHeading), findsOneWidget);
      await tapVisible(tester, find.text(es.createAnAccount));
      expect(find.text(es.registerHeading), findsOneWidget);
      expect(find.text(es.signInHeading), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text(es.forgotPassword));
      expect(find.text(es.recoveryHeading), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-402: switching between sign-in and create keeps the typed password',
    (tester) async {
      await openSpanish(tester);
      await tester.enterText(email, 'ana@example.invalid');
      await tester.enterText(password, 'una-clave-larga-2026');
      await tapVisible(tester, find.text(es.createAnAccount));
      expect(find.text(es.registerHeading), findsOneWidget);
      expect(typed(tester, password), 'una-clave-larga-2026');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(typed(tester, password), 'una-clave-larga-2026');
      expect(typed(tester, email), 'ana@example.invalid');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-403: Spanish, 2× text, 360×740, a password error from the server is on the password field and visible without scrolling',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = await openSpanish(
        tester,
        size: const Size(360, 740),
        api: _LoginApi(
          signInError: ApiException(400, 'This password is too common.', {
            'password': ['This password is too common.'],
          }),
        ),
      );
      await tapVisible(tester, find.text(es.createAnAccount));
      // The rule is stated before typing.
      expect(es.passwordHelp, 'Al menos 12 caracteres, no solo números');
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: password, matching: find.byType(TextField)),
            )
            .decoration!
            .helperText,
        es.passwordHelp,
      );
      await tester.enterText(email, 'ana@example.invalid');
      await tester.enterText(password, 'contraseña123');
      await tapVisible(tester, submit);
      expect(api.signIns.single, ('ana@example.invalid', true));
      final message = es.requestError('password');
      final field = tester.widget<TextField>(
        find.descendant(of: password, matching: find.byType(TextField)),
      );
      expect(field.decoration!.errorText, message);
      final shown = find.descendant(of: password, matching: find.text(message));
      expect(shown, findsOneWidget);
      final rect = tester.getRect(shown);
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$rect');
      expect(rect.bottom, lessThanOrEqualTo(740), reason: '$rect');
      // Not a banner under the button.
      expect(find.byType(MessageBanner), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-403: an email already in use shows on the email field; no connection scrolls its message into view (Spanish, 2× text, 360×740)',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = await openSpanish(
        tester,
        size: const Size(360, 740),
        api: _LoginApi(
          signInError: ApiException(
            400,
            'An account with this email already exists.',
          ),
        ),
      );
      await tapVisible(tester, find.text(es.createAnAccount));
      await tester.enterText(email, 'ana@example.invalid');
      await tester.enterText(password, 'una-clave-larga-2026');
      await tapVisible(tester, submit);
      final used = es.requestError('emailUsed');
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: email, matching: find.byType(TextField)),
            )
            .decoration!
            .errorText,
        used,
      );
      var rect = tester.getRect(
        find.descendant(of: email, matching: find.text(used)),
      );
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$rect');
      expect(rect.bottom, lessThanOrEqualTo(740), reason: '$rect');

      api.signInError = ApiException(0, 'Network unavailable');
      await tester.enterText(email, 'ana@example.invalid');
      await tapVisible(tester, submit);
      final offline = es.requestError('network');
      final banner = find.text(offline);
      expect(banner, findsOneWidget);
      rect = tester.getRect(banner);
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$rect');
      expect(rect.bottom, lessThanOrEqualTo(740), reason: '$rect');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-415: Back in create mode and in recovery returns to sign-in instead of leaving',
    (tester) async {
      await openSpanish(tester);
      await tapVisible(tester, find.text(es.createAnAccount));
      expect(find.text(es.registerHeading), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(es.signInHeading), findsOneWidget);
      await tapVisible(tester, find.text(es.forgotPassword));
      expect(find.text(es.recoveryHeading), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-415: the recovery buttons read Enviar código, then Guardar contraseña nueva; after success the sign-in form holds the email and the new password',
    (tester) async {
      expect(es.sendRecoveryCode, 'Enviar código');
      expect(es.saveNewPassword, 'Guardar contraseña nueva');
      final api = await openSpanish(tester);
      await tapVisible(tester, find.text(es.forgotPassword));
      expect(
        find.descendant(of: submit, matching: find.text(es.sendRecoveryCode)),
        findsOneWidget,
      );
      await tester.enterText(email, 'ana@example.invalid');
      await tapVisible(tester, submit);
      expect(api.requests.last, [
        'auth/password-reset/',
        {'email': 'ana@example.invalid'},
      ]);
      expect(
        find.descendant(of: submit, matching: find.text(es.saveNewPassword)),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-recovery-code')),
        '123456',
      );
      await tester.enterText(password, 'clave-nueva-2026');
      await tapVisible(tester, submit);
      expect(api.requests.last, [
        'auth/password-reset/confirm/',
        {'code': '123456', 'password': 'clave-nueva-2026'},
      ]);
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(
        find.descendant(of: submit, matching: find.text(es.signIn)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('account-recovery-code')), findsNothing);
      expect(typed(tester, password), 'clave-nueva-2026');
      expect(typed(tester, email), 'ana@example.invalid');
      expect(find.text(es.passwordResetComplete), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final register in [false, true]) {
    testWidgets(
      'U14: in ${register ? 'create' : 'sign-in'} mode, Spanish at 2× text on 360×740: the line Apunta lo que tienes que hacer… is under the heading and Continuar con Google, above the email field, is visible without scrolling',
      (tester) async {
        expect(
          es.authPitch,
          'Apunta lo que tienes que hacer y TaskFlow lo pone en tu calendario.',
        );
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openSpanish(tester, size: const Size(360, 740));
        if (register) {
          await tapVisible(tester, find.text(es.createAnAccount));
          // Back at the top, as a newcomer arrives.
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 3000),
          );
          await tester.pumpAndSettle();
        }
        final heading = find.text(
          register ? es.registerHeading : es.signInHeading,
        );
        final pitch = find.text(es.authPitch);
        expect(heading, findsOneWidget);
        expect(pitch, findsOneWidget);
        expect(
          tester.getRect(pitch).top,
          greaterThanOrEqualTo(tester.getRect(heading).bottom),
        );
        expect(google, findsOneWidget);
        expect(
          tester.getRect(google).top,
          greaterThanOrEqualTo(tester.getRect(pitch).bottom),
        );
        expect(
          tester.getRect(google).bottom,
          lessThan(tester.getRect(email).top),
        );
        expect(
          find.descendant(
            of: google,
            matching: find.text(es.continueWithGoogle),
          ),
          findsOneWidget,
        );
        // On screen as it opens, without scrolling.
        expect(tester.getRect(google).top, greaterThanOrEqualTo(0));
        expect(tester.getRect(google).bottom, lessThanOrEqualTo(740));
        expect(google.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'U14 / UX-418: recovery has no Google button, and the sign-in screen has no sun–moon toggle',
    (tester) async {
      await openSpanish(tester);
      expect(find.byKey(const ValueKey('theme-toggle')), findsNothing);
      for (final icon in [
        Icons.dark_mode,
        Icons.dark_mode_outlined,
        Icons.dark_mode_rounded,
        Icons.light_mode,
        Icons.light_mode_outlined,
        Icons.light_mode_rounded,
      ]) {
        expect(find.byIcon(icon), findsNothing);
      }
      await tapVisible(tester, find.text(es.forgotPassword));
      expect(google, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P77 (UX-484): sign-in asks only for a password; a used email
  // offers sign-in ----

  String? passwordError(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(of: password, matching: find.byType(TextField)),
      )
      .decoration!
      .errorText;

  testWidgets(
    'UX-484: in sign-in mode a 6-character password is sent with no 12-character message; wrong credentials then offer Crear una cuenta con este correo with the email kept',
    (tester) async {
      final api = await openSpanish(
        tester,
        api: _LoginApi(
          signInError: ApiException(
            401,
            'No active account found with the given credentials',
          ),
        ),
      );
      expect(find.text(es.signInHeading), findsOneWidget);
      // An empty password is still refused, without reaching the server.
      await tester.enterText(email, 'nueva@example.invalid');
      await tapVisible(tester, submit);
      expect(api.signIns, isEmpty);
      expect(passwordError(tester), isNotNull);
      expect(passwordError(tester), isNot(es.passwordTooShort));
      // A short everyday password goes to the server.
      await tester.enterText(password, 'abc123');
      await tapVisible(tester, submit);
      expect(api.signIns.single, ('nueva@example.invalid', false));
      expect(find.text(es.passwordTooShort), findsNothing);
      expect(passwordError(tester), isNot(es.passwordTooShort));
      expect(find.text(es.requestError('credentials')), findsOneWidget);
      final create = find.byKey(const ValueKey('create-account-with-email'));
      expect(
        find.descendant(
          of: create,
          matching: find.text(es.createAccountWithEmail),
        ),
        findsOneWidget,
      );
      await tapVisible(tester, create);
      expect(find.text(es.registerHeading), findsOneWidget);
      expect(typed(tester, email), 'nueva@example.invalid');
      // Creating the account then asks for 12 characters.
      await tapVisible(tester, submit);
      expect(api.signIns, hasLength(1));
      expect(passwordError(tester), es.passwordTooShort);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-484: in create mode a password under 12 characters is still refused with Usa al menos 12 caracteres',
    (tester) async {
      expect(es.passwordTooShort, 'Usa al menos 12 caracteres');
      final api = await openSpanish(tester);
      await tapVisible(tester, find.text(es.createAnAccount));
      expect(find.text(es.registerHeading), findsOneWidget);
      await tester.enterText(email, 'ana@example.invalid');
      await tester.enterText(password, 'clave-11chr');
      expect('clave-11chr'.length, 11);
      await tapVisible(tester, submit);
      expect(api.signIns, isEmpty);
      expect(passwordError(tester), es.passwordTooShort);
      expect(
        find.descendant(of: password, matching: find.text(es.passwordTooShort)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-484: in create mode ($language), an email already in use shows a sign-in button that switches to sign-in with the email kept',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final api = _LoginApi(
          signInError: ApiException(
            400,
            'An account with this email already exists.',
          ),
        );
        final (_, auth) = await _open(
          tester,
          client: api,
          language: language,
          size: const Size(360, 740),
        );
        auth.finish();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text(l.createAnAccount));
        expect(find.text(l.registerHeading), findsOneWidget);
        await tester.enterText(email, 'ana@example.invalid');
        await tester.enterText(password, 'una-clave-larga-2026');
        await tapVisible(tester, submit);
        expect(api.signIns.single, ('ana@example.invalid', true));
        expect(
          find.descendant(
            of: email,
            matching: find.text(l.requestError('emailUsed')),
          ),
          findsOneWidget,
        );
        final signIn = find.byKey(const ValueKey('sign-in-with-email'));
        expect(signIn, findsOneWidget);
        expect(
          find.descendant(of: signIn, matching: find.text(l.signInWithEmail)),
          findsOneWidget,
        );
        await tapVisible(tester, signIn);
        // In English and Catalan the heading and the button read the same.
        expect(find.text(l.signInHeading), findsWidgets);
        expect(find.text(l.registerHeading), findsNothing);
        expect(typed(tester, email), 'ana@example.invalid');
        expect(find.text(l.requestError('emailUsed')), findsNothing);
        expect(signIn, findsNothing);
        expect(
          find.descendant(of: submit, matching: find.text(l.signIn)),
          findsOneWidget,
        );
        // Signing in now sends it as a sign-in.
        api.signInError = ApiException(0, 'Network unavailable');
        await tapVisible(tester, submit);
        expect(api.signIns.last, ('ana@example.invalid', false));
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- P83 (UX-488): the email-in-use button names itself; a known account
  // offers recovery ----

  final recoverButton = find.byKey(const ValueKey('recover-with-email'));
  final createButton = find.byKey(const ValueKey('create-account-with-email'));
  final signInButton = find.byKey(const ValueKey('sign-in-with-email'));
  ApiException emailInUse() =>
      ApiException(400, 'An account with this email already exists.');
  ApiException wrongCredentials() =>
      ApiException(401, 'No active account found with the given credentials');

  /// Create mode with [address]; the server says the email is in use.
  Future<_LoginApi> reachEmailInUse(
    WidgetTester tester,
    AppLocalizations l, {
    required String language,
    required Size size,
    String address = 'ana@example.invalid',
  }) async {
    final api = _LoginApi(signInError: emailInUse());
    final (_, auth) = await _open(
      tester,
      client: api,
      language: language,
      size: size,
    );
    auth.finish();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text(l.createAnAccount));
    expect(find.text(l.registerHeading), findsOneWidget);
    await tester.enterText(email, address);
    await tester.enterText(password, 'una-clave-larga-2026');
    await tapVisible(tester, submit);
    expect(api.signIns.last, (address, true));
    expect(signInButton, findsOneWidget);
    return api;
  }

  testWidgets(
    'UX-488: Spanish at 2× text on 360×740: email in use → Iniciar sesión con este correo → wrong credentials offer ¿Has olvidado tu contraseña?, not Crear una cuenta con este correo → recovery with the email kept',
    (tester) async {
      expect(es.signInWithEmail, 'Iniciar sesión con este correo');
      expect(es.forgotPassword, '¿Has olvidado tu contraseña?');
      expect(es.signInWithEmail, isNot(es.signIn));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = await reachEmailInUse(
        tester,
        es,
        language: 'es',
        size: const Size(360, 740),
      );
      expect(
        find.descendant(
          of: signInButton,
          matching: find.text(es.signInWithEmail),
        ),
        findsOneWidget,
      );
      // It doesn't read like the submit button.
      expect(
        find.descendant(of: signInButton, matching: find.text(es.signIn)),
        findsNothing,
      );
      await tapVisible(tester, signInButton);
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(find.text(es.registerHeading), findsNothing);
      expect(typed(tester, email), 'ana@example.invalid');
      expect(
        find.descendant(of: submit, matching: find.text(es.signIn)),
        findsOneWidget,
      );
      // The old password is wrong for that account.
      api.signInError = wrongCredentials();
      await tapVisible(tester, submit);
      expect(api.signIns.last, ('ana@example.invalid', false));
      expect(find.text(es.requestError('credentials')), findsOneWidget);
      expect(recoverButton, findsOneWidget);
      expect(
        find.descendant(
          of: recoverButton,
          matching: find.text(es.forgotPassword),
        ),
        findsOneWidget,
      );
      expect(createButton, findsNothing);
      expect(find.text(es.createAccountWithEmail), findsNothing);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, recoverButton);
      expect(find.text(es.recoveryHeading), findsOneWidget);
      expect(typed(tester, email), 'ana@example.invalid');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-488: after reaching sign-in through Iniciar sesión con este correo, changing the email and getting wrong credentials offers Crear una cuenta con este correo again',
    (tester) async {
      final api = await reachEmailInUse(
        tester,
        es,
        language: 'es',
        size: const Size(390, 844),
      );
      await tapVisible(tester, signInButton);
      expect(find.text(es.signInHeading), findsOneWidget);
      await tester.enterText(email, 'otra@example.invalid');
      await tester.pumpAndSettle();
      api.signInError = wrongCredentials();
      await tapVisible(tester, submit);
      expect(api.signIns.last, ('otra@example.invalid', false));
      expect(find.text(es.requestError('credentials')), findsOneWidget);
      expect(createButton, findsOneWidget);
      expect(
        find.descendant(
          of: createButton,
          matching: find.text(es.createAccountWithEmail),
        ),
        findsOneWidget,
      );
      expect(recoverButton, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-488: a direct sign-in with wrong credentials still offers Crear una cuenta con este correo and no recovery button (UX-402 unchanged)',
    (tester) async {
      final api = await openSpanish(
        tester,
        api: _LoginApi(signInError: wrongCredentials()),
      );
      expect(find.text(es.signInHeading), findsOneWidget);
      await tester.enterText(email, 'ana@example.invalid');
      await tester.enterText(password, 'una-clave-larga-2026');
      await tapVisible(tester, submit);
      expect(api.signIns.single, ('ana@example.invalid', false));
      expect(createButton, findsOneWidget);
      expect(
        find.descendant(
          of: createButton,
          matching: find.text(es.createAccountWithEmail),
        ),
        findsOneWidget,
      );
      expect(recoverButton, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-488: a mode switch through the links forgets the known account: email in use → sign in → Crear una cuenta → Iniciar sesión → wrong credentials offers Crear una cuenta con este correo',
    (tester) async {
      final api = await reachEmailInUse(
        tester,
        es,
        language: 'es',
        size: const Size(390, 844),
      );
      await tapVisible(tester, signInButton);
      expect(find.text(es.signInHeading), findsOneWidget);
      // To create mode and back again by the links.
      await tapVisible(tester, find.text(es.createAnAccount));
      expect(find.text(es.registerHeading), findsOneWidget);
      await tapVisible(tester, find.text(es.alreadyHaveAccount));
      expect(find.text(es.signInHeading), findsOneWidget);
      api.signInError = wrongCredentials();
      await tapVisible(tester, submit);
      expect(createButton, findsOneWidget);
      expect(recoverButton, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-488: the button reads Sign in with this email in English and Inicia la sessió amb aquest correu in Catalan; in Catalan at 2× text on 320×640 it wraps without overflow',
    (tester) async {
      final en = lookupAppLocalizations(const Locale('en'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.signInWithEmail, 'Sign in with this email');
      expect(ca.signInWithEmail, 'Inicia la sessió amb aquest correu');
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await reachEmailInUse(
        tester,
        ca,
        language: 'ca',
        size: const Size(320, 640),
      );
      final label = find.descendant(
        of: signInButton,
        matching: find.text(ca.signInWithEmail),
      );
      expect(label, findsOneWidget);
      await tester.ensureVisible(signInButton);
      await tester.pumpAndSettle();
      final button = tester.getRect(signInButton);
      final text = tester.getRect(label);
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(320.5));
      // The whole label is inside its button, on more than one line if needed.
      expect(text.left, greaterThanOrEqualTo(button.left - 0.5));
      expect(text.right, lessThanOrEqualTo(button.right + 0.5));
      expect(text.top, greaterThanOrEqualTo(button.top - 0.5));
      expect(text.bottom, lessThanOrEqualTo(button.bottom + 0.5));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)).first,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P88 (UX-495): one ¿Has olvidado tu contraseña? control, not two ----

  /// Every ¿Has olvidado tu contraseña? on the page, on screen or scrolled.
  Finder forgotAnywhere() => find.text(es.forgotPassword, skipOffstage: false);

  testWidgets(
    'UX-495: Spanish at 2× text on 360×740: email in use → Iniciar sesión con este correo → wrong credentials show ¿Has olvidado tu contraseña? exactly once, as the recover-with-email button',
    (tester) async {
      expect(es.forgotPassword, '¿Has olvidado tu contraseña?');
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final api = await reachEmailInUse(
        tester,
        es,
        language: 'es',
        size: const Size(360, 740),
      );
      await tapVisible(tester, signInButton);
      expect(find.text(es.signInHeading), findsOneWidget);
      api.signInError = wrongCredentials();
      await tapVisible(tester, submit);
      expect(find.text(es.requestError('credentials')), findsOneWidget);
      expect(recoverButton, findsOneWidget);
      expect(forgotAnywhere(), findsOneWidget);
      expect(
        find.descendant(
          of: recoverButton,
          matching: find.text(es.forgotPassword),
        ),
        findsOneWidget,
      );
      // TalkBack meets the name once.
      expect(
        find.bySemanticsLabel(es.forgotPassword, skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-495: a direct sign-in with wrong credentials still shows the small ¿Has olvidado tu contraseña? link once, and Crear una cuenta con este correo',
    (tester) async {
      await openSpanish(
        tester,
        api: _LoginApi(signInError: wrongCredentials()),
      );
      await tester.enterText(email, 'ana@example.invalid');
      await tester.enterText(password, 'una-clave-larga-2026');
      await tapVisible(tester, submit);
      expect(find.text(es.requestError('credentials')), findsOneWidget);
      expect(recoverButton, findsNothing);
      expect(forgotAnywhere(), findsOneWidget);
      expect(
        find.ancestor(of: forgotAnywhere(), matching: find.byType(TextButton)),
        findsOneWidget,
      );
      expect(createButton, findsOneWidget);
      expect(
        find.descendant(
          of: createButton,
          matching: find.text(es.createAccountWithEmail),
        ),
        findsOneWidget,
      );
      // The link still opens recovery.
      await tapVisible(tester, find.text(es.forgotPassword));
      expect(find.text(es.recoveryHeading), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-495: plain sign-in mode with no error still shows the small ¿Has olvidado tu contraseña? link',
    (tester) async {
      await openSpanish(tester);
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(recoverButton, findsNothing);
      expect(forgotAnywhere(), findsOneWidget);
      expect(
        find.ancestor(of: forgotAnywhere(), matching: find.byType(TextButton)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P158 (UX-1222): the Privacy Policy and the Terms, under the card ----

  final privacyLink = find.byKey(const ValueKey('site-privacy'));
  final termsLink = find.byKey(const ValueKey('site-terms'));

  /// Sign-in in [language], noting every page it asks to open.
  Future<List<Uri>> openSignIn(
    WidgetTester tester, {
    String language = 'es',
    Size size = const Size(390, 844),
    bool opens = true,
  }) async {
    final opened = <Uri>[];
    final (_, auth) = await _open(
      tester,
      client: _LoginApi(),
      language: language,
      size: size,
      openPage: (uri) async {
        opened.add(uri);
        return opens;
      },
    );
    auth.finish();
    await tester.pumpAndSettle();
    return opened;
  }

  for (final (language, prefix) in [('es', '/es'), ('en', ''), ('ca', '/ca')]) {
    testWidgets(
      'UX-1222: in $language, sign-in shows Privacy Policy and Terms under the card, quiet, and each opens the site’s page in the app’s language',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final opened = await openSignIn(tester, language: language);
        for (final (link, label) in [
          (privacyLink, l.privacyPolicy),
          (termsLink, l.termsAndConditions),
        ]) {
          expect(
            find.descendant(of: link, matching: find.text(label)),
            findsOneWidget,
          );
          // Under the card, after its last button.
          expect(
            tester.getTopLeft(link).dy,
            greaterThan(tester.getBottomLeft(find.text(l.createAnAccount)).dy),
          );
          final colors = Theme.of(tester.element(link)).colorScheme;
          final style = tester.widget<TextButton>(link).style!;
          expect(style.foregroundColor!.resolve({}), colors.onSurfaceVariant);
        }
        await tapVisible(tester, privacyLink);
        await tapVisible(tester, termsLink);
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
    'UX-1222: the two links show in Crea tu cuenta too, and not in password recovery',
    (tester) async {
      await openSignIn(tester);
      expect(privacyLink, findsOneWidget);
      expect(termsLink, findsOneWidget);
      await tapVisible(tester, find.text(es.createAnAccount));
      expect(find.text(es.registerHeading), findsOneWidget);
      expect(privacyLink, findsOneWidget);
      expect(termsLink, findsOneWidget);
      expect(find.text(es.privacyPolicy), findsOneWidget);
      expect(find.text(es.termsAndConditions), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text(es.forgotPassword));
      expect(find.text(es.recoveryHeading), findsOneWidget);
      expect(find.text(es.privacyPolicy), findsNothing);
      expect(find.text(es.termsAndConditions), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1222: on sign-in, a page that can’t open says «No se ha podido abrir la página.»',
    (tester) async {
      final opened = await openSignIn(tester, opens: false);
      await tapVisible(tester, privacyLink);
      expect(opened, hasLength(1));
      expect(find.text(es.webPageOpenError), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-1222: at 2× on 320×640 in $language, sign-in’s two links show whole, each tap target is at least 48 dp tall, and Google is still the first button',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openSignIn(
          tester,
          language: language,
          size: const Size(320, 640),
        );
        // Google first: above the email, and above every other button the
        // page scrolls.
        final googleRect = tester.getRect(google);
        expect(googleRect.top, lessThan(tester.getTopLeft(email).dy));
        final body = find
            .descendant(
              of: find.byType(LoginScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        final buttons = find.descendant(
          of: body,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          skipOffstage: false,
        );
        expect(buttons.evaluate(), isNotEmpty);
        // Icon buttons (the language menu, show password) aren't ways in.
        final icons = find
            .descendant(
              of: find.byType(IconButton, skipOffstage: false),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              skipOffstage: false,
            )
            .evaluate()
            .toSet();
        for (final element in buttons.evaluate()) {
          if (icons.contains(element)) continue;
          final rect = tester.getRect(find.byElementPredicate(
            (e) => identical(e, element),
            skipOffstage: false,
          ));
          // The Google button itself, or anything inside it.
          if (rect.top >= googleRect.top - 0.5 &&
              rect.bottom <= googleRect.bottom + 0.5) {
            continue;
          }
          expect(
            rect.top,
            greaterThanOrEqualTo(googleRect.bottom - 0.5),
            reason: '${element.widget}',
          );
        }
        for (final (link, label) in [
          (privacyLink, l.privacyPolicy),
          (termsLink, l.termsAndConditions),
        ]) {
          await tester.scrollUntilVisible(link, 100, scrollable: body);
          await tester.pumpAndSettle();
          final rect = tester.getRect(link);
          expect(rect.left, greaterThanOrEqualTo(-0.5), reason: label);
          expect(rect.right, lessThanOrEqualTo(320.5), reason: label);
          expect(rect.height, greaterThanOrEqualTo(48), reason: label);
          final text = find.descendant(of: link, matching: find.text(label));
          final textRect = tester.getRect(text);
          expect(textRect.left, greaterThanOrEqualTo(-0.5), reason: label);
          expect(textRect.right, lessThanOrEqualTo(320.5), reason: label);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

/// The server for sign-in: [signInError] answers every sign-in until it is
/// cleared; password-reset requests succeed.
class _LoginApi extends OfflineApiClient {
  _LoginApi({this.signInError});
  Object? signInError;

  /// Each sign-in as (email, creating an account).
  final signIns = <(String, bool)>[];

  /// Each other request as [path, body].
  final requests = <List<Object?>>[];

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
    signIns.add((email, register));
    // Creating the account here stops short of signing in.
    throw signInError ?? ApiException(0, 'Network unavailable');
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    requests.add([path, data]);
    return {};
  }
}
