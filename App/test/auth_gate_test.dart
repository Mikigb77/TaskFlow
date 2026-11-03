import 'dart:io';
import 'dart:ui' as ui;
import 'package:agenda/providers/no_retry.dart';
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
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/site_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'support/reading_order.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/widgets/app_components.dart';
import 'support/shown_text.dart';

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

/// «Continue with email»: a fresh sign-in folds the email form behind it,
/// under Continue with Google.
Future<void> _openEmailForm(WidgetTester tester) async {
  final open = find.byKey(const ValueKey('continue-with-email'));
  await tester.ensureVisible(open);
  await tester.pumpAndSettle();
  await tester.tap(open);
  await tester.pumpAndSettle();
}

Future<(ProviderContainer, _Auth)> _open(
  WidgetTester tester, {
  ThemeMode theme = ThemeMode.light,
  Key? previewKey,
  OfflineApiClient? client,
  String language = 'en',
  Size size = const Size(390, 844),
  Future<bool> Function(Uri)? openPage,
  // Invitation links opened before signing in, without Android's channel.
  InvitationLinks? invitations,
  // Google sign-in on this phone; supported and configured by default.
  GoogleSignInService? google,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = client ?? OfflineApiClient();
  final auth = _Auth(api);
  final container = ProviderContainer(
    retry: noRetry,
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => auth),
      googleSignInServiceProvider.overrideWithValue(google ?? _Google()),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      pendingCapturesProvider.overrideWith((ref) async => []),
      themeStoreProvider.overrideWithValue(MemoryThemeStore(theme.name)),
      regionalStoreProvider.overrideWithValue(
        MemoryRegionalStore(RegionalPreferences(language: language)),
      ),
      if (openPage != null) openWebPageProvider.overrideWithValue(openPage),
      // Never Android's app_links channel, which a test has no plugin for.
      invitationLinkProvider.overrideWith(
        (ref) => invitations ?? InvitationLinks(listen: false),
      ),
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
        final continueWithEmail = find.byKey(
          const ValueKey('continue-with-email'),
        );
        // Google first; the email fields wait behind Continue with email.
        expect(google.hitTestable(), findsOneWidget);
        expect(email, findsNothing);
        expect(find.text('Create an account'), findsNothing);
        expect(
          tester.getBottomLeft(google).dy,
          lessThan(tester.getTopLeft(continueWithEmail).dy),
        );
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
        await _openEmailForm(tester);
        expect(
          tester.getBottomLeft(google).dy,
          lessThan(tester.getTopLeft(email).dy),
        );
        expect(continueWithEmail, findsNothing);
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
    await _openEmailForm(tester);
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
        {'email': 'ana@example.invalid', 'language': 'es'},
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
        {
          'email': 'ana@example.invalid',
          'code': '123456',
          'password': 'clave-nueva-2026',
        },
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
        await _openEmailForm(tester);
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
    await _openEmailForm(tester);
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
    await _openEmailForm(tester);
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

  // ---- UX loop 2026-10-19-app, round 1 · P170 (UX-1602, UX-1604, UX-1617,
  // UX-1507): sign-in ----

  final recoveryCode = find.byKey(const ValueKey('account-recovery-code'));

  /// Sign-in in [language] on [size], with the server answering through
  /// [api] and invitation links kept by [invitations].
  Future<_LoginApi> openIn(
    WidgetTester tester, {
    String language = 'es',
    _LoginApi? api,
    Size size = const Size(360, 800),
    InvitationLinks? invitations,
  }) async {
    final client = api ?? _LoginApi();
    final (_, auth) = await _open(
      tester,
      client: client,
      language: language,
      size: size,
      invitations: invitations,
    );
    auth.finish();
    await tester.pumpAndSettle();
    await _openEmailForm(tester);
    return client;
  }

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-1602: ${language.toUpperCase()}, 1x on 360x800, after Enviar código for maria.lopez@example.com the line naming the address sits above the recovery code, and the request carries language $language',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final api = await openIn(tester, language: language);
        await tapVisible(tester, find.text(l.forgotPassword));
        await tester.enterText(email, 'maria.lopez@example.com');
        await tapVisible(tester, submit);
        expect(api.requests.last, [
          'auth/password-reset/',
          {'email': 'maria.lopez@example.com', 'language': language},
        ]);
        final sent = findShown(
          l.recoveryEmailRequested('maria.lopez@example.com'),
        );
        expect(sent, findsOneWidget);
        expect(recoveryCode, findsOneWidget);
        expect(
          tester.getRect(sent).bottom,
          lessThanOrEqualTo(tester.getRect(recoveryCode).top),
          reason: 'the sent line, then «${l.recoveryCode}»',
        );
        // Not under the new password's button.
        expect(
          tester.getRect(sent).bottom,
          lessThan(tester.getRect(submit).top),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1602 (P191): the recovery code field keeps only 6 digits of a pasted uid:token value',
    (tester) async {
      final api = await openIn(tester);
      await tapVisible(tester, find.text(es.forgotPassword));
      await tester.enterText(email, 'maria.lopez@example.com');
      await tapVisible(tester, submit);
      const code = 'MTI3:cz9k2v-4f7e1b0a9c8d7e6f5a4b3c2d1e0f9a8b7';
      expect(code.length, 45);
      await tester.enterText(recoveryCode, code);
      await tester.pumpAndSettle();
      expect(typed(tester, recoveryCode), '392471');
      await tester.enterText(password, 'clave-nueva-2026-larga');
      await tapVisible(tester, submit);
      expect(api.requests.last, [
        'auth/password-reset/confirm/',
        {
          'email': 'maria.lopez@example.com',
          'code': '392471',
          'password': 'clave-nueva-2026-larga',
        },
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX loop 2026-10-19-app, round 2 · P199 (UX-1629): the recovery
  // code's label on the border ----

  /// Sign-in in [l]'s language, on to the recovery form with the code sent.
  Future<void> openRecoverySent(WidgetTester tester, AppLocalizations l) async {
    await openIn(tester, language: l.localeName);
    await tapVisible(tester, find.text(l.forgotPassword));
    await tester.enterText(email, 'maria.lopez@example.com');
    await tapVisible(tester, submit);
    expect(recoveryCode, findsOneWidget);
    expect(password, findsOneWidget);
  }

  /// [label]'s text inside [field], its decorator and its typing area.
  ({Rect label, Rect box, Rect typing}) fieldParts(
    WidgetTester tester,
    Finder field,
    String label,
  ) => (
    label: tester.getRect(
      find.descendant(of: field, matching: find.text(label)),
    ),
    box: tester.getRect(
      find.descendant(of: field, matching: find.byType(InputDecorator)),
    ),
    typing: tester.getRect(
      find.descendant(of: field, matching: find.byType(EditableText)),
    ),
  );

  testWidgets(
    'UX-1629: ES, 1x on 360x800, recovery sent: Código de recuperación and Nueva contraseña both sit on their fields’ borders, above the empty fields',
    (tester) async {
      await openRecoverySent(tester, es);
      expect(es.recoveryCode, 'Código de recuperación');
      expect(es.newPassword, 'Nueva contraseña');
      final offsets = <double>[];
      for (final (field, label) in [
        (recoveryCode, es.recoveryCode),
        (password, es.newPassword),
      ]) {
        expect(typed(tester, field), isEmpty, reason: 'the field is empty');
        final decoration = tester
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .decoration!;
        expect(
          decoration.floatingLabelBehavior,
          FloatingLabelBehavior.always,
          reason: label,
        );
        final parts = fieldParts(tester, field, label);
        // Above where the words go, not inside the empty field.
        expect(
          parts.label.bottom,
          lessThanOrEqualTo(parts.typing.top + 0.5),
          reason: '$label ${parts.label} over ${parts.typing}',
        );
        expect(
          parts.label.center.dy,
          lessThan(parts.box.center.dy),
          reason: '$label in the top half of ${parts.box}',
        );
        offsets.add(parts.label.center.dy - parts.box.top);
      }
      // Both labels sit the same way on their borders.
      expect(offsets.first, moreOrLessEquals(offsets.last, epsilon: 1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-1629: ${language.toUpperCase()}, 2x on 360x800, recovery sent: ${language == 'es' ? 'Código de recuperación and Nueva contraseña' : 'Codi de recuperació and Contrasenya nova'} show whole on their borders, not cut',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openRecoverySent(tester, l);
        if (language == 'ca') {
          expect(l.recoveryCode, 'Codi de recuperació');
          expect(l.newPassword, 'Contrasenya nova');
        }
        for (final (field, label) in [
          (recoveryCode, l.recoveryCode),
          (password, l.newPassword),
        ]) {
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          final text = find.descendant(of: field, matching: find.text(label));
          expect(text, findsOneWidget, reason: label);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          final parts = fieldParts(tester, field, label);
          expect(parts.label.left, greaterThanOrEqualTo(parts.box.left - 0.5));
          expect(
            parts.label.right,
            lessThanOrEqualTo(parts.box.right + 0.5),
            reason: '$label ${parts.label} in ${parts.box}',
          );
          expect(parts.label.left, greaterThanOrEqualTo(-0.5));
          expect(parts.label.right, lessThanOrEqualTo(360.5));
          expect(
            parts.label.bottom,
            lessThanOrEqualTo(parts.typing.top + 0.5),
            reason: '$label above the empty field',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1604: TalkBack on sign-in (ES) reads Inicia sesión, then the pitch, then Continuar con Google; no stop ends with a lone «o»',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openIn(tester);
      final stops = readingOrder(tester);
      final heading = readAt(stops, (label) => label == es.signInHeading);
      final pitch = readAt(stops, (label) => label == es.authPitch);
      final google = readAt(
        stops,
        (label) => label.contains(es.continueWithGoogle),
      );
      expect(heading, isNot(-1), reason: '$stops');
      expect(pitch, isNot(-1), reason: 'the pitch is a stop of its own: $stops');
      expect(google, isNot(-1), reason: '$stops');
      expect(heading, lessThan(pitch));
      expect(pitch, lessThan(google));
      for (final stop in stops) {
        expect(
          RegExp(r'(^|\s)o$').hasMatch(stop.label),
          isFalse,
          reason: '«${stop.label}»',
        );
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-1604: after a wrong password (ES), the live region’s label is exactly the error line, not the pitch',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openIn(
        tester,
        api: _LoginApi(
          signInError: ApiException(
            401,
            'No active account found with the given credentials',
          ),
        ),
      );
      await tester.enterText(email, 'ana@example.invalid');
      await tester.enterText(password, 'una-clave-larga-2026');
      await tapVisible(tester, submit);
      final error = es.requestError('credentials');
      expect(find.text(error), findsOneWidget);
      final stops = readingOrder(tester);
      final live = [
        for (final stop in stops)
          if (stop.live) stop.label,
      ];
      final withError = live.where((label) => label.contains(error)).toList();
      expect(withError, [error], reason: 'live regions: $live');
      for (final label in live) {
        expect(label.contains(es.authPitch), isFalse, reason: label);
      }
      semantics.dispose();
    },
  );

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-1617: ${language.toUpperCase()}, the email field reads ${language == 'es' ? 'Correo' : 'Correu'}, and its label and the password’s show above the fields at 2x on 360x800',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openIn(tester, language: language);
        for (final (field, label) in [(email, l.email), (password, l.password)]) {
          final decoration = tester
              .widget<TextField>(
                find.descendant(of: field, matching: find.byType(TextField)),
              )
              .decoration!;
          expect(decoration.labelText, label);
          expect(
            decoration.floatingLabelBehavior,
            FloatingLabelBehavior.always,
          );
        }
        expect(l.email, language == 'es' ? 'Correo' : 'Correu');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1617: ES, creating an account with an email in use says Este correo ya tiene una cuenta., whole at 2x on 360x800',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openIn(
        tester,
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
      final line = find.descendant(of: email, matching: find.text(used));
      expect(line, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(line).didExceedMaxLines,
        isFalse,
      );
      final rect = tester.getRect(line);
      expect(rect.right, lessThanOrEqualTo(360.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1617: ES, at least 8 dp between ¿Has olvidado tu contraseña? and the password field, and between it and Iniciar sesión',
    (tester) async {
      await openIn(tester);
      final forgot = find.widgetWithText(TextButton, es.forgotPassword);
      expect(forgot, findsOneWidget);
      final link = tester.getRect(forgot);
      final field = tester.getRect(
        find.descendant(of: password, matching: find.byType(TextField)),
      );
      final button = tester.getRect(submit);
      expect(link.top - field.bottom, greaterThanOrEqualTo(8));
      expect(button.top - link.bottom, greaterThanOrEqualTo(8));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1617: ES, a wrong password for an unknown account leaves exactly one control that opens create: Crear una cuenta con este correo',
    (tester) async {
      await openIn(
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
      expect(find.text(es.requestError('credentials')), findsOneWidget);
      final creates = find.byWidgetPredicate(
        (widget) =>
            widget is ButtonStyleButton &&
            find
                .descendant(
                  of: find.byWidget(widget),
                  matching: find.byWidgetPredicate(
                    (text) =>
                        text is Text &&
                        (text.data ?? '').startsWith(es.createAnAccount),
                  ),
                )
                .evaluate()
                .isNotEmpty,
      );
      expect(creates, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('create-account-with-email')),
          matching: find.text(es.createAccountWithEmail),
        ),
        findsOneWidget,
      );
      expect(find.text(es.createAnAccount), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-1507: ${language.toUpperCase()}, signed out with a stored invitation link, the line naming its address shows above Continuar con Google; without a link it doesn’t; once cleared it goes',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final invitations = InvitationLinks(listen: false);
        await openIn(tester, language: language, invitations: invitations);
        final line = find.text(l.invitationWaitingSignIn);
        expect(line, findsNothing, reason: 'no link yet');
        invitations.receive(
          Uri.parse(
            'taskflow://invite?kind=list'
            '&id=6f1c2a4e-8b3d-4c5e-9f7a-1b2c3d4e5f60'
            '&code=test-invitation-code',
          ),
        );
        await tester.pumpAndSettle();
        expect(invitations.state, isNotNull);
        expect(line, findsOneWidget);
        expect(
          tester.getRect(line).bottom,
          lessThanOrEqualTo(tester.getRect(google).top),
        );
        // Google stays the first way in.
        expect(
          tester.getRect(google).top,
          lessThan(tester.getRect(email).top),
        );
        invitations.clear(invitations.state!);
        await tester.pumpAndSettle();
        expect(invitations.state, isNull);
        expect(line, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- UX loop 2026-10-19-app, round 1 · P191 (UX-1602): recovery with
  // the 6-digit code ----

  const maria = 'maria.lopez@example.com';
  const newPassword = 'clave-nueva-2026-larga';
  TextField codeTextField(WidgetTester tester) => tester.widget<TextField>(
    find.descendant(of: recoveryCode, matching: find.byType(TextField)),
  );
  bool hasFocus(WidgetTester tester, Finder field) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;

  /// Recovery in [l]'s language, with a code sent to [address].
  Future<_LoginApi> recoverySent(
    WidgetTester tester,
    AppLocalizations l, {
    _LoginApi? api,
    String address = maria,
  }) async {
    final client = await openIn(tester, language: l.localeName, api: api);
    await tapVisible(tester, find.text(l.forgotPassword));
    await tester.enterText(email, address);
    await tapVisible(tester, submit);
    expect(recoveryCode, findsOneWidget);
    return client;
  }

  testWidgets(
    'UX-1602: ES, after Enviar código, the code field has the number pad and the one-time-code hint, takes digits only and stops at 6; with 5 digits Guardar contraseña nueva says «El código tiene 6 cifras» and sends nothing',
    (tester) async {
      final api = await recoverySent(tester, es);
      final field = codeTextField(tester);
      expect(field.keyboardType, TextInputType.number);
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      // Its label stays «Código de recuperación».
      expect(
        find.descendant(of: recoveryCode, matching: find.text(es.recoveryCode)),
        findsOneWidget,
      );
      await tester.enterText(recoveryCode, '12a3-45 6789');
      await tester.pumpAndSettle();
      expect(typed(tester, recoveryCode), '123456');

      await tester.enterText(recoveryCode, '12345');
      await tester.enterText(password, newPassword);
      await tester.pumpAndSettle();
      final sent = api.requests.length;
      await tapVisible(tester, submit);
      expect(es.verifyEmailCodeLength, 'El código tiene 6 cifras');
      expect(
        find.descendant(
          of: recoveryCode,
          matching: find.text(es.verifyEmailCodeLength),
        ),
        findsOneWidget,
      );
      expect(api.requests.length, sent, reason: 'nothing sent');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1602: with 123456 and a 12-character password, the confirm carries the address the code went to, the code and the password; after a 200 sign-in says Contraseña actualizada',
    (tester) async {
      final api = await recoverySent(tester, es, address: '  $maria ');
      expect(api.requests.last, [
        'auth/password-reset/',
        {'email': maria, 'language': 'es'},
      ]);
      await tester.enterText(recoveryCode, '123456');
      expect('doce-letras!'.length, 12);
      await tester.enterText(password, 'doce-letras!');
      await tapVisible(tester, submit);
      expect(api.requests.last, [
        'auth/password-reset/confirm/',
        {'email': maria, 'code': '123456', 'password': 'doce-letras!'},
      ]);
      expect(find.text(es.signInHeading), findsOneWidget);
      expect(
        es.passwordResetComplete,
        'Contraseña actualizada. Inicia sesión con tu nueva contraseña.',
      );
      expect(find.text(es.passwordResetComplete), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1602: through «Ya tengo un código», with no code requested, the email field shows above the code; left empty, nothing is sent and the email field says what is missing',
    (tester) async {
      final api = await openIn(tester);
      await tapVisible(tester, find.text(es.forgotPassword));
      await tapVisible(tester, find.text(es.authHaveRecoveryCode));
      expect(email, findsOneWidget);
      expect(recoveryCode, findsOneWidget);
      expect(
        tester.getRect(email).bottom,
        lessThanOrEqualTo(tester.getRect(recoveryCode).top),
      );
      await tester.enterText(recoveryCode, '123456');
      await tester.enterText(password, newPassword);
      final before = api.requests.length;
      await tapVisible(tester, submit);
      expect(api.requests.length, before, reason: 'nothing sent');
      expect(
        find.descendant(of: email, matching: find.text(es.enterEmail)),
        findsOneWidget,
      );

      await tester.enterText(email, maria);
      await tapVisible(tester, submit);
      expect(api.requests.last, [
        'auth/password-reset/confirm/',
        {'email': maria, 'code': '123456', 'password': newPassword},
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1602: a 400 code_invalid says «Ese código no es correcto…» under the code field, and the new password stays typed',
    (tester) async {
      await recoverySent(tester, es, api: _RefusingApi('code_invalid'));
      await tester.enterText(recoveryCode, '123456');
      await tester.enterText(password, newPassword);
      await tapVisible(tester, submit);
      expect(
        es.verifyEmailCodeInvalid,
        'Ese código no es correcto. Mira el último correo que te hemos enviado.',
      );
      expect(
        find.descendant(
          of: recoveryCode,
          matching: find.text(es.verifyEmailCodeInvalid),
        ),
        findsOneWidget,
      );
      expect(typed(tester, password), newPassword);
      expect(find.text(es.signInHeading), findsNothing, reason: 'still here');
      expect(tester.takeException(), isNull);
    },
  );

  test('UX-1602: the renewed-code line in EN, ES and CA', () {
    expect(
      lookupAppLocalizations(const Locale('en')).recoveryCodeRenewed(maria),
      'That code no longer works. If $maria has an account, a new one is on its way.',
    );
    expect(
      es.recoveryCodeRenewed(maria),
      'Ese código ya no sirve. Si $maria tiene cuenta, te llegará uno nuevo.',
    );
    expect(
      lookupAppLocalizations(const Locale('ca')).recoveryCodeRenewed(maria),
      'Aquest codi ja no serveix. Si $maria té compte, te n’arribarà un de nou.',
    );
  });

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-1602: ${language.toUpperCase()}, a 400 code_expired asks for a new code for the same address and language at once; the code field is empty and focused, and the line above it says a new one is on its way',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final api = await recoverySent(
          tester,
          l,
          api: _RefusingApi('code_expired'),
        );
        await tester.enterText(recoveryCode, '123456');
        await tester.enterText(password, newPassword);
        await tapVisible(tester, submit);
        expect(api.requests.last, [
          'auth/password-reset/',
          {'email': maria, 'language': language},
        ]);
        expect(
          api.requests.where((r) => r[0] == 'auth/password-reset/'),
          hasLength(2),
        );
        expect(typed(tester, recoveryCode), isEmpty);
        expect(hasFocus(tester, recoveryCode), isTrue);
        final line = findShown(l.recoveryCodeRenewed(maria));
        expect(line, findsOneWidget);
        expect(findShown(l.recoveryEmailRequested(maria)), findsNothing);
        expect(
          tester.getRect(line).bottom,
          lessThanOrEqualTo(tester.getRect(recoveryCode).top),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('UX-1602: no catalog has authEnterRecoveryCode', () {
    for (final language in ['en', 'es', 'ca']) {
      final arb = File('lib/l10n/app_$language.arb').readAsStringSync();
      expect(arb, isNot(contains('authEnterRecoveryCode')), reason: language);
    }
  });

  // ---- UX loop 2026-10-19-app, round 1 · P193 (UX-1603): Google first, the
  // email form behind «Continuar con mi correo» ----

  final continueWithEmail = find.byKey(const ValueKey('continue-with-email'));

  /// A fresh sign-in, folded, in [language].
  Future<_LoginApi> openFolded(
    WidgetTester tester, {
    String language = 'es',
    ThemeMode theme = ThemeMode.light,
    Size size = const Size(360, 800),
  }) async {
    final client = _LoginApi();
    final (_, auth) = await _open(
      tester,
      client: client,
      language: language,
      theme: theme,
      size: size,
    );
    auth.finish();
    await tester.pumpAndSettle();
    return client;
  }

  test('UX-1603: «Continuar con mi correo» in EN, ES and CA', () {
    expect(
      lookupAppLocalizations(const Locale('en')).continueWithEmail,
      'Continue with email',
    );
    expect(es.continueWithEmail, 'Continuar con mi correo');
    expect(
      lookupAppLocalizations(const Locale('ca')).continueWithEmail,
      'Continua amb el correu',
    );
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'UX-1603: ES, ${scale}x on 360x800, ${theme.name}, a fresh sign-in shows Continuar con Google and Continuar con mi correo, with no field, no Iniciar sesión, no Crear una cuenta and no «o»',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await openFolded(tester, theme: theme);
          expect(google.hitTestable(), findsOneWidget);
          expect(
            find.descendant(
              of: google,
              matching: find.text(es.continueWithGoogle),
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(continueWithEmail);
          await tester.pumpAndSettle();
          expect(continueWithEmail.hitTestable(), findsOneWidget);
          expect(
            find.descendant(
              of: continueWithEmail,
              matching: find.text(es.continueWithEmail),
            ),
            findsOneWidget,
          );
          expect(tester.widget(continueWithEmail), isA<TextButton>());
          // Under Google.
          expect(
            tester.getRect(continueWithEmail).top,
            greaterThanOrEqualTo(tester.getRect(google).bottom),
          );
          for (final gone in [
            email,
            password,
            submit,
            find.byKey(const ValueKey('account-recovery-code')),
          ]) {
            expect(find.descendant(of: find.byType(LoginScreen), matching: gone,
                skipOffstage: false), findsNothing);
          }
          for (final text in [
            es.signIn,
            es.createAnAccount,
            es.forgotPassword,
            es.authOr,
          ]) {
            expect(
              find.text(text, skipOffstage: false),
              findsNothing,
              reason: text,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'UX-1603: ES, 1x on 360x800, folded, the ways to tap are the language, Google, Continuar con mi correo, Privacidad and Términos (besides debug-only controls), and the only button-shaped one is Google',
    (tester) async {
      await openFolded(tester);
      final body = find
          .descendant(
            of: find.byType(LoginScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      // Every row built, down to the links under the card.
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('site-${SitePage.terms.path}')),
        100,
        scrollable: body,
      );
      await tester.pumpAndSettle();
      final debugOnly = {
        ...find
            .byKey(const ValueKey('development-sign-in'), skipOffstage: false)
            .evaluate(),
        ...find
            .ancestor(
              of: find.text(es.connectionSettings, skipOffstage: false),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            )
            .evaluate(),
      }.map((e) => e.widget).toSet();
      final targets = find
          .descendant(
            of: find.byType(LoginScreen),
            matching: find.byWidgetPredicate(
              (w) =>
                  (w is ButtonStyleButton || w is IconButton) &&
                  !debugOnly.contains(w),
            ),
            skipOffstage: false,
          )
          .evaluate()
          .map((e) => e.widget)
          .toList();
      // An IconButton draws a ButtonStyleButton of its own inside it.
      final icons = targets.whereType<IconButton>().toList();
      final buttons = targets.whereType<ButtonStyleButton>().where(
        (b) => !find
            .descendant(
              of: find.byType(IconButton, skipOffstage: false),
              matching: find.byWidget(b),
              skipOffstage: false,
            )
            .evaluate()
            .isNotEmpty,
      ).toList();
      expect(icons, hasLength(1), reason: 'the language menu');
      expect(icons.single.tooltip, es.language);
      expect(buttons, hasLength(4), reason: '$buttons');
      final shaped = buttons
          .where((b) => b is FilledButton || b is OutlinedButton || b is ElevatedButton)
          .toList();
      expect(shaped, hasLength(1));
      expect(
        find.descendant(
          of: google,
          matching: find.byWidget(shaped.single),
        ),
        findsOneWidget,
      );
      expect(
        buttons.whereType<TextButton>().map((b) => b.key).toSet(),
        {
          const ValueKey('continue-with-email'),
          ValueKey('site-${SitePage.privacy.path}'),
          ValueKey('site-${SitePage.terms.path}'),
        },
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1603: tapping Continuar con mi correo shows the fields, ¿Has olvidado tu contraseña?, Iniciar sesión and Crear una cuenta, with the focus in Correo; Back folds them again',
    (tester) async {
      await openFolded(tester, size: const Size(390, 844));
      await tapVisible(tester, continueWithEmail);
      expect(continueWithEmail, findsNothing);
      expect(email, findsOneWidget);
      expect(password, findsOneWidget);
      expect(find.text(es.authOr), findsOneWidget);
      expect(find.text(es.forgotPassword), findsOneWidget);
      expect(
        find.descendant(of: submit, matching: find.text(es.signIn)),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text(es.createAnAccount));
      await tester.pumpAndSettle();
      expect(find.text(es.createAnAccount), findsOneWidget);
      expect(hasFocus(tester, email), isTrue, reason: 'the focus in Correo');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(email, findsNothing);
      expect(password, findsNothing);
      expect(find.text(es.authOr), findsNothing);
      expect(continueWithEmail, findsOneWidget);
      expect(google, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (name, way, heading) in [
    ('create', es.createAnAccount, es.registerHeading),
    ('recovery', es.forgotPassword, es.recoveryHeading),
  ]) {
    testWidgets(
      'UX-1603: Back from $name lands on the open form, not the folded view',
      (tester) async {
        await openFolded(tester, size: const Size(390, 844));
        await tapVisible(tester, continueWithEmail);
        await tapVisible(tester, find.text(way));
        expect(find.text(heading), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(es.signInHeading), findsOneWidget);
        expect(email, findsOneWidget);
        expect(password, findsOneWidget);
        expect(
          find.descendant(of: submit, matching: find.text(es.signIn)),
          findsOneWidget,
        );
        expect(continueWithEmail, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1603: with Google not configured, the email form shows from the start',
    (tester) async {
      final (_, auth) = await _open(
        tester,
        client: _LoginApi(),
        language: 'es',
        google: _UnconfiguredGoogle(),
      );
      auth.finish();
      await tester.pumpAndSettle();
      expect(email, findsOneWidget);
      expect(password, findsOneWidget);
      expect(continueWithEmail, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1603: TalkBack on the folded sign-in (ES) reads Entra o crea tu cuenta, the pitch, Continuar con Google, then Continuar con mi correo',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openFolded(tester);
      final stops = readingOrder(tester);
      final heading = readAt(stops, (label) => label == es.signInOrUpHeading);
      final pitch = readAt(stops, (label) => label == es.authPitch);
      final viaGoogle = readAt(
        stops,
        (label) => label.contains(es.continueWithGoogle),
      );
      final viaEmail = readAt(
        stops,
        (label) => label.contains(es.continueWithEmail),
      );
      expect(es.signInOrUpHeading, 'Entra o crea tu cuenta');
      for (final at in [heading, pitch, viaGoogle, viaEmail]) {
        expect(at, isNot(-1), reason: '$stops');
      }
      expect(heading, lessThan(pitch), reason: '$stops');
      expect(pitch, lessThan(viaGoogle), reason: '$stops');
      expect(viaGoogle, lessThan(viaEmail), reason: '$stops');
      semantics.dispose();
    },
  );

  // ---- UX loop 2026-10-28-app, round 1 · P291 (UX-2606, UX-2611) ----
  group('P291 · the first screen names both ways in; recovery’s links apart', () {
    test('UX-2606: the folded heading reads as planned in ES, EN and CA', () {
      expect(es.signInOrUpHeading, 'Entra o crea tu cuenta');
      expect(
        lookupAppLocalizations(const Locale('en')).signInOrUpHeading,
        'Sign in or sign up',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).signInOrUpHeading,
        'Entra o crea el teu compte',
      );
    });

    /// [text]'s lines as drawn.
    int linesOf(WidgetTester tester, Finder text) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      final plain = paragraph.text.toPlainText();
      return {
        for (final box in paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: plain.length),
        ))
          box.top.round(),
      }.length;
    }

    for (final (language, scale) in [
      ('es', 1.0),
      ('es', 2.0),
      ('ca', 2.0),
      ('en', 2.0),
    ]) {
      testWidgets(
        'UX-2606: auth/sign-in.sign-in, $language at ${scale.toInt()}× on 360×800, the email form folded: the heading reads «${lookupAppLocalizations(Locale(language)).signInOrUpHeading}», on 2 lines or fewer, and TalkBack names the screen with it',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await (FontLoader('Manrope')
                ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
              .load();
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final l = lookupAppLocalizations(Locale(language));
          await openFolded(tester, language: language);
          expect(continueWithEmail, findsOneWidget, reason: 'folded');
          final heading = find.descendant(
            of: find.byType(AuthHeading),
            matching: find.text(l.signInOrUpHeading),
          );
          expect(heading, findsOneWidget);
          expect(find.text(l.signInHeading), findsNothing);
          expect(linesOf(tester, heading), lessThanOrEqualTo(2));
          final rect = tester.getRect(heading);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360.5));
          final node = tester.getSemantics(find.byType(AuthHeading));
          expect(node.label, l.signInOrUpHeading);
          expect(node.flagsCollection.isHeader, isTrue);
          expect(node.flagsCollection.namesRoute, isTrue);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2606: auth/sign-in.email-open still reads «Inicia sesión»; create keeps «Crea tu cuenta» and recovery its own heading',
      (tester) async {
        await openFolded(tester, size: const Size(390, 844));
        await tapVisible(tester, continueWithEmail);
        expect(find.text(es.signInHeading), findsOneWidget);
        expect(es.signInHeading, 'Inicia sesión');
        expect(find.text(es.signInOrUpHeading), findsNothing);
        await tapVisible(tester, find.text(es.createAnAccount));
        expect(find.text(es.registerHeading), findsOneWidget);
        expect(es.registerHeading, 'Crea tu cuenta');
        expect(find.text(es.signInOrUpHeading), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text(es.forgotPassword));
        expect(find.text(es.recoveryHeading), findsOneWidget);
        expect(find.text(es.signInOrUpHeading), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['es', 'ca']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'UX-2611: auth/sign-in.recovery, $language at ${scale.toInt()}× on 360×800: 8 dp or more between «Ya tengo un código» and «Volver a iniciar sesión»',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final l = lookupAppLocalizations(Locale(language));
            await openIn(tester, language: language);
            await tapVisible(tester, find.text(l.forgotPassword));
            final code = find.widgetWithText(
              TextButton,
              l.authHaveRecoveryCode,
            );
            final back = find.widgetWithText(TextButton, l.backToSignIn);
            await tester.ensureVisible(back);
            await tester.pumpAndSettle();
            expect(code, findsOneWidget);
            expect(back, findsOneWidget);
            expect(
              tester.getRect(back).top - tester.getRect(code).bottom,
              greaterThanOrEqualTo(8 - 0.5),
              reason: 'apart, so a tap on one doesn’t land on the other',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
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

/// P191: the server refuses every recovery code with [refusal]
/// (`code_invalid` or `code_expired`); asking for a code works.
class _RefusingApi extends _LoginApi {
  _RefusingApi(this.refusal);
  final String refusal;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    await super.request(
      method,
      path,
      data: data,
      audioPath: audioPath,
      authenticated: authenticated,
      accountId: accountId,
    );
    if (path == 'auth/password-reset/confirm/') {
      throw ApiException(400, 'Refused.', {'code': refusal});
    }
    return {};
  }
}

/// P193: Google sign-in exists on this phone but isn't set up.
class _UnconfiguredGoogle extends GoogleSignInService {
  @override
  bool get supported => true;
  @override
  bool get configured => false;
}
