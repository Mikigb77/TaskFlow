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
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
